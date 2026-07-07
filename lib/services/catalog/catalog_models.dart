String _titleCase(String slug) => slug
    .split('-')
    .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

class BackendMoveEntry {
  final String name;
  final String displayName;
  final int gen;
  final String type;
  final String damageClass;
  final int? power;
  final int? accuracy;
  final int? pp;
  final int priority;
  final bool isZMove;
  final bool isMaxMove;
  final String? zMoveBase;
  final Map<String, int> flags;
  final Map<String, dynamic>? secondary;
  final String? contestType;
  final String? target;
  final String? effectShort;
  final String? effect;

  const BackendMoveEntry({
    required this.name,
    required this.displayName,
    required this.gen,
    required this.type,
    required this.damageClass,
    this.power,
    this.accuracy,
    this.pp,
    this.priority = 0,
    this.isZMove = false,
    this.isMaxMove = false,
    this.zMoveBase,
    this.flags = const {},
    this.secondary,
    this.contestType,
    this.target,
    this.effectShort,
    this.effect,
  });

  factory BackendMoveEntry.fromJson(Map<String, dynamic> json) {
    final secondaryData = json['secondary'];
    return BackendMoveEntry(
      name: json['name'] as String,
      displayName: json['display_name'] as String? ?? _titleCase(json['name'] as String),
      gen: (json['gen'] as num?)?.toInt() ?? 0,
      type: (json['type'] as String? ?? '').toLowerCase(),
      damageClass: (json['damage_class'] as String? ?? '').toLowerCase(),
      power: (json['power'] as num?)?.toInt(),
      accuracy: (json['accuracy'] as num?)?.toInt(),
      pp: (json['pp'] as num?)?.toInt(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isZMove: json['is_z_move'] as bool? ?? false,
      isMaxMove: json['is_max_move'] as bool? ?? false,
      zMoveBase: json['z_move_base'] as String?,
      flags: (json['flags'] != null
              ? Map<String, dynamic>.from(json['flags'] as Map)
              : {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      secondary: secondaryData != null
          ? Map<String, dynamic>.from(secondaryData as Map)
          : null,
      contestType: json['contest_type'] as String?,
      target: json['target'] as String?,
      effectShort: json['effect_short'] as String?,
      effect: json['effect'] as String?,
    );
  }

  // Used when backend is unavailable — gen/type/damageClass are empty sentinels.
  // filteredMovesProvider treats empty type/damageClass as "pass all filters".
  factory BackendMoveEntry.fromName(String name) => BackendMoveEntry(
        name: name,
        displayName: _titleCase(name),
        gen: 0,
        type: '',
        damageClass: '',
      );
}

class BackendItemEntry {
  final String name;
  final String displayName;
  final int gen;
  final String? category;
  final String? sprite;
  final int? flingPower;
  final bool isMegaStone;
  final Map<String, String>? megaSpecies;
  final bool isZCrystal;
  final bool isBerry;
  final bool isPlate;
  final bool isMemory;
  final String? effectShort;
  final String? effect;

  const BackendItemEntry({
    required this.name,
    required this.displayName,
    required this.gen,
    this.category,
    this.sprite,
    this.flingPower,
    this.isMegaStone = false,
    this.megaSpecies,
    this.isZCrystal = false,
    this.isBerry = false,
    this.isPlate = false,
    this.isMemory = false,
    this.effectShort,
    this.effect,
  });

  factory BackendItemEntry.fromJson(Map<String, dynamic> json) =>
      BackendItemEntry(
        name: json['name'] as String,
        displayName: json['display_name'] as String? ?? _titleCase(json['name'] as String),
        gen: (json['gen'] as num?)?.toInt() ?? 0,
        category: json['category'] as String?,
        sprite: json['sprite'] as String?,
        flingPower: (json['fling_power'] as num?)?.toInt(),
        isMegaStone: json['is_mega_stone'] as bool? ?? false,
        megaSpecies: (json['mega_species'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as String)),
        isZCrystal: json['is_z_crystal'] as bool? ?? false,
        isBerry: json['is_berry'] as bool? ?? false,
        isPlate: json['is_plate'] as bool? ?? false,
        isMemory: json['is_memory'] as bool? ?? false,
        effectShort: json['effect_short'] as String?,
        effect: json['effect'] as String?,
      );

  factory BackendItemEntry.fromName(String name) => BackendItemEntry(
        name: name,
        displayName: _titleCase(name),
        gen: 0,
      );
}

class BackendAbilityEntry {
  final String name;
  final String displayName;
  final int gen;
  final String? effectShort;
  final String? effect;
  final int? slot;
  final bool isHidden;

  const BackendAbilityEntry({
    required this.name,
    required this.displayName,
    required this.gen,
    this.effectShort,
    this.effect,
    this.slot,
    this.isHidden = false,
  });

  factory BackendAbilityEntry.fromJson(Map<String, dynamic> json) =>
      BackendAbilityEntry(
        name: json['name'] as String,
        displayName: json['display_name'] as String? ?? _titleCase(json['name'] as String),
        gen: (json['gen'] as num?)?.toInt() ?? 0,
        effectShort: json['effect_short'] as String?,
        effect: json['effect'] as String?,
        slot: (json['slot'] as num?)?.toInt(),
        isHidden: json['is_hidden'] as bool? ?? false,
      );

  factory BackendAbilityEntry.fromName(String name) => BackendAbilityEntry(
        name: name,
        displayName: _titleCase(name),
        gen: 0,
      );
}

class PaginatedCatalogResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedCatalogResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedCatalogResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromItem,
  ) =>
      PaginatedCatalogResponse(
        items: (json['items'] as List<dynamic>).map(fromItem).toList(),
        total: (json['total'] as num).toInt(),
        page: (json['page'] as num).toInt(),
        pageSize: (json['page_size'] as num).toInt(),
        totalPages: (json['total_pages'] as num).toInt(),
      );
}
