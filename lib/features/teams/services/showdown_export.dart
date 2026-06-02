import 'package:change_case/change_case.dart';
import 'package:poke_team_dex/database/app_database.dart';
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

/// Generates a Pokémon Showdown-compatible export string for [slots].
///
/// When [teamName] is supplied the output is prefixed with the PS team header:
///   `=== [psFormatId] Team Name ===`
/// [formatLabel] should be the PokeTeamDex format id (e.g. "gen6", "swsh").
/// It is looked up in [kFormatToPsFormat] to get the correct PS format string.
/// If no mapping exists the header is omitted to avoid confusing PS.
Future<String> buildShowdownExport(
  List<TeamSlot> slots,
  PokeApiRepository pokeApi, {
  String? teamName,
  String? formatLabel, // PokeTeamDex format id, not the human-readable name
  // Kept for backwards-compat but unused — callers should pass formatLabel.
  String? formatName,
}) async {
  final blocks = <String>[];

  for (final slot in slots..sort((a, b) => a.slot.compareTo(b.slot))) {
    final pokemon = await pokeApi.fetchPokemon(slot.pokemonId);
    final speciesName = pokemon.name.toCapitalCase();
    final nickname = slot.nickname?.trim();
    final hasNickname =
        nickname != null && nickname.isNotEmpty && nickname != speciesName;

    final item = slot.heldItemName;
    final header = hasNickname
        ? '$nickname ($speciesName)${item != null ? ' @ ${item.toCapitalCase()}' : ''}'
        : '$speciesName${item != null ? ' @ ${item.toCapitalCase()}' : ''}';

    final lines = <String>[header];

    if (slot.abilityName != null) {
      lines.add('Ability: ${slot.abilityName!.toCapitalCase()}');
    }

    final level = slot.level ?? 50;
    lines.add('Level: $level');

    if (slot.isShiny) lines.add('Shiny: Yes');

    if (slot.natureName != null) {
      lines.add('Nature: ${slot.natureName!} Nature');
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

    // Moves
    for (final move in [slot.move1, slot.move2, slot.move3, slot.move4]) {
      if (move != null) lines.add('- ${move.toCapitalCase()}');
    }

    blocks.add(lines.join('\n'));
  }

  final body = blocks.join('\n\n');

  // Prepend header only when we have a team name AND a valid PS format ID.
  if (teamName != null && teamName.isNotEmpty) {
    final psFormat = formatLabel != null ? kFormatToPsFormat[formatLabel] : null;
    final header = psFormat != null
        ? '=== [$psFormat] $teamName ==='
        : '=== $teamName ===';
    return '$header\n\n$body';
  }

  return body;
}
