class MoveEntry {
  final String name;
  final String? typeName;
  final String? damageClass; // 'physical', 'special', 'status'
  final int? power;
  final int? accuracy;
  final int? pp;
  final String? shortEffect;

  // Extended fields parsed from the full /move/{name} response
  final String? generationName;   // e.g. "generation-i"
  final String? targetName;       // e.g. "selected-pokemon"
  final int priority;
  final String? contestTypeName;
  final MoveMeta? meta;
  final MoveContestCombos? contestCombos;
  final List<MoveMachineRef> machines;
  final List<MovePokemonRef> learnedByPokemon;
  final List<MovePastValue> pastValues;
  final List<MoveFlavorText> flavorTextEntries;

  const MoveEntry({
    required this.name,
    this.typeName,
    this.damageClass,
    this.power,
    this.accuracy,
    this.pp,
    this.shortEffect,
    this.generationName,
    this.targetName,
    this.priority = 0,
    this.contestTypeName,
    this.meta,
    this.contestCombos,
    this.machines = const [],
    this.learnedByPokemon = const [],
    this.pastValues = const [],
    this.flavorTextEntries = const [],
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

    // Meta
    MoveMeta? meta;
    final rawMeta = json['meta'];
    if (rawMeta is Map) {
      meta = MoveMeta.fromJson(rawMeta.cast<String, dynamic>());
    }

    // Contest combos
    MoveContestCombos? combos;
    final rawCombos = json['contest_combos'];
    if (rawCombos is Map) {
      combos = MoveContestCombos.fromJson(rawCombos.cast<String, dynamic>());
    }

    // Machines
    final machines = <MoveMachineRef>[];
    for (final m in (json['machines'] as List? ?? [])) {
      final mMap = m as Map<String, dynamic>;
      machines.add(MoveMachineRef(
        machineUrl: (mMap['machine'] as Map)['url'] as String,
        versionGroupName:
            (mMap['version_group'] as Map)['name'] as String,
      ));
    }

    // Learned by Pokémon (filter to nat dex 1–1025)
    final learnedBy = <MovePokemonRef>[];
    for (final p in (json['learned_by_pokemon'] as List? ?? [])) {
      final pMap = p as Map<String, dynamic>;
      final url = pMap['url'] as String;
      final idStr = url.split('/').where((s) => s.isNotEmpty).last;
      final id = int.tryParse(idStr);
      if (id != null && id >= 1 && id <= 1025) {
        learnedBy.add(MovePokemonRef(
          name: pMap['name'] as String,
          id: id,
        ));
      }
    }

    // Past values
    final pastValues = <MovePastValue>[];
    for (final pv in (json['past_values'] as List? ?? [])) {
      final pvMap = pv as Map<String, dynamic>;
      pastValues.add(MovePastValue.fromJson(pvMap));
    }

    // English flavor texts (one per version group, latest per group)
    final flavorMap = <String, String>{};
    for (final ft in (json['flavor_text_entries'] as List? ?? [])) {
      final ftMap = ft as Map<String, dynamic>;
      if ((ftMap['language'] as Map)['name'] == 'en') {
        final vg = (ftMap['version_group'] as Map)['name'] as String;
        flavorMap[vg] = (ftMap['flavor_text'] as String)
            .replaceAll('\n', ' ')
            .replaceAll('\f', ' ');
      }
    }
    final flavorEntries = flavorMap.entries
        .map((e) => MoveFlavorText(versionGroupName: e.key, text: e.value))
        .toList();

    return MoveEntry(
      name: json['name'] as String,
      typeName: json['type']?['name'] as String?,
      damageClass: json['damage_class']?['name'] as String?,
      power: json['power'] as int?,
      accuracy: json['accuracy'] is int ? json['accuracy'] as int : null,
      pp: json['pp'] as int?,
      shortEffect: shortEffect,
      generationName: json['generation']?['name'] as String?,
      targetName: json['target']?['name'] as String?,
      priority: json['priority'] as int? ?? 0,
      contestTypeName: json['contest_type']?['name'] as String?,
      meta: meta,
      contestCombos: combos,
      machines: machines,
      learnedByPokemon: learnedBy,
      pastValues: pastValues,
      flavorTextEntries: flavorEntries,
    );
  }

  String get displayName => name
      .split('-')
      .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');

  String get categoryIcon {
    switch (damageClass) {
      case 'physical': return '⚔';
      case 'special':  return '✨';
      case 'status':   return '●';
      default:         return '—';
    }
  }
}

// ── Sub-models ────────────────────────────────────────────────────────────────

class MoveMeta {
  final String? ailmentName;
  final int ailmentChance;
  final String? categoryName;
  final int critRate;
  final int drain;
  final int flinchChance;
  final int healing;
  final int? maxHits;
  final int? minHits;
  final int? maxTurns;
  final int? minTurns;
  final int statChance;

  const MoveMeta({
    this.ailmentName,
    this.ailmentChance = 0,
    this.categoryName,
    this.critRate = 0,
    this.drain = 0,
    this.flinchChance = 0,
    this.healing = 0,
    this.maxHits,
    this.minHits,
    this.maxTurns,
    this.minTurns,
    this.statChance = 0,
  });

  factory MoveMeta.fromJson(Map<String, dynamic> j) => MoveMeta(
        ailmentName: (j['ailment'] as Map?)?.cast<String, dynamic>()['name'] as String?,
        ailmentChance: j['ailment_chance'] as int? ?? 0,
        categoryName: (j['category'] as Map?)?.cast<String, dynamic>()['name'] as String?,
        critRate: j['crit_rate'] as int? ?? 0,
        drain: j['drain'] as int? ?? 0,
        flinchChance: j['flinch_chance'] as int? ?? 0,
        healing: j['healing'] as int? ?? 0,
        maxHits: j['max_hits'] as int?,
        minHits: j['min_hits'] as int?,
        maxTurns: j['max_turns'] as int?,
        minTurns: j['min_turns'] as int?,
        statChance: j['stat_chance'] as int? ?? 0,
      );

  bool get hasNonTrivialData =>
      (ailmentName != null && ailmentName != 'none') ||
      ailmentChance > 0 ||
      critRate > 0 ||
      drain != 0 ||
      flinchChance > 0 ||
      healing != 0 ||
      maxHits != null ||
      maxTurns != null ||
      statChance > 0;
}

class MoveContestCombos {
  final List<String> normalUseBefore;
  final List<String> normalUseAfter;
  final List<String> superUseBefore;
  final List<String> superUseAfter;

  const MoveContestCombos({
    this.normalUseBefore = const [],
    this.normalUseAfter = const [],
    this.superUseBefore = const [],
    this.superUseAfter = const [],
  });

  factory MoveContestCombos.fromJson(Map<String, dynamic> j) {
    List<String> toNames(dynamic raw) {
      if (raw == null || raw is! List) return [];
      return raw.map((e) => (e as Map)['name'] as String).toList();
    }

    final normal = j['normal'] as Map?;
    final superC = j['super'] as Map?;
    return MoveContestCombos(
      normalUseBefore: toNames(normal?['use_before']),
      normalUseAfter:  toNames(normal?['use_after']),
      superUseBefore:  toNames(superC?['use_before']),
      superUseAfter:   toNames(superC?['use_after']),
    );
  }

  bool get hasAny =>
      normalUseBefore.isNotEmpty ||
      normalUseAfter.isNotEmpty ||
      superUseBefore.isNotEmpty ||
      superUseAfter.isNotEmpty;
}

class MoveMachineRef {
  final String machineUrl;
  final String versionGroupName;
  const MoveMachineRef({required this.machineUrl, required this.versionGroupName});
}

class MovePokemonRef {
  final String name;
  final int id;
  const MovePokemonRef({required this.name, required this.id});
  String get displayName => name
      .split('-')
      .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}

class MovePastValue {
  final String versionGroupName;
  final int? power;
  final int? accuracy;
  final int? pp;
  final String? typeName;
  final String? effect;

  const MovePastValue({
    required this.versionGroupName,
    this.power,
    this.accuracy,
    this.pp,
    this.typeName,
    this.effect,
  });

  factory MovePastValue.fromJson(Map<String, dynamic> j) {
    String? effect;
    final entries = j['effect_entries'] as List?;
    if (entries != null && entries.isNotEmpty) {
      final en = entries.cast<Map>().firstWhere(
            (e) => e['language']['name'] == 'en',
            orElse: () => {},
          );
      effect = en['short_effect'] as String?;
    }
    return MovePastValue(
      versionGroupName: (j['version_group'] as Map)['name'] as String,
      power: j['power'] as int?,
      accuracy: j['accuracy'] is int ? j['accuracy'] as int : null,
      pp: j['pp'] as int?,
      typeName: (j['type'] as Map?)?['name'] as String?,
      effect: effect,
    );
  }
}

class MoveFlavorText {
  final String versionGroupName;
  final String text;
  const MoveFlavorText({required this.versionGroupName, required this.text});
}

// ── Unchanged sub-models ──────────────────────────────────────────────────────

class PokemonMoveSlot {
  final String moveName;
  final List<MoveLearnMethod> learnMethods;
  const PokemonMoveSlot({required this.moveName, required this.learnMethods});
}

class MoveLearnMethod {
  final String method;
  final String versionGroup;
  final int? levelLearnedAt;
  const MoveLearnMethod({
    required this.method,
    required this.versionGroup,
    this.levelLearnedAt,
  });
}
