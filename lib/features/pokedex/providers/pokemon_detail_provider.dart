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
/// Non-default detection mirrors the backend's `_fetch_forms` exactly
/// (position-based: `forms[0]` is assumed to be the default, falling back to
/// "everything but index 0" if that yields nothing) — deliberately NOT each
/// form's own `is_default` API flag, for strict online/offline parity. This
/// assumption is wrong for a small, known set of species where PokéAPI's
/// `forms[0]` disagrees with `is_default` (confirmed: Xerneas — `forms[0]` is
/// "xerneas-active", but "xerneas-neutral" is the real default per its own
/// `is_default` flag, its sprite matching the base species' dex-number
/// sprite, and PS's bundled pokedex.json having no separate "xerneasactive"
/// entry at all). That's a backend limitation this mirrors on purpose rather
/// than "fixing" locally, so online and offline behavior always match.
///
/// Every returned entry's [PokemonFormEntry.isDefault] is forced to `false`
/// — mirrors the backend's `FormData(is_default=False, ...)`, which is
/// always hardcoded rather than read from the form's own flag (since, by
/// construction, everything returned here is already "non-default").
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

  // Mirrors the backend's `_fetch_forms`:
  //   non_defaults = [n for n in form_names if n != species_name and n != form_names[0]]
  //   if not non_defaults: non_defaults = form_names[1:] if len(form_names) > 1 else []
  final formNames = pokemon.formNames;
  var nonDefaultNames = formNames
      .where((n) => n != species.name && n != formNames.first)
      .toList();
  if (nonDefaultNames.isEmpty) {
    nonDefaultNames = formNames.length > 1 ? formNames.sublist(1) : const [];
  }
  if (nonDefaultNames.isEmpty) return const [];

  // Isolate each form fetch — mirrors the backend's `_fetch_forms`, which
  // uses `asyncio.gather(..., return_exceptions=True)` and still emits a
  // degraded entry for a form whose fetch failed rather than dropping every
  // other form too. A single transient PokéAPI failure (timeout, 404) must
  // not take down the entire Pokémon resolution — resolvedPokemonProvider's
  // and pokemonFormsProvider's offline fallbacks both await this unguarded,
  // with no try/catch of their own, so an unhandled rejection here
  // previously propagated all the way out to a full BackendUnavailableException
  // even when everything except the forms/cosmetic chips loaded fine.
  final forms = await Future.wait(nonDefaultNames.map((name) async {
    try {
      return await repo.fetchPokemonForm(name);
    } catch (_) {
      return null;
    }
  }));
  return forms
      .whereType<PokemonFormEntry>()
      .map((f) => f.isDefault ? _withIsDefaultFalse(f) : f)
      .toList();
});

PokemonFormEntry _withIsDefaultFalse(PokemonFormEntry f) => PokemonFormEntry(
      id: f.id,
      name: f.name,
      formName: f.formName,
      isDefault: false,
      spriteUrl: f.spriteUrl,
      spriteShinyUrl: f.spriteShinyUrl,
      officialArtworkUrl: f.officialArtworkUrl,
      officialArtworkShinyUrl: f.officialArtworkShinyUrl,
    );

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
