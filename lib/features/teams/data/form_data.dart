// lib/features/teams/data/form_data.dart

/// PS species name → PokéAPI variety name for known mismatches.
/// Checked before the heuristic pipeline in ps_form_resolver.dart — O(1), no API call.
/// All keys must be lowercase-hyphenated (normalised PS names).
const Map<String, String> kPsFormExceptions = {
  // Ogerpon mask forms — PS omits the "-mask" suffix
  'ogerpon-teal':         'ogerpon-teal-mask',
  'ogerpon-wellspring':   'ogerpon-wellspring-mask',
  'ogerpon-hearthflame':  'ogerpon-hearthflame-mask',
  'ogerpon-cornerstone':  'ogerpon-cornerstone-mask',
};

/// Forms whose sprites are filed under "{baseSpeciesId}-{suffix}" in every tier
/// (raw, versioned Gen 1-5, HOME), rather than under the form's own extended ID.
/// Structure: baseSpecies → { formName → spriteFileStem }
/// Covers both cosmetic forms (share base /pokemon resource, e.g. Burmy cloaks)
/// and variety forms whose versioned-sprite paths use the base ID pattern
/// (e.g. Unown letter forms: /pokemon/unown-b has extended ID ~10133, but the
/// Gen 2 sprite repo files it as "201-b.png" not "10133.png").
/// Default/base forms are intentionally absent — they use the normal pipeline.
const Map<String, Map<String, String>> kCosmeticSpriteStems = {
  'burmy': {
    'burmy-sandy': '412-sandy',
    'burmy-trash': '412-trash',
  },
  'wormadam': {
    'wormadam-sandy': '413-sandy',
    'wormadam-trash': '413-trash',
  },
  'shellos': {
    'shellos-east': '422-east',
  },
  'gastrodon': {
    'gastrodon-east': '423-east',
  },
  'deerling': {
    'deerling-summer': '585-summer',
    'deerling-autumn': '585-autumn',
    'deerling-winter': '585-winter',
  },
  'sawsbuck': {
    'sawsbuck-summer': '586-summer',
    'sawsbuck-autumn': '586-autumn',
    'sawsbuck-winter': '586-winter',
  },
  // Unown letter forms have their own /pokemon resources (extended IDs) but the
  // versioned sprite repo (Gen 2) files them as "201-{letter}.png", not
  // by extended ID. The shiny path works because it uses Showdown by name.
  'unown': {
    'unown-a': '201-a', 'unown-b': '201-b', 'unown-c': '201-c',
    'unown-d': '201-d', 'unown-e': '201-e', 'unown-f': '201-f',
    'unown-g': '201-g', 'unown-h': '201-h', 'unown-i': '201-i',
    'unown-j': '201-j', 'unown-k': '201-k', 'unown-l': '201-l',
    'unown-m': '201-m', 'unown-n': '201-n', 'unown-o': '201-o',
    'unown-p': '201-p', 'unown-q': '201-q', 'unown-r': '201-r',
    'unown-s': '201-s', 'unown-t': '201-t', 'unown-u': '201-u',
    'unown-v': '201-v', 'unown-w': '201-w', 'unown-x': '201-x',
    'unown-y': '201-y', 'unown-z': '201-z',
    'unown-exclamation': '201-exclamation',
    'unown-question':    '201-question',
  },
};
