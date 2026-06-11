# Cosmetic Form Chips in Pokédex Header

**Date:** 2026-06-10

## Goal

Show form-selection chips in the Pokédex detail screen header for Pokémon with cosmetic variants (Burmy, Shellos, Unown, Vivillon, Flabébé, etc.). Tapping a chip changes the header artwork/sprite to that form. No tab data changes — cosmetic forms share identical stats, moves, abilities, and evolutions.

---

## Scope

### In scope
- Cosmetic form chips in the header for species where `cosmeticFormsProvider` returns a non-empty list
- Header sprite and artwork update to reflect selected form (HOME artwork → pixel sprite fallback)
- Shiny toggle applies to selected cosmetic form
- ≤ 6 forms: inline horizontal chip strip; > 6 forms: single "Show forms (N)" chip opening a picker sheet

### Out of scope
- Changes to any tab data (stats, moves, abilities, evolutions, locations, teams are identical for cosmetic forms)
- Cosmetic forms that are already handled as battle-meaningful forms in the form switcher badge

---

## Architecture

### State

`String? _selectedCosmeticFormName` is added to `_PokemonDetailScreenState` alongside `_selectedFormName`. Null = base form. Resets to null whenever `_selectedFormName` changes (switching battle forms resets cosmetic selection since cosmetic forms belong to the base species).

`cosmeticFormsProvider(basePokemon.name)` is watched in `build()`. The provider already returns `[]` for the vast majority of Pokémon (no sprites/forms requests are made for them), so there is no meaningful performance cost for non-cosmetic species.

The cosmetic forms list and `_selectedCosmeticFormName` are passed to both layout methods (`_buildNarrowLayout`, `_buildWideLayout`) and from there to `_DetailSliverAppBar`.

### Image resolution

When `_selectedCosmeticFormName` is non-null:
- `defaultUrl` → `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/{form.id}.png`
- `shinyUrl` → `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/{form.id}.png`
- Both fall back to `form.spriteUrl` / `form.spriteShinyUrl` via `PokemonSprite`'s existing error handler

When `_selectedCosmeticFormName` is null, the header continues to use `effectivePokemon.officialArtworkUrl` / `officialArtworkShinyUrl` as before.

---

## UI

### Chip placement

**Narrow layout (SliverAppBar / FlexibleSpaceBar):**
- The sprite and chips render in a `Column` inside the `FlexibleSpaceBar` background.
- `expandedHeight` grows from 280 → 324 dp when cosmetic forms exist (44 dp added for chip row + padding).
- The chip row sits below the sprite, vertically centred in the remaining space.

**Wide layout (left rail):**
- Chips render below the type badge row, above the navigation items in the left rail column.

### Chip rendering — ≤ 6 forms

A horizontal `SingleChildScrollView` containing a `Row` of `_CosmeticFormChip` widgets. Each chip shows:
- Form sprite at 28 × 28 px (`form.spriteUrl`, shiny-aware via `_shiny`)
- Short label derived from `form.formName`: title-cased, hyphens replaced with spaces (`"red-flower"` → `"Red Flower"`, `"sandy"` → `"Sandy"`, `"a"` → `"A"`)
- Selected state highlighted (filled container)

Tapping calls `setState(() => _selectedCosmeticFormName = form.name)`. Tapping the already-selected chip deselects it (resets to null).

### Chip rendering — > 6 forms

A single outlined chip labelled `"${forms.length} forms ▾"`. Tapping opens `_CosmeticFormPickerSheet` as a `showModalBottomSheet`.

### `_CosmeticFormPickerSheet`

A `StatelessWidget` showing a `Wrap` grid of form tiles, each with:
- Sprite image (~52 × 52 px, `form.spriteUrl`)
- Label below

Tapping a tile calls `onSelect(form.name)` and `Navigator.pop`. Same structural pattern as `_FormPickerSheet`.

### Form label helper

```dart
String cosmeticFormLabel(String formName) {
  if (formName.isEmpty) return 'Default';
  return formName.split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
```

---

## Files changed

| File | Change |
|---|---|
| `lib/features/pokedex/presentation/pokemon_detail_screen.dart` | Add `_selectedCosmeticFormName` state; watch `cosmeticFormsProvider`; pass to layouts and `_DetailSliverAppBar`; add `_CosmeticFormChip` and `_CosmeticFormPickerSheet` widgets; update `_DetailSliverAppBar` for dynamic `expandedHeight` and chip row |
