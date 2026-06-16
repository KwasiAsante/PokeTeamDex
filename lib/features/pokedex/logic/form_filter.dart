import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

const _kRegionalSuffixes = {'-galar', '-alola', '-hisui', '-paldea'};

const _kExcludeSuffixes = {
  '-mega', '-mega-x', '-mega-y', '-mega-z',
  '-gmax', '-eternamax',
};

// Totem forms appear as both suffix (e.g. "marowak-totem") and infix
// (e.g. "raticate-totem-alola"), so contains() is more reliable than endsWith().
const _kExcludeSubstrings = {'-totem'};

/// Returns non-default [varieties] that are battle-meaningful — regional forms
/// and significant gender/form differences. Excludes Megas, Gigantamax,
/// cosmetic-only forms, and the default variety.
List<PokemonVariety> battleMeaningfulForms(List<PokemonVariety> varieties) {
  final battleMeaningfulNames = PokemonDataRegistry.instance.battleMeaningfulNames;
  return varieties.where((v) {
    if (v.isDefault) return false;
    final name = v.name;
    if (_kExcludeSuffixes.any((s) => name.endsWith(s))) return false;
    if (_kExcludeSubstrings.any((s) => name.contains(s))) return false;
    if (_kRegionalSuffixes.any((s) => name.endsWith(s))) return true;
    if (battleMeaningfulNames.contains(name)) return true;
    return false;
  }).toList();
}

/// Derives a display label from a PokéAPI cosmetic form suffix.
/// e.g. "red-flower" → "Red Flower", "sandy" → "Sandy", "a" → "A".
String cosmeticFormLabel(String formName) {
  if (formName.isEmpty) return 'Default';
  return formName
      .split('-')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
