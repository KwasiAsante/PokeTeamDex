# PokeTeamDex — Flutter App PRD

> **For AI Agent Use** | Version 1.0 | April 2026 | Status: Ready for implementation

---

## AGENT INSTRUCTIONS

You are implementing **PokeTeamDex**, a cross-platform Flutter app for private personal use. This document is the single source of truth. Follow every section precisely. When making architectural decisions not covered here, default to the simplest approach that satisfies the stated requirements. Ask no clarifying questions — use this document and proceed.

**Tech stack summary:**

- Frontend: Flutter (latest stable), targeting iOS, Android, Web
- Local DB: Drift (SQLite) — offline-first store for teams/folders/slots
- Remote DB: PostgreSQL (self-hosted or managed e.g. Supabase/Neon)
- Backend: Lightweight REST API (Node/Express or FastAPI) with API key auth
- External data: PokéAPI (`https://pokeapi.co/`) — read-only, locally cached
- State management: Riverpod or Bloc
- Navigation: go_router
- HTTP: Dio with interceptors
- Images: cached_network_image
- Sync: connectivity_plus + WorkManager/flutter_background_service

---

## 1. PRODUCT OVERVIEW

### 1.1 Vision

PokeTeamDex combines a full Pokédex browser with a persistent, offline-first team builder. All Pokémon data comes from PokéAPI. Teams are stored locally in SQLite and synced to PostgreSQL so they are accessible and editable from any device.

### 1.2 Inspiration

- **Pokémon Showdown Team Builder** (`https://play.pokemonshowdown.com/teambuilder`) — team UX, moveset config, competitive data layout
- **DataDex Pokédex** — clean mobile Pokédex browsing, filtering, detail pages

### 1.3 Core Goals

1. Browse every Pokémon from every generation across all main-series games with rich detail pages
2. Browse all moves, abilities, items, types, natures, and locations from PokéAPI
3. Create and manage unlimited named Pokémon teams organized in subfolders
4. Configure each team slot: moveset, nature, ability, held item, nickname, gender, shiny, EVs, IVs, level
5. Persist all team data in PostgreSQL accessible from every platform
6. Support full offline use — teams/folders fully readable and editable with no connection; sync automatically when connectivity is restored

---

## 2. SCOPE & CONSTRAINTS

### 2.1 In Scope

- Full Pokédex browsing backed by PokéAPI (all generations, all games)
- Move, ability, item, type, nature, and location browsers
- Team builder — unlimited teams, 1–6 Pokémon per team, organized in named subfolders
- Per-Pokémon team slot configuration (see Section 6)
- **Offline-first team builder** — full read/write with no internet connection
- **Automatic background sync** — local changes sync to PostgreSQL when connectivity returns
- **Conflict resolution** — last-write-wins on `updated_at`; UI surface for sync errors
- Team persistence via PostgreSQL with a lightweight backend API
- Cross-platform: iOS, Android, Web (Flutter targets)
- Offline Pokédex browsing via local Hive cache of PokéAPI responses

### 2.2 Out of Scope

- Real-time battle simulation
- Multi-user accounts or public team sharing
- In-app purchases or monetization
- Pokémon GO data
- Fan-made or fangame Pokémon

### 2.3 Technical Constraints

| Constraint         | Details                                                                          |
| ------------------ | -------------------------------------------------------------------------------- |
| PokéAPI rate limit | 100 req/IP/min — implement local caching; never re-fetch cached data             |
| PokéAPI coverage   | All official games up to Scarlet/Violet                                          |
| Database           | PostgreSQL — self-hosted or managed (Supabase, Neon, Railway)                    |
| Auth               | Single-user private app; API key header (`X-API-Key`) is sufficient              |
| Offline store      | Drift (SQLite) for teams/folders local DB; mirrors server schema                 |
| Sync strategy      | Optimistic local writes + background sync queue; last-write-wins on `updated_at` |
| Flutter version    | Latest stable at time of development                                             |

---

## 3. SYSTEM ARCHITECTURE

### 3.1 Layers

1. **Flutter Client** — all UI, local Drift/SQLite store, sync engine, API communication
2. **Local SQLite (Drift)** — mirrors all team/folder/slot data; source of truth while offline
3. **Backend REST API** — lightweight server; reads/writes to PostgreSQL; exposes sync endpoints
4. **PostgreSQL** — authoritative remote store for teams, folders, slots

### 3.2 Data Flow

| Action                               | Flow                                                                 |
| ------------------------------------ | -------------------------------------------------------------------- |
| Browse Pokédex, moves, items, etc.   | PokéAPI → local Hive cache (read-through)                            |
| View teams/folders (online)          | Local Drift DB — synced from server on app open                      |
| View teams/folders (offline)         | Local Drift DB directly — no network needed                          |
| Create/edit/delete team or slot      | Write to Drift first → enqueue sync op → push to backend when online |
| App comes online after offline edits | Sync engine drains queue → API calls → resolve conflicts             |
| Another device changes a team        | On foreground: pull server state → merge into local Drift            |

### 3.3 Flutter Package Recommendations

| Purpose                 | Package                                               |
| ----------------------- | ----------------------------------------------------- |
| HTTP / PokéAPI calls    | `dio` or `http`                                       |
| PokéAPI local cache     | `hive_flutter`                                        |
| Local team DB (offline) | `drift` (SQLite) — mirrors teams/folders/slots schema |
| State management        | `riverpod` or `bloc`                                  |
| Navigation              | `go_router`                                           |
| Images                  | `cached_network_image`                                |
| Search & filter         | `flutter_typeahead`                                   |
| Sync / connectivity     | `connectivity_plus`                                   |
| Background sync         | `workmanager` or `flutter_background_service`         |
| Sync queue              | Drift table (`pending_sync_ops`)                      |

### 3.4 Suggested Folder Structure

```text
lib/
  features/
    pokedex/          # Pokémon list, detail, sub-screens
    moves/            # Move list and detail
    abilities/        # Ability list and detail
    items/            # Item list and detail
    reference/        # Types chart, natures table, locations
    teams/            # Team list, folder UI, team detail, slot config
  services/
    pokeapi/          # PokéAPI HTTP service + Hive cache + response models
    backend/          # REST API service: teams/folders CRUD + sync push/pull
    sync/             # Sync engine: queue, conflict resolution, connectivity listener
  shared/
    widgets/          # Type badges, stat bars, sprite widgets, etc.
    theme/            # Colors, text styles, type colour palette
  router/             # go_router configuration
```

---

## 4. FEATURE: POKÉDEX BROWSER

### 4.1 Pokémon List Screen

- Sprite thumbnail (official artwork from PokéAPI)
- National Pokédex number, name, type badges (colour-coded per type, up to 2)
- Search bar — by name or Pokédex number
- Filters: Generation (Gen I–IX), Game version, Type (single or dual), Sort (Dex number / name / BST)

### 4.2 Pokémon Detail Screen

Tabs or scrollable sections:

#### 4.2.1 Overview

- Full official artwork + shiny sprite toggle
- National Dex #, name, genus (e.g. "Mouse Pokémon")
- Generation & region of origin
- Type badges
- Pokédex entries from multiple games (scrollable)
- Height, weight, base experience, capture rate, base happiness, growth rate
- Egg groups, hatch time (steps), gender ratio

#### 4.2.2 Base Stats

- Bar chart: HP, Attack, Defense, Sp. Atk, Sp. Def, Speed
- Base Stat Total
- Min/max stat values at level 50 and level 100

#### 4.2.3 Abilities

- All abilities (1–2 regular + 1 hidden ability)
- Name, short effect, full description
- Tap → navigate to Ability Detail screen

#### 4.2.4 Moves

- Grouped by: Level Up, TM/HM, Egg Moves, Tutor
- Filter by game version
- Columns: Name, Type, Category (Physical/Special/Status), Power, Accuracy, PP
- Tap → navigate to Move Detail screen

#### 4.2.5 Evolutions

- Full evolution chain with sprites and evolution conditions
- Tap any Pokémon in chain → navigate to its detail page

#### 4.2.6 Forms & Variants

- Regional forms (Alolan, Galarian, Hisuian, Paldean), Mega Evolutions, Gigantamax, other alternates
- Sprites and stat differences per form

#### 4.2.7 Locations

- All locations where the Pokémon can be found, filtered by game version
- Method (Walking, Fishing, Surfing, etc.) and encounter rate

#### 4.2.8 Add to Team

- FAB or prominent button to add this Pokémon to any existing team or a new team

---

## 5. FEATURE: REFERENCE DATA BROWSERS

### 5.1 Moves Browser

- List all moves: name, type badge, category icon, power, accuracy, PP
- Search by name; filter by type, damage category, generation
- **Move Detail:** name, type, category, power, accuracy, PP, effect, description, contest info, Pokémon that learn it

### 5.2 Abilities Browser

- List all abilities with name and short effect
- Search; filter by generation
- **Ability Detail:** name, generation introduced, short/long effect, Pokémon with this ability (normal vs hidden)

### 5.3 Items Browser

- Categories: Held Items, Berries, Medicines, Poké Balls, TMs/HMs, Key Items, etc.
- Search by name; filter by category and pocket
- **Item Detail:** name, category, effect, fling power/effect, held item attributes; sprite/icon

### 5.4 Types Browser

- Visual type effectiveness chart (18×18 grid)
- **Type Detail:** offensive and defensive matchups, Pokémon of that type, moves of that type

### 5.5 Natures Browser

- Table of all 25 natures
- Columns: Name, Increased Stat (+10%), Decreased Stat (−10%), Favoured Flavour, Disliked Flavour
- Neutral natures (Bashful, Docile, Hardy, Quirky, Serious) clearly indicated

### 5.6 Locations Browser

- Browse by region and game
- **Location Detail:** region, areas within, wild Pokémon encounters, game versions

---

## 6. FEATURE: TEAM BUILDER

### 6.1 Team List Screen

#### 6.1.1 Folder Structure

- Teams can be placed in named **subfolders** (e.g. "Competitive", "Gen IV", "Casual")
- Folders displayed as collapsible sections; uncategorised teams shown in a default root section
- One level of nesting only (folder → teams; no folder-in-folder)
- Folder header: name, team count badge, expand/collapse chevron
- **Create New Folder** button alongside Create New Team
- Long-press/swipe folder: rename, delete (teams move to uncategorised on delete), reorder
- Drag-and-drop teams between folders

#### 6.1.2 Team Cards

- Shows: team name, game/format label, row of 6 sprites (Poké Ball for empty slots)
- Long-press/swipe: rename, duplicate, move to folder, delete
- Tap → open Team Detail screen

### 6.2 Team Detail Screen

- Team name (editable inline), optional game/format label
- 6 Pokémon slots — empty slots show a `+` button
- Each filled slot summary card: sprite (shiny if flagged), nickname, species, held item icon, type badges, nature, ability, 4 move names
- Tap slot → open Slot Configuration screen
- Drag-and-drop to reorder slots
- Save / auto-save
- **Export** button → Pokémon Showdown text format (see Section 11.3)

### 6.3 Slot Configuration Screen

All fields optional except species.

#### 6.3.1 Pokémon Selection

- Search/select species from full Pokédex
- Select form/variant if applicable
- Shiny toggle (renders shiny sprite everywhere)
- Gender (Male / Female / Genderless — respects species gender ratio)

#### 6.3.2 Basics

- Nickname — free text, max 12 characters
- Level — 1–100, default 50
- Friendship/Happiness — 0–255, default species base happiness

#### 6.3.3 Ability

- Dropdown of all valid abilities for selected species/form
- Labels: Ability 1, Ability 2, Hidden Ability

#### 6.3.4 Nature

- Dropdown of all 25 natures
- Shows boosted (+) and reduced (−) stats inline
- Neutral natures labelled

#### 6.3.5 Held Item

- Searchable dropdown of all hold items from PokéAPI
- Item sprite shown; item effect shown as sub-text or tooltip

#### 6.3.6 Moves

- 4 move slots
- Each: searchable dropdown filtered to moves the Pokémon can learn (toggle for all moves)
- Shows: type badge, category icon, power, accuracy, PP
- Tap move name → Move Detail overlay

#### 6.3.7 EVs (Effort Values)

- 6 sliders or numeric inputs: HP, Atk, Def, SpA, SpD, Spe
- Each: 0–252; total must not exceed 510
- Running total shown; excess highlighted red

#### 6.3.8 IVs (Individual Values)

- 6 inputs: 0–31 each, default 31
- Hidden Power type calculator based on IVs (for older gens)

#### 6.3.9 Stat Preview

- Real-time calculated final stats at selected level using standard Gen III+ formula
- Bar chart updating live as user changes EVs, IVs, nature, level

---

## 7. FEATURE: OFFLINE MODE & SYNC

### 7.1 Offline-First Principle

Teams, folders, and slot configurations are **always read from and written to the local Drift/SQLite database first**. The app is fully usable with no internet connection. PostgreSQL is a sync target, not a runtime dependency.

### 7.2 Sync Triggers

- **App foreground**: pull remote changes since last sync timestamp, then push pending local ops
- **Connectivity restored**: `connectivity_plus` detects network return → trigger full sync cycle immediately
- **Pull-to-refresh**: on Team List screen → force full sync
- **Background (mobile only)**: WorkManager attempts sync every 15 minutes while backgrounded

### 7.3 Sync Flow (Ordered Steps)

1. User makes a local change (create/edit/delete) → write to Drift DB immediately → UI updates optimistically
2. Insert a row into `pending_sync_ops` describing the change
3. When online, sync engine reads `pending_sync_ops` in FIFO order
4. For each op, call the relevant backend endpoint. On HTTP 2xx → delete the op row
5. On failure → increment `retry_count`. After 10 failures → mark as error, surface in UI
6. After pushing all ops → call `GET /sync/pull?since=<last_pull_timestamp>` to fetch remote changes
7. Merge pulled records into local Drift using last-write-wins on `updated_at`

### 7.4 Conflict Resolution

- **Strategy**: last-write-wins on `updated_at` timestamp
- If `server.updated_at > local.updated_at` → server record wins; overwrite local
- If `local.updated_at > server.updated_at` → local record wins; will be pushed on next sync
- **Soft deletes**: set `is_deleted = true` and bump `updated_at`; propagates to all devices via normal sync. Hard delete after all clients acknowledge
- **UI**: if `retry_count >= 3`, show warning badge on affected team card: "Sync issue — tap to retry"

### 7.5 Offline UI Behaviour

- Persistent offline banner at top of My Teams screen when offline: *"You are offline — changes will sync when reconnected"*
- All team/folder CRUD remains fully available offline
- Pending unsynced changes shown as a small dot/badge on affected team card
- Sync status (last synced timestamp) shown in Team List header or app settings

---

## p8. DATABASE SCHEMA (PostgreSQL)

> All server tables include `is_deleted BOOLEAN DEFAULT false` and `local_id TEXT` for sync. `local_id` is a client-generated UUID assigned before the server confirms creation. Used to match local↔remote records.

### 8.1 `team_folders`

| Column       | Type             | Notes                                                |
| ------------ | ---------------- | ---------------------------------------------------- |
| `id`         | UUID / SERIAL PK | Primary key                                          |
| `name`       | TEXT NOT NULL    | Folder display name                                  |
| `sort_order` | INT NOT NULL     | Display order among folders, default 0               |
| `is_deleted` | BOOLEAN          | Soft-delete flag for sync                            |
| `local_id`   | TEXT             | Client-generated UUID                                |
| `created_at` | TIMESTAMPTZ      | Auto-set on insert                                   |
| `updated_at` | TIMESTAMPTZ      | Auto-updated on modify; used for conflict resolution |

### 8.2 `teams`

| Column         | Type                 | Notes                                                |
| -------------- | -------------------- | ---------------------------------------------------- |
| `id`           | UUID / SERIAL PK     | Primary key                                          |
| `folder_id`    | FK → team_folders.id | NULL = uncategorised; ON DELETE SET NULL             |
| `name`         | TEXT NOT NULL        | Team name                                            |
| `format_label` | TEXT                 | e.g. "VGC 2025", "Gen IV OU"                         |
| `sort_order`   | INT NOT NULL         | Display order within folder/root, default 0          |
| `is_deleted`   | BOOLEAN              | Soft-delete flag for sync                            |
| `local_id`     | TEXT                 | Client-generated UUID                                |
| `created_at`   | TIMESTAMPTZ          | Auto-set on insert                                   |
| `updated_at`   | TIMESTAMPTZ          | Auto-updated on modify; used for conflict resolution |

### 8.3 `team_slots`

| Column           | Type             | Notes                                                |
| ---------------- | ---------------- | ---------------------------------------------------- |
| `id`             | UUID / SERIAL PK | Primary key                                          |
| `team_id`        | FK → teams.id    | ON DELETE CASCADE                                    |
| `slot_index`     | SMALLINT         | 0–5, position in team                                |
| `species_id`     | INT NOT NULL     | PokéAPI Pokémon ID                                   |
| `form_name`      | TEXT             | PokéAPI form name if alternate form                  |
| `nickname`       | TEXT             | Max 12 chars                                         |
| `level`          | SMALLINT         | 1–100                                                |
| `gender`         | TEXT             | `'male'`, `'female'`, `'genderless'`                 |
| `is_shiny`       | BOOLEAN          | Default false                                        |
| `ability_name`   | TEXT             | PokéAPI ability name                                 |
| `nature_name`    | TEXT             | PokéAPI nature name                                  |
| `held_item_name` | TEXT             | PokéAPI item name                                    |
| `friendship`     | SMALLINT         | 0–255                                                |
| `move_1`         | TEXT             | PokéAPI move name                                    |
| `move_2`         | TEXT             | PokéAPI move name                                    |
| `move_3`         | TEXT             | PokéAPI move name                                    |
| `move_4`         | TEXT             | PokéAPI move name                                    |
| `ev_hp`          | SMALLINT         | 0–252                                                |
| `ev_atk`         | SMALLINT         | 0–252                                                |
| `ev_def`         | SMALLINT         | 0–252                                                |
| `ev_spa`         | SMALLINT         | 0–252                                                |
| `ev_spd`         | SMALLINT         | 0–252                                                |
| `ev_spe`         | SMALLINT         | 0–252                                                |
| `iv_hp`          | SMALLINT         | 0–31, default 31                                     |
| `iv_atk`         | SMALLINT         | 0–31, default 31                                     |
| `iv_def`         | SMALLINT         | 0–31, default 31                                     |
| `iv_spa`         | SMALLINT         | 0–31, default 31                                     |
| `iv_spd`         | SMALLINT         | 0–31, default 31                                     |
| `iv_spe`         | SMALLINT         | 0–31, default 31                                     |
| `updated_at`     | TIMESTAMPTZ      | Auto-updated on modify; used for conflict resolution |
| `is_deleted`     | BOOLEAN          | Soft-delete flag for sync                            |

### 8.4 `pending_sync_ops` (local Drift/SQLite only)

> This table exists **only in the Flutter local database**. Never on the server.

| Column            | Type          | Notes                                    |
| ----------------- | ------------- | ---------------------------------------- |
| `id`              | INTEGER PK    | Auto-increment                           |
| `op_type`         | TEXT NOT NULL | `'create'`, `'update'`, `'delete'`       |
| `entity_type`     | TEXT NOT NULL | `'folder'`, `'team'`, `'slot'`           |
| `entity_local_id` | TEXT NOT NULL | `local_id` of the affected record        |
| `payload`         | TEXT (JSON)   | Full serialised entity at time of change |
| `created_at`      | TIMESTAMPTZ   | When the local change was made           |
| `retry_count`     | INT           | Failed sync attempts; give up after 10   |
| `last_error`      | TEXT          | Last server error message for debugging  |

---

## 9. BACKEND API ENDPOINTS

All routes protected by `X-API-Key` header. Single-user private app — no user accounts needed.

| Method | Endpoint                   | Description                                                                     |
| ------ | -------------------------- | ------------------------------------------------------------------------------- |
| GET    | `/folders`                 | List all folders with team counts                                               |
| POST   | `/folders`                 | Create a new folder                                                             |
| PATCH  | `/folders/:id`             | Rename or reorder a folder                                                      |
| DELETE | `/folders/:id`             | Soft-delete folder; teams → uncategorised                                       |
| PATCH  | `/folders/reorder`         | Reorder folders (send ordered folder IDs)                                       |
| GET    | `/teams`                   | List all teams; filter with `?folder_id=`                                       |
| POST   | `/teams`                   | Create a new team (include `folder_id` or null)                                 |
| GET    | `/teams/:id`               | Get team + all slots                                                            |
| PATCH  | `/teams/:id`               | Update team name, format, or `folder_id`                                        |
| DELETE | `/teams/:id`               | Soft-delete team and all slots                                                  |
| POST   | `/teams/:id/slots`         | Add a slot to a team                                                            |
| PUT    | `/teams/:id/slots/:slotId` | Replace full slot config                                                        |
| PATCH  | `/teams/:id/slots/:slotId` | Partial update a slot                                                           |
| DELETE | `/teams/:id/slots/:slotId` | Soft-delete a slot                                                              |
| PATCH  | `/teams/:id/reorder`       | Reorder slots (send ordered slot IDs)                                           |
| POST   | `/sync/push`               | Batch push: array of local ops (create/update/delete) for folders, teams, slots |
| GET    | `/sync/pull`               | Batch pull: all records with `updated_at > ?since=<ISO timestamp>`              |

---

## 10. POKEAPI INTEGRATION

### 10.1 Key Endpoints

| Data             | PokéAPI Endpoint                       |
| ---------------- | -------------------------------------- |
| Pokémon list     | `/pokemon?limit=10000&offset=0`        |
| Pokémon detail   | `/pokemon/{id or name}`                |
| Pokémon species  | `/pokemon-species/{id or name}`        |
| Evolution chains | `/evolution-chain/{id}`                |
| Moves            | `/move`, `/move/{id or name}`          |
| Abilities        | `/ability`, `/ability/{id or name}`    |
| Items            | `/item`, `/item/{id or name}`          |
| Types            | `/type`, `/type/{id or name}`          |
| Natures          | `/nature`, `/nature/{id or name}`      |
| Locations        | `/location`, `/location/{id or name}`  |
| Location areas   | `/location-area/{id or name}`          |
| Games / versions | `/version`, `/version-group`           |
| Generations      | `/generation/{id or name}`             |
| Pokémon forms    | `/pokemon-form/{id or name}`           |
| Sprites          | Returned inline in `/pokemon` response |

### 10.2 Sprite Paths

```text
Official artwork:  pokemon.sprites.other['official-artwork'].front_default
Shiny artwork:     pokemon.sprites.other['official-artwork'].front_shiny
Default sprite:    pokemon.sprites.front_default
Shiny sprite:      pokemon.sprites.front_shiny
```

### 10.3 Caching Strategy

- All PokéAPI responses cached locally in Hive
- Cache TTL: 7 days for static data (moves, natures, types); 24 hours for Pokémon lists
- On first launch: prefetch full Pokémon name/ID list (`/pokemon?limit=10000`) for instant search
- Detailed data (stats, moves, etc.) fetched on demand and cached
- Manual refresh available in app settings

### 10.4 Pagination Note

Use `?limit=10000&offset=0` to fetch complete lists in one call. Safe for caching. Example:

```text
GET https://pokeapi.co/api/v2/pokemon?limit=10000&offset=0
```

---

## 11. UI / UX GUIDELINES

### 11.1 Navigation (Bottom Tabs)

| Tab       | Screens                                                      |
| --------- | ------------------------------------------------------------ |
| Pokédex   | Pokémon List → Detail → (Move / Ability / Location overlays) |
| Moves     | Move List → Move Detail                                      |
| Items     | Item List → Item Detail                                      |
| Reference | Types Chart, Natures Table, Abilities List, Locations        |
| My Teams  | Team List (with folders) → Team Detail → Slot Config         |

### 11.2 Design Principles

- **Dark mode first** — support system dark/light toggle
- **Type colours** — use official type colour palette consistently for badges, charts, detail pages
- **Sprites** — official artwork on detail pages; smaller sprites in lists and team views
- **Responsive** — phone (360dp min), tablet, and desktop web
- **Fast** — browsing feels instant via caching; no loading spinners for cached data
- **Offline clarity** — always make offline state obvious; never silently fail

### 11.3 Showdown Export Format

```text
{Nickname} ({Species}) @ {Held Item}
Ability: {Ability}
Level: {Level}
Shiny: Yes   ← omit line if not shiny
Nature: {Nature}
EVs: {ev_hp} HP / {ev_atk} Atk / {ev_def} Def / {ev_spa} SpA / {ev_spd} SpD / {ev_spe} Spe
- {Move 1}
- {Move 2}
- {Move 3}
- {Move 4}
```

Omit EV values of 0. If nickname equals species name, output just the species name (no parentheses).

---

## 12. STAT FORMULA (Gen III+)

Use for real-time Stat Preview in Slot Config screen.

```text
HP  = floor(((2 × Base + IV + floor(EV / 4)) × Level / 100) + Level + 10)

Other stats = floor(
  floor(((2 × Base + IV + floor(EV / 4)) × Level / 100) + 5)
  × NatureModifier
)

NatureModifier:
  1.1  if stat is boosted by nature
  0.9  if stat is reduced by nature
  1.0  if neutral
```

---

## 13. DEVELOPMENT MILESTONES

| Phase | Milestone           | Key Deliverables                                                                                                       |
| ----- | ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| 1     | Project Scaffolding | Flutter project, folder structure, routing, theme, PokéAPI service layer, Hive cache setup                             |
| 2     | Pokédex Browser     | Pokémon list + search/filter, all 8 detail tabs, sprites, evolution chain                                              |
| 3     | Reference Browsers  | Moves, abilities, items, types, natures, locations — list + detail screens                                             |
| 4     | Backend & DB        | PostgreSQL schema (with sync columns), REST API, API key auth, `/sync/push` + `/sync/pull` endpoints                   |
| 5     | Team Builder        | Folder hierarchy UI, team list, team detail, slot config screen, all slot fields, stat calculator                      |
| 6     | Offline & Sync      | Drift local DB, `pending_sync_ops` queue, sync engine, conflict resolution, offline UI banners, background sync        |
| 7     | Polish              | EV/IV validation, Showdown export, dark/light mode, drag-reorder, sync status indicators, error states                 |
| 8     | Testing             | Widget tests, integration tests for all CRUD flows, offline→online transition tests, manual testing on iOS/Android/web |

---

## 14. APPENDIX

### 14.1 Type Colour Palette (hex)

```text
Normal:   #A8A878    Fire:     #F08030    Water:    #6890F0
Electric: #F8D030    Grass:    #78C850    Ice:      #98D8D8
Fighting: #C03028    Poison:   #A040A0    Ground:   #E0C068
Flying:   #A890F0    Psychic:  #F85888    Bug:      #A8B820
Rock:     #B8A038    Ghost:    #705898    Dragon:   #7038F8
Dark:     #705848    Steel:    #B8B8D0    Fairy:    #EE99AC
```

### 14.2 EV/IV Validation Rules

- Each EV: 0–252
- Total EVs across all 6 stats: must not exceed 510
- Each IV: 0–31
- Show running EV total; highlight red when over 510
- Prevent saving a slot with invalid EV total

### 14.3 Gender Ratio Handling

PokéAPI returns `gender_rate` as eighths female (0–8). Map to:

```text
-1  → Genderless
 0  → Male only
 8  → Female only
1–7 → show Male / Female options
```

### 14.4 Local Drift Schema Note

The Drift local database should mirror the PostgreSQL schema as closely as possible, with these additions:

- `sync_status` TEXT per record: `'synced'` | `'pending'` | `'error'`
- The `pending_sync_ops` table (see Section 8.4)
- A `meta` table: `{ key TEXT PK, value TEXT }` to store `last_pull_timestamp` and `device_id`

---

*End of document. Implement exactly as specified. For any gap not covered, choose the simplest correct solution and document the decision in code comments.*
