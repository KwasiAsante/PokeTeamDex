# Form Handling Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the files that must be edited when a new Pokémon form ships, and replace scattered `slot.isMegaEvolved` / `slot.formName` reads across widgets with a single `FormDescriptor` value object.

**Architecture:** Shared static data (PS name exceptions, cosmetic sprite stems) moves to `form_data.dart`; form gating rules gain typed classes; the PS resolution heuristics are extracted to a testable `ps_form_resolver.dart`; `FormDescriptor` wraps all DB form-state columns and computes `effectiveApiName` / `spriteHint`; the sprite resolver receives a `SpriteHint` and URL helpers are extracted to named functions.

**Tech Stack:** Flutter/Dart, Drift ORM, flutter_test, PokeAPI sprites (raw.githubusercontent.com)

**Spec:** `docs/superpowers/specs/2026-06-09-form-handling-redesign.md`

**Dependency order:** Task 1 → Task 2 → Task 3 (independent). Task 4 depends on Task 1. Task 5 depends on Task 4. Task 6 depends on Tasks 1 and 4.

---

### Task 1: Create `form_data.dart` — shared static entries (sub-issue B)

**Files:**
- Create: `lib/features/teams/data/form_data.dart`
- Create: `test/unit/form_data_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/form_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/data/form_data.dart';

void main() {
  group('kPsFormExceptions', () {
    test('maps ogerpon-wellspring to ogerpon-wellspring-mask', () {
      expect(kPsFormExceptions['ogerpon-wellspring'], 'ogerpon-wellspring-mask');
    });

    test('maps ogerpon-hearthflame to ogerpon-hearthflame-mask', () {
      expect(kPsFormExceptions['ogerpon-hearthflame'], 'ogerpon-hearthflame-mask');
    });

    test('maps ogerpon-cornerstone to ogerpon-cornerstone-mask', () {
      expect(kPsFormExceptions['ogerpon-cornerstone'], 'ogerpon-cornerstone-mask');
    });

    test('maps ogerpon-teal to ogerpon-teal-mask', () {
      expect(kPsFormExceptions['ogerpon-teal'], 'ogerpon-teal-mask');
    });

    test('all keys are lowercase hyphenated', () {
      for (final key in kPsFormExceptions.keys) {
        expect(key, equals(key.toLowerCase()), reason: '$key must be lowercase');
        expect(key.contains(' '), isFalse, reason: '$key must use hyphens not spaces');
      }
    });
  });

  group('kCosmeticSpriteStems', () {
    test('burmy sandy cloak stem is 412-sandy', () {
      expect(kCosmeticSpriteStems['burmy']?['burmy-sandy'], '412-sandy');
    });

    test('burmy trash cloak stem is 412-trash', () {
      expect(kCosmeticSpriteStems['burmy']?['burmy-trash'], '412-trash');
    });

    test('shellos east sea stem is 422-east', () {
      expect(kCosmeticSpriteStems['shellos']?['shellos-east'], '422-east');
    });

    test('all stem values follow {id}-{suffix} format', () {
      for (final entry in kCosmeticSpriteStems.entries) {
        for (final stem in entry.value.values) {
          expect(
            stem.contains('-'),
            isTrue,
            reason: 'stem "$stem" must follow {id}-{suffix} format',
          );
        }
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/unit/form_data_test.dart
```
Expected: FAIL — `'package:poke_team_dex/features/teams/data/form_data.dart' not found`

- [ ] **Step 3: Create `form_data.dart`**

```dart
// lib/features/teams/data/form_data.dart

/// PS species name → PokéAPI variety name for known mismatches.
/// Checked before the heuristic pipeline in ps_form_resolver.dart — O(1), no API call.
/// All keys must be lowercase-hyphenated (normalised PS names).
const Map<String, String> kPsFormExceptions = {
  // Ogerpon mask forms — PS omits the "-mask" suffix
  'ogerpon-teal':         'ogerpon-teal-mask',
  'ogerpon-wellspring':   'ogerpon-wellspring-mask',
  'ogerpon-hearthflame':  'ogerpon-hearthflame-mask',
  'ogerpon-cornerstone':  'ogerpon-cornerstone-mask',
};

/// Cosmetic forms that share their base species' /pokemon resource.
/// Structure: baseSpecies → { formName → spriteFileStem }
/// The stem is used in sprite path building: "{stem}.png" / "{stem}-shiny.png".
/// e.g. Burmy Sandy Cloak is filed under "412-sandy" in every sprite tier.
const Map<String, Map<String, String>> kCosmeticSpriteStems = {
  'burmy': {
    'burmy-sandy': '412-sandy',
    'burmy-trash': '412-trash',
  },
  'wormadam': {
    'wormadam-sandy': '413-sandy',
    'wormadam-trash': '413-trash',
  },
  'shellos': {
    'shellos-east': '422-east',
  },
  'gastrodon': {
    'gastrodon-east': '423-east',
  },
  'deerling': {
    'deerling-summer': '585-summer',
    'deerling-autumn': '585-autumn',
    'deerling-winter': '585-winter',
  },
  'sawsbuck': {
    'sawsbuck-summer': '586-summer',
    'sawsbuck-autumn': '586-autumn',
    'sawsbuck-winter': '586-winter',
  },
};
```

- [ ] **Step 4: Run test to verify it passes**

```
flutter test test/unit/form_data_test.dart
```
Expected: All 9 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/teams/data/form_data.dart test/unit/form_data_test.dart
git commit -m "feat: add form_data.dart with PS exceptions and cosmetic sprite stems"
```

---

### Task 2: Refactor `form_filter.dart` to typed gating rule classes (sub-issue C)

**Files:**
- Modify: `lib/features/teams/data/form_filter.dart`
- Test: `test/unit/form_filter_test.dart` (existing — all tests must still pass)

The goal is to merge `kArceusPlateForms` and `kSilvallyMemoryForms` into `kItemGatingRules` and replace the raw maps with typed classes. The public API of `filterFormChips()` is unchanged — all existing tests must pass without modification.

- [ ] **Step 1: Run existing tests to confirm baseline**

```
flutter test test/unit/form_filter_test.dart
```
Expected: All tests PASS. If any fail, fix before proceeding.

- [ ] **Step 2: Replace `form_filter.dart` with the typed implementation**

```dart
// lib/features/teams/data/form_filter.dart
// Form chip filtering rules for the slot config form selector.
//
// Rules:
// 1. Always exclude: mega, gmax, gender forms — handled by separate toggles
//    or the gender selector.
// 2. Ability-gated: form chip shown only when the required ability is selected.
// 3. Item-gated: form chip shown only when one of the required items is held.
// 4. Everything else: shown freely as a chip.

// ── Always-exclude patterns ────────────────────────────────────────────────

/// Form name suffixes that should never appear as chips.
///
/// Primal Reversion (`-primal`) is deliberately NOT here — unlike Mega
/// Evolution (an optional in-battle action the trainer chooses to trigger,
/// modelled as a separate toggle), Primal Reversion happens automatically
/// and unavoidably whenever Primal Groudon/Kyogre enters battle holding its
/// orb. That makes it mechanically identical to Giratina's Origin Forme —
/// an automatic, item-bound form change — so it's gated the same way, via
/// [kItemGatingRules] below.
const Set<String> kExcludeFormSuffixes = {
  '-mega', '-mega-x', '-mega-y', '-mega-z',
  '-gmax',
  '-eternamax',
  '-female',
};

/// Specific form names always excluded (gender-only forms without -female suffix).
const Set<String> kAlwaysExcludeForms = {
  'indeedee-female',
  'basculegion-female',
  'oinkologne-female',
};

// ── Typed gating rule classes ──────────────────────────────────────────────

/// A form chip that is shown only when a specific ability is active.
class AbilityGatingRule {
  final String requiredAbility;
  const AbilityGatingRule(this.requiredAbility);
}

/// A form chip that is shown only when one of [requiredItems] is held.
/// Uses a Set to support forms that can be triggered by multiple items
/// (e.g. Giratina-Origin works with both Griseous Orb and Griseous Core).
class ItemGatingRule {
  final Set<String> requiredItems;
  const ItemGatingRule(this.requiredItems);
}

// ── Ability-gated forms ────────────────────────────────────────────────────

/// Form chip is shown only when the mapped ability is selected.
const Map<String, AbilityGatingRule> kAbilityGatingRules = {
  'aegislash-blade':        AbilityGatingRule('stance-change'),
  'darmanitan-zen':         AbilityGatingRule('zen-mode'),
  'darmanitan-galar-zen':   AbilityGatingRule('zen-mode'),
  'wishiwashi-school':      AbilityGatingRule('schooling'),
  'cherrim-sunshine':       AbilityGatingRule('flower-gift'),
  'morpeko-hangry':         AbilityGatingRule('hunger-switch'),
  'mimikyu-busted':         AbilityGatingRule('disguise'),
  'minior-red-core':        AbilityGatingRule('shields-down'),
  'minior-orange-core':     AbilityGatingRule('shields-down'),
  'minior-yellow-core':     AbilityGatingRule('shields-down'),
  'minior-green-core':      AbilityGatingRule('shields-down'),
  'minior-blue-core':       AbilityGatingRule('shields-down'),
  'minior-indigo-core':     AbilityGatingRule('shields-down'),
  'minior-violet-core':     AbilityGatingRule('shields-down'),
  'eiscue-noice':           AbilityGatingRule('ice-face'),
  'palafin-hero':           AbilityGatingRule('zero-to-hero'),
};

// ── Item-gated forms ──────────────────────────────────────────────────────

/// Form chip shown only when one of the required held items is selected.
/// Covers legendary item-bound forms, Primal Reversion, Arceus plates,
/// and Silvally memories — all unified under one map.
const Map<String, ItemGatingRule> kItemGatingRules = {
  // Legendary / item-bound forms
  'giratina-origin':       ItemGatingRule({'griseous-orb', 'griseous-core'}),
  'zacian-crowned':        ItemGatingRule({'rusted-sword'}),
  'zamazenta-crowned':     ItemGatingRule({'rusted-shield'}),
  'calyrex-ice-rider':     ItemGatingRule({'reins-of-unity'}),
  'calyrex-shadow-rider':  ItemGatingRule({'reins-of-unity'}),
  'dialga-origin':         ItemGatingRule({'adamant-crystal'}),
  'palkia-origin':         ItemGatingRule({'lustrous-globe'}),
  'groudon-primal':        ItemGatingRule({'red-orb'}),
  'kyogre-primal':         ItemGatingRule({'blue-orb'}),
  // Arceus plate forms
  'arceus-fighting': ItemGatingRule({'fist-plate'}),
  'arceus-flying':   ItemGatingRule({'sky-plate'}),
  'arceus-poison':   ItemGatingRule({'toxic-plate'}),
  'arceus-ground':   ItemGatingRule({'earth-plate'}),
  'arceus-rock':     ItemGatingRule({'stone-plate'}),
  'arceus-bug':      ItemGatingRule({'insect-plate'}),
  'arceus-ghost':    ItemGatingRule({'spooky-plate'}),
  'arceus-steel':    ItemGatingRule({'iron-plate'}),
  'arceus-fire':     ItemGatingRule({'flame-plate'}),
  'arceus-water':    ItemGatingRule({'splash-plate'}),
  'arceus-grass':    ItemGatingRule({'meadow-plate'}),
  'arceus-electric': ItemGatingRule({'zap-plate'}),
  'arceus-psychic':  ItemGatingRule({'mind-plate'}),
  'arceus-ice':      ItemGatingRule({'icicle-plate'}),
  'arceus-dragon':   ItemGatingRule({'draco-plate'}),
  'arceus-dark':     ItemGatingRule({'dread-plate'}),
  'arceus-fairy':    ItemGatingRule({'pixie-plate'}),
  // Silvally memory forms
  'silvally-fighting': ItemGatingRule({'fighting-memory'}),
  'silvally-flying':   ItemGatingRule({'flying-memory'}),
  'silvally-poison':   ItemGatingRule({'poison-memory'}),
  'silvally-ground':   ItemGatingRule({'ground-memory'}),
  'silvally-rock':     ItemGatingRule({'rock-memory'}),
  'silvally-bug':      ItemGatingRule({'bug-memory'}),
  'silvally-ghost':    ItemGatingRule({'ghost-memory'}),
  'silvally-steel':    ItemGatingRule({'steel-memory'}),
  'silvally-fire':     ItemGatingRule({'fire-memory'}),
  'silvally-water':    ItemGatingRule({'water-memory'}),
  'silvally-grass':    ItemGatingRule({'grass-memory'}),
  'silvally-electric': ItemGatingRule({'electric-memory'}),
  'silvally-psychic':  ItemGatingRule({'psychic-memory'}),
  'silvally-ice':      ItemGatingRule({'ice-memory'}),
  'silvally-dragon':   ItemGatingRule({'dragon-memory'}),
  'silvally-dark':     ItemGatingRule({'dark-memory'}),
  'silvally-fairy':    ItemGatingRule({'fairy-memory'}),
};

// ── Public API ────────────────────────────────────────────────────────────

/// Returns the non-default form names that should be shown as chips.
///
/// [varieties] — all varieties from the species endpoint.
/// [cosmeticForms] — sprite-only form names (e.g. Burmy's cloaks).
/// [heldItem] — current held item (PokéAPI hyphenated name, or null).
/// [abilityName] — current ability (PokéAPI hyphenated name, or null).
List<String> filterFormChips({
  required List<String> varieties,
  List<String> cosmeticForms = const [],
  required String? heldItem,
  required String? abilityName,
}) {
  final candidates = [
    if (varieties.length > 1) ...varieties.skip(1),
    ...cosmeticForms,
  ];
  if (candidates.isEmpty) return [];

  final item    = heldItem?.toLowerCase() ?? '';
  final ability = abilityName?.toLowerCase() ?? '';

  return candidates.where((form) {
    // 1. Always exclude by suffix
    for (final suffix in kExcludeFormSuffixes) {
      if (form.endsWith(suffix)) return false;
    }
    if (kAlwaysExcludeForms.contains(form)) return false;

    // 2. Ability-gated
    final abilityRule = kAbilityGatingRules[form];
    if (abilityRule != null) return ability == abilityRule.requiredAbility;

    // 3. Item-gated (covers legendary, primal, Arceus plates, Silvally memories)
    final itemRule = kItemGatingRules[form];
    if (itemRule != null) return itemRule.requiredItems.contains(item);

    // 4. Free chip
    return true;
  }).toList();
}
```

- [ ] **Step 3: Run existing tests to confirm all still pass**

```
flutter test test/unit/form_filter_test.dart
```
Expected: All tests PASS. No test changes needed — public API is identical.

- [ ] **Step 4: Commit**

```bash
git add lib/features/teams/data/form_filter.dart
git commit -m "refactor: typed AbilityGatingRule/ItemGatingRule in form_filter.dart, merge Arceus/Silvally maps"
```

---

### Task 3: Extract PS form resolution heuristics to testable module (sub-issue D)

**Files:**
- Create: `lib/features/teams/logic/ps_form_resolver.dart`
- Create: `test/unit/ps_form_resolver_test.dart`
- Modify: `lib/features/teams/presentation/ps_import_sheet.dart`

The four heuristic functions are extracted from `_resolveFormName` (private, untestable) into a new `lib/features/teams/logic/ps_form_resolver.dart` that exports a testable public API. The `_resolveFormName` function in `ps_import_sheet.dart` is slimmed to an async wrapper that calls the new logic.

- [ ] **Step 1: Write failing tests for the resolver**

```dart
// test/unit/ps_form_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/logic/ps_form_resolver.dart';

void main() {
  group('resolveFormFromVarieties — exact match', () {
    test('returns exact variety name when present', () {
      expect(
        resolveFormFromVarieties('rotom-heat', ['rotom', 'rotom-heat', 'rotom-wash']),
        'rotom-heat',
      );
    });

    test('returns null when no match', () {
      expect(
        resolveFormFromVarieties('rotom-unknown', ['rotom', 'rotom-heat']),
        isNull,
      );
    });
  });

  group('resolveFormFromVarieties — forward prefix', () {
    test('ogerpon-wellspring matches ogerpon-wellspring-mask', () {
      expect(
        resolveFormFromVarieties(
          'ogerpon-wellspring',
          ['ogerpon', 'ogerpon-teal-mask', 'ogerpon-wellspring-mask'],
        ),
        'ogerpon-wellspring-mask',
      );
    });
  });

  group('resolveFormFromVarieties — reverse prefix', () {
    test('necrozma-dawn-wings matches necrozma-dawn', () {
      expect(
        resolveFormFromVarieties(
          'necrozma-dawn-wings',
          ['necrozma', 'necrozma-dawn', 'necrozma-dusk'],
        ),
        'necrozma-dawn',
      );
    });
  });

  group('resolveFormFromVarieties — last segment', () {
    test('maushold-four matches maushold-family-of-four', () {
      expect(
        resolveFormFromVarieties(
          'maushold-four',
          ['maushold', 'maushold-family-of-three', 'maushold-family-of-four'],
        ),
        'maushold-family-of-four',
      );
    });
  });

  group('resolveFormFromVarieties — pipeline priority', () {
    test('exact match takes priority over forward prefix', () {
      // If psName is an exact variety, return it directly.
      expect(
        resolveFormFromVarieties(
          'aegislash-blade',
          ['aegislash', 'aegislash-blade', 'aegislash-blade-extra'],
        ),
        'aegislash-blade',
      );
    });
  });

  group('applyPsFormExceptions', () {
    test('returns mapped name for known exceptions', () {
      expect(applyPsFormExceptions('ogerpon-wellspring'), 'ogerpon-wellspring-mask');
    });

    test('returns null for unknown names', () {
      expect(applyPsFormExceptions('pikachu-original'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/unit/ps_form_resolver_test.dart
```
Expected: FAIL — file not found.

- [ ] **Step 3: Create `ps_form_resolver.dart`**

```dart
// lib/features/teams/logic/ps_form_resolver.dart
import 'package:poke_team_dex/features/teams/data/form_data.dart';

/// Checks the static exceptions table first (O(1), no API call).
/// Returns the mapped PokeAPI name or null if the PS name is not a known exception.
String? applyPsFormExceptions(String psName) => kPsFormExceptions[psName];

/// Runs the heuristic pipeline against [varieties] (non-default entries only).
/// Returns the first match or null if none of the heuristics succeed.
String? resolveFormFromVarieties(String psName, List<String> varieties) {
  final nonDefault = varieties.skip(1).toList();
  return _exactMatch(psName, varieties) ??
      _forwardPrefixMatch(psName, nonDefault) ??
      _reversePrefixMatch(psName, nonDefault) ??
      _lastSegmentMatch(psName, nonDefault);
}

String? _exactMatch(String psName, List<String> varieties) =>
    varieties.contains(psName) ? psName : null;

String? _forwardPrefixMatch(String psName, List<String> nonDefault) {
  for (final n in nonDefault) {
    if (n.startsWith('$psName-')) return n;
  }
  return null;
}

String? _reversePrefixMatch(String psName, List<String> nonDefault) {
  for (final n in nonDefault) {
    if (psName.startsWith('$n-')) return n;
  }
  return null;
}

String? _lastSegmentMatch(String psName, List<String> nonDefault) {
  final lastSeg = psName.split('-').last;
  for (final n in nonDefault) {
    if (n.split('-').last == lastSeg) return n;
  }
  return null;
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
flutter test test/unit/ps_form_resolver_test.dart
```
Expected: All tests PASS.

- [ ] **Step 5: Update `_resolveFormName` in `ps_import_sheet.dart`**

Find the existing `_resolveFormName` function (around line 72) and replace it:

```dart
// BEFORE (in ps_import_sheet.dart):
Future<String?> _resolveFormName(
    dynamic repo, int basePokemonId, String psName) async {
  try {
    final species = await repo.fetchPokemonSpecies(basePokemonId);
    final names = species.varieties.map((v) => v.name).toList();
    // 1. Exact match
    if (names.contains(psName)) return psName;
    // 2. Forward prefix ...
    for (final n in names.skip(1)) {
      if (n.startsWith('$psName-')) return n;
    }
    // 3. Reverse prefix ...
    for (final n in names.skip(1)) {
      if (psName.startsWith('$n-')) return n;
    }
    // 4. Last-segment match ...
    final lastSeg = psName.split('-').last;
    for (final n in names.skip(1)) {
      if (n.split('-').last == lastSeg) return n;
    }
    return null;
  } catch (_) {
    return null;
  }
}

// AFTER:
Future<String?> _resolveFormName(
    dynamic repo, int basePokemonId, String psName) async {
  // Exceptions table — checked before the API call.
  final exception = applyPsFormExceptions(psName);
  if (exception != null) return exception;

  try {
    final species = await repo.fetchPokemonSpecies(basePokemonId);
    final varieties = species.varieties.map((v) => v.name).toList();
    return resolveFormFromVarieties(psName, varieties);
  } catch (_) {
    return null;
  }
}
```

Add the import at the top of `ps_import_sheet.dart`:

```dart
import 'package:poke_team_dex/features/teams/logic/ps_form_resolver.dart';
```

- [ ] **Step 6: Run all unit tests**

```
flutter test test/unit/
```
Expected: All tests PASS including the existing `ps_import_overrides_test.dart`.

- [ ] **Step 7: Commit**

```bash
git add lib/features/teams/logic/ps_form_resolver.dart \
        test/unit/ps_form_resolver_test.dart \
        lib/features/teams/presentation/ps_import_sheet.dart
git commit -m "refactor: extract PS form heuristics to testable ps_form_resolver.dart, add exceptions-first lookup"
```

---

### Task 4: Add `FormDescriptor` and `SpriteHint` models (sub-issue A, part 1)

**Files:**
- Create: `lib/features/teams/data/form_descriptor.dart`
- Create: `test/unit/form_descriptor_test.dart`

`FormDescriptor` is a pure value object — no I/O. `SpriteHint` carries the override data that the sprite resolver needs for cosmetic forms. Both are tested in isolation without a running Flutter app.

- [ ] **Step 1: Write failing tests**

```dart
// test/unit/form_descriptor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/data/form_descriptor.dart';

void main() {
  group('FormDescriptor.empty', () {
    test('isDefault is true', () {
      expect(FormDescriptor.empty().isDefault, isTrue);
    });

    test('effectiveApiName returns baseSpecies', () {
      expect(
        FormDescriptor.empty().effectiveApiName('charizard', null),
        'charizard',
      );
    });

    test('spriteHint has no overrides', () {
      final hint = FormDescriptor.empty().spriteHint('charizard', 6);
      expect(hint.stem, isNull);
      expect(hint.homeUrl, isNull);
    });
  });

  group('FormDescriptor — variety form (formName set)', () {
    const descriptor = FormDescriptor(formName: 'aegislash-blade');

    test('isDefault is false', () {
      expect(descriptor.isDefault, isFalse);
    });

    test('effectiveApiName returns formName', () {
      expect(descriptor.effectiveApiName('aegislash', null), 'aegislash-blade');
    });

    test('spriteHint has no stem override (variety has own /pokemon resource)', () {
      final hint = descriptor.spriteHint('aegislash', 681);
      expect(hint.stem, isNull);
    });
  });

  group('FormDescriptor — mega evolved', () {
    const descriptor = FormDescriptor(isMegaEvolved: true);

    test('effectiveApiName returns mega form name from kMegaStoneMap', () {
      expect(
        descriptor.effectiveApiName('charizard', 'charizardite-x'),
        'charizard-mega-x',
      );
    });

    test('effectiveApiName returns baseSpecies when heldItem is null', () {
      expect(descriptor.effectiveApiName('charizard', null), 'charizard');
    });

    test('effectiveApiName returns baseSpecies when item not in mega map', () {
      expect(descriptor.effectiveApiName('charizard', 'leftovers'), 'charizard');
    });
  });

  group('FormDescriptor — gigantamax enabled', () {
    const descriptor = FormDescriptor(gigantamaxEnabled: true);

    test('effectiveApiName returns baseSpecies (G-Max uses base stats)', () {
      expect(descriptor.effectiveApiName('charizard', null), 'charizard');
    });

    test('isDefault is false', () {
      expect(descriptor.isDefault, isFalse);
    });
  });

  group('FormDescriptor — cosmetic form', () {
    const descriptor = FormDescriptor(formName: 'burmy-sandy');

    test('spriteHint has stem override for known cosmetic form', () {
      final hint = descriptor.spriteHint('burmy', 412);
      expect(hint.stem, '412-sandy');
    });

    test('spriteHint homeUrl points to correct HOME sprite URL', () {
      final hint = descriptor.spriteHint('burmy', 412);
      expect(
        hint.homeUrl,
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/412-sandy.png',
      );
    });

    test('spriteHint homeShinyUrl points to correct shiny HOME sprite URL', () {
      final hint = descriptor.spriteHint('burmy', 412);
      expect(
        hint.homeShinyUrl,
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/412-sandy.png',
      );
    });
  });

  group('FormDescriptor.copyWith', () {
    test('can clear formName to null', () {
      const d = FormDescriptor(formName: 'aegislash-blade');
      expect(d.copyWith(clearFormName: true).formName, isNull);
    });

    test('preserves unchanged fields', () {
      const d = FormDescriptor(formName: 'aegislash-blade', isShiny: true);
      final updated = d.copyWith(isShiny: false);
      expect(updated.formName, 'aegislash-blade');
      expect(updated.isShiny, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/unit/form_descriptor_test.dart
```
Expected: FAIL — file not found.

- [ ] **Step 3: Create `form_descriptor.dart`**

```dart
// lib/features/teams/data/form_descriptor.dart
import 'package:poke_team_dex/features/teams/data/form_data.dart';
import 'package:poke_team_dex/features/teams/data/mega_forms_data.dart';

/// Overrides the sprite resolver needs for a form's sprite paths.
/// All fields are null for non-cosmetic forms — the resolver uses pokemonId as stem.
class SpriteHint {
  /// File stem override, used only for cosmetic forms sharing a base /pokemon resource.
  /// e.g. "412-sandy" for Burmy Sandy Cloak.
  final String? stem;

  /// Explicit HOME art URL. Set when the base species sprites JSON won't contain
  /// an entry for this form's HOME artwork (cosmetic forms only).
  final String? homeUrl;
  final String? homeShinyUrl;

  const SpriteHint({this.stem, this.homeUrl, this.homeShinyUrl});
}

/// Wraps all form-state columns from [TeamSlotsData] into a single value object.
/// No I/O — constructed from a DB row, passed to widgets and resolvers.
class FormDescriptor {
  final String? formName;
  final bool isShiny;
  final bool isMegaEvolved;
  final bool hasGigantamax;
  final bool gigantamaxEnabled;
  final bool isAlpha;
  final String? gender;

  const FormDescriptor({
    this.formName,
    this.isShiny = false,
    this.isMegaEvolved = false,
    this.hasGigantamax = false,
    this.gigantamaxEnabled = false,
    this.isAlpha = false,
    this.gender,
  });

  factory FormDescriptor.empty() => const FormDescriptor();

  /// Reads form-state columns from a generated Drift data class.
  /// Import the generated data class at the call site — FormDescriptor itself
  /// has no Drift dependency.
  static FormDescriptor from({
    required String? formName,
    required bool isShiny,
    required bool isMegaEvolved,
    required bool hasGigantamax,
    required bool gigantamaxEnabled,
    required bool isAlpha,
    required String? gender,
  }) => FormDescriptor(
    formName: formName,
    isShiny: isShiny,
    isMegaEvolved: isMegaEvolved,
    hasGigantamax: hasGigantamax,
    gigantamaxEnabled: gigantamaxEnabled,
    isAlpha: isAlpha,
    gender: gender,
  );

  static const _sentinel = Object();

  /// Returns a copy with optionally updated fields.
  /// Pass [clearFormName: true] to set formName to null (selecting default form).
  FormDescriptor copyWith({
    Object? formName = _sentinel,
    bool? isShiny,
    bool? isMegaEvolved,
    bool? hasGigantamax,
    bool? gigantamaxEnabled,
    bool? isAlpha,
    Object? gender = _sentinel,
    bool clearFormName = false,
    bool clearGender = false,
  }) => FormDescriptor(
    formName: clearFormName
        ? null
        : (formName == _sentinel ? this.formName : formName as String?),
    isShiny: isShiny ?? this.isShiny,
    isMegaEvolved: isMegaEvolved ?? this.isMegaEvolved,
    hasGigantamax: hasGigantamax ?? this.hasGigantamax,
    gigantamaxEnabled: gigantamaxEnabled ?? this.gigantamaxEnabled,
    isAlpha: isAlpha ?? this.isAlpha,
    gender: clearGender
        ? null
        : (gender == _sentinel ? this.gender : gender as String?),
  );

  /// True when no form variation is active.
  bool get isDefault =>
      formName == null && !isMegaEvolved && !gigantamaxEnabled;

  /// The PokeAPI /pokemon/{name} endpoint to fetch for this form's
  /// stats, abilities, types, and moves.
  ///
  /// Pass [heldItem] to resolve the mega form name when [isMegaEvolved] is true.
  String effectiveApiName(String baseSpecies, String? heldItem) {
    if (isMegaEvolved && heldItem != null) {
      final entry = kMegaStoneMap[heldItem];
      if (entry != null) return entry.megaForm;
    }
    if (formName != null) return formName!;
    return baseSpecies;
  }

  /// Override data for the sprite resolver.
  /// Returns non-null fields only for cosmetic forms — all other forms let
  /// the resolver use the fetched Pokemon's numeric ID as the sprite stem.
  SpriteHint spriteHint(String baseSpecies, int baseSpeciesId) {
    if (formName != null) {
      final cosmeticStems = kCosmeticSpriteStems[baseSpecies];
      if (cosmeticStems != null && cosmeticStems.containsKey(formName)) {
        final stem = cosmeticStems[formName]!;
        final suffix = stem.split('-').last;
        return SpriteHint(
          stem: stem,
          homeUrl: _cosmeticHomeUrl(baseSpeciesId, suffix),
          homeShinyUrl: _cosmeticHomeShinyUrl(baseSpeciesId, suffix),
        );
      }
    }
    return const SpriteHint();
  }
}

String _cosmeticHomeUrl(int id, String suffix) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/$id-$suffix.png';

String _cosmeticHomeShinyUrl(int id, String suffix) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/$id-$suffix.png';
```

- [ ] **Step 4: Run tests to verify they pass**

```
flutter test test/unit/form_descriptor_test.dart
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/teams/data/form_descriptor.dart test/unit/form_descriptor_test.dart
git commit -m "feat: add FormDescriptor and SpriteHint value objects"
```

---

### Task 5: Thread `FormDescriptor` through slot widgets (sub-issue A, part 2)

**Files:**
- Modify: `lib/features/teams/presentation/slot_config_screen.dart`
- Modify: `lib/features/teams/presentation/team_detail_screen.dart`
- Modify: `lib/features/teams/providers/team_detail_providers.dart`

These files each read individual form-state columns from the slot DB row. Replace those scattered reads with `FormDescriptor.from(slot: ...)` constructed once at the top of each relevant widget/provider scope.

**The pattern to find and replace (applies to all three files):**

Search for any of: `slot.formName`, `slot.isMegaEvolved`, `slot.gigantamaxEnabled`, `slot.isAlpha`, `slot.isShiny`, `slot.gender`, `slot.hasGigantamax`.

**Add the import:**
```dart
import 'package:poke_team_dex/features/teams/data/form_descriptor.dart';
```

**Construct the descriptor once at the top of the relevant scope:**
```dart
final descriptor = FormDescriptor.from(
  formName: slot.formName,
  isShiny: slot.isShiny,
  isMegaEvolved: slot.isMegaEvolved,
  hasGigantamax: slot.hasGigantamax,
  gigantamaxEnabled: slot.gigantamaxEnabled,
  isAlpha: slot.isAlpha,
  gender: slot.gender,
);
```

**Replace individual field reads with descriptor methods:**

| Before | After |
|---|---|
| `slot.formName` (for API fetch) | `descriptor.effectiveApiName(baseSpecies, slot.heldItemName)` |
| `slot.formName` (display/chip) | `descriptor.formName` |
| `slot.isMegaEvolved` | `descriptor.isMegaEvolved` |
| `slot.gigantamaxEnabled` | `descriptor.gigantamaxEnabled` |
| `slot.isAlpha` | `descriptor.isAlpha` |
| `slot.isShiny` | `descriptor.isShiny` |
| `slot.gender` | `descriptor.gender` |
| `slot.hasGigantamax` | `descriptor.hasGigantamax` |
| Cosmetic form sprite overrides (spriteFileStem, homeUrl) | `descriptor.spriteHint(baseSpecies, pokemonId)` |

**State changes (user selects a form chip, toggles mega, etc.):**

Where a state change currently writes directly to DB columns, keep writing to those same columns. The DB schema is unchanged. `FormDescriptor` is a read-side concern — it doesn't change how writes work:

```dart
// BEFORE (example — toggling mega):
setState(() => _isMegaEvolved = true);
await _slotRepo.update(slot.id, isMegaEvolved: true);

// AFTER — same write, same columns:
setState(() => _descriptor = _descriptor.copyWith(isMegaEvolved: true));
await _slotRepo.update(slot.id, isMegaEvolved: true);
```

**In `team_detail_providers.dart` — `linkableSlotsProvider`:**

```dart
// BEFORE:
final originFormName = slot.formName;

// AFTER:
final descriptor = FormDescriptor.from(
  formName: slot.formName,
  isShiny: slot.isShiny,
  isMegaEvolved: slot.isMegaEvolved,
  hasGigantamax: slot.hasGigantamax,
  gigantamaxEnabled: slot.gigantamaxEnabled,
  isAlpha: slot.isAlpha,
  gender: slot.gender,
);
final originFormName = descriptor.formName;
```

- [ ] **Step 1: Update `team_detail_providers.dart`** — smallest change; only `formName` is read

Add import, construct descriptor, replace `slot.formName` access with `descriptor.formName`.

- [ ] **Step 2: Run analyze**

```
flutter analyze lib/features/teams/providers/team_detail_providers.dart
```
Expected: No errors.

- [ ] **Step 3: Update `team_detail_screen.dart`** — replace scattered reads with descriptor

Find all occurrences of individual form-state field reads:
```
grep -n "slot\.formName\|slot\.isMegaEvolved\|slot\.gigantamaxEnabled\|slot\.isAlpha\|slot\.isShiny\|slot\.gender\|slot\.hasGigantamax\|spriteFileStem\|cosmeticFormHomeUrl" lib/features/teams/presentation/team_detail_screen.dart
```

Add import and construct `descriptor` at the top of the build scope where slot data is first available. Replace all `slot.isMegaEvolved`, `slot.formName`, `slot.gigantamaxEnabled`, `slot.isAlpha`, `slot.isShiny`, `slot.gender` reads with descriptor properties.

For the sprite call site in `team_detail_screen.dart`, replace the cosmetic form overrides:

```dart
// BEFORE (approximate — find the actual resolveSprite call):
resolveSprite(
  sprites: pokemon.sprites,
  pokemonId: pokemon.id,
  pokemonName: pokemon.name,
  format: format,
  useFormatSprites: useFormatSprites,
  spriteFileStem: isCosmeticForm ? cosmeticStem : null,
  homeUrl: isCosmeticForm ? cosmeticFormHomeUrl(baseId, suffix) : null,
  homeShinyUrl: isCosmeticForm ? cosmeticFormHomeShinyUrl(baseId, suffix) : null,
)

// AFTER:
final hint = descriptor.spriteHint(baseSpecies, baseSpeciesId);
resolveSprite(
  sprites: pokemon.sprites,
  pokemonId: pokemon.id,
  pokemonName: pokemon.name,
  format: format,
  useFormatSprites: useFormatSprites,
  spriteFileStem: hint.stem,
  homeUrl: hint.homeUrl,
  homeShinyUrl: hint.homeShinyUrl,
)
```

- [ ] **Step 4: Run analyze**

```
flutter analyze lib/features/teams/presentation/team_detail_screen.dart
```
Expected: No errors.

- [ ] **Step 5: Update `slot_config_screen.dart`** — largest file; apply the same pattern

Add import, construct `descriptor` once from slot state, replace individual field reads. For mega toggle, Gigantamax toggle, form chip selection — update `_descriptor` via `copyWith`, keep the DB write unchanged.

- [ ] **Step 6: Run full analyze**

```
flutter analyze lib/
```
Expected: No errors. Fix any type mismatches before proceeding.

- [ ] **Step 7: Run all tests**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/teams/presentation/slot_config_screen.dart \
        lib/features/teams/presentation/team_detail_screen.dart \
        lib/features/teams/providers/team_detail_providers.dart
git commit -m "refactor: thread FormDescriptor through slot widgets, replace scattered slot field reads"
```

---

### Task 6: Refactor sprite resolver to `SpriteHint` input and named URL helpers (sub-issue E)

**Files:**
- Modify: `lib/services/format/sprite_resolver.dart`
- Create: `test/unit/sprite_resolver_test.dart`

The three loose optional parameters (`spriteFileStem`, `homeUrl`, `homeShinyUrl`) are replaced by a single `SpriteHint`. The shiny and female URL logic are extracted to named helpers. The logic itself is unchanged — only the structure.

**Note:** Task 5 already uses `hint.stem`, `hint.homeUrl`, `hint.homeShinyUrl` when calling `resolveSprite`. In Task 5, the call sites pass these as the existing 3 separate parameters. In this task we collapse them to `SpriteHint`. Complete Task 5 before Task 6, then update the call sites in this task.

- [ ] **Step 1: Write failing tests for the named URL helpers**

```dart
// test/unit/sprite_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/services/format/sprite_resolver.dart';
import 'package:poke_team_dex/features/teams/data/form_descriptor.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

void main() {
  group('resolveSprite — no format (HOME / artwork path)', () {
    test('returns HOME url when sprites json has home entry', () {
      final sprites = {
        'other': {
          'home': {
            'front_default': 'https://example.com/home/6.png',
            'front_shiny': 'https://example.com/home/shiny/6.png',
          }
        }
      };
      final result = resolveSprite(
        sprites: sprites,
        pokemonId: 6,
        pokemonName: 'charizard',
        format: null,
        useFormatSprites: false,
        hint: const SpriteHint(),
      );
      expect(result.defaultUrl, 'https://example.com/home/6.png');
      expect(result.shinyUrl, 'https://example.com/home/shiny/6.png');
    });

    test('uses hint.homeUrl when provided (cosmetic form)', () {
      final result = resolveSprite(
        sprites: null,
        pokemonId: 412,
        pokemonName: 'burmy',
        format: null,
        useFormatSprites: false,
        hint: const SpriteHint(
          stem: '412-sandy',
          homeUrl: 'https://example.com/home/412-sandy.png',
          homeShinyUrl: 'https://example.com/home/shiny/412-sandy.png',
        ),
      );
      expect(result.defaultUrl, 'https://example.com/home/412-sandy.png');
      expect(result.shinyUrl, 'https://example.com/home/shiny/412-sandy.png');
    });
  });

  group('resolveSprite — Gen 1 (no shiny)', () {
    const gen1Format = GameFormat(
      id: 'yellow',
      name: 'Gen 1 Yellow',
      short: 'Yellow',
      type: FormatType.game,
      gen: 1,
    );

    test('shinyUrl equals defaultUrl in Gen 1 (no shiny mechanic)', () {
      final result = resolveSprite(
        sprites: null,
        pokemonId: 6,
        pokemonName: 'charizard',
        format: gen1Format,
        useFormatSprites: true,
        hint: const SpriteHint(),
      );
      expect(result.shinyUrl, equals(result.defaultUrl));
    });
  });

  group('resolveSprite — hint.stem overrides pokemonId in sprite path', () {
    const gen5Format = GameFormat(
      id: 'bw',
      name: 'Gen 5 BW',
      short: 'BW',
      type: FormatType.game,
      gen: 5,
    );

    test('versioned path uses hint.stem when provided', () {
      final result = resolveSprite(
        sprites: null,
        pokemonId: 412,
        pokemonName: 'burmy',
        format: gen5Format,
        useFormatSprites: true,
        hint: const SpriteHint(stem: '412-sandy'),
      );
      expect(result.defaultUrl, contains('412-sandy'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/unit/sprite_resolver_test.dart
```
Expected: FAIL — `resolveSprite` signature doesn't yet accept `hint` parameter.

- [ ] **Step 3: Refactor `sprite_resolver.dart`**

Replace the function signature and extract URL helpers. The logic is identical — only structure changes.

```dart
// lib/services/format/sprite_resolver.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:poke_team_dex/features/teams/data/form_descriptor.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

const _versionsBase = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
    'master/sprites/pokemon/versions';

const _gameIdToVersionPath = <String, String>{
  'rb':       'generation-i/red-blue',
  'yellow':   'generation-i/yellow',
  'gs':       'generation-ii/gold',
  'crystal':  'generation-ii/crystal',
  'rs':       'generation-iii/ruby-sapphire',
  'emerald':  'generation-iii/emerald',
  'frlg':     'generation-iii/firered-leafgreen',
  'dp':       'generation-iv/diamond-pearl',
  'platinum': 'generation-iv/platinum',
  'hgss':     'generation-iv/heartgold-soulsilver',
  'bw':       'generation-v/black-white',
  'b2w2':     'generation-v/black-white',
};

const _genToDefaultGameId = <int, String>{
  1: 'yellow',
  2: 'crystal',
  3: 'emerald',
  4: 'hgss',
  5: 'bw',
};

bool _needsTransparentSubfolder(int gen) => gen <= 2;

/// Resolves sprite URLs for a Pokémon given the team's format and sprite preference.
///
/// Pass a [SpriteHint] from [FormDescriptor.spriteHint] to supply cosmetic-form
/// overrides (stem, homeUrl, homeShinyUrl). For all other forms, pass [SpriteHint()].
({String? defaultUrl, String? shinyUrl, String? femaleUrl, String? femaleShinyUrl})
    resolveSprite({
  required Map<String, dynamic>? sprites,
  required int pokemonId,
  required String pokemonName,
  required GameFormat? format,
  required bool useFormatSprites,
  required SpriteHint hint,
}) {
  final stem = hint.stem ?? '$pokemonId';
  final rawDefault = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
      'master/sprites/pokemon/$stem.png';
  final rawShiny = 'https://raw.githubusercontent.com/PokeAPI/sprites/'
      'master/sprites/pokemon/shiny/$stem.png';

  if (!useFormatSprites || format == null) {
    return _homeOrArtwork(sprites, rawDefault, rawShiny, hint: hint);
  }

  final gameId = format.type == FormatType.game
      ? format.id
      : _genToDefaultGameId[format.gen];

  if (gameId != null) {
    final versionPath = _gameIdToVersionPath[gameId];
    if (versionPath != null) {
      final gen        = format.gen;
      final isAnimated = gameId == 'bw' || gameId == 'b2w2';
      final ext        = isAnimated ? '.gif' : '.png';
      final transparent = _needsTransparentSubfolder(gen) ? 'transparent/' : '';
      final animSeg    = isAnimated ? 'animated/' : '';

      final defaultUrl = _versionedDefaultUrl(versionPath, animSeg, transparent, stem, ext);
      final shinyUrl   = _versionedShinyUrl(versionPath, gen, animSeg, transparent, stem, ext, pokemonName);
      final (femaleUrl, femaleShinyUrl) = _versionedFemaleUrls(versionPath, gen, animSeg, stem, ext);

      return (defaultUrl: defaultUrl, shinyUrl: shinyUrl, femaleUrl: femaleUrl, femaleShinyUrl: femaleShinyUrl);
    }
  }

  return _homeOrArtwork(sprites, rawDefault, rawShiny, hint: hint);
}

// ── Named URL helpers ─────────────────────────────────────────────────────

String _versionedDefaultUrl(
  String versionPath, String animSeg, String transparent, String stem, String ext,
) => '$_versionsBase/$versionPath/$animSeg$transparent$stem$ext';

String _versionedShinyUrl(
  String versionPath, int gen, String animSeg, String transparent,
  String stem, String ext, String pokemonName,
) {
  if (gen == 1) return _versionedDefaultUrl(versionPath, animSeg, transparent, stem, ext);
  if (animSeg.isNotEmpty) return '$_versionsBase/$versionPath/${animSeg}shiny/$stem$ext';
  if (transparent.isNotEmpty) {
    // PokeAPI has no transparent/shiny subfolder for Gen 2.
    // On non-web: use Pokémon Showdown which has transparent Gen 2 shiny sprites.
    // On web: fall back to PokeAPI non-transparent shiny (Showdown is CORS-blocked in browsers).
    return kIsWeb
        ? '$_versionsBase/$versionPath/shiny/$stem$ext'
        : 'https://play.pokemonshowdown.com/sprites/gen2-shiny/$pokemonName.png';
  }
  return '$_versionsBase/$versionPath/shiny/$stem$ext';
}

(String? femaleUrl, String? femaleShinyUrl) _versionedFemaleUrls(
  String versionPath, int gen, String animSeg, String stem, String ext,
) {
  if (gen < 4) return (null, null);
  final femaleUrl = '$_versionsBase/$versionPath/${animSeg}female/$stem$ext';
  final femaleShinyUrl = gen == 1
      ? femaleUrl
      : '$_versionsBase/$versionPath/${animSeg}shiny/female/$stem$ext';
  return (femaleUrl, femaleShinyUrl);
}

({String? defaultUrl, String? shinyUrl, String? femaleUrl, String? femaleShinyUrl})
    _homeOrArtwork(
  Map<String, dynamic>? sprites,
  String rawDefault,
  String rawShiny, {
  required SpriteHint hint,
}) {
  final home    = sprites == null ? null : _nav(sprites['other'], ['home']);
  final artwork = sprites == null ? null : _nav(sprites['other'], ['official-artwork']);
  return (
    defaultUrl: hint.homeUrl ??
        home?['front_default'] as String? ??
        artwork?['front_default'] as String? ??
        rawDefault,
    shinyUrl: hint.homeShinyUrl ??
        home?['front_shiny'] as String? ??
        artwork?['front_shiny'] as String? ??
        rawShiny,
    femaleUrl: home?['front_female'] as String?,
    femaleShinyUrl: home?['front_shiny_female'] as String?,
  );
}

Map<String, dynamic>? _nav(dynamic root, List<String> path) {
  dynamic cur = root;
  for (final key in path) {
    if (cur is! Map) return null;
    cur = cur[key];
  }
  return cur is Map ? cur.cast<String, dynamic>() : null;
}
```

- [ ] **Step 4: Update all `resolveSprite` call sites to use `hint:`**

Search for `resolveSprite(` across the codebase:

```
grep -rn "resolveSprite(" lib/
```

For each call site, replace the three loose parameters with a `hint:` argument. In Task 5 the call sites were updated to pass `hint.stem`, `hint.homeUrl`, `hint.homeShinyUrl` as separate params — now consolidate them:

```dart
// BEFORE (from Task 5 interim state):
resolveSprite(
  ...,
  spriteFileStem: hint.stem,
  homeUrl: hint.homeUrl,
  homeShinyUrl: hint.homeShinyUrl,
)

// AFTER:
resolveSprite(
  ...,
  hint: hint,
)
```

Any call site that still uses the old three-parameter form must be updated. The Dart analyzer will flag remaining usages as compile errors.

- [ ] **Step 5: Run analyze**

```
flutter analyze lib/
```
Expected: No errors. The old `spriteFileStem`, `homeUrl`, `homeShinyUrl` parameters no longer exist — any call site that still uses them will be flagged.

- [ ] **Step 6: Run all tests**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/services/format/sprite_resolver.dart test/unit/sprite_resolver_test.dart
git commit -m "refactor: sprite resolver accepts SpriteHint, extract named URL helpers"
```

---

## Summary of new / modified files

| File | Action |
|---|---|
| `lib/features/teams/data/form_data.dart` | Create — PS exceptions + cosmetic sprite stems |
| `lib/features/teams/data/form_filter.dart` | Modify — typed gating rule classes, merged maps |
| `lib/features/teams/logic/ps_form_resolver.dart` | Create — testable resolution heuristics |
| `lib/features/teams/data/form_descriptor.dart` | Create — FormDescriptor + SpriteHint |
| `lib/features/teams/presentation/ps_import_sheet.dart` | Modify — exceptions-first + delegate to resolver |
| `lib/features/teams/presentation/slot_config_screen.dart` | Modify — use FormDescriptor |
| `lib/features/teams/presentation/team_detail_screen.dart` | Modify — use FormDescriptor, SpriteHint |
| `lib/features/teams/providers/team_detail_providers.dart` | Modify — use FormDescriptor |
| `lib/services/format/sprite_resolver.dart` | Modify — SpriteHint param, named URL helpers |
| `test/unit/form_data_test.dart` | Create |
| `test/unit/ps_form_resolver_test.dart` | Create |
| `test/unit/form_descriptor_test.dart` | Create |
| `test/unit/sprite_resolver_test.dart` | Create |
