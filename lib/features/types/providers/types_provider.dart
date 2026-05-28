import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/pokeapi/models/type_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';

final typeProvider =
    FutureProvider.autoDispose.family<TypeEntry, String>((ref, name) async {
  final repo = ref.read(pokeApiRepositoryProvider);
  return repo.fetchType(name);
});
