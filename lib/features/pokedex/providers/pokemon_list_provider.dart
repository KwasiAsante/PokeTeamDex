import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_list_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final pokemonListProvider = FutureProvider<List<PokemonListEntry>>((ref) async {
  final pokeApiRepository = ref.read(pokeApiRepositoryProvider);
  return pokeApiRepository.fetchPokemonList();
});
final pokemonSearchProvider = StateProvider<String>((ref) => '');
final filteredPokemonListProvider = Provider<AsyncValue<List<PokemonListEntry>>>((ref) {
  final pokemonList = ref.watch(pokemonListProvider);
  final search = ref.watch(pokemonSearchProvider).trim();
  return pokemonList.when(
    data: (data) => AsyncValue.data(data.where((pokemon) => pokemon.name.toLowerCase().contains(search.toLowerCase()) ||
                                                            pokemon.id.toString().contains(search.toLowerCase()) ||
                                                            pokemon.displayId().contains(search.toLowerCase())).toList()),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    loading: () => AsyncValue.loading(),
  );
});