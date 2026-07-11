import 'dart:convert';
import 'package:flutter/services.dart';

typedef MegaFormEntry = ({String baseSpecies, String megaForm});

class PokemonDataRegistry {
  static PokemonDataRegistry? _instance;
  static PokemonDataRegistry get instance => _instance!;

  // from form_data.dart
  final Map<String, String> psFormExceptions;
  final Map<String, Map<String, String>> cosmeticSpriteStems;

  // from teams/data/form_filter.dart
  final Map<String, String> abilityGatingRules;
  final Map<String, Set<String>> itemGatingRules;
  final Set<int> mutableFormSpeciesIds;

  // from evolution_chain_builder.dart
  final Map<String, String> baseFormNameOverrides;
  final Map<String, String> cosmeticFormLabels;
  final Map<String, String> cosmeticFormHomeUrlOverrides;
  final Map<String, String> cosmeticFormHomeShinyUrlOverrides;
  final Map<String, ({String homeUrl, String shinyUrl})> baseFormCosmeticHomeUrls;
  final Map<String, String> baseFormSuffixOverrides;
  final Map<String, String> regionalFormLookup;

  // from pokedex/logic/form_filter.dart
  final Set<String> battleMeaningfulNames;
  final Set<String> cosmeticVarietyNames;
  final Set<String> noCosmeticFormsPokemon;
  final Set<String> cosmeticGenderDiffPokemon;

  // from mega_forms_data.dart
  final Map<String, MegaFormEntry> megaStoneMap;

  // mega form name → required move (e.g. "rayquaza-mega" → "dragon-ascent") —
  // mirrors the backend's `_mega_form_to_move` (move-triggered Mega
  // Evolutions, as opposed to item-triggered ones already covered by
  // [megaStoneMap]).
  final Map<String, String> megaFormMoveRequirements;

  // from format_models.dart
  final Map<String, String> formatToVersionGroup;
  final Map<int, List<String>> genToVersionGroups;

  // from sprite_resolver.dart
  final Map<String, String> gameIdToVersionPath;
  final Map<int, String> genToDefaultGameId;

  // from pokemon_list_tile.dart
  final Map<String, String?> vgToSubpath;
  final Map<int, String> genToLastVg;

  // variety name → icon sprite_id override (e.g. "calyrex-ice" → "898-ice-rider") —
  // mirrors the backend's `_variety_icon_id_overrides`.
  final Map<String, String> varietyIconIdOverrides;

  PokemonDataRegistry._({
    required this.psFormExceptions,
    required this.cosmeticSpriteStems,
    required this.abilityGatingRules,
    required this.itemGatingRules,
    required this.mutableFormSpeciesIds,
    required this.baseFormNameOverrides,
    required this.cosmeticFormLabels,
    required this.cosmeticFormHomeUrlOverrides,
    required this.cosmeticFormHomeShinyUrlOverrides,
    required this.baseFormCosmeticHomeUrls,
    required this.baseFormSuffixOverrides,
    required this.regionalFormLookup,
    required this.battleMeaningfulNames,
    required this.cosmeticVarietyNames,
    required this.noCosmeticFormsPokemon,
    required this.cosmeticGenderDiffPokemon,
    required this.megaStoneMap,
    required this.megaFormMoveRequirements,
    required this.formatToVersionGroup,
    required this.genToVersionGroups,
    required this.gameIdToVersionPath,
    required this.genToDefaultGameId,
    required this.vgToSubpath,
    required this.genToLastVg,
    required this.varietyIconIdOverrides,
  });

  static Future<void> initialize() async {
    final raw = await rootBundle.loadString('shared/pokemon_registry.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    _instance = PokemonDataRegistry._(
      psFormExceptions: _strMap(j['psFormExceptions']),
      cosmeticSpriteStems: (j['cosmeticSpriteStems'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, _strMap(v)),
      ),
      abilityGatingRules: _strMap(j['abilityGatingRules']),
      itemGatingRules: (j['itemGatingRules'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List).cast<String>().toSet()),
      ),
      mutableFormSpeciesIds: (j['mutableFormSpeciesIds'] as List).cast<int>().toSet(),
      baseFormNameOverrides: _strMap(j['baseFormNameOverrides']),
      cosmeticFormLabels: _strMap(j['cosmeticFormLabels']),
      cosmeticFormHomeUrlOverrides: _strMap(j['cosmeticFormHomeUrlOverrides']),
      cosmeticFormHomeShinyUrlOverrides: _strMap(j['cosmeticFormHomeShinyUrlOverrides']),
      baseFormCosmeticHomeUrls: (j['baseFormCosmeticHomeUrls'] as Map<String, dynamic>).map(
        (k, v) {
          final m = v as Map<String, dynamic>;
          return MapEntry(k, (homeUrl: m['homeUrl'] as String, shinyUrl: m['shinyUrl'] as String));
        },
      ),
      baseFormSuffixOverrides: _strMap(j['baseFormSuffixOverrides']),
      regionalFormLookup: _strMap(j['regionalFormLookup']),
      battleMeaningfulNames: (j['battleMeaningfulNames'] as List).cast<String>().toSet(),
      cosmeticVarietyNames: (j['cosmeticVarietyNames'] as List).cast<String>().toSet(),
      noCosmeticFormsPokemon: (j['noCosmeticFormsPokemon'] as List).cast<String>().toSet(),
      cosmeticGenderDiffPokemon: (j['cosmeticGenderDiffPokemon'] as List).cast<String>().toSet(),
      megaStoneMap: (j['megaStoneMap'] as Map<String, dynamic>).map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(k, (baseSpecies: m['baseSpecies'] as String, megaForm: m['megaForm'] as String));
      }),
      megaFormMoveRequirements: _strMap(j['megaFormMoveRequirements']),
      formatToVersionGroup: _strMap(j['formatToVersionGroup']),
      genToVersionGroups: (j['genToVersionGroups'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), (v as List).cast<String>()),
      ),
      gameIdToVersionPath: _strMap(j['gameIdToVersionPath']),
      genToDefaultGameId: (j['genToDefaultGameId'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as String),
      ),
      vgToSubpath: (j['vgToSubpath'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String?),
      ),
      genToLastVg: (j['genToLastVg'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as String),
      ),
      varietyIconIdOverrides: _strMap(j['varietyIconIdOverrides']),
    );
  }

  static Map<String, String> _strMap(dynamic raw) =>
      (raw as Map<String, dynamic>).cast<String, String>();

  Map<String, String>? _megaFormToItem;

  /// mega form name → required item (e.g. "charizard-mega-x" →
  /// "charizardite-x") — the inverse of [megaStoneMap] (keyed by item name),
  /// mirroring the backend's `_mega_form_to_item`. Computed once, lazily.
  Map<String, String> get megaFormToItem => _megaFormToItem ??= {
        for (final entry in megaStoneMap.entries) entry.value.megaForm: entry.key,
      };

  Map<String, int>? _vgToGen;

  /// PokéAPI version-group name → generation — the inverse of
  /// [genToVersionGroups], mirroring the backend's `LearnsetService._vg_to_gen`
  /// (derived identically from the same `genToVersionGroups` registry data).
  /// Computed once, lazily.
  Map<String, int> get vgToGen => _vgToGen ??= {
        for (final entry in genToVersionGroups.entries)
          for (final vg in entry.value) vg: entry.key,
      };
}
