import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

class AbilityInfo {
  final String name;
  final bool isHidden;
  final int slot;

  const AbilityInfo({
    required this.name,
    required this.isHidden,
    required this.slot,
  });

  factory AbilityInfo.fromJson(Map<String, dynamic> json) => AbilityInfo(
        // Backend may send Showdown display names ("Sand Veil") or PokéAPI slugs
        // ("sand-veil"). Normalise to slug so abilityProvider can look them up.
        name: (json['name'] as String).toLowerCase().replaceAll(' ', '-'),
        isHidden: json['is_hidden'] as bool,
        slot: json['slot'] as int,
      );

  factory AbilityInfo.fromPokeApi(Map<String, dynamic> json) => AbilityInfo(
        name: (json['ability'] as Map<String, dynamic>)['name'] as String,
        isHidden: json['is_hidden'] as bool,
        slot: json['slot'] as int,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_hidden': isHidden,
        'slot': slot,
      };
}

class MoveLearnDetail {
  final String versionGroup;
  final String method;
  final int level;

  const MoveLearnDetail({
    required this.versionGroup,
    required this.method,
    required this.level,
  });

  factory MoveLearnDetail.fromJson(Map<String, dynamic> json) => MoveLearnDetail(
        versionGroup: json['version_group'] as String,
        method: json['method'] as String,
        level: json['level'] as int,
      );

  factory MoveLearnDetail.fromPokeApi(Map<String, dynamic> json) => MoveLearnDetail(
        versionGroup: (json['version_group'] as Map<String, dynamic>)['name'] as String,
        method: (json['move_learn_method'] as Map<String, dynamic>)['name'] as String,
        level: json['level_learned_at'] as int,
      );

  Map<String, dynamic> toJson() => {
        'version_group': versionGroup,
        'method': method,
        'level': level,
      };
}

class MoveSummary {
  final String name;
  final List<MoveLearnDetail> learnDetails;

  const MoveSummary({required this.name, required this.learnDetails});

  factory MoveSummary.fromJson(Map<String, dynamic> json) => MoveSummary(
        name: json['name'] as String,
        learnDetails: (json['learn_details'] as List<dynamic>)
            .map((d) => MoveLearnDetail.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  factory MoveSummary.fromPokeApi(Map<String, dynamic> json) => MoveSummary(
        name: (json['move'] as Map<String, dynamic>)['name'] as String,
        learnDetails: (json['version_group_details'] as List<dynamic>)
            .map((d) => MoveLearnDetail.fromPokeApi(d as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'learn_details': learnDetails.map((d) => d.toJson()).toList(),
      };
}

class SupplementMove {
  final String name;
  final String displayName;
  final List<int> generations;
  final List<String> methods;

  const SupplementMove({
    required this.name,
    required this.displayName,
    required this.generations,
    required this.methods,
  });

  factory SupplementMove.fromJson(Map<String, dynamic> json) => SupplementMove(
        name: json['name'] as String,
        displayName: json['display_name'] as String,
        generations: List<int>.from(json['generations'] as List),
        methods: List<String>.from(json['methods'] as List),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'display_name': displayName,
        'generations': generations,
        'methods': methods,
      };
}

class SpriteUrlsFull {
  final String? officialArtwork;
  final String? officialArtworkShiny;
  final String? officialArtworkFemale;
  final String? officialArtworkFemaleShiny;
  final String? home;
  final String? homeShiny;
  final String? homeFemale;
  final String? homeFemaleShiny;
  final String? gameFront;
  final String? gameFrontShiny;
  final String? gameFrontFemale;
  final String? gameFrontFemaleShiny;
  // Gen-specific icon sprite.
  // gen 8+: generation-viii/icons/{id}.png
  // gen 7:  generation-vii/icons/{id}.png
  // gen ≤ 6: plain front sprite (no icon directories exist)
  final String? icon;
  // Shiny icon — uses game_front_shiny since no dedicated shiny icon sprites exist.
  final String? iconShiny;
  // Female icon — generation-viii/icons/female/{id}.png (or gen-vii equivalent).
  // Only non-null for Pokémon with visually distinct female sprites.
  final String? iconFemale;
  // Female shiny icon — uses game_front_female_shiny (no dedicated sprites exist).
  final String? iconFemaleShiny;

  const SpriteUrlsFull({
    this.officialArtwork,
    this.officialArtworkShiny,
    this.officialArtworkFemale,
    this.officialArtworkFemaleShiny,
    this.home,
    this.homeShiny,
    this.homeFemale,
    this.homeFemaleShiny,
    this.gameFront,
    this.gameFrontShiny,
    this.gameFrontFemale,
    this.gameFrontFemaleShiny,
    this.icon,
    this.iconShiny,
    this.iconFemale,
    this.iconFemaleShiny,
  });

  factory SpriteUrlsFull.fromJson(Map<String, dynamic> json) => SpriteUrlsFull(
        officialArtwork: json['official_artwork'] as String?,
        officialArtworkShiny: json['official_artwork_shiny'] as String?,
        officialArtworkFemale: json['official_artwork_female'] as String?,
        officialArtworkFemaleShiny: json['official_artwork_female_shiny'] as String?,
        home: json['home'] as String?,
        homeShiny: json['home_shiny'] as String?,
        homeFemale: json['home_female'] as String?,
        homeFemaleShiny: json['home_female_shiny'] as String?,
        gameFront: json['game_front'] as String?,
        gameFrontShiny: json['game_front_shiny'] as String?,
        gameFrontFemale: json['game_front_female'] as String?,
        gameFrontFemaleShiny: json['game_front_female_shiny'] as String?,
        icon: json['icon'] as String?,
        iconShiny: json['icon_shiny'] as String?,
        iconFemale: json['icon_female'] as String?,
        iconFemaleShiny: json['icon_female_shiny'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'official_artwork': officialArtwork,
        'official_artwork_shiny': officialArtworkShiny,
        'official_artwork_female': officialArtworkFemale,
        'official_artwork_female_shiny': officialArtworkFemaleShiny,
        'home': home,
        'home_shiny': homeShiny,
        'home_female': homeFemale,
        'home_female_shiny': homeFemaleShiny,
        'game_front': gameFront,
        'game_front_shiny': gameFrontShiny,
        'game_front_female': gameFrontFemale,
        'game_front_female_shiny': gameFrontFemaleShiny,
        'icon': icon,
        'icon_shiny': iconShiny,
        'icon_female': iconFemale,
        'icon_female_shiny': iconFemaleShiny,
      };
}

class PokemonResolvedBackendResponse {
  final int pokemonId;
  final int gen;
  final String name;
  final List<String> types;
  final Map<String, int> baseStats;
  final List<AbilityInfo> abilities;
  final int height;
  final int weight;
  final int? baseExperience;
  final String? speciesName;
  final List<MoveSummary> moves;
  final String? movesUrl;
  final List<SupplementMove> supplementMoves;
  final List<Map<String, dynamic>>? smogonAnalyses;
  final List<Map<String, dynamic>> varieties;
  final List<FormBackendData> forms;
  final SpriteUrlsFull spriteUrls;
  final String? genus;
  final String generationName;
  final int? genderRate;
  final int? captureRate;
  final int? baseHappiness;
  final int? hatchCounter;
  final String? growthRate;
  final List<String> eggGroups;
  final List<FlavorTextEntry> flavorTextEntries;
  final String? flavorTextUrl;
  final bool isBaby;
  final bool isLegendary;
  final bool isMythical;
  final bool isMega;
  final bool isBattleOnly;
  final bool isGmax;
  final String? associatedItem;
  final String? associatedMove;
  final String? associatedAbility;
  final int? evolutionChainId;

  const PokemonResolvedBackendResponse({
    required this.pokemonId,
    required this.gen,
    required this.name,
    required this.types,
    required this.baseStats,
    required this.abilities,
    required this.height,
    required this.weight,
    this.baseExperience,
    this.speciesName,
    required this.moves,
    this.movesUrl,
    required this.supplementMoves,
    this.smogonAnalyses,
    required this.varieties,
    required this.forms,
    required this.spriteUrls,
    this.genus,
    required this.generationName,
    this.genderRate,
    this.captureRate,
    this.baseHappiness,
    this.hatchCounter,
    this.growthRate,
    required this.eggGroups,
    required this.flavorTextEntries,
    this.flavorTextUrl,
    required this.isBaby,
    required this.isLegendary,
    required this.isMythical,
    this.isMega = false,
    this.isBattleOnly = false,
    this.isGmax = false,
    this.associatedItem,
    this.associatedMove,
    this.associatedAbility,
    this.evolutionChainId,
  });

  factory PokemonResolvedBackendResponse.fromJson(Map<String, dynamic> json) {
    return PokemonResolvedBackendResponse(
      pokemonId: json['pokemon_id'] as int,
      gen: json['gen'] as int,
      name: json['name'] as String,
      types: (json['types'] as List).map((t) => (t as String).toLowerCase()).toList(),
      baseStats: Map<String, int>.from(
        (json['base_stats'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      ),
      abilities: (json['abilities'] as List<dynamic>)
          .map((a) => AbilityInfo.fromJson(a as Map<String, dynamic>))
          .toList(),
      height: (json['height'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
      baseExperience: (json['base_experience'] as num?)?.toInt(),
      speciesName: json['species_name'] as String?,
      moves: (json['moves'] as List<dynamic>? ?? [])
          .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
          .toList(),
      movesUrl: json['moves_url'] as String?,
      supplementMoves: (json['supplement_moves'] as List<dynamic>? ?? [])
          .map((m) => SupplementMove.fromJson(m as Map<String, dynamic>))
          .toList(),
      smogonAnalyses: (json['smogon_analyses'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      varieties: (json['varieties'] as List<dynamic>? ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList(),
      forms: (json['forms'] as List<dynamic>? ?? [])
          .map((f) => FormBackendData.fromJson(f as Map<String, dynamic>))
          .toList(),
      spriteUrls: SpriteUrlsFull.fromJson(
          json['sprite_urls'] as Map<String, dynamic>? ?? {}),
      genus: json['genus'] as String?,
      generationName: json['generation_name'] as String? ?? 'generation-ix',
      genderRate: (json['gender_rate'] as num?)?.toInt(),
      captureRate: (json['capture_rate'] as num?)?.toInt(),
      baseHappiness: (json['base_happiness'] as num?)?.toInt(),
      hatchCounter: (json['hatch_counter'] as num?)?.toInt(),
      growthRate: json['growth_rate'] as String?,
      eggGroups: List<String>.from(json['egg_groups'] as List? ?? []),
      flavorTextEntries: (json['flavor_text_entries'] as List<dynamic>? ?? [])
          .map((e) => FlavorTextEntry.fromBackend(e as Map<String, dynamic>))
          .toList(),
      flavorTextUrl: json['flavor_text_url'] as String?,
      isBaby: json['is_baby'] as bool? ?? false,
      isLegendary: json['is_legendary'] as bool? ?? false,
      isMythical: json['is_mythical'] as bool? ?? false,
      isMega: json['is_mega'] as bool? ?? false,
      isBattleOnly: json['is_battle_only'] as bool? ?? false,
      isGmax: json['is_gmax'] as bool? ?? false,
      associatedItem: json['associated_item'] as String?,
      associatedMove: json['associated_move'] as String?,
      associatedAbility: json['associated_ability'] as String?,
      evolutionChainId: (json['evolution_chain_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'pokemon_id': pokemonId,
        'gen': gen,
        'name': name,
        'types': types,
        'base_stats': baseStats,
        'abilities': abilities.map((a) => a.toJson()).toList(),
        'height': height,
        'weight': weight,
        'base_experience': baseExperience,
        'species_name': speciesName,
        'moves': moves.map((m) => m.toJson()).toList(),
        'moves_url': movesUrl,
        'supplement_moves': supplementMoves.map((s) => s.toJson()).toList(),
        'smogon_analyses': smogonAnalyses,
        'varieties': varieties,
        'forms': forms.map((f) => f.toJson()).toList(),
        'sprite_urls': spriteUrls.toJson(),
        'genus': genus,
        'generation_name': generationName,
        'gender_rate': genderRate,
        'capture_rate': captureRate,
        'base_happiness': baseHappiness,
        'hatch_counter': hatchCounter,
        'growth_rate': growthRate,
        'egg_groups': eggGroups,
        'flavor_text_entries': flavorTextEntries.map((e) => e.toJson()).toList(),
        'flavor_text_url': flavorTextUrl,
        'is_baby': isBaby,
        'is_legendary': isLegendary,
        'is_mythical': isMythical,
        'is_mega': isMega,
        'is_battle_only': isBattleOnly,
        'is_gmax': isGmax,
        'associated_item': associatedItem,
        'associated_move': associatedMove,
        'associated_ability': associatedAbility,
        'evolution_chain_id': evolutionChainId,
      };

  /// Constructs a [PokemonEntry] from this backend response.
  ///
  /// Passes typed fields directly — [PokemonEntry] now uses the same typed
  /// representations ([List<String>] types, [Map<String, int>] stats,
  /// [List<AbilityInfo>] abilities, [List<MoveSummary>] moves).
  static const _statKeyMap = {
    'atk': 'attack',
    'def': 'defense',
    'spa': 'special-attack',
    'spd': 'special-defense',
    'spe': 'speed',
  };

  static Map<String, int> _normalizeStats(Map<String, int> stats) {
    return stats.map((k, v) => MapEntry(_statKeyMap[k] ?? k, v));
  }

  PokemonEntry toPokemonEntry() {
    return PokemonEntry(
      id: pokemonId,
      name: name,
      speciesName: speciesName,
      height: height,
      weight: weight,
      baseExperience: baseExperience,
      types: types,
      officialArtworkUrl: spriteUrls.officialArtwork,
      sprites: null,
      stats: _normalizeStats(baseStats),
      abilities: abilities,
      moves: moves,
      formNames: forms.map((f) => f.name).toList(),
    );
  }

  PokemonSpeciesEntry toPokemonSpeciesEntry() => PokemonSpeciesEntry(
        id: pokemonId,
        name: speciesName ?? name,
        genus: genus,
        generationName: generationName,
        genderRate: genderRate,
        captureRate: captureRate,
        baseHappiness: baseHappiness,
        hatchCounter: hatchCounter,
        growthRate: growthRate,
        eggGroups: eggGroups,
        flavorTextEntries: flavorTextEntries,
        isBaby: isBaby,
        isLegendary: isLegendary,
        isMythical: isMythical,
        evolutionChainId: evolutionChainId,
        varieties: varieties
            .map((v) => PokemonVariety(
                  isDefault: v['is_default'] as bool? ?? false,
                  name: (v['name'] as String?) ?? '',
                ))
            .toList(),
      );

  List<PokemonFormEntry> toCosmeticForms() {
    return forms
        .where((f) => !f.isDefault)
        .map((f) => PokemonFormEntry(
              id: f.formId ?? pokemonId,
              name: f.name,
              formName: _extractFormName(f.name, speciesName ?? name),
              isDefault: false,
              spriteUrl: f.spriteUrls?.gameFront ?? f.frontSpriteUrl,
              spriteShinyUrl: f.spriteUrls?.gameFrontShiny,
              officialArtworkUrl: f.spriteUrls?.officialArtwork,
              officialArtworkShinyUrl: f.spriteUrls?.officialArtworkShiny,
            ))
        .toList();
  }

  static String _extractFormName(String formName, String speciesName) {
    final prefix = '$speciesName-';
    if (formName.startsWith(prefix)) return formName.substring(prefix.length);
    return formName;
  }
}

class FormBackendData {
  final String name;
  final int? formId;
  final bool isDefault;
  final String? frontSpriteUrl;
  final SpriteUrlsFull? spriteUrls;

  const FormBackendData({
    required this.name,
    this.formId,
    required this.isDefault,
    this.frontSpriteUrl,
    this.spriteUrls,
  });

  factory FormBackendData.fromJson(Map<String, dynamic> json) => FormBackendData(
        name: json['name'] as String,
        formId: (json['form_id'] as num?)?.toInt(),
        isDefault: json['is_default'] as bool? ?? false,
        frontSpriteUrl: json['front_sprite_url'] as String?,
        spriteUrls: json['sprite_urls'] != null
            ? SpriteUrlsFull.fromJson(json['sprite_urls'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'form_id': formId,
        'is_default': isDefault,
        'front_sprite_url': frontSpriteUrl,
        'sprite_urls': spriteUrls?.toJson(),
      };
}

/// Full variety data returned by [GET /pokemon/varieties/{id}].
///
/// Slim [resolvedPokemonProvider] varieties only carry [name], [pokemonId],
/// [isDefault], and [resolvedUrl]. This model adds [types], [baseStats],
/// [abilities], and [spriteUrls] for use in form picker chips and variety
/// form display.
class VarietyBackendData {
  final String name;
  final int pokemonId;
  final bool isDefault;
  final String? resolvedUrl;
  final List<String>? types;
  final Map<String, int>? baseStats;
  // PS ability format: {"0": "blaze", "1": "fire-spin", "H": "solar-power"}
  final Map<String, String>? abilities;
  final SpriteUrlsFull? spriteUrls;
  // Form classification flags from backend
  final bool? isMega;
  final bool? isBattleOnly;
  final bool? isGmax;
  // Associated trigger: item (e.g. "charizardite-x"), move (e.g. "dragon-ascent"),
  // or ability (e.g. "stance-change"). At most one is non-null per variety.
  final String? associatedItem;
  final String? associatedMove;
  final String? associatedAbility;

  const VarietyBackendData({
    required this.name,
    required this.pokemonId,
    required this.isDefault,
    this.resolvedUrl,
    this.types,
    this.baseStats,
    this.abilities,
    this.spriteUrls,
    this.isMega,
    this.isBattleOnly,
    this.isGmax,
    this.associatedItem,
    this.associatedMove,
    this.associatedAbility,
  });

  factory VarietyBackendData.fromJson(Map<String, dynamic> json) =>
      VarietyBackendData(
        name: json['name'] as String,
        pokemonId: (json['pokemon_id'] as num).toInt(),
        isDefault: json['is_default'] as bool? ?? false,
        resolvedUrl: json['resolved_url'] as String?,
        types: (json['types'] as List<dynamic>?)
            ?.map((t) => t as String)
            .toList(),
        baseStats: (json['base_stats'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toInt())),
        abilities: (json['abilities'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as String)),
        spriteUrls: json['sprite_urls'] != null
            ? SpriteUrlsFull.fromJson(
                json['sprite_urls'] as Map<String, dynamic>)
            : null,
        isMega: json['is_mega'] as bool?,
        isBattleOnly: json['is_battle_only'] as bool?,
        isGmax: json['is_gmax'] as bool?,
        associatedItem: json['associated_item'] as String?,
        associatedMove: json['associated_move'] as String?,
        associatedAbility: json['associated_ability'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'pokemon_id': pokemonId,
        'is_default': isDefault,
        'resolved_url': resolvedUrl,
        'types': types,
        'base_stats': baseStats,
        'abilities': abilities,
        'sprite_urls': spriteUrls?.toJson(),
        'is_mega': isMega,
        'is_battle_only': isBattleOnly,
        'is_gmax': isGmax,
        'associated_item': associatedItem,
        'associated_move': associatedMove,
        'associated_ability': associatedAbility,
      };
}
