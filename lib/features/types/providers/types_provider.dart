import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/pokeapi/models/type_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final typeProvider =
    FutureProvider.autoDispose.family<TypeEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchType(name);
});

/// Fetches all 18 types in parallel and returns them as a keyed map.
/// Used to build the full 18×18 effectiveness matrix.
/// Results are individually cached by [typeProvider], so this is fast
/// after the first full load.
final allTypesProvider = FutureProvider<Map<String, TypeEntry>>((ref) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  final results = await Future.wait(kAllTypes.map((t) => repo.fetchType(t)));
  return {for (var i = 0; i < kAllTypes.length; i++) kAllTypes[i]: results[i]};
});
