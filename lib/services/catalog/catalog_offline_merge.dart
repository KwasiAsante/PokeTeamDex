import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_service.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Offline-fallback catalog builders for [movesListProvider]/[itemsListProvider]/
/// [abilitiesListProvider]. Replicate the backend's `CatalogService._preload_kind`
/// merge client-side: enumerate every name from PokéAPI (the authoritative
/// source for which entries exist), fetch each concurrently, enrich with
/// bundled PS data where available, then append PS-only entries (Z-moves,
/// Max moves, etc.) that have no PokéAPI page of their own. If PokéAPI's name
/// list itself is unreachable, falls back further to a PS-data-only catalog
/// (mirrors `_preload_kind`'s `if not names:` branch) rather than failing —
/// every PS id is tracked as it's matched to a PokéAPI entry so that pass
/// never double-adds an entry whose PS display-name slug differs from
/// PokéAPI's canonical name for the same move/item/ability.
///
/// Only runs when the backend is unreachable AND no usable cache entry
/// exists — the per-entry PokéAPI fetches (~900 moves, ~2100 items, ~300
/// abilities) are expensive, which is why [withBackendFallback] caches the
/// result for 24h once built.
const _kRomanToGen = {
  'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5,
  'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9,
};

int? _genFromGenerationName(String? generationName) {
  if (generationName == null) return null;
  return _kRomanToGen[generationName.split('-').last];
}

final _variantSuffixRe = RegExp(r'--\w+$');
String _stripVariantSuffix(String name) => name.replaceAll(_variantSuffixRe, '');

String _titleCaseSlug(String slug) => slug
    .split('-')
    .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

/// Runs [fn] over [items] with at most [limit] concurrent in-flight calls.
Future<List<R>> _mapBounded<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item) fn,
) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= items.length) return;
      results[i] = await fn(items[i]);
    }
  }

  final workerCount = items.isEmpty ? 0 : limit.clamp(1, items.length);
  await Future.wait(List.generate(workerCount, (_) => worker()));
  return results.cast<R>();
}

/// Enumerates a PokéAPI name list, mirroring the backend's
/// `_fetch_pokeapi_names` — returns `[]` on any failure (network error, bad
/// response) rather than throwing, so callers can fall back to a
/// PS-only-enumeration build instead of failing outright.
Future<List<String>> _fetchNamesOrEmpty(Future<List<String>> Function() fetch) async {
  try {
    return await fetch();
  } catch (_) {
    return const [];
  }
}

Future<List<BackendMoveEntry>> buildOfflineMoveCatalog(
  PokeApiRepository pokeApi,
  PsDataService psData,
) async {
  await psData.initialize();
  final names = await _fetchNamesOrEmpty(pokeApi.fetchMoveList);
  final results = <String, BackendMoveEntry>{};

  if (names.isEmpty) {
    // PokéAPI's move list is unreachable — build from PS data alone rather
    // than returning nothing, mirroring the backend's `_preload_kind`.
    for (final entry in psData.moves.entries) {
      final raw = entry.value as Map<String, dynamic>;
      final displayName = raw['name'] as String? ?? entry.key;
      final slug = psSlugFromDisplayName(displayName);
      results[slug] = _mergeMove(raw, null, slug);
    }
    AppLogger().w(
        '[catalog offline] move list unavailable; built ${results.length} entries from PS data only');
    return results.values.toList();
  }

  final zVaries = <String>{};
  final zVariesRe = RegExp(r'^(.+)--(?:physical|special)$');
  for (final n in names) {
    final m = zVariesRe.firstMatch(n);
    if (m != null) zVaries.add(m.group(1)!);
  }

  final fetched = await _mapBounded<String, MoveEntry?>(names, 20, (name) async {
    try {
      return await pokeApi.fetchMove(name);
    } catch (_) {
      return null;
    }
  });

  // Tracks PS ids already merged from a PokéAPI match, keyed independently
  // of the resulting entry name — a PS raw entry's own display-name slug can
  // diverge from PokéAPI's canonical name for the same move, so name-only
  // dedup below isn't enough to prevent a duplicate.
  final coveredPsIds = <String>{};
  for (final moveEntry in fetched) {
    if (moveEntry == null) continue;
    final canonicalName = _stripVariantSuffix(moveEntry.name);
    if (results.containsKey(canonicalName)) continue;
    final psId = psIdFromName(canonicalName);
    coveredPsIds.add(psId);
    final raw = psData.moves[psId] as Map<String, dynamic>?;
    results[canonicalName] = _mergeMove(raw, moveEntry, canonicalName);
  }

  for (final entry in psData.moves.entries) {
    if (coveredPsIds.contains(entry.key)) continue;
    final raw = entry.value as Map<String, dynamic>;
    final displayName = raw['name'] as String? ?? entry.key;
    final slug = psSlugFromDisplayName(displayName);
    if (results.containsKey(slug)) continue;
    results[slug] = _mergeMove(raw, null, slug);
  }

  for (final baseName in zVaries) {
    final entry = results[baseName];
    if (entry != null) results[baseName] = _withDamageClass(entry, 'varies');
  }

  AppLogger().d('[catalog offline] built ${results.length} move entries');
  return results.values.toList();
}

BackendMoveEntry _mergeMove(
  Map<String, dynamic>? raw,
  MoveEntry? pokeApiEntry,
  String slug,
) {
  final displayName = raw?['name'] as String? ?? _titleCaseSlug(slug);
  var gen = (raw?['gen'] as num?)?.toInt() ?? 1;
  String? type = raw?['type'] as String?;
  int? power = (raw?['base_power'] as num?)?.toInt();
  int? accuracy = (raw?['accuracy'] as num?)?.toInt();
  int? pp = (raw?['pp'] as num?)?.toInt();
  var priority = (raw?['priority'] as num?)?.toInt() ?? 0;
  var damageClass = (raw?['category'] as String?)?.toLowerCase() ?? 'status';
  final isZMove = raw?['is_z_move'] as bool? ?? false;
  final isMaxMove = raw?['is_max_move'] as bool? ?? false;
  String? contestType;
  String? target;
  String? effectShort;

  if (pokeApiEntry != null) {
    damageClass = pokeApiEntry.damageClass ?? damageClass;
    gen = _genFromGenerationName(pokeApiEntry.generationName) ?? gen;
    contestType = pokeApiEntry.contestTypeName;
    target = pokeApiEntry.targetName;
    effectShort = pokeApiEntry.shortEffect;
    type ??= pokeApiEntry.typeName;
    power ??= pokeApiEntry.power;
    accuracy ??= pokeApiEntry.accuracy;
    pp ??= pokeApiEntry.pp;
    if (priority == 0) priority = pokeApiEntry.priority;
  }

  // Z-moves and Max/G-max moves are tied to a single generation by game
  // mechanics — more reliable than PokéAPI's generation field, which many of
  // them don't even have a resource for.
  if (isZMove) gen = 7;
  if (isMaxMove) gen = 8;

  final flagsRaw = raw?['flags'];
  final flags = flagsRaw is Map
      ? flagsRaw.map((k, v) => MapEntry(k as String, (v as num).toInt()))
      : const <String, int>{};

  return BackendMoveEntry(
    name: slug,
    displayName: displayName,
    gen: gen,
    type: (type ?? 'normal').toLowerCase(),
    damageClass: damageClass,
    power: power,
    accuracy: accuracy,
    pp: pp,
    priority: priority,
    isZMove: isZMove,
    isMaxMove: isMaxMove,
    zMoveBase: raw?['z_move_base'] as String?,
    flags: flags,
    secondary: raw?['secondary'] as Map<String, dynamic>?,
    contestType: contestType,
    target: target,
    effectShort: effectShort,
  );
}

BackendMoveEntry _withDamageClass(BackendMoveEntry entry, String damageClass) => BackendMoveEntry(
      pokeApiId: entry.pokeApiId,
      name: entry.name,
      displayName: entry.displayName,
      gen: entry.gen,
      type: entry.type,
      damageClass: damageClass,
      power: entry.power,
      accuracy: entry.accuracy,
      pp: entry.pp,
      priority: entry.priority,
      isZMove: entry.isZMove,
      isMaxMove: entry.isMaxMove,
      zMoveBase: entry.zMoveBase,
      flags: entry.flags,
      secondary: entry.secondary,
      contestType: entry.contestType,
      target: entry.target,
      effectShort: entry.effectShort,
      effect: entry.effect,
    );

Future<List<BackendItemEntry>> buildOfflineItemCatalog(
  PokeApiRepository pokeApi,
  PsDataService psData,
) async {
  await psData.initialize();
  final names = await _fetchNamesOrEmpty(pokeApi.fetchItemList);
  final results = <String, BackendItemEntry>{};

  if (names.isEmpty) {
    for (final entry in psData.items.entries) {
      final raw = entry.value as Map<String, dynamic>;
      final displayName = raw['name'] as String? ?? entry.key;
      final slug = psSlugFromDisplayName(displayName);
      results[slug] = _mergeItem(raw, null, slug);
    }
    AppLogger().w(
        '[catalog offline] item list unavailable; built ${results.length} entries from PS data only');
    return results.values.toList();
  }

  final fetched = await _mapBounded<String, ItemEntry?>(names, 20, (name) async {
    try {
      return await pokeApi.fetchItem(name);
    } catch (_) {
      return null;
    }
  });

  final coveredPsIds = <String>{};
  for (final itemEntry in fetched) {
    if (itemEntry == null) continue;
    final canonicalName = _stripVariantSuffix(itemEntry.name);
    if (results.containsKey(canonicalName)) continue;
    final psId = psIdFromName(canonicalName);
    coveredPsIds.add(psId);
    final raw = psData.items[psId] as Map<String, dynamic>?;
    results[canonicalName] = _mergeItem(raw, itemEntry, canonicalName);
  }

  for (final entry in psData.items.entries) {
    if (coveredPsIds.contains(entry.key)) continue;
    final raw = entry.value as Map<String, dynamic>;
    final displayName = raw['name'] as String? ?? entry.key;
    final slug = psSlugFromDisplayName(displayName);
    if (results.containsKey(slug)) continue;
    results[slug] = _mergeItem(raw, null, slug);
  }

  AppLogger().d('[catalog offline] built ${results.length} item entries');
  return results.values.toList();
}

BackendItemEntry _mergeItem(
  Map<String, dynamic>? raw,
  ItemEntry? pokeApiEntry,
  String slug,
) {
  final displayName = raw?['name'] as String? ?? _titleCaseSlug(slug);
  // Items have no reliable PokéAPI generation field — PS's `gen` is the
  // authoritative source (see backend `_pokeapi_gen` doc comment).
  final gen = (raw?['gen'] as num?)?.toInt() ?? 1;
  final megaSpeciesRaw = raw?['mega_species'] as Map<String, dynamic>?;

  return BackendItemEntry(
    name: slug,
    displayName: displayName,
    gen: gen,
    category: pokeApiEntry?.category,
    sprite: pokeApiEntry?.spriteUrl,
    flingPower: pokeApiEntry?.flingPower,
    isMegaStone: raw?['is_mega_stone'] as bool? ?? false,
    megaSpecies: megaSpeciesRaw?.map((k, v) => MapEntry(k, v as String)),
    isZCrystal: raw?['is_z_crystal'] as bool? ?? false,
    isBerry: raw?['is_berry'] as bool? ?? false,
    isPlate: raw?['is_plate'] as bool? ?? false,
    isMemory: raw?['is_memory'] as bool? ?? false,
    effectShort: pokeApiEntry?.shortEffect,
    effect: pokeApiEntry?.longEffect,
  );
}

Future<List<BackendAbilityEntry>> buildOfflineAbilityCatalog(
  PokeApiRepository pokeApi,
  PsDataService psData,
) async {
  await psData.initialize();
  final names = await _fetchNamesOrEmpty(pokeApi.fetchAbilityList);
  final results = <String, BackendAbilityEntry>{};

  if (names.isEmpty) {
    for (final entry in psData.abilities.entries) {
      final raw = entry.value as Map<String, dynamic>;
      final displayName = raw['name'] as String? ?? entry.key;
      final slug = psSlugFromDisplayName(displayName);
      results[slug] = _mergeAbility(raw, null, slug);
    }
    AppLogger().w(
        '[catalog offline] ability list unavailable; built ${results.length} entries from PS data only');
    return results.values.toList();
  }

  final fetched = await _mapBounded<String, AbilityEntry?>(names, 20, (name) async {
    try {
      return await pokeApi.fetchAbility(name);
    } catch (_) {
      return null;
    }
  });

  final coveredPsIds = <String>{};
  for (final abilityEntry in fetched) {
    if (abilityEntry == null) continue;
    final canonicalName = abilityEntry.name;
    if (results.containsKey(canonicalName)) continue;
    final psId = psIdFromName(canonicalName);
    coveredPsIds.add(psId);
    final raw = psData.abilities[psId] as Map<String, dynamic>?;
    results[canonicalName] = _mergeAbility(raw, abilityEntry, canonicalName);
  }

  for (final entry in psData.abilities.entries) {
    if (coveredPsIds.contains(entry.key)) continue;
    final raw = entry.value as Map<String, dynamic>;
    final displayName = raw['name'] as String? ?? entry.key;
    final slug = psSlugFromDisplayName(displayName);
    if (results.containsKey(slug)) continue;
    results[slug] = _mergeAbility(raw, null, slug);
  }

  AppLogger().d('[catalog offline] built ${results.length} ability entries');
  return results.values.toList();
}

BackendAbilityEntry _mergeAbility(
  Map<String, dynamic>? raw,
  AbilityEntry? pokeApiEntry,
  String slug,
) {
  final displayName = raw?['name'] as String? ?? _titleCaseSlug(slug);
  var gen = (raw?['gen'] as num?)?.toInt() ?? 3;
  if (pokeApiEntry != null) {
    gen = _genFromGenerationName(pokeApiEntry.generationName) ?? gen;
  }

  return BackendAbilityEntry(
    name: slug,
    displayName: displayName,
    gen: gen,
    effectShort: pokeApiEntry?.shortEffect,
    effect: pokeApiEntry?.longEffect,
  );
}
