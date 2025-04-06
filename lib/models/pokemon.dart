class Pokemon {
  final int id;
  final String name;
  final String imageUrl;

  final List<String> types; // Added this

  Pokemon({required this.id, required this.name, required this.imageUrl, required this.types});

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      id: json['id'],
      name: json['name'],
      imageUrl: json['sprites']['front_default'],
      types: (json['types'] as List)
              .map((t) => t['type']['name'].toString())
              .toList(),
    );
  }
}
