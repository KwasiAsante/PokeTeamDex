import 'package:change_case/change_case.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/teams/logic/hidden_power.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

/// Maps a PokeTeamDex format ID → the corresponding Pokémon Showdown format
/// string used in the === [...] === team header.
const Map<String, String> kFormatToPsFormat = {
  // Gen 1
  'gen1': 'gen1ubers', 'rb': 'gen1ubers', 'yellow': 'gen1ubers',
  // Gen 2
  'gen2': 'gen2ubers', 'gs': 'gen2ubers', 'crystal': 'gen2ubers',
  // Gen 3
  'gen3': 'gen3ubers', 'rs': 'gen3ubers', 'emerald': 'gen3ubers',
  'frlg': 'gen3frlgou',
  // Gen 4
  'gen4': 'gen4anythinggoes', 'dp': 'gen4anythinggoes',
  'platinum': 'gen4anythinggoes', 'hgss': 'gen4anythinggoes',
  // Gen 5
  'bw': 'gen5bw1ou',
  'gen5': 'gen5ubers', 'b2w2': 'gen5ubers',
  // Gen 6
  'gen6': 'gen6anythinggoes', 'xy': 'gen6anythinggoes',
  'oras': 'gen6anythinggoes',
  // Gen 7
  'gen7': 'gen7anythinggoes', 'sm': 'gen7anythinggoes',
  'usum': 'gen7anythinggoes',
  // Gen 8
  'gen8': 'gen8anythinggoes', 'swsh': 'gen8anythinggoes',
  'pla': 'gen8anythinggoes',
  'bdsp': 'gen8bdspubers',
  // Gen 9
  'gen9': 'gen9anythinggoes', 'sv': 'gen9anythinggoes',
};

/// Capitalizes the first letter of each hyphen-separated segment.
/// "rotom-wash" → "Rotom-Wash", "charizard-mega-x" → "Charizard-Mega-X"
String _capitalizeHyphenated(String name) {
  return name.split('-').map((part) {
    if (part.isEmpty) return part;
    return part[0].toUpperCase() + part.substring(1);
  }).join('-');
}

/// Normalises a stored nature name to just the nature word, capitalised.
/// Handles values that may have been stored with a "Nature: " prefix or
/// " Nature" suffix due to an import parsing issue.
String _normalisedNature(String raw) {
  var n = raw
      .replaceFirst(RegExp(r'^[Nn]ature:\s*'), '')   // strip "Nature: " prefix
      .replaceAll(RegExp(r'\s*[Nn]ature\s*$'), '')   // strip " Nature" suffix
      .trim();
  if (n.isEmpty) return raw;
  return n[0].toUpperCase() + n.substring(1).toLowerCase();
}

/// Generates a Pokémon Showdown-compatible export string for [slots].
/// Produces only the Pokémon blocks — no header line.
Future<String> buildShowdownExport(
  List<TeamSlot> slots,
  PokeApiRepository pokeApi, {
  String? teamName,
  String? formatLabel,
  String? formatName,
  int? gen,
}) async {
  final blocks = <String>[];

  for (final slot in slots..sort((a, b) => a.slot.compareTo(b.slot))) {
    final pokemon = await pokeApi.fetchPokemon(slot.pokemonId);
    // Some species' *default* variety is itself gender-suffixed at the
    // /pokemon level (e.g. Pyroar's default variety is literally named
    // "pyroar-male", Jellicent's "jellicent-male") — pokemon.name would
    // wrongly become "Pyroar Male" even with no form selected. speciesName
    // is the species-level name ("pyroar"), unaffected by this. Same
    // speciesName-vs-name distinction used for form suffix stripping
    // elsewhere in the app.
    final baseName = (pokemon.speciesName ?? pokemon.name).toCapitalCase();
    final nickname = slot.nickname?.trim();
    final hasNickname =
        nickname != null && nickname.isNotEmpty && nickname != baseName;

    // Species display name includes form when set — but only for
    // battle-meaningful, non-default varieties (species with their own
    // /pokemon resource, e.g. "rotom-wash"). Cosmetic form-entries (e.g.
    // Pyroar's or Jellicent's "-female" sprite-only form, which has no
    // /pokemon resource of its own) aren't real PS species and must not be
    // folded into the species name — PS conveys their gender purely via
    // the (M)/(F) tag below. The default-variety exclusion additionally
    // covers species like Pyroar/Jellicent whose default variety name
    // (e.g. "pyroar-male") would otherwise match here too.
    String? battleFormName;
    if (slot.formName != null && slot.formName!.isNotEmpty) {
      final species = await pokeApi.fetchPokemonSpecies(pokemon.id);
      final matchedVariety =
          species.varieties.where((v) => v.name == slot.formName).firstOrNull;
      if (matchedVariety != null && !matchedVariety.isDefault) {
        battleFormName = slot.formName;
      }
    }
    final speciesDisplay = battleFormName != null
        ? _capitalizeHyphenated(battleFormName)
        : baseName;

    // Gender tag: (M) for male, (F) for female, empty for genderless.
    final genderTag = slot.gender == 'male'
        ? ' (M)'
        : slot.gender == 'female'
            ? ' (F)'
            : '';

    final item = slot.heldItemName;
    final itemSuffix = item != null ? ' @ ${item.toCapitalCase()}' : '';

    final header = hasNickname
        ? '$nickname ($speciesDisplay)$genderTag$itemSuffix'
        : '$speciesDisplay$genderTag$itemSuffix';

    final lines = <String>[header];

    if (slot.abilityName != null) {
      lines.add('Ability: ${slot.abilityName!.toCapitalCase()}');
    }

    final level = slot.level ?? 50;
    lines.add('Level: $level');

    if (slot.isShiny) lines.add('Shiny: Yes');

    if (slot.natureName != null) {
      lines.add('${_normalisedNature(slot.natureName!)} Nature');
    }

    // EVs — omit zero values
    final evParts = <String>[];
    void addEv(int? val, String label) {
      if (val != null && val > 0) evParts.add('$val $label');
    }
    addEv(slot.evHp, 'HP');
    addEv(slot.evAtk, 'Atk');
    addEv(slot.evDef, 'Def');
    addEv(slot.evSpa, 'SpA');
    addEv(slot.evSpd, 'SpD');
    addEv(slot.evSpe, 'Spe');
    if (evParts.isNotEmpty) lines.add('EVs: ${evParts.join(' / ')}');

    // IVs — omit stats at their generation-appropriate default. Gen 1/2
    // slots store raw 0–15 DVs (see GenerationMechanics.statMax); PS's own
    // file format always uses the doubled 0–31 IV scale even for Gen 1/2
    // (verified against real Showdown-exported Gen 1/2 teams — every IV
    // value in them is even), so DVs are converted via IV = DV × 2 here.
    // Gen 3+ IVs are already on that scale and used as-is.
    final isDvGen = gen == 1 || gen == 2;
    final ivDefault = isDvGen ? 30 : 31;
    final ivParts = <String>[];
    void addIv(int? val, String label) {
      final raw = val ?? (isDvGen ? 15 : 31);
      final converted = isDvGen ? raw * 2 : raw;
      if (converted != ivDefault) ivParts.add('$converted $label');
    }
    addIv(slot.ivHp, 'HP');
    addIv(slot.ivAtk, 'Atk');
    addIv(slot.ivDef, 'Def');
    addIv(slot.ivSpa, 'SpA');
    addIv(slot.ivSpd, 'SpD');
    addIv(slot.ivSpe, 'Spe');
    if (ivParts.isNotEmpty) lines.add('IVs: ${ivParts.join(' / ')}');

    // Moves — Hidden Power gets its IV-derived type appended, e.g.
    // "Hidden Power [Ice]", matching the syntax PS's parser (and our own
    // import parser) expects.
    for (final move in [slot.move1, slot.move2, slot.move3, slot.move4]) {
      if (move == null) continue;
      final moveLabel = move.toCapitalCase();
      lines.add(move == 'hidden-power'
          ? '- $moveLabel [${hiddenPowerTypeName(
              ivHp: slot.ivHp,
              ivAtk: slot.ivAtk,
              ivDef: slot.ivDef,
              ivSpa: slot.ivSpa,
              ivSpd: slot.ivSpd,
              ivSpe: slot.ivSpe,
              gen: gen,
            )}]'
          : '- $moveLabel');
    }

    blocks.add(lines.join('\n'));
  }

  return blocks.join('\n\n');
}
