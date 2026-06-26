# Investigation: GMax Moves on Wrong Base Moves

**Issue:** [#248](https://github.com/KwasiAsante/poke_team_dex/issues/248)  
**Branch:** `investigation/gmax-moves-base-move-filter`  
**Status:** Investigation complete — ready for implementation

---

## 1. Research Findings

### 1.1 Root Cause

In `lib/features/teams/data/dynamax_data.dart`, `resolveMaxMove()` returns the Gigantamax
move for **any** non-status base move when `useGMax=true`:

```dart
// dynamax_data.dart:104–107
if (useGMax) {
  final gmax = gmaxMoveForSpecies(speciesName);
  if (gmax != null) return gmax;  // ← returns G-Max for ALL non-status moves
}
```

The function receives `moveType` (e.g. `'fire'`, `'dragon'`) but never checks it when
`useGMax` is true. As a result, Charizard's G-Max Wildfire (a Fire-type move) appears as
the derived Max Move under Air Slash (Flying), Dragon Claw (Dragon), and every other
non-status move — not just Fire-type moves.

### 1.2 Game Mechanics

Each G-Max move has a fixed type. It replaces only the Max Move of that same type:

- **G-Max Wildfire** (Fire) → replaces Max Flare on Fire-type non-status moves  
- **G-Max Volt Crash** (Electric) → replaces Max Lightning on Electric-type moves  
- Non-matching types still produce the regular type-appropriate Max Move  

This is a type-gating rule, not a specific base-move whitelist, which means the fix is
purely in the data and the guard logic — no external data source or API is needed.

### 1.3 Affected Files

| File | Role | Change needed |
|------|------|---------------|
| `lib/features/teams/data/dynamax_data.dart` | GMax data + resolution | Add `type` field to species entries; update `gmaxMoveForSpecies()` return type; add type guard in `resolveMaxMove()` |
| `lib/features/teams/presentation/slot_config_screen.dart` | Calls `gmaxMoveForSpecies()` at lines 685–686 | Update to use `.moveName` from new record type |
| `lib/features/teams/presentation/team_detail_screen.dart` | Calls `gmaxMoveForSpecies()` at line 976 | Update to use `.moveName` from new record type |
| `test/unit/dynamax_test.dart` | Unit tests | Add type-guard tests; update existing exact-match expectations |

### 1.4 Z-Move Pattern as Reference

`z_moves_data.dart` shows the correct pattern for move gating. `ExclusiveZData` includes
`requiredMoveId`, and `resolveZMove()` returns `null` when the base move doesn't match.
The G-Max fix follows the same principle but guards on type rather than move ID.

### 1.5 No Backend or PokéAPI Changes Required

The type data for all 34 G-Max entries is static and well-established (Gen 8 mechanics
do not change). It is hardcoded — consistent with `kMaxMovesByType` and
`kGMaxMovesBySpecies` already in the file.

---

## 2. Answered Investigation Questions

**Why does the G-Max move appear under every non-status move?**  
`resolveMaxMove()` short-circuits to return the G-Max move the moment `useGMax=true` and
the species has a G-Max entry, ignoring `moveType` entirely.

**What data is needed?**  
The type of each G-Max move. There are 34 entries (32 species + 2 Urshifu forms +
1 urshifu fallback). All types are statically known; no external lookup needed.

**Does this affect the regular Dynamax (non-Gigantamax) path?**  
No. The type-based `kMaxMovesByType` lookup is already correct. The bug only affects
the `useGMax=true` branch.

**Should existing tests break?**  
Yes — the existing `resolveMaxMove` G-Max tests pass the matching type by coincidence
(e.g. `moveType: 'fire'` for Charizard). New tests with mismatched types must be added,
and the `gmaxMoveForSpecies` exact-match tests must be updated to check `.moveName`.

---

## 3. Implementation Plan

### Task 1 — Extend `kGMaxMovesBySpecies` with type data

Change the map value type from `String` to a Dart record `({String moveName, String type})`.

```dart
// Before
const Map<String, String> kGMaxMovesBySpecies = {
  'charizard': 'g-max-wildfire',
  ...
};

// After
const Map<String, ({String moveName, String type})> kGMaxMovesBySpecies = {
  'venusaur':              (moveName: 'g-max-vine-lash',   type: 'grass'),
  'charizard':             (moveName: 'g-max-wildfire',    type: 'fire'),
  'blastoise':             (moveName: 'g-max-cannonade',   type: 'water'),
  'butterfree':            (moveName: 'g-max-befuddle',    type: 'bug'),
  'pikachu':               (moveName: 'g-max-volt-crash',  type: 'electric'),
  'meowth':                (moveName: 'g-max-gold-rush',   type: 'normal'),
  'machamp':               (moveName: 'g-max-chi-strike',  type: 'fighting'),
  'gengar':                (moveName: 'g-max-terror',      type: 'ghost'),
  'kingler':               (moveName: 'g-max-foam-burst',  type: 'water'),
  'lapras':                (moveName: 'g-max-resonance',   type: 'ice'),
  'eevee':                 (moveName: 'g-max-cuddle',      type: 'normal'),
  'snorlax':               (moveName: 'g-max-replenish',   type: 'normal'),
  'garbodor':              (moveName: 'g-max-malodor',     type: 'poison'),
  'melmetal':              (moveName: 'g-max-meltdown',    type: 'steel'),
  'corviknight':           (moveName: 'g-max-wind-rage',   type: 'flying'),
  'orbeetle':              (moveName: 'g-max-gravitas',    type: 'psychic'),
  'drednaw':               (moveName: 'g-max-stonesurge',  type: 'water'),
  'coalossal':             (moveName: 'g-max-volcalith',   type: 'rock'),
  'flapple':               (moveName: 'g-max-tartness',    type: 'grass'),
  'appletun':              (moveName: 'g-max-sweetness',   type: 'grass'),
  'sandaconda':            (moveName: 'g-max-sandblast',   type: 'ground'),
  'toxtricity':            (moveName: 'g-max-stun-shock',  type: 'electric'),
  'centiskorch':           (moveName: 'g-max-centiferno',  type: 'fire'),
  'hatterene':             (moveName: 'g-max-smite',       type: 'fairy'),
  'grimmsnarl':            (moveName: 'g-max-snooze',      type: 'dark'),
  'alcremie':              (moveName: 'g-max-finale',      type: 'fairy'),
  'copperajah':            (moveName: 'g-max-steelsurge',  type: 'steel'),
  'duraludon':             (moveName: 'g-max-depletion',   type: 'dragon'),
  'rillaboom':             (moveName: 'g-max-drum-solo',   type: 'grass'),
  'cinderace':             (moveName: 'g-max-fireball',    type: 'fire'),
  'inteleon':              (moveName: 'g-max-hydrosnipe',  type: 'water'),
  'urshifu-single-strike': (moveName: 'g-max-one-blow',    type: 'dark'),
  'urshifu-rapid-strike':  (moveName: 'g-max-rapid-flow',  type: 'water'),
  'urshifu':               (moveName: 'g-max-one-blow',    type: 'dark'),
};
```

### Task 2 — Update `gmaxMoveForSpecies()` return type

```dart
// Returns the G-Max entry (moveName + type) for speciesName, or null.
({String moveName, String type})? gmaxMoveForSpecies(String speciesName) {
  if (kGMaxMovesBySpecies.containsKey(speciesName)) {
    return kGMaxMovesBySpecies[speciesName];
  }
  for (final entry in kGMaxMovesBySpecies.entries) {
    if (speciesName.startsWith(entry.key)) return entry.value;
  }
  return null;
}
```

### Task 3 — Add type guard in `resolveMaxMove()`

```dart
if (useGMax) {
  final gmax = gmaxMoveForSpecies(speciesName);
  if (gmax != null && moveType == gmax.type) return gmax.moveName;
}
// Falls through to kMaxMovesByType for non-matching types (correct behaviour)
```

### Task 4 — Update callers of `gmaxMoveForSpecies()`

Both callers only need the move name to check for non-null (existence test):

- `slot_config_screen.dart:685` — `gmaxMoveForSpecies(…) != null` → no change in logic; result type change only (still non-null check)
- `team_detail_screen.dart:976` — same pattern

Both currently do `gmaxMoveForSpecies(name) != null` to determine `canGigantamax`. The
record return type makes `!= null` work the same way. No logic change needed at call sites.

### Task 5 — Update `dynamax_test.dart`

1. Update `gmaxMoveForSpecies` tests: use `.moveName` when checking the returned value.
2. Add `resolveMaxMove` type-guard tests:
   - G-Max species + **matching** type → returns G-Max move name (existing cases, still pass)
   - G-Max species + **non-matching** type → returns the regular Max Move for that type
   - G-Max species + **status** → still returns `max-guard` (no change)

Example new test cases:
```dart
test('charizard + flying move → max-airstream (not g-max-wildfire)', () {
  expect(
    resolveMaxMove(
      moveType: 'flying',
      moveCategory: 'physical',
      speciesName: 'charizard',
      useGMax: true,
    ),
    'max-airstream',
  );
});

test('pikachu + grass move → max-overgrowth (not g-max-volt-crash)', () {
  expect(
    resolveMaxMove(
      moveType: 'grass',
      moveCategory: 'special',
      speciesName: 'pikachu',
      useGMax: true,
    ),
    'max-overgrowth',
  );
});
```

---

## 4. Acceptance Criteria

- [ ] In `slot_config_screen.dart`, when a Gigantamax Pokémon (e.g. Charizard) has a
  Fire-type move selected, the derived move chip shows G-Max Wildfire.
- [ ] When the same Pokémon has a non-Fire move selected (e.g. Air Slash — Flying), the
  chip shows Max Airstream, not G-Max Wildfire.
- [ ] Status moves still produce Max Guard regardless of GMax eligibility.
- [ ] Non-Gigantamax Pokémon are unaffected.
- [ ] All existing `dynamax_test.dart` tests pass after the return-type update.
- [ ] New type-guard tests pass.
