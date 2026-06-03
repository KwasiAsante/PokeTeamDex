import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Displays a Pokémon sprite or official artwork.
/// Supports a [shiny] toggle that swaps to the shiny URL when true.
/// Falls back to a Poké Ball placeholder on load and an error icon on failure.
class PokemonSprite extends StatelessWidget {
  final String? defaultUrl;
  final String? shinyUrl;
  /// Shown when [defaultUrl] fails to load (e.g. official artwork as fallback
  /// for HOME sprites that may not exist for all forms).
  final String? fallbackUrl;
  final bool shiny;
  final double size;
  final BoxFit fit;

  const PokemonSprite({
    super.key,
    required this.defaultUrl,
    this.shinyUrl,
    this.fallbackUrl,
    this.shiny = false,
    this.size = 96,
    this.fit = BoxFit.contain,
  });

  String? get _resolvedUrl => (shiny && shinyUrl != null) ? shinyUrl : defaultUrl;

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;
    if (url == null || url.isEmpty) {
      return _placeholder(size);
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: fit,
      placeholder: (_, __) => _placeholder(size),
      errorWidget: fallbackUrl != null
          ? (_, __, ___) => CachedNetworkImage(
                imageUrl: fallbackUrl!,
                width: size,
                height: size,
                fit: fit,
                placeholder: (_, __) => _placeholder(size),
                errorWidget: (_, __, ___) => _broken(size),
              )
          : (_, __, ___) => _broken(size),
    );
  }

  static Widget _broken(double size) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.broken_image_outlined),
      );

  static Widget _placeholder(double size) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.catching_pokemon, color: Color(0xFFBDBDBD)),
      );
}

// Helper — build a PokéAPI HOME artwork URL from a numeric Pokémon id.
// HOME sprites have higher quality than official artwork for most Pokémon.
String pokemonHomeUrl(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/$id.png';

String pokemonHomeShinyUrl(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/$id.png';
