# Live Teams — Design Spec

**Date:** 2026-06-09
**Issue:** #176 — Import/Read Pokemon Save Files
**Status:** Approved

---

## Overview

Live Teams is a new tab on the Teams screen that imports teams and boxes directly from Pokemon game save files (`.sav`, `.bin`). Imported content is read-only and stays in sync with the source file. Users can copy any live team into My Teams to create a fully editable duplicate.

---

## Architecture

### Backend: `pkhex-extract` binary

A small self-contained C# console app using `PKHeX.Facade` + `PKHeX.Core` is compiled as a Linux binary and bundled into the backend Docker image. It accepts a save file path as an argument and writes parsed data as JSON to stdout.

```
pkhex-extract /tmp/upload.sav
```

Output shape:

```json
{
  "game": "FireRed",
  "generation": 3,
  "trainer_name": "ASH",
  "party": {
    "name": "Party",
    "slots": [
      {
        "slot_index": 0,
        "species_id": 6,
        "species_name": "charizard",
        "nickname": "CHARIZARD",
        "level": 50,
        "is_shiny": false,
        "gender": "male",
        "nature": "jolly",
        "ability": "blaze",
        "held_item": "charcoal",
        "friendship": 255,
        "moves": ["flamethrower", "fly", "slash", "ember"],
        "evs": { "hp": 0, "atk": 252, "def": 0, "spa": 0, "spd": 4, "spe": 252 },
        "ivs": { "hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31 }
      }
    ]
  },
  "boxes": [
    {
      "box_index": 0,
      "box_name": "Box 1",
      "slots": [ /* same slot shape */ ]
    }
  ]
}
```

Species/ability/move/item names are normalised to lowercase-hyphen (matching the app's existing PokeAPI convention) inside the C# tool. Gen 1–5 are the priority; Gen 6–9 are supported by PKHeX.Core and included from day one.

### Backend: new endpoint

`POST /save/parse`

- Accepts a multipart save file upload
- Writes bytes to a temp path, shells out to `pkhex-extract`, reads stdout JSON, cleans up
- Returns the parsed JSON plus a backend-assigned `save_file_id`
- Saves a `SaveFile` record to the database (game, generation, trainer name, user ID)
- Creates or updates the corresponding `Team` + `TeamSlot` records, marked `is_read_only = true`

### New database entity: `SaveFile`

Tracks one imported save file per row. A save file produces one party team and zero or more box teams.

| Column | Type | Notes |
|--------|------|-------|
| `id` | int PK | |
| `user_id` | int FK | |
| `game_label` | str | e.g. "FireRed" |
| `generation` | int | 1–9 |
| `trainer_name` | str? | From save data |
| `import_mode` | str | `'upload'` or `'path'` |
| `file_hash` | str? | SHA-256, for change detection |
| `remote_id` | str? | Server-assigned ID for sync |
| `is_deleted` | bool | Soft delete |
| `created_at` / `updated_at` | datetime | |

### Teams table additions

Two new columns on `Team` (Flutter + backend):

| Column | Type | Notes |
|--------|------|-------|
| `is_read_only` | bool | Default `false`. `true` for all live teams. |
| `save_file_id` | int? FK → SaveFile | Links team to its source save |

---

## Flutter data model

### New table: `SaveFiles` (`lib/database/tables/save_files_table.dart`)

```dart
class SaveFiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get gameLabel => text()();
  IntColumn get generation => integer()();
  TextColumn get trainerName => text().nullable()();
  TextColumn get importMode => text()(); // 'upload' | 'path'
  TextColumn get localPath => text().nullable()(); // path-watch mode only
  TextColumn get fileHash => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```

### Teams table additions

```dart
BoolColumn get isReadOnly => boolean().withDefault(const Constant(false))();
IntColumn get saveFileId => integer().nullable()(); // no FK enforce — mirrors pattern
```

`schemaVersion` bumped by 1. Migration adds both columns and the new `save_files` table.

---

## UI

### Tab bar

The Teams screen gains a `TabBar` / `TabBarView` with two tabs:

- **My Teams** — existing content, unchanged
- **Live Teams** — new content described below

### Live Teams tab

**Empty state:** Centred message "No saves yet." with the FAB visible.

**Populated state:** A scrollable list of save file cards. Each card:

- **Header row** (always visible): game icon, game label, trainer name, slot count summary, mode badge
  - `[live]` badge — green — path-watch mode, file is monitored
  - `[uploaded]` badge — grey — static until re-uploaded
  - Chevron rotates to indicate expand/collapse state
- **Expanded body:** One row per team derived from this save (party first, then boxes in order). Each row shows an icon (⚔️ party, 📦 box), name, and slot count. Tapping navigates to the read-only team detail screen.
- **Long-press on the header** → context menu:
  - **Re-upload** (upload mode) or **Update now** (path mode) — triggers re-parse
  - **Remove** — soft-deletes the save file and all its live teams (confirms before acting)

**FAB** (bottom-right): Opens a bottom sheet with two options:
- **Upload file** — launches `file_picker`, uploads the selected file to `POST /save/parse`
- **Watch a path** — launches `file_picker` in path mode, stores the path locally, begins file watching

"Watch a path" is hidden on **web** and **iOS**. On those platforms only "Upload file" is shown, and the bottom sheet may be skipped entirely (FAB directly opens the file picker).

### Read-only team detail screen

Reuses `TeamDetailScreen` with two additions:

1. A `🔒 Read-only` chip in the app bar
2. All editing interactions disabled — slots are viewable but fields are not editable
3. A **"Copy to My Teams"** button pinned at the bottom of the screen

Tapping "Copy to My Teams":
1. Opens a folder picker (same sheet used when creating a new team)
2. Creates a full editable duplicate of the team in the chosen folder
3. Navigates the user to the new copy in My Teams

The original live team is unaffected.

---

## File change detection

### Path-watch mode

| Platform | Mechanism |
|----------|-----------|
| Windows / macOS / Linux | `package:watcher` — real-time filesystem callbacks |
| Android | `WorkManager` periodic task (already in pubspec) — checks file hash every 15 minutes when the save path is set |
| iOS / Web | Not supported — upload mode only |

**On change detected:**

1. Re-upload the file to `POST /save/parse`
2. Backend replaces all `TeamSlot` rows for this save file's teams with the freshly parsed data (full replacement, not diff — simpler and safe since live teams are never user-edited)
3. Flutter merges the updated teams into the local DB via the sync pull path
4. A snack bar appears: *"{game} updated"*
5. Normal sync push propagates the changes to the remote; other devices receive them on their next pull

**Offline behaviour:** If the device has no connectivity when a file change is detected, the re-upload is queued in the existing `pending_sync_ops` table and fires automatically when connectivity returns.

---

## Sync contract additions

Following the CLAUDE.md data contract table — all layers updated together:

| Layer | Change |
|-------|--------|
| Backend model | `is_read_only`, `save_file_id` on `Team`; new `SaveFile` model |
| Backend migration | Alembic migration for new columns + `save_files` table |
| Backend push schema | `is_read_only`, `save_file_id` in Team Op schemas |
| Backend pull schema | `is_read_only`, `save_file_id` in Team response schema |
| Backend sync handler | Read/write new fields on push and pull |
| Flutter `_buildOp` | Include `is_read_only`, `save_file_id` |
| Flutter `_mergeTeam` | Write `is_read_only`, `save_file_id` from response |
| Flutter tables | `save_files_table.dart` (new); `teams_table.dart` (two new columns) |
| Flutter `app_database.dart` | Bump `schemaVersion`, add migration |

---

## Build order

1. `pkhex-extract` C# binary — standalone, testable independently
2. Backend Docker integration — copy binary, verify `POST /save/parse` end-to-end
3. Flutter + backend data model — new table, new columns, migrations (both sides)
4. Backend `SaveFile` sync endpoints
5. Flutter upload-mode import flow (FAB → sheet → file picker → parse → display)
6. Live Teams tab UI (expandable cards, empty state)
7. Read-only team detail + "Copy to My Teams"
8. Sync of read-only teams to other devices
9. File watcher service — desktop first, then Android

---

## Out of scope (this spec)

- Editing live teams (they are always read-only by design)
- iOS path-watch (sandboxed filesystem)
- Web path-watch (no filesystem access)
- Automatic detection of save file game version on the client (backend handles this via PKHeX)
