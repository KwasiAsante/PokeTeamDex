import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Displays a Pokémon sprite or official artwork.
/// Supports a [shiny] toggle that swaps to the shiny URL when true.
/// Falls back to a Poké Ball placeholder on load and an error icon on failure.
class PokemonSprite extends StatelessWidget {
  final String? defaultUrl;
  final String? shinyUrl;
  final bool shiny;
  final double size;
  final BoxFit fit;

  const PokemonSprite({
    super.key,
    required this.defaultUrl,
    this.shinyUrl,
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
      errorWidget: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  static Widget _placeholder(double size) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.catching_pokemon, color: Color(0xFFBDBDBD)),
      );
}
