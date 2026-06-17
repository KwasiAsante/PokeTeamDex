import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/models/resolved_pokemon.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';

const _kBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/';

/// Merges [pokemonDetailProvider], [pokemonSpeciesProvider], and
/// [cosmeticFormsProvider] for a single Pokémon ID into one [ResolvedPokemon].
///
/// This provider is **keepAlive** (no `.autoDispose`) — once resolved it stays
/// in memory for the app session. This eliminates the ~100 provider rebuild
/// cycles generated per full scroll pass through the Pokédex list (50 tiles ×
/// 2 autoDispose providers each).
///
/// [pokemonByNameProvider] for user-selected alternate forms (Mega, Gmax,
/// battle varieties) remains a separate autoDispose provider — those are
/// on-demand fetches, not baseline data.
final resolvedPokemonProvider =
    FutureProvider.family<ResolvedPokemon, int>((ref, id) async {
  final detail = await ref.watch(pokemonDetailProvider(id).future);
  final species = await ref.watch(pokemonSpeciesProvider(id).future);

  // cosmeticFormsProvider returns [] for species with ≤1 form or where all
  // form names are varieties. Skip entirely for species known to inherit
  // irrelevant form names from an evolution partner (e.g. Mothim ← Burmy).
  final rawCosmetic =
      PokemonDataRegistry.instance.noCosmeticFormsPokemon.contains(detail.name)
          ? const <PokemonFormEntry>[]
          : await ref.watch(cosmeticFormsProvider(detail.name).future);

  // Patch gender form entries whose /pokemon-form sprite URL is null
  // (frillish-female, jellicent-female) and preserve artwork URLs.
  final patched = rawCosmetic.map((f) {
    if (f.spriteUrl == null && f.formName == 'female') {
      return PokemonFormEntry(
        id: f.id,
        name: f.name,
        formName: f.formName,
        isDefault: f.isDefault,
        spriteUrl: '${_kBase}female/${detail.id}.png',
        spriteShinyUrl: '${_kBase}shiny/female/${detail.id}.png',
        officialArtworkUrl: f.officialArtworkUrl,
        officialArtworkShinyUrl: f.officialArtworkShinyUrl,
      );
    }
    return f;
  }).toList();

  // Synthetic female entry for species with gender-diff sprites but no
  // separate /pokemon-form resource (e.g. Unfezant).
  final cosmeticForms = [
    ...patched,
    if (PokemonDataRegistry.instance.cosmeticGenderDiffPokemon
        .contains(detail.name))
      PokemonFormEntry(
        id: detail.id,
        name: '${detail.name}-female',
        formName: 'female',
        isDefault: false,
        spriteUrl: '${_kBase}female/${detail.id}.png',
        spriteShinyUrl: '${_kBase}shiny/female/${detail.id}.png',
      ),
  ];

  return ResolvedPokemon(
    detail: detail,
    species: species,
    cosmeticForms: cosmeticForms,
  );
});
