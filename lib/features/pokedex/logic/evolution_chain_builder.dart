import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

class DisplayNode {
  final EvolutionNode source;
  final int displayId;
  final List<DisplayNode> evolvesTo;
  List<EvolutionDetail>? matchedDetails;
  /// PokéAPI name for the specific form (e.g. "zigzagoon-galar"), used for
  /// navigation: tapping the card goes to /pokedex/{source.speciesId}?form={formName}.
  /// Null when this node represents the default (base) form.
  String? formName;

  DisplayNode({
    required this.source,
    required this.displayId,
    required this.evolvesTo,
    this.matchedDetails,
    this.formName,
  });
}

const _kRegionalSuffixes = {'-galar', '-alola', '-hisui', '-paldea'};

bool isRegionalVariety(PokemonVariety variety) {
  if (variety.isDefault) return false;
  return _kRegionalSuffixes.any((s) => variety.name.endsWith(s));
}

String? regionalSuffixOf(String varietyName) {
  // Specific form overrides (e.g. "basculin-white-striped" is Hisuian-exclusive).
  final override = kBaseFormSuffixOverrides[varietyName];
  if (override != null) return override;

  // Exact suffix (e.g. "zigzagoon-galar" → "galar").
  for (final s in _kRegionalSuffixes) {
    if (varietyName.endsWith(s)) return s.substring(1);
  }
  // Regional infix for compound forms (e.g. "darmanitan-galar-standard" → "galar").
  // Skips cosmetic variants where the word after the regional infix is a cosmetic
  // indicator (e.g. "pikachu-alola-cap" has "cap" after "alola" → not a regional form).
  const cosmeticNextParts = {'cap'};
  final parts = varietyName.split('-');
  for (final s in _kRegionalSuffixes) {
    final suffix = s.substring(1);
    final idx = parts.indexOf(suffix);
    if (idx != -1 && idx < parts.length - 1) {
      if (cosmeticNextParts.contains(parts[idx + 1])) continue;
      return suffix;
    }
  }
  return null;
}

bool chainHasFormDetails(EvolutionNode node) {
  for (final child in node.evolvesTo) {
    if (child.details.any((d) => d.baseForm != null)) return true;
    if (chainHasFormDetails(child)) return true;
  }
  return false;
}

/// Returns the regional suffix needed to reach [targetSpeciesId] when every
/// path to it goes through a form-specific (base_form) edge.
/// Returns null if reachable via a default edge or not found.
String? formSuffixForSpecies(EvolutionNode root, int targetSpeciesId) =>
    _findSuffix(root, targetSpeciesId);

String? _findSuffix(EvolutionNode node, int targetSpeciesId) {
  for (final child in node.evolvesTo) {
    if (child.speciesId == targetSpeciesId) {
      final withBase = child.details.where((d) => d.baseForm != null).toList();
      final withoutBase = child.details.where((d) => d.baseForm == null).toList();
      if (withBase.isNotEmpty && withoutBase.isEmpty) {
        final suffixes = withBase
            .map((d) => regionalSuffixOf(d.baseForm!.name))
            .whereType<String>()
            .toSet();
        if (suffixes.length == 1) return suffixes.first;
      }
      return null;
    }
    final found = _findSuffix(child, targetSpeciesId);
    if (found != null) return found;
  }
  return null;
}

List<String> collectSpeciesNames(EvolutionNode node) =>
    [node.speciesName, ...node.evolvesTo.expand((c) => collectSpeciesNames(c))];

/// Builds one [DisplayNode] chain for [formSuffix] or the default chain when null.
/// [formIds] maps "{name}-{suffix}" → Pokémon ID for resolving terminal-node IDs
/// and region-keyed branches.
/// Builds one [DisplayNode] chain for [formSuffix] or the default chain when null.
///
/// [excludeRegionSuffixes]: in the default chain, region-keyed branches whose
/// suffix appears here are omitted. Pass the set of suffixes already in the
/// form switcher so the base chain doesn't duplicate branches the user can
/// reach by switching forms (e.g. Raichu's base chain omits "alola" because
/// the switcher already offers Alolan Raichu).
DisplayNode buildFormChain(
  EvolutionNode root,
  String? formSuffix,
  int rootDisplayId, {
  Map<String, int> formIds = const {},
  Set<String> excludeRegionSuffixes = const {},
}) {
  final node = _buildNode(root, formSuffix, rootDisplayId, formIds, excludeRegionSuffixes);
  // Set formName on the root node when it has a form-specific display ID so
  // tapping it navigates to /pokedex/{speciesId}?form={formName} correctly.
  // e.g. Alolan Vulpix root: displayId=10103, speciesId=37 → formName="vulpix-alola"
  if (formSuffix != null && rootDisplayId != root.speciesId) {
    final simpleName = '${root.speciesName}-$formSuffix';
    final lookupName = kRegionalFormLookup[simpleName];
    final compoundName = '$simpleName-standard';
    node.formName = (lookupName != null && formIds.containsKey(lookupName))
        ? lookupName
        : formIds.containsKey(compoundName) ? compoundName : simpleName;
  }
  return node;
}

DisplayNode _buildNode(
  EvolutionNode node,
  String? formSuffix,
  int displayId,
  Map<String, int> formIds,
  Set<String> excludeRegionSuffixes,
) {
  final children = <DisplayNode>[];

  if (formSuffix != null) {
    // Regional chain.
    //
    // If ANY child has a form-specific evolution for this suffix, we only follow
    // those children — we do NOT fall back to default (no-restriction) evolutions
    // for other siblings. This prevents Galarian Meowth from inheriting the
    // default Kantonian Meowth→Persian path when it already has Perrserker.
    //
    // If NO child has a form-specific evolution (e.g. Pichu→Pikachu for the
    // Alolan chain), we fall back to default edges so intermediate steps are
    // still traversed.
    // Checks whether a detail applies to the current form suffix, including
    // overrides like "basculin-white-striped" mapping to "hisui".
    bool matchesSuffix(EvolutionDetail d) =>
        d.baseForm?.name.endsWith('-$formSuffix') == true ||
        d.region?.name == formSuffix ||
        (d.baseForm != null && kBaseFormSuffixOverrides[d.baseForm!.name] == formSuffix);

    final hasFormSpecific = node.evolvesTo.any((c) => c.details.any(matchesSuffix));

    for (final child in node.evolvesTo) {
      final formDetail = child.details.where(matchesSuffix).firstOrNull;

      final detail = formDetail ??
          (!hasFormSpecific
              ? child.details.where((d) => d.baseForm == null && d.region == null).firstOrNull
              : null);

      if (detail == null) continue;
      final childId = _resolveChildId(child, formSuffix, formIds);
      final childFormName = _resolveChildFormName(child, formSuffix, formIds);
      final n = _buildNode(child, formSuffix, childId, formIds, excludeRegionSuffixes);
      n.matchedDetails = [detail];
      n.formName = childFormName;
      children.add(n);
    }
  } else {
    for (final child in node.evolvesTo) {
      final defaultDetail =
          child.details.where((d) => d.baseForm == null && d.region == null).firstOrNull;
      if (defaultDetail != null) {
        final n = _buildNode(child, null, child.speciesId, formIds, excludeRegionSuffixes);
        n.matchedDetails = [defaultDetail];
        children.add(n);
      }
      // Region-keyed branches in the default chain (e.g. Galarian Mr. Mime from
      // Mime Jr, Alolan Raichu from Pikachu). Skipped when the region suffix is
      // already covered by the form switcher — the user selects that form via
      // the badge instead of seeing it as a branch in the default chain.
      for (final rd in child.details.where((d) => d.region != null)) {
        final rName = rd.region!.name;
        if (excludeRegionSuffixes.contains(rName)) continue;
        final rId = formIds['${child.speciesName}-$rName'];
        if (rId == null) continue;
        final regionFormName = '${child.speciesName}-$rName';
        final n = _buildNode(child, rName, rId, formIds, excludeRegionSuffixes);
        n.matchedDetails = [rd];
        n.formName = regionFormName;
        children.add(n);
      }
    }
  }
  return DisplayNode(source: node, displayId: displayId, evolvesTo: children);
}


int _resolveChildId(EvolutionNode child, String? suffix, Map<String, int> formIds) {
  if (suffix == null) return child.speciesId;
  for (final gc in child.evolvesTo) {
    for (final d in gc.details) {
      if (d.baseForm?.name.endsWith('-$suffix') == true) return d.baseForm!.id;
    }
  }
  return formIds['${child.speciesName}-$suffix'] ?? child.speciesId;
}

/// Returns the PokéAPI form name for [child] in the given [suffix] chain,
/// or null if the child has no regional variant (navigate to base species).
String? _resolveChildFormName(EvolutionNode child, String? suffix, Map<String, int> formIds) {
  if (suffix == null) return null;
  for (final gc in child.evolvesTo) {
    for (final d in gc.details) {
      if (d.baseForm?.name.endsWith('-$suffix') == true) return d.baseForm!.name;
    }
  }
  final simpleName = '${child.speciesName}-$suffix';
  if (formIds.containsKey(simpleName)) {
    // Prefer a specific lookup override (e.g. "basculin-hisui" → "basculin-white-striped").
    final lookupName = kRegionalFormLookup[simpleName];
    if (lookupName != null && formIds.containsKey(lookupName)) return lookupName;
    // Prefer compound form name (e.g. "darmanitan-galar-standard" over "darmanitan-galar").
    final compoundName = '$simpleName-standard';
    if (formIds.containsKey(compoundName)) return compoundName;
    return simpleName;
  }
  return null;
}

/// Override labels for the base/default form of specific species where the
/// default form has its own name rather than just "Base".
/// Key: PokéAPI species name. Value: display label for the default form.
const kBaseFormNameOverrides = <String, String>{
  'lycanroc-midday':           'Midday',
  'urshifu-single-strike':     'Single Strike',
  'basculin-red-striped':      'Red-Striped',
  'oricorio-baile':            'Baile',
  'toxtricity-amped':          'Amped',
  'zacian':                    'Hero',
  'zamazenta':                 'Hero',
  'palafin-zero':              'Zero',
  // Variety-based cosmetic forms
  'wormadam-plant':            'Plant',
  'squawkabilly-green-plumage':'Green Plumage',
  'tatsugiri-curly':           'Curly',
  'dudunsparce-two-segment':   'Two Segment',
  'floette':                   'Red Flower',
};

/// Override labels for specific cosmetic form chips where the PokéAPI form name
/// would produce a misleading or incorrect label.
/// Key: PokéAPI variety/form name. Value: display label for the chip.
const kCosmeticFormLabels = <String, String>{
  // Xerneas: the official artwork at pokemon/716 shows the Active form, so the
  // non-default form chip should be labeled "Neutral" (the resting pose).
  'xerneas-active': 'Neutral',
};

/// Override HOME artwork URLs for cosmetic form chips where the default URL
/// derivation would show the wrong visual.
/// Key: PokéAPI form/variety name. Value: full HOME artwork URL.
const kCosmeticFormHomeUrlOverrides = <String, String>{
  // xerneas-active is relabeled "Neutral" — show the neutral (resting) form
  // HOME artwork so the chip actually displays the neutral appearance.
  'xerneas-active':
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/716-neutral.png',
};

/// Same as [kCosmeticFormHomeUrlOverrides] but for shiny HOME artwork.
const kCosmeticFormHomeShinyUrlOverrides = <String, String>{
  'xerneas-active':
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/716-neutral.png',
};

/// Maps specific base_form names (as they appear in PokéAPI evolution_details)
/// to their effective regional suffix. Used for forms that are regionally
/// exclusive but don't follow the simple "{name}-{suffix}" naming convention.
const kBaseFormSuffixOverrides = <String, String>{
  'basculin-white-striped': 'hisui',
};

/// Maps "{speciesName}-{suffix}" to the actual PokéAPI Pokémon name when the
/// true form name doesn't follow the "{name}-{suffix}" convention.
/// Used by _EvolutionsTab to pre-resolve form IDs and by _resolveChildFormName
/// to produce correct navigation targets.
const kRegionalFormLookup = <String, String>{
  'basculin-hisui': 'basculin-white-striped',
};

const _kSuffixLabel = {
  'galar': 'Galarian Form', 'alola': 'Alolan Form',
  'hisui': 'Hisuian Form',  'paldea': 'Paldean Form',
};

const _kGenLabel = {
  'generation-i':    'Kantonian Form', 'generation-ii':   'Johtonian Form',
  'generation-iii':  'Hoennian Form',  'generation-iv':   'Sinnohian Form',
  'generation-v':    'Unovan Form',    'generation-vi':   'Kalosian Form',
  'generation-vii':  'Alolan Form',    'generation-viii': 'Galarian Form',
  'generation-ix':   'Paldean Form',
};

String formLabel({
  required bool isDefault,
  required String varietyName,
  required String? generationName,
}) {
  if (!isDefault) {
    final suffix = regionalSuffixOf(varietyName);
    if (suffix != null) return _kSuffixLabel[suffix] ?? 'Regional Form';
  }
  return (generationName != null ? _kGenLabel[generationName] : null) ?? 'Original Form';
}

const _kGenLabelShort = {
  'generation-i':    'Kantonian', 'generation-ii':   'Johtonian',
  'generation-iii':  'Hoennian',  'generation-iv':   'Sinnohian',
  'generation-v':    'Unovan',    'generation-vi':   'Kalosian',
  'generation-vii':  'Alolan',    'generation-viii': 'Galarian',
  'generation-ix':   'Paldean',
};

/// Short label for the base form in the form picker (e.g. "Kantonian", "Hoennian").
/// Matches the style of [shortFormLabel] — no "Form" suffix.
String shortBaseFormLabel(String? generationName) =>
    (generationName != null ? _kGenLabelShort[generationName] : null) ?? 'Original';

/// Hardcoded overrides for form names where the generic algorithm produces
/// an ambiguous or incorrect label.
const _kSpecificFormLabels = <String, String>{
  'darmanitan-zen':            'Unovan Zen',
  'darmanitan-galar-standard': 'Galarian',
  'basculin-white-striped':    'Hisuian White-Striped',
  'oricorio-pom-pom':          'Pom-Pom',
  "oricorio-pau":              "Pa'u",
  'toxtricity-low-key':        'Low Key',
  'urshifu-rapid-strike':      'Rapid Strike',
};

/// Short label for the app bar badge (e.g. "Galarian", "Alolan", "Combat Breed").
///
/// For plain regional forms (e.g. "zigzagoon-galar") returns the region adjective.
/// For forms with a regional infix followed by a sub-form descriptor
/// (e.g. "tauros-paldea-combat-breed") returns the sub-form label ("Combat Breed").
String shortFormLabel(String varietyName) {
  // Hardcoded overrides first.
  final specific = _kSpecificFormLabels[varietyName];
  if (specific != null) return specific;

  const suffixShort = {
    'galar': 'Galarian', 'alola': 'Alolan',
    'hisui': 'Hisuian',  'paldea': 'Paldean',
  };
  // Plain regional suffix — return the region adjective.
  for (final entry in suffixShort.entries) {
    if (varietyName.endsWith('-${entry.key}')) return entry.value;
  }
  // Regional infix with sub-form content after it (e.g. tauros-paldea-combat-breed).
  // Returns "{RegionalAdjective} {SubForm}" — e.g. "Paldean Combat Breed".
  final parts = varietyName.split('-');
  for (final entry in suffixShort.entries) {
    final idx = parts.indexOf(entry.key);
    if (idx != -1 && idx < parts.length - 1) {
      final subLabel = parts.sublist(idx + 1)
          .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
          .join(' ');
      return '${entry.value} $subLabel';
    }
  }
  // Fallback: capitalize last segment.
  final last = parts.last;
  return '${last[0].toUpperCase()}${last.substring(1)}';
}
