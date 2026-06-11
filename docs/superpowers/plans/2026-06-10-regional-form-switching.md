# Regional Form Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compact form-switcher badge to the Pokémon detail screen app bar that switches all tabs (Overview, Stats, Abilities, Moves, Evolutions, Forms, Locations, Teams) to show data for the selected regional or battle-meaningful form, with the shiny flag applied to the selected form's artwork.

**Architecture:** Local `_selectedFormName: String?` state on `_PokemonDetailScreenState` drives an `effectivePokemon` (from `pokemonByNameProvider` when a form is selected, otherwise the base pokemon). All tabs receive `effectivePokemon`; the Evolutions tab auto-detects the correct chain via a two-step suffix resolution using helpers in a new `evolution_chain_builder.dart`. A separate `form_filter.dart` in `lib/features/pokedex/logic/` defines which forms appear in the switcher.

**Tech Stack:** Flutter/Dart, Riverpod, `flutter_test` + `mocktail`, `cached_network_image`, `go_router`.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `lib/services/pokeapi/models/evolution_chain.dart` | Modify | Add `baseForm` and `region` fields to `EvolutionDetail`; update `conditionLabel` |
| `lib/features/pokedex/logic/evolution_chain_builder.dart` | **Create** | `DisplayNode`, all chain-building helpers, `formLabel`, `formSuffixForSpecies` |
| `lib/features/pokedex/logic/form_filter.dart` | **Create** | `battleMeaningfulForms()` — which forms appear in the switcher |
| `lib/features/pokedex/presentation/pokemon_detail_screen.dart` | Modify | Form state, `effectivePokemon`, badge widget, bottom sheet, tab wiring |
| `test/unit/evolution_chain_builder_test.dart` | **Create** | Unit tests for chain-building helpers |
| `test/unit/pokedex_form_filter_test.dart` | **Create** | Unit tests for `battleMeaningfulForms` |

---

## Task 1: Add `baseForm` + `region` to `EvolutionDetail`

**Files:**
- Modify: `lib/services/pokeapi/models/evolution_chain.dart`

PokéAPI's `/evolution-chain` endpoint includes two form-specific fields in `evolution_details` entries:
- `base_form` — the specific Pokémon form required for that evolution edge (e.g. `{name:"linoone-galar", url:".../pokemon/10175/"}`). Used for base-form evolution gating (Zigzagoon → Linoone → Obstagoon).
- `region` — a region restriction (e.g. `{name:"alola"}`). Used when any Pikachu in Alola can evolve into Alolan Raichu.

Currently `EvolutionDetail` discards both. This task adds them.

- [ ] **Read the file first**

  ```bash
  # Confirm current EvolutionDetail class — check lines 43-145
  ```
  Read `lib/services/pokeapi/models/evolution_chain.dart` lines 43–145.

- [ ] **Add `baseForm` and `region` fields + constructor params**

  In `EvolutionDetail`, after `final String? turnUpsideDown;` add:
  ```dart
  final ({String name, int id})? baseForm;
  final ({String name})? region;
  ```

  In the constructor, after `this.turnUpsideDown,` add:
  ```dart
  this.baseForm,
  this.region,
  ```

- [ ] **Add `fromJson` parsing**

  In `fromJson`, add to the return statement (alongside the other fields):
  ```dart
  baseForm: EvolutionDetail._parseBaseForm(json['base_form']),
  region: EvolutionDetail._parseRegion(json['region']),
  ```

- [ ] **Add the two static helpers**

  Add inside `EvolutionDetail` class, just before the closing `}`:
  ```dart
  static ({String name, int id})? _parseBaseForm(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final url = (raw as Map<String, dynamic>)['url'] as String?;
    if (url == null) return null;
    final segments = Uri.parse(url).pathSegments;
    final idStr = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
    final id = int.tryParse(idStr);
    if (id == null) return null;
    return (name: raw['name'] as String, id: id);
  }

  static ({String name})? _parseRegion(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final name = (raw as Map<String, dynamic>)['name'] as String?;
    if (name == null) return null;
    return (name: name);
  }
  ```

- [ ] **Add `region` to `conditionLabel`**

  In `conditionLabel`, immediately before `return parts.join(', ');` add:
  ```dart
  if (region != null) {
    final r = region!.name;
    parts.add('(${r[0].toUpperCase()}${r.substring(1)})');
  }
  ```

- [ ] **Verify**
  ```bash
  flutter analyze lib/services/pokeapi/models/evolution_chain.dart
  ```
  Expected: `No issues found!`

- [ ] **Commit**
  ```bash
  git add lib/services/pokeapi/models/evolution_chain.dart
  git commit -m "feat: parse base_form and region fields in EvolutionDetail"
  ```

---

## Task 2: Create `evolution_chain_builder.dart` with tests

**Files:**
- Create: `lib/features/pokedex/logic/evolution_chain_builder.dart`
- Create: `test/unit/evolution_chain_builder_test.dart`

- [ ] **Write failing tests first**

  Create `test/unit/evolution_chain_builder_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
  import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
  import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

  EvolutionDetail _detail({
    String? baseFormName,
    int? baseFormId,
    String? regionName,
    int? minLevel,
  }) =>
      EvolutionDetail(
        trigger: 'level-up',
        minLevel: minLevel,
        baseForm: baseFormName != null && baseFormId != null
            ? (name: baseFormName, id: baseFormId)
            : null,
        region: regionName != null ? (name: regionName) : null,
      );

  // Zigzagoon chain: two details on the Linoone edge (default + galar base_form),
  // and one galar-only detail on the Obstagoon edge.
  EvolutionNode _zigzagoonChain() => EvolutionNode(
        speciesId: 263,
        speciesName: 'zigzagoon',
        details: const [],
        evolvesTo: [
          EvolutionNode(
            speciesId: 264,
            speciesName: 'linoone',
            details: [
              _detail(minLevel: 20),
              _detail(baseFormName: 'zigzagoon-galar', baseFormId: 10174, minLevel: 20),
            ],
            evolvesTo: [
              EvolutionNode(
                speciesId: 862,
                speciesName: 'obstagoon',
                details: [
                  _detail(baseFormName: 'linoone-galar', baseFormId: 10175, minLevel: 35),
                ],
                evolvesTo: const [],
              ),
            ],
          ),
        ],
      );

  // Mime Jr chain: region-keyed edge to Mr. Mime, then base_form edge to Mr. Rime.
  EvolutionNode _mimeJrChain() => EvolutionNode(
        speciesId: 439,
        speciesName: 'mime-jr',
        details: const [],
        evolvesTo: [
          EvolutionNode(
            speciesId: 122,
            speciesName: 'mr-mime',
            details: [
              _detail(minLevel: 1),
              _detail(regionName: 'galar', minLevel: 1),
            ],
            evolvesTo: [
              EvolutionNode(
                speciesId: 866,
                speciesName: 'mr-rime',
                details: [
                  _detail(baseFormName: 'mr-mime-galar', baseFormId: 10168, minLevel: 42),
                ],
                evolvesTo: const [],
              ),
            ],
          ),
        ],
      );

  void main() {
    group('isRegionalVariety', () {
      test('false for default', () {
        expect(isRegionalVariety(const PokemonVariety(isDefault: true, name: 'zigzagoon')), isFalse);
      });
      test('true for -galar', () {
        expect(isRegionalVariety(const PokemonVariety(isDefault: false, name: 'zigzagoon-galar')), isTrue);
      });
      test('true for -alola, -hisui, -paldea', () {
        for (final s in ['-alola', '-hisui', '-paldea']) {
          expect(isRegionalVariety(PokemonVariety(isDefault: false, name: 'meowth$s')), isTrue);
        }
      });
      test('false for -mega, -gmax, cap', () {
        for (final n in ['charizard-mega-x', 'pikachu-alola-cap', 'venusaur-gmax']) {
          expect(isRegionalVariety(PokemonVariety(isDefault: false, name: n)), isFalse);
        }
      });
    });

    group('regionalSuffixOf', () {
      test('returns galar', () => expect(regionalSuffixOf('zigzagoon-galar'), 'galar'));
      test('null for plain', () => expect(regionalSuffixOf('zigzagoon'), isNull));
      test('null for cap', () => expect(regionalSuffixOf('pikachu-alola-cap'), isNull));
    });

    group('chainHasFormDetails', () {
      test('false for plain chain', () {
        final root = EvolutionNode(
          speciesId: 1, speciesName: 'bulbasaur', details: const [],
          evolvesTo: [
            EvolutionNode(speciesId: 2, speciesName: 'ivysaur',
                details: [_detail(minLevel: 16)], evolvesTo: const []),
          ],
        );
        expect(chainHasFormDetails(root), isFalse);
      });
      test('true for zigzagoon (base_form on edge)', () {
        expect(chainHasFormDetails(_zigzagoonChain()), isTrue);
      });
    });

    group('formSuffixForSpecies', () {
      test('returns galar for obstagoon (only galar edge reaches it)', () {
        expect(formSuffixForSpecies(_zigzagoonChain(), 862), 'galar');
      });
      test('returns galar for mr-rime', () {
        expect(formSuffixForSpecies(_mimeJrChain(), 866), 'galar');
      });
      test('null for species reachable via default edge', () {
        expect(formSuffixForSpecies(_zigzagoonChain(), 264), isNull);
      });
    });

    group('buildFormChain — default (null suffix)', () {
      test('zigzagoon: stops before obstagoon', () {
        final result = buildFormChain(_zigzagoonChain(), null, 263);
        expect(result.displayId, 263);
        expect(result.evolvesTo.length, 1);
        final linoone = result.evolvesTo.first;
        expect(linoone.displayId, 264);
        expect(linoone.evolvesTo, isEmpty);
      });
    });

    group('buildFormChain — galar suffix', () {
      test('zigzagoon: uses override IDs, includes obstagoon', () {
        final result = buildFormChain(_zigzagoonChain(), 'galar', 10174);
        expect(result.displayId, 10174);
        final linoone = result.evolvesTo.first;
        expect(linoone.displayId, 10175);
        expect(linoone.evolvesTo.first.displayId, 862);
      });
      test('mime-jr: galar chain via region edge → mr-mime-galar → mr-rime', () {
        final formIds = {'mr-mime-galar': 10168};
        final result = buildFormChain(_mimeJrChain(), 'galar', 439, formIds: formIds);
        expect(result.displayId, 439);
        final mrMime = result.evolvesTo.first;
        expect(mrMime.displayId, 10168);
        expect(mrMime.evolvesTo.first.source.speciesId, 866);
      });
    });

    group('formLabel', () {
      test('gen-iii → Hoennian Form', () {
        expect(formLabel(isDefault: true, varietyName: 'zigzagoon', generationName: 'generation-iii'),
            'Hoennian Form');
      });
      test('gen-i → Kantonian Form', () {
        expect(formLabel(isDefault: true, varietyName: 'meowth', generationName: 'generation-i'),
            'Kantonian Form');
      });
      test('-galar → Galarian Form', () {
        expect(formLabel(isDefault: false, varietyName: 'zigzagoon-galar', generationName: null),
            'Galarian Form');
      });
      test('unknown gen → Original Form', () {
        expect(formLabel(isDefault: true, varietyName: 'x', generationName: null), 'Original Form');
      });
    });
  }
  ```

- [ ] **Run tests — expect compilation failure**
  ```bash
  flutter test test/unit/evolution_chain_builder_test.dart
  ```
  Expected: error — file does not exist yet.

- [ ] **Create `lib/features/pokedex/logic/evolution_chain_builder.dart`**

  ```dart
  import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
  import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

  class DisplayNode {
    final EvolutionNode source;
    final int displayId;
    final List<DisplayNode> evolvesTo;
    List<EvolutionDetail>? matchedDetails;

    DisplayNode({
      required this.source,
      required this.displayId,
      required this.evolvesTo,
      this.matchedDetails,
    });
  }

  const _kRegionalSuffixes = {'-galar', '-alola', '-hisui', '-paldea'};

  bool isRegionalVariety(PokemonVariety variety) {
    if (variety.isDefault) return false;
    return _kRegionalSuffixes.any((s) => variety.name.endsWith(s));
  }

  String? regionalSuffixOf(String varietyName) {
    for (final s in _kRegionalSuffixes) {
      if (varietyName.endsWith(s)) return s.substring(1);
    }
    return null;
  }

  bool chainHasFormDetails(EvolutionNode node) {
    for (final child in node.evolvesTo) {
      if (child.details.any((d) => d.baseForm != null)) return true;
      if (chainHasFormDetails(child)) return true;
    }
    return false;
  }

  /// Returns the regional suffix needed to reach [targetSpeciesId] in [root]
  /// when every path to it goes through a form-specific edge (base_form only).
  /// Returns null if reachable via a default (no-form) edge, or not found.
  String? formSuffixForSpecies(EvolutionNode root, int targetSpeciesId) =>
      _findSuffix(root, targetSpeciesId);

  String? _findSuffix(EvolutionNode node, int targetSpeciesId) {
    for (final child in node.evolvesTo) {
      if (child.speciesId == targetSpeciesId) {
        final withBase = child.details.where((d) => d.baseForm != null).toList();
        final withoutBase = child.details.where((d) => d.baseForm == null).toList();
        if (withBase.isNotEmpty && withoutBase.isEmpty) {
          final suffixes = withBase
              .map((d) => regionalSuffixOf(d.baseForm!.name))
              .whereType<String>()
              .toSet();
          if (suffixes.length == 1) return suffixes.first;
        }
        return null;
      }
      final found = _findSuffix(child, targetSpeciesId);
      if (found != null) return found;
    }
    return null;
  }

  List<String> collectSpeciesNames(EvolutionNode node) =>
      [node.speciesName, ...node.evolvesTo.expand((c) => collectSpeciesNames(c))];

  /// Builds one [DisplayNode] chain for [formSuffix] (e.g. "galar") or
  /// the default chain when null. [formIds] maps "{name}-{suffix}" → Pokémon ID
  /// for resolving terminal-node IDs and region-keyed branches.
  DisplayNode buildFormChain(
    EvolutionNode root,
    String? formSuffix,
    int rootDisplayId, {
    Map<String, int> formIds = const {},
  }) =>
      _buildNode(root, formSuffix, rootDisplayId, formIds);

  DisplayNode _buildNode(
    EvolutionNode node,
    String? formSuffix,
    int displayId,
    Map<String, int> formIds,
  ) {
    final children = <DisplayNode>[];
    for (final child in node.evolvesTo) {
      if (formSuffix != null) {
        final detail = _matchingDetail(child.details, formSuffix);
        if (detail == null) continue;
        final childId = _resolveChildId(child, formSuffix, formIds);
        final n = _buildNode(child, formSuffix, childId, formIds);
        n.matchedDetails = [detail];
        children.add(n);
      } else {
        final defaultDetail =
            child.details.where((d) => d.baseForm == null && d.region == null).firstOrNull;
        if (defaultDetail != null) {
          final n = _buildNode(child, null, child.speciesId, formIds);
          n.matchedDetails = [defaultDetail];
          children.add(n);
        }
        // Region-keyed branches in the default chain (e.g. Alolan Raichu from Pikachu,
        // Galarian Mr. Mime from Mime Jr).
        for (final rd in child.details.where((d) => d.region != null)) {
          final rName = rd.region!.name;
          final rId = formIds['${child.speciesName}-$rName'];
          if (rId == null) continue;
          final n = _buildNode(child, rName, rId, formIds);
          n.matchedDetails = [rd];
          children.add(n);
        }
      }
    }
    return DisplayNode(source: node, displayId: displayId, evolvesTo: children);
  }

  EvolutionDetail? _matchingDetail(List<EvolutionDetail> details, String? suffix) {
    if (suffix == null) {
      return details.where((d) => d.baseForm == null && d.region == null).firstOrNull;
    }
    return details.where((d) =>
      d.baseForm?.name.endsWith('-$suffix') == true ||
      d.region?.name == suffix
    ).firstOrNull;
  }

  int _resolveChildId(EvolutionNode child, String? suffix, Map<String, int> formIds) {
    if (suffix == null) return child.speciesId;
    for (final gc in child.evolvesTo) {
      for (final d in gc.details) {
        if (d.baseForm?.name.endsWith('-$suffix') == true) return d.baseForm!.id;
      }
    }
    return formIds['${child.speciesName}-$suffix'] ?? child.speciesId;
  }

  const _kSuffixLabel = {
    'galar': 'Galarian Form', 'alola': 'Alolan Form',
    'hisui': 'Hisuian Form',  'paldea': 'Paldean Form',
  };

  const _kGenLabel = {
    'generation-i':    'Kantonian Form', 'generation-ii':  'Johtonian Form',
    'generation-iii':  'Hoennian Form',  'generation-iv':  'Sinnohian Form',
    'generation-v':    'Unovan Form',    'generation-vi':  'Kalosian Form',
    'generation-vii':  'Alolan Form',    'generation-viii':'Galarian Form',
    'generation-ix':   'Paldean Form',
  };

  String formLabel({
    required bool isDefault,
    required String varietyName,
    required String? generationName,
  }) {
    if (!isDefault) {
      final suffix = regionalSuffixOf(varietyName);
      if (suffix != null) return _kSuffixLabel[suffix] ?? 'Regional Form';
    }
    return (generationName != null ? _kGenLabel[generationName] : null) ?? 'Original Form';
  }

  /// Short label for the app bar badge (e.g. "Galarian", "Alolan").
  String shortFormLabel(String varietyName) {
    const suffixShort = {
      'galar': 'Galarian', 'alola': 'Alolan',
      'hisui': 'Hisuian',  'paldea': 'Paldean',
    };
    for (final entry in suffixShort.entries) {
      if (varietyName.endsWith('-${entry.key}')) return entry.value;
    }
    final parts = varietyName.split('-');
    final last = parts.last;
    return '${last[0].toUpperCase()}${last.substring(1)}';
  }
  ```

- [ ] **Run tests**
  ```bash
  flutter test test/unit/evolution_chain_builder_test.dart
  ```
  Expected: all pass.

- [ ] **Commit**
  ```bash
  git add lib/features/pokedex/logic/evolution_chain_builder.dart \
          test/unit/evolution_chain_builder_test.dart
  git commit -m "feat: add evolution_chain_builder with DisplayNode, form chain helpers"
  ```

---

## Task 3: Create `form_filter.dart` with tests

**Files:**
- Create: `lib/features/pokedex/logic/form_filter.dart`
- Create: `test/unit/pokedex_form_filter_test.dart`

- [ ] **Write failing tests**

  Create `test/unit/pokedex_form_filter_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
  import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

  PokemonVariety _v(String name, {bool isDefault = false}) =>
      PokemonVariety(isDefault: isDefault, name: name);

  void main() {
    group('battleMeaningfulForms', () {
      test('excludes default variety', () {
        final result = battleMeaningfulForms([_v('zigzagoon', isDefault: true), _v('zigzagoon-galar')]);
        expect(result.map((v) => v.name), ['zigzagoon-galar']);
      });

      test('includes regional suffixes', () {
        final varieties = [
          _v('meowth', isDefault: true),
          _v('meowth-alola'),
          _v('meowth-galar'),
        ];
        final result = battleMeaningfulForms(varieties);
        expect(result.map((v) => v.name), containsAll(['meowth-alola', 'meowth-galar']));
      });

      test('excludes mega, gmax, eternamax', () {
        final varieties = [
          _v('charizard', isDefault: true),
          _v('charizard-mega-x'),
          _v('charizard-mega-y'),
          _v('charizard-gmax'),
        ];
        expect(battleMeaningfulForms(varieties), isEmpty);
      });

      test('includes meowstic-female (different stats/moves)', () {
        final result = battleMeaningfulForms([_v('meowstic', isDefault: true), _v('meowstic-female')]);
        expect(result.map((v) => v.name), contains('meowstic-female'));
      });

      test('includes rotom appliances', () {
        final varieties = [
          _v('rotom', isDefault: true),
          _v('rotom-heat'), _v('rotom-wash'), _v('rotom-frost'),
          _v('rotom-fan'), _v('rotom-mow'),
        ];
        final result = battleMeaningfulForms(varieties);
        expect(result.length, 5);
      });

      test('excludes cosmetic-only (pikachu cap variants)', () {
        final varieties = [
          _v('pikachu', isDefault: true),
          _v('pikachu-original-cap'),
          _v('pikachu-alola-cap'),
          _v('pikachu-gmax'),
        ];
        expect(battleMeaningfulForms(varieties), isEmpty);
      });

      test('includes urshifu-rapid-strike', () {
        final result = battleMeaningfulForms([
          _v('urshifu', isDefault: true), _v('urshifu-rapid-strike'),
        ]);
        expect(result.map((v) => v.name), contains('urshifu-rapid-strike'));
      });
    });
  }
  ```

- [ ] **Run tests — expect compilation failure**
  ```bash
  flutter test test/unit/pokedex_form_filter_test.dart
  ```

- [ ] **Create `lib/features/pokedex/logic/form_filter.dart`**

  ```dart
  import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

  const _kRegionalSuffixes = {'-galar', '-alola', '-hisui', '-paldea'};

  const _kExcludeSuffixes = {
    '-mega', '-mega-x', '-mega-y', '-mega-z',
    '-gmax', '-eternamax', '-totem',
  };

  /// Non-regional forms with meaningfully different stats, moves, or abilities.
  const _kBattleMeaningfulNames = {
    'meowstic-female',
    'indeedee-female',
    'basculegion-female',
    'urshifu-rapid-strike',
    'lycanroc-midnight', 'lycanroc-dusk',
    'oricorio-pom-pom', 'oricorio-pau', 'oricorio-sensu',
    'toxtricity-low-key',
    'rotom-heat', 'rotom-wash', 'rotom-frost', 'rotom-fan', 'rotom-mow',
    'zacian-crowned', 'zamazenta-crowned',
    'calyrex-ice', 'calyrex-shadow',
    'palafin-hero',
  };

  /// Returns non-default [varieties] that are battle-meaningful — regional forms
  /// and significant gender/form differences. Excludes Megas, Gigantamax,
  /// cosmetic-only forms, and the default variety.
  List<PokemonVariety> battleMeaningfulForms(List<PokemonVariety> varieties) {
    return varieties.where((v) {
      if (v.isDefault) return false;
      final name = v.name;
      if (_kExcludeSuffixes.any((s) => name.endsWith(s))) return false;
      if (_kRegionalSuffixes.any((s) => name.endsWith(s))) return true;
      if (_kBattleMeaningfulNames.contains(name)) return true;
      return false;
    }).toList();
  }
  ```

- [ ] **Run tests**
  ```bash
  flutter test test/unit/pokedex_form_filter_test.dart
  ```
  Expected: all pass.

- [ ] **Commit**
  ```bash
  git add lib/features/pokedex/logic/form_filter.dart \
          test/unit/pokedex_form_filter_test.dart
  git commit -m "feat: add battleMeaningfulForms form filter for Pokédex form switcher"
  ```

---

## Task 4: Add `_selectedFormName` state + `effectivePokemon` to the detail screen

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart`

`_PokemonDetailScreenState` already has `_shiny` and `_tabController`. This task adds `_selectedFormName` and derives `effectivePokemon` in `build()`.

- [ ] **Add imports at the top of `pokemon_detail_screen.dart`**

  Find the existing imports block and add:
  ```dart
  import 'package:poke_team_dex/features/pokedex/logic/evolution_chain_builder.dart';
  import 'package:poke_team_dex/features/pokedex/logic/form_filter.dart';
  ```

- [ ] **Add `_selectedFormName` field to `_PokemonDetailScreenState`**

  After `bool _shiny = false;` add:
  ```dart
  String? _selectedFormName; // null = base form
  ```

- [ ] **Update `build()` to derive `effectivePokemon`**

  The current `build()` starts at line ~98. Replace it so that after watching the two base providers, it also watches the form provider:

  ```dart
  @override
  Widget build(BuildContext context) {
    final pokemonAsync = ref.watch(pokemonDetailProvider(widget.pokemonId));
    final speciesAsync = ref.watch(pokemonSpeciesProvider(widget.pokemonId));
    final formAsync = _selectedFormName != null
        ? ref.watch(pokemonByNameProvider(_selectedFormName!))
        : null;
    final isWide = MediaQuery.sizeOf(context).width > 840;

    return pokemonAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const LoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(pokemonDetailProvider(widget.pokemonId)),
        ),
      ),
      data: (basePokemon) {
        final effectivePokemon = formAsync?.asData?.value ?? basePokemon;
        final primaryType =
            effectivePokemon.types[1] ?? effectivePokemon.types.values.first;
        final headerColor =
            PokemonTypeColors.colors[primaryType] ?? Theme.of(context).colorScheme.primary;

        return isWide
            ? _buildWideLayout(context, basePokemon, effectivePokemon, speciesAsync, headerColor)
            : _buildNarrowLayout(context, basePokemon, effectivePokemon, speciesAsync, headerColor);
      },
    );
  }
  ```

- [ ] **Update `_buildNarrowLayout` signature + body**

  ```dart
  Widget _buildNarrowLayout(
    BuildContext context,
    PokemonEntry basePokemon,
    PokemonEntry effectivePokemon,
    AsyncValue<PokemonSpeciesEntry> speciesAsync,
    Color headerColor,
  ) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _DetailSliverAppBar(
            basePokemon: basePokemon,
            effectivePokemon: effectivePokemon,
            headerColor: headerColor,
            shiny: _shiny,
            onShinyToggle: () => setState(() => _shiny = !_shiny),
            tabController: _tabController,
            tabs: _tabs,
            speciesAsync: speciesAsync,
            selectedFormName: _selectedFormName,
            onFormSelect: (name) => setState(() => _selectedFormName = name),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _tabChildren(basePokemon, effectivePokemon, speciesAsync),
        ),
      ),
    );
  }
  ```

- [ ] **Update `_buildWideLayout` signature to match**

  Add `PokemonEntry basePokemon, PokemonEntry effectivePokemon,` parameters and replace `pokemon` references to use either `basePokemon` (for `displayId()`, `displaySpeciesName`, navigation) or `effectivePokemon` (for sprite, types, stats). Also pass `speciesAsync`, `selectedFormName`, `onFormSelect` to the wide AppBar actions (see Task 5). Note: `widget.pokemonId` stays as-is for Teams/Locations.

- [ ] **Update `_tabChildren` signature**

  ```dart
  List<Widget> _tabChildren(
    PokemonEntry basePokemon,
    PokemonEntry effectivePokemon,
    AsyncValue<PokemonSpeciesEntry> speciesAsync,
  ) => [
    _OverviewTab(pokemon: effectivePokemon, speciesAsync: speciesAsync),
    _StatsTab(pokemon: effectivePokemon),
    _AbilitiesTab(pokemon: effectivePokemon),
    _MovesTab(pokemon: effectivePokemon),
    _EvolutionsTab(speciesAsync: speciesAsync, selectedFormName: _selectedFormName),
    _FormsTab(speciesAsync: speciesAsync, battleForms: [], selectedFormName: _selectedFormName, onFormSelect: (name) => setState(() => _selectedFormName = name)),
    _LocationsTab(pokemonId: effectivePokemon.id),
    _TeamsTab(pokemonId: widget.pokemonId, pokemon: basePokemon, selectedFormName: _selectedFormName),
  ];
  ```

  Note: `_FormsTab`'s `battleForms` list is filled from the species data — Task 8 will compute this properly; pass `const []` for now.

- [ ] **Verify compile**
  ```bash
  flutter analyze lib/features/pokedex/presentation/pokemon_detail_screen.dart
  ```
  Fix any type errors from the signature changes before proceeding.

- [ ] **Commit**
  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart
  git commit -m "feat: add _selectedFormName state and effectivePokemon derivation to detail screen"
  ```

---

## Task 5: Add form badge + bottom sheet picker

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart`

This task adds the `_FormBadge` widget (the compact chip in the app bar) and `_FormPickerSheet` (the bottom sheet). It also wires them into `_DetailSliverAppBar` and the wide-layout `AppBar`.

- [ ] **Add `_FormBadge` widget**

  Add this class at the bottom of `pokemon_detail_screen.dart` (before the last `}`):

  ```dart
  /// Compact chip button in the app bar that opens the form picker sheet.
  /// Only rendered when [battleForms] is non-empty.
  class _FormBadge extends StatelessWidget {
    final List<PokemonVariety> battleForms;
    final String? selectedFormName;
    final PokemonEntry effectivePokemon;
    final bool shiny;
    final void Function(String?) onSelect;

    const _FormBadge({
      required this.battleForms,
      required this.selectedFormName,
      required this.effectivePokemon,
      required this.shiny,
      required this.onSelect,
    });

    @override
    Widget build(BuildContext context) {
      if (battleForms.isEmpty) return const SizedBox.shrink();
      final label = selectedFormName != null
          ? shortFormLabel(selectedFormName!)
          : 'Base';
      return GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => _FormPickerSheet(
            battleForms: battleForms,
            selectedFormName: selectedFormName,
            shiny: shiny,
            onSelect: (name) {
              onSelect(name);
              Navigator.pop(context);
            },
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white38),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
            ],
          ),
        ),
      );
    }
  }

  class _FormPickerSheet extends ConsumerWidget {
    final List<PokemonVariety> battleForms;
    final String? selectedFormName;
    final bool shiny;
    final void Function(String?) onSelect;

    const _FormPickerSheet({
      required this.battleForms,
      required this.selectedFormName,
      required this.shiny,
      required this.onSelect,
    });

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final colorScheme = Theme.of(context).colorScheme;
      // All forms including "Base" as the first entry (null = base).
      final allOptions = <(String? name, String label)>[
        (null, 'Base Form'),
        ...battleForms.map((v) => (v.name, shortFormLabel(v.name))),
      ];

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Form', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: allOptions.map((opt) {
                final (name, label) = opt;
                final isSelected = name == selectedFormName;
                // Fetch the Pokémon entry to get the sprite.
                final pokemonAsync = name != null
                    ? ref.watch(pokemonByNameProvider(name))
                    : null;
                final formPokemon = pokemonAsync?.asData?.value;
                final spriteUrl = shiny
                    ? (formPokemon?.officialArtworkShinyUrl ?? formPokemon?.officialArtworkUrl)
                    : formPokemon?.officialArtworkUrl;

                return GestureDetector(
                  onTap: () => onSelect(name),
                  child: Container(
                    width: 88,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (spriteUrl != null)
                          CachedNetworkImage(imageUrl: spriteUrl, height: 56, width: 56)
                        else
                          const SizedBox(height: 56, width: 56,
                              child: Icon(Icons.catching_pokemon, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? colorScheme.primary : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Update `_DetailSliverAppBar` to accept form parameters**

  Add to `_DetailSliverAppBar` fields and constructor:
  ```dart
  final PokemonEntry effectivePokemon;      // NEW — for sprite and types
  final PokemonEntry basePokemon;            // NEW — rename 'pokemon' to this
  final AsyncValue<PokemonSpeciesEntry> speciesAsync;  // NEW — for battleMeaningfulForms
  final String? selectedFormName;            // NEW
  final void Function(String?) onFormSelect; // NEW
  ```

  Rename the existing `final PokemonEntry pokemon;` to `final PokemonEntry basePokemon;` and add the new fields.

  In `_DetailSliverAppBar.build()`:
  - Sprite: change to use `effectivePokemon` for artwork URLs:
    ```dart
    PokemonSprite(
      defaultUrl: effectivePokemon.officialArtworkUrl,
      shinyUrl: effectivePokemon.officialArtworkShinyUrl,
      shiny: shiny,
      size: 200,
    )
    ```
  - Title: keep `basePokemon.displayId()  basePokemon.displaySpeciesName`
  - Actions: add `_FormBadge` before the shiny icon:
    ```dart
    speciesAsync.asData?.when(
      data: (species) {
        final forms = battleMeaningfulForms(species.varieties);
        if (forms.isEmpty) return const SizedBox.shrink();
        return _FormBadge(
          battleForms: forms,
          selectedFormName: selectedFormName,
          effectivePokemon: effectivePokemon,
          shiny: shiny,
          onSelect: onFormSelect,
        );
      },
      loading: () => null,
      error: (_, __) => null,
    ) ?? const SizedBox.shrink(),
    ```
  
  Note: `speciesAsync.asData?.when` — use `asData?.value` to unwrap:
    ```dart
    Builder(builder: (context) {
      final species = speciesAsync.asData?.value;
      if (species == null) return const SizedBox.shrink();
      final forms = battleMeaningfulForms(species.varieties);
      if (forms.isEmpty) return const SizedBox.shrink();
      return _FormBadge(
        battleForms: forms,
        selectedFormName: selectedFormName,
        effectivePokemon: effectivePokemon,
        shiny: shiny,
        onSelect: onFormSelect,
      );
    }),
    ```

- [ ] **Add form badge to the wide-layout AppBar actions similarly**

  In `_buildWideLayout`, the `AppBar` has `actions: [FavoriteButton(...), IconButton(shiny...), ...]`. Insert the `_FormBadge` in the same position as in the narrow layout.

- [ ] **Verify**
  ```bash
  flutter analyze lib/features/pokedex/presentation/pokemon_detail_screen.dart
  ```
  Expected: `No issues found!`

- [ ] **Commit**
  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart
  git commit -m "feat: add form badge and bottom sheet picker to Pokédex detail screen"
  ```

---

## Task 6: Update `_EvolutionsTab` for single-chain rendering

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart` (lines ~1374–1483)

The old `_EvolutionsTab` does not accept a form name and always shows the default chain. This task replaces it with the form-aware single-chain version using `evolution_chain_builder.dart`.

- [ ] **Replace `_EvolutionsTab` class**

  Find `class _EvolutionsTab` (~line 1374). Replace the entire class and the `_FormChainSection` / `_EvolutionTree` / `_EvolutionNodeCard` / `_EvolutionArrow` / `_ConditionChip` classes with the versions below. Also add `DisplayNode` import (already done in Task 4).

  ```dart
  class _EvolutionsTab extends ConsumerWidget {
    final AsyncValue<PokemonSpeciesEntry> speciesAsync;
    final String? selectedFormName;
    const _EvolutionsTab({required this.speciesAsync, this.selectedFormName});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      return speciesAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e),
        data: (species) {
          final chainId = species.evolutionChainId;
          if (chainId == null) {
            return const EmptyState(icon: Icons.device_unknown, title: 'No evolution data');
          }
          final chainAsync = ref.watch(evolutionChainProvider(chainId));
          return chainAsync.when(
            loading: () => const LoadingState(),
            error: (e, _) => ErrorState(error: e),
            data: (root) {
              // Step 1: suffix from the form switcher.
              String? suffix = selectedFormName != null
                  ? regionalSuffixOf(selectedFormName!)
                  : null;
              // Step 2: auto-detect for Pokémon like Obstagoon/Mr. Rime.
              suffix ??= chainHasFormDetails(root)
                  ? formSuffixForSpecies(root, species.id)
                  : null;

              // Pre-resolve form IDs for terminal nodes and region branches.
              final allNames = collectSpeciesNames(root);
              const regionalSuffixes = ['galar', 'alola', 'hisui', 'paldea'];
              final formIds = <String, int>{};
              for (final name in allNames) {
                for (final s in regionalSuffixes) {
                  final async = ref.watch(pokemonByNameProvider('$name-$s'));
                  final id = async.asData?.value.id;
                  if (id != null) formIds['$name-$s'] = id;
                }
              }

              // Root display ID: Galarian form of the root species if available.
              final rootDisplayId = suffix != null
                  ? (formIds['${root.speciesName}-$suffix'] ?? root.speciesId)
                  : root.speciesId;

              final displayRoot = buildFormChain(root, suffix, rootDisplayId, formIds: formIds);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _EvolutionTree(displayNode: displayRoot),
              );
            },
          );
        },
      );
    }
  }

  class _EvolutionTree extends StatelessWidget {
    final DisplayNode displayNode;
    const _EvolutionTree({required this.displayNode});

    @override
    Widget build(BuildContext context) {
      final node = displayNode;
      if (node.evolvesTo.isEmpty) return _EvolutionNodeCard(displayNode: node);

      if (node.evolvesTo.length == 1) {
        final child = node.evolvesTo.first;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EvolutionNodeCard(displayNode: node),
            const SizedBox(height: 6),
            _EvolutionArrow(details: child.matchedDetails ?? child.source.details),
            const SizedBox(height: 6),
            _EvolutionTree(displayNode: child),
          ],
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EvolutionNodeCard(displayNode: node),
          const SizedBox(height: 6),
          const Icon(Icons.call_split_rounded, size: 22, color: Colors.grey),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 16,
            children: node.evolvesTo.map((child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ConditionChip(details: child.matchedDetails ?? child.source.details),
                const SizedBox(height: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.shade400),
                const SizedBox(height: 4),
                _EvolutionTree(displayNode: child),
              ],
            )).toList(),
          ),
        ],
      );
    }
  }

  class _EvolutionNodeCard extends StatelessWidget {
    final DisplayNode displayNode;
    const _EvolutionNodeCard({required this.displayNode});

    @override
    Widget build(BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      final spriteUrl =
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${displayNode.displayId}.png';
      return GestureDetector(
        onTap: () => context.push('/pokedex/${displayNode.source.speciesId}'),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CachedNetworkImage(
                imageUrl: spriteUrl,
                width: 72, height: 72,
                placeholder: (_, _) => const SizedBox(width: 72, height: 72,
                    child: Icon(Icons.catching_pokemon, color: Colors.grey)),
                errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
              ),
              const SizedBox(height: 4),
              Text(displayNode.source.displayName,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              Text('#${displayNode.source.speciesId.toString().padLeft(3, '0')}',
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
  }
  ```

  Keep `_EvolutionArrow` and `_ConditionChip` unchanged from their current implementations — they already work correctly.

- [ ] **Verify**
  ```bash
  flutter analyze lib/features/pokedex/presentation/pokemon_detail_screen.dart
  ```

- [ ] **Commit**
  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart
  git commit -m "feat: update _EvolutionsTab to single-chain rendering with form-aware suffix resolution"
  ```

---

## Task 7: Update `_FormsTab` and `_TeamsTab`

**Files:**
- Modify: `lib/features/pokedex/presentation/pokemon_detail_screen.dart`

- [ ] **Update `_FormsTab` to exclude battle-meaningful forms**

  Find `class _FormsTab` (~line 1575). Update constructor and build to filter out battle-meaningful forms:

  ```dart
  class _FormsTab extends ConsumerWidget {
    final AsyncValue<PokemonSpeciesEntry> speciesAsync;
    final String? selectedFormName;
    final void Function(String?) onFormSelect;
    const _FormsTab({
      required this.speciesAsync,
      required this.selectedFormName,
      required this.onFormSelect,
    });

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      return speciesAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e),
        data: (species) {
          // Exclude battle-meaningful forms — they live in the app bar switcher.
          final switcherForms = battleMeaningfulForms(species.varieties)
              .map((v) => v.name)
              .toSet();
          final nonDefault = species.varieties
              .where((v) => !v.isDefault && !switcherForms.contains(v.name))
              .toList();
          if (nonDefault.isEmpty) {
            return const EmptyState(
              icon: Icons.style_outlined,
              title: 'No alternate forms',
              subtitle: 'Alternate regional forms are accessible via the form switcher above.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: nonDefault.length,
            separatorBuilder: (_, _) => const Divider(height: 24),
            itemBuilder: (_, i) => _FormCard(variety: nonDefault[i]),
          );
        },
      );
    }
  }
  ```

  Also update `_tabChildren` to pass the correct arguments (remove the `battleForms: const []` placeholder from Task 4):
  ```dart
  _FormsTab(
    speciesAsync: speciesAsync,
    selectedFormName: _selectedFormName,
    onFormSelect: (name) => setState(() => _selectedFormName = name),
  ),
  ```

- [ ] **Update `_TeamsTab` to filter by `selectedFormName`**

  Find `class _TeamsTab` (~line 1882). Add `selectedFormName` parameter and filter the stream results:

  ```dart
  class _TeamsTab extends ConsumerWidget {
    final int pokemonId;
    final PokemonEntry pokemon;
    final String? selectedFormName;
    const _TeamsTab({
      required this.pokemonId,
      required this.pokemon,
      this.selectedFormName,
    });

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final pairsAsync = ref.watch(teamsForPokemonProvider(pokemonId));
      // ... existing colorScheme / textTheme setup unchanged ...

      return pairsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e),
        data: (allPairs) {
          // Filter by selected form: null selectedFormName matches slots with
          // no formName (base form). Non-null matches the specific form name.
          final pairs = allPairs.where((pair) {
            final (_, slot) = pair;
            return slot.formName == selectedFormName;
          }).toList();
          // ... rest of existing build logic uses `pairs` instead of the
          // original variable name — keep all existing UI code unchanged.
        },
      );
    }
  }
  ```

- [ ] **Verify**
  ```bash
  flutter analyze lib/features/pokedex/presentation/pokemon_detail_screen.dart
  ```
  Expected: `No issues found!`

- [ ] **Run all tests**
  ```bash
  flutter test test/unit/
  ```
  Expected: all pass.

- [ ] **Commit**
  ```bash
  git add lib/features/pokedex/presentation/pokemon_detail_screen.dart
  git commit -m "feat: update _FormsTab and _TeamsTab for form switcher integration"
  ```

---

## Task 8: Branch, push, open PR

- [ ] **Create branch from current state**
  ```bash
  git checkout -b feat/regional-form-switching
  # All Task 1–7 commits are already on this branch if you branched at the start.
  # If you committed on main, cherry-pick or rebase now.
  git push origin feat/regional-form-switching
  ```

- [ ] **Open PR**
  ```bash
  gh pr create \
    --title "feat: regional form switching in Pokédex detail screen" \
    --body "$(cat <<'EOF'
  ## Summary

  - Adds a compact form-switcher badge to the Pokémon detail screen app bar, visible only for Pokémon with battle-meaningful forms (regional variants, significant gender/form differences; excludes Megas, Gigantamax, cosmetics).
  - Switching form updates every tab: Overview, Stats, Abilities, Moves, Locations, and Teams use `effectivePokemon` from `pokemonByNameProvider(selectedFormName)`. The shiny toggle applies to the selected form's artwork.
  - Evolutions tab shows a single form-correct chain: selected suffix from the switcher, or auto-detected via `formSuffixForSpecies` for terminal evolutions like Obstagoon and Mr. Rime.
  - Forms tab excludes battle-meaningful forms (they're in the switcher) and shows only cosmetics/Megas/Gigantamax.
  - Teams tab filters slots by `formName == selectedFormName`.

  ## Test plan

  - [ ] Zigzagoon → select Galarian Form → Evolutions shows Galarian chain → Obstagoon
  - [ ] Obstagoon → Evolutions auto-shows Galarian chain (no switcher needed)
  - [ ] Mr. Mime → select Galarian Form → Stats/Abilities/Moves show Galarian data; Evolutions shows Mime Jr → Galarian Mr. Mime → Mr. Rime
  - [ ] Mr. Rime → Evolutions auto-shows Galarian chain
  - [ ] Raichu → select Alolan Form → sprite shows Alolan Raichu, types = Electric/Psychic; toggle shiny → shiny Alolan Raichu artwork
  - [ ] Pikachu → Evolutions shows Pichu → Pikachu → [Raichu | Raichu-Alola] branch in default chain
  - [ ] Meowth → switcher shows Alolan and Galarian forms
  - [ ] Rotom → switcher shows all 5 appliance forms
  - [ ] Venusaur → no switcher (Mega is excluded)
  - [ ] Teams tab: slot with formName="mr-mime-galar" shown only when Galarian is selected
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  EOF
  )"
  ```
