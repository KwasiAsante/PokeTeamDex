import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

/// A filtered, display-ready version of [EvolutionNode] for one regional form chain.
class DisplayNode {
  final EvolutionNode source;
  final int displayId;
  final List<DisplayNode> evolvesTo;
  /// When non-null, use these details for condition display instead of [source.details].
  /// Avoids duplicate conditions when a node has both default and form-specific edges.
  List<EvolutionDetail>? matchedDetails;

  DisplayNode({
    required this.source,
    required this.displayId,
    required this.evolvesTo,
    this.matchedDetails,
  });
}

const _kRegionalSuffixes = {'-galar', '-alola', '-hisui', '-paldea'};

/// True when [variety] is a non-default regional form (Galarian, Alolan, etc.).
bool isRegionalVariety(PokemonVariety variety) {
  if (variety.isDefault) return false;
  return _kRegionalSuffixes.any((s) => variety.name.endsWith(s));
}

/// Returns the bare regional suffix (e.g. "galar" from "zigzagoon-galar"), or null.
String? regionalSuffixOf(String varietyName) {
  for (final s in _kRegionalSuffixes) {
    if (varietyName.endsWith(s)) return s.substring(1);
  }
  return null;
}

/// True when any edge in the subtree rooted at [node] carries a base_form.
bool chainHasFormDetails(EvolutionNode node) {
  for (final child in node.evolvesTo) {
    if (child.details.any((d) => d.baseForm != null)) return true;
    if (chainHasFormDetails(child)) return true;
  }
  return false;
}

/// Returns the regional suffix needed to reach [targetSpeciesId] in the chain,
/// or null if the target is reachable via a default (no-base_form) path.
/// Used to detect that Obstagoon (only reachable via Galarian Linoone) should
/// show the Galarian chain even though Obstagoon itself has no regional variety.
String? formSuffixForSpecies(EvolutionNode root, int targetSpeciesId) {
  return _findSuffix(root, targetSpeciesId);
}

String? _findSuffix(EvolutionNode node, int targetSpeciesId) {
  for (final child in node.evolvesTo) {
    if (child.speciesId == targetSpeciesId) {
      // Found it — if ALL details have a base_form with a single suffix, return that suffix.
      final withBaseForm = child.details.where((d) => d.baseForm != null).toList();
      final withoutBaseForm = child.details.where((d) => d.baseForm == null).toList();
      if (withBaseForm.isNotEmpty && withoutBaseForm.isEmpty) {
        final suffixes = withBaseForm
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

/// Returns all species names in the subtree rooted at [node].
/// Used by _EvolutionsTab to know which form providers to pre-watch.
List<String> collectSpeciesNames(EvolutionNode node) {
  return [node.speciesName, ...node.evolvesTo.expand((c) => collectSpeciesNames(c))];
}

/// Builds a [DisplayNode] tree for [formSuffix] (e.g. "galar") or the default
/// chain when [formSuffix] is null.
///
/// [rootDisplayId]: for the default chain pass [root.speciesId]; for a regional
/// chain pass the variety's Pokémon ID (e.g. 10174 for zigzagoon-galar).
///
/// [formIds]: optional map of "{speciesName}-{suffix}" → Pokémon ID, used to
/// resolve terminal node IDs when outgoing-edge scanning finds nothing, and to
/// add region-based branches (e.g. Alolan Raichu) in the default chain.
DisplayNode buildFormChain(
  EvolutionNode root,
  String? formSuffix,
  int rootDisplayId, {
  Map<String, int> formIds = const {},
}) {
  return _buildNode(root, formSuffix, rootDisplayId, formIds);
}

DisplayNode _buildNode(
  EvolutionNode node,
  String? formSuffix,
  int displayId,
  Map<String, int> formIds,
) {
  final children = <DisplayNode>[];

  for (final child in node.evolvesTo) {
    if (formSuffix != null) {
      // ── Regional chain (e.g. Galarian) ─────────────────────────────────────
      final matchingDetail = _matchingDetail(child.details, formSuffix);
      if (matchingDetail == null) continue;
      final childDisplayId = _resolveChildDisplayId(child, formSuffix, formIds);
      final childNode = _buildNode(child, formSuffix, childDisplayId, formIds);
      childNode.matchedDetails = [matchingDetail];
      children.add(childNode);
    } else {
      // ── Default chain ───────────────────────────────────────────────────────
      // Default path: a detail with no base_form AND no region restriction.
      final defaultDetail = child.details
          .where((d) => d.baseForm == null && d.region == null)
          .firstOrNull;
      if (defaultDetail != null) {
        final defaultChild = _buildNode(child, null, child.speciesId, formIds);
        defaultChild.matchedDetails = [defaultDetail];
        children.add(defaultChild);
      }

      // Region-specific branches (e.g. Alolan Raichu from Pikachu).
      // For each unique region in the details, add a branch using the
      // regional form's Pokémon ID from the pre-resolved formIds map.
      final regionDetails = child.details.where((d) => d.region != null).toList();
      for (final regionDetail in regionDetails) {
        final regionName = regionDetail.region!.name;
        final formName = '${child.speciesName}-$regionName';
        final regionDisplayId = formIds[formName];
        if (regionDisplayId == null) continue;
        // Build the regional branch — terminal for now (Alolan Raichu doesn't evolve).
        final regionChild = DisplayNode(
          source: child,
          displayId: regionDisplayId,
          evolvesTo: const [],
          matchedDetails: [regionDetail],
        );
        children.add(regionChild);
      }
    }
  }

  return DisplayNode(source: node, displayId: displayId, evolvesTo: children);
}

EvolutionDetail? _matchingDetail(List<EvolutionDetail> details, String? formSuffix) {
  if (formSuffix == null) {
    return details.where((d) => d.baseForm == null && d.region == null).firstOrNull;
  }
  return details
      .where((d) => d.baseForm?.name.endsWith('-$formSuffix') == true)
      .firstOrNull;
}

int _resolveChildDisplayId(
  EvolutionNode child,
  String? formSuffix,
  Map<String, int> formIds,
) {
  if (formSuffix == null) return child.speciesId;

  // Try grandchild edge scan first (works for non-terminal nodes like Linoone).
  for (final grandchild in child.evolvesTo) {
    for (final d in grandchild.details) {
      if (d.baseForm?.name.endsWith('-$formSuffix') == true) {
        return d.baseForm!.id;
      }
    }
  }

  // Fallback: look up from pre-resolved map (handles terminal nodes like Arcanine-Hisui).
  final formName = '${child.speciesName}-$formSuffix';
  return formIds[formName] ?? child.speciesId;
}

const _kSuffixLabel = {
  'galar':  'Galarian Form',
  'alola':  'Alolan Form',
  'hisui':  'Hisuian Form',
  'paldea': 'Paldean Form',
};

const _kGenLabel = {
  'generation-i':    'Kantonian Form',
  'generation-ii':   'Johtonian Form',
  'generation-iii':  'Hoennian Form',
  'generation-iv':   'Sinnohian Form',
  'generation-v':    'Unovan Form',
  'generation-vi':   'Kalosian Form',
  'generation-vii':  'Alolan Form',
  'generation-viii': 'Galarian Form',
  'generation-ix':   'Paldean Form',
};

/// Returns the display label for a form section header.
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
