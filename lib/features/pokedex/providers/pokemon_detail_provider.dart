import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/encounter_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
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
  return repo.fetchPokemonByNameOrDefault(name);
});

/// Resolves the non-default `pokemon-form` resources for a cosmetic-form
/// species — one whose alternate appearances exist only as `pokemon-form`
/// entries sharing a single `/pokemon` resource (e.g. Burmy's cloaks,
/// Shellos' seas, Cherrim's Sunshine Form), unlike variety-based forms
/// (Aegislash, Rotom) which each have their own `/pokemon` resource and are
/// surfaced via [pokemonSpeciesProvider]'s varieties instead.
///
/// The form matching the species' default appearance does not always share
/// its name with the species/pokemon resource — Cherrim's default form is
/// "cherrim-overcast" (not "cherrim"), and Xerneas' default is
/// "xerneas-neutral" despite "xerneas-active" being listed first in `forms`.
/// Only the form resource's own `is_default` flag is reliable, so every
/// candidate is resolved and filtered by it.
///
/// Returns `[]` for species with a single form or multiple varieties —
/// no `pokemon-form` requests are made for the vast majority of species
/// that have no cosmetic forms (the `pokemon`/`pokemon-species` lookups
/// that gate this are already cached by other providers).
final cosmeticFormsProvider = FutureProvider.autoDispose
    .family<List<PokemonFormEntry>, String>((ref, pokemonName) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  final pokemon = await repo.fetchPokemonByName(pokemonName);
  if (pokemon.formNames.length <= 1) return const [];
  final species = await repo.fetchPokemonSpecies(pokemon.id);
  if (species.varieties.length > 1) return const [];
  final forms = await Future.wait(pokemon.formNames.map(repo.fetchPokemonForm));
  return forms.where((f) => !f.isDefault).toList();
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

/// Each prior-evolution species' display name + raw PokeAPI moves list, oldest
/// ancestor first. Empty for Pokémon with no prior evolutions.
final priorEvoMoveSetsProvider = FutureProvider.autoDispose.family<
    List<({String speciesName, List<Map<String, dynamic>> moves})>, int>(
  (ref, pokemonId) =>
      ref.read(pokeApiRepositoryProvider).fetchPriorEvoMoveSets(pokemonId),
);
