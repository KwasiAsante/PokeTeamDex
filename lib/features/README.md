# lib/features/

Feature modules. Each module owns its screens, Riverpod providers, and local data models. No feature imports from another feature — cross-cutting concerns (DB, sync, format engine) live in `lib/services/` and `lib/database/`.

---

## Module Structure

Every feature follows the same layout:

```text
features/<name>/
├── presentation/
│   ├── <name>_screen.dart      # Root screen widget
│   └── widgets/                # Screen-specific sub-widgets
├── providers/                  # Riverpod providers + notifiers
└── data/                       # Static data, models, or service wrappers
```

---

## Feature Index

### `pokedex/`

Pokémon browser across all 9 generations.

| Screen | Description |
| ------ | ----------- |
| `PokemonListScreen` | Infinite-scroll list (50/page); search, gen/type/game filter, sort; form chip on every tile/card |
| `PokemonDetailScreen` | Tabbed detail: Overview, Stats, Abilities, Moves, Evolutions, Forms, Locations |
| `FormPickerSheet` (`presentation/widget/`) | Bottom-sheet form picker opened from list card chips and detail header |

Notable behaviours:

- **Hero animation** — sprite transitions from list card to detail header
- **Adaptive layout** — tab bar becomes a left sidebar on wide screens (> 840dp)
- **Stat bars** — staggered animated fill using `AnimationController`
- **Favorites** — star button writes to the `Favorites` Drift table
- **Form switching** — form chip on list tiles and grid cards; selecting a form updates the sprite, gradient, and display name in place; covers battle-meaningful variety forms, cosmetic variety forms, and form-entry cosmetics

`logic/` files:

- `form_filter.dart` — `filterFormChips()`: determines which form chips to show for a species, gated by generation and prerequisite item/ability
- `evolution_chain_builder.dart` — builds a typed evolution tree from PokéAPI `evolution_chain` JSON

`providers/` + `models/` — backend-hybrid data:

- `providers/resolved_pokemon_provider.dart` — `resolvedPokemonProvider` (`FutureProvider.family`, `keepAlive`): merges detail + species + cosmetic forms into one `ResolvedPokemon`, sourced from Hive cache → backend `/pokemon/{id}/resolved` → PokéAPI fallback (built on top of `lib/services/pokemon_resolved/`, see [`services/README.md`](../services/README.md#pokemon_resolved))
- `models/resolved_pokemon.dart` — `ResolvedPokemon`: the merged object consumed by the detail screen, list tiles/cards, and team/slot screens

---

### `teams/`

The core team builder feature — the most complex module.

| Screen | Description |
| ------ | ----------- |
| `TeamsScreen` | Folder hierarchy; create/rename/delete teams and folders; drag-reorder; drag-to-folder |
| `TeamDetailScreen` | 6-slot list with filled/empty slot cards; Showdown export; format picker; rename |
| `SlotPickerScreen` | Browse Pokédex to assign a Pokémon to a slot (format auto-filters to eligible Pokémon) |
| `SlotConfigScreen` | Full slot configuration — all per-Pokémon fields |

**SlotConfigScreen** sections:

- Form picker (regional variants, Mega, Gigantamax, cosmetic variants — Unown, Vivillon, Alcremie, etc.)
- Level slider (1–100)
- Gender chips + shiny toggle + friendship slider
- Ability cards — gen-gated (hidden abilities hidden for Gen 1–4; abilities not yet introduced hidden by format gen)
- Nature dropdown (25 natures with stat deltas inline)
- Held item — searchable picker with sprite + effect
- 4 Move slots — learnable moves filtered by generation/format
- EV grid (0–252/stat, 510 total cap with overflow block)
- IV grid (0–31/stat, renamed DVs with max 15 in Gen 1–2)
- Tera Type selector (18-type chips, Gen 9 / SV formats only)
- Ribbon catalog — gen-gated chip-grid picker
- Mega/Dynamax/Gigantamax/Alpha toggles (gated by generation)
- Contest stat sliders + radar chart (Gen 3–4 / no-format only)
- Pokémon Identity section (instance chain browser)

`data/` files:

- `form_data.dart` — PS form exception maps and cosmetic sprite stem constants
- `form_descriptor.dart` — `FormDescriptor` value object: bundles form name, sprite hint, and battle-meaningful flag

`logic/` files:

- `ps_form_resolver.dart` — heuristics for resolving a PS form name from PokéAPI variety name; exceptions-first lookup

**`services/showdown_export.dart`** — `buildShowdownExport(team, slots)` produces standard Showdown `.txt` format.

---

### `moves/`

Moves browser with full detail.

- Search by name
- Filter by damage class (Physical / Special / Status) and type (all 18)
- Z-move, Max move, G-Max move chips on tiles
- `MoveDetailBottomSheet` — type, category, power, accuracy, PP, effect, contest data, TM/HM list, Learned by Pokémon list

---

### `items/`

Items browser.

- Search by name; pocket filter; sort A→Z / Z→A / ID↑ / ID↓
- `ItemDetailBottomSheet` — sprite, fling power, attributes, effect, flavor text, baby trigger, move taught, Held by Pokémon

---

### `abilities/`

Abilities browser.

- Search by name; generation filter (Gen 3–9)
- `AbilityDetailBottomSheet` — generation, main-series flag, short/long effect, generation-specific effect changes, Pokémon list

---

### `types/`

Type effectiveness reference.

- Full 18×18 attack vs defence matrix
- Colour-coded cells: 2× (green), ½× (red), 0× (dark), 1× (neutral)
- `TypeDetailBottomSheet` — attacking and defending matchups for a single type

---

### `locations/`

Locations browser.

- Browse by region
- `LocationDetailScreen` — collapsible location areas, version filter chips, encounter table (sprite, method, level range, encounter rate %)

---

### `natures/`

25 natures in a sortable table with +/− stat columns. Neutral natures labelled.

---

### `reference/`

Hub screen that links to Locations, Abilities, Types, and Natures.

---

### `auth/`

- `LoginScreen` — email + password; Enter key on password field submits; auto-sync on success
- `RegisterScreen` — email + password + confirm; same flow

---

### `settings/`

- `SettingsScreen` — API base URL, theme mode (Light/System/Dark), accent colour (9 presets), PS directory export toggle
- `SyncMonitorScreen` — history of sync runs, pending op count, error details
