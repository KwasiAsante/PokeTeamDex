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
import 'package:poke_team_dex/features/teams/presentation/team_detail_screen.dart'
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

  const SlotConfigScreen({
    super.key,
    required this.teamId,
    required this.slotNumber,
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
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    for (final c in _evCtrls) { c.dispose(); }
    for (final c in _ivCtrls) { c.dispose(); }
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
    _natureName   = slot.natureName;
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
        const SnackBar(content: Text('EV total exceeds 510 — reduce before saving.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final evs = _evCtrls.map((c) => (int.tryParse(c.text) ?? 0).clamp(0, 252)).toList();
      final ivs = _ivCtrls.map((c) => (int.tryParse(c.text) ?? 31).clamp(0, 31)).toList();
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Pre-load item list so the picker is instant when the user taps.
    ref.watch(_itemListProvider);

    final slotsAsync = ref.watch(teamSlotsProvider(widget.teamId));
    return slotsAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (slots) {
        final slot = slots.where((s) => s.slot == widget.slotNumber).firstOrNull;
        if (slot == null) {
          // Only pop if we were already showing data — this guards against the
          // race where the stream emits before the insert is visible (e.g. when
          // navigating here immediately after the slot picker creates the row).
          if (_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.canPop()) context.pop();
            });
          }
          return Scaffold(
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
    final pokemonAsync = ref.watch(pokemonDetailProvider(slot.pokemonId));
    return pokemonAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
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
        final violations = format != null
            ? _computeViolations(formatService, format, pokemon.name, pokemonMoves)
            : <String, String>{};

        // Learnable moves filtered by format version groups.
        // No format → show everything the Pokémon can ever learn.
        final learnableMoves = (format != null
                ? buildLearnsetForFormat(pokemonMoves, format)
                : pokemon.moves
                    .map((m) => m['move']['name'] as String)
                    .toSet())
            .toList()
          ..sort();

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

        return Scaffold(
          appBar: AppBar(
            title: Text('Slot ${widget.slotNumber} — $speciesName'),
            actions: [
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(slot, spriteUrls, mechanics),
                const SizedBox(height: 24),
                _buildBasics(mechanics),
                // ── Ability (Gen 3+) ──
                if (mechanics == null || mechanics.hasAbilities) ...[
                  const SizedBox(height: 24),
                  _SectionTitle('Ability'),
                  const SizedBox(height: 8),
                  _buildAbility(abilities, violations['ability']),
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
                  _buildHeldItem(violation: violations['item']),
                ],
                const SizedBox(height: 24),
                _SectionTitle('Moves'),
                const SizedBox(height: 8),
                _buildMoves(learnableMoves, violations: violations),
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
                const SizedBox(height: 24),
                _SectionTitle('Stat Preview (Lv $_level)'),
                const SizedBox(height: 8),
                _buildStatPreview(baseStats, mechanics),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    TeamSlot slot,
    ({String? defaultUrl, String? shinyUrl}) spriteUrls,
    GenerationMechanics? mechanics,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            PokemonSprite(
              defaultUrl: spriteUrls.defaultUrl,
              shinyUrl: spriteUrls.shinyUrl,
              shiny: _isShiny,
              size: 140,
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
                    _heldItemName?.toCapitalCase() ?? '— None —',
                    style: textTheme.bodyMedium,
                  ),
                ),
                if (_heldItemName != null) ...[
                  GestureDetector(
                    onTap: () => context.push('/items/$_heldItemName'),
                    child: Icon(Icons.info_outline,
                        size: 18,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _heldItemName = null),
                    child: const Icon(Icons.clear, size: 18),
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
                      // Inline type + stats when selected
                      if (moveDetail != null) ...[
                        if (moveDetail.typeName != null)
                          TypeBadge(type: moveDetail.typeName!),
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
                        GestureDetector(
                          onTap: () => context.push('/moves/${_moves[i]}'),
                          child: Icon(Icons.info_outline,
                              size: 18,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 2),
                      ],
                      if (_moves[i] != null)
                        GestureDetector(
                          onTap: () => setState(() => _moves[i] = null),
                          child: const Icon(Icons.clear, size: 18),
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
    final items = ref.read(_itemListProvider).asData?.value ?? [];
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemPickerSheet(items: items, current: _heldItemName),
    );
    if (result != null) setState(() => _heldItemName = result);
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
    final description = entry?.shortEffect;

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
      title: Text(itemName.toCapitalCase(),
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
