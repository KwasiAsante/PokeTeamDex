import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart' show MoveSummary;

/// The result of validating one slot against a format.
/// [violations] maps field name → human-readable reason so the slot config
/// screen can highlight the specific field.
class SlotValidation {
  /// Keys: 'ability', 'item', 'move1'–'move4'
  final Map<String, String> violations;

  const SlotValidation(this.violations);

  bool get isValid => violations.isEmpty;
  bool hasViolation(String field) => violations.containsKey(field);
  String? violationFor(String field) => violations[field];
}

/// Validates [slot] against [format] — Layer 1 (generation availability) only.
///
/// [pokemonName] is the PokéAPI name (e.g. "umbreon").
/// [pokemonMoves] is the raw `moves` list from `PokemonEntry` — it includes
/// `version_group_details` so we can check per-game learnsets.
///
/// For a **game format** (type == FormatType.game) we check only the moves
/// learnable in that specific version group.
/// For a **general gen format** we accept moves from any version group within
/// that generation.
/// [availableAbilities]/[availableItems] must already be gen-filtered for
/// [format.gen] by the caller (e.g. `slotValidationProvider` reads
/// `abilitiesListProvider`/`itemsListProvider` and filters by `gen <= format.gen`).
Future<SlotValidation> validateSlot(
  TeamSlot slot,
  String pokemonName,
  List<MoveSummary> pokemonMoves,
  GameFormat format,
  List<BackendAbilityEntry> availableAbilities,
  List<BackendItemEntry> availableItems,
) async {
  return validateSlotSync(
    slot.abilityName,
    slot.heldItemName,
    [slot.move1, slot.move2, slot.move3, slot.move4],
    pokemonName,
    pokemonMoves,
    format,
    availableAbilities,
    availableItems,
  );
}

/// Validates ability/item/move choices against [format] — Layer 1
/// (generation availability) only.
///
/// [pokemonName] is the PokéAPI name (e.g. "umbreon").
/// [pokemonMoves] is the backend-resolved moves list (already merged with PS
/// learnset data server-side) — it includes per-version-group learn details
/// so we can check per-game learnsets.
///
/// [availableAbilities]/[availableItems] must already be gen-filtered for
/// [format.gen] by the caller.
///
/// For a **game format** (type == FormatType.game) we check only the moves
/// learnable in that specific version group.
/// For a **general gen format** we accept moves from any version group within
/// that generation.
SlotValidation validateSlotSync(
  String? abilityName,
  String? heldItemName,
  List<String?> moves,
  String pokemonName,
  List<MoveSummary> pokemonMoves,
  GameFormat format,
  List<BackendAbilityEntry> availableAbilities,
  List<BackendItemEntry> availableItems,
) {
  final gen = format.gen;
  final m = GenerationMechanics.forGen(gen);
  final violations = <String, String>{};

  if (abilityName != null) {
    if (!m.hasAbilities) {
      violations['ability'] = 'Abilities don\'t exist in Gen $gen';
    } else if (!availableAbilities.any((a) => a.name == abilityName)) {
      violations['ability'] = '${_display(abilityName)} not available in Gen $gen';
    }
  }

  if (heldItemName != null) {
    if (!m.hasItems) {
      violations['item'] = 'Held items don\'t exist in Gen $gen';
    } else if (!availableItems.any((i) => i.name == heldItemName)) {
      violations['item'] = '${_display(heldItemName)} not available in Gen $gen';
    }
  }

  final learnset = buildLearnsetForFormat(pokemonMoves, format);
  for (int i = 0; i < moves.length; i++) {
    final moveName = moves[i];
    if (moveName == null) continue;
    if (learnset.contains(moveName)) continue;
    violations['move${i + 1}'] =
        '${_display(moveName)} not learnable in ${_formatLabel(format)}';
  }

  return SlotValidation(violations);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns the set of move names (PokéAPI hyphenated format) learnable in
/// [format]. Supplements PokéAPI version-group data with PS learnset data so
/// that moves PokéAPI incorrectly attributes to a later gen are still included
/// (e.g. Charizard's Dragon Dance is listed in Gen 8/9 by PokéAPI but was
/// available in Gen 6 via move tutors) — the backend's `/pokemon/moves`
/// endpoint already merges PS learnset data server-side (including
/// event-exclusive moves), so [pokemonMoves] itself is sufficient here.
Set<String> buildLearnsetForFormat(
  List<MoveSummary> pokemonMoves,
  GameFormat format,
) {
  return _buildLearnset(pokemonMoves, format);
}

Set<String> _buildLearnset(
  List<MoveSummary> pokemonMoves,
  GameFormat format,
) {
  // For the move PICKER we accept any move the Pokémon could ever have learned
  // in generations 1 through format.gen.  A move learned by breeding/tutoring/
  // event in an earlier generation can be transferred to the current format,
  // so restricting to a single version-group would incorrectly exclude legal
  // egg/tutor/prior-evolution moves.
  //
  // Strict legality checking (e.g. "does this specific game allow this move?")
  // is left to the validation layer which shows warning badges separately.
  final allAcceptedGroups = <String>{};
  for (int g = 1; g <= format.gen; g++) {
    allAcceptedGroups.addAll(PokemonDataRegistry.instance.genToVersionGroups[g] ?? []);
  }

  if (allAcceptedGroups.isEmpty) {
    // Unknown generation — fall back to accepting everything.
    return pokemonMoves.map((m) => m.name).toSet();
  }

  final result = <String>{};
  for (final moveData in pokemonMoves) {
    final moveName = moveData.name;
    final learnable = moveData.learnDetails.any((d) {
      return allAcceptedGroups.contains(d.versionGroup);
    });
    if (learnable) result.add(moveName);
  }

  return result;
}

/// Returns move names learnable by any prior evolution (in [ancestorMoveSets])
/// for [format] that the current Pokémon ([currentMoves]) cannot learn in
/// [format]. These are moves that must be learned before the Pokémon evolves.
///
/// [pokemonName] and [formatService] are forwarded to [buildLearnsetForFormat]
/// for the current Pokémon's PS supplementary learnset cross-check. Each
/// ancestor's PS cross-check is keyed by that ancestor's own species name —
/// e.g. gift Dratini's event-exclusive Extreme Speed must be looked up under
/// "dratini", not "dragonite", or it would never be recognized as learnable
/// by any prior evolution.
///
/// [currentLearnset] lets a caller that already built the current Pokémon's
/// learnable-move set (with the same [currentMoves]/[format]/[pokemonName]/
/// [formatService]) pass it straight through — `buildLearnsetForFormat` walks
/// that exact set elsewhere (e.g. the move picker) shouldn't pay for it twice.
Set<String> buildPriorEvoExclusiveMoveNames({
  required List<MoveSummary> currentMoves,
  required List<({String speciesName, List<MoveSummary> moves})> ancestorMoveSets,
  required GameFormat format,
  Set<String>? currentLearnset,
}) {
  final current = currentLearnset ?? buildLearnsetForFormat(currentMoves, format);
  final ancestorAll = <String>{};
  for (final ancestor in ancestorMoveSets) {
    ancestorAll.addAll(buildLearnsetForFormat(ancestor.moves, format));
  }
  return ancestorAll.difference(current);
}

String _display(String id) => id
    .split('-')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _formatLabel(GameFormat f) =>
    f.type == FormatType.game ? f.name : 'Gen ${f.gen}';
