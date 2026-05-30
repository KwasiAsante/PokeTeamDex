# PokeTeamDex — Progress Tracker

> Generated 2026-05-29 from PRD v1.0 audit. Checked items are confirmed implemented in the codebase.

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
- [ ] **`is_deleted` soft-delete on local Drift schema** — `teams`, `team_folders`, `team_slots` tables lack the column; deletions can't propagate to other devices via pull

---

## Phase 5 — Team Builder

- [x] Folder hierarchy UI — collapsible sections, create/rename/delete, team count badge
- [x] Teams list with folder grouping and ungrouped fallback section
- [x] Create / rename / delete team
- [x] Team detail — 6-slot grid (filled + empty cards)
- [x] Filled slot card — sprite, nickname/species, type badges
- [x] Slot long-press menu — edit nickname, replace Pokémon, remove from team
- [x] Empty slot — tap to pick Pokémon (slot picker screen)
- [x] Slot picker screen (search Pokédex, select Pokémon for a slot)
- [ ] **Slot Config screen** — all per-slot fields (required to unblock full Showdown export + stat preview):
  - [ ] Ability dropdown (valid abilities for species, labelled 1 / 2 / Hidden)
  - [ ] Nature dropdown (25 natures with +/− stat labels inline)
  - [ ] Held item — searchable dropdown with sprite + effect sub-text
  - [ ] 4 move slots — moves the Pokémon can learn, type badge + power/accuracy, tap for detail overlay
  - [ ] EV sliders/inputs (0–252 each; running total, highlight red over 510)
  - [ ] IV inputs (0–31 each, default 31)
  - [ ] Level (1–100, default 50)
  - [ ] Shiny toggle
  - [ ] Gender picker (respects species `gender_rate`)
  - [ ] Form/variant selector
  - [ ] Friendship/happiness (0–255)
- [ ] **Local DB slot config columns** — `team_slots` Drift table currently stores only `pokemonId` + `nickname`; needs all slot config fields added (ability, nature, held item, moves 1–4, EVs 1–6, IVs 1–6, level, is_shiny, gender, form_name)
- [ ] **Stat preview** — real-time Gen III+ calculator updating as EVs/IVs/nature/level change (formula in PRD §12)
- [ ] **Drag-reorder** — slots within a team; teams within a folder
- [ ] **`format_label` field on Team** — game/format label (e.g. "VGC 2025") per PRD §6.1.2; not in DB schema or UI yet

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
- [ ] **WorkManager background sync callback** — registered but callback is a no-op stub; needs to call `SyncService.run()`
- [ ] **Soft-delete propagation** — `is_deleted` not in local Drift schema; deletions made on device A don't reach device B via pull
- [ ] **Pull-to-refresh on Teams screen** — PRD §7.2 specifies this as a sync trigger *(not implemented)*

---

## Phase 7 — Polish

- [x] Type colour palette (18 types, used on badges + detail pages)
- [x] Dark/light mode toggle (system-driven)
- [x] Sync status indicators — pending dot + error badge on team tiles
- [x] Basic Showdown export — `{Nickname} ({Species})` / `{Species}` per team, copies to clipboard
- [x] Performance pass — list providers (`movesListProvider`, `itemsListProvider`, `abilitiesListProvider`) no longer `autoDispose`; survive tab navigation
- [ ] **Full Showdown export** — blocked by Slot Config; needs held item, ability, level, shiny, nature, EVs (omit zeros), 4 moves per PRD §11.3
- [ ] **EV/IV validation** — 0–252 per stat, 510 total cap with red highlight *(blocked by Slot Config)*
- [ ] **Shiny sprite** — shiny artwork shown when slot `is_shiny = true`; infrastructure exists in sprite widget but not wired to slot state
- [ ] **Drag-reorder** — reorder slots within team; reorder teams within folder (`ReorderableListView`)

---

## Phase 8 — Testing

- [ ] Unit tests — `SyncService` (push drain, pull merge, conflict resolution)
- [ ] Unit tests — `buildShowdownExport` (when full fields are in place)
- [ ] Unit tests — stat formula calculator
- [ ] Widget tests — `TeamsScreen`, `TeamDetailScreen`, `PokemonDetailScreen`
- [ ] Widget tests — slot config form (EV overflow, IV clamping)
- [ ] Integration tests — full CRUD flow: create folder → team → add slots → verify Drift DB
- [ ] Integration tests — offline → online sync (write offline, come online, verify push + pull)
- [ ] Integration tests — conflict resolution (local newer, remote newer)
- [ ] Manual test matrix — iOS, Android, Web (Chrome)

---

## UI / UX Polish & Responsive Layouts

> The app currently functions but looks bare-bones. This section covers visual polish, interaction quality, and making the layout work well across phone, tablet, and desktop web.

### Navigation & Shell

- [ ] **Adaptive nav** — switch from bottom `NavigationBar` to a `NavigationRail` (tablet) or permanent `NavigationDrawer` (desktop/wide web) at ≥ 600 dp breakpoint
- [ ] **App-wide back gesture / breadcrumb** — on wide layouts the detail screen should open in a side panel rather than pushing a new route (master-detail pattern for Pokédex, Teams)

### Pokédex

- [ ] **List layout** — replace flat `ListView` with a 2-column grid on tablet / 3-column on desktop; card size adapts to available width
- [ ] **Detail screen layout** — on wide screens show tabs as a left sidebar (rail) rather than a horizontal `TabBar` that truncates
- [ ] **Pokédex entry card** — add subtle gradient using primary type colour; official artwork on card instead of small sprite
- [ ] **Stat bars** — animate fill on first render (staggered per stat)
- [ ] **Evolution chain** — style with connecting arrows/icons and evolution condition chips; currently text-only
- [ ] **Type effectiveness grid** — full 18×18 visual matrix in the Types browser; currently only shows matchups for one type at a time
- [ ] **Hero animation** — shared element transition (sprite) from list card to detail screen

### Reference Browsers (Moves / Items / Abilities)

- [ ] **Skeleton placeholders** — replace `LinearProgressIndicator` in tile subtitles with a shimmer skeleton while per-item detail loads (name is known; only stat row is pending)
- [ ] **Move/Item/Ability list layout** — 2-column grid on tablet+
- [ ] **Filter persistence** — remember search query and filter chips across tab switches (currently resets because search state is `autoDispose`)

### Team Builder

- [ ] **Team list card** — show row of 6 mini sprites (Poké Ball for empty slots) on the team tile, matching PRD §6.1.2
- [ ] **Team detail — wide layout** — on tablet/desktop, show the 6-slot grid alongside a detail panel so tapping a slot opens its config without full navigation
- [ ] **Slot card polish** — show held item icon, nature label, 4 move names in the filled slot summary card (once Slot Config is done)
- [ ] **Empty-state illustrations** — replace generic icon + text with a more polished empty state (e.g. Poké Ball graphic for empty team list)
- [ ] **Folder drag-and-drop** — reorder folders with long-press drag

### Theming & Visual Consistency

- [ ] **Colour-scheme seeding** — allow user to choose accent colour in Settings (fed into `ColorScheme.fromSeed`); current red is hardcoded
- [ ] **Type badge sizing** — standardise badge height and font size; currently slightly inconsistent between Pokédex list, detail tabs, and team slot cards
- [ ] **Loading states** — replace full-screen `CircularProgressIndicator` on list screens with a paginated skeleton list (avoids blank screen on first load)
- [ ] **Error states** — add a branded error illustration and a clear retry CTA; current `ErrorState` widget is plain text
- [ ] **Snackbar → toast migration** — use Material 3 `SnackBar` styling consistently; avoid stacking snackbars (dismiss previous before showing new)
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

---

*Next milestone: **Slot Config screen** (Phase 5) — unblocks full Showdown export, EV/IV validation, stat preview, and shiny toggle.*
