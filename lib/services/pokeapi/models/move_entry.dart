class MoveEntry {
  final String name;
  final String? typeName;
  final String? damageClass; // 'physical', 'special', 'status'
  final int? power;
  final int? accuracy;
  final int? pp;
  final String? shortEffect;

  const MoveEntry({
    required this.name,
    this.typeName,
    this.damageClass,
    this.power,
    this.accuracy,
    this.pp,
    this.shortEffect,
  });

  factory MoveEntry.fromJson(Map<String, dynamic> json) {
    String? shortEffect;
    final effectEntries = json['effect_entries'] as List?;
    if (effectEntries != null) {
      final en = effectEntries.cast<Map>().firstWhere(
            (e) => e['language']['name'] == 'en',
            orElse: () => {},
          );
      shortEffect = en['short_effect'] as String?;
    }

    return MoveEntry(
      name: json['name'] as String,
      typeName: json['type']?['name'] as String?,
      damageClass: json['damage_class']?['name'] as String?,
      power: json['power'] as int?,
      accuracy: json['accuracy'] as int?,
      pp: json['pp'] as int?,
      shortEffect: shortEffect,
    );
  }

  String get displayName {
    return name
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  String get categoryIcon {
    switch (damageClass) {
      case 'physical':
        return '⚔';
      case 'special':
        return '✨';
      case 'status':
        return '●';
      default:
        return '—';
    }
  }
}

/// A Pokémon's move with the learn methods for a specific version group.
class PokemonMoveSlot {
  final String moveName;
  final List<MoveLearnMethod> learnMethods;

  const PokemonMoveSlot({required this.moveName, required this.learnMethods});
}

class MoveLearnMethod {
  final String method; // 'level-up', 'machine', 'egg', 'tutor'
  final String versionGroup;
  final int? levelLearnedAt;

  const MoveLearnMethod({
    required this.method,
    required this.versionGroup,
    this.levelLearnedAt,
  });
}
