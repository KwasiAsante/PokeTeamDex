# Pokédex List Screen — Form Switching (Issue #192)

## Overview

Add a form chip to each Pokédex list card that has switchable forms. Tapping the chip opens a bottom sheet picker; selecting a form updates the card's sprite, artwork, gradient colour, and display name in place. Tapping the Pokémon's name navigates to the detail screen with the selected form pre-selected.

---

## Architecture

### Files created

| File | Purpose |
|---|---|
| `lib/features/pokedex/presentation/widget/form_picker_sheet.dart` | Public `FormPickerSheet` and `FormOptionTile` widgets, extracted from the private classes in `pokemon_detail_screen.dart` |

### Files modified

| File | Change |
|---|---|
| `lib/features/pokedex/logic/evolution_chain_builder.dart` | Add public `computeBaseFormLabel(pokemonName, generationName, battleForms)` — extracts the inline label logic from the detail screen so both the detail screen and list cards can call it |
| `lib/features/pokedex/logic/form_filter.dart` | Move `kCosmeticVarietyNames` and `cosmeticFormLabel` here from `pokemon_detail_screen.dart` so list card widgets can import them without a dependency on the detail screen |
| `lib/features/pokedex/presentation/pokemon_detail_screen.dart` | Remove private `_FormPickerSheet` / `_FormOptionTile`; import shared widget; use `computeBaseFormLabel`; pass pre-computed `allForms` list to picker |
| `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart` | `ConsumerWidget` → `ConsumerStatefulWidget`; add `String? _selectedFormName` state; add form chip and species provider watch |
| `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart` | Same conversion as list tile |

---

## Data Flow

Each card already watches `pokemonDetailProvider(pokemon.id)` for type/colour. The only new provider call is `pokemonSpeciesProvider(pokemon.id)`, which provides `varieties`.

**Form list — computed once species resolves:**
```
battleForms   = battleMeaningfulForms(species.varieties)
cosmeticForms = species.varieties.where(v => kCosmeticVarietyNames.contains(v.name))
allForms      = [(null, baseFormLabel), ...battleForms, ...cosmeticForms]  // (name?, label) pairs
```

`kCosmeticVarietyNames` is currently defined in `pokemon_detail_screen.dart`. Move it (and `cosmeticFormLabel`) to `lib/features/pokedex/logic/form_filter.dart` so list card widgets can import it without depending on the detail screen. No `cosmeticFormsProvider` call — no extra pokemon-form API requests.

**Chip visibility:** shown only when `allForms.length > 1`.

**When a form is selected**, the card watches `pokemonByNameProvider(selectedFormName)`:

| Property | Source |
|---|---|
| Gradient colour | `formEntry.types` |
| Compact list image | `formEntry.sprites['front_default']` |
| Medium+ list / grid image | `formEntry.officialArtworkUrl` |
| Display name | `"${basePokemon.displaySpeciesName} - ${label}"` where `label` is the pre-computed label from `allForms` |

**Name tap navigation:**
- Base form selected: `context.push('/pokedex/${pokemon.id}')` — unchanged
- Non-base form selected: `context.push('/pokedex/${pokemon.id}?form=$_selectedFormName')` — router already handles the `form` query param via `initialFormName`

---

## Form Picker Sheet Interface

The extracted `FormPickerSheet` accepts pre-computed label pairs rather than raw `PokemonVariety` lists, making it form-type-agnostic:

```dart
class FormPickerSheet extends StatelessWidget {
  final List<(String? name, String label)> allForms; // null name = base form
  final String? baseSpriteUrl;
  final String? baseShinyUrl;
  final String? selectedFormName;
  final bool shiny;
  final void Function(String?) onSelect;
}
```

The detail screen adapts its call site to pre-compute `allForms` before passing to the sheet.

---

## Chip Rendering

### List tile — compact (< 600dp)
Chip rendered as a **dedicated row** below the type badge `Wrap`:
```
#487
Giratina
[Ghost] [Dragon]
[Altered ▾]          ← own row, aligned start
```

### List tile — medium+ (≥ 600dp)
Chip **appended to the same `Wrap`** as type badges:
```
#487
Giratina
[Ghost] [Dragon]  [Altered ▾]
```
`Wrap` handles overflow naturally if both badges and chip exceed line width.

### Grid card (all sizes)
`Stack` wrapping the existing image area. Chip is a `Positioned(bottom: 6, left: 6)` overlay with a dark semi-transparent background (`Colors.black45`) for legibility over any artwork.

### Chip style
- **List tile** (light card background): outlined style — `surfaceContainerLow` fill, `outlineVariant` border, `onSurface` text
- **Grid card** (over artwork): dark semi-transparent pill — `Colors.black45` fill, white text, matches the existing `_FormBadge` style from the detail screen

Both chips show the current form label + `▾` icon.

---

## State

```dart
String? _selectedFormName; // null = base form; local to each card widget
```

State is per-card and ephemeral — resets whenever the widget leaves the render tree (scroll off-screen or navigate away). No persistence, no shared provider.

---

## Hero Tag

Updated from `'pokemon-sprite-${pokemon.id}'` to `'pokemon-sprite-${pokemon.id}-${_selectedFormName ?? ''}'` so the Hero animation is correct when navigating from a non-base form to the detail screen.

---

## Image Transition

`AnimatedSwitcher` wraps the image widget in both card types. When `_selectedFormName` changes the image cross-fades in, matching the `AnimatedContainer` gradient transition already in use.

---

## Loading & Edge Cases

| Scenario | Behaviour |
|---|---|
| Species still loading | Chip hidden; card looks identical to today until species resolves |
| No forms for this Pokémon | Chip never appears; card is unaffected |
| Form entry loading (`pokemonByNameProvider` pending after selection) | Image slot shows a centred `CircularProgressIndicator`; gradient stays at base-form colour until new type data arrives |
| `kBaseFormNameOverrides` species (e.g. Giratina-Altered, Deoxys-Normal) | `computeBaseFormLabel` handles via override map |
| Cosmetic-only species (e.g. Wormadam) | `allForms` contains base + cosmetic varieties; chip appears correctly |
| All-female battle forms (e.g. Meowstic) | `computeBaseFormLabel` returns `"Male"` for the base chip label |

---

## Out of Scope (v1)

- Persisting the selected form across navigation or app restarts
- Shiny toggle on list cards (picker's `shiny` param is always `false`)
- `cosmeticFormsProvider` pokemon-form cosmetics (Burmy cloaks, Shellos seas, etc.) — variety-based cosmetics via `kCosmeticVarietyNames` are included; form-based cosmetics are not
