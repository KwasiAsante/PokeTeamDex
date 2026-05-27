class AbilityEntry {
  final String name;
  final String? shortEffect;
  final String? longEffect;
  final String? generationName;

  const AbilityEntry({
    required this.name,
    this.shortEffect,
    this.longEffect,
    this.generationName,
  });

  factory AbilityEntry.fromJson(Map<String, dynamic> json) {
    String? shortEffect;
    String? longEffect;

    final effectEntries = json['effect_entries'] as List?;
    if (effectEntries != null) {
      final en = effectEntries.cast<Map>().firstWhere(
            (e) => e['language']['name'] == 'en',
            orElse: () => {},
          );
      shortEffect = en['short_effect'] as String?;
      longEffect = en['effect'] as String?;
    }

    return AbilityEntry(
      name: json['name'] as String,
      shortEffect: shortEffect,
      longEffect: longEffect,
      generationName: json['generation']?['name'] as String?,
    );
  }

  String get displayName {
    return name
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  String get generationLabel {
    if (generationName == null) return '';
    final parts = generationName!.split('-');
    return parts.length >= 2 ? 'Gen ${parts[1].toUpperCase()}' : generationName!;
  }
}
