class ItemEntry {
  final String name;
  final int? cost;
  final String? category;
  final String? shortEffect;
  final String? longEffect;
  final String? spriteUrl;

  // Extended fields
  final int? flingPower;
  final String? flingEffectName;
  final List<String> attributes;
  final List<ItemFlavorText> flavorTextEntries;
  final List<ItemHeldByPokemon> heldByPokemon;
  final bool hasBabyTrigger;
  final List<ItemMachineRef> machines;

  const ItemEntry({
    required this.name,
    this.cost,
    this.category,
    this.shortEffect,
    this.longEffect,
    this.spriteUrl,
    this.flingPower,
    this.flingEffectName,
    this.attributes = const [],
    this.flavorTextEntries = const [],
    this.heldByPokemon = const [],
    this.hasBabyTrigger = false,
    this.machines = const [],
  });

  factory ItemEntry.fromJson(Map<String, dynamic> json) {
    // Effect text
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

    // Sprite
    final sprites = json['sprites'] as Map?;
    final spriteUrl = sprites?['default'] as String?;

    // Attributes
    final attributes = (json['attributes'] as List? ?? [])
        .map((a) => (a as Map)['name'] as String)
        .toList();

    // Flavor text (English, one entry per version group — take last per group)
    final flavorMap = <String, String>{};
    for (final ft in (json['flavor_text_entries'] as List? ?? [])) {
      final ftMap = ft as Map<String, dynamic>;
      if ((ftMap['language'] as Map)['name'] == 'en') {
        final vg = (ftMap['version_group'] as Map)['name'] as String;
        flavorMap[vg] = (ftMap['text'] as String).replaceAll('\n', ' ');
      }
    }
    final flavorEntries = flavorMap.entries
        .map((e) => ItemFlavorText(versionGroupName: e.key, text: e.value))
        .toList();

    // Held by Pokémon
    final heldBy = <ItemHeldByPokemon>[];
    for (final h in (json['held_by_pokemon'] as List? ?? [])) {
      final hMap = h as Map<String, dynamic>;
      final pokemonMap = hMap['pokemon'] as Map<String, dynamic>;
      final url = pokemonMap['url'] as String;
      final idStr = url.split('/').where((s) => s.isNotEmpty).last;
      final id = int.tryParse(idStr);
      if (id != null && id >= 1 && id <= 1025) {
        final versionDetails = (hMap['version_details'] as List? ?? [])
            .map((vd) => ItemHeldVersionDetail(
                  rarity: (vd as Map)['rarity'] as int,
                  versionName: (vd['version'] as Map)['name'] as String,
                ))
            .toList();
        heldBy.add(ItemHeldByPokemon(
          pokemonName: pokemonMap['name'] as String,
          pokemonId: id,
          versionDetails: versionDetails,
        ));
      }
    }

    // Machines
    final machines = (json['machines'] as List? ?? []).map((m) {
      final mMap = m as Map<String, dynamic>;
      return ItemMachineRef(
        machineUrl: (mMap['machine'] as Map)['url'] as String,
        versionGroupName:
            (mMap['version_group'] as Map)['name'] as String,
      );
    }).toList();

    return ItemEntry(
      name: json['name'] as String,
      cost: json['cost'] as int?,
      category: (json['category'] as Map?)
          ?.cast<String, dynamic>()['name'] as String?,
      shortEffect: shortEffect,
      longEffect: longEffect,
      spriteUrl: spriteUrl,
      flingPower: json['fling_power'] as int?,
      flingEffectName:
          (json['fling_effect'] as Map?)?['name'] as String?,
      attributes: attributes,
      flavorTextEntries: flavorEntries,
      heldByPokemon: heldBy,
      hasBabyTrigger: json['baby_trigger_for'] != null,
      machines: machines,
    );
  }

  String get displayName => name
      .split('-')
      .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');

  String get categoryLabel {
    if (category == null) return '';
    return category!
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}

// ── Sub-models ────────────────────────────────────────────────────────────────

class ItemFlavorText {
  final String versionGroupName;
  final String text;
  const ItemFlavorText({required this.versionGroupName, required this.text});
}

class ItemHeldByPokemon {
  final String pokemonName;
  final int pokemonId;
  final List<ItemHeldVersionDetail> versionDetails;
  const ItemHeldByPokemon({
    required this.pokemonName,
    required this.pokemonId,
    required this.versionDetails,
  });
  String get displayName => pokemonName
      .split('-')
      .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}

class ItemHeldVersionDetail {
  final int rarity;
  final String versionName;
  const ItemHeldVersionDetail(
      {required this.rarity, required this.versionName});
}

class ItemMachineRef {
  final String machineUrl;
  final String versionGroupName;
  const ItemMachineRef(
      {required this.machineUrl, required this.versionGroupName});
}
