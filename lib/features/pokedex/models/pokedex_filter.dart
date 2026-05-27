/// Immutable filter + sort state for the Pokédex list.
class PokedexFilter {
  final int? generation;       // 1–9, null = all
  final String? type;          // PokéAPI type name, null = all
  final PokedexSort sort;

  const PokedexFilter({
    this.generation,
    this.type,
    this.sort = PokedexSort.dexNumber,
  });

  PokedexFilter copyWith({
    Object? generation = _sentinel,
    Object? type = _sentinel,
    PokedexSort? sort,
  }) {
    return PokedexFilter(
      generation: generation == _sentinel ? this.generation : generation as int?,
      type: type == _sentinel ? this.type : type as String?,
      sort: sort ?? this.sort,
    );
  }

  bool get isDefault => generation == null && type == null && sort == PokedexSort.dexNumber;
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
