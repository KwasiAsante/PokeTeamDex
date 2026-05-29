import 'package:change_case/change_case.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

/// Generates a Pokémon Showdown-compatible export string for [slots].
///
/// Fields not yet stored in the local DB (ability, nature, held item, moves,
/// EVs, IVs, level, shiny) are omitted — Showdown accepts partial entries and
/// fills them in with defaults. These fields will be added when the full Slot
/// Config screen is implemented.
Future<String> buildShowdownExport(
  List<TeamSlot> slots,
  PokeApiRepository pokeApi,
) async {
  final blocks = <String>[];

  for (final slot in slots..sort((a, b) => a.slot.compareTo(b.slot))) {
    final pokemon = await pokeApi.fetchPokemon(slot.pokemonId);
    final speciesName = pokemon.name.toCapitalCase();
    final nickname = slot.nickname?.trim();

    final header = (nickname != null && nickname.isNotEmpty && nickname != speciesName)
        ? '$nickname ($speciesName)'
        : speciesName;

    blocks.add(header);
  }

  return blocks.join('\n\n');
}
