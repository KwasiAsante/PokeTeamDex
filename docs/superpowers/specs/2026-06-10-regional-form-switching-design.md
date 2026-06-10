# Regional Form Switching — Pokédex Detail Screen

**Date:** 2026-06-10

## Goal

Allow users to switch between a Pokémon's battle-meaningful forms (regional variants, significant gender/form differences) directly from the detail screen. Switching a form updates every tab — Overview, Stats, Abilities, Moves, Evolutions, Forms, Locations, and Teams — to show data for that form.

---

## Scope

### In scope
- Regional forms: `-alola`, `-galar`, `-hisui`, `-paldea`
- Significant gender/battle forms: Meowstic, Indeedee, Basculegion, Urshifu, Lycanroc, Oricorio, Toxtricity, Rotom appliances, Zacian/Zamazenta crowned, and other forms with meaningfully different stats/moves/abilities
- Correct evolution chain display for forms with unique evolution paths (Obstagoon, Mr. Rime) — even without a form switcher

### Out of scope
- Mega evolutions and Gigantamax forms (remain in Forms tab as read-only)
- Cosmetic-only forms (Flabébé colours, Vivillon patterns, Pikachu cap variants)
- URL-based form deep-linking (form selection is local widget state, resets on navigation)

---

## Architecture

### State model

`_selectedFormName: String?` is added to `_PokemonDetailScreenState` (already a `ConsumerStatefulWidget`). Null = base form. Set to a PokéAPI Pokémon name string (e.g. `"raichu-alola"`, `"mr-mime-galar"`) when a form is selected.

`effectivePokemon` is derived synchronously from the watched `pokemonByNameProvider(_selectedFormName)` when non-null, falling back to `basePokemon` from `pokemonDetailProvider(widget.pokemonId)` while loading or when no form is selected. Species data (`speciesAsync`) is always from the base species and never changes — all forms share the same species (e.g. Raichu-Alola belongs to species 26).

### Form detection

A new pure helper `battleMeaningfulForms(List<PokemonVariety> varieties) → List<PokemonVariety>` is extracted to `lib/features/pokedex/logic/form_filter.dart`. It returns varieties that are:
- Non-default, AND
- Not excluded by the existing `filterFormChips` exclusion set (megas, gmax, totem, primal, etc.), AND
- Either: name ends in a known regional suffix (`-alola`, `-galar`, `-hisui`, `-paldea`), or name matches a known battle-form list (meowstic-male/female, indeedee-male/female, basculegion-male/female, urshifu-rapid-strike, lycanroc-midday/midnight/dusk, oricorio-pom-pom/pau/sensu, toxtricity-low-key, rotom-heat/wash/frost/fan/mow, zacian-crowned, zamazenta-crowned).

The form switcher is only shown when `battleMeaningfulForms(species.varieties).isNotEmpty`.

---

## UI

### App bar badge (form switcher trigger)

A compact chip button sits in the app bar trailing area alongside the star/shiny icons. It displays the current form name (e.g. "Galarian") or "Base Form". Only rendered when `battleMeaningfulForms` returns at least one variety. Tapping opens a modal bottom sheet.

### Bottom sheet picker

Shows one card per form (base + each battle-meaningful form), each displaying the form's sprite, name, and primary type badge. The active form is highlighted. Tapping any card calls `setState(() => _selectedFormName = variety.name)` (or null for base) and closes the sheet.

### Header update on form switch

When `_selectedFormName` is non-null and `pokemonByNameProvider` has loaded:
- Sprite: official artwork for `effectivePokemon.id`
- Type badges: `effectivePokemon.types`
- Background gradient: derived from `effectivePokemon.types[0]` (same existing logic)
- Pokémon name: still shows base species name ("Raichu") — form is indicated by the app bar badge

While the form provider is loading, the header shows a loading shimmer/spinner without clearing existing content.

---

## Tab behaviour

| Tab | When form selected |
|---|---|
| **Overview** | Uses `effectivePokemon` types, genus, base stat totals |
| **Stats** | Uses `effectivePokemon.stats` |
| **Abilities** | Uses `effectivePokemon.abilities` |
| **Moves** | Uses `effectivePokemon.moves` (form-specific learnset) |
| **Evolutions** | See Evolutions section below |
| **Forms** | Shows only non-battle-meaningful forms (cosmetics, Megas, Gmax). If none remain, shows existing empty state. Battle-meaningful forms are excluded — they live in the app bar switcher. |
| **Locations** | Uses `pokemonEncountersProvider(effectivePokemon.id)` |
| **Teams** | Filters slots where `pokemonId == widget.pokemonId AND formName == _selectedFormName` (or `formName == null` when base is selected) |

---

## Evolutions tab

The `_EvolutionsTab` receives `String? selectedFormName` from the parent. It resolves the correct form suffix via a two-step process:

1. **Form switcher active**: derive `formSuffix` from `selectedFormName` (e.g. `"raichu-alola"` → `"alola"`).
2. **No form switcher** (Pokémon has no battle-meaningful varieties of its own — e.g. Obstagoon, Mr. Rime): auto-detect via `formSuffixForSpecies(root, species.id)` from `evolution_chain_builder.dart`. This walks the chain and returns the suffix if the current species is only reachable via form-specific edges.
3. **Neither applies**: use null (default chain).

`buildFormChain(root, formSuffix, rootDisplayId, formIds: formIds)` renders **one chain** for the resolved suffix. No multi-section layout. Examples:
- Raichu page, Alolan selected → single chain: Pichu → Pikachu → Raichu-Alola
- Raichu page, base selected → single chain: Pichu → Pikachu → Raichu (Kantonian)
- Obstagoon page (no switcher) → auto-detects "galar" → Galarian Zigzagoon → Galarian Linoone → Obstagoon
- Mr. Rime page (no switcher) → auto-detects "galar" → Mime Jr → Galarian Mr. Mime → Mr. Rime
- Zigzagoon page, Galarian selected → Galarian Zigzagoon → Galarian Linoone → Obstagoon
- Zigzagoon page, base selected → Zigzagoon → Linoone (stops; Obstagoon is Galarian-only)

The `evolution_chain_builder.dart` code is reused as-is. The `region` field parsing (for Pikachu → Alolan Raichu) is included in the chain builder and works within the single-chain model.

---

## Files changed

| File | Action | Purpose |
|---|---|---|
| `lib/features/pokedex/logic/form_filter.dart` | **Create** | `battleMeaningfulForms()` pure helper + unit tests |
| `lib/services/pokeapi/models/evolution_chain.dart` | Modify | `region` field on `EvolutionDetail` (already done in closed PR — re-apply) |
| `lib/features/pokedex/logic/evolution_chain_builder.dart` | Modify | Re-apply changes from closed PR; receives `selectedFormName` context |
| `lib/features/pokedex/presentation/pokemon_detail_screen.dart` | Modify | Add `_selectedFormName` state, form badge in app bar, bottom sheet, `effectivePokemon`, pass form context to all tabs |
| `test/unit/form_filter_test.dart` | **Create** | Unit tests for `battleMeaningfulForms` |

---

## Regional naming conventions

- Gen 1 (Kanto) → Kantonian
- Gen 2 (Johto) → Johtonian
- Gen 3 (Hoenn) → Hoennian
- Gen 4 (Sinnoh) → Sinnohian
- Gen 5 (Unova) → Unovan
- Gen 6 (Kalos) → Kalosian
- Gen 7 (Alola) → Alolan
- Gen 8 (Galar) → Galarian
- Gen 9 (Paldea) → Paldean

Display names in the form picker are derived from the variety name suffix or the existing `formLabel()` function in `evolution_chain_builder.dart`.
