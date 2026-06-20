import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';

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

  /// Full sprite URL set from the backend response.
  /// On the offline fallback path, only [SpriteUrlsFull.officialArtwork] is
  /// populated (derived from [PokemonEntry.officialArtworkUrl]).
  final SpriteUrlsFull spriteUrls;

  /// Additional moves sourced from the backend (Smogon / supplement data).
  /// Empty on the offline fallback path.
  final List<SupplementMove> supplementMoves;

  /// Smogon analysis data returned by the backend, if available.
  /// Null on the offline fallback path.
  final List<Map<String, dynamic>>? smogonAnalyses;

  const ResolvedPokemon({
    required this.detail,
    required this.species,
    required this.cosmeticForms,
    required this.spriteUrls,
    this.supplementMoves = const <SupplementMove>[],
    this.smogonAnalyses,
  });

  int get id => detail.id;
  String get name => detail.name;
  String? get speciesName => detail.speciesName;
  String get displaySpeciesName => detail.displaySpeciesName;
  List<String> get formNames => detail.formNames;
  List<String> get types => detail.types;
  Map<String, dynamic>? get sprites => detail.sprites;
  String? get officialArtworkUrl => detail.officialArtworkUrl;
  Map<String, int> get stats => detail.stats;
  List<AbilityInfo> get abilities => detail.abilities;
  List<MoveSummary> get moves => detail.moves;
  List<PokemonVariety> get varieties => species.varieties;
  String? get generationName => species.generationName;
}
