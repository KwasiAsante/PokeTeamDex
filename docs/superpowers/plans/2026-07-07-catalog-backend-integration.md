# Catalog Backend Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up backend catalog endpoints (`/moves`, `/items`, `/abilities`) as the primary data source for the moves, items, and abilities list providers, with PokéAPI as a fallback.

**Architecture:** Add `BackendMoveEntry`, `BackendItemEntry`, and `BackendAbilityEntry` models in a new `lib/services/catalog/` directory. Extend `PokemonBackendRepository` with 6 new fetch methods following the existing pattern. Replace `movesListProvider`, `itemsListProvider`, and `abilitiesListProvider` with backend-first equivalents; update the filtered providers to do client-side filtering on the richer entry fields. All filtered providers keep their existing `AsyncValue<List<String>>` return type so the screens need no changes.

**Tech Stack:** Dart / Flutter, Riverpod (`FutureProvider`, `Provider`, `StateProvider`), Dio, mocktail (tests), `flutter_test`

## Global Constraints

- Follow existing `pokemon_backend_repository.dart` pattern: `_apiClient.dio.get(...)`, throw descriptive `Exception` on non-200.
- Fallback entries (`fromName` constructor) use `gen: 0` / `type: ''` / `damageClass: ''` as sentinels — filtered providers treat empty strings as "no metadata, pass filter" to avoid blank lists when backend is unavailable.
- All filtered providers keep their existing return type `AsyncValue<List<String>>` — no screen changes required.
- `pageSize: 1000` for all list fetch calls (fetch the full catalog in one request).
- Tests use `mocktail` + `MockDio` + `MockApiClient` pattern from `test/services/pokemon_resolved/pokemon_backend_repository_test.dart`.
- Provider tests use `ProviderContainer(overrides: [...])` pattern from `test/services/pokemon_resolved/resolved_pokemon_provider_test.dart`.
- Run tests with: `flutter test <path>`

---

### Task 1: Catalog models

**Files:**
- Create: `lib/services/catalog/catalog_models.dart`
- Test: `test/services/catalog/catalog_models_test.dart`

**Interfaces:**
- Produces:
  - `class BackendMoveEntry` — `fromJson(Map<String,dynamic>)`, `fromName(String)`, fields: `name`, `displayName`, `gen`, `type`, `damageClass`, `power`, `accuracy`, `pp`, `priority`, `isZMove`, `isMaxMove`, `zMoveBase`, `flags`, `contestType`, `target`, `effectShort`, `effect`
  - `class BackendItemEntry` — `fromJson(Map<String,dynamic>)`, `fromName(String)`, fields: `name`, `displayName`, `gen`, `category`, `sprite`, `flingPower`, `isMegaStone`, `megaSpecies`, `isZCrystal`, `isBerry`, `isPlate`, `isMemory`, `effectShort`, `effect`
  - `class BackendAbilityEntry` — `fromJson(Map<String,dynamic>)`, `fromName(String)`, fields: `name`, `displayName`, `gen`, `effectShort`, `effect`, `slot`, `isHidden`
  - `class PaginatedCatalogResponse<T>` — `fromJson(Map<String,dynamic>, T Function(dynamic) fromItem)`, fields: `items`, `total`, `page`, `pageSize`, `totalPages`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/catalog/catalog_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';

void main() {
  group('BackendMoveEntry', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'thunderbolt',
        'display_name': 'Thunderbolt',
        'gen': 1,
        'type': 'electric',
        'damage_class': 'special',
        'power': 90,
        'accuracy': 100,
        'pp': 15,
        'priority': 0,
        'is_z_move': false,
        'is_max_move': false,
        'z_move_base': null,
        'flags': {'contact': 0},
        'secondary': null,
        'contest_type': 'cool',
        'target': 'selected-pokemon',
        'effect_short': 'May paralyze target.',
        'effect': 'May paralyze the target.',
      };
      final entry = BackendMoveEntry.fromJson(json);
      expect(entry.name, 'thunderbolt');
      expect(entry.displayName, 'Thunderbolt');
      expect(entry.gen, 1);
      expect(entry.type, 'electric');
      expect(entry.damageClass, 'special');
      expect(entry.power, 90);
      expect(entry.accuracy, 100);
      expect(entry.pp, 15);
      expect(entry.isZMove, false);
      expect(entry.isMaxMove, false);
      expect(entry.effectShort, 'May paralyze target.');
    });

    test('fromName creates sentinel entry', () {
      final entry = BackendMoveEntry.fromName('fire-blast');
      expect(entry.name, 'fire-blast');
      expect(entry.displayName, 'Fire Blast');
      expect(entry.gen, 0);
      expect(entry.type, '');
      expect(entry.damageClass, '');
    });
  });

  group('BackendItemEntry', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'leftovers',
        'display_name': 'Leftovers',
        'gen': 2,
        'category': 'held-items',
        'sprite': 'https://example.com/leftovers.png',
        'fling_power': 10,
        'is_mega_stone': false,
        'mega_species': null,
        'is_z_crystal': false,
        'is_berry': false,
        'is_plate': false,
        'is_memory': false,
        'effect_short': 'Restores 1/16 HP.',
        'effect': 'Restores 1/16 HP each turn.',
      };
      final entry = BackendItemEntry.fromJson(json);
      expect(entry.name, 'leftovers');
      expect(entry.gen, 2);
      expect(entry.category, 'held-items');
      expect(entry.isBerry, false);
      expect(entry.effectShort, 'Restores 1/16 HP.');
    });

    test('fromName creates sentinel entry', () {
      final entry = BackendItemEntry.fromName('master-ball');
      expect(entry.name, 'master-ball');
      expect(entry.displayName, 'Master Ball');
      expect(entry.gen, 0);
      expect(entry.category, null);
    });
  });

  group('BackendAbilityEntry', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'blaze',
        'display_name': 'Blaze',
        'gen': 3,
        'effect_short': 'Powers up Fire moves in a pinch.',
        'effect': 'Powers up Fire-type moves in a pinch.',
        'slot': null,
        'is_hidden': false,
      };
      final entry = BackendAbilityEntry.fromJson(json);
      expect(entry.name, 'blaze');
      expect(entry.gen, 3);
      expect(entry.effectShort, 'Powers up Fire moves in a pinch.');
      expect(entry.isHidden, false);
    });

    test('fromName creates sentinel entry', () {
      final entry = BackendAbilityEntry.fromName('levitate');
      expect(entry.name, 'levitate');
      expect(entry.displayName, 'Levitate');
      expect(entry.gen, 0);
    });
  });

  group('PaginatedCatalogResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'items': [
          {'name': 'tackle', 'display_name': 'Tackle', 'gen': 1,
           'type': 'normal', 'damage_class': 'physical',
           'power': 40, 'accuracy': 100, 'pp': 35, 'priority': 0,
           'is_z_move': false, 'is_max_move': false, 'flags': {}},
        ],
        'total': 1, 'page': 1, 'page_size': 1, 'total_pages': 1,
      };
      final response = PaginatedCatalogResponse.fromJson(
          json, (item) => BackendMoveEntry.fromJson(item as Map<String, dynamic>));
      expect(response.items.length, 1);
      expect(response.items[0].name, 'tackle');
      expect(response.total, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/services/catalog/catalog_models_test.dart
```
Expected: FAIL — `catalog_models.dart` does not exist yet.

- [ ] **Step 3: Create the catalog models file**

```dart
// lib/services/catalog/catalog_models.dart

String _titleCase(String slug) => slug
    .split('-')
    .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

class BackendMoveEntry {
  final String name;
  final String displayName;
  final int gen;
  final String type;
  final String damageClass;
  final int? power;
  final int? accuracy;
  final int? pp;
  final int priority;
  final bool isZMove;
  final bool isMaxMove;
  final String? zMoveBase;
  final Map<String, int> flags;
  final Map<String, dynamic>? secondary;
  final String? contestType;
  final String? target;
  final String? effectShort;
  final String? effect;

  const BackendMoveEntry({
    required this.name,
    required this.displayName,
    required this.gen,
    required this.type,
    required this.damageClass,
    this.power,
    this.accuracy,
    this.pp,
    this.priority = 0,
    this.isZMove = false,
    this.isMaxMove = false,
    this.zMoveBase,
    this.flags = const {},
    this.secondary,
    this.contestType,
    this.target,
    this.effectShort,
    this.effect,
  });

  factory BackendMoveEntry.fromJson(Map<String, dynamic> json) =>
      BackendMoveEntry(
        name: json['name'] as String,
        displayName: json['display_name'] as String? ?? _titleCase(json['name'] as String),
        gen: (json['gen'] as num?)?.toInt() ?? 0,
        type: (json['type'] as String? ?? '').toLowerCase(),
        damageClass: (json['damage_class'] as String? ?? '').toLowerCase(),
        power: (json['power'] as num?)?.toInt(),
        accuracy: (json['accuracy'] as num?)?.toInt(),
        pp: (json['pp'] as num?)?.toInt(),
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        isZMove: json['is_z_move'] as bool? ?? false,
        isMaxMove: json['is_max_move'] as bool? ?? false,
        zMoveBase: json['z_move_base'] as String?,
        flags: (json['flags'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        secondary: json['secondary'] as Map<String, dynamic>?,
        contestType: json['contest_type'] as String?,
        target: json['target'] as String?,
        effectShort: json['effect_short'] as String?,
        effect: json['effect'] as String?,
      );

  // Used when backend is unavailable — gen/type/damageClass are empty sentinels.
  // filteredMovesProvider treats empty type/damageClass as "pass all filters".
  factory BackendMoveEntry.fromName(String name) => BackendMoveEntry(
        name: name,
        displayName: _titleCase(name),
        gen: 0,
        type: '',
        damageClass: '',
      );
}

class BackendItemEntry {
  final String name;
  final String displayName;
  final int gen;
  final String? category;
  final String? sprite;
  final int? flingPower;
  final bool isMegaStone;
  final Map<String, String>? megaSpecies;
  final bool isZCrystal;
  final bool isBerry;
  final bool isPlate;
  final bool isMemory;
  final String? effectShort;
  final String? effect;

  const BackendItemEntry({
    required this.name,
    required this.displayName,
    required this.gen,
    this.category,
    this.sprite,
    this.flingPower,
    this.isMegaStone = false,
    this.megaSpecies,
    this.isZCrystal = false,
    this.isBerry = false,
    this.isPlate = false,
    this.isMemory = false,
    this.effectShort,
    this.effect,
  });

  factory BackendItemEntry.fromJson(Map<String, dynamic> json) =>
      BackendItemEntry(
        name: json['name'] as String,
        displayName: json['display_name'] as String? ?? _titleCase(json['name'] as String),
        gen: (json['gen'] as num?)?.toInt() ?? 0,
        category: json['category'] as String?,
        sprite: json['sprite'] as String?,
        flingPower: (json['fling_power'] as num?)?.toInt(),
        isMegaStone: json['is_mega_stone'] as bool? ?? false,
        megaSpecies: (json['mega_species'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as String)),
        isZCrystal: json['is_z_crystal'] as bool? ?? false,
        isBerry: json['is_berry'] as bool? ?? false,
        isPlate: json['is_plate'] as bool? ?? false,
        isMemory: json['is_memory'] as bool? ?? false,
        effectShort: json['effect_short'] as String?,
        effect: json['effect'] as String?,
      );

  factory BackendItemEntry.fromName(String name) => BackendItemEntry(
        name: name,
        displayName: _titleCase(name),
        gen: 0,
      );
}

class BackendAbilityEntry {
  final String name;
  final String displayName;
  final int gen;
  final String? effectShort;
  final String? effect;
  final int? slot;
  final bool isHidden;

  const BackendAbilityEntry({
    required this.name,
    required this.displayName,
    required this.gen,
    this.effectShort,
    this.effect,
    this.slot,
    this.isHidden = false,
  });

  factory BackendAbilityEntry.fromJson(Map<String, dynamic> json) =>
      BackendAbilityEntry(
        name: json['name'] as String,
        displayName: json['display_name'] as String? ?? _titleCase(json['name'] as String),
        gen: (json['gen'] as num?)?.toInt() ?? 0,
        effectShort: json['effect_short'] as String?,
        effect: json['effect'] as String?,
        slot: (json['slot'] as num?)?.toInt(),
        isHidden: json['is_hidden'] as bool? ?? false,
      );

  factory BackendAbilityEntry.fromName(String name) => BackendAbilityEntry(
        name: name,
        displayName: _titleCase(name),
        gen: 0,
      );
}

class PaginatedCatalogResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedCatalogResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedCatalogResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromItem,
  ) =>
      PaginatedCatalogResponse(
        items: (json['items'] as List<dynamic>).map(fromItem).toList(),
        total: (json['total'] as num).toInt(),
        page: (json['page'] as num).toInt(),
        pageSize: (json['page_size'] as num).toInt(),
        totalPages: (json['total_pages'] as num).toInt(),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/services/catalog/catalog_models_test.dart
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/catalog/catalog_models.dart test/services/catalog/catalog_models_test.dart
git commit -m "feat: add catalog backend entry models (move/item/ability)"
```

---

### Task 2: Repository catalog fetch methods

**Files:**
- Modify: `lib/services/pokemon_resolved/pokemon_backend_repository.dart`
- Test: `test/services/catalog/catalog_backend_repository_test.dart`

**Interfaces:**
- Consumes: `BackendMoveEntry`, `BackendItemEntry`, `BackendAbilityEntry`, `PaginatedCatalogResponse<T>` from Task 1
- Produces (on `PokemonBackendRepository`):
  - `Future<PaginatedCatalogResponse<BackendMoveEntry>> fetchCatalogMoves({int page, int pageSize, int? gen, String? damageClass, bool? isZMove, bool? isMaxMove})`
  - `Future<BackendMoveEntry> fetchCatalogMove(String idOrName)`
  - `Future<PaginatedCatalogResponse<BackendItemEntry>> fetchCatalogItems({int page, int pageSize, int? gen, String? category, bool? isMegaStone, bool? isZCrystal, bool? isBerry, bool? isPlate, bool? isMemory})`
  - `Future<BackendItemEntry> fetchCatalogItem(String idOrName)`
  - `Future<PaginatedCatalogResponse<BackendAbilityEntry>> fetchCatalogAbilities({int page, int pageSize, int? gen, String? pokemon})`
  - `Future<BackendAbilityEntry> fetchCatalogAbility(String idOrName)`

- [ ] **Step 1: Write the failing tests**

```dart
// test/services/catalog/catalog_backend_repository_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';

class MockDio extends Mock implements Dio {}
class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockDio mockDio;
  late MockApiClient mockApiClient;
  late PokemonBackendRepository repo;

  setUp(() {
    mockDio = MockDio();
    mockApiClient = MockApiClient();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    repo = PokemonBackendRepository(mockApiClient);
  });

  group('fetchCatalogMoves', () {
    test('returns PaginatedCatalogResponse<BackendMoveEntry> on 200', () async {
      when(() => mockDio.get<dynamic>('/moves',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _movesListJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/moves'),
              ));

      final result = await repo.fetchCatalogMoves(pageSize: 1000);
      expect(result.items.length, 1);
      expect(result.items[0].name, 'thunderbolt');
      expect(result.items[0].type, 'electric');
      expect(result.total, 1);
    });

    test('throws on non-200', () async {
      when(() => mockDio.get<dynamic>('/moves',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 500,
                requestOptions: RequestOptions(path: '/moves'),
              ));

      expect(() => repo.fetchCatalogMoves(), throwsException);
    });
  });

  group('fetchCatalogMove', () {
    test('returns BackendMoveEntry on 200', () async {
      when(() => mockDio.get<dynamic>('/moves/thunderbolt',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _moveEntryJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/moves/thunderbolt'),
              ));

      final result = await repo.fetchCatalogMove('thunderbolt');
      expect(result.name, 'thunderbolt');
      expect(result.power, 90);
    });
  });

  group('fetchCatalogItems', () {
    test('returns PaginatedCatalogResponse<BackendItemEntry> on 200', () async {
      when(() => mockDio.get<dynamic>('/items',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _itemsListJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/items'),
              ));

      final result = await repo.fetchCatalogItems(pageSize: 1000);
      expect(result.items.length, 1);
      expect(result.items[0].name, 'leftovers');
      expect(result.items[0].isBerry, false);
    });
  });

  group('fetchCatalogItem', () {
    test('returns BackendItemEntry on 200', () async {
      when(() => mockDio.get<dynamic>('/items/leftovers',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _itemEntryJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/items/leftovers'),
              ));

      final result = await repo.fetchCatalogItem('leftovers');
      expect(result.name, 'leftovers');
      expect(result.gen, 2);
    });
  });

  group('fetchCatalogAbilities', () {
    test('returns PaginatedCatalogResponse<BackendAbilityEntry> on 200', () async {
      when(() => mockDio.get<dynamic>('/abilities',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _abilitiesListJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/abilities'),
              ));

      final result = await repo.fetchCatalogAbilities(pageSize: 1000);
      expect(result.items.length, 1);
      expect(result.items[0].name, 'blaze');
      expect(result.items[0].gen, 3);
    });
  });

  group('fetchCatalogAbility', () {
    test('returns BackendAbilityEntry on 200', () async {
      when(() => mockDio.get<dynamic>('/abilities/blaze',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: _abilityEntryJson(),
                statusCode: 200,
                requestOptions: RequestOptions(path: '/abilities/blaze'),
              ));

      final result = await repo.fetchCatalogAbility('blaze');
      expect(result.name, 'blaze');
    });
  });
}

Map<String, dynamic> _movesListJson() => {
  'items': [_moveEntryJson()],
  'total': 1, 'page': 1, 'page_size': 1000, 'total_pages': 1,
};

Map<String, dynamic> _moveEntryJson() => {
  'name': 'thunderbolt', 'display_name': 'Thunderbolt',
  'gen': 1, 'type': 'electric', 'damage_class': 'special',
  'power': 90, 'accuracy': 100, 'pp': 15, 'priority': 0,
  'is_z_move': false, 'is_max_move': false, 'flags': {},
};

Map<String, dynamic> _itemsListJson() => {
  'items': [_itemEntryJson()],
  'total': 1, 'page': 1, 'page_size': 1000, 'total_pages': 1,
};

Map<String, dynamic> _itemEntryJson() => {
  'name': 'leftovers', 'display_name': 'Leftovers',
  'gen': 2, 'category': 'held-items', 'sprite': null,
  'fling_power': 10, 'is_mega_stone': false, 'mega_species': null,
  'is_z_crystal': false, 'is_berry': false, 'is_plate': false, 'is_memory': false,
};

Map<String, dynamic> _abilitiesListJson() => {
  'items': [_abilityEntryJson()],
  'total': 1, 'page': 1, 'page_size': 1000, 'total_pages': 1,
};

Map<String, dynamic> _abilityEntryJson() => {
  'name': 'blaze', 'display_name': 'Blaze', 'gen': 3,
  'effect_short': 'Powers up Fire moves in a pinch.',
  'effect': null, 'slot': null, 'is_hidden': false,
};
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/services/catalog/catalog_backend_repository_test.dart
```
Expected: FAIL — `fetchCatalogMoves` method does not exist yet.

- [ ] **Step 3: Add the 6 fetch methods to `PokemonBackendRepository`**

Add the following methods at the end of the class body in `lib/services/pokemon_resolved/pokemon_backend_repository.dart`:

```dart
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
// Add this import at the top of the file (alongside existing imports).
```

Then add at the bottom of the class (before the closing `}`):

```dart
  Future<PaginatedCatalogResponse<BackendMoveEntry>> fetchCatalogMoves({
    int page = 1,
    int pageSize = 200,
    int? gen,
    String? damageClass,
    bool? isZMove,
    bool? isMaxMove,
  }) async {
    final qp = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (gen != null) qp['gen'] = gen;
    if (damageClass != null) qp['damage_class'] = damageClass;
    if (isZMove != null) qp['is_z_move'] = isZMove;
    if (isMaxMove != null) qp['is_max_move'] = isMaxMove;
    final response = await _apiClient.dio.get<dynamic>('/moves', queryParameters: qp);
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogMoves failed: ${response.statusCode}');
    }
    return PaginatedCatalogResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
      (item) => BackendMoveEntry.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<BackendMoveEntry> fetchCatalogMove(String idOrName) async {
    final response =
        await _apiClient.dio.get<dynamic>('/moves/$idOrName');
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogMove failed for $idOrName: ${response.statusCode}');
    }
    return BackendMoveEntry.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<PaginatedCatalogResponse<BackendItemEntry>> fetchCatalogItems({
    int page = 1,
    int pageSize = 200,
    int? gen,
    String? category,
    bool? isMegaStone,
    bool? isZCrystal,
    bool? isBerry,
    bool? isPlate,
    bool? isMemory,
  }) async {
    final qp = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (gen != null) qp['gen'] = gen;
    if (category != null) qp['category'] = category;
    if (isMegaStone != null) qp['is_mega_stone'] = isMegaStone;
    if (isZCrystal != null) qp['is_z_crystal'] = isZCrystal;
    if (isBerry != null) qp['is_berry'] = isBerry;
    if (isPlate != null) qp['is_plate'] = isPlate;
    if (isMemory != null) qp['is_memory'] = isMemory;
    final response = await _apiClient.dio.get<dynamic>('/items', queryParameters: qp);
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogItems failed: ${response.statusCode}');
    }
    return PaginatedCatalogResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
      (item) => BackendItemEntry.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<BackendItemEntry> fetchCatalogItem(String idOrName) async {
    final response =
        await _apiClient.dio.get<dynamic>('/items/$idOrName');
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogItem failed for $idOrName: ${response.statusCode}');
    }
    return BackendItemEntry.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<PaginatedCatalogResponse<BackendAbilityEntry>> fetchCatalogAbilities({
    int page = 1,
    int pageSize = 200,
    int? gen,
    String? pokemon,
  }) async {
    final qp = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (gen != null) qp['gen'] = gen;
    if (pokemon != null) qp['pokemon'] = pokemon;
    final response =
        await _apiClient.dio.get<dynamic>('/abilities', queryParameters: qp);
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogAbilities failed: ${response.statusCode}');
    }
    return PaginatedCatalogResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
      (item) => BackendAbilityEntry.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<BackendAbilityEntry> fetchCatalogAbility(String idOrName) async {
    final response =
        await _apiClient.dio.get<dynamic>('/abilities/$idOrName');
    if (response.statusCode != 200) {
      throw Exception('fetchCatalogAbility failed for $idOrName: ${response.statusCode}');
    }
    return BackendAbilityEntry.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/catalog/catalog_backend_repository_test.dart
```
Expected: All 6 group tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/pokemon_resolved/pokemon_backend_repository.dart \
        lib/services/catalog/catalog_models.dart \
        test/services/catalog/catalog_backend_repository_test.dart
git commit -m "feat: add catalog fetch methods to PokemonBackendRepository"
```

---

### Task 3: Moves provider — backend-first

**Files:**
- Modify: `lib/features/moves/providers/moves_provider.dart`
- Test: `test/features/moves/moves_provider_test.dart`

**Interfaces:**
- Consumes: `BackendMoveEntry` (Task 1), `fetchCatalogMoves` (Task 2), `pokemonBackendRepositoryProvider` (from `pokemon_resolved_providers.dart`), `pokeApiRepositoryProvider` (from `poke_api_providers.dart`)
- Produces:
  - `movesListProvider: FutureProvider<List<BackendMoveEntry>>` — backend-first, PokéAPI fallback
  - `filteredMovesProvider: Provider<AsyncValue<List<String>>>` — unchanged signature; type/damageClass/search filtered client-side
  - All other providers (`movesSearchProvider`, `movesDamageClassFilterProvider`, `movesTypeFilterProvider`, `movesByTypeProvider`, `machineProvider`, `contestEffectProvider`, `superContestEffectProvider`) — unchanged

**Fallback behavior:** When backend fails, entries are created with `BackendMoveEntry.fromName(n)` where `type == ''` and `damageClass == ''`. The filtered provider skips type/damageClass filters when entry fields are empty (entries pass through). Name search still works.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/moves/moves_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/moves/providers/moves_provider.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

class MockPokemonBackendRepository extends Mock
    implements PokemonBackendRepository {}

class MockPokeApiRepository extends Mock implements PokeApiRepository {}

void main() {
  late MockPokemonBackendRepository mockBackend;
  late MockPokeApiRepository mockPokeApi;

  setUpAll(() {
    registerFallbackValue(1);
    registerFallbackValue('');
  });

  setUp(() {
    mockBackend = MockPokemonBackendRepository();
    mockPokeApi = MockPokeApiRepository();
  });

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        pokemonBackendRepositoryProvider.overrideWithValue(mockBackend),
        pokeApiRepositoryProvider.overrideWithValue(mockPokeApi),
      ]);

  test('movesListProvider returns backend entries on success', () async {
    when(() => mockBackend.fetchCatalogMoves(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              damageClass: any(named: 'damageClass'),
              isZMove: any(named: 'isZMove'),
              isMaxMove: any(named: 'isMaxMove'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendMoveEntry.fromJson({
                  'name': 'tackle', 'display_name': 'Tackle', 'gen': 1,
                  'type': 'normal', 'damage_class': 'physical',
                  'power': 40, 'accuracy': 100, 'pp': 35, 'priority': 0,
                  'is_z_move': false, 'is_max_move': false, 'flags': {},
                }),
              ],
              total: 1, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    final result = await container.read(movesListProvider.future);
    expect(result.length, 1);
    expect(result[0].name, 'tackle');
    expect(result[0].type, 'normal');
  });

  test('movesListProvider falls back to PokéAPI name list on backend failure', () async {
    when(() => mockBackend.fetchCatalogMoves(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              damageClass: any(named: 'damageClass'),
              isZMove: any(named: 'isZMove'),
              isMaxMove: any(named: 'isMaxMove'),
            ))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchMoveList())
        .thenAnswer((_) async => ['tackle', 'flamethrower']);

    final container = makeContainer();
    final result = await container.read(movesListProvider.future);
    expect(result.length, 2);
    expect(result[0].name, 'tackle');
    expect(result[0].type, ''); // sentinel — no metadata from PokéAPI fallback
  });

  test('filteredMovesProvider filters by type client-side', () async {
    when(() => mockBackend.fetchCatalogMoves(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              damageClass: any(named: 'damageClass'),
              isZMove: any(named: 'isZMove'),
              isMaxMove: any(named: 'isMaxMove'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendMoveEntry.fromJson({
                  'name': 'tackle', 'display_name': 'Tackle', 'gen': 1,
                  'type': 'normal', 'damage_class': 'physical',
                  'power': 40, 'accuracy': 100, 'pp': 35, 'priority': 0,
                  'is_z_move': false, 'is_max_move': false, 'flags': {},
                }),
                BackendMoveEntry.fromJson({
                  'name': 'thunderbolt', 'display_name': 'Thunderbolt', 'gen': 1,
                  'type': 'electric', 'damage_class': 'special',
                  'power': 90, 'accuracy': 100, 'pp': 15, 'priority': 0,
                  'is_z_move': false, 'is_max_move': false, 'flags': {},
                }),
              ],
              total: 2, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    // Wait for list to load
    await container.read(movesListProvider.future);
    // Apply type filter
    container.read(movesTypeFilterProvider.notifier).state = 'electric';
    final filtered = container.read(filteredMovesProvider);
    expect(filtered.requireValue, ['thunderbolt']);
  });

  test('filteredMovesProvider passes all entries when backend unavailable (sentinel type)', () async {
    when(() => mockBackend.fetchCatalogMoves(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              damageClass: any(named: 'damageClass'),
              isZMove: any(named: 'isZMove'),
              isMaxMove: any(named: 'isMaxMove'),
            ))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchMoveList())
        .thenAnswer((_) async => ['tackle']);

    final container = makeContainer();
    await container.read(movesListProvider.future);
    container.read(movesTypeFilterProvider.notifier).state = 'electric';
    final filtered = container.read(filteredMovesProvider);
    // Sentinel entries (type == '') pass the type filter
    expect(filtered.requireValue, ['tackle']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/moves/moves_provider_test.dart
```
Expected: FAIL — `movesListProvider` still returns `List<String>`.

- [ ] **Step 3: Update `moves_provider.dart`**

Replace the entire content of `lib/features/moves/providers/moves_provider.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Backend-first full move catalog. Falls back to PokéAPI name list on failure.
/// Fallback entries use sentinel values (type == '', damageClass == '') — the
/// filtered provider treats those as "no metadata, pass all filters".
final movesListProvider = FutureProvider<List<BackendMoveEntry>>((ref) async {
  ref.keepAlive();
  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final result = await repo.fetchCatalogMoves(pageSize: 1000);
    AppLogger().d('[catalog] moves: loaded ${result.total} entries from backend');
    return result.items;
  } catch (e) {
    AppLogger().w('[catalog] moves backend failed, falling back to PokéAPI', error: e);
    final names = await ref.read(pokeApiRepositoryProvider).fetchMoveList();
    return names.map(BackendMoveEntry.fromName).toList();
  }
});

// Persists across tab switches.
final movesSearchProvider = StateProvider<String>((ref) => '');
final movesDamageClassFilterProvider = StateProvider<String?>((ref) => null);
final movesTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Move names for a given type — fetched from /type/{name}, cached 7 days.
/// Still used by the retry callback in MovesScreen; type filtering is now
/// client-side on backend entries for the filtered provider.
final movesByTypeProvider =
    FutureProvider.family<List<String>, String>((ref, typeName) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMovesByType(typeName);
});

/// Filtered move names derived client-side from the backend entry list.
///
/// Type and damage class filters use entry metadata when available (gen > 0).
/// Fallback entries (gen == 0, type == '') pass all filters to preserve usability
/// when the backend is unavailable.
final filteredMovesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final typeFilter = ref.watch(movesTypeFilterProvider);
  final damageClassFilter = ref.watch(movesDamageClassFilterProvider);
  final search = ref.watch(movesSearchProvider).trim().toLowerCase();

  final listAsync = ref.watch(movesListProvider);

  if (listAsync is AsyncLoading) return const AsyncValue.loading();
  if (listAsync is AsyncError) {
    return AsyncValue.error(
        (listAsync as AsyncError).error,
        (listAsync as AsyncError).stackTrace);
  }

  List<BackendMoveEntry> entries = List.of(listAsync.requireValue);

  // Empty type/damageClass == sentinel (PokéAPI fallback) — skip that filter.
  if (typeFilter != null) {
    entries = entries
        .where((e) => e.type.isEmpty || e.type == typeFilter)
        .toList();
  }
  if (damageClassFilter != null) {
    entries = entries
        .where((e) => e.damageClass.isEmpty || e.damageClass == damageClassFilter)
        .toList();
  }
  if (search.isNotEmpty) {
    entries = entries
        .where((e) =>
            e.name.replaceAll('-', ' ').contains(search) ||
            e.displayName.toLowerCase().contains(search))
        .toList();
  }

  return AsyncValue.data(entries.map((e) => e.name).toList());
});

/// Fetches a machine's item name and URL by the machine's full PokéAPI URL.
final machineProvider =
    FutureProvider.autoDispose.family<Map<String, String>, String>(
        (ref, url) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMachineByUrl(url);
});

/// Fetches Gen III regular contest effect data (appeal + jam + effect text).
final contestEffectProvider =
    FutureProvider.autoDispose.family<ContestEffectData, String>(
        (ref, url) async {
  return ref.read(pokeApiRepositoryProvider).fetchContestEffect(url);
});

/// Fetches Gen IV super contest effect data (appeal + flavor text).
final superContestEffectProvider =
    FutureProvider.autoDispose.family<SuperContestEffectData, String>(
        (ref, url) async {
  return ref.read(pokeApiRepositoryProvider).fetchSuperContestEffect(url);
});
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/moves/moves_provider_test.dart
```
Expected: All 4 tests PASS.

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
flutter test
```
Expected: All tests PASS (no regressions from `movesListProvider` type change).

- [ ] **Step 6: Commit**

```bash
git add lib/features/moves/providers/moves_provider.dart \
        test/features/moves/moves_provider_test.dart
git commit -m "feat: moves — backend-first catalog list provider with client-side filtering"
```

---

### Task 4: Items provider — backend-first

**Files:**
- Modify: `lib/features/items/providers/items_provider.dart`
- Test: `test/features/items/items_provider_test.dart`

**Interfaces:**
- Consumes: `BackendItemEntry` (Task 1), `fetchCatalogItems` (Task 2)
- Produces:
  - `itemsListProvider: FutureProvider<List<BackendItemEntry>>` — backend-first, PokéAPI fallback
  - `filteredItemsProvider: Provider<AsyncValue<List<String>>>` — unchanged signature; pocket filter still uses PokéAPI (`itemsByPocketProvider`); search applied on entry names
  - All other providers (`itemsSearchProvider`, `itemPocketFilterProvider`, `itemSortProvider`, `kItemPockets`, `itemsByPocketProvider`, `itemProvider`) — unchanged

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/items/items_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

class MockPokemonBackendRepository extends Mock
    implements PokemonBackendRepository {}

class MockPokeApiRepository extends Mock implements PokeApiRepository {}

void main() {
  late MockPokemonBackendRepository mockBackend;
  late MockPokeApiRepository mockPokeApi;

  setUp(() {
    mockBackend = MockPokemonBackendRepository();
    mockPokeApi = MockPokeApiRepository();
  });

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        pokemonBackendRepositoryProvider.overrideWithValue(mockBackend),
        pokeApiRepositoryProvider.overrideWithValue(mockPokeApi),
      ]);

  test('itemsListProvider returns backend entries on success', () async {
    when(() => mockBackend.fetchCatalogItems(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              category: any(named: 'category'),
              isMegaStone: any(named: 'isMegaStone'),
              isZCrystal: any(named: 'isZCrystal'),
              isBerry: any(named: 'isBerry'),
              isPlate: any(named: 'isPlate'),
              isMemory: any(named: 'isMemory'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendItemEntry.fromJson({
                  'name': 'leftovers', 'display_name': 'Leftovers',
                  'gen': 2, 'is_berry': false, 'is_mega_stone': false,
                  'is_z_crystal': false, 'is_plate': false, 'is_memory': false,
                }),
              ],
              total: 1, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    final result = await container.read(itemsListProvider.future);
    expect(result.length, 1);
    expect(result[0].name, 'leftovers');
  });

  test('itemsListProvider falls back to PokéAPI on backend failure', () async {
    when(() => mockBackend.fetchCatalogItems(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              category: any(named: 'category'),
              isMegaStone: any(named: 'isMegaStone'),
              isZCrystal: any(named: 'isZCrystal'),
              isBerry: any(named: 'isBerry'),
              isPlate: any(named: 'isPlate'),
              isMemory: any(named: 'isMemory'),
            ))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchItemList())
        .thenAnswer((_) async => ['leftovers', 'master-ball']);

    final container = makeContainer();
    final result = await container.read(itemsListProvider.future);
    expect(result.length, 2);
    expect(result[0].name, 'leftovers');
    expect(result[0].gen, 0); // sentinel
  });

  test('filteredItemsProvider applies name search', () async {
    when(() => mockBackend.fetchCatalogItems(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              category: any(named: 'category'),
              isMegaStone: any(named: 'isMegaStone'),
              isZCrystal: any(named: 'isZCrystal'),
              isBerry: any(named: 'isBerry'),
              isPlate: any(named: 'isPlate'),
              isMemory: any(named: 'isMemory'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendItemEntry.fromName('leftovers'),
                BackendItemEntry.fromName('master-ball'),
              ],
              total: 2, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    await container.read(itemsListProvider.future);
    container.read(itemsSearchProvider.notifier).state = 'left';
    final filtered = container.read(filteredItemsProvider);
    expect(filtered.requireValue, ['leftovers']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/items/items_provider_test.dart
```
Expected: FAIL — `itemsListProvider` still returns `List<String>`.

- [ ] **Step 3: Update `items_provider.dart`**

Replace the `itemsListProvider` and `filteredItemsProvider` with the following (keep everything else unchanged):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Backend-first full item catalog. Falls back to PokéAPI name list on failure.
final itemsListProvider = FutureProvider<List<BackendItemEntry>>((ref) async {
  ref.keepAlive();
  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final result = await repo.fetchCatalogItems(pageSize: 1000);
    AppLogger().d('[catalog] items: loaded ${result.total} entries from backend');
    return result.items;
  } catch (e) {
    AppLogger().w('[catalog] items backend failed, falling back to PokéAPI', error: e);
    final names = await ref.read(pokeApiRepositoryProvider).fetchItemList();
    return names.map(BackendItemEntry.fromName).toList();
  }
});

// Not autoDispose — persists across tab switches.
final itemsSearchProvider = StateProvider<String>((ref) => '');

// ── Filtering & sorting ───────────────────────────────────────────────────────

enum ItemSort { nameAZ, nameZA, idAscending, idDescending }

/// Selected item pocket filter (null = all items).
final itemPocketFilterProvider = StateProvider<String?>((ref) => null);

/// Sort direction for the item list.
final itemSortProvider = StateProvider<ItemSort>((ref) => ItemSort.nameAZ);

/// The item pockets available as filter options.
/// Maps PokéAPI pocket name → display label.
const kItemPockets = <String, String>{
  'pokeballs': 'Poké Balls',
  'medicine':  'Medicine',
  'berries':   'Berries',
  'held-items': 'Held Items',
  'machines':  'Machines',
  'battle':    'Battle',
  'key':       'Key Items',
  'misc':      'Misc',
};

/// Item names for a given pocket, fetched from PokéAPI and cached.
///
/// "held-items" is special-cased: it's a PokéAPI item *category* nested
/// inside the "misc" pocket, not a pocket of its own — see
/// [PokeApiRepository.fetchItemsByCategory].
final itemsByPocketProvider =
    FutureProvider.family<List<String>, String>((ref, pocket) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return pocket == 'held-items'
      ? repo.fetchItemsByCategory('held-items')
      : repo.fetchItemsByPocket(pocket);
});

// ── Per-item detail (autoDispose — large family cache) ────────────────────────

final itemProvider =
    FutureProvider.autoDispose.family<ItemEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchItem(name);
});

// ── Filtered + sorted list ────────────────────────────────────────────────────

final filteredItemsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final pocket = ref.watch(itemPocketFilterProvider);
  final sort   = ref.watch(itemSortProvider);
  final search = ref.watch(itemsSearchProvider).trim().toLowerCase();

  // Backend list for the no-filter case and for ID ordering.
  final backendAsync = ref.watch(itemsListProvider);
  final backendList = backendAsync.asData?.value ?? const <BackendItemEntry>[];
  final idOrder = <String, int>{
    for (int i = 0; i < backendList.length; i++) backendList[i].name: i,
  };

  // When pocket filter active, use PokéAPI pocket list (returns names).
  // When no pocket filter, extract names from backend entries.
  final AsyncValue<List<String>> namesAsync;
  if (pocket != null) {
    namesAsync = ref.watch(itemsByPocketProvider(pocket));
  } else if (backendAsync is AsyncLoading) {
    namesAsync = const AsyncValue.loading();
  } else if (backendAsync is AsyncError) {
    namesAsync = AsyncValue.error(
        (backendAsync as AsyncError).error,
        (backendAsync as AsyncError).stackTrace);
  } else {
    namesAsync =
        AsyncValue.data(backendList.map((e) => e.name).toList());
  }

  if (namesAsync is AsyncLoading || backendAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }
  if (namesAsync is AsyncError) {
    return AsyncValue.error(
        (namesAsync as AsyncError).error,
        (namesAsync as AsyncError).stackTrace);
  }

  List<String> items = List<String>.from(namesAsync.requireValue);

  if (search.isNotEmpty) {
    items = items
        .where((n) => n.replaceAll('-', ' ').contains(search))
        .toList();
  }

  switch (sort) {
    case ItemSort.nameAZ:
      items.sort();
    case ItemSort.nameZA:
      items.sort((a, b) => b.compareTo(a));
    case ItemSort.idAscending:
      items.sort((a, b) =>
          (idOrder[a] ?? 999999).compareTo(idOrder[b] ?? 999999));
    case ItemSort.idDescending:
      items.sort((a, b) =>
          (idOrder[b] ?? 999999).compareTo(idOrder[a] ?? 999999));
  }

  return AsyncValue.data(items);
});
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/items/items_provider_test.dart
```
Expected: All 3 tests PASS.

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
flutter test
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/items/providers/items_provider.dart \
        test/features/items/items_provider_test.dart
git commit -m "feat: items — backend-first catalog list provider"
```

---

### Task 5: Abilities provider — backend-first

**Files:**
- Modify: `lib/features/abilities/providers/abilities_provider.dart`
- Test: `test/features/abilities/abilities_provider_test.dart`

**Interfaces:**
- Consumes: `BackendAbilityEntry` (Task 1), `fetchCatalogAbilities` (Task 2)
- Produces:
  - `abilitiesListProvider: FutureProvider<List<BackendAbilityEntry>>` — backend-first, PokéAPI fallback
  - `filteredAbilitiesProvider: Provider<AsyncValue<List<String>>>` — unchanged signature; gen filter is now client-side on `entry.gen` using `_kGenNameToInt`
  - `kAbilityGenerations`, `abilityGenerationFilterProvider`, `abilitySortProvider`, `AbilitySort` — unchanged

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/abilities/abilities_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/abilities/providers/abilities_provider.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

class MockPokemonBackendRepository extends Mock
    implements PokemonBackendRepository {}

class MockPokeApiRepository extends Mock implements PokeApiRepository {}

void main() {
  late MockPokemonBackendRepository mockBackend;
  late MockPokeApiRepository mockPokeApi;

  setUp(() {
    mockBackend = MockPokemonBackendRepository();
    mockPokeApi = MockPokeApiRepository();
  });

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        pokemonBackendRepositoryProvider.overrideWithValue(mockBackend),
        pokeApiRepositoryProvider.overrideWithValue(mockPokeApi),
      ]);

  test('abilitiesListProvider returns backend entries on success', () async {
    when(() => mockBackend.fetchCatalogAbilities(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              pokemon: any(named: 'pokemon'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendAbilityEntry.fromJson({
                  'name': 'blaze', 'display_name': 'Blaze',
                  'gen': 3, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
              ],
              total: 1, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    final result = await container.read(abilitiesListProvider.future);
    expect(result.length, 1);
    expect(result[0].name, 'blaze');
    expect(result[0].gen, 3);
  });

  test('abilitiesListProvider falls back to PokéAPI on backend failure', () async {
    when(() => mockBackend.fetchCatalogAbilities(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              pokemon: any(named: 'pokemon'),
            ))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchAbilityList())
        .thenAnswer((_) async => ['blaze', 'levitate']);

    final container = makeContainer();
    final result = await container.read(abilitiesListProvider.future);
    expect(result.length, 2);
    expect(result[0].gen, 0); // sentinel
  });

  test('filteredAbilitiesProvider filters by gen client-side', () async {
    when(() => mockBackend.fetchCatalogAbilities(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              pokemon: any(named: 'pokemon'),
            ))
        .thenAnswer((_) async => PaginatedCatalogResponse(
              items: [
                BackendAbilityEntry.fromJson({
                  'name': 'blaze', 'display_name': 'Blaze',
                  'gen': 3, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
                BackendAbilityEntry.fromJson({
                  'name': 'intimidate', 'display_name': 'Intimidate',
                  'gen': 3, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
                BackendAbilityEntry.fromJson({
                  'name': 'flash-fire', 'display_name': 'Flash Fire',
                  'gen': 3, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
                BackendAbilityEntry.fromJson({
                  'name': 'moody', 'display_name': 'Moody',
                  'gen': 5, 'effect_short': null, 'effect': null,
                  'slot': null, 'is_hidden': false,
                }),
              ],
              total: 4, page: 1, pageSize: 1000, totalPages: 1,
            ));

    final container = makeContainer();
    await container.read(abilitiesListProvider.future);
    container.read(abilityGenerationFilterProvider.notifier).state = 'generation-v';
    final filtered = container.read(filteredAbilitiesProvider);
    expect(filtered.requireValue, ['moody']);
  });

  test('filteredAbilitiesProvider passes all entries for sentinel gen (PokéAPI fallback)', () async {
    when(() => mockBackend.fetchCatalogAbilities(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              gen: any(named: 'gen'),
              pokemon: any(named: 'pokemon'),
            ))
        .thenThrow(Exception('backend down'));
    when(() => mockPokeApi.fetchAbilityList())
        .thenAnswer((_) async => ['blaze']);

    final container = makeContainer();
    await container.read(abilitiesListProvider.future);
    container.read(abilityGenerationFilterProvider.notifier).state = 'generation-v';
    final filtered = container.read(filteredAbilitiesProvider);
    // Sentinel entries (gen == 0) pass the gen filter
    expect(filtered.requireValue, ['blaze']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/abilities/abilities_provider_test.dart
```
Expected: FAIL — `abilitiesListProvider` still returns `List<String>`.

- [ ] **Step 3: Update `abilities_provider.dart`**

Replace the entire content of `lib/features/abilities/providers/abilities_provider.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Maps PokéAPI generation names (as stored in abilityGenerationFilterProvider)
/// to the integer gen field used by the backend.
const _kGenNameToInt = <String, int>{
  'generation-i': 1,
  'generation-ii': 2,
  'generation-iii': 3,
  'generation-iv': 4,
  'generation-v': 5,
  'generation-vi': 6,
  'generation-vii': 7,
  'generation-viii': 8,
  'generation-ix': 9,
};

/// Backend-first full ability catalog. Falls back to PokéAPI name list on failure.
/// Fallback entries use gen == 0 as a sentinel; the filtered provider passes
/// sentinel entries through all gen filters to preserve usability when offline.
final abilitiesListProvider =
    FutureProvider<List<BackendAbilityEntry>>((ref) async {
  ref.keepAlive();
  try {
    final repo = ref.read(pokemonBackendRepositoryProvider);
    final result = await repo.fetchCatalogAbilities(pageSize: 1000);
    AppLogger().d('[catalog] abilities: loaded ${result.total} entries from backend');
    return result.items;
  } catch (e) {
    AppLogger().w('[catalog] abilities backend failed, falling back to PokéAPI', error: e);
    final names = await ref.read(pokeApiRepositoryProvider).fetchAbilityList();
    return names.map(BackendAbilityEntry.fromName).toList();
  }
});

// Not autoDispose — persists across tab switches.
final abilitiesSearchProvider = StateProvider<String>((ref) => '');

// ── Filtering & sorting ───────────────────────────────────────────────────────

enum AbilitySort { nameAZ, nameZA }

/// Selected generation filter (null = all). Value is the PokéAPI gen name
/// e.g. "generation-iii". Abilities start from Gen III.
final abilityGenerationFilterProvider = StateProvider<String?>((ref) => null);

/// Sort direction.
final abilitySortProvider =
    StateProvider<AbilitySort>((ref) => AbilitySort.nameAZ);

/// Generation options shown as filter chips (gen name → display label).
const kAbilityGenerations = <String, String>{
  'generation-iii': 'Gen III',
  'generation-iv':  'Gen IV',
  'generation-v':   'Gen V',
  'generation-vi':  'Gen VI',
  'generation-vii': 'Gen VII',
  'generation-viii':'Gen VIII',
  'generation-ix':  'Gen IX',
};

// ── Filtered + sorted list ────────────────────────────────────────────────────

final filteredAbilitiesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final genFilter = ref.watch(abilityGenerationFilterProvider);
  final sort      = ref.watch(abilitySortProvider);
  final search    = ref.watch(abilitiesSearchProvider).trim().toLowerCase();

  final listAsync = ref.watch(abilitiesListProvider);

  if (listAsync is AsyncLoading) return const AsyncValue.loading();
  if (listAsync is AsyncError) {
    return AsyncValue.error(
        (listAsync as AsyncError).error,
        (listAsync as AsyncError).stackTrace);
  }

  List<BackendAbilityEntry> entries = List.of(listAsync.requireValue);

  if (genFilter != null) {
    final genInt = _kGenNameToInt[genFilter];
    if (genInt != null) {
      // gen == 0 is the PokéAPI fallback sentinel — pass it through.
      entries = entries
          .where((e) => e.gen == 0 || e.gen == genInt)
          .toList();
    }
  }
  if (search.isNotEmpty) {
    entries = entries
        .where((e) =>
            e.name.replaceAll('-', ' ').contains(search) ||
            e.displayName.toLowerCase().contains(search))
        .toList();
  }

  List<String> names = entries.map((e) => e.name).toList();

  switch (sort) {
    case AbilitySort.nameAZ:
      names.sort();
    case AbilitySort.nameZA:
      names.sort((a, b) => b.compareTo(a));
  }

  return AsyncValue.data(names);
});
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/abilities/abilities_provider_test.dart
```
Expected: All 4 tests PASS.

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
flutter test
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/abilities/providers/abilities_provider.dart \
        test/features/abilities/abilities_provider_test.dart
git commit -m "feat: abilities — backend-first catalog list provider with client-side gen filtering"
```

---

### Task 6: README updates

**Files:**
- Create: `lib/services/catalog/README.md`
- Modify: `lib/services/README.md`

**Interfaces:**
- No code; no tests.

- [ ] **Step 1: Create `lib/services/catalog/README.md`**

```markdown
# lib/services/catalog/

Dart models for the backend catalog endpoints (`/moves`, `/items`, `/abilities`).

| File | Purpose |
| ---- | ------- |
| `catalog_models.dart` | `BackendMoveEntry`, `BackendItemEntry`, `BackendAbilityEntry`, `PaginatedCatalogResponse<T>` — `fromJson` parsers and `fromName` sentinel constructors used by fallback paths |

The fetch methods that call the backend live in `pokemon_resolved/pokemon_backend_repository.dart`
(`fetchCatalogMoves`, `fetchCatalogMove`, `fetchCatalogItems`, `fetchCatalogItem`,
`fetchCatalogAbilities`, `fetchCatalogAbility`).

The Riverpod providers that wire backend → PokéAPI fallback → filtering live in the
respective feature provider files:

| Feature | Provider file |
| ------- | ------------- |
| Moves   | `lib/features/moves/providers/moves_provider.dart` |
| Items   | `lib/features/items/providers/items_provider.dart` |
| Abilities | `lib/features/abilities/providers/abilities_provider.dart` |
```

- [ ] **Step 2: Add catalog entry to `lib/services/README.md`**

After the existing `## pokemon_resolved/` block, add a new `## catalog/` section:

```markdown
## `catalog/`

Dart models for the standalone `/moves`, `/items`, `/abilities` catalog endpoints.

| File | Purpose |
| ---- | ------- |
| `catalog_models.dart` | `BackendMoveEntry`, `BackendItemEntry`, `BackendAbilityEntry`, `PaginatedCatalogResponse<T>` |

Fetch methods are in `pokemon_resolved/pokemon_backend_repository.dart`.
Riverpod providers and backend-first + fallback logic live in the respective `lib/features/*/providers/` files.
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/catalog/README.md lib/services/README.md
git commit -m "docs: add catalog service README and update services index"
```

---

## Self-Review

### Spec coverage

| Requirement | Task |
| --- | --- |
| Backend catalog models (MoveEntry, ItemEntry, AbilityEntry, PaginatedCatalogResponse) | Task 1 |
| Repository methods: fetchCatalogMoves, fetchCatalogMove, fetchCatalogItems, fetchCatalogItem, fetchCatalogAbilities, fetchCatalogAbility | Task 2 |
| movesListProvider — backend-first + fallback | Task 3 |
| filteredMovesProvider — client-side type/damageClass/search filtering | Task 3 |
| itemsListProvider — backend-first + fallback | Task 4 |
| filteredItemsProvider — updated for backend entries | Task 4 |
| abilitiesListProvider — backend-first + fallback | Task 5 |
| filteredAbilitiesProvider — client-side gen filtering | Task 5 |
| No UI screen changes | All tasks (filtered providers keep `AsyncValue<List<String>>` signature) |
| Detail providers (fetchCatalogMove, fetchCatalogItem, fetchCatalogAbility) | Task 2 — methods defined; individual detail `FutureProvider`s are deferred per issue scope |

**Note:** The issue mentions adding individual detail providers (e.g., `catalogMoveProvider`). These are defined as repo methods in Task 2 but the wrapping Riverpod `FutureProvider`s are not added since the existing detail screens (`move_detail_screen.dart`, `item_detail_screen.dart`, `ability_detail_screen.dart`) each fetch details directly via PokéAPI providers. Wiring up backend-first detail providers is a separate pass and is not required for the issue acceptance criteria.

### Placeholder scan

No TBD, TODO, or placeholder steps found.

### Type consistency

- `BackendMoveEntry` — used consistently across Task 1 (model), Task 2 (repo return type), Task 3 (provider list type)
- `BackendItemEntry` — used consistently across Task 1, 2, 4
- `BackendAbilityEntry` — used consistently across Task 1, 2, 5
- `PaginatedCatalogResponse<T>` — `fromJson` signature in Task 1 matches usage in Task 2 mock data
- `movesListProvider: FutureProvider<List<BackendMoveEntry>>` — read in Task 3 filtered provider as `ref.watch(movesListProvider)` returning `AsyncValue<List<BackendMoveEntry>>` ✓
- `abilitiesListProvider: FutureProvider<List<BackendAbilityEntry>>` — Task 5 filtered provider uses `List.of(listAsync.requireValue)` which is `List<BackendAbilityEntry>` ✓
