class PokemonEntry {
  final int id;
  final String name;
  final int height;
  final int weight;
  final int? baseExperience;
  final Map<int, String> types;
  final String? officialArtworkUrl;
  final Map<String, dynamic>? sprites;
  final List<Map<String, dynamic>> stats;
  final List<Map<String, dynamic>> abilities;
  final List<Map<String, dynamic>> moves;
  /// Alternative form names for this Pokémon (e.g. ["aegislash-shield","aegislash-blade"]).
  final List<String> formNames;

  PokemonEntry({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    this.baseExperience,
    required this.types,
    this.officialArtworkUrl,
    this.sprites,
    this.stats = const [],
    this.abilities = const [],
    this.moves = const [],
    this.formNames = const [],
  });

  factory PokemonEntry.fromJson(Map<String, dynamic> json) {
    final sprites = json['sprites'] as Map<String, dynamic>?;
    return PokemonEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      height: json['height'] as int,
      weight: json['weight'] as int,
      baseExperience: json['base_experience'] as int?,
      types: Map.fromEntries(
        (json['types'] as List<dynamic>).map(
          (t) => MapEntry(t['slot'] as int, t['type']['name'] as String),
        ),
      ),
      sprites: sprites,
      officialArtworkUrl:
          sprites?['other']?['official-artwork']?['front_default'] as String?,
      stats: (json['stats'] as List?)
              ?.map((s) => Map<String, dynamic>.from(s as Map))
              .toList() ??
          [],
      abilities: (json['abilities'] as List?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          [],
      moves: (json['moves'] as List?)
              ?.map((m) => Map<String, dynamic>.from(m as Map))
              .toList() ??
          [],
      formNames: (json['forms'] as List?)
              ?.map((f) => (f as Map)['name'] as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'height': height,
        'weight': weight,
        'base_experience': baseExperience,
        'types': types,
        'sprites': sprites,
        'stats': stats,
        'abilities': abilities,
        'moves': moves,
      };

  String displayId() => '#${id.toString().padLeft(3, '0')}';

  String? getImageUrl() {
    if (officialArtworkUrl != null && officialArtworkUrl!.isNotEmpty) {
      return officialArtworkUrl;
    }
    return sprites?['front_default'] as String?;
  }

  String displayHeight() => '${(height / 10).toStringAsFixed(1)} m';
  String displayWeight() => '${(weight / 10).toStringAsFixed(1)} kg';
}
