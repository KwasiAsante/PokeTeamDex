import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

/// Owns format (Layer 1 metadata) management: the list of general/game
/// formats and their generation mechanics.
///
/// PS data loading (learnsets, moves, items, abilities, event data) has
/// moved to [PsDataService] — the backend now merges that data server-side
/// for every provider that used to read it from here, and [PsDataService]
/// covers the offline-fallback case for those same providers.
class FormatService {
  List<GameFormat> _formats = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final raw = await rootBundle.loadString('assets/data/ps/formats.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final fmtList = decoded['formats'] as List;
    _formats = fmtList.map((f) => GameFormat.fromJson(f as Map<String, dynamic>)).toList();
    _initialized = true;
  }

  /// All available formats (general + game-specific + custom).
  List<GameFormat> get formats => List.unmodifiable(_formats);

  /// Formats filtered by type.
  List<GameFormat> formatsOfType(FormatType type) =>
      _formats.where((f) => f.type == type).toList();

  /// Find a format by id; returns null if not found.
  GameFormat? formatById(String id) =>
      _formats.where((f) => f.id == id).firstOrNull;

  /// Generation mechanics for [gen] (Layer 1 — what the gen supports).
  GenerationMechanics mechanicsForGen(int gen) =>
      GenerationMechanics.forGen(gen);
}
