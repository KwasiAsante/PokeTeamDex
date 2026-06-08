# Import Name & Format Overrides — Design Spec

**Issue:** #139  
**Date:** 2026-06-08  
**Status:** Approved

---

## Problem

When importing a team from Pokémon Showdown, the name and format are extracted from the `=== [gen9ou] My Team ===` header line. If that header is absent (common for clipboard exports that strip it), the team gets a generic fallback name and no format. Users currently have no way to specify these values at import time.

---

## Solution

Add two optional override fields to the top of `PsImportSheet` — Team Name and Format — shown only on the new-team creation path. If filled, they take precedence over whatever is parsed from the paste text. If left empty, the existing parse-and-fallback logic runs unchanged.

---

## Scope

- **In scope:** `PsImportSheet` when `targetTeamId` is null (new team creation — triggered from Teams List AppBar and folder context menu).
- **Out of scope:** `PsImportSheet` when `targetTeamId` is set (import into existing team). The team already has a name and format; no changes needed there.

---

## UI

Layout: **Option A — fields above the paste area.**

```
┌─────────────────────────────────┐
│ Import from Showdown            │
│                                 │
│ Team Name          (optional)   │
│ [________________________]      │
│                                 │
│ Format             (optional)   │
│ [No format selected          ▾] │
│                                 │
│ Paste Showdown text             │
│ [                               │
│   Pikachu @ Light Ball          │
│   Ability: Static               │
│   ...                           │
│ ]                               │
│                                 │
│  [Cancel]        [Import]       │
└─────────────────────────────────┘
```

### Team Name field
- Standard `TextField`, hint text: `"e.g. Sun Team · optional"`
- Empty → use `parsed.name` (from `=== … ===` header) or `"Imported Team"` fallback (existing behaviour)
- Non-empty → use the entered value, ignoring any parsed name

### Format field
- Tappable row styled like the format selector on `team_detail_screen.dart`
- Displays "No format · optional" when nothing is selected; shows `GameFormat.short` when selected
- Tapping opens the existing `FormatPickerSheet` via `showModalBottomSheet`
- Returns a `GameFormat?`; `isFormatCleared` sentinel is not needed here (field simply starts as null)
- Empty/null → use `parsed.formatId` (from `[gen9ou]` bracket in header) or null (existing behaviour)
- Selected → use `GameFormat.id`, ignoring any parsed format

---

## State Changes (`_PsImportSheetState`)

| Addition | Type | Purpose |
|---|---|---|
| `_nameCtrl` | `TextEditingController` | Holds the override team name |
| `_selectedFormat` | `GameFormat?` | Holds the override format; null = no override |

Both are disposed in `dispose()`.

The fields are only rendered when `widget.targetTeamId == null`.

---

## Logic Changes (`_importAsNewTeam`)

After `_parseTeam()` returns a `_PsTeam`, apply overrides before using the parsed values:

```dart
final name = _nameCtrl.text.trim().isNotEmpty
    ? _nameCtrl.text.trim()
    : (parsed.name.isNotEmpty ? parsed.name : 'Imported Team');

final formatId = _selectedFormat != null
    ? _selectedFormat!.id
    : parsed.formatId; // may be null — existing behaviour
```

Everything downstream (team insert, sync enqueue, slot insertion, navigation) is unchanged.

---

## Files Changed

| File | Change |
|---|---|
| `lib/features/teams/presentation/ps_import_sheet.dart` | Add `_nameCtrl`, `_selectedFormat`, render override fields, apply overrides in `_importAsNewTeam` |

No other files change. `FormatPickerSheet` is reused as-is.

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| Name field empty, header present | Parsed name used |
| Name field empty, no header | "Imported Team" fallback |
| Name field filled | Override used regardless of header |
| Format field empty, `[gen9ou]` in header | Parsed format used |
| Format field empty, no bracket | null format (no format assigned) |
| Format field selected | Override used regardless of header |
| `targetTeamId` set | Override fields not rendered; no behaviour change |
