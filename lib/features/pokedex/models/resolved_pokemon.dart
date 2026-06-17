import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

/// Merged result of [pokemonDetailProvider], [pokemonSpeciesProvider], and
/// [cosmeticFormsProvider] for a single species.
///
/// Kept alive for the app session by [resolvedPokemonProvider] so that
/// scrolling a Pokédex tile off-screen and back never re-fetches.
class ResolvedPokemon {
  final PokemonEntry detail;
  final PokemonSpeciesEntry species;

  /// Non-default cosmetic form entries from the `pokemon-form` endpoint.
  /// Female sprite patches are already applied (null spriteUrl → constructed
  /// URL), and synthetic female entries are already added for species in
  /// [PokemonDataRegistry.cosmeticGenderDiffPokemon].
  /// Does NOT include variety-based cosmetics — those are fetched on demand
  /// via [pokemonByNameProvider].
  final List<PokemonFormEntry> cosmeticForms;

  const ResolvedPokemon({
    required this.detail,
    required this.species,
    required this.cosmeticForms,
  });

  int get id => detail.id;
  String get name => detail.name;
  String? get speciesName => detail.speciesName;
  String get displaySpeciesName => detail.displaySpeciesName;
  List<String> get formNames => detail.formNames;
  Map<int, String> get types => detail.types;
  Map<String, dynamic>? get sprites => detail.sprites;
  String? get officialArtworkUrl => detail.officialArtworkUrl;
  List<Map<String, dynamic>> get stats => detail.stats;
  List<Map<String, dynamic>> get abilities => detail.abilities;
  List<Map<String, dynamic>> get moves => detail.moves;
  List<PokemonVariety> get varieties => species.varieties;
  String? get generationName => species.generationName;
}
