import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart'
    show AbilityInfo, LearnsetSupplementMove, MoveLearnDetail, MoveSummary;

/// Owns loading of the raw Pokémon Showdown data files bundled under
/// `shared/ps_data/` — the same files the backend's `CatalogService` and
/// `PokemonResolverService` read to build their PokéAPI+PS merges.
///
/// This is a raw-data layer only: it exposes decoded JSON maps keyed by PS id
/// (e.g. "thunderbolt", "kingsrock") for `offlineFallback` implementations to
/// read directly. It does not filter, gen-check, or otherwise interpret the
/// data — that responsibility moved to the backend (`CatalogService`,
/// `PokemonResolverService`) and, for the offline path, lives in each
/// provider's own `offlineFallback` closure.
class PsDataService {
  static const _dir = 'shared/ps_data';

  Map<String, dynamic> _moves = const {};
  Map<String, dynamic> _items = const {};
  Map<String, dynamic> _abilities = const {};
  Map<String, dynamic> _pokedex = const {};
  Map<String, dynamic> _pokedexGenOverrides = const {};
  final Map<int, Map<String, dynamic>> _learnsetsByGen = {};
  final Map<int, Future<Map<String, dynamic>>> _learnsetLoads = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;
  Future<void>? _initializeFuture;

  /// Loads `moves.json`, `items.json`, `abilities.json`, `pokedex.json`, and
  /// `pokedex-gen-overrides.json`. Per-gen `learnset_N.json` files are loaded
  /// lazily via [learnsetForGen] since each can run into the megabytes.
  ///
  /// Concurrent callers (e.g. `resolvedPokemonProvider`, `pokemonMovesProvider`,
  /// `pokemonVarietiesProvider`, and `pokemonFormsProvider` all initializing
  /// at once when a detail screen first loads offline) share a single
  /// in-flight load rather than each racing to spawn their own `compute()`
  /// isolate and re-decode the same bundled JSON.
  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializeFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    final raw = await Future.wait([
      rootBundle.loadString('$_dir/moves.json'),
      rootBundle.loadString('$_dir/items.json'),
      rootBundle.loadString('$_dir/abilities.json'),
      rootBundle.loadString('$_dir/pokedex.json'),
      rootBundle.loadString('$_dir/pokedex-gen-overrides.json'),
    ]);

    final decoded = await compute(_decodeJsonStrings, {
      'moves': raw[0],
      'items': raw[1],
      'abilities': raw[2],
      'pokedex': raw[3],
      'pokedexGenOverrides': raw[4],
    });

    _moves = decoded['moves'] as Map<String, dynamic>;
    _items = decoded['items'] as Map<String, dynamic>;
    _abilities = decoded['abilities'] as Map<String, dynamic>;
    _pokedex = decoded['pokedex'] as Map<String, dynamic>;
    _pokedexGenOverrides =
        decoded['pokedexGenOverrides'] as Map<String, dynamic>;
    _initialized = true;
  }

  /// Raw PS move data keyed by PS id (e.g. "thunderbolt"). Each value carries
  /// `name`, `gen`, `type`, `category`, `base_power`, `accuracy`, `pp`,
  /// `priority`, `is_z_move`, `is_max_move`, `flags`, `secondary`,
  /// `z_move_base`.
  Map<String, dynamic> get moves => _moves;

  /// Raw PS item data keyed by PS id. Each value carries `name`, `gen`,
  /// `is_mega_stone`, `mega_species`, `is_z_crystal`, `is_berry`, `is_plate`,
  /// `is_memory`.
  Map<String, dynamic> get items => _items;

  /// Raw PS ability data keyed by PS id. Each value carries `name`, `gen`.
  Map<String, dynamic> get abilities => _abilities;

  /// Raw PS pokedex data keyed by PS species id. Used for gen-accurate
  /// base stat / type overrides in [resolvedPokemonProvider]'s offline path.
  Map<String, dynamic> get pokedex => _pokedex;

  /// Per-gen base stat overrides, keyed `"gen1"`..`"gen9"` then by PS species
  /// id. Supplements [pokedex] for species whose stats changed across gens.
  Map<String, dynamic> get pokedexGenOverrides => _pokedexGenOverrides;

  /// Raw PS learnset data for [gen] (`learnset_N.json`), keyed by PS species
  /// id → move id → list of `{method, level?}` learn-method records. Loaded
  /// and decoded lazily (off the UI isolate) on first request per gen, then
  /// cached for the lifetime of the service.
  Future<Map<String, dynamic>> learnsetForGen(int gen) {
    final cached = _learnsetsByGen[gen];
    if (cached != null) return Future.value(cached);
    return _learnsetLoads.putIfAbsent(gen, () async {
      final raw = await rootBundle.loadString('$_dir/learnset_$gen.json');
      final decoded =
          await compute(_decodeJsonString, raw) as Map<String, dynamic>;
      _learnsetsByGen[gen] = decoded;
      return decoded;
    });
  }
}

/// Converts a display name or PokéAPI slug to PS's no-separator id format,
/// e.g. "Sand Veil" / "sand-veil" -> "sandveil". Mirrors
/// `_ps_id_from_name`/`normalize_ps_id` on the backend so offline-fallback
/// lookups into [PsDataService]'s maps use the same keys the backend does.
String psIdFromName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

final _slugStripRe = RegExp(r"[',.()\[\]]");

/// Best-effort PokéAPI slug from a PS display name — mirrors the backend's
/// `_ps_slug`. e.g. "10,000,000 Volt Thunderbolt" ->
/// "10000000-volt-thunderbolt"; "King's Rock" -> "kings-rock".
String psSlugFromDisplayName(String displayName) {
  final cleaned = displayName.toLowerCase().replaceAll(_slugStripRe, '');
  return cleaned.trim().replaceAll(RegExp(r'\s+'), '-');
}

/// Backend `base_stats` maps use Showdown-style abbreviated keys
/// (`hp`/`atk`/`def`/`spa`/`spd`/`spe`) — converts to the PokéAPI-style full
/// keys [PokemonEntry.stats] expects.
const _statKeyMap = {
  'atk': 'attack',
  'def': 'defense',
  'spa': 'special-attack',
  'spd': 'special-defense',
  'spe': 'speed',
};

Map<String, int> normalizeShowdownStatKeys(Map<String, dynamic> raw) =>
    raw.map((k, v) => MapEntry(_statKeyMap[k] ?? k, (v as num).toInt()));

/// PS ability-slot key ("0"/"1"/"H") → PokéAPI-style slot number (1/2/3) —
/// mirrors the backend's `_PS_TO_SLOT`.
const _kPsToSlot = <String, int>{'0': 1, '1': 2, 'H': 3};

/// Gen-accurate types/base-stats/abilities for [speciesPsId] in [gen],
/// mirroring the backend's `resolve()` step 4 + `_apply_gen_overrides`
/// exactly:
///
/// 1. **Base source**: PS's `pokedex.json` entry for this species is the
///    *primary* source for types/stats/abilities — [rawTypes]/[rawStats]/
///    [rawAbilities] (from PokéAPI) are only used as a fallback when PS has
///    no entry for this species at all (rare — PS's pokedex covers
///    essentially every current species).
/// 2. **Per-gen override cascade**: scans `pokedex-gen-overrides.json` from
///    [gen] upward through 9 for the nearest recorded override, applying it
///    on top of whichever base won *independently per field* — a species
///    can have its types come from a gen5-recorded override while its
///    abilities come from a gen7-recorded override, if that's the nearest
///    each field was ever recorded. This mirrors `_apply_gen_overrides`'
///    per-field `if types is None and "types" in overrides: ...` loop
///    exactly (not a single "first override wins" shortcut).
///
/// [rawAbilities] must be PokéAPI's abilities for the species (used both as
/// the ability-name fallback and, regardless of which source's ability
/// *names* win, as the source of truth for `is_hidden` per PokéAPI slot —
/// same as the backend's `pokeapi_ability_map`).
({List<String> types, Map<String, int> stats, List<AbilityInfo> abilities})
    resolveGenAccuratePokedexData(
  PsDataService psData,
  String speciesPsId,
  int gen, {
  required List<String> rawTypes,
  required Map<String, int> rawStats,
  required List<AbilityInfo> rawAbilities,
}) {
  final baseEntry = psData.pokedex[speciesPsId] as Map<String, dynamic>?;

  final baseEntryTypes = baseEntry?['types'] as List?;
  List<String> types = baseEntryTypes != null
      ? baseEntryTypes.cast<String>().map((t) => t.toLowerCase()).toList()
      : rawTypes;

  final baseEntryStats = baseEntry?['baseStats'] as Map<String, dynamic>?;
  Map<String, int> stats =
      baseEntryStats != null ? normalizeShowdownStatKeys(baseEntryStats) : rawStats;

  final rawAbilitiesMap = {for (final a in rawAbilities) a.slot.toString(): a.name};
  final baseEntryAbilities =
      (baseEntry?['abilities'] as Map<String, dynamic>?)?.cast<String, String>();
  Map<String, String> abilitiesRaw =
      (baseEntryAbilities != null && baseEntryAbilities.isNotEmpty)
          ? baseEntryAbilities
          : rawAbilitiesMap;

  // Independent per-field scan-forward — each field takes the nearest
  // recorded override for that field specifically, not necessarily from the
  // same gen entry as the others.
  List<String>? overrideTypes;
  Map<String, int>? overrideStats;
  Map<String, String>? overrideAbilities;
  for (var scanGen = gen; scanGen <= 9; scanGen++) {
    final overrides = (psData.pokedexGenOverrides['gen$scanGen']
        as Map<String, dynamic>?)?[speciesPsId] as Map<String, dynamic>?;
    if (overrides == null) continue;
    if (overrideTypes == null && overrides.containsKey('types')) {
      overrideTypes =
          (overrides['types'] as List).cast<String>().map((t) => t.toLowerCase()).toList();
    }
    if (overrideStats == null && overrides.containsKey('baseStats')) {
      overrideStats = normalizeShowdownStatKeys(overrides['baseStats'] as Map<String, dynamic>);
    }
    if (overrideAbilities == null && overrides.containsKey('abilities')) {
      overrideAbilities = (overrides['abilities'] as Map<String, dynamic>).cast<String, String>();
    }
    if (overrideTypes != null && overrideStats != null && overrideAbilities != null) break;
  }

  types = overrideTypes ?? types;
  stats = overrideStats ?? stats;
  abilitiesRaw = overrideAbilities ?? abilitiesRaw;

  // Rebuild the typed ability list from whichever raw slot-map won above —
  // mirrors the backend's PS-slot → PokéAPI-slot remap + is_hidden
  // preservation + display-name → slug conversion.
  final isHiddenBySlot = {for (final a in rawAbilities) a.slot.toString(): a.isHidden};
  final abilities = <AbilityInfo>[];
  for (final entry in abilitiesRaw.entries) {
    final pokeApiSlot = _kPsToSlot[entry.key] ?? int.tryParse(entry.key);
    if (pokeApiSlot == null) continue;
    final isHidden = isHiddenBySlot[pokeApiSlot.toString()] ?? (entry.key == 'H');
    final slug = entry.value.toLowerCase().replaceAll(' ', '-');
    abilities.add(AbilityInfo(name: slug, isHidden: isHidden, slot: pokeApiSlot));
  }
  abilities.sort((a, b) => a.slot.compareTo(b.slot));

  return (types: types, stats: stats, abilities: abilities);
}

/// PokéAPI-style slot number (1/2/3) → PS ability-slot key ("0"/"1"/"H") —
/// the inverse of [_kPsToSlot]. Used to re-encode a resolved [AbilityInfo]
/// list back into the PS-slot-keyed map shape `VarietyBackendData.abilities`
/// expects (e.g. `{"0": "blaze", "H": "solar-power"}`).
const _kSlotToPs = <int, String>{1: '0', 2: '1', 3: 'H'};

/// Converts a resolved [AbilityInfo] list back into a PS-slot-keyed
/// `{"0"/"1"/"H": displayName}` map — the format `VarietyBackendData.abilities`
/// and its consumers (e.g. `slot_config_screen.dart`) expect. Display names
/// are title-cased from the slug (PokéAPI slugs and PS display names only
/// differ in casing/hyphenation for ability names).
Map<String, String> abilityInfoListToPsSlotMap(List<AbilityInfo> abilities) => {
      for (final a in abilities)
        (_kSlotToPs[a.slot] ?? a.slot.toString()): a.name
            .split('-')
            .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
            .join(' '),
    };

/// National dex number → introducing generation, mirrors the backend's
/// `_GEN_RANGES`/`_num_to_gen`.
const _kGenRanges = <(int, int)>[
  (151, 1), (251, 2), (386, 3), (493, 4), (649, 5),
  (721, 6), (809, 7), (905, 8), (10000, 9),
];

int _numToGen(int num) {
  for (final (limit, gen) in _kGenRanges) {
    if (num <= limit) return gen;
  }
  return 9;
}

/// Name-pattern → introduction gen for variety forms — mirrors the backend's
/// `_VARIETY_GEN_PATTERNS`. Checked in order; first match wins.
const _kVarietyGenPatterns = <(String, int)>[
  ('-mega', 6), ('-primal', 6),
  ('-alola', 7), ('-totem', 7),
  ('-galar', 8), ('-gmax', 8), ('-eternamax', 8), ('-hisui', 8),
  ('-paldea', 9),
];

/// Returns the generation [varietyName] was introduced in — mirrors the
/// backend's `_variety_intro_gen` exactly: known name patterns (megas in gen
/// 6, Alolan forms in gen 7, etc.) take priority; battle-state/origin forms
/// with no matching pattern (Zen Darmanitan, Aegislash-Blade, ...) fall back
/// to the base species' own introducing gen via [baseNum].
int varietyIntroGen(String varietyName, int? baseNum) {
  for (final (pattern, gen) in _kVarietyGenPatterns) {
    if (varietyName.contains(pattern)) return gen;
  }
  return _numToGen(baseNum ?? 0);
}

/// Maps raw `learnset_N.json` method strings to the intermediate label used
/// by [_kSupplementMethodPriority]/[_kSupplementToPokeApiMethod] — mirrors
/// the backend's `_LEARNSET_METHOD_LABEL`. Unknown raw methods pass through
/// unchanged, same as the backend's `.get(raw, raw)` fallback.
const _kLearnsetMethodLabel = <String, String>{
  'level_up': 'level',
  'machine': 'machine',
  'egg': 'egg',
  'tutor': 'tutor',
  'relearn': 'relearn',
  'event': 'event',
  'transfer': 'transfer',
  'other': 'other',
};

/// Priority order for picking the "best" method when a supplement move has
/// sources under several learn methods — mirrors the backend's
/// `_SUPPLEMENT_METHOD_PRIORITY` (lower = higher priority; unknown methods
/// sort last, same as the backend's `.get(m, 99)` fallback).
const _kSupplementMethodPriority = <String, int>{
  'level': 0,
  'machine': 1,
  'egg': 2,
  'tutor': 3,
  'event': 4,
  'relearn': 5,
  'transfer': 6,
  'other': 7,
};

/// Maps the intermediate label to the PokéAPI-style method string used in
/// [MoveLearnDetail.method] — mirrors the backend's
/// `_SUPPLEMENT_TO_POKEAPI_METHOD`.
const _kSupplementToPokeApiMethod = <String, String>{
  'level': 'level-up',
  'machine': 'machine',
  'egg': 'egg',
  'tutor': 'tutor',
  'event': 'event',
  'relearn': 'level-up',
  'transfer': 'transfer',
  'other': 'other',
};

/// Moves [speciesPsId] learns in [gen] per PS's `learnset_N.json` that are
/// NOT already present in [existingMoveNames] (typically the move names
/// PokéAPI already reported) — supplements the offline-fallback movepool the
/// same way the backend's PS learnset merge does server-side.
///
/// [LearnsetSupplementMove.methods] holds the *intermediate* labels (e.g. `"level"`,
/// not raw `"level_up"` or PokéAPI-style `"level-up"`) — mirrors the
/// backend's `EventMove.methods`. Use [supplementMoveToMoveSummary] to
/// convert to a displayable [MoveSummary] the same way the backend's
/// `_event_move_to_summary` does.
List<LearnsetSupplementMove> learnsetSupplementMoves({
  required PsDataService psData,
  required Map<String, dynamic> learnsetForGen,
  required String speciesPsId,
  required int gen,
  required Set<String> existingMoveNames,
}) {
  final entry = learnsetForGen[speciesPsId] as Map<String, dynamic>?;
  if (entry == null) return const [];

  final result = <LearnsetSupplementMove>[];
  for (final moveEntry in entry.entries) {
    final moveId = moveEntry.key;
    final psMove = psData.moves[moveId] as Map<String, dynamic>?;
    final displayName = psMove?['name'] as String? ?? moveId;
    final slug = psSlugFromDisplayName(displayName);
    if (existingMoveNames.contains(slug)) continue;

    final sources = moveEntry.value as List<dynamic>;
    final methods = sources
        .map((m) {
          final raw = (m as Map)['method'] as String? ?? 'other';
          return _kLearnsetMethodLabel[raw] ?? raw;
        })
        .toSet()
        .toList()
      ..sort();

    // Mirrors the backend's `_get_supplement_moves`: the first source with a
    // `via_prevo` entry (a prevo species PS id string) wins — PokéAPI may not
    // list a move on the evolved form when it's only inherited pre-evolution.
    var viaPrevo = false;
    String? prevo;
    for (final src in sources) {
      final vp = (src as Map)['via_prevo'] as String?;
      if (vp != null && !viaPrevo) {
        viaPrevo = true;
        prevo = vp;
      }
    }

    result.add(LearnsetSupplementMove(
      name: slug,
      displayName: displayName,
      generations: [gen],
      methods: methods,
      viaPrevo: viaPrevo,
      prevo: prevo,
    ));
  }
  return result;
}

/// Converts a [LearnsetSupplementMove] into a single-entry [MoveSummary], picking
/// the highest-priority method the same way the backend's
/// `_event_move_to_summary` does, rather than emitting one
/// [MoveLearnDetail] per method — a move with both `"level"` and `"event"`
/// sources is correctly bucketed as `level-up`, not `event` (event is
/// priority 4, well below level/machine/egg/tutor).
MoveSummary supplementMoveToMoveSummary(LearnsetSupplementMove move, String versionGroup) {
  final sortedMethods = List<String>.of(move.methods)
    ..sort((a, b) => (_kSupplementMethodPriority[a] ?? 99)
        .compareTo(_kSupplementMethodPriority[b] ?? 99));
  final bestLabel = sortedMethods.isNotEmpty ? sortedMethods.first : 'event';
  final method = _kSupplementToPokeApiMethod[bestLabel] ?? bestLabel;
  return MoveSummary(
    name: move.name,
    learnDetails: [
      MoveLearnDetail(
        versionGroup: versionGroup,
        method: method,
        level: null,
        viaPrev: move.viaPrevo,
        prevo: move.prevo,
      ),
    ],
  );
}

Map<String, dynamic> _decodeJsonStrings(Map<String, String> raw) =>
    raw.map((key, value) => MapEntry(key, jsonDecode(value) as dynamic));

dynamic _decodeJsonString(String raw) => jsonDecode(raw);
