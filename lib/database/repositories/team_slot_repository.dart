import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

class TeamSlotRepository {
  TeamSlotRepository(this._db);
  final AppDatabase _db;

  Stream<List<TeamSlot>> watchByTeam(int teamId) =>
      (_db.select(_db.teamSlots)
            ..where((s) => s.teamId.equals(teamId))
            ..orderBy([(s) => OrderingTerm.asc(s.slot)]))
          .watch();

  Future<TeamSlot?> getByTeamAndSlot(int teamId, int slot) =>
      (_db.select(_db.teamSlots)
            ..where((s) => s.teamId.equals(teamId) & s.slot.equals(slot)))
          .getSingleOrNull();

  Future<List<TeamSlot>> getByTeam(int teamId) =>
      (_db.select(_db.teamSlots)
            ..where((s) => s.teamId.equals(teamId))
            ..orderBy([(s) => OrderingTerm.asc(s.slot)]))
          .get();

  Future<int> insert(TeamSlotsCompanion entry) =>
      _db.into(_db.teamSlots).insert(entry);

  Future<bool> update(TeamSlotsCompanion entry) =>
      _db.update(_db.teamSlots).replace(entry);

  Future<int> deleteSlot(int teamId, int slot) =>
      (_db.delete(_db.teamSlots)
            ..where((s) => s.teamId.equals(teamId) & s.slot.equals(slot)))
          .go();

  Future<int> deleteAllForTeam(int teamId) =>
      (_db.delete(_db.teamSlots)..where((s) => s.teamId.equals(teamId))).go();

  /// All non-deleted slots that contain [pokemonId] across every team.
  Stream<List<TeamSlot>> watchByPokemonId(int pokemonId) =>
      (_db.select(_db.teamSlots)
            ..where(
              (s) => s.pokemonId.equals(pokemonId) & s.isDeleted.equals(false),
            ))
          .watch();

  /// Updates only the slot-position column — safe to call during reorder.
  Future<int> updateSlotPosition(int id, int newSlot) =>
      (_db.update(_db.teamSlots)..where((s) => s.id.equals(id)))
          .write(TeamSlotsCompanion(slot: Value(newSlot)));

  /// Partial-updates only instanceId, bumping syncStatus and updatedAt.
  Future<int> setInstanceId(int slotId, int? instanceId) =>
      (_db.update(_db.teamSlots)..where((s) => s.id.equals(slotId))).write(
        TeamSlotsCompanion(
          instanceId: Value(instanceId),
          syncStatus: const Value('pending'),
          updatedAt: Value(DateTime.now()),
        ),
      );
}
