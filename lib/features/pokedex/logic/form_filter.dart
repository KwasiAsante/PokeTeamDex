import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

const _kRegionalSuffixes = {'-galar', '-alola', '-hisui', '-paldea'};

const _kExcludeSuffixes = {
  '-mega', '-mega-x', '-mega-y', '-mega-z',
  '-gmax', '-eternamax', '-totem',
};

/// Non-regional forms with meaningfully different stats, moves, or abilities.
const _kBattleMeaningfulNames = {
  'meowstic-female',
  'indeedee-female',
  'basculegion-female',
  'urshifu-rapid-strike',
  'lycanroc-midnight', 'lycanroc-dusk',
  'oricorio-pom-pom', 'oricorio-pau', 'oricorio-sensu',
  'toxtricity-low-key',
  'rotom-heat', 'rotom-wash', 'rotom-frost', 'rotom-fan', 'rotom-mow',
  'zacian-crowned', 'zamazenta-crowned',
  'calyrex-ice', 'calyrex-shadow',
  'palafin-hero',
};

/// Returns non-default [varieties] that are battle-meaningful — regional forms
/// and significant gender/form differences. Excludes Megas, Gigantamax,
/// cosmetic-only forms, and the default variety.
List<PokemonVariety> battleMeaningfulForms(List<PokemonVariety> varieties) {
  return varieties.where((v) {
    if (v.isDefault) return false;
    final name = v.name;
    if (_kExcludeSuffixes.any((s) => name.endsWith(s))) return false;
    if (_kRegionalSuffixes.any((s) => name.endsWith(s))) return true;
    if (_kBattleMeaningfulNames.contains(name)) return true;
    return false;
  }).toList();
}
