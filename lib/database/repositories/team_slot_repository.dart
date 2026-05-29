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
}
