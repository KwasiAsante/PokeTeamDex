class TypeEntry {
  final String name;
  final List<String> doubleDamageTo;
  final List<String> halfDamageTo;
  final List<String> noDamageTo;
  final List<String> doubleDamageFrom;
  final List<String> halfDamageFrom;
  final List<String> noDamageFrom;

  const TypeEntry({
    required this.name,
    required this.doubleDamageTo,
    required this.halfDamageTo,
    required this.noDamageTo,
    required this.doubleDamageFrom,
    required this.halfDamageFrom,
    required this.noDamageFrom,
  });

  factory TypeEntry.fromJson(Map<String, dynamic> json) {
    final dr = json['damage_relations'] as Map<String, dynamic>;

    List<String> names(String key) =>
        (dr[key] as List).map((e) => e['name'] as String).toList();

    return TypeEntry(
      name: json['name'] as String,
      doubleDamageTo: names('double_damage_to'),
      halfDamageTo: names('half_damage_to'),
      noDamageTo: names('no_damage_to'),
      doubleDamageFrom: names('double_damage_from'),
      halfDamageFrom: names('half_damage_from'),
      noDamageFrom: names('no_damage_from'),
    );
  }

  String get displayName =>
      '${name[0].toUpperCase()}${name.substring(1)}';
}

/// All 18 battle types (excludes unknown/shadow).
const kAllTypes = [
  'normal', 'fire', 'water', 'electric', 'grass', 'ice',
  'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug',
  'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy',
];
