class ItemEntry {
  final String name;
  final int? cost;
  final String? category; // e.g. 'pokeballs', 'medicine', 'held-items'
  final String? shortEffect;
  final String? spriteUrl;

  const ItemEntry({
    required this.name,
    this.cost,
    this.category,
    this.shortEffect,
    this.spriteUrl,
  });

  factory ItemEntry.fromJson(Map<String, dynamic> json) {
    String? shortEffect;
    final effectEntries = json['effect_entries'] as List?;
    if (effectEntries != null) {
      final en = effectEntries.cast<Map>().firstWhere(
            (e) => e['language']['name'] == 'en',
            orElse: () => {},
          );
      shortEffect = en['short_effect'] as String?;
    }

    final sprites = json['sprites'] as Map?;
    final spriteUrl = sprites?['default'] as String?;

    return ItemEntry(
      name: json['name'] as String,
      cost: json['cost'] as int?,
      category: (json['category'] as Map?)?.cast<String, dynamic>()['name'] as String?,
      shortEffect: shortEffect,
      spriteUrl: spriteUrl,
    );
  }

  String get displayName {
    return name
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  String get categoryLabel {
    if (category == null) return '';
    return category!
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}
