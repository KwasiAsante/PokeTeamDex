import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/features/abilities/providers/abilities_provider.dart';
import 'package:poke_team_dex/features/items/providers/items_provider.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_service.dart';
import 'package:poke_team_dex/services/format/slot_validator.dart';

final formatServiceProvider = Provider<FormatService>((ref) {
  return FormatService();
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

  final abilities = await ref.watch(abilitiesListProvider.future);
  final items = await ref.watch(itemsListProvider.future);
  final availableAbilities =
      abilities.where((a) => a.gen <= format.gen).toList();
  final availableItems = items.where((i) => i.gen <= format.gen).toList();

  final pokemon = await ref.watch(
      pokemonDetailProvider(args.slot.pokemonId).future);

  // If the slot has a battle-meaningful variety form selected (e.g. Rotom-Wash),
  // use that variety's move list so form-exclusive moves (Hydro Pump for
  // Rotom-Wash) are not incorrectly flagged as unlearnable.
  final formName = args.slot.formName;
  final effectiveMoves = await () async {
    if (formName == null || formName.isEmpty) return pokemon.moves;
    final varietyName = '${pokemon.name}-$formName';
    try {
      final variety = await ref.watch(pokemonByNameProvider(varietyName).future);
      return variety.moves.isNotEmpty ? variety.moves : pokemon.moves;
    } catch (_) {
      return pokemon.moves;
    }
  }();

  final base = await validateSlot(
      args.slot, pokemon.name, effectiveMoves, format, availableAbilities, availableItems);
  if (base.isValid) return base;

  // Fetch prior-evo move sets and suppress move violations for exclusive moves.
  final priorEvoSets = await ref.watch(
      priorEvoMoveSetsProvider((id: args.slot.pokemonId, gen: null)).future);
  if (priorEvoSets.isEmpty) return base;
  final priorEvoMoves = buildPriorEvoExclusiveMoveNames(
    currentMoves: effectiveMoves,
    ancestorMoveSets: priorEvoSets,
    format: format,
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
