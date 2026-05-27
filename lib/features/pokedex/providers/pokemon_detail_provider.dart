import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final pokemonDetailProvider = FutureProvider.autoDispose.family<PokemonEntry, int>((ref, id) async {
  final pokeApiRepository = ref.read(pokeApiRepositoryProvider);
  return pokeApiRepository.fetchPokemon(id);
});