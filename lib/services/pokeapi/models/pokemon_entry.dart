class PokemonEntry {
  final int id;
  final String name;
  final int height;
  final int weight;
  final Map<int, String> types;
  final String? officialArtworkUrl;
  final Map<String, dynamic>? sprites;

  PokemonEntry({
      required this.id,
      required this.name,
      required this.height,
      required this.weight,
      required this.types,
      this.officialArtworkUrl,
      this.sprites
  });

  factory PokemonEntry.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? sprites = json['sprites'] as Map<String, dynamic>?;
    var entry = PokemonEntry(
      id: json['id'],
      name: json['name'],
      height: json['height'],
      weight: json['weight'],
      types: Map.fromEntries(
        (json['types'] as List<dynamic>).map(
          (type) => MapEntry(type['slot'] as int, type['type']['name'] as String)
        )
      ),
      sprites: sprites,
      officialArtworkUrl: sprites?['other']?['official-artwork']?['front_default']
    );

    return entry;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'height': height,
      'weight': weight,
      'types': types,
      'sprites': sprites
    };
  }

  String? getImageUrl() {
    if (officialArtworkUrl != null && officialArtworkUrl!.isNotEmpty) {
      return officialArtworkUrl;
    }

    return sprites!['front_default'];
  }

  String displayHeight() {
    return "Height: ${(height / 10).toStringAsFixed(1)} m";
  }

  String displayWeight() {
    return "Weight: ${(weight / 10).toStringAsFixed(1)} kg";
  }
}