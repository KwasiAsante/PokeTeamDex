// Form chip filtering rules for the slot config form selector.
//
// Rules:
// 1. Always exclude: mega, primal, gmax, gender forms — handled by separate
//    toggles or the gender selector.
// 2. Ability-gated: form chip shown only when the required ability is selected.
// 3. Item-gated: form chip shown only when the required item is held.
// 4. Everything else: shown freely as a chip.

// ── Always-exclude patterns ────────────────────────────────────────────────

/// Form name suffixes that should never appear as chips.
const Set<String> kExcludeFormSuffixes = {
  '-mega', '-mega-x', '-mega-y', '-mega-z',
  '-primal',
  '-gmax',
  '-eternamax',
  '-female',       // Gender forms — handled by gender selector
};

/// Specific form names always excluded (gender-only forms without -female suffix).
const Set<String> kAlwaysExcludeForms = {
  'indeedee-female',
  'basculegion-female',
  'oinkologne-female',
};

// ── Ability-gated forms ────────────────────────────────────────────────────

/// Form chip is shown only when the mapped ability is selected.
const Map<String, String> kAbilityGatedForms = {
  'aegislash-blade':        'stance-change',
  'darmanitan-zen':         'zen-mode',
  'darmanitan-galar-zen':   'zen-mode',
  'wishiwashi-school':      'schooling',
  'cherrim-sunshine':       'flower-gift',
  'morpeko-hangry':         'hunger-switch',
  'mimikyu-busted':         'disguise',
  'minior-red-core':        'shields-down',
  'minior-orange-core':     'shields-down',
  'minior-yellow-core':     'shields-down',
  'minior-green-core':      'shields-down',
  'minior-blue-core':       'shields-down',
  'minior-indigo-core':     'shields-down',
  'minior-violet-core':     'shields-down',
  'eiscue-noice':           'ice-face',
  'palafin-hero':           'zero-to-hero',
};

// ── Item-gated forms ──────────────────────────────────────────────────────

/// Form chip shown only when the required held item is selected.
const Map<String, String> kItemGatedForms = {
  'giratina-origin':       'griseous-orb',
  'zacian-crowned':        'rusted-sword',
  'zamazenta-crowned':     'rusted-shield',
  'calyrex-ice-rider':     'reins-of-unity',
  'calyrex-shadow-rider':  'reins-of-unity',
  'dialga-origin':         'adamant-crystal',
  'palkia-origin':         'lustrous-globe',
};

/// Arceus type forms each need the matching plate.
const Map<String, String> kArceusPlateForms = {
  'arceus-fighting': 'fist-plate',   'arceus-flying':   'sky-plate',
  'arceus-poison':   'toxic-plate',  'arceus-ground':   'earth-plate',
  'arceus-rock':     'stone-plate',  'arceus-bug':      'insect-plate',
  'arceus-ghost':    'spooky-plate', 'arceus-steel':    'iron-plate',
  'arceus-fire':     'flame-plate',  'arceus-water':    'splash-plate',
  'arceus-grass':    'meadow-plate', 'arceus-electric': 'zap-plate',
  'arceus-psychic':  'mind-plate',   'arceus-ice':      'icicle-plate',
  'arceus-dragon':   'draco-plate',  'arceus-dark':     'dread-plate',
  'arceus-fairy':    'pixie-plate',
};

/// Silvally type forms each need the matching memory.
const Map<String, String> kSilvallyMemoryForms = {
  'silvally-fighting': 'fighting-memory', 'silvally-flying':   'flying-memory',
  'silvally-poison':   'poison-memory',   'silvally-ground':   'ground-memory',
  'silvally-rock':     'rock-memory',     'silvally-bug':      'bug-memory',
  'silvally-ghost':    'ghost-memory',    'silvally-steel':    'steel-memory',
  'silvally-fire':     'fire-memory',     'silvally-water':    'water-memory',
  'silvally-grass':    'grass-memory',    'silvally-electric': 'electric-memory',
  'silvally-psychic':  'psychic-memory',  'silvally-ice':      'ice-memory',
  'silvally-dragon':   'dragon-memory',   'silvally-dark':     'dark-memory',
  'silvally-fairy':    'fairy-memory',
};

// ── Public API ────────────────────────────────────────────────────────────

/// Returns the non-default form names that should be shown as chips.
///
/// [varieties] — all varieties from the species endpoint.
/// [heldItem]  — current held item (PokéAPI hyphenated name, or null).
/// [abilityName] — current ability (PokéAPI hyphenated name, or null).
///
/// The default form (varieties.first) is never included — it is the
/// implicit "no chip selected" state.
List<String> filterFormChips({
  required List<String> varieties,
  required String? heldItem,
  required String? abilityName,
}) {
  if (varieties.length <= 1) return [];

  final item     = heldItem?.toLowerCase() ?? '';
  final ability  = abilityName?.toLowerCase() ?? '';

  return varieties.skip(1).where((form) {
    // 1. Always exclude by suffix
    for (final suffix in kExcludeFormSuffixes) {
      if (form.endsWith(suffix)) return false;
    }
    if (kAlwaysExcludeForms.contains(form)) return false;

    // 2. Ability-gated
    if (kAbilityGatedForms.containsKey(form)) {
      return ability == kAbilityGatedForms[form];
    }

    // 3. Simple item-gated
    if (kItemGatedForms.containsKey(form)) {
      return item == kItemGatedForms[form];
    }

    // 4. Arceus plate forms
    if (kArceusPlateForms.containsKey(form)) {
      return item == kArceusPlateForms[form];
    }

    // 5. Silvally memory forms
    if (kSilvallyMemoryForms.containsKey(form)) {
      return item == kSilvallyMemoryForms[form];
    }

    // 6. Free chip for everything else
    return true;
  }).toList();
}
