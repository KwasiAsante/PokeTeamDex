// lib/features/teams/logic/ps_form_resolver.dart
import 'package:poke_team_dex/features/teams/data/form_data.dart';

/// Checks the static exceptions table first (O(1), no API call).
/// Returns the mapped PokeAPI name or null if the PS name is not a known exception.
String? applyPsFormExceptions(String psName) => kPsFormExceptions[psName];

/// Runs the heuristic pipeline against [varieties] (the full varieties list,
/// including the default form). Non-default filtering is applied internally.
/// Returns the first match or null if none of the heuristics succeed.
String? resolveFormFromVarieties(String psName, List<String> varieties) {
  final nonDefault = varieties.skip(1).toList();
  return _exactMatch(psName, varieties) ??
      _forwardPrefixMatch(psName, nonDefault) ??
      _reversePrefixMatch(psName, nonDefault) ??
      _lastSegmentMatch(psName, nonDefault);
}

String? _exactMatch(String psName, List<String> varieties) =>
    varieties.contains(psName) ? psName : null;

String? _forwardPrefixMatch(String psName, List<String> nonDefault) {
  for (final n in nonDefault) {
    if (n.startsWith('$psName-')) return n;
  }
  return null;
}

String? _reversePrefixMatch(String psName, List<String> nonDefault) {
  for (final n in nonDefault) {
    if (psName.startsWith('$n-')) return n;
  }
  return null;
}

String? _lastSegmentMatch(String psName, List<String> nonDefault) {
  final lastSeg = psName.split('-').last;
  for (final n in nonDefault) {
    if (n.split('-').last == lastSeg) return n;
  }
  return null;
}
