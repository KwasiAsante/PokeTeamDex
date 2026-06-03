import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poke_team_dex/database/app_database.dart';

class PokemonInstanceRepository {
  PokemonInstanceRepository(this._db);
  final AppDatabase _db;

  // ── Create ────────────────────────────────────────────────────────────────

  /// Creates a new origin instance for a Pokémon (no parent).
  Future<int> createOrigin({
    required int pokemonId,
    String? nickname,
  }) async {
    final aliases = nickname != null ? jsonEncode([nickname]) : null;
    return _db.into(_db.pokemonInstances).insert(
          PokemonInstancesCompanion.insert(
            pokemonId: pokemonId,
            nicknameAliases: Value(aliases),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Creates a new iteration linked to [parentInstanceId], inheriting its
  /// ribbons and prepending any new nickname to the alias history.
  Future<int> createIteration({
    required int pokemonId,
    required int parentInstanceId,
    String? newNickname,
  }) async {
    final parent = await getById(parentInstanceId);
    if (parent == null) throw Exception('Parent instance $parentInstanceId not found');

    // Inherit ribbons from parent chain.
    final inheritedRibbons = parent.inheritedRibbons;

    // Prepend the parent's current nickname (from the slot that owns it) to
    // the alias history.  Callers can update aliases after creation.
    final existingAliases = parent.nicknameAliases != null
        ? (jsonDecode(parent.nicknameAliases!) as List).cast<String>()
        : <String>[];
    final aliases = newNickname != null
        ? jsonEncode([newNickname, ...existingAliases])
        : parent.nicknameAliases;

    return _db.into(_db.pokemonInstances).insert(
          PokemonInstancesCompanion.insert(
            pokemonId: pokemonId,
            parentInstanceId: Value(parentInstanceId),
            nicknameAliases: Value(aliases),
            inheritedRibbons: Value(inheritedRibbons),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<PokemonInstance?> getById(int id) =>
      (_db.select(_db.pokemonInstances)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<PokemonInstance?> watchById(int id) =>
      (_db.select(_db.pokemonInstances)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  /// Returns the full chain from the given instance back to the origin,
  /// ordered from oldest (origin) to newest.
  Future<List<PokemonInstance>> getChain(int instanceId) async {
    final chain = <PokemonInstance>[];
    PokemonInstance? current = await getById(instanceId);
    while (current != null) {
      chain.insert(0, current);
      final parentId = current.parentInstanceId;
      current = parentId != null ? await getById(parentId) : null;
    }
    return chain;
  }

  /// Returns all instances whose [parentInstanceId] equals [instanceId]
  /// (i.e. the direct children of this instance in the chain).
  Future<List<PokemonInstance>> getDirectChildren(int instanceId) =>
      (_db.select(_db.pokemonInstances)
            ..where((t) => t.parentInstanceId.equals(instanceId)))
          .get();

  /// Returns all slots currently linked to [instanceId].
  Future<List<TeamSlot>> getSlotsForInstance(int instanceId) =>
      (_db.select(_db.teamSlots)
            ..where((s) =>
                s.instanceId.equalsNullable(instanceId) &
                s.isDeleted.equals(false)))
          .get();

  // ── Update ────────────────────────────────────────────────────────────────

  /// Appends [alias] to this instance's nickname history if not already present.
  Future<void> addNicknameAlias(int instanceId, String alias) async {
    final inst = await getById(instanceId);
    if (inst == null) return;
    final existing = inst.nicknameAliases != null
        ? (jsonDecode(inst.nicknameAliases!) as List).cast<String>()
        : <String>[];
    if (existing.contains(alias)) return;
    final updated = jsonEncode([...existing, alias]);
    await (_db.update(_db.pokemonInstances)
          ..where((t) => t.id.equals(instanceId)))
        .write(PokemonInstancesCompanion(
          nicknameAliases: Value(updated),
          updatedAt: Value(DateTime.now()),
        ));
  }

  /// Merges [ribbonIds] into the inherited ribbons of this instance
  /// (union — no duplicates).
  Future<void> mergeRibbons(int instanceId, List<String> ribbonIds) async {
    final inst = await getById(instanceId);
    if (inst == null) return;
    final existing = inst.inheritedRibbons != null
        ? (jsonDecode(inst.inheritedRibbons!) as List).cast<String>()
        : <String>[];
    final merged = {...existing, ...ribbonIds}.toList();
    await (_db.update(_db.pokemonInstances)
          ..where((t) => t.id.equals(instanceId)))
        .write(PokemonInstancesCompanion(
          inheritedRibbons: Value(jsonEncode(merged)),
          updatedAt: Value(DateTime.now()),
        ));
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(int instanceId) async {
    // Unlink all slots that reference this instance before deleting.
    await (_db.update(_db.teamSlots)
          ..where((s) => s.instanceId.equalsNullable(instanceId)))
        .write(const TeamSlotsCompanion(instanceId: Value(null)));
    await (_db.delete(_db.pokemonInstances)
          ..where((t) => t.id.equals(instanceId)))
        .go();
  }
}
