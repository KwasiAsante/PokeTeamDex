# Changelog

All notable changes to PokeTeamDex are documented here.

---

## [1.0.4] — 2026-06-08

### Added
- **Tera Type** selection in Slot Config and team card (Gen 9)
- **Promote/demote** Pokémon between Team and Box from the slot context menu
- **Multi-select slots** — long-press any slot to enter selection mode; bulk delete, copy, or move selected slots to another team
- **Move/copy slot** to another team from the slot context menu
- **Import name & format override** — enter a custom team name and pick the format when importing a Pokémon Showdown paste
- **Cosmetic form support** — Unown letters, Vivillon patterns, Alcremie decorations, and other cosmetic variants tracked per slot
- **Event/gift Pokémon movesets** surfaced in slot details and used during move legality validation
- **Horizontally scrollable** team list card sprites — all 6 slot icons always visible on narrow screens
- **Loading indicators** on held-item and move description fetch in Slot Config
- Sync team/folder sort order and `isBox` flag to backend

### Fixed
- PS import now handles special-named Pokémon (Sirfetch'd, Gastrodon-East)
- Team Detail AppBar actions moved to overflow menu on mobile to prevent crowding
- Form suffix stripped from display name for species with no plain form (e.g. Minior-Meteor)
- Full ancestor tree shown in slot config link chain; height bounded to prevent overflow
- Rayquaza can Mega Evolve via Dragon Ascent without holding a Mega Stone
- Primal Reversion restricted to its Gen 6–7 window
- Primal Reversion now surfaced via Red Orb / Blue Orb
- Shiny variants resolved correctly for Mega and G-Max artwork
- Wormadam gender locked to female; Griseous Core accepted; Urshifu/Toxtricity G-Max art corrected

### Performance
- PS JSON data decoded off the UI isolate (eliminates jank on slow devices)
- Learnset and violation recomputation eliminated in Slot Config (only recalculates on change)
- Species, ability, evolution-chain, and form entries memoized across the session
- Decoded image cache capped; slot saves batched in a single DB transaction
- Sync DB writes batched in transactions to stop redundant provider rebuild storms

---

## [1.0.3] — 2026-06-06

### Added
- **Prior-evolution-exclusive moves** shown in Slot Config move picker and Pokémon detail Moves tab
- **Evolution-aware slot linking** — evolving a Pokémon in a chain slot creates a child instance automatically; gender-specific artwork applied
- **Save All Slots** button on Team Detail screen — saves every open slot in one tap
- **Import into existing team** — Pokémon Showdown paste can be imported directly over an existing team (replaces its slots)
- **Minimize-to-tray toggle** in Settings (Windows/macOS/Linux)
- **System-tray shutdown dialog** — confirm before quitting from the tray icon
- Structured logging for Flutter and FastAPI with Loki integration
- Auto-deploy backend Docker image to GHCR on every push to `main` that touches `backend/`
- `format_label` synced end-to-end (push and pull) for all teams

### Fixed
- `format_label` now emitted in `team:create` sync op
- Gen 2 shiny and female sprite URLs corrected
- `updated_at` explicitly set on all push mutations (backend) to prevent stale-merge collisions
- Permanently unprocessable sync ops (5+ failures) are now discarded instead of blocking the queue
- Move name no longer renders vertically on narrow mobile screens
- GHCR Docker image tag lowercased via `docker/metadata-action`
- `workflow_dispatch` trigger added to backend deploy workflow for manual runs

---

## [1.0.2] — 2026-06-05

### Fixed
- MSI installer: app now launches after clicking Finish (WiX 4 `Publish` dialog event)
- MSI installer: replaced `WixShellExec` with a type-34 `CustomAction` for reliable app launch
- MSI installer: corrected `Condition` attribute syntax (WiX 4 — attribute not inner text)
- Backend update-notification workflow only fires after all platform builds complete
- `FcmService.isSupported` made public (was `_isSupported`, broke the web build)
- `is_box` migration guarded against duplicate-column errors on dev builds
- Login cancel no longer leaves a stale auth state

---

## [1.0.1] — 2026-06-04

### Added
- **Boxes** — create a Team or a Box from the same dialog; `isBox` column on teams; Boxes hold a configurable number of slots (not limited to 6)
- Gen 1–2 EV rules — EVs labelled "Stat Experience", capped at 65535, total cap lifted
- Gen 1 Special stat — single Spc stat shown and calculated in place of SpA/SpD
- Gen-gated ribbons and gender — ribbon picker and gender chip hidden for formats that don't support them

### Fixed
- `isBox` migration uses raw SQL (`customStatement`) to bypass Drift `BoolColumn` restriction
- Gen 1 Special stat correctly mirrors SpD value on Pokémon Showdown import
- PS import auto-detects Box when paste contains more than 6 Pokémon

---

## [1.0.0] — 2026-06-04

Initial public release.

### Pokédex
- Paginated list (50/page, infinite scroll) with search, generation, type, and sort filters
- Pokédex game filter — filters to a game's regional dex, sorts by regional entry number
- Adaptive layout: single column (< 600dp) → 2-col grid → 3-col grid (> 840dp) with view toggle
- Type-gradient tile backgrounds; adaptive images (icon / sprite / official artwork by breakpoint)
- Hero animation — sprite transitions from list to detail screen
- Detail tabs: Overview, Base Stats (animated bars), Abilities, Moves (version filter), Evolutions, Forms & Variants, Locations, Add to Team

### Reference Browsers
- Moves — search, damage-class filter, type filter; 2-column grid on tablet+; rich detail (type, stats, effect, contest data, TM/HM, Learned By)
- Items — search, pocket filter, sort; rich detail (sprite, fling, attributes, effect, Held By)
- Abilities — search, generation filter, sort; rich detail (effect history, Pokémon list)
- Types — full 18×18 type effectiveness matrix
- Natures — all 25 natures with +/− stat columns
- Locations — browse by region; location detail with area accordion, version filter, and encounter table

### Team Builder
- Folder hierarchy — create/rename/delete folders; collapsible sections; team count badge
- Teams list with folder grouping and drag-to-folder
- Create / rename / delete / duplicate teams; move team to folder
- Team detail — full-width slot cards with sprite, nickname/species, type badges, level, gender, item, ability, nature, stat bars, and move strip
- Slot Config — ability cards, nature dropdown, held item picker, 4 move slots, EV/IV grids, level slider, shiny toggle, gender picker, friendship slider; stat preview recalculates in real time
- Pokémon Showdown import (paste → team + slots) and export (file write + clipboard)
- Drag-reorder for slots, teams, and folders
- Team list card shows 6 mini sprites (Poké Ball for empty slots)
- Favorites — star button on list tile, detail header, and slot config; filter chip in Pokédex

### Format Engine
- 32 formats (Gen 1–9 general + 22 mainline games) with full gen-gating
- Gen-appropriate mechanics: abilities/nature hidden Gen 1–2; held item/shiny hidden Gen 1; EVs renamed "Stat Exp" Gen 1–2; DVs (max 15) for Gen 1–2; Gen 1 shows 5 stats
- Gen-aware sprites: PS transparent sprites Gen 1–5 (animated GIFs for Gen 5); HOME/official art Gen 6+; toggle in Settings
- Move picker filtered by format version groups; illegal moves/abilities/items flagged in validation
- Slot picker pre-seeded with generation/game filter when team has a format

### Generation Gimmicks
- Mega Evolution — held Mega Stone swaps sprite, recalculates stats; `is_mega_evolved` flag
- Z-Moves — Z-crystal → Z-move display next to each move; exclusive Z-moves shown when base move present
- Dynamax / Gigantamax — Max Move shown per move; G-Max toggle swaps sprite; `gigantamax_enabled` flag
- Alpha — `is_alpha` flag for Legends: Arceus formats

### Pokémon Instances
- `pokemon_instances` table — `parent_instance_id` self-ref chain; nickname aliases; inherited ribbons
- Link UI in Slot Config — origin vs child type chooser; chain view with ancestor/descendant badges; copy-to-team-slot picker
- Data inheritance — ribbons merged from chain; "Previously known as" alias shown; gender/shiny propagated to child slots
- Chain row navigation — tapping any row navigates to that slot's Slot Config screen

### Slot Config Extras
- Ribbons — full catalog by category (League, Contest, Tower, Memorial, Gift, Special); JSON column on `team_slots`
- Contest stats — 6 sliders (Coolness/Beautifulness/Cuteness/Cleverness/Toughness/Sheen); radar/spider chart via `fl_chart`; visible for Gen 3/4 and no-format
- Event/gift movesets — surfaced in details and used in move legality validation

### Backend & Sync
- FastAPI + PostgreSQL backend; Alembic migrations; JWT auth
- Offline-first sync engine — push queue (drains on connect, skips after 5 failures) + pull with last-write-wins on `updated_at`
- Soft-delete propagation across devices; folder delete cascades to teams + slots
- Sync status indicators — pending dot + error badge on team tiles
- Connectivity status button on every AppBar; auto-sync on login and on network return
- Pull-to-refresh (mobile) and compact sync bar (desktop)
- WorkManager 1-hour background sync (non-web)
- `POST /sync/push` batch endpoint

### Platform & CI/CD
- Android (minSdk 24), Windows MSI + EXE installer, Web (Firebase Hosting)
- CI: Firebase Hosting deploy on push to `main` or tag; APK + Windows builds + Docker image on tag
- System tray — minimize to tray on Windows/macOS/Linux; tray icon with quick-sync and quit
- Adaptive navigation: bottom bar (< 600dp) / rail (600–840dp) / permanent drawer (> 840dp)
- Dark / Light / System theme toggle + 9 accent colour presets; both persist via Drift
- Accessibility: semantic labels, 48×48 dp touch targets, text-scaling audit, screen-reader tab order
- Skeleton loading states, floating snackbars, hero animations, haptic feedback
