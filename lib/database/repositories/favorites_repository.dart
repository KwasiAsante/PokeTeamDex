import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

class FavoritesRepository {
  FavoritesRepository(this._db);
  final AppDatabase _db;

  Stream<Set<int>> watchAll() => _db
      .select(_db.favorites)
      .watch()
      .map((rows) => rows.map((r) => r.pokemonId).toSet());

  Stream<bool> watchIsFavorite(int pokemonId) =>
      (_db.select(_db.favorites)
            ..where((f) => f.pokemonId.equals(pokemonId)))
          .watchSingleOrNull()
          .map((row) => row != null);

  Future<void> toggle(int pokemonId) async {
    final existing = await (_db.select(_db.favorites)
          ..where((f) => f.pokemonId.equals(pokemonId)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.delete(_db.favorites)
            ..where((f) => f.pokemonId.equals(pokemonId)))
          .go();
    } else {
      await _db.into(_db.favorites).insert(
            FavoritesCompanion(pokemonId: Value(pokemonId)),
          );
    }
  }
}
