import 'package:poke_team_dex/services/pokemon_resolved/models.dart';

class PokemonEntry {
  final int id;
  final String name;

  /// The bare species name from the `species` field of the `/pokemon` response
  /// (e.g. `"wormadam"` when `name` is `"wormadam-plant"`).  Null for entries
  /// fetched from older cached responses that pre-date this field.
  final String? speciesName;
  final int height;
  final int weight;
  final int? baseExperience;
  final List<String> types; // was Map<int, String>
  final String? officialArtworkUrl;
  final Map<String, dynamic>? sprites;
  final Map<String, int> stats; // was List<Map<String, dynamic>>
  final List<AbilityInfo> abilities; // was List<Map<String, dynamic>>
  final List<MoveSummary> moves; // was List<Map<String, dynamic>>

  /// Alternative form names for this Pokémon (e.g. ["aegislash-shield","aegislash-blade"]).
  final List<String> formNames;

  PokemonEntry({
    required this.id,
    required this.name,
    this.speciesName,
    required this.height,
    required this.weight,
    this.baseExperience,
    required this.types,
    this.officialArtworkUrl,
    this.sprites,
    this.stats = const {},
    this.abilities = const [],
    this.moves = const [],
    this.formNames = const [],
  });

  factory PokemonEntry.fromJson(Map<String, dynamic> json) {
    final sprites = json['sprites'] as Map<String, dynamic>?;
    final rawTypes = json['types'] as List<dynamic>? ?? [];
    final sortedTypes = List.of(rawTypes)
      ..sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));

    return PokemonEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      speciesName: json['species']?['name'] as String?,
      height: json['height'] as int,
      weight: json['weight'] as int,
      baseExperience: json['base_experience'] as int?,
      types: sortedTypes.map((t) => t['type']['name'] as String).toList(),
      sprites: sprites,
      officialArtworkUrl:
          sprites?['other']?['official-artwork']?['front_default'] as String?,
      stats: Map.fromEntries(
        (json['stats'] as List<dynamic>? ?? []).map(
          (s) => MapEntry(
            (s as Map<String, dynamic>)['stat']['name'] as String,
            s['base_stat'] as int,
          ),
        ),
      ),
      abilities: (json['abilities'] as List<dynamic>? ?? [])
          .map((a) => AbilityInfo.fromPokeApi(a as Map<String, dynamic>))
          .toList(),
      moves: (json['moves'] as List<dynamic>? ?? [])
          .map((m) => MoveSummary.fromPokeApi(m as Map<String, dynamic>))
          .toList(),
      formNames: (json['forms'] as List<dynamic>? ?? [])
          .map((f) => (f as Map)['name'] as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'species_name': speciesName,
        'height': height,
        'weight': weight,
        'base_experience': baseExperience,
        'types': types,
        'sprites': sprites,
        'stats': stats,
        'abilities': abilities.map((a) => a.toJson()).toList(),
        'moves': moves.map((m) => m.toJson()).toList(),
        'form_names': formNames,
      };

  /// Round-trips a [toJson] payload — a flat snapshot of this object's own
  /// fields — as opposed to [fromJson], which parses a raw `/pokemon/{id}`
  /// PokéAPI response (a structurally different, nested shape).
  factory PokemonEntry.fromCacheJson(Map<String, dynamic> json) {
    return PokemonEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      speciesName: json['species_name'] as String?,
      height: json['height'] as int,
      weight: json['weight'] as int,
      baseExperience: json['base_experience'] as int?,
      types: (json['types'] as List).cast<String>(),
      sprites: (json['sprites'] as Map<String, dynamic>?),
      stats: (json['stats'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
      abilities: (json['abilities'] as List<dynamic>? ?? [])
          .map((a) => AbilityInfo.fromJson(a as Map<String, dynamic>))
          .toList(),
      moves: (json['moves'] as List<dynamic>? ?? [])
          .map((m) => MoveSummary.fromJson(m as Map<String, dynamic>))
          .toList(),
      formNames: (json['form_names'] as List?)?.cast<String>() ?? const [],
    );
  }

  String displayId() => '#${id.toString().padLeft(3, '0')}';

  /// Display-ready species name.
  ///
  /// For species whose default variety name has a form suffix baked in
  /// (e.g. `name = "wormadam-plant"`, `speciesName = "wormadam"`), returns
  /// the bare species name capitalised ("Wormadam").  For normal species where
  /// the variety name equals the species name, returns the capitalised name as
  /// usual ("Charizard", "Mr-Mime" → "Mr Mime").
  String get displaySpeciesName {
    final sn = speciesName;
    if (sn != null && name.startsWith('$sn-')) {
      return sn
          .split('-')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return name
        .split('-')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// The form-suffix portion of [name] for "no-plain-form" species.
  ///
  /// Returns `"plant"` when `name = "wormadam-plant"` and
  /// `speciesName = "wormadam"`, so callers can label the default form chip
  /// "Plant" instead of the generic "Default".  Returns `null` for normal
  /// species (where the variety name equals the species name).
  String? get defaultFormLabel {
    final sn = speciesName;
    if (sn != null && name.startsWith('$sn-')) {
      return name.substring(sn.length + 1);
    }
    return null;
  }

  String? get officialArtworkShinyUrl =>
      sprites?['other']?['official-artwork']?['front_shiny'] as String?;

  String? getImageUrl() {
    if (officialArtworkUrl != null && officialArtworkUrl!.isNotEmpty) {
      return officialArtworkUrl;
    }
    return sprites?['front_default'] as String?;
  }

  String displayHeight() => '${(height / 10).toStringAsFixed(1)} m';
  String displayWeight() => '${(weight / 10).toStringAsFixed(1)} kg';
}
