import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_service.dart';

final formatServiceProvider = Provider<FormatService>((ref) {
  return FormatService(ref.read(apiClientProvider));
});

/// All formats, grouped by type.
final allFormatsProvider = FutureProvider<List<GameFormat>>((ref) async {
  final svc = ref.watch(formatServiceProvider);
  await svc.initialize();
  return svc.formats;
});

final generalFormatsProvider = FutureProvider<List<GameFormat>>((ref) async {
  final svc = ref.watch(formatServiceProvider);
  await svc.initialize();
  return svc.formatsOfType(FormatType.general);
});

final gameFormatsProvider = FutureProvider<List<GameFormat>>((ref) async {
  final svc = ref.watch(formatServiceProvider);
  await svc.initialize();
  return svc.formatsOfType(FormatType.game);
});

/// Learnset for a specific Pokémon in a specific generation.
final learnsetProvider = FutureProvider.autoDispose
    .family<List<String>, ({String pokemon, int gen})>((ref, args) async {
  final svc = ref.watch(formatServiceProvider);
  await svc.initialize();
  return svc.learnsetForGen(args.pokemon, args.gen);
});

/// Items available in a generation (Layer 1 filtered).
final itemsForGenProvider =
    FutureProvider.autoDispose.family<List<PsItemEntry>, int>((ref, gen) async {
  final svc = ref.watch(formatServiceProvider);
  await svc.initialize();
  return svc.itemsForGen(gen);
});

/// Abilities available in a generation (Layer 1 filtered).
final abilitiesForGenProvider =
    FutureProvider.autoDispose.family<List<PsAbilityEntry>, int>((ref, gen) async {
  final svc = ref.watch(formatServiceProvider);
  await svc.initialize();
  return svc.abilitiesForGen(gen);
});
