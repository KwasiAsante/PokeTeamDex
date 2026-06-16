// lib/services/format/sprite_resolver.dart
//
// Thin wrapper retained for call-site compatibility.
// All resolution logic lives in PokemonDataResolver.resolveFormSprite().

import 'package:poke_team_dex/data/pokemon_data_resolver.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

({
  String? defaultUrl,
  String? shinyUrl,
  String? femaleUrl,
  String? femaleShinyUrl,
  String? fallbackUrl,
  String? fallbackUrl2,
}) resolveSprite({
  required Map<String, dynamic>? sprites,
  required int pokemonId,
  required String pokemonName,
  required String baseSpecies,
  required String? formName,
  required GameFormat? format,
  required bool useFormatSprites,
}) =>
    PokemonDataResolver.resolveFormSprite(
      sprites: sprites,
      pokemonId: pokemonId,
      pokemonName: pokemonName,
      baseSpecies: baseSpecies,
      formName: formName,
      format: format,
      useFormatSprites: useFormatSprites,
    );
