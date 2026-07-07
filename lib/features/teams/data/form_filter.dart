// lib/features/teams/data/form_filter.dart
// Form chip filtering rules for the slot config form selector.
//
// Rules:
// 1. Always exclude: mega, gmax, gender forms — handled by separate toggles
//    or the gender selector.
// 2. Ability-gated: form chip shown only when the required ability is selected.
// 3. Item-gated: form chip shown only when one of the required items is held.
// 4. Everything else: shown freely as a chip.

import 'package:poke_team_dex/data/pokemon_data_registry.dart';

// ── Always-exclude patterns ────────────────────────────────────────────────

/// Form name suffixes that should never appear as chips.
///
/// Primal Reversion (`-primal`) is deliberately NOT here — unlike Mega
/// Evolution (an optional in-battle action the trainer chooses to trigger,
/// modelled as a separate toggle), Primal Reversion happens automatically
/// and unavoidably whenever Primal Groudon/Kyogre enters battle holding its
/// orb. That makes it mechanically identical to Giratina's Origin Forme —
/// an automatic, item-bound form change — so it's gated the same way, via
/// the item gating rules in the registry.
const Set<String> kExcludeFormSuffixes = {
  '-mega', '-mega-x', '-mega-y', '-mega-z',
  '-gmax',
  '-eternamax',
  '-female',
};

/// Specific form names always excluded (gender-only forms without -female suffix).
const Set<String> kAlwaysExcludeForms = {
  'indeedee-female',
  'basculegion-female',
  'oinkologne-female',
};

// ── Generation-gated forms ────────────────────────────────────────────────

/// Forms that were introduced mid-series and should not appear in formats
/// for earlier generations. Maps form name → minimum generation (inclusive).
const Map<String, int> kFormMinGen = {
  // Unown ! and ? were added in FireRed/LeafGreen (Gen 3).
  // Gen 1–2 formats only have the 26 letter forms.
  'unown-exclamation': 3,
  'unown-question':    3,
};

/// Regional form suffix → minimum generation (inclusive).
///
/// Regional suffixes can appear as infixes (e.g. `darmanitan-galar-zen`),
/// so [filterFormChips] uses `.contains()` rather than `.endsWith()`.
/// Hisuian forms are Gen 9 because they were not available in any mainline
/// Gen 8 game (Sword/Shield) and only became usable competitively via
/// Pokémon HOME transfer into Scarlet/Violet.
const Map<String, int> kRegionalSuffixMinGen = {
  '-alola': 7,
  '-galar': 8,
  '-hisui': 9,
  '-paldea': 9,
};

// ── Public API ────────────────────────────────────────────────────────────

/// Returns the non-default form names that should be shown as chips.
///
/// [varieties] — all varieties from the species endpoint.
/// [cosmeticForms] — sprite-only form names (e.g. Burmy's cloaks).
/// [heldItem] — current held item (PokéAPI hyphenated name, or null).
/// [abilityName] — current ability (PokéAPI hyphenated name, or null).
/// [gen] — current format generation (null = no format, no restriction).
List<String> filterFormChips({
  required List<String> varieties,
  List<String> cosmeticForms = const [],
  required String? heldItem,
  required String? abilityName,
  int? gen,
}) {
  final candidates = [
    ...varieties.skip(1), // first entry is the default form — never shown as a chip
    ...cosmeticForms,
  ];
  if (candidates.isEmpty) return [];

  final item    = heldItem?.toLowerCase() ?? '';
  final ability = abilityName?.toLowerCase() ?? '';
  final registry = PokemonDataRegistry.instance;

  return candidates.where((form) {
    // 1. Always exclude by suffix
    for (final suffix in kExcludeFormSuffixes) {
      if (form.endsWith(suffix)) return false;
    }
    if (kAlwaysExcludeForms.contains(form)) return false;

    // 2. Generation-gated: hide forms introduced after the current format's gen
    final minGen = kFormMinGen[form];
    if (minGen != null && gen != null && gen < minGen) return false;

    // 2b. Regional-suffix gen gating (suffix may appear mid-name, e.g. darmanitan-galar-zen)
    if (gen != null) {
      for (final entry in kRegionalSuffixMinGen.entries) {
        if (form.contains(entry.key) && gen < entry.value) return false;
      }
    }

    // 3. Ability-gated
    final requiredAbility = registry.abilityGatingRules[form];
    if (requiredAbility != null) return ability == requiredAbility;

    // 4. Item-gated (covers legendary, primal, Arceus plates, Silvally memories)
    final requiredItems = registry.itemGatingRules[form];
    if (requiredItems != null) return requiredItems.contains(item);

    // 5. Free chip
    return true;
  }).toList();
}
