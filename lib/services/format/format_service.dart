import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:poke_team_dex/services/api/api_client.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

/// Loads PS data from bundled Flutter assets on first run.
/// Checks the backend /ps-data/version endpoint on each launch and
/// downloads fresher data into Hive when the sha changes.
class FormatService {
  FormatService(this._apiClient);
  final ApiClient _apiClient;

  // In-memory caches populated on [initialize].
  List<GameFormat> _formats = [];
  Map<String, Map<String, List<String>>> _learnsets = {};
  /// Gen 6 move allow-list from learnsets-g6.js.
  /// Maps pokémon name → set of moves PS considers valid in Gen 6.
  Map<String, Set<String>> _g6Allowlist = {};
  Map<String, PsMoveEntry> _moves = {};
  Map<String, PsItemEntry> _items = {};
  Map<String, PsAbilityEntry> _abilities = {};
  /// Full-fidelity learnset data built from PS's raw source files —
  /// supplements [_learnsets] with genuine event/gift-Pokémon movesets
  /// (`eventData`) and full source-code strings (so "S" = event sources can
  /// be told apart from level-up/egg/tutor/machine). PokéAPI has no
  /// equivalent category for event movesets at all.
  /// Maps pokémon name → (move name → full source-code strings, e.g. "2S1").
  Map<String, Map<String, List<String>>> _detailedLearnsets = {};
  Map<String, List<PsEventEntry>> _eventData = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;

  // Hive box keys
  static const _boxName = 'ps_data';
  static const _keyLearnsets        = 'learnsets';
  static const _keyG6Allowlist      = 'learnsets_g6_allowlist';
  static const _keyMoves            = 'moves';
  static const _keyItems            = 'items';
  static const _keyAbilities        = 'abilities';
  static const _keyEventLearnsets   = 'event_learnsets';
  static const _keyVersion          = 'version';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    final box = await Hive.openBox<String>(_boxName);

    // 1. Load from Hive cache if available, otherwise fall back to bundled assets.
    final learnsets       = await _loadJson(box, _keyLearnsets,      'assets/data/ps/learnsets.json');
    final g6Allowlist     = await _loadJson(box, _keyG6Allowlist,    'assets/data/ps/learnsets-g6-allowlist.json');
    final moves           = await _loadJson(box, _keyMoves,          'assets/data/ps/moves.json');
    final items           = await _loadJson(box, _keyItems,          'assets/data/ps/items.json');
    final abilities       = await _loadJson(box, _keyAbilities,      'assets/data/ps/abilities.json');
    final eventLearnsets  = await _loadJson(box, _keyEventLearnsets, 'assets/data/ps/event_learnsets.json');
    final formatsRaw      = await _loadAsset('assets/data/ps/formats.json');

    _parseAll(learnsets, moves, items, abilities, formatsRaw);
    _parseG6Allowlist(g6Allowlist);
    _parseEventLearnsets(eventLearnsets);
    _initialized = true;

    // 2. Check for updates in the background (non-blocking).
    _checkForUpdates(box);
  }

  Future<String> _loadJson(Box<String> box, String key, String assetPath) async {
    final cached = box.get(key);
    if (cached != null) return cached;
    return _loadAsset(assetPath);
  }

  Future<String> _loadAsset(String path) async {
    return rootBundle.loadString(path);
  }

  void _parseG6Allowlist(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _g6Allowlist = map.map((k, v) =>
          MapEntry(k, (v as List).cast<String>().toSet()));
    } catch (_) {
      _g6Allowlist = {};
    }
  }

  /// Parses `event_learnsets.json` — built from PS's raw learnset sources.
  /// Format: { "dratini": { "learnset": {"extremespeed": ["2S1","4E",...]},
  ///                        "eventData": [{"generation": 2, "level": 15, ...}] } }
  void _parseEventLearnsets(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final learnsets = <String, Map<String, List<String>>>{};
      final events = <String, List<PsEventEntry>>{};
      for (final entry in map.entries) {
        final data = entry.value as Map<String, dynamic>;
        final learnset = data['learnset'] as Map<String, dynamic>?;
        if (learnset != null) {
          learnsets[entry.key] = learnset.map(
              (move, codes) => MapEntry(move, (codes as List).cast<String>()));
        }
        final eventData = data['eventData'] as List?;
        if (eventData != null && eventData.isNotEmpty) {
          events[entry.key] = eventData
              .map((e) => PsEventEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      _detailedLearnsets = learnsets;
      _eventData = events;
    } catch (_) {
      _detailedLearnsets = {};
      _eventData = {};
    }
  }

  /// Returns true when [moveName] (PokéAPI hyphenated id, e.g. "dragon-dance")
  /// is in the Gen 6 PS allow-list for [pokemonName].
  /// The allow-list uses PS ids (no hyphens), so the input is normalised.
  bool isInG6Allowlist(String pokemonName, String moveName) {
    final entry = _g6Allowlist[pokemonName.toLowerCase()];
    if (entry == null) return false;
    // Convert PokéAPI hyphenated name → PS id (strip hyphens + lowercase).
    final psId = moveName.toLowerCase().replaceAll('-', '');
    return entry.contains(psId);
  }

  void _parseAll(
    String learnsets,
    String moves,
    String items,
    String abilities,
    String formats,
  ) {
    final lsMap = jsonDecode(learnsets) as Map<String, dynamic>;
    _learnsets = lsMap.map((k, v) {
      final byGen = v as Map<String, dynamic>;
      return MapEntry(k, byGen.map((g, ml) =>
          MapEntry(g, (ml as List).cast<String>())));
    });

    final mvMap = jsonDecode(moves) as Map<String, dynamic>;
    _moves = mvMap.map((k, v) =>
        MapEntry(k, PsMoveEntry.fromJson(k, v as Map<String, dynamic>)));

    final itMap = jsonDecode(items) as Map<String, dynamic>;
    _items = itMap.map((k, v) =>
        MapEntry(k, PsItemEntry.fromJson(k, v as Map<String, dynamic>)));

    final abMap = jsonDecode(abilities) as Map<String, dynamic>;
    _abilities = abMap.map((k, v) =>
        MapEntry(k, PsAbilityEntry.fromJson(k, v as Map<String, dynamic>)));

    final fmtList = (jsonDecode(formats) as Map<String, dynamic>)['formats'] as List;
    _formats = fmtList
        .map((f) => GameFormat.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Background version check + update
  // ---------------------------------------------------------------------------

  Future<void> _checkForUpdates(Box<String> box) async {
    try {
      final response = await _apiClient.dio.get('/ps-data/version');
      if (response.statusCode != 200) return;

      final remote = response.data as Map<String, dynamic>;
      final remoteSha = (remote['sha'] as Map<String, dynamic>).cast<String, String>();
      final localVersion = box.get(_keyVersion);
      final localSha = localVersion != null
          ? (jsonDecode(localVersion) as Map<String, dynamic>).cast<String, String>()
          : <String, String>{};

      // Download each file that has changed.
      final fileMap = {
        _keyLearnsets:      ('learnsets.json',       'assets/data/ps/learnsets.json'),
        _keyMoves:          ('moves.json',           'assets/data/ps/moves.json'),
        _keyItems:          ('items.json',           'assets/data/ps/items.json'),
        _keyAbilities:      ('abilities.json',       'assets/data/ps/abilities.json'),
        _keyEventLearnsets: ('event_learnsets.json', 'assets/data/ps/event_learnsets.json'),
      };

      bool anyUpdated = false;
      for (final entry in fileMap.entries) {
        final key = entry.key;
        final (filename, assetPath) = entry.value;
        if (remoteSha[key] != localSha[key]) {
          final data = await _downloadPsFile(filename) ??
              await _loadAsset(assetPath);
          await box.put(key, data);
          anyUpdated = true;
        }
      }

      if (anyUpdated) {
        await box.put(_keyVersion, jsonEncode(remoteSha));
        // Re-parse with the updated data.
        final learnsets      = box.get(_keyLearnsets)      ?? await _loadAsset('assets/data/ps/learnsets.json');
        final moves          = box.get(_keyMoves)          ?? await _loadAsset('assets/data/ps/moves.json');
        final items          = box.get(_keyItems)          ?? await _loadAsset('assets/data/ps/items.json');
        final abilities      = box.get(_keyAbilities)      ?? await _loadAsset('assets/data/ps/abilities.json');
        final eventLearnsets = box.get(_keyEventLearnsets) ?? await _loadAsset('assets/data/ps/event_learnsets.json');
        final formats        = await _loadAsset('assets/data/ps/formats.json');
        _parseAll(learnsets, moves, items, abilities, formats);
        _parseEventLearnsets(eventLearnsets);
      }
    } catch (_) {
      // Version check is best-effort; silently ignore network errors.
    }
  }

  Future<String?> _downloadPsFile(String filename) async {
    try {
      final r = await _apiClient.dio
          .get('/ps-data/file/$filename');
      if (r.statusCode == 200) return r.data as String;
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

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

  /// Cumulative learnset for [pokemonName] in [gen].
  /// Includes all moves the Pokémon could learn in gens 1–[gen].
  List<String> learnsetForGen(String pokemonName, int gen) {
    final byGen = _learnsets[pokemonName.toLowerCase()];
    if (byGen == null) return [];
    final moves = <String>{};
    for (int g = 1; g <= gen; g++) {
      final genMoves = byGen[g.toString()];
      if (genMoves != null) moves.addAll(genMoves);
    }
    return moves.toList()..sort();
  }

  /// Cumulative learnset for [pokemonName] in [gen] from the full-fidelity
  /// detailed-learnset source (built from PS's raw learnset sources — see
  /// [_detailedLearnsets]). Source-agnostic: includes a move if ANY of its
  /// source codes (e.g. "2S1", "4E", "8M") has a leading generation digit
  /// ≤ [gen]. Supplements [learnsetForGen] with moves PS's compiled data
  /// endpoints — and therefore the bundled `learnsets.json` — don't carry,
  /// most notably genuine event/gift sources ("S").
  Set<String> detailedLearnsetForGen(String pokemonName, int gen) {
    final learnset = _detailedLearnsets[pokemonName.toLowerCase()];
    if (learnset == null) return const {};
    final moves = <String>{};
    for (final entry in learnset.entries) {
      if (entry.value.any((code) => _codeGen(code) <= gen)) moves.add(entry.key);
    }
    return moves;
  }

  /// Moves [pokemonName] is only known to learn via a real event/gift
  /// encounter in generations 1–[gen] — i.e. PS source-codes it with "S"
  /// (e.g. "2S1") or it appears in a structured `eventData` record for that
  /// generation (Pokémon Crystal's gift Dratini knowing Extreme Speed is
  /// exactly this case). PokéAPI has no equivalent category at all.
  Set<String> eventMovesForGen(String pokemonName, int gen) {
    final key = pokemonName.toLowerCase();
    final moves = <String>{};

    final learnset = _detailedLearnsets[key];
    if (learnset != null) {
      for (final entry in learnset.entries) {
        if (entry.value.any((code) {
          final g = _codeGen(code);
          return g <= gen && code.length > 1 && code[1] == 'S';
        })) {
          moves.add(entry.key);
        }
      }
    }

    final events = _eventData[key];
    if (events != null) {
      for (final event in events) {
        if (event.generation <= gen) moves.addAll(event.moves);
      }
    }

    return moves;
  }

  /// Raw event/gift-Pokémon encounter records for [pokemonName] (any
  /// generation) — for any future richer display of event details
  /// (level, shininess, full gift moveset, etc).
  List<PsEventEntry> eventsForSpecies(String pokemonName) =>
      List.unmodifiable(_eventData[pokemonName.toLowerCase()] ?? const []);

  /// Leading generation digit of a PS source-code string (e.g. "2S1" → 2).
  /// Malformed/empty codes sort last (gen 99) so they never spuriously match.
  static int _codeGen(String code) {
    if (code.isEmpty) return 99;
    final digit = int.tryParse(code[0]);
    return digit ?? 99;
  }

  /// Items available in [gen], optionally filtered by [mechanics].
  /// Layer 1 only — excludes items that didn't exist in the gen.
  List<PsItemEntry> itemsForGen(int gen) {
    final m = GenerationMechanics.forGen(gen);
    return _items.values.where((item) {
      if (item.gen > gen) return false;
      if (item.isMegaStone && !m.hasMegaStone) return false;
      if (item.isZCrystal && !m.hasZCrystal) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Abilities available in [gen].
  List<PsAbilityEntry> abilitiesForGen(int gen) {
    final m = GenerationMechanics.forGen(gen);
    if (!m.hasAbilities) return [];
    return _abilities.values.where((a) => a.gen <= gen).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Move detail by PS move id, or null if not in dataset.
  PsMoveEntry? moveDetail(String moveId) => _moves[moveId];

  /// Item detail by PS item id, or null if not in dataset.
  PsItemEntry? itemDetail(String itemId) => _items[itemId];
}
