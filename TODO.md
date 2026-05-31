# PokeTeamDex — Progress Tracker

> Updated 2026-05-30 after schema v3 + slot config merge (PR #30).

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
- [ ] **Locations browser** — browse by region/game; location detail with wild encounters and methods *(not implemented)*

---

## Phase 4 — Backend & Database

- [x] PostgreSQL schema — `users`, `team_folders`, `teams`, `team_slots` with sync columns (`updated_at`, `local_id`)
- [x] Alembic migrations (initial schema + nullable `folder_id` patch)
- [x] Auth endpoints (`POST /auth/register`, `POST /auth/login`)
- [x] Folders CRUD (`GET/POST /folders`, `PATCH/DELETE /folders/:id`)
- [x] Teams CRUD (`GET/POST /teams`, `GET/PATCH/DELETE /teams/:id`)
- [x] Slot endpoints (`POST/PUT/PATCH/DELETE /teams/:id/slots/:slotId`)
- [x] `GET /sync/pull?since=` endpoint (returns folders + teams + slots updated after timestamp)
- [ ] **`POST /sync/push` batch endpoint** — PRD §9 specifies a single batch-push; current client calls individual CRUD endpoints per queued op instead *(no `/sync/push` route exists)*

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
- [ ] **banlist** — Layer 2 competitive ban checking (Ubers, clause violations, format-specific bans) *(deferred)*
- [ ] **custom-formats** — custom format builder UI *(deferred)*

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
- [ ] **Soft-delete propagation** — `is_deleted` column exists in local Drift schema but sync engine still hard-deletes; deletions made on device A don't reach device B via pull
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

- [ ] Unit tests — `SyncService` (push drain, pull merge, conflict resolution)
- [ ] Unit tests — `buildShowdownExport`
- [ ] Unit tests — stat formula calculator
- [ ] Widget tests — `TeamsScreen`, `TeamDetailScreen`, `PokemonDetailScreen`
- [ ] Widget tests — slot config form (EV overflow, IV clamping)
- [ ] Integration tests — full CRUD flow: create folder → team → add slots → verify Drift DB
- [ ] Integration tests — offline → online sync (write offline, come online, verify push + pull)
- [ ] Integration tests — conflict resolution (local newer, remote newer)
- [ ] Manual test matrix — iOS, Android, Web (Chrome)

---

## UI / UX Polish & Responsive Layouts

### Desktop Platform

- [ ] **System tray** — minimize or close the app to the system tray on Windows/macOS/Linux; tray icon with quick-sync and quit actions (`tray_manager` package). The 15-min periodic Timer continues running while minimized to tray, giving near-WorkManager behaviour without needing a closed-app scheduler.

### Navigation & Shell

- [ ] **Adaptive nav** — switch from bottom `NavigationBar` to a `NavigationRail` (tablet) or permanent `NavigationDrawer` (desktop/wide web) at ≥ 600 dp breakpoint
- [ ] **App-wide back gesture / breadcrumb** — on wide layouts the detail screen should open in a side panel rather than pushing a new route (master-detail pattern for Pokédex, Teams)

### Pokédex

- [ ] **List layout** — replace flat `ListView` with a 2-column grid on tablet / 3-column on desktop
- [ ] **Detail screen layout** — on wide screens show tabs as a left sidebar (rail) rather than a horizontal `TabBar` that truncates
- [ ] **Pokédex entry card** — add subtle gradient using primary type colour; official artwork on card instead of small sprite
- [ ] **Stat bars** — animate fill on first render (staggered per stat)
- [ ] **Evolution chain** — style with connecting arrows/icons and evolution condition chips; currently text-only
- [ ] **Type effectiveness grid** — full 18×18 visual matrix in the Types browser; currently only shows matchups for one type at a time
- [ ] **Hero animation** — shared element transition (sprite) from list card to detail screen

### Reference Browsers (Moves / Items / Abilities)

- [ ] **Skeleton placeholders** — replace `LinearProgressIndicator` in tile subtitles with a shimmer skeleton while per-item detail loads
- [ ] **Move/Item/Ability list layout** — 2-column grid on tablet+
- [ ] **Filter persistence** — remember search query and filter chips across tab switches (currently resets because search state is `autoDispose`)

### Team Builder

- [ ] **Team detail — wide layout** — on tablet/desktop, show the 6-slot list alongside a detail panel so tapping a slot opens its config without full navigation
- [ ] **Empty-state illustrations** — replace generic icon + text with a more polished empty state (e.g. Poké Ball graphic for empty team list)
- [ ] **Folder drag-and-drop** — reorder folders with long-press drag

### Theming & Visual Consistency

- [ ] **Colour-scheme seeding** — allow user to choose accent colour in Settings (fed into `ColorScheme.fromSeed`); current red is hardcoded
- [ ] **Type badge sizing** — standardise badge height and font size; currently slightly inconsistent between Pokédex list, detail tabs, and team slot cards
- [x] **Pokédex pagination** — virtual infinite scroll (50 per page); filter/search operate on full dataset; resets to page 1 on filter change
- [ ] **Loading states** — replace full-screen `CircularProgressIndicator` on list screens with a paginated skeleton list
- [ ] **Error states** — add a branded error illustration and a clear retry CTA; current `ErrorState` widget is plain text
- [ ] **Snackbar → toast migration** — use Material 3 `SnackBar` styling consistently; avoid stacking snackbars
- [ ] **Haptic feedback** — light impact on long-press (slot menu, folder actions), success notification on Showdown export copy

### Accessibility

- [ ] **Semantic labels** — add `Semantics` / `tooltip` to icon-only buttons (sync, export, settings)
- [ ] **Minimum touch targets** — audit all tappable widgets for 48 × 48 dp minimum
- [ ] **Text scaling** — verify layouts don't break at large (1.3×) and extra-large (1.5×) system font sizes
- [ ] **Screen reader order** — ensure tab order on wide layouts is logical (left-to-right, top-to-bottom)

### Responsive Breakpoints (reference)

| Breakpoint | Width      | Layout change |
| ---------- | ---------- | ------------- |
| Compact    | < 600 dp   | Current layout — bottom nav, single column |
| Medium     | 600–840 dp | `NavigationRail`, 2-column grids |
| Expanded   | > 840 dp   | Permanent `NavigationDrawer`, master-detail panels, 3-column grids |

---

## Deferred / Out of Scope

- Real-time battle simulation
- Multi-user / public team sharing
- Pokémon GO data
- In-app purchases
