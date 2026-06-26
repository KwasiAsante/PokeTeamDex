// Dynamax / Gigantamax move data for Gen 8 (Sword & Shield).

// ── Max Moves (Dynamax) ───────────────────────────────────────────────────────

/// Maps move type → type-appropriate Max Move name (PokéAPI format).
/// Status moves always become Max Guard regardless of type.
const Map<String, String> kMaxMovesByType = {
  'normal':   'max-strike',
  'fire':     'max-flare',
  'water':    'max-geyser',
  'electric': 'max-lightning',
  'grass':    'max-overgrowth',
  'ice':      'max-hailstorm',
  'fighting': 'max-knuckle',
  'poison':   'max-ooze',
  'ground':   'max-quake',
  'flying':   'max-airstream',
  'psychic':  'max-mindstorm',
  'bug':      'max-flutterby',
  'rock':     'max-rockfall',
  'ghost':    'max-phantasm',
  'dragon':   'max-wyrmwind',
  'dark':     'max-darkness',
  'steel':    'max-steelspike',
  'fairy':    'max-starfall',
};

const String kMaxGuard = 'max-guard'; // status moves → Max Guard

// ── G-Max Moves (Gigantamax) ──────────────────────────────────────────────────

/// Maps PokéAPI species name → G-Max move name and type.
/// Species prefixes are used so all forms of a species match
/// (e.g. 'urshifu' covers both urshifu-single-strike and urshifu-rapid-strike).
/// The type field gates display: a G-Max move only replaces the Max Move for
/// base moves of the same type.
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
  // Isle of Armor DLC additions
  'rillaboom':             (moveName: 'g-max-drum-solo',   type: 'grass'),
  'cinderace':             (moveName: 'g-max-fireball',    type: 'fire'),
  'inteleon':              (moveName: 'g-max-hydrosnipe',  type: 'water'),
  // Urshifu has two forms with different G-Max moves; handled in resolveGMaxMove.
  'urshifu-single-strike': (moveName: 'g-max-one-blow',    type: 'dark'),
  'urshifu-rapid-strike':  (moveName: 'g-max-rapid-flow',  type: 'water'),
  'urshifu':               (moveName: 'g-max-one-blow',    type: 'dark'), // fallback for base form
};

/// Returns the G-Max entry (moveName + type) for [speciesName], or null if
/// the species cannot Gigantamax.
({String moveName, String type})? gmaxMoveForSpecies(String speciesName) {
  // Exact match first (covers urshifu-single-strike etc.)
  if (kGMaxMovesBySpecies.containsKey(speciesName)) {
    return kGMaxMovesBySpecies[speciesName];
  }
  // Prefix match for unlisted forms (e.g. pikachu-original → pikachu).
  for (final entry in kGMaxMovesBySpecies.entries) {
    if (speciesName.startsWith(entry.key)) return entry.value;
  }
  return null;
}

/// Returns the Max Move name for a given move, or null when Dynamax doesn't
/// apply (non-Gen-8 formats handled by the caller).
///
/// [moveType]     — PokéAPI type name of the move (null if unknown).
/// [moveCategory] — 'physical', 'special', or 'status'.
/// [speciesName]  — PokéAPI species name; used only when [useGMax] is true.
/// [useGMax]      — whether this Pokémon has Gigantamax enabled.
String? resolveMaxMove({
  required String? moveType,
  required String? moveCategory,
  required String speciesName,
  bool useGMax = false,
}) {
  // Status moves always become Max Guard.
  if (moveCategory == 'status') return kMaxGuard;

  if (useGMax) {
    final gmax = gmaxMoveForSpecies(speciesName);
    if (gmax != null && moveType == gmax.type) return gmax.moveName;
  }

  return moveType != null ? kMaxMovesByType[moveType] : null;
}
