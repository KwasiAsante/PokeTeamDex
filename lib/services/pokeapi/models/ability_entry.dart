class AbilityEntry {
  final String name;
  final String? shortEffect;
  final String? longEffect;
  final String? generationName;

  // Extended fields
  final bool isMainSeries;
  final List<AbilityEffectChange> effectChanges;
  final List<AbilityFlavorText> flavorTextEntries;
  final List<AbilityPokemonRef> pokemon;

  const AbilityEntry({
    required this.name,
    this.shortEffect,
    this.longEffect,
    this.generationName,
    this.isMainSeries = true,
    this.effectChanges = const [],
    this.flavorTextEntries = const [],
    this.pokemon = const [],
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

    // Effect changes across generations (English only)
    final effectChanges = <AbilityEffectChange>[];
    for (final ec in (json['effect_changes'] as List? ?? [])) {
      final ecMap = ec as Map<String, dynamic>;
      final entries = ecMap['effect_entries'] as List? ?? [];
      final en = entries.cast<Map>().firstWhere(
            (e) => e['language']['name'] == 'en',
            orElse: () => {},
          );
      final effect = en['effect'] as String?;
      if (effect != null) {
        effectChanges.add(AbilityEffectChange(
          versionGroupName:
              (ecMap['version_group'] as Map)['name'] as String,
          effect: effect,
        ));
      }
    }

    // Flavor text (English, one entry per version group)
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
        .map((e) =>
            AbilityFlavorText(versionGroupName: e.key, text: e.value))
        .toList();

    // Pokémon that have this ability (filter to nat dex 1–1025)
    final pokemonRefs = <AbilityPokemonRef>[];
    for (final p in (json['pokemon'] as List? ?? [])) {
      final pMap = p as Map<String, dynamic>;
      final pokemonData = pMap['pokemon'] as Map<String, dynamic>;
      final url = pokemonData['url'] as String;
      final idStr = url.split('/').where((s) => s.isNotEmpty).last;
      final id = int.tryParse(idStr);
      if (id != null && id >= 1 && id <= 1025) {
        pokemonRefs.add(AbilityPokemonRef(
          pokemonName: pokemonData['name'] as String,
          pokemonId: id,
          isHidden: pMap['is_hidden'] as bool? ?? false,
          slot: pMap['slot'] as int? ?? 1,
        ));
      }
    }
    // Sort: regular abilities first (slot 1, 2), hidden last
    pokemonRefs.sort((a, b) {
      if (a.isHidden != b.isHidden) return a.isHidden ? 1 : -1;
      return a.pokemonId.compareTo(b.pokemonId);
    });

    return AbilityEntry(
      name: json['name'] as String,
      shortEffect: shortEffect,
      longEffect: longEffect,
      generationName: json['generation']?['name'] as String?,
      isMainSeries: json['is_main_series'] as bool? ?? true,
      effectChanges: effectChanges,
      flavorTextEntries: flavorEntries,
      pokemon: pokemonRefs,
    );
  }

  String get displayName => name
      .split('-')
      .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');

  String get generationLabel {
    if (generationName == null) return '';
    final parts = generationName!.split('-');
    return parts.length >= 2
        ? 'Gen ${parts[1].toUpperCase()}'
        : generationName!;
  }
}

// ── Sub-models ────────────────────────────────────────────────────────────────

class AbilityEffectChange {
  final String versionGroupName;
  final String effect;
  const AbilityEffectChange(
      {required this.versionGroupName, required this.effect});
}

class AbilityFlavorText {
  final String versionGroupName;
  final String text;
  const AbilityFlavorText(
      {required this.versionGroupName, required this.text});
}

class AbilityPokemonRef {
  final String pokemonName;
  final int pokemonId;
  final bool isHidden;
  final int slot;
  const AbilityPokemonRef({
    required this.pokemonName,
    required this.pokemonId,
    required this.isHidden,
    required this.slot,
  });
  String get displayName => pokemonName
      .split('-')
      .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}
