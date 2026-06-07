import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_service.dart';
import 'package:poke_team_dex/services/format/slot_validator.dart';

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

/// Validates a single slot against the team's format (Layer 1 only).
/// Fetches pokemon data internally to access version_group learnsets.
/// Prior-evolution-exclusive moves are excluded from violations.
final slotValidationProvider = FutureProvider.autoDispose
    .family<SlotValidation, ({TeamSlot slot, String formatId})>(
        (ref, args) async {
  final svc = ref.watch(formatServiceProvider);
  await svc.initialize();
  final format = svc.formatById(args.formatId);
  if (format == null) return const SlotValidation({});
  final pokemon = await ref.watch(
      pokemonDetailProvider(args.slot.pokemonId).future);
  final moves = pokemon.moves.cast<Map<String, dynamic>>();
  final base = await validateSlot(args.slot, pokemon.name, moves, format, svc);
  if (base.isValid) return base;

  // Fetch prior-evo move sets and suppress move violations for exclusive moves.
  final priorEvoSets = await ref.watch(
      priorEvoMoveSetsProvider(args.slot.pokemonId).future);
  if (priorEvoSets.isEmpty) return base;
  final priorEvoMoves = buildPriorEvoExclusiveMoveNames(
    currentMoves: moves,
    ancestorMoveSets: priorEvoSets,
    format: format,
    pokemonName: pokemon.name,
    formatService: svc,
  );
  if (priorEvoMoves.isEmpty) return base;

  final filtered = {
    for (final entry in base.violations.entries)
      if (!entry.key.startsWith('move') ||
          !priorEvoMoves.contains(
              [args.slot.move1, args.slot.move2, args.slot.move3, args.slot.move4]
                  [int.parse(entry.key.substring(4)) - 1]))
        entry.key: entry.value,
  };
  return SlotValidation(filtered);
});
