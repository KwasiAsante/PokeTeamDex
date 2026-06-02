import 'package:drift/drift.dart';

class Favorites extends Table {
  IntColumn get pokemonId => integer()();

  @override
  Set<Column> get primaryKey => {pokemonId};
}
