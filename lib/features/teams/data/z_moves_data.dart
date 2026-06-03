// Z-Crystal → Z-Move mapping data.
// Type Z-crystals convert any move of the matching type.
// Exclusive Z-crystals require a specific base move (and often a specific species).

// ── Type Z-crystals ───────────────────────────────────────────────────────────

typedef TypeZEntry = ({String type, String zMove});

/// Maps PokéAPI item name → (type, z-move) for the 18 type Z-crystals.
const Map<String, TypeZEntry> kTypeZCrystals = {
  'buginium-z':   (type: 'bug',      zMove: 'savage-spin-out'),
  'darkinium-z':  (type: 'dark',     zMove: 'black-hole-eclipse'),
  'dragonium-z':  (type: 'dragon',   zMove: 'devastating-drake'),
  'electrium-z':  (type: 'electric', zMove: 'gigavolt-havoc'),
  'fairium-z':    (type: 'fairy',    zMove: 'twinkle-tackle'),
  'fightinium-z': (type: 'fighting', zMove: 'all-out-pummeling'),
  'firium-z':     (type: 'fire',     zMove: 'inferno-overdrive'),
  'flyinium-z':   (type: 'flying',   zMove: 'supersonic-skystrike'),
  'ghostium-z':   (type: 'ghost',    zMove: 'never-ending-nightmare'),
  'grassium-z':   (type: 'grass',    zMove: 'bloom-doom'),
  'groundium-z':  (type: 'ground',   zMove: 'tectonic-rage'),
  'icium-z':      (type: 'ice',      zMove: 'subzero-slammer'),
  'normalium-z':  (type: 'normal',   zMove: 'breakneck-blitz'),
  'poisonium-z':  (type: 'poison',   zMove: 'acid-downpour'),
  'psychium-z':   (type: 'psychic',  zMove: 'shattered-psyche'),
  'rockium-z':    (type: 'rock',     zMove: 'continental-crush'),
  'steelium-z':   (type: 'steel',    zMove: 'corkscrew-crash'),
  'waterium-z':   (type: 'water',    zMove: 'hydro-vortex'),
};

// ── Exclusive Z-crystals ──────────────────────────────────────────────────────

class ExclusiveZData {
  /// Species name prefixes that are allowed (empty = any species is fine).
  /// Use prefixes to cover all forms, e.g. 'lycanroc' covers all Lycanroc forms.
  final List<String> speciesPrefixes;

  /// The PokéAPI move name required as the base move.
  final String requiredMoveId;

  /// The PokéAPI Z-move name produced.
  final String zMove;

  const ExclusiveZData({
    required this.speciesPrefixes,
    required this.requiredMoveId,
    required this.zMove,
  });

  /// Returns true when [pokemonName] satisfies the species requirement.
  bool matchesSpecies(String pokemonName) {
    if (speciesPrefixes.isEmpty) return true;
    return speciesPrefixes.any((p) => pokemonName.startsWith(p));
  }
}

/// Maps PokéAPI item name → exclusive Z-crystal data.
const Map<String, ExclusiveZData> kExclusiveZCrystals = {
  'aloraichium-z': ExclusiveZData(
    speciesPrefixes: ['raichu-alola'],
    requiredMoveId: 'thunderbolt',
    zMove: '10000000-volt-thunderbolt',
  ),
  'decidium-z': ExclusiveZData(
    speciesPrefixes: ['decidueye'],
    requiredMoveId: 'spirit-shackle',
    zMove: 'sinister-arrow-raid',
  ),
  'eevium-z': ExclusiveZData(
    speciesPrefixes: ['eevee'],
    requiredMoveId: 'last-resort',
    zMove: 'extreme-evoboost',
  ),
  'incinium-z': ExclusiveZData(
    speciesPrefixes: ['incineroar'],
    requiredMoveId: 'darkest-lariat',
    zMove: 'malicious-moonsault',
  ),
  'kommonium-z': ExclusiveZData(
    speciesPrefixes: ['kommo-o'],
    requiredMoveId: 'clanging-scales',
    zMove: 'clangorous-soulblaze',
  ),
  'lunalium-z': ExclusiveZData(
    speciesPrefixes: ['lunala'],
    requiredMoveId: 'moongeist-beam',
    zMove: 'menacing-moonraze-maelstrom',
  ),
  'lycanium-z': ExclusiveZData(
    speciesPrefixes: ['lycanroc'],
    requiredMoveId: 'stone-edge',
    zMove: 'splintered-stormshards',
  ),
  'marshadium-z': ExclusiveZData(
    speciesPrefixes: ['marshadow'],
    requiredMoveId: 'spectral-thief',
    zMove: 'soul-stealing-7-star-strike',
  ),
  'mewnium-z': ExclusiveZData(
    speciesPrefixes: ['mew'],
    requiredMoveId: 'nasty-plot',
    zMove: 'genesis-supernova',
  ),
  'mimikium-z': ExclusiveZData(
    speciesPrefixes: ['mimikyu'],
    requiredMoveId: 'play-rough',
    zMove: 'lets-snuggle-forever',
  ),
  'pikanium-z': ExclusiveZData(
    speciesPrefixes: ['pikachu'],
    requiredMoveId: 'volt-tackle',
    zMove: 'catastropika',
  ),
  'pikashunium-z': ExclusiveZData(
    speciesPrefixes: ['pikachu'],
    requiredMoveId: 'thunderbolt',
    zMove: '10000000-volt-thunderbolt',
  ),
  'primarium-z': ExclusiveZData(
    speciesPrefixes: ['primarina'],
    requiredMoveId: 'sparkling-aria',
    zMove: 'oceanic-operetta',
  ),
  'snorlium-z': ExclusiveZData(
    speciesPrefixes: ['snorlax'],
    requiredMoveId: 'giga-impact',
    zMove: 'pulverizing-pancake',
  ),
  'solganium-z': ExclusiveZData(
    speciesPrefixes: ['solgaleo'],
    requiredMoveId: 'sunsteel-strike',
    zMove: 'searing-sunraze-smash',
  ),
  'tapunium-z': ExclusiveZData(
    speciesPrefixes: ['tapu-'],
    requiredMoveId: 'natures-madness',
    zMove: 'guardian-of-alola',
  ),
  'ultranecrozium-z': ExclusiveZData(
    speciesPrefixes: ['necrozma'],
    requiredMoveId: 'photon-geyser',
    zMove: 'light-that-burns-the-sky',
  ),
};

/// Strips the `-held` or `-bag` suffix that PokéAPI/PS attaches to the
/// held-form of Z-crystals (e.g. `incinium-z-held` → `incinium-z`).
/// Also strips any trailing hyphens left over after the removal.
String _normalizeZCrystalId(String itemId) => itemId
    .replaceAll(RegExp(r'-(held|bag)$'), '')
    .replaceAll(RegExp(r'-+$'), '');

/// Returns the Z-move name for [moveId] (PokéAPI name) given the current
/// Z-crystal [itemId] and [pokemonName].
/// Returns null when no Z-move applies.
String? resolveZMove({
  required String itemId,
  required String moveId,
  required String pokemonName,
  String? moveType, // PokéAPI type name of the move
}) {
  final id = _normalizeZCrystalId(itemId);

  // Check exclusive Z-crystals first.
  final exclusive = kExclusiveZCrystals[id];
  if (exclusive != null) {
    if (moveId == exclusive.requiredMoveId &&
        exclusive.matchesSpecies(pokemonName)) {
      return exclusive.zMove;
    }
    return null; // exclusive crystal → only the one required move qualifies
  }

  // Check type Z-crystals.
  final typeEntry = kTypeZCrystals[id];
  if (typeEntry != null && moveType == typeEntry.type) {
    return typeEntry.zMove;
  }

  return null;
}
