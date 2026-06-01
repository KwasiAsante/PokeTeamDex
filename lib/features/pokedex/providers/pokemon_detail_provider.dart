import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/encounter_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final pokemonDetailProvider =
    FutureProvider.autoDispose.family<PokemonEntry, int>((ref, id) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchPokemon(id);
});

final pokemonSpeciesProvider =
    FutureProvider.autoDispose.family<PokemonSpeciesEntry, int>((ref, id) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchPokemonSpecies(id);
});

final abilityProvider =
    FutureProvider.autoDispose.family<AbilityEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchAbility(name);
});

final pokemonByNameProvider =
    FutureProvider.autoDispose.family<PokemonEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchPokemonByName(name);
});

final evolutionChainProvider =
    FutureProvider.autoDispose.family<EvolutionNode, int>((ref, chainId) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchEvolutionChain(chainId);
});

final moveProvider =
    FutureProvider.autoDispose.family<MoveEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchMove(name);
});

final pokemonEncountersProvider =
    FutureProvider.autoDispose.family<List<EncounterEntry>, int>((ref, id) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchPokemonEncounters(id);
});

/// Pokéathlon stats map (speed/power/skill/stamina/jump → 1–10).
/// Returns null for Pokémon outside Gen I–IV (no data on PokéAPI).
final pokeathlonStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>?, int>((ref, pokemonId) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchPokeathlonStats(pokemonId);
});
