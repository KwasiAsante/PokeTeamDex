# PokeTeamDex — Progress Tracker

> Updated 2026-06-09 after v1.0.6 release.

---

## Phase 1 — Project Scaffolding ✅

- [x] Flutter project + folder structure (`lib/features/`, `lib/services/`, `lib/shared/`)
- [x] go_router with bottom tab `StatefulShellRoute` (Pokédex / Moves / Items / Reference / Teams)
- [x] Material 3 theme with dark/light mode support
- [x] PokéAPI HTTP service layer + Hive read-through cache
- [x] Hive cache TTL (24h lists, 7d details)
- [x] Riverpod state management throughout

---

## Phase 2 — Pokédex Browser ✅

- [x] Pokémon list — sprite thumbnails, Dex#, name, type badges
- [x] Search by name or Dex number
- [x] Filters: Generation (1–9), Type, Sort (Dex# / Name)
- [x] Detail — **Overview** (artwork, types, height/weight, Pokédex entries, egg groups, gender ratio)
- [x] Detail — **Base Stats** (bar chart, BST, min/max at L50/L100)
- [x] Detail — **Abilities** (name, effect, hidden flag, generation)
- [x] Detail — **Moves** (grouped by learn method, version filter, power/accuracy/PP columns)
- [x] Detail — **Evolutions** (full chain with conditions, tap to navigate)
- [x] Detail — **Forms** (regional variants, Mega, Gigantamax with stat diffs)
- [x] Detail — **Locations** (by game version, encounter method + rate)
- [x] Detail — **Add to Team** (slot selector with type-based theming)

---

## Phase 3 — Reference Browsers

- [x] Moves — list (search + damage class filter), detail bottom sheet (type, category, power, accuracy, PP, effect)
- [x] Abilities — list (search), detail bottom sheet (short/long effect, generation, expand toggle)
- [x] Items — list (search), detail bottom sheet (sprite, category, price, effect)
- [x] Types — type effectiveness grid + detail sheet (2× / ½× / 0×)
- [x] Natures — table of 25 natures with +/− stat columns, neutral labelled
- [x] **Locations browser** — browse by region + search; location detail with collapsible areas, version filter chips, encounter table (sprite, method, level range, chance %)

---

## Phase 4 — Backend & Database

- [x] PostgreSQL schema — `users`, `team_folders`, `teams`, `team_slots` with sync columns (`updated_at`, `local_id`)
- [x] Alembic migrations (initial schema + nullable `folder_id` patch)
- [x] Auth endpoints (`POST /auth/register`, `POST /auth/login`)
- [x] Folders CRUD (`GET/POST /folders`, `PATCH/DELETE /folders/:id`)
- [x] Teams CRUD (`GET/POST /teams`, `GET/PATCH/DELETE /teams/:id`)
- [x] Slot endpoints (`POST/PUT/PATCH/DELETE /teams/:id/slots/:slotId`)
- [x] `GET /sync/pull?since=` endpoint (returns folders + teams + slots updated after timestamp)
- [x] **`POST /sync/push` batch endpoint** — PRD §9 specifies a single batch-push; current client calls individual CRUD endpoints per queued op instead *(no `/sync/push` route exists)*

---

## Phase 5 — Team Builder ✅

- [x] Folder hierarchy UI — collapsible sections, create/rename/delete, team count badge
- [x] Teams list with folder grouping and ungrouped fallback section
- [x] Create / rename / delete team
- [x] Team detail — full-width slot cards (redesigned from grid)
- [x] Filled slot card — sprite (shiny-aware), nickname/species, type badges, level, gender, item sprite + name, ability, nature, calculated stat bars, move strip
- [x] Slot long-press menu — configure slot, replace Pokémon, remove from team
- [x] Empty slot — tap → Slot Picker → Slot Config (context.replace, no intermediate Team Detail step)
- [x] Slot picker screen (search Pokédex, select Pokémon for a slot)
- [x] **Slot Config screen** — all per-slot fields:
  - [x] Ability cards (valid abilities for species, with effect description, labelled Hidden)
  - [x] Nature dropdown (25 natures with +/− stat labels inline)
  - [x] Held item — searchable picker with sprite + effect sub-text
  - [x] 4 move slots — learnable moves with type badge + power/acc/pp + effect description
  - [x] EV grid (0–252 each; running total, blocks save over 510)
  - [x] IV grid (0–31 each, default 31)
  - [x] Level (1–100, slider, default 50)
  - [x] Shiny toggle (swaps sprite to shiny URL)
  - [x] Gender picker (Male / Female / None chips)
  - [x] Friendship/happiness (0–255 slider)
- [x] **Local DB slot config columns** — schema v3: all slot config fields + `is_deleted` + `sync_status` on all entity tables, `format_label` + `sort_order` on teams, `sort_order` on folders
- [x] **Stat preview** — real-time Gen III+ calculator updating as EVs/IVs/nature/level change
- [x] **Drag-reorder** — slots within a team; teams within a folder; folders (all `ReorderableListView` / `SliverReorderableList`)
- [x] **`format_label` UI** — format picker in Create Team dialog + tune button on Team Detail; 32 formats (Gen 1–9 general + 22 mainline games)

---

## Format Engine Epic (format-engine/*)

- [x] **data-layer** — PS data sync script (`sync_ps_data.py`), bundled learnsets/moves/items/abilities JSON, `GET /ps-data/version` backend endpoint, `FormatService` with Hive cache + background update
- [x] **format-picker** — format selection on team create/edit, format display on team tile + detail AppBar, `updateTeamFormat` action, sync null-cast + stale-op fixes
- [x] **gen-mechanics** — slot config UI gates sections by generation: abilities/nature hidden Gen 1–2, held item hidden Gen 1, shiny toggle hidden Gen 1, friendship hidden Gen 1, EVs labelled "Stat Experience" Gen 1–2, IVs renamed "DVs" with max 15, Gen 1 shows 5 stats (HP/Atk/Def/Spc/Spe)
- [x] **gen-sprites** — PS transparent sprites for Gen 1–5 (gen5ani animated GIFs for BW), HOME/official artwork for Gen 6+; "Use generation sprites" toggle in Settings
- [x] **gen-learnsets** — move picker filtered by format version groups; game formats check exact version-group, gen formats union all groups in that gen; validation flags illegal moves/abilities/items
- [x] **event/gift movesets** — event and gift Pokémon movesets sourced from PS learnset data; surfaced in slot config move picker and used during move legality validation
- [ ] **format-sync** — fetch and sync competitive formats (tiers, rulesets) from Pokémon Showdown and Smogon *(deferred — post-release)*
- [ ] **custom-formats** — custom format builder UI *(deferred — post-release)*

---

## Phase 6 — Offline & Sync

- [x] `pending_sync_ops` Drift table (op_type, entity_type, payload, attempts, created_at)
- [x] Sync engine — push phase drains queue (skips after 5 attempts), calls per-entity API endpoints
- [x] Sync engine — pull phase fetches since `last_pull_at`, merges with last-write-wins on `updated_at`
- [x] `meta` Drift table for `last_pull_at` and `device_id`
- [x] Conflict resolution — last-write-wins on `updated_at`
- [x] Offline banner on Teams screen
- [x] Pending sync dot badge on team tiles
- [x] Sync error badge on team tiles (≥ 3 failed attempts, with subtitle)
- [x] Connectivity listener — auto-triggers sync when network returns
- [x] Auto-sync on login and register
- [x] WorkManager registered with 1-hour periodic task (non-web)
- [x] `is_deleted` + `sync_status` columns on all entity tables (schema v3)
- [x] **WorkManager background sync callback** — bootstraps standalone DB + API stack and calls `SyncService.run()` in the background isolate
- [x] **Soft-delete propagation** — backend soft-deletes (migration 0003); pull merge handles `is_deleted: true` by hard-deleting locally; folder delete cascades to teams + slots; CORS headers added to all error responses
- [x] **Pull-to-refresh on Teams screen** — `RefreshIndicator` on mobile; compact "Sync now" bar on desktop

---

## Phase 7 — Polish

- [x] Type colour palette (18 types, used on badges + detail pages)
- [x] Dark/light mode toggle (system-driven)
- [x] Sync status indicators — pending dot + error badge on team tiles
- [x] **Full Showdown export** — PRD §11.3 format: nickname, item, ability, level, shiny, nature, EVs (zeros omitted), 4 moves
- [x] **EV/IV validation** — 0–252 per stat, 510 total cap with red highlight; save blocked when over limit
- [x] **Shiny sprite** — shiny artwork shown when slot `is_shiny = true`
- [x] Performance pass — list providers no longer `autoDispose`; survive tab navigation
- [x] **Drag-reorder** — reorder slots within team; reorder teams within folder; reorder folders
- [x] **Team list card sprites** — 6 mini sprites (36px) on team tile; Poké Ball icon for empty slots

---

## Phase 8 — Testing

- [x] Unit tests — `SyncService` (push drain, pull merge, conflict resolution)
- [x] Unit tests — `buildShowdownExport`
- [x] Unit tests — stat formula calculator
- [x] Unit tests — `filterFormChips`, `resolveZMove`, `gmaxMoveForSpecies`, `resolveMaxMove`, `GenerationMechanics.forGen`, `GameFormat`, `PsMoveEntry/PsItemEntry/PsAbilityEntry` (123 tests total across 7 files)
- [x] Widget tests — `TeamsScreen`, `TeamDetailScreen`, `PokemonDetailScreen`
- [x] Widget tests — slot config form (EV overflow, IV clamping)
- [x] Integration tests — full CRUD flow: create folder → team → add slots → verify Drift DB
- [x] Integration tests — conflict resolution (local newer, remote newer, remote deleted)
- [ ] Integration tests — offline → online sync (write offline, come online, verify push + pull) *(requires HTTP mock layer; deferred post-release)*

---

## UI / UX Polish & Responsive Layouts

### Desktop Platform

- [x] **System tray** — minimize or close the app to the system tray on Windows/macOS/Linux; tray icon with quick-sync and quit actions (`tray_manager` package). The 15-min periodic Timer continues running while minimized to tray, giving near-WorkManager behaviour without needing a closed-app scheduler.

### Navigation & Shell

- [x] **Adaptive nav** — `BottomNavigationBar` < 600dp, `NavigationRail` 600–840dp, permanent `NavigationDrawer` > 840dp; overflow fixes for team tile sprites, slot card type badges, location encounter table
- [ ] **Pokéathlon stats in Slot Config** — display Pokéathlon stats per Pokémon in Slot Config; requires investigation into a viable data source (PokéAPI `/pokeathlon-stat/` only returns nature-affinity data, not per-Pokémon base values) *(requires investigation)*
- [x] **Connectivity status button** — wifi icon + coloured dot on every screen's AppBar; green = online + signed in, amber = online + not signed in, red = offline; tapping opens sheet with live Device / PokéAPI / Backend API / Account status rows + refresh button
- [x] **Teams tab** — shows "On your teams" list (team name, slot #, nickname, format label, tap to navigate); "Add to a team" sheet with team picker → slot grid showing current occupants; replacement confirmation dialog; "New team" creation from the sheet; inserts slot with defaults (L50, IVs 31) and queues sync op

### Pokédex

- [x] **List layout** — adaptive: list (1/row) default with view toggle chip → 2-col grid (600–840dp) or 3-col grid (>840dp)
- [x] **Pokédex entry card** — type-gradient background; adaptive images: icon (<600dp) / sprite (600–840dp) / official artwork (>840dp); applies to both list tiles and grid cards
- [x] **Detail screen layout** — on wide screens (> 840dp) show tabs as a left sidebar (220dp rail with icon + label) rather than a horizontal `TabBar`; sprite + type badges shown in rail header
- [x] **Stat bars** — staggered animated fill on first render (70ms per stat, `AnimationController` + `Curves.easeOut`)
- [x] **Evolution chain** — card-style nodes with border/background; linear chains use `_EvolutionArrow` with condition chip + arrow icon; branching chains (Eevee etc.) spread horizontally in a `Wrap` with `Icons.call_split_rounded` at branch point
- [x] **Type effectiveness grid** — full 18×18 matrix (Chart tab); 2×/½×/0×/1× colour-coded cells; scrollable; Types tab keeps existing detail sheet
- [x] **Hero animation** — shared element transition (sprite) from list card to detail screen

### Reference Browsers (Moves / Items / Abilities)

- [x] **Skeleton placeholders** — replace `LinearProgressIndicator` in tile subtitles with a shimmer skeleton while per-item detail loads
- [x] **Move/Item/Ability list layout** — 2-column grid on tablet+
- [x] **Filter persistence** — search/filter providers changed to non-autoDispose; SearchController text restored in initState on tab return

### Team Builder

- [x] **Team detail — wide layout** — on tablet/desktop, show the 6-slot list alongside a detail panel so tapping a slot opens its config without full navigation
- [x] **Empty-state illustrations** — replace generic icon + text with a more polished empty state (e.g. Poké Ball graphic for empty team list)
- [x] **Folder drag-and-drop** — reorder folders with long-press drag

### Bug Fixes & Polish Needed

- [x] **Unsaved changes guard** — when leaving slot config with unsaved changes, show a dialog offering "Discard" or "Save" before navigating away; works in both narrow (PopScope on Scaffold) and wide layout (back button on team detail intercepted via canCloseNotifier)
- [x] **Sync failure feedback** — push failures are now surfaced; pull still runs on push failure but sync reports error instead of success
- [x] **Connectivity button → login shortcut** — Account row in the connectivity sheet is tappable when not signed in and navigates to the login screen
- [x] **Login screen keyboard submit** — pressing Enter/Return on the password field triggers the login attempt

### Bug Fixes & Polish Applied

- [x] **Regional form gen gating** — Alolan/Galarian/Hisuian/Paldean form chips are now hidden when the team format's gen is below their introduction gen (7/8/9/9); uses `.contains()` so infix forms like `darmanitan-galar-zen` are also covered (#202)
- [x] Moves damage class filter no longer leaves blank gaps — `itemExtent` disabled when filter active
- [x] Moves list: type filter chips (all 18 types, API-backed, cached)
- [x] Slot Config: ⓘ info icons on ability cards, held item, move slots → link to detail screens
- [x] Move Detail screen — type, stats, effect, flavor text, past values, contest, TM/HM/TR (→ Item Detail), Learned by (→ Pokédex)
- [x] Item Detail screen — sprite, fling, attributes, effect, flavor text, baby trigger, move taught (→ Move Detail), Held by Pokémon (→ Pokédex)
- [x] Ability Detail screen — generation, main series badge, effect changes, flavor text, Pokémon list (→ Pokédex)
- [x] Items list: pocket filter + sort (A→Z / Z→A / ID↑ / ID↓)
- [x] Abilities list: generation filter (Gen III–IX) + sort toggle

### Theming & Visual Consistency

- [x] **Colour-scheme seeding** — 9 preset accent colour swatches in Settings → Appearance; theme mode toggle (Light / System / Dark); both persist via Drift and apply instantly app-wide
- [x] **Type badge sizing** — standardised badge to `labelSmall` (11sp, w600, 0.3 letter-spacing), capitalized; consistent across Pokédex list, detail tabs, and team slot cards
- [x] **Pokédex pagination** — virtual infinite scroll (50 per page); filter/search operate on full dataset; resets to page 1 on filter change
- [x] **Pokédex game filter** — game chip appears when generation is active; filters to that game's regional dex; Dex # sort uses regional entry numbers; generation change clears game filter
- [x] **Loading states** — replace full-screen `CircularProgressIndicator` on list screens with a paginated skeleton list
- [x] **Error states** — themed error colours (errorContainer/onErrorContainer), friendly "Something went wrong" copy, detail in bodySmall, "Try again" FilledButton; EmptyState now uses a surfaceContainerHighest circle icon container
- [x] **Skeleton loaders in machine tiles** — replaced `LinearProgressIndicator` with `SkeletonBox` in move and item detail `_MachineTile`
- [x] **Snackbar → floating** — `SnackBarBehavior.floating` applied to all 12 `showSnackBar` calls across settings, sync monitor, teams, slot picker, slot config, team detail screens
- [x] **Error states** — add a branded error illustration and a clear retry CTA; current `ErrorState` widget is plain text
- [x] **Snackbar → toast migration** — use Material 3 `SnackBar` styling consistently; avoid stacking snackbars
- [x] **Haptic feedback** — mediumImpact on slot card long-press; lightImpact on Showdown export copy

### Accessibility

- [x] **Semantic labels** — add `Semantics` / `tooltip` to icon-only buttons (sync, export, settings)
- [x] **Minimum touch targets** — audit all tappable widgets for 48 × 48 dp minimum
- [x] **Text scaling** — verify layouts don't break at large (1.3×) and extra-large (1.5×) system font sizes
- [x] **Screen reader order** — ensure tab order on wide layouts is logical (left-to-right, top-to-bottom)

### Responsive Breakpoints (reference)

| Breakpoint | Width      | Layout change |
| ---------- | ---------- | ------------- |
| Compact    | < 600 dp   | Current layout — bottom nav, single column |
| Medium     | 600–840 dp | `NavigationRail`, 2-column grids |
| Expanded   | > 840 dp   | Permanent `NavigationDrawer`, master-detail panels, 3-column grids |

---

## Planned Features — Wave 1 (Pre-release, simpler)

### Team Management
- [x] **Team: Move to folder** — "Move to folder" in team context menu; bottom sheet lists all folders + Ungrouped; one DB write + sync op
- [x] **Team: Drag to folder** — folder section headers as `DragTarget`; team tiles as `Draggable`; cross-section drag replaces folder assignment
- [x] **Team: Duplicate** — "Duplicate team" in context menu; deep-copies team row + all slots with "(Copy)" suffix; queues create ops
- [x] **Promote/demote Team ↔ Box** — context menu option on any team or box to flip the `isBox` flag; synced to backend
- [x] **Slot: Multi-select** — long-press enters selection mode; bulk delete, copy, or move selected slots to another team
- [x] **Slot: Move/copy to another team** — single-slot context menu action; destination picker sheet shows all teams with available slots
- [x] **PS Import: name & format override** — dialog lets user enter a custom team name and pick a format before the paste is committed to DB
- [x] **Sync sort order and isBox** — team and folder `sort_order` + team `is_box` synced end-to-end to backend (push + pull)

### Pokédex
- [x] **Favorites** — star `IconButton` on Pokédex list tile, detail header, team slot card, and slot config AppBar; favorites `FilterChip` in Pokédex filter bar; `favorites` Drift table (`pokemon_id` PK)
- [x] **Slot picker: format auto-filter** — when team has a `formatLabel`, pre-seed the generation filter (and game chip for game-specific formats) in the slot picker so only eligible Pokémon are shown
- [x] **Form switching on Pokédex list screen** (#192) — form chip on every list tile and grid card that has switchable forms; chip opens a bottom-sheet picker; selecting a form updates the card's sprite, gradient, and display name in place; covers battle-meaningful variety forms, cosmetic variety forms (`kCosmeticVarietyNames`), and form-entry cosmetics (`cosmeticFormsProvider`); tapping a card with a battle form selected navigates to the detail screen with that form pre-selected

### Reference Browsers
- [x] **Move chips: Z / Max / G-Max** — "Z" chip (IDs 622–658, 695–703, 719, 723–728), "Max" chip (IDs 734, 757–774) on move tiles + detail; "G-Max" chip derived from PS `moves.json` (names starting with `g-max-`)
- [x] **Contest data enhancement** — super contest + contest spectacular data in move detail; heart bar for appeal (❤️/🤍 per point), jam bar (🖤/🤍); contest-type badge chips (Cool/Beautiful/Cute/Clever/Tough)

### Slot Config
- [x] **Contest stats + radar chart** — 6 contest stat sliders (Coolness/Beautifulness/Cuteness/Cleverness/Toughness/Sheen, 0–255) in slot config, visible only for gen 3/4/no-format; rendered as a radar/spider chart via `fl_chart RadarChart`; DB migration adds 6 columns to `team_slots`
- [x] **Ribbons** — hardcoded ribbon catalog by category (League, Contest, Tower, Memorial, Gift, Special) sourced from Bulbapedia; `ribbons` JSON column on `team_slots`; chip-grid picker in slot config
- [x] **Tera Type** — 18-type chip selector in slot config; shown only for Gen 9 / SV formats; `tera_type` column on `team_slots`; displayed on team card
- [x] **Cosmetic form support** — Unown letters, Vivillon patterns, Alcremie decorations, and other cosmetic-only variants tracked per slot; cosmetic forms do not change stats/typing/moves

### Pokémon Showdown Sync
- [x] **PS import** — parse PS team `.txt` format (Nickname (Species) @ Item, Ability, EVs, moves) → create teams + slots locally; folder mapping from PS subfolder structure
- [x] **PS export to directory** — setting to point to PS teams directory (path picker); write/update `.txt` on every team save; subfolder per app folder
- [x] **PS export: format header** — PS format ID prefixed in exported filename (`[gen6anythinggoes] Team Name.txt`); file body is clean Pokémon blocks only (no header inside)

---

## Planned Features — Wave 2 (Pre-release, complex — after Wave 1)

### Generation Gimmicks (format-engine/gimmicks epic)
- [x] **Mega Evolution** — mega stone → mega form mapping JSON; in slot config when held item is a Mega Stone and Pokémon has a mega form: sprite/image swaps to mega form, base stats recalculate, toggle to switch between base and mega; `is_mega_evolved` bool column on `team_slots`
- [x] **Z-Moves** — Z-crystal → Z-move lookup JSON (18 type crystals + ~20 exclusive crystals with required base moves); in slot config when Z-crystal is held show corresponding Z-move next to each of the 4 moves; exclusive Z-move shown if base move present
- [x] **Dynamax / Gigantamax** — all Pokémon: show type-appropriate Max Move next to each move; G-Max capable list + G-Max move per species from PS data; `has_gigantamax` + `gigantamax_enabled` booleans on `team_slots`; G-Max toggle swaps sprite to `-gmax` form; Alpha Pokémon flag (`is_alpha` bool) for Legends Arceus

### Pokémon Instances (continuity across teams)
- [x] **Data model** — `pokemon_instances` table (schema v9): `id`, `parent_instance_id` (nullable self-ref chain), `nickname_aliases` (JSON), `inherited_ribbons` (JSON); `team_slots.instance_id` nullable FK; `PokemonInstanceRepository` with full CRUD + `getChain` / `getDirectChildren`
- [x] **Link UI** — "Pokémon Identity" section in slot config; link type chooser (child vs origin); instance picker sheet; chain view showing ancestors + current slot + direct children with origin/child badges; "Add child" button on linked state; copy-to-team-slot destination picker (new team or empty slot in existing team)
- [x] **Data inheritance** — ribbon merging from `inheritedRibbons`; "Previously known as" alias display when nickname differs from parent; gender/isShiny propagated when copying to child slot
- [x] **Inherited ribbons excluded from picker** — ribbons already in the instance chain are shown in the read-only "Inherited" chips section only; filtered out of the selectable catalog so they can't be redundantly toggled (#207)
- [x] **Navigation** — tapping a chain row navigates to that slot's config screen
- [x] **Chain sync fix** — `parent_instance_id` now preserved across devices: backend pull ordered by ID, push topologically sorts instance ops, Flutter merge uses two-pass resolution (#214)

---

## Optional / Post-release Enhancements

- [ ] **Master-detail side panel** — on wide layouts (> 840dp) show Pokédex list + detail and Teams list + team detail as side-by-side panels rather than full navigations; primarily a desktop UX polish item, irrelevant on mobile

---

## Investigations

- [ ] **Unified Pokémon data resolution layer** — cross-source gaps (PokéAPI / Showdown / Smogon), scattered override maps, and unresiolved form data are recomputed on every request with no single cached result; investigate a unified model that does gap-filling once and caches the resolved output *(#201)*

---

## Deferred / Post-release

- [ ] **G-Max moves in move list + detail** — G-Max moves (`g-max-*`) are currently accessible via the moves browser but don't appear in PokéAPI's learned-by lists; source from PS/Bulbapedia data and surface them as a filterable category in the move list and as a distinct section in Pokémon detail Moves tab
- [ ] **PS sync: live directory watch** — `Directory.watch()` + three-way conflict resolution (PS file mtime vs local `updated_at` vs remote `updated_at`)
- [ ] **Contest moves toggle** — contest move mode in slot config; separate 4-move picker showing contest information (appeal, jam, type) per move
