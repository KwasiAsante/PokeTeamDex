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

  // ── Moves — per-game or per-gen learnset ─────────────────────────────────
  final learnset = _buildLearnset(pokemonMoves, format);
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

  final learnset = _buildLearnset(pokemonMoves, format);
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

/// Build the set of moves learnable in [format] from PokéAPI version-group data.
Set<String> _buildLearnset(
  List<Map<String, dynamic>> pokemonMoves,
  GameFormat format,
) {
  final result = <String>{};

  // Determine which version groups to accept
  final List<String> acceptedGroups;
  if (format.type == FormatType.game) {
    final vg = kFormatToVersionGroup[format.id];
    acceptedGroups = vg != null ? [vg] : [];
  } else {
    // General gen format: accept any version group in this generation.
    acceptedGroups = kGenToVersionGroups[format.gen] ?? [];
  }

  if (acceptedGroups.isEmpty) {
    // Unknown format — fall back to accepting everything
    return pokemonMoves.map((m) => m['move']['name'] as String).toSet();
  }

  for (final moveData in pokemonMoves) {
    final moveName = (moveData['move'] as Map)['name'] as String;
    final details = moveData['version_group_details'] as List;
    final learnable = details.any((d) {
      final vg = ((d as Map)['version_group'] as Map)['name'] as String;
      return acceptedGroups.contains(vg);
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
