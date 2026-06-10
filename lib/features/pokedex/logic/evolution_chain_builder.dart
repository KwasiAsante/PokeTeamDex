import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

class DisplayNode {
  final EvolutionNode source;
  final int displayId;
  final List<DisplayNode> evolvesTo;
  List<EvolutionDetail>? matchedDetails;

  DisplayNode({
    required this.source,
    required this.displayId,
    required this.evolvesTo,
    this.matchedDetails,
  });
}

const _kRegionalSuffixes = {'-galar', '-alola', '-hisui', '-paldea'};

bool isRegionalVariety(PokemonVariety variety) {
  if (variety.isDefault) return false;
  return _kRegionalSuffixes.any((s) => variety.name.endsWith(s));
}

String? regionalSuffixOf(String varietyName) {
  for (final s in _kRegionalSuffixes) {
    if (varietyName.endsWith(s)) return s.substring(1);
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
DisplayNode buildFormChain(
  EvolutionNode root,
  String? formSuffix,
  int rootDisplayId, {
  Map<String, int> formIds = const {},
}) =>
    _buildNode(root, formSuffix, rootDisplayId, formIds);

DisplayNode _buildNode(
  EvolutionNode node,
  String? formSuffix,
  int displayId,
  Map<String, int> formIds,
) {
  final children = <DisplayNode>[];
  for (final child in node.evolvesTo) {
    if (formSuffix != null) {
      final detail = _matchingDetail(child.details, formSuffix);
      if (detail == null) continue;
      final childId = _resolveChildId(child, formSuffix, formIds);
      final n = _buildNode(child, formSuffix, childId, formIds);
      n.matchedDetails = [detail];
      children.add(n);
    } else {
      final defaultDetail =
          child.details.where((d) => d.baseForm == null && d.region == null).firstOrNull;
      if (defaultDetail != null) {
        final n = _buildNode(child, null, child.speciesId, formIds);
        n.matchedDetails = [defaultDetail];
        children.add(n);
      }
      // Region-keyed branches in the default chain (e.g. Alolan Raichu, Galarian Mr. Mime).
      for (final rd in child.details.where((d) => d.region != null)) {
        final rName = rd.region!.name;
        final rId = formIds['${child.speciesName}-$rName'];
        if (rId == null) continue;
        final n = _buildNode(child, rName, rId, formIds);
        n.matchedDetails = [rd];
        children.add(n);
      }
    }
  }
  return DisplayNode(source: node, displayId: displayId, evolvesTo: children);
}

EvolutionDetail? _matchingDetail(List<EvolutionDetail> details, String? suffix) {
  if (suffix == null) {
    return details.where((d) => d.baseForm == null && d.region == null).firstOrNull;
  }
  return details.where((d) =>
    d.baseForm?.name.endsWith('-$suffix') == true ||
    d.region?.name == suffix
  ).firstOrNull;
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

/// Short label for the app bar badge (e.g. "Galarian", "Alolan").
String shortFormLabel(String varietyName) {
  const suffixShort = {
    'galar': 'Galarian', 'alola': 'Alolan',
    'hisui': 'Hisuian',  'paldea': 'Paldean',
  };
  for (final entry in suffixShort.entries) {
    if (varietyName.endsWith('-${entry.key}')) return entry.value;
  }
  final parts = varietyName.split('-');
  final last = parts.last;
  return '${last[0].toUpperCase()}${last.substring(1)}';
}
