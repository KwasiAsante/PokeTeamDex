# Changelog

All notable changes to PokeTeamDex are documented here.

---

## [1.1.1] — 2026-07-11

### Added

- Slot Config now defaults Friendship to max (255) instead of 0 for new/unset slots (closes #228) — matches Showdown's own convention of treating an omitted `Happiness:` line as 255

### Fixed

- Form chip selector was silently disappearing for species whose only real alternate variety is its first/sole entry in the backend's variety list (Toxtricity-Low-Key, Giratina-Origin) — `filterFormChips` assumed the default form is always the first element so it could skip it, but the backend's `/resolved` endpoint never includes the default variety at all, so the real form was being dropped in its place
- CI: `notify-backend` release job referenced `needs.create-release.outputs.tag` without declaring `create-release` in its own `needs:` list, so the v1.1.0 release notification went out with an empty version/URL instead of the real tag

---

## [1.1.0] — 2026-07-11

### Added

- **Backend-driven move/item/ability catalog + gen-accurate learnsets** (closes investigation #276) — `shared/ps_data/` is now the single source of truth for PS-derived data (moves, items, abilities, pokedex overrides, per-generation `learnset_1.json`–`learnset_9.json`), generated straight from Pokémon Showdown's TypeScript source instead of the lossy compiled `learnsets.json` endpoint; new backend `LearnsetService` and `CatalogService` back `GET /moves`, `GET /items`, `GET /abilities` (+ single-entry variants) and a gen-aware `?gen=N` filter on `GET /pokemon/moves/{id}` and `/pokemon/{id}/resolved`, both PostgreSQL-cached (new `catalog_cache` table, 7-day TTL, same pattern as `pokemon_resolved`); Flutter's move/item/ability pickers and list/detail screens now go through a single `withBackendFallback` utility (backend cache → Hive cache → offline reconstruction from bundled PS data → error) instead of calling PokéAPI directly, and prior-evolution moves route through the backend correctly via new `viaPrev`/`prevo` fields on move learn details
- **Save All Teams** — folder overflow menu action that saves every team and box in a folder in one action (between "Import from Showdown" and "Rename"/"Delete"), with a live progress dialog and a matching best-effort PS export per team; stops and reports how many teams succeeded if a save fails partway through
- Showdown export now includes EVs' IVs on the correct scale (Gen 1/2 DVs doubled to PS's IV convention) and appends the Hidden Power type annotation (`Hidden Power [Ice]`)
- OpenAPI `summary=`, descriptions, and tag metadata added to every backend router so `/docs` and `/redoc` render a complete, grouped API reference

### Fixed

- **PS import was silently dropping or mis-storing several fields.** Nature was never captured on a real Showdown paste (parser matched a corrupted-data artifact instead of PS's actual `<Nature> Nature` syntax); Gigantamax, Tera Type, and Happiness lines weren't parsed on import or emitted on export at all; species names containing periods (`Mr. Rime`, `Mime Jr.`) failed to resolve; Gen 1/2 IVs weren't converted back to raw DVs on import (PS's file format always uses the doubled IV scale, even for Gen 1/2); fields that don't exist in the target generation (gender/nature/item/happiness/shiny/Gigantamax/Tera Type) are now stripped instead of stored blindly when they're present in a pasted export that doesn't match the team's format
- Showdown export no longer folds a gender-suffixed default variety (Pyroar, Jellicent) or a cosmetic gender-only form into the exported species name — gender is conveyed solely via the `(M)`/`(F)` tag, matching real PS output
- Box team exports to the configured PS teams directory now use a `[{format}-box]` filename prefix instead of `[{format}]`, distinguishing them from regular team exports
- "Save All" (team detail screen and the new folder-level action) now re-triggers the PS export instead of leaving the exported `.txt` file stale until an individual slot was saved again
- Female sprite fallback logic corrected on the Teams screen
- Backend catalog move/ability generation is now derived from PokéAPI instead of an unreliable PS field; Z-Move and Max Move generation forced to 7 and 8 respectively; removed a nonexistent `max_move_base` field and fixed `z_move_base` to populate from the Z-Crystal item instead of a move field that doesn't exist
- CI: Docker build context corrected to the project root to match the Dockerfile; `.env` now created from `.env.example` before Flutter builds so CI doesn't fail on a missing environment file

### Changed

- `dotenv` integrated for environment variable management, with `DEBUG_API_URL` support for pointing a debug build at a local backend
- 17 pre-existing test failures fixed as part of the catalog integration work (form chip default-form leak, `pokemon_registry.json` data integrity issues, mock response formats, an AppBar icon screen-width guard, and a Hive dependency leak in widget tests)

---

## [1.0.8] — 2026-06-20

### Added

- **Linux desktop support** — tar.gz, AppImage, and Flatpak packages now built and published to every GitHub Release alongside Windows/Android; tar.gz bundles a `.desktop` file, app icon, and `install.sh` for launcher integration; system tray works on Linux (`tray_manager` native libs bundled for tar.gz/AppImage, built from source via Flatpak `shared-modules` to avoid glib ABI mismatches)
- **Backend Pokémon data aggregation** — `GET /pokemon/{id}/resolved` combines PokéAPI + Showdown event learnsets + Smogon competitive sets into one 7-day-cached response, gen-aware (types/stats reflect the requested generation); dedicated `GET /pokemon/varieties`, `/forms`, `/smogon`, `/moves`, and `/flavor-text` endpoints for on-demand expansion without re-fetching the full resolved payload
- **Admin cache eviction** — `DELETE /admin/cache/pokemon` clears stale `pokemon_resolved` rows by ID or in full, so registry/sprite-override fixes show up immediately instead of waiting out the 7-day TTL
- Held Items category filter now hits the correct PokéAPI endpoint (see Fixed)

### Changed

- **Unified Pokémon data resolution layer** — new `PokemonDataResolver` (`lib/data/pokemon_data_resolver.dart`) and `PokemonDataRegistry` (backed by `assets/data/pokemon_registry.json`) consolidate sprite/form override maps that were previously duplicated across `form_data.dart`, `form_filter.dart`, `evolution_chain_builder.dart`, `mega_forms_data.dart`, and `sprite_resolver.dart`; `sprite_resolver.dart` is now a thin wrapper
- **Flutter hybrid data integration** — `PokemonEntry.types`/`stats`/`abilities`/`moves` are now typed (`List<String>`, `Map<String,int>`, `List<AbilityInfo>`, `List<MoveSummary>`) instead of raw JSON maps; `resolvedPokemonProvider` fetches Hive cache → backend → PokéAPI fallback with keepAlive caching; moves and flavor text in the detail screen and Slot Config now lazy-load through the backend
- **Provider hygiene audit** — memoized `fetchMove`/`fetchItem` in `PokeApiRepository` (mirrors the existing `fetchAbility` cache); consolidated duplicate per-screen ability/move/item detail providers (Slot Config, team detail) into the shared Pokédex-wide providers; Slot Picker now reads the cached `resolvedPokemonProvider` instead of issuing its own full detail fetch
- `pokemon_registry.json` gained `varietyIconIdOverrides` for icon resolution on specific Pokémon varieties

### Fixed

- Held Items filter 404s — `"held-items"` is a PokéAPI item *category* nested in the `misc` pocket, not a pocket itself; added `PokeApiRepository.fetchItemsByCategory` and routed the filter through it
- RenderFlex overflow on the Items tab's wide-layout loading skeleton (grid cell height was 2px short of the skeleton's minimum)
- Double navigation on startup — GoRouter was being constructed twice, firing the initial redirect twice
- Form-aware slot linking, sprites, and team list icons corrected for several form-switching edge cases
- Flatpak runtime upgraded to 24.08; library install paths corrected

---

## [1.0.7] — 2026-06-12

### Added

- **Form switching on Pokédex list screen** — form chip on every list tile and grid card that has switchable forms; tapping opens a bottom-sheet picker; covers battle-meaningful variety forms, cosmetic variety forms, and form-entry cosmetics; selecting a form updates the card's sprite, gradient, and display name in place
- **Hidden Power type in team detail move strip** — the inferred Hidden Power type is shown alongside the move name on the team card

### Fixed

- **Ability gen gating in Slot Config** — ability picker now filtered by format generation: hidden abilities suppressed for Gen 1–4 (Dream World didn't exist); abilities introduced after the format gen hidden via PokéAPI `generationName`; currently-selected ability always kept visible so the violation banner can explain any mismatch
- **Ribbon gen gating** — ribbon picker filtered by format generation; ribbons with a `minGen` higher than the team format's gen are hidden; no-format teams remain unrestricted
- Snackbar auto-dismiss restored; duration tiers added (short 2 s / medium 4 s / long 6 s)
- Unlink and remove now reset the instance link chain — orphaned descendants are relinked to the grandparent; chain view filters out orphaned ancestor nodes
- Instance chain `parent_instance_id` links now preserved across sync devices
- Hidden Power damage formula corrected for Gen 2 (uses the Gen 2 DV-based formula instead of the Gen 3+ IV-based formula)
- Regional forms gated by generation in the form chip filter
- Inherited ribbons excluded from the selectable ribbon catalog in Slot Config
- Slot and team deletions now propagate to the server on next sync
- Breeding moves no longer missing for Pokémon whose regional-form ancestor has extra moves
- PS-imported box no longer demoted to a regular team on sync
- Renaming a box no longer demotes it to a regular team
- Team ownership verified server-side before slot upsert/delete (sync push)
- Unown ! and ? forms hidden in Gen 1–2 formats (those forms were introduced in Gen 3)
- Gen 2 Pokémon Crystal sprite fallback URLs corrected

---

## [1.0.6] — 2026-06-09

### Fixed
- Update check errors now surfaced to the user instead of silently failing; FCM notification tap handler correctly opens the app on cold start
- Web: skip `opfsShared` strategy for cross-browser SQLite compatibility (fixes Firefox `NoModificationAllowedError`)
- Web: cross-origin isolation headers (COOP/COEP) added to Firebase Hosting config for stable SharedArrayBuffer support

---

## [1.0.5] — 2026-06-09

### Fixed
- Sort order no longer reverts after sync — `updateSortOrder` now bumps `updatedAt` so the local timestamp always beats the server's stale value on pull
- Teams/folders reordered before their first sync now land at the correct server position — create op reads current DB `sortOrder` instead of the always-zero payload value
- Folder name on mobile no longer renders vertically — `TextOverflow.ellipsis` prevents character-per-line wrapping when the trailing action row is wide
- Reorder arrows (↑ ↓ top/bottom) on folder headers and team tiles are hidden on narrow screens (< 600 dp) and moved into the `⋮` overflow menu instead; wide screens (tablet/desktop/web) keep the inline buttons

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
