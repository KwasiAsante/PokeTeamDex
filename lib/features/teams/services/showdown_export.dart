import 'package:change_case/change_case.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

/// Generates a Pokémon Showdown-compatible export string for [slots].
///
/// When [teamName] and [formatName] are supplied the output is prefixed
/// with a PS team header:  `=== [Format Name] Team Name ===`
/// [formatName] should be the human-readable tier name from [GameFormat.name]
/// (e.g. "Gen 9 OU", "Gen 9 Ubers").
Future<String> buildShowdownExport(
  List<TeamSlot> slots,
  PokeApiRepository pokeApi, {
  String? teamName,
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

  // Prepend === [Format] Name === header when a format is set.
  if (teamName != null && teamName.isNotEmpty) {
    final header = formatName != null && formatName.isNotEmpty
        ? '=== [$formatName] $teamName ==='
        : '=== $teamName ===';
    return '$header\n\n$body';
  }

  return body;
}
