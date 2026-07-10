class PokemonSpeciesEntry {
  final int id;
  final String name;
  final String? genus;
  final String? generationName;
  final int? genderRate;       // -1 = genderless, 0 = male-only, 8 = female-only
  final int? captureRate;
  final int? baseHappiness;
  final int? hatchCounter;     // egg cycles; steps ≈ (hatchCounter + 1) * 255
  final String? growthRate;
  final List<String> eggGroups;
  final List<FlavorTextEntry> flavorTextEntries;
  final bool isBaby;
  final bool isLegendary;
  final bool isMythical;
  final int? evolutionChainId;
  final List<PokemonVariety> varieties;
  final List<EvolutionChainLink>? evolutionChain; // populated separately

  const PokemonSpeciesEntry({
    required this.id,
    required this.name,
    this.genus,
    this.generationName,
    this.genderRate,
    this.captureRate,
    this.baseHappiness,
    this.hatchCounter,
    this.growthRate,
    required this.eggGroups,
    required this.flavorTextEntries,
    this.isBaby = false,
    this.evolutionChainId,
    this.varieties = const [],
    this.isLegendary = false,
    this.isMythical = false,
    this.evolutionChain,
  });

  factory PokemonSpeciesEntry.fromJson(Map<String, dynamic> json) {
    // English genus
    final genusEntry = (json['genera'] as List?)?.firstWhere(
      (g) => g['language']['name'] == 'en',
      orElse: () => null,
    );

    return PokemonSpeciesEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      genus: genusEntry?['genus'] as String?,
      generationName: json['generation']?['name'] as String?,
      genderRate: json['gender_rate'] as int?,
      captureRate: json['capture_rate'] as int?,
      baseHappiness: json['base_happiness'] as int?,
      hatchCounter: json['hatch_counter'] as int?,
      growthRate: json['growth_rate']?['name'] as String?,
      eggGroups: (json['egg_groups'] as List?)
              ?.map((e) => e['name'] as String)
              .toList() ??
          [],
      flavorTextEntries: (json['flavor_text_entries'] as List?)
              ?.map((e) => FlavorTextEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isBaby: json['is_baby'] as bool? ?? false,
      isLegendary: json['is_legendary'] as bool? ?? false,
      isMythical: json['is_mythical'] as bool? ?? false,
      evolutionChainId: _extractChainId(json['evolution_chain']?['url'] as String?),
      varieties: (json['varieties'] as List?)
              ?.map((v) => PokemonVariety.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Flat cache snapshot of this object's own fields — round-trips with
  /// [fromCacheJson]. Distinct from [fromJson], which parses a raw
  /// `/pokemon-species/{id}` PokéAPI response (a differently-shaped payload).
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'genus': genus,
        'generation_name': generationName,
        'gender_rate': genderRate,
        'capture_rate': captureRate,
        'base_happiness': baseHappiness,
        'hatch_counter': hatchCounter,
        'growth_rate': growthRate,
        'egg_groups': eggGroups,
        'flavor_text_entries': flavorTextEntries.map((e) => e.toJson()).toList(),
        'is_baby': isBaby,
        'is_legendary': isLegendary,
        'is_mythical': isMythical,
        'evolution_chain_id': evolutionChainId,
        'varieties': varieties
            .map((v) => {
                  'is_default': v.isDefault,
                  'name': v.name,
                  'pokemon_id': v.pokemonId,
                })
            .toList(),
      };

  factory PokemonSpeciesEntry.fromCacheJson(Map<String, dynamic> json) {
    return PokemonSpeciesEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      genus: json['genus'] as String?,
      generationName: json['generation_name'] as String?,
      genderRate: json['gender_rate'] as int?,
      captureRate: json['capture_rate'] as int?,
      baseHappiness: json['base_happiness'] as int?,
      hatchCounter: json['hatch_counter'] as int?,
      growthRate: json['growth_rate'] as String?,
      eggGroups: (json['egg_groups'] as List?)?.cast<String>() ?? const [],
      flavorTextEntries: (json['flavor_text_entries'] as List<dynamic>? ?? [])
          .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
          .toList(),
      isBaby: json['is_baby'] as bool? ?? false,
      isLegendary: json['is_legendary'] as bool? ?? false,
      isMythical: json['is_mythical'] as bool? ?? false,
      evolutionChainId: json['evolution_chain_id'] as int?,
      varieties: (json['varieties'] as List<dynamic>? ?? [])
          .map((v) => PokemonVariety(
                isDefault: (v as Map)['is_default'] as bool? ?? false,
                name: v['name'] as String,
                pokemonId: (v['pokemon_id'] as num?)?.toInt(),
              ))
          .toList(),
    );
  }

  static int? _extractChainId(String? url) {
    if (url == null) return null;
    final segments = Uri.parse(url).pathSegments;
    final idStr = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
    return int.tryParse(idStr);
  }

  String genderDisplay() {
    if (genderRate == null || genderRate == -1) return 'Genderless';
    if (genderRate == 0) return '100% ♂';
    if (genderRate == 8) return '100% ♀';
    final femalePct = (genderRate! / 8 * 100).toStringAsFixed(1);
    final malePct = ((8 - genderRate!) / 8 * 100).toStringAsFixed(1);
    return '$malePct% ♂ / $femalePct% ♀';
  }

  int get hatchSteps => hatchCounter != null ? (hatchCounter! + 1) * 255 : 0;

  String get generationLabel {
    if (generationName == null) return '';
    final parts = generationName!.split('-');
    if (parts.length < 2) return generationName!;
    return 'Gen ${parts[1].toUpperCase()}';
  }
}

class FlavorTextEntry {
  final String text;
  final String language;
  final String version;

  const FlavorTextEntry({
    required this.text,
    required this.language,
    required this.version,
  });

  factory FlavorTextEntry.fromJson(Map<String, dynamic> json) {
    return FlavorTextEntry(
      // Mirrors the backend's exact normalization (resolve(),
      // `e["flavor_text"].replace("\n", " ").replace("\f", " ")`) — only
      // newline/form-feed become a single space each; unlike a `\s+`
      // collapse, this does NOT merge consecutive whitespace (e.g. a
      // double-newline becomes two spaces, same as backend).
      text: (json['flavor_text'] as String).replaceAll('\n', ' ').replaceAll('\f', ' '),
      language: json['language']['name'] as String,
      version: json['version']['name'] as String,
    );
  }

  factory FlavorTextEntry.fromBackend(Map<String, dynamic> json) {
    return FlavorTextEntry(
      text: json['text'] as String,
      language: json['language'] as String,
      version: json['version'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'language': language,
        'version': version,
      };
}

// Minimal placeholder — populated by evolution-chain PR
class EvolutionChainLink {
  final int speciesId;
  final String speciesName;
  const EvolutionChainLink({required this.speciesId, required this.speciesName});
}

class PokemonVariety {
  final bool isDefault;
  final String name; // e.g. 'venusaur-mega', 'pikachu-alola-cap'
  // Parsed from the species response's own `pokemon.url` — lets callers
  // build a slim placeholder for this variety (mirrors the backend's
  // `_fetch_varieties` stub-on-fetch-failure path) without needing a
  // successful `/pokemon/{name}` fetch first. Null for varieties built from
  // pre-this-fix cached species data.
  final int? pokemonId;

  const PokemonVariety({required this.isDefault, required this.name, this.pokemonId});

  factory PokemonVariety.fromJson(Map<String, dynamic> json) {
    final pokemonMap = json['pokemon'] as Map;
    return PokemonVariety(
      isDefault: json['is_default'] as bool,
      name: pokemonMap['name'] as String,
      pokemonId: _idFromUrl(pokemonMap['url'] as String?),
    );
  }

  static int? _idFromUrl(String? url) {
    if (url == null) return null;
    final segments = url.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? null : int.tryParse(segments.last);
  }

  String get displayName {
    return name
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}
