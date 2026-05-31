/// Immutable filter + sort state for the Pokédex list.
class PokedexFilter {
  final int? generation;       // 1–9, null = all
  final String? type;          // PokéAPI type name, null = all
  final String? game;          // format game id (e.g. "emerald"), null = all
  final PokedexSort sort;

  const PokedexFilter({
    this.generation,
    this.type,
    this.game,
    this.sort = PokedexSort.dexNumber,
  });

  PokedexFilter copyWith({
    Object? generation = _sentinel,
    Object? type = _sentinel,
    Object? game = _sentinel,
    PokedexSort? sort,
  }) {
    return PokedexFilter(
      generation: generation == _sentinel ? this.generation : generation as int?,
      type: type == _sentinel ? this.type : type as String?,
      game: game == _sentinel ? this.game : game as String?,
      sort: sort ?? this.sort,
    );
  }

  bool get isDefault =>
      generation == null &&
      type == null &&
      game == null &&
      sort == PokedexSort.dexNumber;
}

enum PokedexSort { dexNumber, name }

// Sentinel for copyWith nullable fields
const Object _sentinel = Object();

/// National Dex ID ranges per generation.
const Map<int, (int, int)> generationRanges = {
  1: (1, 151),
  2: (152, 251),
  3: (252, 386),
  4: (387, 493),
  5: (494, 649),
  6: (650, 721),
  7: (722, 809),
  8: (810, 905),
  9: (906, 1025),
};

/// Maps format game id → list of PokéAPI pokedex names.
/// Games with split regional dexes (e.g. X/Y Kalos) list them in order;
/// they are merged sequentially when building the combined regional dex.
const Map<String, List<String>> kGameToPokedexNames = {
  // Gen 1
  'rb':       ['kanto'],
  'yellow':   ['kanto'],
  // Gen 2
  'gs':       ['original-johto'],
  'crystal':  ['original-johto'],
  // Gen 3
  'rs':       ['hoenn'],
  'emerald':  ['hoenn'],
  'frlg':     ['kanto'],
  // Gen 4
  'dp':       ['original-sinnoh'],
  'platinum': ['extended-sinnoh'],
  'hgss':     ['updated-johto'],
  // Gen 5
  'bw':       ['original-unova'],
  'b2w2':     ['updated-unova'],
  // Gen 6
  'xy':       ['kalos-central', 'kalos-coastal', 'kalos-mountain'],
  'oras':     ['updated-hoenn'],
  // Gen 7
  'sm':       ['original-alola'],
  'usum':     ['updated-alola'],
  // Gen 8
  'swsh':     ['galar'],
  'bdsp':     ['updated-sinnoh'],
  'pla':      ['hisui'],
  // Gen 9
  'sv':       ['paldea'],
};
