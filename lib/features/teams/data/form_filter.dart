// lib/features/teams/data/form_filter.dart
// Form chip filtering rules for the slot config form selector.
//
// Rules:
// 1. Always exclude: mega, gmax, gender forms — handled by separate toggles
//    or the gender selector.
// 2. Ability-gated: form chip shown only when the required ability is selected.
// 3. Item-gated: form chip shown only when one of the required items is held.
// 4. Everything else: shown freely as a chip.

// ── Always-exclude patterns ────────────────────────────────────────────────

/// Form name suffixes that should never appear as chips.
///
/// Primal Reversion (`-primal`) is deliberately NOT here — unlike Mega
/// Evolution (an optional in-battle action the trainer chooses to trigger,
/// modelled as a separate toggle), Primal Reversion happens automatically
/// and unavoidably whenever Primal Groudon/Kyogre enters battle holding its
/// orb. That makes it mechanically identical to Giratina's Origin Forme —
/// an automatic, item-bound form change — so it's gated the same way, via
/// [kItemGatingRules] below.
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

// ── Typed gating rule classes ──────────────────────────────────────────────

/// A form chip that is shown only when a specific ability is active.
class AbilityGatingRule {
  final String requiredAbility;
  const AbilityGatingRule(this.requiredAbility);
}

/// A form chip that is shown only when one of [requiredItems] is held.
/// Uses a Set to support forms that can be triggered by multiple items
/// (e.g. Giratina-Origin works with both Griseous Orb and Griseous Core).
class ItemGatingRule {
  final Set<String> requiredItems;
  const ItemGatingRule(this.requiredItems);
}

// ── Ability-gated forms ────────────────────────────────────────────────────

/// Form chip is shown only when the mapped ability is selected.
const Map<String, AbilityGatingRule> kAbilityGatingRules = {
  'aegislash-blade':        AbilityGatingRule('stance-change'),
  'darmanitan-zen':         AbilityGatingRule('zen-mode'),
  'darmanitan-galar-zen':   AbilityGatingRule('zen-mode'),
  'wishiwashi-school':      AbilityGatingRule('schooling'),
  'cherrim-sunshine':       AbilityGatingRule('flower-gift'),
  'morpeko-hangry':         AbilityGatingRule('hunger-switch'),
  'mimikyu-busted':         AbilityGatingRule('disguise'),
  'minior-red-core':        AbilityGatingRule('shields-down'),
  'minior-orange-core':     AbilityGatingRule('shields-down'),
  'minior-yellow-core':     AbilityGatingRule('shields-down'),
  'minior-green-core':      AbilityGatingRule('shields-down'),
  'minior-blue-core':       AbilityGatingRule('shields-down'),
  'minior-indigo-core':     AbilityGatingRule('shields-down'),
  'minior-violet-core':     AbilityGatingRule('shields-down'),
  'eiscue-noice':           AbilityGatingRule('ice-face'),
  'palafin-hero':           AbilityGatingRule('zero-to-hero'),
};

// ── Item-gated forms ──────────────────────────────────────────────────────

/// Form chip shown only when one of the required held items is selected.
/// Covers legendary item-bound forms, Primal Reversion, Arceus plates,
/// and Silvally memories — all unified under one map.
const Map<String, ItemGatingRule> kItemGatingRules = {
  // Legendary / item-bound forms
  'giratina-origin':       ItemGatingRule({'griseous-orb', 'griseous-core'}),
  'zacian-crowned':        ItemGatingRule({'rusted-sword'}),
  'zamazenta-crowned':     ItemGatingRule({'rusted-shield'}),
  'calyrex-ice-rider':     ItemGatingRule({'reins-of-unity'}),
  'calyrex-shadow-rider':  ItemGatingRule({'reins-of-unity'}),
  'dialga-origin':         ItemGatingRule({'adamant-crystal'}),
  'palkia-origin':         ItemGatingRule({'lustrous-globe'}),
  'groudon-primal':        ItemGatingRule({'red-orb'}),
  'kyogre-primal':         ItemGatingRule({'blue-orb'}),
  // Arceus plate forms
  'arceus-fighting': ItemGatingRule({'fist-plate'}),
  'arceus-flying':   ItemGatingRule({'sky-plate'}),
  'arceus-poison':   ItemGatingRule({'toxic-plate'}),
  'arceus-ground':   ItemGatingRule({'earth-plate'}),
  'arceus-rock':     ItemGatingRule({'stone-plate'}),
  'arceus-bug':      ItemGatingRule({'insect-plate'}),
  'arceus-ghost':    ItemGatingRule({'spooky-plate'}),
  'arceus-steel':    ItemGatingRule({'iron-plate'}),
  'arceus-fire':     ItemGatingRule({'flame-plate'}),
  'arceus-water':    ItemGatingRule({'splash-plate'}),
  'arceus-grass':    ItemGatingRule({'meadow-plate'}),
  'arceus-electric': ItemGatingRule({'zap-plate'}),
  'arceus-psychic':  ItemGatingRule({'mind-plate'}),
  'arceus-ice':      ItemGatingRule({'icicle-plate'}),
  'arceus-dragon':   ItemGatingRule({'draco-plate'}),
  'arceus-dark':     ItemGatingRule({'dread-plate'}),
  'arceus-fairy':    ItemGatingRule({'pixie-plate'}),
  // Silvally memory forms
  'silvally-fighting': ItemGatingRule({'fighting-memory'}),
  'silvally-flying':   ItemGatingRule({'flying-memory'}),
  'silvally-poison':   ItemGatingRule({'poison-memory'}),
  'silvally-ground':   ItemGatingRule({'ground-memory'}),
  'silvally-rock':     ItemGatingRule({'rock-memory'}),
  'silvally-bug':      ItemGatingRule({'bug-memory'}),
  'silvally-ghost':    ItemGatingRule({'ghost-memory'}),
  'silvally-steel':    ItemGatingRule({'steel-memory'}),
  'silvally-fire':     ItemGatingRule({'fire-memory'}),
  'silvally-water':    ItemGatingRule({'water-memory'}),
  'silvally-grass':    ItemGatingRule({'grass-memory'}),
  'silvally-electric': ItemGatingRule({'electric-memory'}),
  'silvally-psychic':  ItemGatingRule({'psychic-memory'}),
  'silvally-ice':      ItemGatingRule({'ice-memory'}),
  'silvally-dragon':   ItemGatingRule({'dragon-memory'}),
  'silvally-dark':     ItemGatingRule({'dark-memory'}),
  'silvally-fairy':    ItemGatingRule({'fairy-memory'}),
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
    if (varieties.length > 1) ...varieties.skip(1),
    ...cosmeticForms,
  ];
  if (candidates.isEmpty) return [];

  final item    = heldItem?.toLowerCase() ?? '';
  final ability = abilityName?.toLowerCase() ?? '';

  return candidates.where((form) {
    // 1. Always exclude by suffix
    for (final suffix in kExcludeFormSuffixes) {
      if (form.endsWith(suffix)) return false;
    }
    if (kAlwaysExcludeForms.contains(form)) return false;

    // 2. Generation-gated: hide forms introduced after the current format's gen
    final minGen = kFormMinGen[form];
    if (minGen != null && gen != null && gen < minGen) return false;

    // 3. Ability-gated
    final abilityRule = kAbilityGatingRules[form];
    if (abilityRule != null) return ability == abilityRule.requiredAbility;

    // 4. Item-gated (covers legendary, primal, Arceus plates, Silvally memories)
    final itemRule = kItemGatingRules[form];
    if (itemRule != null) return itemRule.requiredItems.contains(item);

    // 5. Free chip
    return true;
  }).toList();
}
