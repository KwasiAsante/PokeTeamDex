import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/encounter_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/move_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart' show MoveSummary;
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart'
    show pokemonMovesProvider;

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
  // Skip variety-based species where every form name corresponds to one of
  // the species' own varieties (e.g. Rotom, Aegislash). For species like
  // Floette whose form names are DIFFERENT from their varieties (floette-red
  // vs variety floette), we should still surface the cosmetic forms.
  if (species.varieties.length > 1) {
    final varietyNames = species.varieties.map((v) => v.name).toSet();
    final allFormsAreVarieties =
        pokemon.formNames.every((fn) => varietyNames.contains(fn));
    if (allFormsAreVarieties) return const [];
  }
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

/// Each prior-evolution species' display name + moves list, oldest ancestor first.
/// Empty for Pokémon with no prior evolutions.
///
/// Ancestor IDs come from PokéAPI evo chain traversal; move data comes from the
/// backend so [MoveLearnDetail] entries are present and [buildLearnsetForFormat]
/// works correctly on the result. When [gen] is null the backend returns all
/// version-group moves; when [gen] is N only gen-N moves are returned.
final priorEvoMoveSetsProvider = FutureProvider.autoDispose.family<
    List<({String speciesName, List<MoveSummary> moves})>, ({int id, int? gen})>(
  (ref, args) async {
    final entries =
        await ref.read(pokeApiRepositoryProvider).fetchPriorEvoEntries(args.id);
    if (entries.isEmpty) return const [];
    final result = <({String speciesName, List<MoveSummary> moves})>[];
    for (final entry in entries) {
      final moves = await ref.read(
        pokemonMovesProvider((id: entry.pokemonId, gen: args.gen)).future,
      );
      result.add((speciesName: entry.speciesName, moves: moves));
    }
    return result;
  },
);
