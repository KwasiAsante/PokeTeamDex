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

/// Cosmetic forms that share their base species' /pokemon resource.
/// Structure: baseSpecies → { formName → spriteFileStem }
/// The stem is used in sprite path building: "{stem}.png" / "{stem}-shiny.png".
/// e.g. Burmy Sandy Cloak is filed under "412-sandy" in every sprite tier.
/// Default/base forms (Plant Cloak, West Sea, Spring) are intentionally absent —
/// they use the normal sprite pipeline via pokemonId and need no stem override.
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
};
