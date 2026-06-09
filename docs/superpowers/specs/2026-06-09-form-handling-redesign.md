# Form Handling Redesign — Design Spec

**Issue:** #164  
**Date:** 2026-06-09  
**Status:** Approved for implementation planning

---

## Problem

Form handling is spread across multiple disconnected files with hardcoded static data that grows with each new Pokémon generation. Pain points affect all three areas equally:

- **PS import:** 5 inlined heuristics with no exceptions table; known PS↔PokeAPI name mismatches (e.g. `ogerpon-wellspring` → `ogerpon-wellspring-mask`) have no dedicated escape hatch
- **Form gating:** `kArceusPlateForms` and `kSilvallyMemoryForms` are separate maps doing the same thing as `kItemGatedForms`; new item-gated forms require adding a new `if` branch
- **Sprite resolver:** cosmetic form overrides require 3 loose optional parameters computed by callers; shiny URL decision logic is inlined with no named structure
- **Scattered form state reads:** every widget independently reads `slot.isMegaEvolved`, `slot.formName`, `slot.gigantamaxEnabled`, etc. to decide which PokeAPI name to fetch and which sprite to show

Adding support for a new form currently requires editing 3+ files. The goal is to reduce that to 2 files maximum for data changes, and 0 files for logic changes when a new form fits an existing pattern.

---

## Out of scope (separate issues)

- Reducing total number of API / DB / PS calls (flagged for its own sub-issue)
- PS export of form information (separate sub-issue)
- DB schema changes (no migration required by this redesign)

---

## Architecture

### What changes

| Concern | Current | After |
|---|---|---|
| DB columns | 5 booleans + `formName` text | Unchanged |
| Dart form model | None — raw DB fields scattered in widgets | New `FormDescriptor` value object |
| Static form data | Embedded across `mega_forms_data.dart`, `form_filter.dart`, `ps_import_sheet.dart` | PS exceptions + cosmetic sprite stems extracted to `form_data.dart` |
| Form gating | Raw maps including separate Arceus/Silvally maps | Typed `AbilityGatingRule` / `ItemGatingRule` objects; Arceus + Silvally merged into `kItemGatingRules` |
| PS → PokeAPI resolution | 5 inlined heuristics, no exceptions table | Exceptions map checked first, then named heuristic pipeline |
| Sprite resolver | 3 loose optional override parameters; inline shiny branch | `SpriteHint` input from `FormDescriptor`; shiny/female URL logic extracted to named helpers |

### What stays the same

- `mega_forms_data.dart` — well-structured, unchanged
- `dynamax_data.dart` — contains `resolveMaxMove()` logic, unchanged
- DB columns and schema version — no migration
- `pokemonByNameProvider` and all PokeAPI fetch logic — unchanged
- Number of API / DB calls — unchanged in this redesign

---

## New files

### `lib/features/teams/data/form_descriptor.dart`

Pure Dart value object. No I/O. Created once per slot; passed to widgets instead of raw DB row fields.

```
FormDescriptor
├── formName: String?
├── isShiny: bool
├── isMegaEvolved: bool
├── gigantamaxEnabled: bool
├── isAlpha: bool
├── gender: String?
│
├── FormDescriptor.from(TeamSlotsData slot)    — read from DB row
├── FormDescriptor.empty()                     — fresh slot, all defaults
├── FormDescriptor.copyWith(...)               — mutation for UI changes
├── Map<String, dynamic> toColumns()           — write back to DB (same columns)
│
├── String effectiveApiName(String baseSpecies, String? heldItem)
│     isMegaEvolved  → looks up mega_forms_data by heldItem → mega form name
│     formName != null (variety/regional) → formName
│     gigantamaxEnabled → baseSpecies (G-Max uses base stats; move resolved separately)
│     isAlpha → baseSpecies (same stats, sprite-only difference)
│     default → baseSpecies
│
└── SpriteHint spriteHint(String baseSpecies, int baseSpeciesId)
      isMegaEvolved → SpriteHint(stem: megaFormName)
      gigantamaxEnabled → SpriteHint(stem: '$baseSpecies-gmax')
      cosmetic form → SpriteHint(stem: '$baseSpeciesId-$suffix', homeUrl: ..., homeShinyUrl: ...)
      variety form → SpriteHint(stem: formName)
      default → SpriteHint.defaultForm()
```

Stats, abilities, types, and moves are unaffected — `effectiveApiName` returns the string that the existing `pokemonByNameProvider` already uses to fetch them. No new API calls.

### `lib/features/teams/data/form_data.dart`

Pure static constants. No logic. Two categories only:

```dart
/// PS name → PokeAPI name for known mismatches checked before heuristics.
const Map<String, String> kPsFormExceptions = {
  'ogerpon-wellspring':    'ogerpon-wellspring-mask',
  'ogerpon-hearthflame':   'ogerpon-hearthflame-mask',
  'ogerpon-cornerstone':   'ogerpon-cornerstone-mask',
  // ...
};

/// Cosmetic forms needing a sprite stem override.
/// baseSpecies → Map<formName, spriteFileStem>
const Map<String, Map<String, String>> kCosmeticSpriteStems = {
  'burmy':    {'burmy-sandy': '412-sandy', 'burmy-trash': '412-trash'},
  'wormadam': {'wormadam-sandy': '413-sandy', 'wormadam-trash': '413-trash'},
  // ...
};
```

New gen = edit this file for data, `form_filter.dart` for gating rules if needed. Two files maximum. Never three.

---

## Modified files

### `lib/features/teams/data/form_filter.dart`

Two typed rule classes replace the raw maps. `kArceusPlateForms` and `kSilvallyMemoryForms` are merged into `kItemGatingRules`.

```dart
class AbilityGatingRule {
  final String requiredAbility;
  const AbilityGatingRule(this.requiredAbility);
}

class ItemGatingRule {
  final Set<String> requiredItems;
  const ItemGatingRule(this.requiredItems);
}

// Before: 4 separate maps (kAbilityGatedForms, kItemGatedForms,
//          kArceusPlateForms, kSilvallyMemoryForms)
// After: 2 typed maps
const Map<String, AbilityGatingRule> kAbilityGatingRules = { ... };
const Map<String, ItemGatingRule>    kItemGatingRules    = { ... };
```

`filterFormChips()` logic shrinks from 5 branches to 4 (exclude suffix, exclude exact, ability-gated, item-gated). Adding a new item-gated form in a future gen = one line in `kItemGatingRules`. No new `if` branch.

### `lib/features/teams/presentation/ps_import_sheet.dart`

`_resolveFormName` gains an exceptions check before the heuristic loop. Each heuristic becomes a named top-level function.

```
_resolveFormName(repo, basePokemonId, psName)
  ├── 1. kPsFormExceptions lookup (O(1), no API call) → return early if found
  ├── 2. fetch species varieties (1 API call — same as today)
  └── 3. pipeline: [_exactMatch, _forwardPrefixMatch, _reversePrefixMatch, _lastSegmentMatch]
             first non-null result returned; null if none match

// Adding a new strategy: add one function + append to the pipeline list.
```

### `lib/services/format/sprite_resolver.dart`

`resolveSprite` signature loses the 3 loose optional parameters and gains a `SpriteHint`. Shiny and female URL building are extracted to named helpers.

```
// Before
resolveSprite(..., String? spriteFileStem, String? homeUrl, String? homeShinyUrl)

// After
resolveSprite(..., SpriteHint hint)
  hint provided by FormDescriptor.spriteHint() at call site

// Extracted helpers (same logic, now named and scannable)
_versionedDefaultUrl(versionPath, gen, animSeg, stem, ext)
_versionedShinyUrl(versionPath, gen, animSeg, stem, ext, pokemonName)
_versionedFemaleUrls(versionPath, gen, animSeg, stem, ext)
```

---

## Sub-issues to create (children of #164)

Each is an independent, reviewable unit that can ship without the others:

| # | Title | Scope |
|---|---|---|
| A | Add `FormDescriptor` model and thread through slot widgets | New file; modify `slot_config_screen.dart`, `team_detail_screen.dart`, `team_detail_providers.dart` |
| B | Add `form_data.dart` and populate PS exceptions + cosmetic sprite stems | New file only; no logic changes |
| C | Refactor `form_filter.dart` to typed gating rule classes | Modify existing file; merge Arceus/Silvally maps |
| D | Refactor PS import to exceptions-first + heuristic pipeline | Modify `ps_import_sheet.dart` |
| E | Refactor sprite resolver to `SpriteHint` input + named URL helpers | Modify `sprite_resolver.dart`; depends on A (for `SpriteHint` type) and B (for cosmetic stem data) |
| F | Investigate reducing API / DB / PS call count | Investigation + follow-up issues |

Recommended order: B → C → D → A → E → F. B, C, D have no dependencies and can be done in parallel. A depends on B (cosmetic stem data used in `spriteHint`). E depends on A and B.

---

## Constraints

- No DB migration — all existing columns preserved as-is
- `mega_forms_data.dart` and `dynamax_data.dart` untouched
- All existing provider/fetch logic untouched
- No change to API call count in this redesign (tracked separately as sub-issue F)
