import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final teamSlotsProvider =
    StreamProvider.autoDispose.family<List<TeamSlot>, int>((ref, teamId) {
  return ref.watch(teamSlotRepositoryProvider).watchByTeam(teamId);
});

final teamByIdProvider =
    StreamProvider.autoDispose.family<Team?, int>((ref, teamId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.teams)..where((t) => t.id.equals(teamId)))
      .watchSingleOrNull();
});

final slotItemDetailProvider =
    FutureProvider.autoDispose.family<ItemEntry, String>((ref, name) =>
        ref.read(pokeApiRepositoryProvider).fetchItem(name));
