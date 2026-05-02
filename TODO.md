# PokeTeamDex Implementation TODO

This file converts `PokeTeamDex_PRD.md` + `PokeTeamDex_PRD_learning.md` into an actionable build plan.

## Rules of Execution

- Refactor/delete existing code freely when it speeds up clean architecture.
- Build in small vertical slices; keep the app runnable at the end of each slice.
- Prefer simple implementations that satisfy PRD requirements exactly.
- Offline-first is non-negotiable for teams/folders/slots.
- Keep PokéAPI usage cached to respect rate limits.

## Recommended Build Order

## Phase 0 - Reset and Baseline

- [ ] Decide reset strategy:
  - [ ] Minimal reset (keep app shell, replace features), or
  - [ ] Full reset (replace most `lib/` and rebuild cleanly).
- [ ] Keep `main.dart` bootstrapping only (theme + router + providers).
- [ ] Create/verify top-level structure:
  - [ ] `lib/features/`
  - [ ] `lib/services/`
  - [ ] `lib/shared/`
  - [ ] `lib/router/`
- [ ] Confirm app launches on your main target platform.

## Phase 1 - Project Scaffolding

- [ ] Add/verify dependencies:
  - [ ] `flutter_riverpod` (or `bloc`)
  - [ ] `go_router`
  - [ ] `dio`
  - [ ] `hive_flutter`
  - [ ] `drift` + `drift_dev` + sqlite runtime
  - [ ] `cached_network_image`
  - [ ] `connectivity_plus`
  - [ ] `workmanager` (or `flutter_background_service`)
- [ ] Router shell with tabs:
  - [ ] Pokedex
  - [ ] Moves
  - [ ] Items
  - [ ] Reference
  - [ ] My Teams
- [ ] Global theme:
  - [ ] Dark mode first
  - [ ] Type color palette constants
- [ ] Shared UI primitives:
  - [ ] Type badge
  - [ ] Sprite image widget
  - [ ] Empty/loading/error states

## Phase 2 - PokéAPI Service + Cache

- [ ] Build `services/pokeapi/`:
  - [ ] HTTP client with base URL + timeout + logging interceptor
  - [ ] Endpoints for pokemon/species/evolution/moves/items/types/natures/locations
- [ ] Build Hive cache layer:
  - [ ] Cache key strategy
  - [ ] TTL policy (24h list, 7d static)
  - [ ] Read-through pattern
- [ ] First-launch prefetch:
  - [ ] `/pokemon?limit=10000&offset=0`
- [ ] Add manual cache refresh trigger.

## Phase 3 - Pokédex Feature

- [ ] Pokémon list:
  - [ ] Name + dex number search
  - [ ] Filters (generation, game, type, sort)
  - [ ] Cached sprites and type badges
- [ ] Pokémon detail:
  - [ ] Overview
  - [ ] Base Stats + BST + level 50/100 ranges
  - [ ] Abilities
  - [ ] Moves (grouped)
  - [ ] Evolutions
  - [ ] Forms & variants
  - [ ] Locations
  - [ ] Add to Team action

## Phase 4 - Reference Browsers

- [ ] Moves list + detail
- [ ] Abilities list + detail
- [ ] Items list + detail
- [ ] Types chart + type detail
- [ ] Natures table (25 natures + neutral flags)
- [ ] Locations browser + detail

## Phase 5 - Local Data Model (Drift)

- [ ] Implement local tables mirroring server schema:
  - [ ] `team_folders`
  - [ ] `teams`
  - [ ] `team_slots`
- [ ] Add local-only tables:
  - [ ] `pending_sync_ops`
  - [ ] `meta` (`last_pull_timestamp`, `device_id`)
- [ ] Add `sync_status` field behavior (`synced|pending|error`) for local records.
- [ ] Repository layer around Drift (no direct DB calls in UI).

## Phase 6 - Team Builder UI

- [ ] Team List:
  - [ ] Folder sections (single-level nesting)
  - [ ] Team cards with 6 slot visuals
  - [ ] Folder/team CRUD + move + duplicate + reorder
- [ ] Team Detail:
  - [ ] Editable team name/format
  - [ ] 6 slots with drag reorder
  - [ ] Slot summary cards
  - [ ] Export button
- [ ] Slot Config:
  - [ ] Species/form selection
  - [ ] Shiny, gender, nickname, level, friendship
  - [ ] Ability, nature, held item
  - [ ] 4 moves
  - [ ] EV/IV editors + validation
  - [ ] Real-time stat preview (Gen III+ formula)

## Phase 7 - Backend + Sync

- [ ] Build backend REST API with API key auth:
  - [ ] Folder/team/slot CRUD
  - [ ] Reorder endpoints
  - [ ] `/sync/push`
  - [ ] `/sync/pull?since=...`
- [ ] PostgreSQL schema:
  - [ ] Sync columns (`updated_at`, `local_id`, `is_deleted`)
  - [ ] Soft delete behavior
- [ ] Sync engine in app:
  - [ ] Queue local writes to `pending_sync_ops`
  - [ ] FIFO push with retries (max 10)
  - [ ] Pull then merge with last-write-wins
  - [ ] Connectivity + foreground + pull-to-refresh triggers
  - [ ] Background sync schedule (mobile)

## Phase 8 - Offline UX + Polish

- [ ] Offline banner on My Teams
- [ ] Unsynced badge on affected teams
- [ ] Sync status timestamp in UI
- [ ] Sync error surfacing/retry actions
- [ ] Showdown export formatting
- [ ] EV/IV hard validation on save
- [ ] Performance pass (avoid unnecessary spinners for cached data)

## Phase 9 - Testing and Stability

- [ ] Widget tests for key screens
- [ ] Integration tests:
  - [ ] Team/folder/slot CRUD
  - [ ] Offline edits then online sync
  - [ ] Conflict merge behavior
- [ ] Manual verification on:
  - [ ] Android
  - [ ] iOS
  - [ ] Web

## Immediate Next Steps (Do These First)

- [ ] Pick Riverpod or Bloc (recommendation: Riverpod for faster setup).
- [ ] Pick backend stack (recommendation: FastAPI for speed and typed models).
- [ ] Create clean folder structure in `lib/`.
- [ ] Replace current navigation with 5-tab shell via `go_router`.
- [ ] Build PokéAPI client + cache foundation before feature screens.

## Mentor-Style Workflow (from Learning PRD)

Use this loop for every task:

1. Choose one smallest unit of work (single file/class/method/table).
2. Implement it.
3. Run app/tests quickly.
4. Self-check against PRD acceptance points.
5. Move to the next smallest unit.

If you want, I can now guide you one exact step at a time and review each step before you continue.
