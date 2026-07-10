import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart' show SupplementMove;

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

  /// Loads `moves.json`, `items.json`, `abilities.json`, `pokedex.json`, and
  /// `pokedex-gen-overrides.json`. Per-gen `learnset_N.json` files are loaded
  /// lazily via [learnsetForGen] since each can run into the megabytes.
  Future<void> initialize() async {
    if (_initialized) return;

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

/// Gen-accurate base-stat/type override for [speciesPsId] in [gen], read from
/// [PsDataService.pokedexGenOverrides]. Returns null when no override exists
/// for that species in that gen (the common case — most species' stats/types
/// haven't changed across gens).
({Map<String, int> stats, List<String> types})? genAccuratePokedexOverride(
  PsDataService psData,
  String speciesPsId,
  int gen,
) {
  final forGen = psData.pokedexGenOverrides['gen$gen'] as Map<String, dynamic>?;
  final entry = forGen?[speciesPsId] as Map<String, dynamic>?;
  if (entry == null) return null;
  final baseStats = entry['baseStats'] as Map<String, dynamic>?;
  final types = entry['types'] as List?;
  return (
    stats: baseStats == null ? const {} : normalizeShowdownStatKeys(baseStats),
    types: types == null
        ? const []
        : types.cast<String>().map((t) => t.toLowerCase()).toList(),
  );
}

/// Moves [speciesPsId] learns in [gen] per PS's `learnset_N.json` that are
/// NOT already present in [existingMoveNames] (typically the move names
/// PokéAPI already reported) — supplements the offline-fallback movepool the
/// same way the backend's PS learnset merge does server-side.
List<SupplementMove> learnsetSupplementMoves({
  required PsDataService psData,
  required Map<String, dynamic> learnsetForGen,
  required String speciesPsId,
  required int gen,
  required Set<String> existingMoveNames,
}) {
  final entry = learnsetForGen[speciesPsId] as Map<String, dynamic>?;
  if (entry == null) return const [];

  final result = <SupplementMove>[];
  for (final moveEntry in entry.entries) {
    final moveId = moveEntry.key;
    final psMove = psData.moves[moveId] as Map<String, dynamic>?;
    final displayName = psMove?['name'] as String? ?? moveId;
    final slug = psSlugFromDisplayName(displayName);
    if (existingMoveNames.contains(slug)) continue;

    final methods = (moveEntry.value as List<dynamic>)
        .map((m) => (m as Map)['method'] as String? ?? 'unknown')
        .toSet()
        .toList();
    result.add(SupplementMove(
      name: slug,
      displayName: displayName,
      generations: [gen],
      methods: methods,
    ));
  }
  return result;
}

Map<String, dynamic> _decodeJsonStrings(Map<String, String> raw) =>
    raw.map((key, value) => MapEntry(key, jsonDecode(value) as dynamic));

dynamic _decodeJsonString(String raw) => jsonDecode(raw);
