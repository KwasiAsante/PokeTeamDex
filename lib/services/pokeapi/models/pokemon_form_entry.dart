/// A cosmetic form resource from `/pokemon-form/{name}`.
///
/// Cosmetic forms (e.g. Burmy's cloaks, Shellos' seas, Unown's letters) share
/// a single `/pokemon/{base}` resource for stats/types/abilities/moves and
/// exist only as `pokemon-form` entries — this model captures just the bits
/// that differ per form: identity and sprite.
class PokemonFormEntry {
  final int id;
  final String name;
  final String formName;
  final bool isDefault;
  final String? spriteUrl;
  final String? spriteShinyUrl;
  /// Official artwork URL (populated for variety-based forms fetched via
  /// /pokemon/{name}; null for form-name-based cosmetics from /pokemon-form).
  final String? officialArtworkUrl;
  final String? officialArtworkShinyUrl;

  PokemonFormEntry({
    required this.id,
    required this.name,
    required this.formName,
    required this.isDefault,
    this.spriteUrl,
    this.spriteShinyUrl,
    this.officialArtworkUrl,
    this.officialArtworkShinyUrl,
  });

  factory PokemonFormEntry.fromJson(Map<String, dynamic> json) {
    final sprites = json['sprites'] as Map<String, dynamic>?;
    return PokemonFormEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      formName: json['form_name'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      spriteUrl: sprites?['front_default'] as String?,
      spriteShinyUrl: sprites?['front_shiny'] as String?,
    );
  }

  /// Flat cache snapshot of this object's own fields — round-trips with
  /// [fromCacheJson]. Distinct from [fromJson], which parses a raw
  /// `/pokemon-form/{name}` PokéAPI response (a differently-shaped payload).
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'form_name': formName,
        'is_default': isDefault,
        'sprite_url': spriteUrl,
        'sprite_shiny_url': spriteShinyUrl,
        'official_artwork_url': officialArtworkUrl,
        'official_artwork_shiny_url': officialArtworkShinyUrl,
      };

  factory PokemonFormEntry.fromCacheJson(Map<String, dynamic> json) {
    return PokemonFormEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      formName: json['form_name'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      spriteUrl: json['sprite_url'] as String?,
      spriteShinyUrl: json['sprite_shiny_url'] as String?,
      officialArtworkUrl: json['official_artwork_url'] as String?,
      officialArtworkShinyUrl: json['official_artwork_shiny_url'] as String?,
    );
  }
}
