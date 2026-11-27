import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A [CachedNetworkImage] that walks an ordered list of [urls], moving to the
/// next one whenever the current one fails to load (404, decode error, …).
/// [errorWidget] is shown only after every URL has failed.
///
/// Used for Pokémon icons: no single PokeAPI icon folder covers every variety
/// (see `iconUrlCandidates` in `sprite_url_builder.dart`), so callers pass
/// the icon candidates followed by any sprite fallbacks.
class FallbackNetworkImage extends StatelessWidget {
  final List<String> urls;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final WidgetBuilder? placeholder;
  final WidgetBuilder errorWidget;

  const FallbackNetworkImage({
    super.key,
    required this.urls,
    required this.errorWidget,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) => _build(context, _dedupe(urls), 0);

  static List<String> _dedupe(List<String> urls) =>
      urls.where((u) => u.isNotEmpty).toSet().toList();

  Widget _build(BuildContext context, List<String> list, int i) {
    if (i >= list.length) return errorWidget(context);
    return CachedNetworkImage(
      imageUrl: list[i],
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: placeholder == null ? null : (ctx, _) => placeholder!(ctx),
      errorWidget: (ctx, _, _) => _build(ctx, list, i + 1),
    );
  }
}
