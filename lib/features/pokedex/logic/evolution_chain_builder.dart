import 'package:poke_team_dex/services/pokeapi/models/evolution_chain.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

/// A filtered, display-ready version of [EvolutionNode] for one regional form chain.
class DisplayNode {
  final EvolutionNode source;
  final int displayId;
  final List<DisplayNode> evolvesTo;

  const DisplayNode({
    required this.source,
    required this.displayId,
    required this.evolvesTo,
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

/// Builds a [DisplayNode] tree for [formSuffix] (e.g. "galar") or the default
/// chain when [formSuffix] is null.
///
/// [rootDisplayId]: for the default chain pass [root.speciesId]; for a regional
/// chain pass the variety's Pokémon ID (e.g. 10174 for zigzagoon-galar).
DisplayNode buildFormChain(EvolutionNode root, String? formSuffix, int rootDisplayId) {
  return _buildNode(root, formSuffix, rootDisplayId);
}

DisplayNode _buildNode(EvolutionNode node, String? formSuffix, int displayId) {
  final children = <DisplayNode>[];
  for (final child in node.evolvesTo) {
    if (_matchingDetail(child.details, formSuffix) == null) continue;
    final childDisplayId = _resolveChildDisplayId(child, formSuffix);
    children.add(_buildNode(child, formSuffix, childDisplayId));
  }
  return DisplayNode(source: node, displayId: displayId, evolvesTo: children);
}

EvolutionDetail? _matchingDetail(List<EvolutionDetail> details, String? formSuffix) {
  if (formSuffix == null) {
    return details.where((d) => d.baseForm == null).firstOrNull;
  }
  return details
      .where((d) => d.baseForm?.name.endsWith('-$formSuffix') == true)
      .firstOrNull;
}

int _resolveChildDisplayId(EvolutionNode child, String? formSuffix) {
  if (formSuffix == null) return child.speciesId;
  for (final grandchild in child.evolvesTo) {
    for (final d in grandchild.details) {
      if (d.baseForm?.name.endsWith('-$formSuffix') == true) {
        return d.baseForm!.id;
      }
    }
  }
  return child.speciesId;
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
