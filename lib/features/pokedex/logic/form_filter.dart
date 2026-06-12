import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

const _kRegionalSuffixes = {'-galar', '-alola', '-hisui', '-paldea'};

const _kExcludeSuffixes = {
  '-mega', '-mega-x', '-mega-y', '-mega-z',
  '-gmax', '-eternamax',
};

// Totem forms appear as both suffix (e.g. "marowak-totem") and infix
// (e.g. "raticate-totem-alola"), so contains() is more reliable than endsWith().
const _kExcludeSubstrings = {'-totem'};

/// Non-regional forms with meaningfully different stats, moves, or abilities.
const _kBattleMeaningfulNames = {
  'meowstic-female',
  'indeedee-female',
  'basculegion-female',
  'oinkologne-female',
  'urshifu-rapid-strike',
  'lycanroc-midnight', 'lycanroc-dusk',
  'oricorio-pom-pom', 'oricorio-pau', 'oricorio-sensu',
  'toxtricity-low-key',
  'rotom-heat', 'rotom-wash', 'rotom-frost', 'rotom-fan', 'rotom-mow',
  'zacian-crowned', 'zamazenta-crowned',
  'calyrex-ice', 'calyrex-shadow',
  'palafin-hero',
  // Paldean Tauros breeds — each has distinct typing, stats, moves, and locations.
  'tauros-paldea-combat-breed',
  'tauros-paldea-blaze-breed',
  'tauros-paldea-aqua-breed',
  // Darmanitan forms — zen modes have different types/stats; Galarian forms are
  // the same species but distinct in stats and type.
  'darmanitan-zen',
  'darmanitan-galar-standard',
  'darmanitan-galar-zen',
  // Basculin White-Striped is Hisui-exclusive and the only form that evolves
  // into Basculegion; treated as a regional form.
  'basculin-white-striped',
  // Deoxys — each forme has a distinct stat distribution
  'deoxys-attack', 'deoxys-defense', 'deoxys-speed',
  // Shaymin — Sky forme has different type, stats, and ability
  'shaymin-sky',
  // Giratina — Origin forme has different ability and stats
  'giratina-origin',
  // Dialga & Palkia — Origin formes have different typing and stats
  'dialga-origin',
  'palkia-origin',
  // Forces of Nature — Therian formes have different abilities and stats
  'tornadus-therian', 'thundurus-therian', 'landorus-therian', 'enamorus-therian',
  // Kyurem — fusion formes have different typing and stats
  'kyurem-black', 'kyurem-white',
  // Meloetta — Pirouette forme has different type (Fighting) and stats
  'meloetta-pirouette',
  // Greninja — Ash-Greninja has boosted SpA/Spe via Battle Bond
  'greninja-ash',
  // Aegislash — Blade forme has inverted bulk/offense stat spread
  'aegislash-blade',
  // Zygarde — 10% and Complete formes have very different stats
  'zygarde-10', 'zygarde-complete',
  // Hoopa — Unbound forme has different type and stats
  'hoopa-unbound',
  // Wishiwashi — School forme has massively boosted stats (ability-triggered)
  'wishiwashi-school',
  // Necrozma — fusion and Ultra formes have different types and stats
  'necrozma-dusk', 'necrozma-dawn', 'necrozma-ultra',
  // Ursaluna — Bloodmoon forme has different typing and a signature move
  'ursaluna-bloodmoon',
  // Gimmighoul — Roaming forme has different stats
  'gimmighoul-roaming',
  // Ogerpon — each mask changes typing and gives a unique signature move
  'ogerpon-wellspring-mask', 'ogerpon-hearthflame-mask', 'ogerpon-cornerstone-mask',
};

/// Returns non-default [varieties] that are battle-meaningful — regional forms
/// and significant gender/form differences. Excludes Megas, Gigantamax,
/// cosmetic-only forms, and the default variety.
List<PokemonVariety> battleMeaningfulForms(List<PokemonVariety> varieties) {
  return varieties.where((v) {
    if (v.isDefault) return false;
    final name = v.name;
    if (_kExcludeSuffixes.any((s) => name.endsWith(s))) return false;
    if (_kExcludeSubstrings.any((s) => name.contains(s))) return false;
    if (_kRegionalSuffixes.any((s) => name.endsWith(s))) return true;
    if (_kBattleMeaningfulNames.contains(name)) return true;
    return false;
  }).toList();
}

/// Variety names that are purely cosmetic (same stats as base) and should
/// appear as cosmetic chips rather than in the Forms tab.
const kCosmeticVarietyNames = <String>{
  'wormadam-sandy', 'wormadam-trash',
  'squawkabilly-blue-plumage', 'squawkabilly-yellow-plumage', 'squawkabilly-white-plumage',
  'tatsugiri-droopy', 'tatsugiri-stretchy',
  'dudunsparce-three-segment',
  'basculin-blue-striped',
  'morpeko-hangry',
  'mimikyu-busted',
  'minior-red', 'minior-orange', 'minior-yellow', 'minior-green',
  'minior-blue', 'minior-indigo', 'minior-violet',
  'magearna-original',
  'eiscue-noice',
  'zarude-dada',
  'maushold-family-of-three',
  'keldeo-resolute',
};

/// Species whose `pokemon-form` entries are phantom / irrelevant.
/// Mothim inherits Burmy's Sandy/Trash form names but always looks identical.
const kNoCosmeticFormsPokemon = <String>{'mothim'};

/// Species with cosmetically different gender sprites but no `/pokemon-form`
/// resource in PokéAPI. A female chip is synthesised for these in the UI.
const kCosmeticGenderDiffPokemon = <String>{'unfezant'};

/// Derives a display label from a PokéAPI cosmetic form suffix.
/// e.g. "red-flower" → "Red Flower", "sandy" → "Sandy", "a" → "A".
String cosmeticFormLabel(String formName) {
  if (formName.isEmpty) return 'Default';
  return formName
      .split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
