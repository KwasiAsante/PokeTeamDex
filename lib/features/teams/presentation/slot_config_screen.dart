import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:change_case/change_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart'
    show teamByIdProvider, teamSlotsProvider;
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_providers.dart';
import 'package:poke_team_dex/services/format/format_service.dart';
import 'package:poke_team_dex/services/format/slot_validator.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart'
    show MoveSummary, VarietyBackendData;
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart'
    show pokemonFormsProvider, pokemonMovesProvider, pokemonVarietiesProvider;
import 'package:poke_team_dex/services/pokeapi/models/type_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:poke_team_dex/features/teams/data/dynamax_data.dart';
import 'package:poke_team_dex/features/teams/data/form_filter.dart';
import 'package:poke_team_dex/features/teams/data/z_moves_data.dart';
import 'package:poke_team_dex/features/teams/data/ribbon_catalog.dart';
import 'package:poke_team_dex/features/teams/presentation/instance_chain_view.dart';
import 'package:poke_team_dex/features/teams/presentation/instance_picker_sheet.dart';
import 'package:poke_team_dex/features/teams/services/ps_export_service.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';
import 'package:poke_team_dex/shared/utils/snack_bar.dart';
import 'package:poke_team_dex/shared/utils/stat_calculator.dart' as stat;
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

// ── Providers ─────────────────────────────────────────────────────────────────


/// Set of species names (PokéAPI format) catchable in Legends: Arceus.
/// Fetched once, cached in Hive by the repository layer.
final _hisuiDexProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final dex =
      await ref.read(pokeApiRepositoryProvider).fetchRegionalPokedex('hisui');
  return dex.keys.toSet();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SlotConfigScreen extends ConsumerStatefulWidget {
  final int teamId;
  final int slotNumber;
  final bool embedded;
  final VoidCallback? onClose;
  /// When set by the parent, the slot config registers a [Future<bool>]
  /// callback that the parent can invoke to ask "is it safe to close?".
  /// The callback shows the unsaved-changes dialog if dirty and returns
  /// true when the parent may proceed (saved or discarded) or false if
  /// the user cancelled.
  final ValueNotifier<Future<bool> Function()?>? canCloseNotifier;

  const SlotConfigScreen({
    super.key,
    required this.teamId,
    required this.slotNumber,
    this.embedded = false,
    this.onClose,
    this.canCloseNotifier,
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
  int? _originalInstanceId;

  // Data inherited from the instance chain
  Set<String> _inheritedRibbons = {};
  List<String> _nicknameAliases = [];
  // Nickname at load time — used to record an alias when it changes on save.
  String _originalNickname = '';

  // Mega Evolution toggle
  bool _isMegaEvolved = false;

  // Gigantamax (Gen 8)
  bool _hasGigantamax = false;
  bool _gigantamaxEnabled = false;

  // Alpha Pokémon (Legends: Arceus)
  bool _isAlpha = false;

  // Tera Type (Gen 9 / No Format)
  String? _teraType;

  bool _initialized = false;
  bool _saving = false;
  bool _dirty = false;
  TeamSlot? _currentSlot;

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
    widget.canCloseNotifier?.value = _canClose;
  }

  @override
  void dispose() {
    widget.canCloseNotifier?.value = null;
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
    _originalInstanceId = slot.instanceId;
    _originalNickname = slot.nickname ?? '';
    if (slot.instanceId != null) _loadInheritedData(slot.instanceId!, currentSlotId: slot.id);
    _isMegaEvolved = slot.isMegaEvolved;
    _hasGigantamax = slot.hasGigantamax;
    _gigantamaxEnabled = slot.gigantamaxEnabled;
    _isAlpha = slot.isAlpha;
    _teraType = slot.teraType;

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
    _currentSlot = slot;
  }

  /// Loads inherited ribbons and nickname aliases from the instance chain.
  /// Fire-and-forget from [_initFromSlot] — updates state when ready.
  Future<void> _loadInheritedData(int instanceId, {required int currentSlotId}) async {
    final repo = ref.read(pokemonInstanceRepositoryProvider);
    // Walk the full ancestor chain to union all inheritedRibbons.
    final chain = await repo.getChain(instanceId);
    final ribbons = <String>{};
    final aliases = <String>[];

    void addAlias(String? a) {
      if (a != null && a.isNotEmpty && !aliases.contains(a)) aliases.add(a);
    }

    for (final inst in chain) {
      // Aliases are collected from ancestors only — the current instance is the
      // "now", so its own names are not "previous".
      final isCurrentInstance = inst.id == instanceId;

      if (!isCurrentInstance) {
        // Include active slot nicknames for ancestor instances.
        // Skip the current slot so its own nickname doesn't appear.
        final slots = await repo.getSlotsForInstance(inst.id);
        for (final slot in slots) {
          if (slot.id != currentSlotId) addAlias(slot.nickname);
        }

        // Include superseded names stored in the ancestor's alias history.
        if (inst.nicknameAliases != null && inst.nicknameAliases!.isNotEmpty) {
          try {
            final a =
                (jsonDecode(inst.nicknameAliases!) as List).cast<String>();
            for (final alias in a) {
              addAlias(alias);
            }
          } catch (_) {}
        }
      }

      // Inherited ribbons are only meaningful from ancestor instances — the
      // current instance's inheritedRibbons is an accumulator for future
      // children, not something this slot itself inherited.
      if (!isCurrentInstance &&
          inst.inheritedRibbons != null &&
          inst.inheritedRibbons!.isNotEmpty) {
        try {
          ribbons.addAll(
              (jsonDecode(inst.inheritedRibbons!) as List).cast<String>());
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _inheritedRibbons = ribbons;
      _nicknameAliases = aliases;
    });
  }

  int get _evTotal =>
      _evCtrls.fold(0, (sum, c) => sum + (int.tryParse(c.text) ?? 0));

  /// Compute real-time violations against [format] for current form values.
  /// Uses PokéAPI version-group learnsets for game-specific accuracy.
  Map<String, String> _computeViolations(
    FormatService service,
    GameFormat format,
    String pokemonName,
    List<MoveSummary> pokemonMoves,
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
    // Resolve format to apply generation-specific validation rules.
    final team = ref.read(teamByIdProvider(existing.teamId)).asData?.value;
    final formatService = ref.read(formatServiceProvider);
    final saveFormat = team?.formatLabel != null
        ? formatService.formatById(team!.formatLabel!)
        : null;
    final saveGen = saveFormat?.gen;

    // Gen 3+: 510 total EV cap. Gen 1-2 Stat Exp: no total cap, 252 per stat.
    final hasTotalCap = saveGen == null || saveGen >= 3;
    if (hasTotalCap && _evTotal > 510) {
      showAppSnackBar(
        context,
        'EV total exceeds 510 — reduce before saving.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final evs = _evCtrls.map((c) => (int.tryParse(c.text) ?? 0).clamp(0, 252)).toList();
      final ivs = _ivCtrls.map((c) => (int.tryParse(c.text) ?? 31).clamp(0, 31)).toList();
      // Gen 1: no separate SpA/SpD — both mirror the single Special stat (index 3).
      if (saveGen == 1) {
        evs[4] = evs[3];
        ivs[4] = ivs[3];
      }
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
          teraType: Value(_teraType),
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
            'team_local_id':   existing.teamId,
            'slot':            existing.slot,
            'pokemon_id':      existing.pokemonId,
            if (nickname.isNotEmpty) 'nickname': nickname,
            if (_instanceId != null) 'instance_client_local_id': _instanceId,
            if (_formName != null) 'form_name': _formName,
            'level':           _level,
            if (_gender != null) 'gender': _gender,
            'is_shiny':        _isShiny,
            'friendship': _friendship,
            if (_abilityName != null) 'ability_name': _abilityName,
            if (_natureName != null) 'nature_name': _natureName,
            if (_heldItemName != null) 'held_item_name': _heldItemName,
            if (_moves[0] != null) 'move1': _moves[0],
            if (_moves[1] != null) 'move2': _moves[1],
            if (_moves[2] != null) 'move3': _moves[2],
            if (_moves[3] != null) 'move4': _moves[3],
            'ev_hp':  evs[0], 'ev_atk': evs[1], 'ev_def': evs[2],
            'ev_spa': evs[3], 'ev_spd': evs[4], 'ev_spe': evs[5],
            'iv_hp':  ivs[0], 'iv_atk': ivs[1], 'iv_def': ivs[2],
            'iv_spa': ivs[3], 'iv_spd': ivs[4], 'iv_spe': ivs[5],
            if (_ribbons.isNotEmpty) 'ribbons': jsonEncode(_ribbons.toList()),
            'is_mega_evolved':    _isMegaEvolved,
            'has_gigantamax':     _hasGigantamax,
            'gigantamax_enabled': _gigantamaxEnabled,
            'is_alpha':           _isAlpha,
            if (_teraType != null) 'tera_type': _teraType,
            'contest_cool':       contest[0], 'contest_beautiful': contest[1],
            'contest_cute':       contest[2], 'contest_clever':    contest[3],
            'contest_tough':      contest[4], 'contest_sheen':     contest[5],
          })),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Propagate instance data when linked.
      if (_instanceId != null) {
        final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);

        // Record old nickname as an alias if it changed.
        final newNickname = _nicknameCtrl.text.trim();
        if (_originalNickname.isNotEmpty &&
            _originalNickname != newNickname) {
          await instanceRepo.addNicknameAlias(
              _instanceId!, _originalNickname);
        }
        _originalNickname = newNickname;

        // Merge this slot's ribbons into the instance's inheritedRibbons so
        // child instances can pick them up.
        if (_ribbons.isNotEmpty) {
          await instanceRepo.mergeRibbons(_instanceId!, _ribbons.toList());
        }
      }

      // Repair chain continuity when a link is removed: re-parent
      // descendants of the orphaned instance, then delete it immediately
      // so the chain view is clean without waiting for manual cleanup.
      if (_originalInstanceId != null && _instanceId == null) {
        final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
        await instanceRepo.relinkOrphanedChain();
        await instanceRepo.deleteOrphanedInstances();
        _originalInstanceId = null;
      }

      // Best-effort PS export — runs after the DB write succeeds.
      await _maybePsExport(existing);

      if (mounted) {
        setState(() => _dirty = false);
        showAppSnackBar(context, 'Saved');
        if (!widget.embedded) context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Save failed: $e', isError: true);
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
    ref.watch(itemsListProvider);

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
    // Resolve format before resolvedPokemonProvider so gen-specific sprite
    // data (game_front) is fetched in the same backend call.
    final team = ref.watch(teamByIdProvider(slot.teamId)).asData?.value;
    final formatId = team?.formatLabel;
    final format = formatId != null
        ? ref.watch(formatServiceProvider).formatById(formatId)
        : null;
    final formatGen = format?.gen;
    final resolvedAsync = ref.watch(resolvedPokemonProvider((id: slot.pokemonId, gen: formatGen)));
    final formsData = ref.watch(pokemonFormsProvider((id: slot.pokemonId, gen: formatGen))).asData?.value;
    final varietiesData = ref.watch(pokemonVarietiesProvider((id: slot.pokemonId, gen: formatGen))).asData?.value;
    return resolvedAsync.when(
      loading: () => widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(appBar: AppBar(),
                      body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => widget.embedded
          ? Center(child: Text('$e'))
          : Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (resolved) {
        // ── Identity ───────────────────────────────────────────────────────
        final pokemon = resolved.detail;
        final speciesName = pokemon.displaySpeciesName;

        // ── Format & mechanics ─────────────────────────────────────────────
        // format/formatId computed above; only formatService is watched here.
        final formatService = ref.watch(formatServiceProvider);
        final mechanics = format != null
            ? GenerationMechanics.forGen(format.gen)
            : null;

        // ── Form state ─────────────────────────────────────────────────────
        final allVarieties = resolved.species.varieties.map((v) => v.name).toList();
        // Cosmetic forms pre-patched and keepAlive in resolvedPokemonProvider.
        final cosmeticFormEntries = resolved.cosmeticForms;
        final cosmeticForms = cosmeticFormEntries.map((f) => f.name).toList();
        // Primal Reversion only existed in Gen 6-7 (same window as Mega Stones).
        final primalFormatOk = mechanics == null ||
            mechanics.gen == 6 ||
            mechanics.gen == 7;
        const primalForms = {'groudon-primal', 'kyogre-primal'};
        final availableForms = filterFormChips(
          varieties: allVarieties,
          cosmeticForms: cosmeticForms,
          heldItem: _heldItemName,
          abilityName: _abilityName,
          gen: format?.gen,
        ).where((f) => primalFormatOk || !primalForms.contains(f)).toList();
        final hasMultipleForms = availableForms.isNotEmpty;
        final isCosmeticFormSelected =
            _formName != null && cosmeticForms.contains(_formName);
        // Battle-meaningful variety — look up directly in varietiesData.
        final formVariety = (_formName != null && !isCosmeticFormSelected)
            ? varietiesData?.where((v) => v.name == _formName).firstOrNull
            : null;
        // Fetch variety-specific moves when a form is active.
        final formMovesAsync = formVariety != null
            ? ref.watch(pokemonMovesProvider((id: formVariety.pokemonId, gen: format?.gen)))
            : null;
        PokemonFormEntry? cosmeticForm;
        if (isCosmeticFormSelected) {
          for (final entry in cosmeticFormEntries) {
            if (entry.name == _formName) {
              cosmeticForm = entry;
              break;
            }
          }
        }

        // ── Mega detection ─────────────────────────────────────────────────
        // Backend varieties carry is_mega, associated_item, associated_move.
        bool isMegaMatch(VarietyBackendData v) {
          if (v.isMega != true) return false;
          if (v.associatedItem != null && _heldItemName == v.associatedItem) return true;
          if (v.associatedMove != null && _moves.contains(v.associatedMove)) return true;
          return false;
        }
        final canMegaEvolve = (mechanics == null || mechanics.hasMegaStone) &&
            (varietiesData?.any(isMegaMatch) ?? false);
        final megaVariety = (_isMegaEvolved && canMegaEvolve)
            ? varietiesData?.where(isMegaMatch).firstOrNull
            : null;

        // ── GMax detection ─────────────────────────────────────────────────
        final canDynamax = mechanics == null || mechanics.hasGigantamax;
        final effectiveSpeciesName = formVariety?.name ?? pokemon.name;
        final gmaxMove = gmaxMoveForSpecies(effectiveSpeciesName)?.moveName;
        final canGigantamax = canDynamax && gmaxMove != null;
        final gmaxFormName = canGigantamax ? '$effectiveSpeciesName-gmax' : null;
        final gmaxPokemonAsync = (canGigantamax && _hasGigantamax && _gigantamaxEnabled)
            ? ref.watch(pokemonByNameProvider(gmaxFormName!))
            : null;
        final gmaxPokemon = gmaxPokemonAsync?.asData?.value;

        // ── Abilities ──────────────────────────────────────────────────────
        final abilities = pokemon.abilities
            .map((a) => (name: a.name, isHidden: a.isHidden, abilitySlot: a.slot))
            .toList()
          ..sort((a, b) => a.abilitySlot.compareTo(b.abilitySlot));
        // Form abilities from VarietyBackendData: {"0": "blaze", "H": "solar-power"}.
        // PS data uses display names ("Sand Veil"); normalise to PokéAPI slug
        // so abilityProvider and route navigation receive the right format.
        final effectiveAbilities = (formVariety?.abilities?.isNotEmpty == true)
            ? (formVariety!.abilities!.entries
                    .map((e) => (
                          name: e.value.toLowerCase().replaceAll(' ', '-'),
                          isHidden: e.key == 'H',
                          abilitySlot:
                              e.key == 'H' ? 3 : (int.tryParse(e.key) ?? 0) + 1,
                        ))
                    .toList()
                  ..sort((a, b) => a.abilitySlot.compareTo(b.abilitySlot)))
            : abilities;

        // ── Moves ──────────────────────────────────────────────────────────
        // Backend already returns gen-filtered moves with supplement moves merged
        // when gen is specified; no client-side buildLearnsetForFormat needed.
        final pokemonMovesAsync = ref.watch(pokemonMovesProvider((id: slot.pokemonId, gen: format?.gen)));
        final pokemonMoves = pokemonMovesAsync.asData?.value ?? pokemon.moves;
        final formMoves = formMovesAsync?.asData?.value;
        final effectivePokemonMoves =
            (formMoves != null && formMoves.isNotEmpty) ? formMoves : pokemonMoves;
        final effectivePokemonName = formVariety?.name ?? pokemon.name;
        final effectiveLearnableMoveSet = effectivePokemonMoves.map((m) => m.name).toSet();
        final effectiveLearnableMoves = effectiveLearnableMoveSet.toList()..sort();
        final priorEvoMoveSetsAsync = ref.watch(priorEvoMoveSetsProvider(
          (id: formVariety != null ? formVariety.pokemonId : slot.pokemonId, gen: format?.gen),
        ));
        final effectivePriorEvoMoves = priorEvoMoveSetsAsync.whenOrNull(data: (sets) {
          if (sets.isEmpty) return const <String>{};
          final ancestorAll = <String>{};
          for (final ancestor in sets) {
            for (final m in ancestor.moves) {
              ancestorAll.add(m.name);
            }
          }
          return ancestorAll.difference(effectiveLearnableMoveSet);
        }) ??
            const <String>{};
        // Event moves: surfaced for the picker's "Event" badge only.
        final effectiveEventMoves = <String>{};
        if (format != null && formatService.isInitialized) {
          final eventIds =
              formatService.eventMovesForGen(effectivePokemonName, format.gen);
          if (eventIds.isNotEmpty) {
            for (final name in effectiveLearnableMoves) {
              if (eventIds.contains(name.replaceAll('-', '').toLowerCase())) {
                effectiveEventMoves.add(name);
              }
            }
          }
        }
        final allPickableMoves = {
          ...effectiveLearnableMoves,
          ...effectivePriorEvoMoves,
        }.toList()..sort();

        // ── Stats ──────────────────────────────────────────────────────────
        // Priority: form > mega > base.
        final baseStats = pokemon.stats;
        final effectiveBaseStats = megaVariety?.baseStats?.map((k, v) => MapEntry(k, v))
            ?? baseStats;
        final finalBaseStats = formVariety?.baseStats?.map((k, v) => MapEntry(k, v))
            ?? effectiveBaseStats;

        // ── Validation ─────────────────────────────────────────────────────
        // Prior-evo moves are excluded from violation checking.
        final effectiveViolations = {
          for (final entry in (format != null
                  ? _computeViolations(formatService, format, pokemon.name,
                      effectivePokemonMoves)
                  : <String, String>{})
              .entries)
            if (!entry.key.startsWith('move') ||
                !effectivePriorEvoMoves.contains(
                    _moves[int.parse(entry.key.substring(4)) - 1]))
              entry.key: entry.value,
        };

        // ── Sprites ────────────────────────────────────────────────────────
        final useFormatSprites =
            ref.watch(useFormatSpritesProvider).asData?.value ?? true;
        final useGen15Sprite = useFormatSprites && format != null && format.gen <= 5;

        // Cosmetic form sprite: full sprite data from formsData (backend-resolved).
        final cosmeticFormRef = cosmeticForm;
        final cosmeticFullSprite = cosmeticFormRef != null
            ? formsData?.where((fd) => fd.name == cosmeticFormRef.name).firstOrNull
            : null;

        // Active sprite source: active form's SpriteUrlsFull takes priority
        // over the base pokemon's. Falls back to resolved.spriteUrls.
        final activeSpriteSource = formVariety?.spriteUrls
            ?? cosmeticFullSprite?.spriteUrls
            ?? resolved.spriteUrls;

        // Sprite record: gen 1-5 → game_front; gen 6+ → HOME.
        // Form sprites flow through automatically via activeSpriteSource.
        final spriteUrls = useGen15Sprite
            ? (
                defaultUrl: activeSpriteSource.gameFront,
                shinyUrl: activeSpriteSource.gameFrontShiny ??
                    activeSpriteSource.gameFront,
                femaleUrl: activeSpriteSource.gameFrontFemale,
                femaleShinyUrl: activeSpriteSource.gameFrontFemaleShiny,
                fallbackUrl: null as String?,
                fallbackUrl2: null as String?,
              )
            : (
                defaultUrl: activeSpriteSource.home,
                shinyUrl: activeSpriteSource.homeShiny ?? activeSpriteSource.home,
                femaleUrl: activeSpriteSource.homeFemale,
                femaleShinyUrl: activeSpriteSource.homeFemaleShiny,
                fallbackUrl: null as String?,
                fallbackUrl2: null as String?,
              );

        // Mega artwork (HOME only — true artwork override, not mixed with sprites).
        final megaHomeUrl = megaVariety != null
            ? (_isShiny
                ? (megaVariety.spriteUrls?.homeShiny ?? megaVariety.spriteUrls?.home)
                : megaVariety.spriteUrls?.home)
            : null;

        // GMax sprite.
        final gmaxHomeUrl = gmaxPokemon != null
            ? (_isShiny
                ? pokemonHomeShinyUrl(gmaxPokemon.id)
                : pokemonHomeUrl(gmaxPokemon.id))
            : null;

        // Override artwork: GMax > Mega only.
        // Form sprites are already in spriteUrls via activeSpriteSource.
        final effectiveMegaArtworkUrl = gmaxHomeUrl ?? megaHomeUrl;
        final effectiveMegaFallbackUrl = gmaxHomeUrl != null
            ? (_isShiny
                ? (gmaxPokemon?.officialArtworkShinyUrl ??
                    gmaxPokemon?.officialArtworkUrl)
                : gmaxPokemon?.officialArtworkUrl)
            : (_isShiny
                ? (megaVariety?.spriteUrls?.officialArtworkShiny ??
                    megaVariety?.spriteUrls?.officialArtwork)
                : megaVariety?.spriteUrls?.officialArtwork);

        // ── Alpha ──────────────────────────────────────────────────────────
        // Only shown for formats where Alpha transfers make sense
        // (PLA / Gen 9 / no format) and only for species actually in PLA.
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
                  isFormLoading: formMovesAsync?.isLoading ?? false),
              // ── Form selector (when Pokémon has multiple forms) ──
              if (hasMultipleForms) ...[
                const SizedBox(height: 16),
                _buildFormSelector(availableForms,
                    defaultFormLabel: pokemon.defaultFormLabel ??
                        PokemonDataRegistry.instance.baseFormNameOverrides[pokemon.name],
                    speciesName: pokemon.speciesName ?? pokemon.name),
              ],
              const SizedBox(height: 24),
              _buildBasics(mechanics, resolved.species.genderRate),
              // ── Ability (Gen 3+) ──
              if (mechanics == null || mechanics.hasAbilities) ...[
                const SizedBox(height: 24),
                _SectionTitle('Ability'),
                const SizedBox(height: 8),
                _buildAbility(effectiveAbilities, effectiveViolations['ability'], format),
                // Mega form ability shown as read-only info when evolved.
                if (canMegaEvolve && _isMegaEvolved &&
                    megaVariety?.abilities?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _buildMegaAbilityInfo(
                      (megaVariety!.abilities!['0'] ?? megaVariety.abilities!.values.first)
                          .toLowerCase()
                          .replaceAll(' ', '-')),
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
                _buildMegaToggle(megaVariety?.name ?? ''),
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
              // ── Tera Type (Gen 9 / No Format) ──
              if (mechanics == null || mechanics.hasTeraType) ...[
                const SizedBox(height: 24),
                _SectionTitle('Tera Type'),
                const SizedBox(height: 8),
                _buildTeraType(),
              ],
              const SizedBox(height: 24),
              _SectionTitle('Moves'),
              const SizedBox(height: 8),
              _buildMoves(allPickableMoves,
                  violations: effectiveViolations,
                  pokemonName: effectivePokemonName,
                  showMaxMoves: canDynamax,
                  useGMax: canGigantamax && _hasGigantamax && _gigantamaxEnabled,
                  priorEvoMoves: effectivePriorEvoMoves,
                  eventMoves: effectiveEventMoves),
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
              // ── Ribbons (Gen 3+ only — introduced in Ruby/Sapphire) ──
              if (mechanics == null || mechanics.gen >= 3) ...[
                const SizedBox(height: 24),
                _SectionTitle('Ribbons'),
                const SizedBox(height: 8),
                _buildRibbons(mechanics),
              ],
              // ── Pokémon Instance ──
              const SizedBox(height: 24),
              _SectionTitle('Pokémon Identity'),
              const SizedBox(height: 8),
              _buildInstanceSection(slot, speciesName),
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
                        onPressed: _dirty
                            ? () => _showUnsavedDialog(onDiscard: widget.onClose)
                            : widget.onClose,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: scrollBody),
            ],
          );
        }

        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _showUnsavedDialog();
          },
          child: Scaffold(
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
        ),
        );
      },
    );
  }

  /// Called by the parent (wide layout) to check whether it is safe to
  /// navigate away. Shows the unsaved-changes dialog when dirty and returns
  /// true if the caller may proceed (saved or discarded) or false if cancelled.
  Future<bool> _canClose() async {
    if (!_dirty) return true;
    final slot = _currentSlot;
    if (slot == null) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Would you like to save or discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null), // cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false), // discard
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true), // save
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (result == true) {
      await _save(slot);
      return true;
    } else if (result == false) {
      setState(() => _dirty = false);
      return true;
    }
    return false; // cancelled
  }

  Future<void> _showUnsavedDialog({VoidCallback? onDiscard}) async {
    final slot = _currentSlot;
    if (slot == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Would you like to save or discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result == true) {
      await _save(slot);
    } else if (result == false) {
      setState(() => _dirty = false);
      if (!mounted) return;
      if (onDiscard != null) {
        onDiscard();
      } else {
        context.pop();
      }
    }
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    TeamSlot slot,
    ({String? defaultUrl, String? shinyUrl, String? femaleUrl, String? femaleShinyUrl, String? fallbackUrl, String? fallbackUrl2}) spriteUrls,
    GenerationMechanics? mechanics, {
    String? megaArtworkUrl,
    String? megaFallbackUrl,
    bool isFormLoading = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // spriteUrls already holds the correct URL for the active gen: HOME for
    // gen 6+/no-format, versioned sprite for gen 1-5.
    final isFemale = _gender == 'female';
    final genderUrl = isFemale
        ? (_isShiny ? spriteUrls.femaleShinyUrl : spriteUrls.femaleUrl)
        : null;
    final genFallback = _isShiny ? spriteUrls.shinyUrl : spriteUrls.defaultUrl;
    final homeFemaleUrl = isFemale
        ? (_isShiny
            ? pokemonHomeShinyFemaleUrl(slot.pokemonId)
            : pokemonHomeFemaleUrl(slot.pokemonId))
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            PokemonSprite(
              defaultUrl: megaArtworkUrl ?? genderUrl ?? spriteUrls.defaultUrl,
              fallbackUrl: megaArtworkUrl != null
                  ? megaFallbackUrl
                  : genderUrl != null
                      ? genFallback
                      : spriteUrls.fallbackUrl,
              fallbackUrl2: megaArtworkUrl != null
                  ? spriteUrls.defaultUrl
                  : genderUrl != null
                      ? homeFemaleUrl
                      : spriteUrls.fallbackUrl2,
              shinyUrl: (megaArtworkUrl == null && genderUrl == null)
                  ? spriteUrls.shinyUrl
                  : null,
              shiny: megaArtworkUrl == null && genderUrl == null && _isShiny,
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
              onTap: () => setState(() { _isShiny = !_isShiny; _dirty = true; }),
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
                onChanged: (_) => setState(() => _dirty = true),
              ),
              if (_nicknameAliases.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Previously known as: ${_nicknameAliases.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Basics ────────────────────────────────────────────────────────────────

  Widget _buildBasics(GenerationMechanics? mechanics, int? genderRate) {
    // Friendship exists from Gen 2 onward; Gen 1 has no friendship mechanic.
    final showFriendship = mechanics == null || mechanics.gen >= 2;
    // Gender mechanic introduced in Gen 2; Gen 1 Pokémon have no gender.
    final showGender = mechanics == null || mechanics.gen >= 2;
    // Restrict gender chips to what the species can actually be — e.g.
    // Wormadam (rate 8) can only ever be female, Tauros (rate 0) only male,
    // Magnemite (rate -1) is genderless. Mixed-ratio species (1-7) can be
    // either but never genderless.
    final genderOptions = switch (genderRate) {
      -1 => const [('genderless', '⚲ None')],
      0 => const [('male', '♂ Male')],
      8 => const [('female', '♀ Female')],
      null => const [('male', '♂ Male'), ('female', '♀ Female'), ('genderless', '⚲ None')],
      _ => const [('male', '♂ Male'), ('female', '♀ Female')],
    };
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
                onChanged: (v) => setState(() { _level = v.round(); _dirty = true; }),
              ),
            ),
          ],
        ),
        if (showGender) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final g in genderOptions)
                ChoiceChip(
                  label: Text(g.$2),
                  selected: _gender == g.$1,
                  onSelected: (_) =>
                      setState(() { _gender = _gender == g.$1 ? null : g.$1; _dirty = true; }),
                ),
            ],
          ),
        ],
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
                  onChanged: (v) => setState(() { _friendship = v.round(); _dirty = true; }),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Ability — selectable cards with descriptions ───────────────────────────

  static int? _genNameToNumber(String? generationName) {
    const map = {
      'generation-i': 1, 'generation-ii': 2, 'generation-iii': 3,
      'generation-iv': 4, 'generation-v': 5, 'generation-vi': 6,
      'generation-vii': 7, 'generation-viii': 8, 'generation-ix': 9,
    };
    return generationName == null ? null : map[generationName];
  }

  Widget _buildAbility(
    List<({String name, bool isHidden, int abilitySlot})> abilities,
    String? violation,
    GameFormat? format,
  ) {
    if (abilities.isEmpty) return const Text('No abilities available');

    final cards = Column(
      children: abilities.map((a) {
        final detailAsync = ref.watch(abilityProvider(a.name));
        final isSelected = _abilityName == a.name;
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        final description = detailAsync.whenOrNull(
          data: (entry) => entry.shortEffect,
        );

        // Gen gating — two rules, always exempting the currently-selected
        // ability so the violation banner can explain any mismatch:
        //
        // Rule 1 (synchronous): hidden abilities didn't exist until Gen 5
        // (Dream World). Hides e.g. Umbreon's Inner Focus in Gen 3.
        //
        // Rule 2 (async): PS ability data lacks accurate gen info, so use
        // PokéAPI's generationName to gate abilities not yet introduced.
        // Hides e.g. Super Luck (Gen 4 ability) in a Gen 3 format.
        if (format != null && !isSelected) {
          if (a.isHidden && format.gen < 5) return const SizedBox.shrink();
          final abilityGen = detailAsync.whenOrNull(
            data: (entry) => _genNameToNumber(entry.generationName),
          );
          if (abilityGen != null && abilityGen > format.gen) {
            return const SizedBox.shrink();
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() { _abilityName = isSelected ? null : a.name; _dirty = true; }),
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
                          const _DescriptionLoadingBar(),
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
        onChanged: (v) => setState(() { _natureName = v; _dirty = true; }),
      ),
    );
  }

  // ── Held item — picker + description ──────────────────────────────────────

  Widget _buildHeldItem({String? violation}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String? description;
    bool descriptionLoading = false;
    if (_heldItemName != null) {
      final detailAsync = ref.watch(itemProvider(_heldItemName!));
      description = detailAsync.whenOrNull(data: (e) => e.shortEffect);
      descriptionLoading = description == null && detailAsync.isLoading;
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
                    onPressed: () => setState(() { _heldItemName = null; _dirty = true; }),
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
          )
        else if (descriptionLoading)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: _DescriptionLoadingBar(),
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
    Set<String> priorEvoMoves = const {},
    Set<String> eventMoves = const {},
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: List.generate(4, (i) {
        MoveEntry? moveDetail;
        bool moveDetailLoading = false;
        if (_moves[i] != null) {
          final detailAsync = ref.watch(moveProvider(_moves[i]!));
          moveDetail = detailAsync.whenOrNull(data: (e) => e);
          moveDetailLoading = moveDetail == null && detailAsync.isLoading;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tap target row
              InkWell(
                onTap: () => _pickMove(i, learnableMoves,
                    priorEvoMoves: priorEvoMoves, eventMoves: eventMoves),
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
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _moves[i]?.toCapitalCase() ?? '— None —',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      if (_moves[i] != null && priorEvoMoves.contains(_moves[i]))
                        Padding(
                          padding: const EdgeInsets.only(left: 4, right: 2),
                          child: _PreEvoBadge(),
                        ),
                      if (_moves[i] != null && eventMoves.contains(_moves[i]))
                        Padding(
                          padding: const EdgeInsets.only(left: 4, right: 2),
                          child: _EventMoveBadge(),
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
                        Flexible(
                          child: Text(
                            [
                              if (moveDetail.power != null) 'Pow ${moveDetail.power}',
                              if (moveDetail.accuracy != null) '${moveDetail.accuracy}%',
                              if (moveDetail.pp != null) 'PP ${moveDetail.pp}',
                            ].join('  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
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
                          onPressed: () => setState(() { _moves[i] = null; _dirty = true; }),
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
                )
              else if (moveDetailLoading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: _DescriptionLoadingBar(),
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

  /// Returns 0–15 index of the Hidden Power type from current IVs/DVs.
  /// Gen 2: type = (Atk_DV mod 4)*4 + (Def_DV mod 4).
  /// Gen 3+: uses LSB of each IV in HP/Atk/Def/Spe/SpA/SpD order.
  int _hiddenPowerTypeIndex({int? gen}) {
    final iv = _ivCtrls.map((c) => int.tryParse(c.text) ?? 31).toList();
    if (gen == 2) {
      return (iv[1] % 4) * 4 + (iv[2] % 4);
    }
    // Bit order: HP, Atk, Def, Spe, SpA, SpD (Spe=index 5, SpA=index 3, SpD=index 4)
    final n = (iv[0] & 1) +
        (iv[1] & 1) * 2 +
        (iv[2] & 1) * 4 +
        (iv[5] & 1) * 8 +
        (iv[3] & 1) * 16 +
        (iv[4] & 1) * 32;
    return (n * 15) ~/ 63;
  }

  /// Returns the power of Hidden Power.
  /// Gen 2: 31–70, using MSBs of Atk/Def/Spe/Special DVs and Special mod 4.
  /// Gen 3–5: 30–70, using second bits of all IVs.
  /// Gen 6+: always 60.
  int _hiddenPowerPower({int? gen}) {
    if (gen != null && gen >= 6) return 60;
    final iv = _ivCtrls.map((c) => int.tryParse(c.text) ?? 31).toList();
    if (gen == 2) {
      // HPpower = floor((5*(v + 2w + 4x + 8y) + Z) / 2) + 31
      // v=Special MSB, w=Speed MSB, x=Def MSB, y=Atk MSB, Z=Special mod 4
      final v = iv[3] >= 8 ? 1 : 0;
      final w = iv[5] >= 8 ? 1 : 0;
      final x = iv[2] >= 8 ? 1 : 0;
      final y = iv[1] >= 8 ? 1 : 0;
      final z = iv[3] % 4;
      return (5 * (v + 2 * w + 4 * x + 8 * y) + z) ~/ 2 + 31;
    }
    final u = ((iv[0] >> 1) & 1) +
        ((iv[1] >> 1) & 1) * 2 +
        ((iv[2] >> 1) & 1) * 4 +
        ((iv[5] >> 1) & 1) * 8 +
        ((iv[3] >> 1) & 1) * 16 +
        ((iv[4] >> 1) & 1) * 32;
    return (u * 40) ~/ 63 + 30;
  }

  Widget _buildHiddenPower({int? gen}) {
    final typeIdx = _hiddenPowerTypeIndex(gen: gen);
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
          onChanged: (_) => setState(() => _dirty = true),
        );
      },
    );
  }

  // ── Stat preview ──────────────────────────────────────────────────────────

  // Gen 1 stat preview uses the same 5-stat layout as the EV/IV grid.
  // SpD is absent; Special (index 3) covers both SpA and SpD.
  static const _gen1PreviewKeys = [
    'hp', 'attack', 'defense', 'special-attack', 'speed',
  ];

  Widget _buildStatPreview(Map<String, int> baseStats, GenerationMechanics? mechanics) {
    if (baseStats.isEmpty) return const SizedBox.shrink();
    final maxIv = mechanics?.statMax ?? 31;
    final evs = _evCtrls.map((c) => (int.tryParse(c.text) ?? 0).clamp(0, 252)).toList();
    final ivs = _ivCtrls
        .map((c) => (int.tryParse(c.text) ?? maxIv).clamp(0, maxIv))
        .toList();

    final isGen1 = mechanics?.gen == 1;
    // Gen 1: SpD = SpA (both are the single Special stat).
    // Sync the hidden SpD controller so the preview reflects what was typed.
    if (isGen1) {
      evs[4] = evs[3];
      ivs[4] = ivs[3];
    }

    // Gen 1: nature modifiers don't apply
    final useNature = mechanics == null || mechanics.hasAbilities;

    final labels  = isGen1 ? _gen1StatLabels  : _statLabels;
    final indices = isGen1 ? _gen1StatIndices  : List.generate(6, (i) => i);
    final keys    = isGen1 ? _gen1PreviewKeys  : _statKeys;

    return Column(
      children: [
        for (int i = 0; i < indices.length; i++)
          StatBar(
            label: labels[i],
            value: keys[i] == 'hp'
                ? stat.calcHP(baseStats['hp'] ?? 0, ivs[0], evs[0], _level)
                : stat.calcStat(
                    baseStats[keys[i]] ?? 0,
                    ivs[indices[i]], evs[indices[i]], _level,
                    useNature ? stat.natureMod(_natureName, keys[i]) : 1.0),
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
    final items = (ref.read(itemsListProvider).asData?.value ?? [])
        .map((e) => e.name)
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
      setState(() {
        _heldItemName = result
            .replaceAll(RegExp(r'-(held|bag)$'), '')
            .replaceAll(RegExp(r'-+$'), '');
        _dirty = true;
      });
    }
  }

  Future<void> _pickMove(
    int moveIndex,
    List<String> learnableMoves, {
    Set<String> priorEvoMoves = const {},
    Set<String> eventMoves = const {},
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MovePickerSheet(
        moves: learnableMoves,
        current: _moves[moveIndex],
        label: 'Move ${moveIndex + 1}',
        priorEvoMoves: priorEvoMoves,
        eventMoves: eventMoves,
      ),
    );
    if (result != null) setState(() { _moves[moveIndex] = result; _dirty = true; });
  }

  // ── Form selector ─────────────────────────────────────────────────────────

  Widget _buildFormSelector(List<String> forms,
      {String? defaultFormLabel, String? speciesName}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Strip the species-name prefix from a variety name so chips show only
    // the form-specific part: "necrozma-dawn-wings" → "Dawn Wings",
    // "urshifu-rapid-strike" → "Rapid Strike", "gastrodon-east" → "East".
    String fmtForm(String name) {
      final prefix = speciesName != null ? '$speciesName-' : null;
      final raw =
          prefix != null && name.startsWith(prefix) ? name.substring(prefix.length) : name;
      return raw
          .split('-')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }

    final isDefault = _formName == null;
    // For no-plain-form species (e.g. Wormadam), label the default chip with
    // the actual form name ("Plant") rather than the generic "Default".
    final defaultChipLabel =
        defaultFormLabel != null ? fmtForm(defaultFormLabel) : 'Default';

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
              label: Text(defaultChipLabel),
              selected: isDefault,
              onSelected: (_) => setState(() { _formName = null; _dirty = true; }),
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
                onSelected: (_) => setState(() { _formName = form; _dirty = true; }),
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

  Widget _buildMegaAbilityInfo(String abilityName) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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

  Widget _buildMegaToggle(String megaFormName) {
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
                  megaFormName.split('-').map((w) =>
                      w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
                      .join(' '),
                  style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
              value: _isMegaEvolved,
              onChanged: (v) => setState(() { _isMegaEvolved = v; _dirty = true; }),
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
                  _dirty = true;
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
                    onChanged: (v) => setState(() { _gigantamaxEnabled = v; _dirty = true; }),
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
            onChanged: (v) => setState(() { _isAlpha = v; _dirty = true; }),
          ),
        ],
      ),
    );
  }

  // ── Tera Type ─────────────────────────────────────────────────────────────

  Widget _buildTeraType() {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kAllTypes.map((type) {
        final isSelected = _teraType == type;
        final typeColor = PokemonTypeColors.colors[type] ?? Colors.grey;
        return GestureDetector(
          onTap: () => setState(() => _teraType = isSelected ? null : type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? typeColor
                  : typeColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? typeColor : typeColor.withValues(alpha: 0.5),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              type[0].toUpperCase() + type.substring(1),
              style: textTheme.labelMedium?.copyWith(
                color: isSelected ? Colors.white : typeColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Ribbons ───────────────────────────────────────────────────────────────

  // ── Pokémon Instance ──────────────────────────────────────────────────────

  // ── "Link as child" path ──
  // Current slot is the child; the picked slot is (or becomes) the origin.

  Future<void> _onLinkAsChild(TeamSlot currentSlot, TeamSlot targetSlot) async {
    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);

    // Ensure the target has an origin instance.
    int parentInstanceId;
    if (targetSlot.instanceId != null) {
      parentInstanceId = targetSlot.instanceId!;
    } else {
      parentInstanceId = await instanceRepo.createOrigin(
        pokemonId: targetSlot.pokemonId,
      );
      await slotRepo.setInstanceId(targetSlot.id, parentInstanceId);
    }

    // Create an iteration for the current slot.
    final childInstanceId = await instanceRepo.createIteration(
      pokemonId: currentSlot.pokemonId,
      parentInstanceId: parentInstanceId,
    );

    setState(() { _instanceId = childInstanceId; _dirty = true; });
  }

  // ── "Link as origin" path ──
  // Current slot is the origin; the picked slot becomes the child.

  Future<void> _onLinkAsOriginExisting(
      TeamSlot currentSlot, TeamSlot targetSlot) async {
    // Block if the target already has an origin.
    if (targetSlot.instanceId != null) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'That slot already has an origin. Unlink it from its config first.',
        isError: true,
      );
      return;
    }

    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);

    // Ensure the current slot has an origin instance.
    int originInstanceId;
    if (_instanceId != null) {
      originInstanceId = _instanceId!;
    } else {
      originInstanceId = await instanceRepo.createOrigin(
        pokemonId: currentSlot.pokemonId,
      );
      setState(() { _instanceId = originInstanceId; _dirty = true; });
    }

    // Create a child iteration for the target slot.
    final childInstanceId = await instanceRepo.createIteration(
      pokemonId: targetSlot.pokemonId,
      parentInstanceId: originInstanceId,
    );
    await slotRepo.setInstanceId(targetSlot.id, childInstanceId);
  }

  Future<void> _onLinkAsOriginNewTeam(
      TeamSlot currentSlot, String speciesName) async {
    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);
    final teamRepo = ref.read(teamRepositoryProvider);

    // 1. Create the new team (no format, no folder).
    final allTeams = await teamRepo.getAll();
    final newTeamId = await teamRepo.insert(
      TeamsCompanion(
        name: Value('$speciesName — Journey'),
        sortOrder: Value(allTeams.length),
        syncStatus: const Value('pending'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // 2. Ensure the current slot has an origin instance.
    int originInstanceId;
    if (_instanceId != null) {
      originInstanceId = _instanceId!;
    } else {
      originInstanceId = await instanceRepo.createOrigin(
        pokemonId: currentSlot.pokemonId,
      );
      setState(() { _instanceId = originInstanceId; _dirty = true; });
    }

    // 3. Create a child iteration for the new slot.
    final childInstanceId = await instanceRepo.createIteration(
      pokemonId: currentSlot.pokemonId,
      parentInstanceId: originInstanceId,
    );

    // 4. Insert the new slot (copies species, gender, shiny).
    await slotRepo.insert(
      TeamSlotsCompanion(
        teamId: Value(newTeamId),
        slot: const Value(1),
        pokemonId: Value(currentSlot.pokemonId),
        gender: Value(currentSlot.gender),
        isShiny: Value(currentSlot.isShiny),
        instanceId: Value(childInstanceId),
        syncStatus: const Value('pending'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (!mounted) return;
    showAppSnackBar(context, '"$speciesName — Journey" created and linked as child.');
  }

  // ── Link-type chooser ──

  void _showLinkTypeSheet(TeamSlot slot, String speciesName) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How is this slot connected?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose whether this slot is the original appearance or a later one.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),

              // ── This slot is the CHILD ──
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.south_rounded, size: 18),
                ),
                title: const Text('This slot is the child'),
                subtitle:
                    const Text('Pick the earlier slot this Pokémon came from.'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => InstancePickerSheet(
                      originSlot: slot,
                      forwardDirection: false, // child role → show ancestors
                      onPick: (targetSlot) {
                        Navigator.of(context).pop();
                        _onLinkAsChild(slot, targetSlot);
                      },
                    ),
                  );
                },
              ),

              const Divider(),

              // ── This slot is the ORIGIN ──
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.north_rounded, size: 18),
                ),
                title: const Text('This slot is the origin'),
                subtitle: const Text(
                    'Link a later slot, or create a new team to track this Pokémon forward.'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showOriginSubOptions(slot, speciesName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOriginSubOptions(TeamSlot slot, String speciesName) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Link as origin',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),

              // ── Link to an already-filled slot ──
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.people_alt_rounded, size: 18),
                ),
                title: const Text('Link to an existing slot'),
                subtitle: const Text(
                    'Pick a filled slot on another team to become the child.'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => InstancePickerSheet(
                      originSlot: slot,
                      forwardDirection: true, // origin role → show evolutions
                      onPick: (targetSlot) {
                        Navigator.of(context).pop();
                        _onLinkAsOriginExisting(slot, targetSlot);
                      },
                    ),
                  );
                },
              ),

              const Divider(),

              // ── Copy to a team slot (new team OR empty slot in existing team) ──
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.add_circle_outline_rounded, size: 18),
                ),
                title: const Text('Copy to a team slot'),
                subtitle: const Text(
                    'Create a new team or pick an empty slot in an existing team.'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _TeamSlotDestinationSheet(
                      speciesName: speciesName,
                      onNewTeam: () {
                        Navigator.of(context).pop();
                        _onLinkAsOriginNewTeam(slot, speciesName);
                      },
                      onExistingSlot: (teamId, slotNum, teamName) {
                        Navigator.of(context).pop();
                        _onLinkAsOriginExistingSlot(
                            slot, teamId, slotNum, teamName);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Copies the current slot's Pokémon into an empty slot on an existing team,
  /// then links: current slot = origin, target slot = child.
  Future<void> _onLinkAsOriginExistingSlot(
    TeamSlot currentSlot,
    int targetTeamId,
    int targetSlotNum,
    String targetTeamName,
  ) async {
    final instanceRepo = ref.read(pokemonInstanceRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);

    // Ensure current slot has an origin instance.
    int originInstanceId;
    if (_instanceId != null) {
      originInstanceId = _instanceId!;
    } else {
      originInstanceId = await instanceRepo.createOrigin(
        pokemonId: currentSlot.pokemonId,
      );
      setState(() { _instanceId = originInstanceId; _dirty = true; });
    }

    // Create child iteration.
    final childInstanceId = await instanceRepo.createIteration(
      pokemonId: currentSlot.pokemonId,
      parentInstanceId: originInstanceId,
    );

    // Insert into the target slot.
    await slotRepo.insert(
      TeamSlotsCompanion(
        teamId: Value(targetTeamId),
        slot: Value(targetSlotNum),
        pokemonId: Value(currentSlot.pokemonId),
        gender: Value(currentSlot.gender),
        isShiny: Value(currentSlot.isShiny),
        instanceId: Value(childInstanceId),
        syncStatus: const Value('pending'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (!mounted) return;
    showAppSnackBar(context, 'Copied to "$targetTeamName" slot $targetSlotNum and linked.');
  }

  void _unlink() => setState(() { _instanceId = null; _dirty = true; });

  Widget _buildInstanceSection(TeamSlot slot, String speciesName) {
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add_link_rounded, size: 16),
                label: const Text('Add child'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showOriginSubOptions(slot, speciesName),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.link_off_rounded, size: 16),
                label: const Text('Unlink'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.5)),
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
            onPressed: () => _showLinkTypeSheet(slot, speciesName),
          ),
        ],
      ],
    );
  }

  Widget _buildRibbons(GenerationMechanics? mechanics) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Ribbons that are inherited but not yet awarded on this slot.
    final inheritedOnly =
        _inheritedRibbons.difference(_ribbons).toList()..sort();

    // Pre-filter the catalog: inherited ribbons are already shown above and
    // should not appear again as selectable options. When a format is set,
    // also hide ribbons introduced in a later generation.
    final selectableCatalog = kRibbonCatalog
        .map((cat) => (
              name: cat.name,
              ribbons: cat.ribbons
                  .where((r) =>
                      !_inheritedRibbons.contains(r.id) &&
                      (mechanics == null || r.minGen <= mechanics.gen))
                  .toList(),
            ))
        .where((cat) => cat.ribbons.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Inherited from chain ──────────────────────────────────────────
        if (inheritedOnly.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Inherited from previous appearances',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: inheritedOnly.map((id) {
              // Find ribbon metadata for display name / sprite.
              final ribbon = kRibbonCatalog
                  .expand((c) => c.ribbons)
                  .where((r) => r.id == id)
                  .firstOrNull;
              return Chip(
                avatar: ribbon?.spriteUrl != null
                    ? CachedNetworkImage(
                        imageUrl: ribbon!.spriteUrl!,
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                        ),
                      )
                    : const Icon(Icons.workspace_premium_rounded, size: 14),
                label: Text(ribbon?.name ?? id),
                visualDensity: VisualDensity.compact,
                labelStyle: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                side: BorderSide(
                    color: colorScheme.outlineVariant, width: 1),
                backgroundColor: colorScheme.surfaceContainerHighest,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
        ],

        // ── Awarded on this slot ──────────────────────────────────────────
        if (_ribbons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_ribbons.length} ribbon${_ribbons.length == 1 ? '' : 's'} awarded',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        for (final category in selectableCatalog) ...[
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
                        errorWidget: (_, _, _) => const Icon(
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
                onSelected: (on) => setState(() {
                    on ? _ribbons.add(r.id) : _ribbons.remove(r.id);
                    _dirty = true;
                  }),
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
            onChanged: () => setState(() => _dirty = true),
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
// ConsumerStatefulWidget so each list tile can watch moveProvider.

class _MovePickerSheet extends ConsumerStatefulWidget {
  final List<String> moves;
  final String? current;
  final String label;
  final Set<String> priorEvoMoves;
  final Set<String> eventMoves;

  const _MovePickerSheet({
    required this.moves,
    required this.label,
    this.current,
    this.priorEvoMoves = const {},
    this.eventMoves = const {},
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
                isPriorEvo: widget.priorEvoMoves.contains(_filtered[i]),
                isEvent: widget.eventMoves.contains(_filtered[i]),
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
  final bool isPriorEvo;
  final bool isEvent;
  final VoidCallback onTap;

  const _MoveListTile({
    required this.moveName,
    required this.isSelected,
    required this.onTap,
    this.isPriorEvo = false,
    this.isEvent = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(moveProvider(moveName));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      selected: isSelected,
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(moveName.toCapitalCase(),
                      style: textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : null),
                      overflow: TextOverflow.ellipsis),
                ),
                if (isPriorEvo) ...[
                  const SizedBox(width: 4),
                  _PreEvoBadge(),
                ],
                if (isEvent) ...[
                  const SizedBox(width: 4),
                  _EventMoveBadge(),
                ],
              ],
            ),
          ),
          detailAsync.when(
            loading: () => const SizedBox(width: 60,
                child: LinearProgressIndicator(minHeight: 2)),
            error: (_, _) => const SizedBox.shrink(),
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

// Small badge shown on prior-evolution-exclusive moves in the picker and slot.
class _PreEvoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Pre-evo',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: colorScheme.onTertiaryContainer,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// Small badge shown on genuine event/gift-Pokémon-exclusive moves (e.g.
// Pokémon Crystal's gift Dratini knowing Extreme Speed) in the picker and slot.
class _EventMoveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Event',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSecondaryContainer,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// Thin progress placeholder shown in place of an ability/item/move
// description while its detail fetch is still in flight — kept as a single
// widget so all three description spots show an identical loading state.
class _DescriptionLoadingBar extends StatelessWidget {
  const _DescriptionLoadingBar();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 8,
        width: 80,
        child: LinearProgressIndicator(),
      );
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
    final detailAsync = ref.watch(itemProvider(itemName));
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
                errorWidget: (_, _, _) => const Icon(Icons.inventory_2_outlined, size: 20),
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

// ── Team-slot destination picker ──────────────────────────────────────────────
//
// Shows a "New team" tile at the top, followed by every existing team that has
// at least one empty slot (1–6). Tapping an empty slot number calls back with
// the team id, slot number, and team name.

class _TeamSlotDestinationSheet extends ConsumerStatefulWidget {
  final String speciesName;
  final VoidCallback onNewTeam;
  final void Function(int teamId, int slotNum, String teamName) onExistingSlot;

  const _TeamSlotDestinationSheet({
    required this.speciesName,
    required this.onNewTeam,
    required this.onExistingSlot,
  });

  @override
  ConsumerState<_TeamSlotDestinationSheet> createState() =>
      _TeamSlotDestinationSheetState();
}

class _TeamSlotDestinationSheetState
    extends ConsumerState<_TeamSlotDestinationSheet> {
  // teamId → set of occupied slot numbers
  Map<int, Set<int>>? _occupiedSlots;
  List<Team>? _teams;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final slotRepo = ref.read(teamSlotRepositoryProvider);

    final teams = await teamRepo.getAll();
    final occupied = <int, Set<int>>{};
    for (final t in teams) {
      final slots = await slotRepo.getByTeam(t.id);
      occupied[t.id] = slots.map((s) => s.slot).toSet();
    }
    if (mounted) setState(() { _teams = teams; _occupiedSlots = occupied; });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Copy to a team slot',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _occupiedSlots == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: scrollCtrl,
                    children: [
                      // ── New team ──
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              colorScheme.primaryContainer,
                          child: Icon(Icons.add_rounded,
                              color: colorScheme.onPrimaryContainer),
                        ),
                        title: Text(
                          '${widget.speciesName} — Journey',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Create new team'),
                        onTap: widget.onNewTeam,
                      ),
                      const Divider(),
                      // ── Existing teams with empty slots ──
                      for (final team in _teams ?? <Team>[]) ...[
                        _buildTeamSection(team, colorScheme, textTheme),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(
      Team team, ColorScheme colorScheme, TextTheme textTheme) {
    final occupied = _occupiedSlots![team.id] ?? <int>{};
    final emptySlots =
        List.generate(6, (i) => i + 1).where((n) => !occupied.contains(n)).toList();

    if (emptySlots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            team.name,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: emptySlots.map((slotNum) {
              return ActionChip(
                label: Text('Slot $slotNum'),
                avatar: const Icon(Icons.add_rounded, size: 16),
                onPressed: () =>
                    widget.onExistingSlot(team.id, slotNum, team.name),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
