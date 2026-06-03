import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:change_case/change_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart'
    show teamByIdProvider, teamSlotsProvider;
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/services/format/format_service.dart';
import 'package:poke_team_dex/services/format/slot_validator.dart';
import 'package:poke_team_dex/services/format/sprite_resolver.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:poke_team_dex/features/teams/data/dynamax_data.dart';
import 'package:poke_team_dex/features/teams/data/form_filter.dart';
import 'package:poke_team_dex/features/teams/data/mega_forms_data.dart';
import 'package:poke_team_dex/features/teams/data/z_moves_data.dart';
import 'package:poke_team_dex/features/teams/data/ribbon_catalog.dart';
import 'package:poke_team_dex/features/teams/presentation/instance_chain_view.dart';
import 'package:poke_team_dex/features/teams/presentation/instance_picker_sheet.dart';
import 'package:poke_team_dex/features/teams/services/ps_export_service.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/widgets/connectivity_status_button.dart';
import 'package:poke_team_dex/shared/widgets/favorite_button.dart';
import 'package:poke_team_dex/shared/widgets/move_type_chip.dart';
import 'package:poke_team_dex/shared/widgets/pokemon_sprite.dart';
import 'package:poke_team_dex/shared/widgets/stat_bar.dart';
import 'package:poke_team_dex/shared/widgets/type_badge.dart';

// ── Nature data ───────────────────────────────────────────────────────────────

class _NatureData {
  final String name;
  final String? increased;
  final String? decreased;
  const _NatureData(this.name, {this.increased, this.decreased});
  bool get isNeutral => increased == null;
}

const _kNatures = [
  _NatureData('Hardy'),
  _NatureData('Docile'),
  _NatureData('Serious'),
  _NatureData('Bashful'),
  _NatureData('Quirky'),
  _NatureData('Lonely', increased: 'Attack', decreased: 'Defense'),
  _NatureData('Brave', increased: 'Attack', decreased: 'Speed'),
  _NatureData('Adamant', increased: 'Attack', decreased: 'Sp. Atk'),
  _NatureData('Naughty', increased: 'Attack', decreased: 'Sp. Def'),
  _NatureData('Bold', increased: 'Defense', decreased: 'Attack'),
  _NatureData('Relaxed', increased: 'Defense', decreased: 'Speed'),
  _NatureData('Impish', increased: 'Defense', decreased: 'Sp. Atk'),
  _NatureData('Lax', increased: 'Defense', decreased: 'Sp. Def'),
  _NatureData('Timid', increased: 'Speed', decreased: 'Attack'),
  _NatureData('Hasty', increased: 'Speed', decreased: 'Defense'),
  _NatureData('Jolly', increased: 'Speed', decreased: 'Sp. Atk'),
  _NatureData('Naive', increased: 'Speed', decreased: 'Sp. Def'),
  _NatureData('Modest', increased: 'Sp. Atk', decreased: 'Attack'),
  _NatureData('Mild', increased: 'Sp. Atk', decreased: 'Defense'),
  _NatureData('Quiet', increased: 'Sp. Atk', decreased: 'Speed'),
  _NatureData('Rash', increased: 'Sp. Atk', decreased: 'Sp. Def'),
  _NatureData('Calm', increased: 'Sp. Def', decreased: 'Attack'),
  _NatureData('Gentle', increased: 'Sp. Def', decreased: 'Defense'),
  _NatureData('Sassy', increased: 'Sp. Def', decreased: 'Speed'),
  _NatureData('Careful', increased: 'Sp. Def', decreased: 'Sp. Atk'),
];

const _kNatureModifiers = <String, (String?, String?)>{
  'hardy':   (null, null),
  'docile':  (null, null),
  'serious': (null, null),
  'bashful': (null, null),
  'quirky':  (null, null),
  'lonely':  ('attack', 'defense'),
  'brave':   ('attack', 'speed'),
  'adamant': ('attack', 'special-attack'),
  'naughty': ('attack', 'special-defense'),
  'bold':    ('defense', 'attack'),
  'relaxed': ('defense', 'speed'),
  'impish':  ('defense', 'special-attack'),
  'lax':     ('defense', 'special-defense'),
  'timid':   ('speed', 'attack'),
  'hasty':   ('speed', 'defense'),
  'jolly':   ('speed', 'special-attack'),
  'naive':   ('speed', 'special-defense'),
  'modest':  ('special-attack', 'attack'),
  'mild':    ('special-attack', 'defense'),
  'quiet':   ('special-attack', 'speed'),
  'rash':    ('special-attack', 'special-defense'),
  'calm':    ('special-defense', 'attack'),
  'gentle':  ('special-defense', 'defense'),
  'sassy':   ('special-defense', 'speed'),
  'careful': ('special-defense', 'special-attack'),
};

// ── Stat calculator (Gen III+ formula) ───────────────────────────────────────

int _calcHP(int base, int iv, int ev, int level) =>
    ((2 * base + iv + ev ~/ 4) * level) ~/ 100 + level + 10;

int _calcStat(int base, int iv, int ev, int level, double natureMod) {
  final inner = ((2 * base + iv + ev ~/ 4) * level) ~/ 100 + 5;
  return (inner * natureMod).floor();
}

double _natureMod(String? natureName, String statKey) {
  if (natureName == null) return 1.0;
  final mods = _kNatureModifiers[natureName.toLowerCase()];
  if (mods == null) return 1.0;
  if (mods.$1 == statKey) return 1.1;
  if (mods.$2 == statKey) return 0.9;
  return 1.0;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _itemListProvider = FutureProvider<List<String>>((ref) =>
    ref.read(pokeApiRepositoryProvider).fetchItemList());

/// Set of species names (PokéAPI format) catchable in Legends: Arceus.
/// Fetched once, cached in Hive by the repository layer.
final _hisuiDexProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final dex =
      await ref.read(pokeApiRepositoryProvider).fetchRegionalPokedex('hisui');
  return dex.keys.toSet();
});

final _abilityDetailProvider =
    FutureProvider.autoDispose.family<AbilityEntry, String>((ref, name) =>
        ref.read(pokeApiRepositoryProvider).fetchAbility(name));

final _moveDetailProvider =
    FutureProvider.autoDispose.family<MoveEntry, String>((ref, name) =>
        ref.read(pokeApiRepositoryProvider).fetchMove(name));

final _itemDetailProvider =
    FutureProvider.autoDispose.family<ItemEntry, String>((ref, name) =>
        ref.read(pokeApiRepositoryProvider).fetchItem(name));

// ── Screen ────────────────────────────────────────────────────────────────────

class SlotConfigScreen extends ConsumerStatefulWidget {
  final int teamId;
  final int slotNumber;
  final bool embedded;
  final VoidCallback? onClose;

  const SlotConfigScreen({
    super.key,
    required this.teamId,
    required this.slotNumber,
    this.embedded = false,
    this.onClose,
  });

  @override
  ConsumerState<SlotConfigScreen> createState() => _SlotConfigState();
}

class _SlotConfigState extends ConsumerState<SlotConfigScreen> {
  late TextEditingController _nicknameCtrl;
  bool _isShiny = false;
  String? _gender;
  int _level = 50;
  int _friendship = 0;
  String? _abilityName;
  String? _natureName;
  String? _heldItemName;
  final List<String?> _moves = [null, null, null, null];

  // EVs / IVs indexed [hp, atk, def, spa, spd, spe]
  late List<TextEditingController> _evCtrls;
  late List<TextEditingController> _ivCtrls;

  // Contest conditions indexed [cool, beautiful, cute, clever, tough, sheen]
  late List<TextEditingController> _contestCtrls;

  // Ribbons — set of ribbon ids currently awarded to this Pokémon
  final Set<String> _ribbons = {};

  // Form change (e.g. aegislash-shield ↔ aegislash-blade)
  String? _formName; // null = use the Pokémon's default form

  // Pokemon instance link
  int? _instanceId;

  // Mega Evolution toggle
  bool _isMegaEvolved = false;

  // Gigantamax (Gen 8)
  bool _hasGigantamax = false;
  bool _gigantamaxEnabled = false;

  // Alpha Pokémon (Legends: Arceus)
  bool _isAlpha = false;

  bool _initialized = false;
  bool _saving = false;

  static const _statLabels = ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe'];
  static const _statKeys = [
    'hp', 'attack', 'defense', 'special-attack', 'special-defense', 'speed',
  ];

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController();
    _evCtrls = List.generate(6, (_) => TextEditingController(text: '0'));
    _ivCtrls = List.generate(6, (_) => TextEditingController(text: '31'));
    _contestCtrls = List.generate(6, (_) => TextEditingController(text: '0'));
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    for (final c in _evCtrls) { c.dispose(); }
    for (final c in _ivCtrls) { c.dispose(); }
    for (final c in _contestCtrls) { c.dispose(); }
    super.dispose();
  }

  void _initFromSlot(TeamSlot slot) {
    if (_initialized) return;
    _initialized = true;
    _nicknameCtrl.text = slot.nickname ?? '';
    _isShiny      = slot.isShiny;
    _gender       = slot.gender;
    _level        = slot.level ?? 50;
    _friendship   = slot.friendship ?? 0;
    _abilityName  = slot.abilityName;
    // Normalise nature to match DropdownButton item values (Proper case).
    // Guards against lowercase values stored by older imports.
    final rawNature = slot.natureName;
    _natureName = (rawNature != null && rawNature.isNotEmpty)
        ? rawNature[0].toUpperCase() + rawNature.substring(1).toLowerCase()
        : null;
    // If the value still doesn't match a known nature, clear it rather than crash.
    if (_natureName != null &&
        !_kNatures.any((n) => n.name == _natureName)) {
      _natureName = null;
    }
    _heldItemName = slot.heldItemName;
    _moves[0] = slot.move1;
    _moves[1] = slot.move2;
    _moves[2] = slot.move3;
    _moves[3] = slot.move4;
    _evCtrls[0].text = (slot.evHp  ?? 0).toString();
    _evCtrls[1].text = (slot.evAtk ?? 0).toString();
    _evCtrls[2].text = (slot.evDef ?? 0).toString();
    _evCtrls[3].text = (slot.evSpa ?? 0).toString();
    _evCtrls[4].text = (slot.evSpd ?? 0).toString();
    _evCtrls[5].text = (slot.evSpe ?? 0).toString();
    _ivCtrls[0].text = (slot.ivHp  ?? 31).toString();
    _ivCtrls[1].text = (slot.ivAtk ?? 31).toString();
    _ivCtrls[2].text = (slot.ivDef ?? 31).toString();
    _ivCtrls[3].text = (slot.ivSpa ?? 31).toString();
    _ivCtrls[4].text = (slot.ivSpd ?? 31).toString();
    _ivCtrls[5].text = (slot.ivSpe ?? 31).toString();
    _formName = slot.formName;
    _instanceId = slot.instanceId;
    _isMegaEvolved = slot.isMegaEvolved;
    _hasGigantamax = slot.hasGigantamax;
    _gigantamaxEnabled = slot.gigantamaxEnabled;
    _isAlpha = slot.isAlpha;

    // Ribbons
    _ribbons.clear();
    final ribbonJson = slot.ribbons;
    if (ribbonJson != null && ribbonJson.isNotEmpty) {
      try {
        _ribbons.addAll(
          (jsonDecode(ribbonJson) as List).cast<String>(),
        );
      } catch (_) {}
    }
    _contestCtrls[0].text = (slot.contestCool      ?? 0).toString();
    _contestCtrls[1].text = (slot.contestBeautiful  ?? 0).toString();
    _contestCtrls[2].text = (slot.contestCute       ?? 0).toString();
    _contestCtrls[3].text = (slot.contestClever     ?? 0).toString();
    _contestCtrls[4].text = (slot.contestTough      ?? 0).toString();
    _contestCtrls[5].text = (slot.contestSheen      ?? 0).toString();
  }

  int get _evTotal =>
      _evCtrls.fold(0, (sum, c) => sum + (int.tryParse(c.text) ?? 0));

  /// Compute real-time violations against [format] for current form values.
  /// Uses PokéAPI version-group learnsets for game-specific accuracy.
  Map<String, String> _computeViolations(
    FormatService service,
    GameFormat format,
    String pokemonName,
    List<Map<String, dynamic>> pokemonMoves,
  ) {
    if (!service.isInitialized) return {};
    return validateSlotSync(
      _abilityName,
      _heldItemName,
      _moves,
      pokemonName,
      pokemonMoves,
      format,
      service,
    ).violations;
  }

  Future<void> _save(TeamSlot existing) async {
    if (_evTotal > 510) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('EV total exceeds 510 — reduce before saving.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final evs = _evCtrls.map((c) => (int.tryParse(c.text) ?? 0).clamp(0, 252)).toList();
      final ivs = _ivCtrls.map((c) => (int.tryParse(c.text) ?? 31).clamp(0, 31)).toList();
      final contest = _contestCtrls.map((c) => (int.tryParse(c.text) ?? 0).clamp(0, 255)).toList();
      final nickname = _nicknameCtrl.text.trim();

      await ref.read(teamSlotRepositoryProvider).update(
        TeamSlotsCompanion(
          id:           Value(existing.id),
          teamId:       Value(existing.teamId),
          slot:         Value(existing.slot),
          pokemonId:    Value(existing.pokemonId),
          nickname:     Value(nickname.isEmpty ? null : nickname),
          isShiny:      Value(_isShiny),
          gender:       Value(_gender),
          level:        Value(_level),
          friendship:   Value(_friendship),
          abilityName:  Value(_abilityName),
          natureName:   Value(_natureName),
          heldItemName: Value(_heldItemName),
          move1:        Value(_moves[0]),
          move2:        Value(_moves[1]),
          move3:        Value(_moves[2]),
          move4:        Value(_moves[3]),
          evHp:  Value(evs[0]),
          evAtk: Value(evs[1]),
          evDef: Value(evs[2]),
          evSpa: Value(evs[3]),
          evSpd: Value(evs[4]),
          evSpe: Value(evs[5]),
          ivHp:  Value(ivs[0]),
          ivAtk: Value(ivs[1]),
          ivDef: Value(ivs[2]),
          ivSpa: Value(ivs[3]),
          ivSpd: Value(ivs[4]),
          ivSpe: Value(ivs[5]),
          formName: Value(_formName),
          isMegaEvolved: Value(_isMegaEvolved),
          hasGigantamax: Value(_hasGigantamax),
          gigantamaxEnabled: Value(_gigantamaxEnabled),
          isAlpha: Value(_isAlpha),
          instanceId: Value(_instanceId),
          ribbons: Value(_ribbons.isEmpty
              ? null
              : jsonEncode(_ribbons.toList())),
          contestCool:      Value(contest[0]),
          contestBeautiful: Value(contest[1]),
          contestCute:      Value(contest[2]),
          contestClever:    Value(contest[3]),
          contestTough:     Value(contest[4]),
          contestSheen:     Value(contest[5]),
          syncStatus: const Value('pending'),
          updatedAt:  Value(DateTime.now()),
        ),
      );

      await ref.read(syncQueueRepositoryProvider).enqueue(
        PendingSyncOpsCompanion(
          operation:  const Value('upsert'),
          entityType: const Value('team_slot'),
          entityId:   Value(existing.id),
          payload: Value(jsonEncode({
            'team_local_id': existing.teamId,
            'slot':          existing.slot,
            'pokemon_id':    existing.pokemonId,
          })),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Best-effort PS export — runs after the DB write succeeds.
      await _maybePsExport(existing);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Saved'),
          ),
        );
        if (!widget.embedded) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Save failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Writes the team's PS export file if a PS directory is configured.
  /// Errors are swallowed so they don't disrupt the normal save flow.
  Future<void> _maybePsExport(TeamSlot existing) async {
    if (!PsExportService.isSupported) return;
    try {
      final configRepo = ref.read(appConfigRepositoryProvider);
      final psDir = await configRepo.getPsDirectory();
      if (psDir == null || psDir.isEmpty) return;

      final teamRepo = ref.read(teamRepositoryProvider);
      final slotRepo = ref.read(teamSlotRepositoryProvider);
      final folderRepo = ref.read(teamFolderRepositoryProvider);

      final team = await teamRepo.getById(existing.teamId);
      TeamFolder? folder;
      if (team.folderId != null) {
        folder = await folderRepo.getByIdOrNull(team.folderId!);
      }
      final slots = await slotRepo.getByTeam(existing.teamId);

      await PsExportService.exportTeam(
        team: team,
        folder: folder,
        slots: slots,
        psDirectory: psDir,
        pokeApi: ref.read(pokeApiRepositoryProvider),
        formatLabel: team.formatLabel, // raw format id → PS format lookup
      );
    } catch (_) {
      // Best-effort — do not surface PS export errors to the user.
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Pre-load item list so the picker is instant when the user taps.
    ref.watch(_itemListProvider);

    final slotsAsync = ref.watch(teamSlotsProvider(widget.teamId));
    return slotsAsync.when(
      loading: () => widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => widget.embedded
          ? Center(child: Text('$e'))
          : Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (slots) {
        final slot = slots.where((s) => s.slot == widget.slotNumber).firstOrNull;
        if (slot == null) {
          // Only pop/close if we were already showing data — this guards against
          // the race where the stream emits before the insert is visible.
          if (_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (widget.embedded) {
                widget.onClose?.call();
              } else if (context.canPop()) {
                context.pop();
              }
            });
          }
          return widget.embedded
              ? const Center(child: CircularProgressIndicator())
              : Scaffold(
                  appBar: AppBar(),
                  body: const Center(child: CircularProgressIndicator()),
                );
        }
        _initFromSlot(slot);
        return _buildWithPokemon(slot);
      },
    );
  }

  Widget _buildWithPokemon(TeamSlot slot) {
    ref.watch(allFormatsProvider); // ensures PS data is loaded; triggers rebuild when ready
    final pokemonAsync = ref.watch(pokemonDetailProvider(slot.pokemonId));
    return pokemonAsync.when(
      loading: () => widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => widget.embedded
          ? Center(child: Text('$e'))
          : Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (pokemon) {
        final speciesName = pokemon.name.toCapitalCase();

        final abilities = pokemon.abilities.map((a) => (
          name: a['ability']['name'] as String,
          isHidden: a['is_hidden'] as bool,
          abilitySlot: a['slot'] as int,
        )).toList()
          ..sort((a, b) => a.abilitySlot.compareTo(b.abilitySlot));

        final baseStats = <String, int>{
          for (final s in pokemon.stats)
            s['stat']['name'] as String: s['base_stat'] as int,
        };

        // Format + mechanics + validation
        final team = ref.watch(teamByIdProvider(widget.teamId)).asData?.value;
        final formatId = team?.formatLabel;
        final formatService = ref.watch(formatServiceProvider);
        final format = formatId != null ? formatService.formatById(formatId) : null;
        final mechanics = format != null
            ? GenerationMechanics.forGen(format.gen)
            : null;
        final pokemonMoves = pokemon.moves.cast<Map<String, dynamic>>();
        // violations is recomputed as effectiveViolations after form data loads.
        // ignore: unused_local_variable
        final violations = format != null
            ? _computeViolations(formatService, format, pokemon.name, pokemonMoves)
            : <String, String>{};

        // Learnable moves filtered by format version groups.
        // No format → show everything the Pokémon can ever learn.
        // Learnable moves supplemented by PS learnset to catch moves
        // Base learnset (overridden by effectiveLearnableMoves below when a form
        // is active — kept here so the compiler doesn't complain about order).

        // Sprite resolution
        final useFormatSprites =
            ref.watch(useFormatSpritesProvider).asData?.value ?? true;
        final spriteUrls = resolveSprite(
          sprites: pokemon.sprites,
          pokemonId: slot.pokemonId,
          pokemonName: pokemon.name,
          format: format,
          useFormatSprites: useFormatSprites,
        );

        // ── Mega Evolution ─────────────────────────────────────────────────
        // Determine if a mega toggle should be shown for the current slot.
        final megaEntry = _heldItemName != null
            ? kMegaStoneMap[_heldItemName]
            : null;
        // No format = no restrictions; hasMegaStone applies only for specific gens.
        final canMegaEvolve = megaEntry != null &&
            pokemon.name == megaEntry.baseSpecies &&
            (mechanics == null || mechanics.hasMegaStone);

        // Fetch mega form data lazily when the toggle is on.
        final megaPokemonAsync = (canMegaEvolve && _isMegaEvolved)
            ? ref.watch(pokemonByNameProvider(megaEntry.megaForm))
            : null;
        final megaPokemon = megaPokemonAsync?.asData?.value;

        // Use mega form for stats and artwork when evolved.
        final effectiveBaseStats = megaPokemon != null
            ? <String, int>{
                for (final s in megaPokemon.stats)
                  s['stat']['name'] as String: s['base_stat'] as int,
              }
            : baseStats;
        // Prefer HOME artwork (higher quality); fall back to official artwork.
        final megaHomeUrl = megaPokemon != null
            ? pokemonHomeUrl(megaPokemon.id)
            : null;
        final megaArtworkUrl = megaHomeUrl; // primary; official is the fallback


        // ── Form change ────────────────────────────────────────────────────
        // pokemon.formNames only lists the current form. Use the species
        // endpoint (varieties) to get ALL forms for this species.
        final speciesAsync = ref.watch(pokemonSpeciesProvider(slot.pokemonId));
        final allVarieties = speciesAsync.asData?.value.varieties
                .map((v) => v.name)
                .toList() ??
            <String>[];
        // Filter: exclude mega/primal/gmax/gender; gate ability/item forms
        // on their prerequisite being selected.
        final availableForms = filterFormChips(
          varieties: allVarieties,
          heldItem: _heldItemName,
          abilityName: _abilityName,
        );
        final hasMultipleForms = availableForms.isNotEmpty;
        // Fetch form data whenever a non-default form is selected (_formName != null).
        final formPokemonAsync = _formName != null
            ? ref.watch(pokemonByNameProvider(_formName!))
            : null;
        final formPokemon = formPokemonAsync?.asData?.value;

        // ── Form-specific abilities, moves, and base stats ─────────────────
        // When a non-default form is active (e.g. Alolan Raichu, Galarian
        // Rapidash) use that form's abilities and moves instead of the base
        // form's data so the picker and validation reflect the correct options.
        final effectiveAbilities = (formPokemon != null &&
                formPokemon.abilities.isNotEmpty)
            ? (formPokemon.abilities.map((a) => (
                  name: a['ability']['name'] as String,
                  isHidden: a['is_hidden'] as bool,
                  abilitySlot: a['slot'] as int,
                )).toList()
              ..sort((a, b) => a.abilitySlot.compareTo(b.abilitySlot)))
            : abilities;

        final effectivePokemonMoves = formPokemon != null &&
                formPokemon.moves.isNotEmpty
            ? formPokemon.moves.cast<Map<String, dynamic>>()
            : pokemonMoves;

        // Re-compute violations and learnable moves with form-specific data.
        final effectiveViolations = format != null
            ? _computeViolations(
                formatService, format, pokemon.name, effectivePokemonMoves)
            : <String, String>{};

        final effectiveLearnableMoves = (format != null
                ? buildLearnsetForFormat(
                    effectivePokemonMoves, format,
                    pokemonName: formPokemon?.name ?? pokemon.name,
                    formatService: formatService,
                  )
                : effectivePokemonMoves
                    .map((m) => m['move']['name'] as String)
                    .toSet())
            .toList()
          ..sort();

        // Form stats take highest priority (form > mega > base).
        final finalBaseStats = formPokemon != null
            ? <String, int>{
                for (final s in formPokemon.stats)
                  s['stat']['name'] as String: s['base_stat'] as int,
              }
            : effectiveBaseStats;

        // ── Gigantamax / Dynamax ────────────────────────────────────────────
        final canDynamax = mechanics == null || mechanics.hasGigantamax;
        final gmaxMove = gmaxMoveForSpecies(pokemon.name);
        final canGigantamax = canDynamax && gmaxMove != null;

        // Fetch G-Max form sprite when G-Max is active.
        final gmaxFormName = canGigantamax ? '${pokemon.name}-gmax' : null;
        final gmaxPokemonAsync = (canGigantamax && _hasGigantamax && _gigantamaxEnabled)
            ? ref.watch(pokemonByNameProvider(gmaxFormName!))
            : null;
        final gmaxPokemon = gmaxPokemonAsync?.asData?.value;

        // Form artwork — use shiny version when slot is shiny.
        final formHomeUrl = formPokemon != null
            ? (_isShiny
                ? pokemonHomeShinyUrl(formPokemon.id)
                : pokemonHomeUrl(formPokemon.id))
            : null;
        final formFallbackUrl = formPokemon != null
            ? (_isShiny
                ? (formPokemon.officialArtworkShinyUrl ??
                    formPokemon.officialArtworkUrl)
                : formPokemon.officialArtworkUrl)
            : null;

        // Sprite priority: G-Max > Mega > Form change > default.
        final gmaxHomeUrl = gmaxPokemon != null ? pokemonHomeUrl(gmaxPokemon.id) : null;
        // ── Gender-specific base sprite ─────────────────────────────────────
        // Try female HOME url first for female slots; CachedNetworkImage falls
        // back to the regular HOME url if no female sprite exists for this species.
        final isFemale = _gender == 'female';
        final genderBaseUrl = isFemale
            ? (_isShiny
                ? pokemonHomeShinyFemaleUrl(pokemon.id)
                : pokemonHomeFemaleUrl(pokemon.id))
            : null;
        final genderBaseFallback = isFemale
            ? (_isShiny ? pokemonHomeShinyUrl(pokemon.id) : pokemonHomeUrl(pokemon.id))
            : null;

        final effectiveMegaArtworkUrl =
            gmaxHomeUrl ?? megaArtworkUrl ?? formHomeUrl;
        final effectiveMegaFallbackUrl = gmaxHomeUrl != null
            ? gmaxPokemon?.officialArtworkUrl
            : megaArtworkUrl != null
                ? megaPokemon?.officialArtworkUrl
                : formFallbackUrl;

        // ── Alpha Pokémon ───────────────────────────────────────────────────
        // Only show for formats where Alpha transfers make sense
        // (PLA / Gen 9 / no format) AND only for species actually in PLA.
        final alphaFormatOk = mechanics == null ||
            format?.id == 'pla' ||
            format?.gen == 9;
        final hisuiDexAsync =
            alphaFormatOk ? ref.watch(_hisuiDexProvider) : null;
        final isInHisui =
            hisuiDexAsync?.asData?.value.contains(pokemon.name) ?? false;
        final canAlpha = alphaFormatOk && isInHisui;

        final scrollBody = SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(slot, spriteUrls, mechanics,
                  megaArtworkUrl: effectiveMegaArtworkUrl,
                  megaFallbackUrl: effectiveMegaFallbackUrl,
                  genderBaseUrl: genderBaseUrl,
                  genderBaseFallback: genderBaseFallback,
                  isFormLoading: formPokemonAsync?.isLoading ?? false),
              // ── Form selector (when Pokémon has multiple forms) ──
              if (hasMultipleForms) ...[
                const SizedBox(height: 16),
                _buildFormSelector(availableForms),
              ],
              const SizedBox(height: 24),
              _buildBasics(mechanics),
              // ── Ability (Gen 3+) ──
              if (mechanics == null || mechanics.hasAbilities) ...[
                const SizedBox(height: 24),
                _SectionTitle('Ability'),
                const SizedBox(height: 8),
                _buildAbility(effectiveAbilities, effectiveViolations['ability']),
                // Mega form ability shown as read-only info when evolved.
                if (canMegaEvolve && _isMegaEvolved && megaPokemon != null &&
                    megaPokemon.abilities.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildMegaAbilityInfo(megaPokemon.abilities),
                ],
              ],
              // ── Nature (Gen 3+) ──
              if (mechanics == null || mechanics.hasAbilities) ...[
                const SizedBox(height: 24),
                _SectionTitle('Nature'),
                const SizedBox(height: 8),
                _buildNature(),
              ],
              // ── Held item (Gen 2+) ──
              if (mechanics == null || mechanics.hasItems) ...[
                const SizedBox(height: 24),
                _SectionTitle('Held Item'),
                const SizedBox(height: 8),
                _buildHeldItem(violation: effectiveViolations['item']),
              ],
              // ── Mega Evolution toggle (Gen 6–7, when applicable) ──
              if (canMegaEvolve) ...[
                const SizedBox(height: 16),
                _buildMegaToggle(megaEntry, megaPokemon,
                    loading: megaPokemonAsync?.isLoading ?? false),
              ],
              // ── Gigantamax (Gen 8) ──
              if (canDynamax) ...[
                if (canGigantamax) ...[
                  const SizedBox(height: 12),
                  _buildGigantamaxToggle(
                      gmaxMove: gmaxMove,
                      gmaxPokemon: gmaxPokemon,
                      loading: gmaxPokemonAsync?.isLoading ?? false),
                ],
              ],
              // ── Alpha Pokémon (Legends: Arceus) ──
              if (canAlpha) ...[
                const SizedBox(height: 12),
                _buildAlphaToggle(),
              ],
              const SizedBox(height: 24),
              _SectionTitle('Moves'),
              const SizedBox(height: 8),
              _buildMoves(effectiveLearnableMoves,
                  violations: effectiveViolations,
                  pokemonName: formPokemon?.name ?? pokemon.name,
                  showMaxMoves: canDynamax,
                  useGMax: canGigantamax && _hasGigantamax && _gigantamaxEnabled),
              const SizedBox(height: 24),
              // ── EVs / Stat Exp. ──
              _SectionTitle(
                mechanics?.statMode == StatValueMode.dvs
                    ? 'Stat Experience'
                    : 'Effort Values (EVs)',
              ),
              if (mechanics?.statMode != StatValueMode.dvs) ...[
                const SizedBox(height: 4),
                _buildEvTotal(),
              ],
              const SizedBox(height: 8),
              _buildStatGrid(
                _evCtrls,
                maxVal: 252,
                gen1Mode: format?.gen == 1,
              ),
              const SizedBox(height: 24),
              // ── IVs / DVs ──
              _SectionTitle(
                mechanics?.statMode == StatValueMode.dvs
                    ? 'Determinant Values (DVs)  max ${mechanics!.statMax}'
                    : 'Individual Values (IVs)',
              ),
              const SizedBox(height: 8),
              _buildStatGrid(
                _ivCtrls,
                maxVal: mechanics?.statMax ?? 31,
                gen1Mode: format?.gen == 1,
              ),
              // ── Hidden Power (Gen 2–7 only) ──
              if (mechanics == null || mechanics.hasHiddenPower) ...[
                const SizedBox(height: 12),
                _buildHiddenPower(gen: format?.gen),
              ],
              const SizedBox(height: 24),
              _SectionTitle('Stat Preview (Lv $_level)'),
              const SizedBox(height: 8),
              _buildStatPreview(finalBaseStats, mechanics),
              // ── Contest conditions (Gen 3 / Gen 4 / no format) ──
              if (mechanics == null || mechanics.gen == 3 || mechanics.gen == 4) ...[
                const SizedBox(height: 24),
                _SectionTitle('Contest Conditions'),
                const SizedBox(height: 8),
                _buildContestStats(),
              ],
              // ── Ribbons ──
              const SizedBox(height: 24),
              _SectionTitle('Ribbons'),
              const SizedBox(height: 8),
              _buildRibbons(),
              // ── Pokémon Instance ──
              const SizedBox(height: 24),
              _SectionTitle('Pokémon Identity'),
              const SizedBox(height: 8),
              _buildInstanceSection(slot),
            ],
          ),
        );

        if (widget.embedded) {
          return Column(
            children: [
              // ── Panel header ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Slot ${widget.slotNumber} — $speciesName',
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FavoriteButton(pokemonId: slot.pokemonId, iconSize: 20),
                    if (_saving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: () => _save(slot),
                        child: const Text('Save'),
                      ),
                    if (widget.onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: widget.onClose,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: scrollBody),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Slot ${widget.slotNumber} — $speciesName'),
            actions: [
              FavoriteButton(pokemonId: slot.pokemonId),
              const ConnectivityStatusButton(),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                TextButton(
                  onPressed: () => _save(slot),
                  child: const Text('Save'),
                ),
            ],
          ),
          body: scrollBody,
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    TeamSlot slot,
    ({String? defaultUrl, String? shinyUrl}) spriteUrls,
    GenerationMechanics? mechanics, {
    String? megaArtworkUrl,
    String? megaFallbackUrl,
    // Gender-specific base sprite (female HOME url when slot is female).
    String? genderBaseUrl,
    String? genderBaseFallback,
    bool isFormLoading = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            PokemonSprite(
              // Priority: form/mega/gmax override > female base > default sprite.
              defaultUrl: megaArtworkUrl ??
                  genderBaseUrl ??
                  spriteUrls.defaultUrl,
              fallbackUrl: megaArtworkUrl != null
                  ? megaFallbackUrl
                  : genderBaseUrl != null
                      ? genderBaseFallback
                      : null,
              shinyUrl: (megaArtworkUrl == null && genderBaseUrl == null)
                  ? spriteUrls.shinyUrl
                  : null,
              shiny: megaArtworkUrl == null &&
                  genderBaseUrl == null &&
                  _isShiny,
              size: 140,
            ),
            // Loading overlay while form sprite is fetching
            if (isFormLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (mechanics == null || mechanics.hasShiny)
            GestureDetector(
              onTap: () => setState(() => _isShiny = !_isShiny),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _isShiny ? Colors.amber : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Icon(Icons.auto_awesome, size: 16,
                    color: _isShiny ? Colors.white : colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nickname',
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              TextField(
                controller: _nicknameCtrl,
                decoration: const InputDecoration(
                  hintText: 'Optional (max 12 chars)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(12)],
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Basics ────────────────────────────────────────────────────────────────

  Widget _buildBasics(GenerationMechanics? mechanics) {
    // Friendship exists from Gen 2 onward; Gen 1 has no friendship mechanic.
    final showFriendship = mechanics == null || mechanics.gen >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Basics'),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 72,
              child: Text('Level $_level',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Slider(
                value: _level.toDouble(),
                min: 1, max: 100, divisions: 99,
                label: '$_level',
                onChanged: (v) => setState(() => _level = v.round()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final g in [('male', '♂ Male'), ('female', '♀ Female'), ('genderless', '⚲ None')])
              ChoiceChip(
                label: Text(g.$2),
                selected: _gender == g.$1,
                onSelected: (_) =>
                    setState(() => _gender = _gender == g.$1 ? null : g.$1),
              ),
          ],
        ),
        if (showFriendship) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text('Friendly\n$_friendship',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              Expanded(
                child: Slider(
                  value: _friendship.toDouble(),
                  min: 0, max: 255, divisions: 255,
                  label: '$_friendship',
                  onChanged: (v) => setState(() => _friendship = v.round()),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Ability — selectable cards with descriptions ───────────────────────────

  Widget _buildAbility(
    List<({String name, bool isHidden, int abilitySlot})> abilities,
    String? violation,
  ) {
    if (abilities.isEmpty) return const Text('No abilities available');

    final cards = Column(
      children: abilities.map((a) {
        final detailAsync = ref.watch(_abilityDetailProvider(a.name));
        final isSelected = _abilityName == a.name;
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        final description = detailAsync.whenOrNull(
          data: (entry) => entry.shortEffect,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => _abilityName = isSelected ? null : a.name),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(a.name.toCapitalCase(),
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            if (a.isHidden) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Hidden',
                                    style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onTertiaryContainer)),
                              ),
                            ],
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => context.push(
                                  '/reference/abilities/${a.name}'),
                              child: Icon(Icons.info_outline,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 3),
                          Text(description,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ] else if (detailAsync.isLoading) ...[
                          const SizedBox(height: 6),
                          const SizedBox(
                            height: 8,
                            width: 80,
                            child: LinearProgressIndicator(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cards,
        _buildViolationBanner(violation),
      ],
    );
  }

  // violation banner shown below the whole ability section
  Widget _buildViolationBanner(String? violation) {
    if (violation == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              violation,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Nature ────────────────────────────────────────────────────────────────

  Widget _buildNature() {
    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButton<String>(
        value: _natureName,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: const Text('Select nature'),
        items: _kNatures.map((n) {
          final label = n.isNeutral
              ? '${n.name} (neutral)'
              : '${n.name}  +${n.increased!} / −${n.decreased!}';
          return DropdownMenuItem(
            value: n.name,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          );
        }).toList(),
        onChanged: (v) => setState(() => _natureName = v),
      ),
    );
  }

  // ── Held item — picker + description ──────────────────────────────────────

  Widget _buildHeldItem({String? violation}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String? description;
    if (_heldItemName != null) {
      final detailAsync = ref.watch(_itemDetailProvider(_heldItemName!));
      description = detailAsync.whenOrNull(data: (e) => e.shortEffect);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickItem,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _heldItemName
                            ?.replaceAll(RegExp(r'-(held|bag)$'), '')
                            .replaceAll(RegExp(r'-+$'), '')
                            .toCapitalCase() ??
                        '— None —',
                    style: textTheme.bodyMedium,
                  ),
                ),
                if (_heldItemName != null) ...[
                  IconButton(
                    tooltip: 'View item details',
                    icon: Icon(Icons.info_outline,
                        size: 18,
                        color: colorScheme.onSurfaceVariant),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => context.push('/items/$_heldItemName'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Remove item',
                    icon: const Icon(Icons.clear, size: 18),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _heldItemName = null),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(description,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
        _buildViolationBanner(violation),
      ],
    );
  }

  // ── Moves — picker + description per selected move ────────────────────────

  Widget _buildMoves(
    List<String> learnableMoves, {
    Map<String, String> violations = const {},
    String pokemonName = '',
    bool showMaxMoves = false,
    bool useGMax = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: List.generate(4, (i) {
        MoveEntry? moveDetail;
        if (_moves[i] != null) {
          final detailAsync = ref.watch(_moveDetailProvider(_moves[i]!));
          moveDetail = detailAsync.whenOrNull(data: (e) => e);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tap target row
              InkWell(
                onTap: () => _pickMove(i, learnableMoves),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text('${i + 1}',
                            style: TextStyle(fontSize: 11,
                                color: colorScheme.onPrimaryContainer)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _moves[i]?.toCapitalCase() ?? '— None —',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      // Inline type + special-move chip + stats when selected
                      if (moveDetail != null) ...[
                        if (moveDetail.typeName != null)
                          TypeBadge(type: moveDetail.typeName!),
                        Builder(builder: (ctx) {
                          final svc = ref.read(formatServiceProvider);
                          final special = classifyMoveType(svc, moveDetail!.name);
                          if (special == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: MoveTypeChip(type: special),
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          [
                            if (moveDetail.power != null) 'Pow ${moveDetail.power}',
                            if (moveDetail.accuracy != null) '${moveDetail.accuracy}%',
                            if (moveDetail.pp != null) 'PP ${moveDetail.pp}',
                          ].join('  '),
                          style: textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (_moves[i] != null) ...[
                        IconButton(
                          tooltip: 'View move details',
                          icon: Icon(Icons.info_outline,
                              size: 18,
                              color: colorScheme.onSurfaceVariant),
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => context.push('/moves/${_moves[i]}'),
                        ),
                        const SizedBox(width: 2),
                      ],
                      if (_moves[i] != null)
                        IconButton(
                          tooltip: 'Remove move',
                          icon: const Icon(Icons.clear, size: 18),
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _moves[i] = null),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              // Short effect description
              if (moveDetail?.shortEffect != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(moveDetail!.shortEffect!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ),
              // Z-Move info — Gen 7 / no-format; shown when Z-crystal held and move qualifies
              if (_moves[i] != null && _heldItemName != null) ...[
                Builder(builder: (ctx) {
                  final zMove = resolveZMove(
                    itemId: _heldItemName!,
                    moveId: _moves[i]!,
                    pokemonName: pokemonName,
                    moveType: moveDetail?.typeName,
                  );
                  if (zMove == null) return const SizedBox.shrink();
                  final zDisplay = zMove
                      .split('-')
                      .map((w) => w.isEmpty
                          ? ''
                          : '${w[0].toUpperCase()}${w.substring(1)}')
                      .join(' ');
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => context.push('/moves/$zMove'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B2FBE)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF7B2FBE)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Text('💠',
                                style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            Text(
                              'Z-Move: $zDisplay',
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF9B4FDE),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.info_outline,
                                size: 14,
                                color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              // Max Move / G-Max Move — shown when Dynamax/Gigantamax is available
              if (showMaxMoves && _moves[i] != null) ...[
                Builder(builder: (ctx) {
                  final maxMove = resolveMaxMove(
                    moveType: moveDetail?.typeName,
                    moveCategory: moveDetail?.damageClass,
                    speciesName: pokemonName,
                    useGMax: useGMax,
                  );
                  if (maxMove == null) return const SizedBox.shrink();
                  final isGMax = maxMove.startsWith('g-max-');
                  final displayName = maxMove
                      .split('-')
                      .map((w) => w.isEmpty
                          ? ''
                          : '${w[0].toUpperCase()}${w.substring(1)}')
                      .join(' ');
                  final color = isGMax
                      ? const Color(0xFFF9A825)   // G-Max: amber
                      : const Color(0xFFB71C1C);  // Max: crimson
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => context.push('/moves/$maxMove'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: color.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Text(isGMax ? '🌟' : '💢',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            Text(
                              '${isGMax ? "G-Max" : "Max"}: $displayName',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const Spacer(),
                            Icon(Icons.info_outline,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              // Violation banner
              _buildViolationBanner(violations['move${i + 1}']),
            ],
          ),
        );
      }),
    );
  }

  // ── EV total ──────────────────────────────────────────────────────────────

  Widget _buildEvTotal() {
    final total = _evTotal;
    final over = total > 510;
    return Row(
      children: [
        Text('Total: $total / 510',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: over
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: over ? FontWeight.bold : FontWeight.normal,
                )),
        if (over) ...[
          const SizedBox(width: 6),
          Icon(Icons.warning_amber, size: 16,
              color: Theme.of(context).colorScheme.error),
        ],
      ],
    );
  }

  // ── Hidden Power ─────────────────────────────────────────────────────────

  /// Type names for the 16 possible Hidden Power types (indices 0–15).
  static const _hpTypeNames = [
    'Fighting', 'Flying', 'Poison', 'Ground', 'Rock', 'Bug',
    'Ghost',    'Steel',  'Fire',   'Water',  'Grass', 'Electric',
    'Psychic',  'Ice',    'Dragon', 'Dark',
  ];

  /// Returns 0–15 index of the Hidden Power type from current IVs.
  /// Uses the standard Gen 3+ formula.
  int _hiddenPowerTypeIndex() {
    final iv = _ivCtrls.map((c) => int.tryParse(c.text) ?? 31).toList();
    // Bit order: HP, Atk, Def, Spe, SpA, SpD (note Spe=index 5, SpA=index 3, SpD=index 4)
    final n = (iv[0] & 1) +
        (iv[1] & 1) * 2 +
        (iv[2] & 1) * 4 +
        (iv[5] & 1) * 8 +
        (iv[3] & 1) * 16 +
        (iv[4] & 1) * 32;
    return (n * 15) ~/ 63;
  }

  /// Returns the power of Hidden Power (30–70 in Gen 2–5; always 60 in Gen 6+).
  int _hiddenPowerPower({int? gen}) {
    if (gen != null && gen >= 6) return 60;
    final iv = _ivCtrls.map((c) => int.tryParse(c.text) ?? 31).toList();
    final u = ((iv[0] >> 1) & 1) +
        ((iv[1] >> 1) & 1) * 2 +
        ((iv[2] >> 1) & 1) * 4 +
        ((iv[5] >> 1) & 1) * 8 +
        ((iv[3] >> 1) & 1) * 16 +
        ((iv[4] >> 1) & 1) * 32;
    return (u * 40) ~/ 63 + 30;
  }

  Widget _buildHiddenPower({int? gen}) {
    final typeIdx = _hiddenPowerTypeIndex();
    final typeName = _hpTypeNames[typeIdx].toLowerCase();
    final power = _hiddenPowerPower(gen: gen);
    final typeColor = PokemonTypeColors.colors[typeName] ??
        Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Text('Hidden Power:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: typeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _hpTypeNames[typeIdx],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Power $power',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (gen == null || gen < 6)
          Text(
            '  (Gen 6+: 60)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
          ),
      ],
    );
  }

  // ── EV / IV grid ──────────────────────────────────────────────────────────

  // Gen 1: 5 stats — HP, Atk, Def, Spc (combined Special), Spe (no SpD).
  static const _gen1StatLabels  = ['HP', 'Atk', 'Def', 'Spc', 'Spe'];
  static const _gen1StatIndices = [0, 1, 2, 3, 5]; // skip SpD (controller index 4)

  Widget _buildStatGrid(
    List<TextEditingController> ctrls, {
    required int maxVal,
    bool gen1Mode = false,
  }) {
    final labels  = gen1Mode ? _gen1StatLabels  : _statLabels;
    final indices = gen1Mode ? _gen1StatIndices : List.generate(6, (i) => i);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8, mainAxisSpacing: 8,
        childAspectRatio: 2.4,
      ),
      itemCount: indices.length,
      itemBuilder: (_, i) {
        final ctrlIdx = indices[i];
        return TextField(
          controller: ctrls[ctrlIdx],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: labels[i],
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          onChanged: (_) => setState(() {}),
        );
      },
    );
  }

  // ── Stat preview ──────────────────────────────────────────────────────────

  Widget _buildStatPreview(Map<String, int> baseStats, GenerationMechanics? mechanics) {
    if (baseStats.isEmpty) return const SizedBox.shrink();
    final maxIv = mechanics?.statMax ?? 31;
    final evs = _evCtrls.map((c) => (int.tryParse(c.text) ?? 0).clamp(0, 252)).toList();
    final ivs = _ivCtrls
        .map((c) => (int.tryParse(c.text) ?? maxIv).clamp(0, maxIv))
        .toList();
    // Gen 1: nature modifiers don't apply
    final useNature = mechanics == null || mechanics.hasAbilities;

    return Column(
      children: [
        for (int i = 0; i < _statKeys.length; i++)
          StatBar(
            label: _statLabels[i],
            value: _statKeys[i] == 'hp'
                ? _calcHP(baseStats['hp'] ?? 0, ivs[0], evs[0], _level)
                : _calcStat(
                    baseStats[_statKeys[i]] ?? 0, ivs[i], evs[i], _level,
                    useNature ? _natureMod(_natureName, _statKeys[i]) : 1.0),
            maxValue: 700,
          ),
      ],
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickItem() async {
    // PokéAPI has both -held and -bag variants for some items (e.g. Z-crystals).
    // -bag variants are true duplicates with no gameplay difference — exclude them.
    // -held variants are kept (some items only exist in held form); the display
    // strips "-held" so users see "Incinium Z" not "Incinium Z Held".
    final items = (ref.read(_itemListProvider).asData?.value ?? [])
        .where((n) => !n.endsWith('-bag'))
        .toList();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemPickerSheet(items: items, current: _heldItemName),
    );
    // Normalise stored value: strip -held/-bag and any trailing hyphen.
    // e.g. "incinium-z-held" → strips "-held" → "incinium-z"
    //      "incinium-z-"    → strips trailing "-" → "incinium-z"
    if (result != null) {
      setState(() => _heldItemName = result
          .replaceAll(RegExp(r'-(held|bag)$'), '')
          .replaceAll(RegExp(r'-+$'), ''));
    }
  }

  Future<void> _pickMove(int moveIndex, List<String> learnableMoves) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MovePickerSheet(
        moves: learnableMoves,
        current: _moves[moveIndex],
        label: 'Move ${moveIndex + 1}',
      ),
    );
    if (result != null) setState(() => _moves[moveIndex] = result);
  }

  // ── Form selector ─────────────────────────────────────────────────────────

  Widget _buildFormSelector(List<String> forms) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String fmtForm(String name) => name
        .split('-')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    final isDefault = _formName == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Form', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            // Default form chip
            ChoiceChip(
              label: const Text('Default'),
              selected: isDefault,
              onSelected: (_) => setState(() => _formName = null),
              selectedColor: colorScheme.primaryContainer,
              labelStyle: textTheme.labelSmall?.copyWith(
                fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // Non-default form chips (already filtered)
            ...forms.map((form) {
              final selected = _formName == form;
              return ChoiceChip(
                label: Text(fmtForm(form)),
                selected: selected,
                onSelected: (_) => setState(() => _formName = form),
                selectedColor: colorScheme.primaryContainer,
                labelStyle: textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── Mega ability info row ─────────────────────────────────────────────────

  Widget _buildMegaAbilityInfo(List<dynamic> megaAbilities) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final abilityName = (megaAbilities.first['ability'] as Map)['name'] as String;
    final displayName = abilityName
        .split('-')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/reference/abilities/$abilityName'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 14, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Mega form ability: ',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            Expanded(
              child: Text(
                displayName,
                style: textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.info_outline,
                size: 14, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── Mega Evolution ────────────────────────────────────────────────────────

  Widget _buildMegaToggle(
    MegaFormEntry entry,
    dynamic megaPokemon,    // PokemonEntry? — typed as dynamic to avoid import
    {required bool loading}
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isMegaEvolved
            ? colorScheme.primaryContainer.withValues(alpha: 0.4)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isMegaEvolved
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 18,
            color: _isMegaEvolved ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mega Evolution',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isMegaEvolved ? colorScheme.primary : null,
                  ),
                ),
                Text(
                  entry.megaForm.split('-').map((w) =>
                      w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
                      .join(' '),
                  style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: _isMegaEvolved,
              onChanged: (v) => setState(() => _isMegaEvolved = v),
            ),
        ],
      ),
    );
  }

  // ── Gigantamax toggle ─────────────────────────────────────────────────────

  Widget _buildGigantamaxToggle({
    required String gmaxMove,
    required dynamic gmaxPokemon,
    required bool loading,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const gmaxColor = Color(0xFFB71C1C);

    final gmaxDisplay = gmaxMove
        .split('-')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return Column(
      children: [
        // Has Gigantamax Factor toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hasGigantamax
                ? gmaxColor.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _hasGigantamax
                    ? gmaxColor.withValues(alpha: 0.4)
                    : colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              const Text('💢', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gigantamax Factor',
                        style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _hasGigantamax ? gmaxColor : null)),
                    Text('G-Max Move: $gmaxDisplay',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Switch(
                value: _hasGigantamax,
                onChanged: (v) => setState(() {
                  _hasGigantamax = v;
                  if (!v) _gigantamaxEnabled = false;
                }),
              ),
            ],
          ),
        ),
        // Gigantamax enabled toggle (only when has Gigantamax Factor)
        if (_hasGigantamax) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _gigantamaxEnabled
                  ? const Color(0xFFF9A825).withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _gigantamaxEnabled
                      ? const Color(0xFFF9A825).withValues(alpha: 0.5)
                      : colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                const Text('🌟', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gigantamax',
                          style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _gigantamaxEnabled
                                  ? const Color(0xFFF9A825)
                                  : null)),
                      Text(
                          loading ? 'Loading form…' : 'Show G-Max sprite and G-Max Moves',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Switch(
                    value: _gigantamaxEnabled,
                    onChanged: (v) => setState(() => _gigantamaxEnabled = v),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Alpha toggle ──────────────────────────────────────────────────────────

  Widget _buildAlphaToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const alphaColor = Color(0xFF1565C0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isAlpha
            ? alphaColor.withValues(alpha: 0.1)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _isAlpha
                ? alphaColor.withValues(alpha: 0.4)
                : colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.brightness_high_rounded,
              size: 20,
              color: _isAlpha ? alphaColor : colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alpha Pokémon',
                    style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _isAlpha ? alphaColor : null)),
                Text('Legends: Arceus — extra-large, more aggressive',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: _isAlpha,
            onChanged: (v) => setState(() => _isAlpha = v),
          ),
        ],
      ),
    );
  }

  // ── Ribbons ───────────────────────────────────────────────────────────────

  // ── Pokémon Instance ──────────────────────────────────────────────────────

  /// Called when the user picks a slot to link to from the picker sheet.
  /// Creates instance records immediately so the chain view can render.
  Future<void> _onLinkSelected(TeamSlot targetSlot) async {
    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);

    // 1. Ensure the target slot has an instance (create origin if needed).
    int parentInstanceId;
    if (targetSlot.instanceId != null) {
      parentInstanceId = targetSlot.instanceId!;
    } else {
      // Create an origin instance for the target slot.
      parentInstanceId = await instanceRepo.createOrigin(
        pokemonId: targetSlot.pokemonId,
        nickname: targetSlot.nickname,
      );
      // Link the target slot to its new origin instance right away.
      await slotRepo.update(
        TeamSlotsCompanion(
          id: Value(targetSlot.id),
          teamId: Value(targetSlot.teamId),
          slot: Value(targetSlot.slot),
          pokemonId: Value(targetSlot.pokemonId),
          instanceId: Value(parentInstanceId),
          syncStatus: const Value('pending'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    // 2. Create an iteration instance for the current slot.
    final newInstanceId = await instanceRepo.createIteration(
      pokemonId: targetSlot.pokemonId,
      parentInstanceId: parentInstanceId,
      newNickname: _nicknameCtrl.text.trim().isEmpty
          ? null
          : _nicknameCtrl.text.trim(),
    );

    setState(() => _instanceId = newInstanceId);
  }

  /// Unlinks this slot from its instance without deleting the instance itself
  /// (other slots in the chain are unaffected).
  void _unlink() => setState(() => _instanceId = null);

  Widget _buildInstanceSection(TeamSlot slot) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Track this Pokémon\'s journey across teams. '
          'Linking records nickname history and ribbon inheritance.',
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        if (_instanceId != null) ...[
          // ── Linked state ──
          InstanceChainView(
            instanceId: _instanceId!,
            currentSlotId: slot.id,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.link_off_rounded, size: 16),
                label: const Text('Unlink'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _unlink,
              ),
            ],
          ),
        ] else ...[
          // ── Unlinked state ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.link_off_rounded,
                    size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Not linked to a Pokémon identity',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Link to another team\'s Pokémon'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => InstancePickerSheet(
                pokemonId: slot.pokemonId,
                currentSlotId: slot.id,
                onPick: (targetSlot) {
                  Navigator.of(context).pop();
                  _onLinkSelected(targetSlot);
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRibbons() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_ribbons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_ribbons.length} ribbon${_ribbons.length == 1 ? '' : 's'} awarded',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        for (final category in kRibbonCatalog) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 8),
            child: Text(
              category.name,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: category.ribbons.map((r) {
              final selected = _ribbons.contains(r.id);
              return FilterChip(
                avatar: r.spriteUrl != null
                    ? CachedNetworkImage(
                        imageUrl: r.spriteUrl!,
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.workspace_premium_rounded,
                          size: 16,
                        ),
                      )
                    : const Icon(Icons.workspace_premium_rounded, size: 16),
                label: Text(r.name),
                selected: selected,
                visualDensity: VisualDensity.compact,
                labelStyle: textTheme.labelSmall?.copyWith(
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (on) => setState(
                    () => on ? _ribbons.add(r.id) : _ribbons.remove(r.id)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ── Contest conditions ──────────────────────────────────────────────────────

  static const _contestLabels = [
    'Cool', 'Beautiful', 'Cute', 'Clever', 'Tough', 'Sheen',
  ];
  static const _contestColors = [
    Color(0xFFE53935), // Cool — red
    Color(0xFF1E88E5), // Beautiful — blue
    Color(0xFFE91E63), // Cute — pink
    Color(0xFF43A047), // Clever — green
    Color(0xFFF9A825), // Tough — amber/yellow (Bulbapedia)
    Color(0xFF9E9E9E), // Sheen — grey
  ];

  Widget _buildContestStats() {
    final vals = _contestCtrls
        .map((c) => (int.tryParse(c.text) ?? 0).clamp(0, 255))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Radar chart — always visible; colored dots mark each stat's value.
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AspectRatio(
            aspectRatio: 2.4,
            child: Stack(
              children: [
                RadarChart(
                  RadarChartData(
                    dataSets: [
                      RadarDataSet(
                        dataEntries: vals
                            .take(5)
                            .map((v) => RadarEntry(value: v.toDouble()))
                            .toList(),
                        borderColor: Theme.of(context).colorScheme.primary,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                        borderWidth: 2,
                        entryRadius: 0, // dots handled by overlay
                      ),
                    ],
                    radarBackgroundColor: Colors.transparent,
                    radarShape: RadarShape.polygon,
                    tickCount: 4,
                    ticksTextStyle: const TextStyle(fontSize: 0),
                    tickBorderData: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant),
                    gridBorderData: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant),
                    radarBorderData: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant),
                    getTitle: (index, angle) => RadarChartTitle(
                      text: _contestLabels[index],
                      positionPercentageOffset: 0.1,
                    ),
                  ),
                ),
                // Colored vertex dots overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RadarDotsPainter(
                      values: vals.take(5).toList(),
                      colors: _contestColors.take(5).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Sliders for all 6 stats
        for (int i = 0; i < 6; i++) ...[
          _ContestStatRow(
            label: _contestLabels[i],
            color: _contestColors[i],
            ctrl: _contestCtrls[i],
            onChanged: () => setState(() {}),
          ),
          if (i < 5) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Contest stat row ──────────────────────────────────────────────────────────

class _ContestStatRow extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController ctrl;
  final VoidCallback onChanged;

  const _ContestStatRow({
    required this.label,
    required this.color,
    required this.ctrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = (int.tryParse(ctrl.text) ?? 0).clamp(0, 255);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              overlayColor: color.withValues(alpha: 0.1),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: (v) {
                ctrl.text = v.round().toString();
                onChanged();
              },
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Radar dots painter ────────────────────────────────────────────────────────

/// Overlays colour-coded dots at each pentagon vertex proportional to the
/// stat value.  fl_chart's RadarChart leaves ~22% of each side as label
/// padding, so the inner circle radius ≈ shortestSide * 0.39.
class _RadarDotsPainter extends CustomPainter {
  final List<int> values;  // 5 values (0–255)
  final List<Color> colors; // 5 colors

  const _RadarDotsPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final innerRadius = size.shortestSide * 0.39;

    for (int i = 0; i < 5; i++) {
      final v = values[i];
      if (v == 0) continue;
      // Vertex 0 starts at the top (−π/2) and goes clockwise.
      final angle = -math.pi / 2 + 2 * math.pi * i / 5;
      final r = innerRadius * v / 255;
      final pos = Offset(center.dx + r * math.cos(angle),
                         center.dy + r * math.sin(angle));

      canvas.drawCircle(pos, 5,
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.fill);
      canvas.drawCircle(pos, 5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_RadarDotsPainter old) =>
      !_listEq(old.values, values);

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

// ── Move picker sheet ─────────────────────────────────────────────────────────
//
// ConsumerStatefulWidget so each list tile can watch _moveDetailProvider.

class _MovePickerSheet extends ConsumerStatefulWidget {
  final List<String> moves;
  final String? current;
  final String label;

  const _MovePickerSheet({
    required this.moves,
    required this.label,
    this.current,
  });

  @override
  ConsumerState<_MovePickerSheet> createState() => _MovePickerSheetState();
}

class _MovePickerSheetState extends ConsumerState<_MovePickerSheet> {
  late List<String> _filtered;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.moves;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.moves
          : widget.moves.where((s) => s.contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(widget.label,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search moves…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () { _ctrl.clear(); _filter(''); },
                      )
                    : null,
              ),
              onChanged: _filter,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemExtent: 64,
              itemBuilder: (_, i) => _MoveListTile(
                moveName: _filtered[i],
                isSelected: _filtered[i] == widget.current,
                onTap: () => Navigator.pop(context, _filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Each row watches its own move detail provider — loads lazily as scrolled.
class _MoveListTile extends ConsumerWidget {
  final String moveName;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoveListTile({
    required this.moveName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_moveDetailProvider(moveName));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      selected: isSelected,
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(moveName.toCapitalCase(),
                style: textTheme.bodyMedium
                    ?.copyWith(fontWeight: isSelected ? FontWeight.bold : null)),
          ),
          detailAsync.when(
            loading: () => const SizedBox(width: 60,
                child: LinearProgressIndicator(minHeight: 2)),
            error: (_, __) => const SizedBox.shrink(),
            data: (move) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (move.typeName != null) TypeBadge(type: move.typeName!),
                const SizedBox(width: 6),
                Text(
                  [
                    if (move.power != null) '${move.power}',
                    if (move.accuracy != null) '${move.accuracy}%',
                    if (move.pp != null) 'PP${move.pp}',
                  ].join(' · '),
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.check, size: 16),
            ),
        ],
      ),
      subtitle: detailAsync.whenOrNull(
        data: (move) => move.shortEffect != null
            ? Text(move.shortEffect!,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)
            : null,
      ),
    );
  }
}

// ── Item picker sheet ─────────────────────────────────────────────────────────

class _ItemPickerSheet extends ConsumerStatefulWidget {
  final List<String> items;
  final String? current;

  const _ItemPickerSheet({required this.items, this.current});

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  late List<String> _filtered;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items.where((s) => s.contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text('Held Item',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search items…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () { _ctrl.clear(); _filter(''); },
                      )
                    : null,
              ),
              onChanged: _filter,
            ),
          ),
          const Divider(height: 1),
          if (widget.items.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _filtered.length,
                itemExtent: 64,
                itemBuilder: (_, i) => _ItemListTile(
                  itemName: _filtered[i],
                  isSelected: _filtered[i] == widget.current,
                  onTap: () => Navigator.pop(context, _filtered[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemListTile extends ConsumerWidget {
  final String itemName;
  final bool isSelected;
  final VoidCallback onTap;

  const _ItemListTile({
    required this.itemName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_itemDetailProvider(itemName));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final entry = detailAsync.whenOrNull(data: (e) => e);
    final spriteUrl = entry?.spriteUrl;
    // Z-crystals have a placeholder shortEffect ("XXX new effect for …").
    // Use flavor text for them; keep shortEffect for everything else.
    final normalizedItemName = itemName
        .replaceAll(RegExp(r'-(held|bag)$'), '')
        .replaceAll(RegExp(r'-+$'), '');
    final isZCrystal = normalizedItemName.endsWith('-z');
    final description = entry == null
        ? null
        : (isZCrystal && entry.flavorTextEntries.isNotEmpty)
            ? entry.flavorTextEntries.last.text
            : entry.shortEffect;

    return ListTile(
      dense: true,
      selected: isSelected,
      onTap: onTap,
      leading: SizedBox(
        width: 32,
        height: 32,
        child: spriteUrl != null
            ? CachedNetworkImage(
                imageUrl: spriteUrl,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Icon(Icons.inventory_2_outlined, size: 20),
              )
            : const Icon(Icons.inventory_2_outlined, size: 20,
                color: Colors.transparent),
      ),
      title: Text(
          // Strip -held/-bag and trailing hyphens so "incinium-z-held" → "Incinium Z"
          itemName
              .replaceAll(RegExp(r'-(held|bag)$'), '')
              .replaceAll(RegExp(r'-+$'), '')
              .toCapitalCase(),
          style: textTheme.bodyMedium
              ?.copyWith(fontWeight: isSelected ? FontWeight.bold : null)),
      subtitle: description != null
          ? Text(description,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: isSelected ? const Icon(Icons.check, size: 16) : null,
    );
  }
}
