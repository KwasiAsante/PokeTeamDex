import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/services/format/format_models.dart';
import 'package:poke_team_dex/services/format/format_service.dart';

/// The result of validating one slot against a format.
/// [violations] is a map from field name to the violation message so the
/// slot config screen can highlight the specific field.
class SlotValidation {
  /// Key = field name ('ability', 'item', 'move1'–'move4').
  /// Value = human-readable reason.
  final Map<String, String> violations;

  const SlotValidation(this.violations);

  bool get isValid => violations.isEmpty;

  /// Whether a specific field has a violation.
  bool hasViolation(String field) => violations.containsKey(field);

  String? violationFor(String field) => violations[field];
}

/// Validates [slot] against [format] using [service] for data lookups.
/// Returns [SlotValidation.isValid] == true when no issues are found.
///
/// Layer 1 only (generation availability). Layer 2 ban-list checking is
/// deferred to format-engine/banlist.
Future<SlotValidation> validateSlot(
  TeamSlot slot,
  String pokemonName,
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
      final available = service.abilitiesForGen(gen);
      if (!available.any((a) => a.id == slot.abilityName)) {
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
      final available = service.itemsForGen(gen);
      if (!available.any((i) => i.id == slot.heldItemName)) {
        violations['item'] =
            '${_display(slot.heldItemName!)} not available in Gen $gen';
      }
    }
  }

  // ── Moves ─────────────────────────────────────────────────────────────────
  final learnset = service.learnsetForGen(pokemonName, gen).toSet();
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
          '${_display(moveName)} not learnable in Gen $gen';
    }
  }

  return SlotValidation(violations);
}

String _display(String id) =>
    id.split('-').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
