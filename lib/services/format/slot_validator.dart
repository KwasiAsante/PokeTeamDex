import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_service.dart';

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
Future<SlotValidation> validateSlot(
  TeamSlot slot,
  String pokemonName,
  List<Map<String, dynamic>> pokemonMoves,
  GameFormat format,
  FormatService service,
) async {
  await service.initialize();
  final gen = format.gen;
  final m = GenerationMechanics.forGen(gen);
  final violations = <String, String>{};

  // ── Ability ──────────────────────────────────────────────────────────────
  if (slot.abilityName != null) {
    if (!m.hasAbilities) {
      violations['ability'] = 'Abilities don\'t exist in Gen $gen';
    } else {
      final psId = _toPsId(slot.abilityName!);
      final available = service.abilitiesForGen(gen);
      if (!available.any((a) => a.id == psId)) {
        violations['ability'] =
            '${_display(slot.abilityName!)} not available in Gen $gen';
      }
    }
  }

  // ── Held item ─────────────────────────────────────────────────────────────
  if (slot.heldItemName != null) {
    if (!m.hasItems) {
      violations['item'] = 'Held items don\'t exist in Gen $gen';
    } else {
      final psId = _toPsId(slot.heldItemName!);
      final available = service.itemsForGen(gen);
      if (!available.any((i) => i.id == psId)) {
        violations['item'] =
            '${_display(slot.heldItemName!)} not available in Gen $gen';
      }
    }
  }

  // ── Moves — per-game or per-gen learnset (PS-supplemented) ──────────────
  final learnset = buildLearnsetForFormat(
    pokemonMoves, format,
    pokemonName: pokemonName,
    formatService: service,
  );
  final moveSlots = {
    'move1': slot.move1,
    'move2': slot.move2,
    'move3': slot.move3,
    'move4': slot.move4,
  };
  for (final entry in moveSlots.entries) {
    final moveName = entry.value;
    if (moveName != null && !learnset.contains(moveName)) {
      violations[entry.key] =
          '${_display(moveName)} not learnable in ${_formatLabel(format)}';
    }
  }

  return SlotValidation(violations);
}

/// Same logic as [validateSlot] but synchronous — for real-time feedback
/// in the slot config screen where data is already available.
SlotValidation validateSlotSync(
  String? abilityName,
  String? heldItemName,
  List<String?> moves,
  String pokemonName,
  List<Map<String, dynamic>> pokemonMoves,
  GameFormat format,
  FormatService service,
) {
  final gen = format.gen;
  final m = GenerationMechanics.forGen(gen);
  final violations = <String, String>{};

  if (abilityName != null) {
    if (!m.hasAbilities) {
      violations['ability'] = 'Abilities don\'t exist in Gen $gen';
    } else if (!service.abilitiesForGen(gen).any((a) => a.id == _toPsId(abilityName))) {
      violations['ability'] = '${_display(abilityName)} not available in Gen $gen';
    }
  }

  if (heldItemName != null) {
    if (!m.hasItems) {
      violations['item'] = 'Held items don\'t exist in Gen $gen';
    } else if (!service.itemsForGen(gen).any((i) => i.id == _toPsId(heldItemName))) {
      violations['item'] = '${_display(heldItemName)} not available in Gen $gen';
    }
  }

  final learnset = buildLearnsetForFormat(
    pokemonMoves, format,
    pokemonName: pokemonName,
    formatService: service,
  );
  for (int i = 0; i < moves.length; i++) {
    final moveName = moves[i];
    if (moveName != null && !learnset.contains(moveName)) {
      violations['move${i + 1}'] =
          '${_display(moveName)} not learnable in ${_formatLabel(format)}';
    }
  }

  return SlotValidation(violations);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns the set of move names (PokéAPI hyphenated format) learnable in
/// [format]. Supplements PokéAPI version-group data with PS learnset data so
/// that moves PokéAPI incorrectly attributes to a later gen are still included
/// (e.g. Charizard's Dragon Dance is listed in Gen 8/9 by PokéAPI but was
/// available in Gen 6 via move tutors).
///
/// [pokemonName] and [formatService] are optional; when supplied the PS
/// learnset is cross-checked: any move in [pokemonMoves] whose PS id appears
/// in the PS learnset for [format.gen] is included regardless of PokéAPI's
/// version-group data.
Set<String> buildLearnsetForFormat(
  List<Map<String, dynamic>> pokemonMoves,
  GameFormat format, {
  String? pokemonName,
  FormatService? formatService,
}) {
  final result = _buildLearnset(pokemonMoves, format);

  // PS supplementary pass — catches moves PokéAPI links to the wrong gen.
  if (pokemonName != null &&
      formatService != null &&
      formatService.isInitialized) {
    final psMoveIds = formatService
        .learnsetForGen(pokemonName.toLowerCase(), format.gen)
        .toSet();
    if (psMoveIds.isNotEmpty) {
      for (final moveData in pokemonMoves) {
        final moveName = (moveData['move'] as Map)['name'] as String;
        // Convert PokéAPI name to PS id (strip hyphens) for comparison.
        final psId = _toPsId(moveName);
        if (psMoveIds.contains(psId)) result.add(moveName);
      }
    }
  }

  return result;
}

Set<String> _buildLearnset(
  List<Map<String, dynamic>> pokemonMoves,
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
    allAcceptedGroups.addAll(kGenToVersionGroups[g] ?? []);
  }

  if (allAcceptedGroups.isEmpty) {
    // Unknown generation — fall back to accepting everything.
    return pokemonMoves.map((m) => m['move']['name'] as String).toSet();
  }

  final result = <String>{};
  for (final moveData in pokemonMoves) {
    final moveName = (moveData['move'] as Map)['name'] as String;
    final details = moveData['version_group_details'] as List;
    final learnable = details.any((d) {
      final vg = ((d as Map)['version_group'] as Map)['name'] as String;
      return allAcceptedGroups.contains(vg);
    });
    if (learnable) result.add(moveName);
  }

  return result;
}

/// PokéAPI uses hyphenated names ("choice-specs"); PS ids strip hyphens ("choicespecs").
String _toPsId(String pokeApiName) => pokeApiName.replaceAll('-', '').toLowerCase();

String _display(String id) => id
    .split('-')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _formatLabel(GameFormat f) =>
    f.type == FormatType.game ? f.name : 'Gen ${f.gen}';
