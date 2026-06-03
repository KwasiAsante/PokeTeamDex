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

/// Maps PokéAPI species name → G-Max move name.
/// Species prefixes are used so all forms of a species match
/// (e.g. 'urshifu' covers both urshifu-single-strike and urshifu-rapid-strike).
const Map<String, String> kGMaxMovesBySpecies = {
  'venusaur':   'g-max-vine-lash',
  'charizard':  'g-max-wildfire',
  'blastoise':  'g-max-cannonade',
  'butterfree': 'g-max-befuddle',
  'pikachu':    'g-max-volt-crash',
  'meowth':     'g-max-gold-rush',
  'machamp':    'g-max-chi-strike',
  'gengar':     'g-max-terror',
  'kingler':    'g-max-foam-burst',
  'lapras':     'g-max-resonance',
  'eevee':      'g-max-cuddle',
  'snorlax':    'g-max-replenish',
  'garbodor':   'g-max-malodor',
  'melmetal':   'g-max-meltdown',
  'corviknight':'g-max-wind-rage',
  'orbeetle':   'g-max-gravitas',
  'drednaw':    'g-max-stonesurge',
  'coalossal':  'g-max-volcalith',
  'flapple':    'g-max-tartness',
  'appletun':   'g-max-sweetness',
  'sandaconda': 'g-max-sandblast',
  'toxtricity': 'g-max-stun-shock',
  'centiskorch':'g-max-centiferno',
  'hatterene':  'g-max-smite',
  'grimmsnarl': 'g-max-snooze',
  'alcremie':   'g-max-finale',
  'copperajah': 'g-max-steelsurge',
  'duraludon':  'g-max-depletion',
  // Isle of Armor DLC additions
  'rillaboom':  'g-max-drum-solo',
  'cinderace':  'g-max-fireball',
  'inteleon':   'g-max-hydrosnipe',
  // Urshifu has two forms with different G-Max moves; handled in resolveGMaxMove.
  'urshifu-single-strike': 'g-max-one-blow',
  'urshifu-rapid-strike':  'g-max-rapid-flow',
  'urshifu':               'g-max-one-blow', // fallback for base form
};

/// Returns the G-Max move for [speciesName], or null if the species cannot
/// Gigantamax.
String? gmaxMoveForSpecies(String speciesName) {
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
    if (gmax != null) return gmax;
  }

  return moveType != null ? kMaxMovesByType[moveType] : null;
}
