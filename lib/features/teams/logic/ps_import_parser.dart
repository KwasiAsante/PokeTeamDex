// Pure text parsing for Pokémon Showdown team exports — no API calls, no
// widget dependencies. Kept separate from ps_import_sheet.dart so the
// parsing logic is independently unit-testable.
import 'package:poke_team_dex/services/format/format_models.dart';

/// A single parsed Pokémon from a pasted Showdown team export.
class PsSlot {
  final String species; // normalised PokéAPI name (e.g. charizard-mega-x)
  final String? nickname;
  final String? item; // normalised (e.g. choice-scarf)
  final String? ability; // normalised
  final int level;
  final bool isShiny;
  final String? gender; // 'male' | 'female' | null
  final String? nature; // Proper case (e.g. Jolly)
  final int? friendship; // 0–255, from "Happiness: N"
  final bool isGigantamax; // from "Gigantamax: Yes"
  final String? teraType; // lowercase PokéAPI type name, from "Tera Type: X"
  final Map<String, int> evs; // {pokeapi-stat-name: value}
  final Map<String, int> ivs;
  final List<String> moves; // normalised pokeapi names

  const PsSlot({
    required this.species,
    this.nickname,
    this.item,
    this.ability,
    this.level = 100,
    this.isShiny = false,
    this.gender,
    this.nature,
    this.friendship,
    this.isGigantamax = false,
    this.teraType,
    this.evs = const {},
    this.ivs = const {},
    this.moves = const [],
  });
}

class PsTeam {
  final String name;
  final String? formatId; // e.g. "gen9ou"
  final List<PsSlot> slots;
  const PsTeam({required this.name, this.formatId, required this.slots});
}

const _kStatMap = {
  'HP': 'hp', 'Atk': 'attack', 'Def': 'defense',
  'SpA': 'special-attack', 'SpD': 'special-defense', 'Spe': 'speed',
};

/// Normalises a raw Showdown name fragment (species, item, ability, move) to
/// PokéAPI's hyphenated-lowercase slug convention.
String normalisePsName(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll('.', '') // "Mr. Rime" → "mr rime" (PokéAPI: "mr-rime")
    .replaceAll(' ', '-')
    .replaceAll("'", '') // U+0027 ASCII apostrophe
    .replaceAll('’', '') // U+2019 RIGHT SINGLE QUOTATION MARK
    .replaceAll('ʼ', ''); // U+02BC MODIFIER LETTER APOSTROPHE

PsTeam parsePsTeam(String text) {
  String teamName = 'Imported Team';
  String? formatId;

  // Strip === Team Name === header.
  final headerRe = RegExp(r'===\s*(?:\[([^\]]+)\]\s*)?(.+?)\s*===');
  final headerMatch = headerRe.firstMatch(text);
  if (headerMatch != null) {
    if (headerMatch.group(1) != null) {
      // "[gen9ou] My Team" → extract format and name
      final rawFmt = headerMatch.group(1)!.trim().toLowerCase().replaceAll(' ', '');
      formatId = rawFmt.isNotEmpty ? rawFmt : null;
    }
    if ((headerMatch.group(2) ?? '').isNotEmpty) {
      teamName = headerMatch.group(2)!.trim();
    }
    text = text.substring(headerMatch.end);
  }

  // Split into Pokémon blocks (separated by blank lines).
  final blocks = text
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();

  final slots = <PsSlot>[];
  for (final block in blocks) {
    final slot = _parseBlock(block);
    if (slot != null) slots.add(slot);
  }

  return PsTeam(name: teamName, formatId: formatId, slots: slots);
}

PsSlot? _parseBlock(String block) {
  final lines =
      block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) return null;

  // ── Line 0: [Nickname (Species)] [(M/F)] [@ Item] ─────────────────────────
  var first = lines[0];
  String? item;
  if (first.contains(' @ ')) {
    final idx = first.lastIndexOf(' @ ');
    item = normalisePsName(first.substring(idx + 3).trim());
    first = first.substring(0, idx).trim();
  }

  String? gender;
  if (first.endsWith('(M)')) {
    gender = 'male';
    first = first.substring(0, first.length - 3).trim();
  } else if (first.endsWith('(F)')) {
    gender = 'female';
    first = first.substring(0, first.length - 3).trim();
  }

  String? nickname;
  String species;
  final parenMatch = RegExp(r'^(.*?)\(([^)]+)\)\s*$').firstMatch(first);
  if (parenMatch != null && parenMatch.group(1)!.trim().isNotEmpty) {
    nickname = parenMatch.group(1)!.trim();
    species = normalisePsName(parenMatch.group(2)!.trim());
  } else if (parenMatch != null) {
    species = normalisePsName(parenMatch.group(2)!.trim());
  } else {
    species = normalisePsName(first.trim());
  }

  // ── Remaining lines ────────────────────────────────────────────────────────
  String? ability;
  int level = 100;
  bool isShiny = false;
  String? nature;
  int? friendship;
  bool isGigantamax = false;
  String? teraType;
  final evs = <String, int>{};
  final ivs = <String, int>{};
  final moves = <String>[];

  for (int i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('Ability: ')) {
      ability = normalisePsName(line.substring(9).trim());
    } else if (line.startsWith('Level: ')) {
      level = int.tryParse(line.substring(7).trim()) ?? 100;
    } else if (line.startsWith('Shiny: Yes')) {
      isShiny = true;
    } else if (line.startsWith('Happiness: ')) {
      friendship = int.tryParse(line.substring(11).trim());
    } else if (line.startsWith('Gigantamax: Yes')) {
      isGigantamax = true;
    } else if (line.startsWith('Tera Type: ')) {
      teraType = normalisePsName(line.substring(11).trim());
    } else if (line.startsWith('EVs: ')) {
      _parseStatLine(line.substring(5), evs);
    } else if (line.startsWith('IVs: ')) {
      _parseStatLine(line.substring(5), ivs);
    } else if (line.endsWith(' Nature')) {
      // "Timid Nature" (real PS syntax) → "Timid". Also defensively strips a
      // leading "Nature: " prefix, in case older corrupted data is re-pasted.
      var raw = line.substring(0, line.length - 7).trim();
      raw = raw.replaceFirst(RegExp(r'^[Nn]ature:\s*'), '').trim();
      nature = raw.isNotEmpty
          ? raw[0].toUpperCase() + raw.substring(1).toLowerCase()
          : null;
    } else if (line.startsWith('- ')) {
      // Strip Hidden Power type annotation: "Hidden Power [Ice]" → "hidden-power"
      var move = line.substring(2).trim();
      move = move.replaceAll(RegExp(r'\s*\[.*?\]'), '').trim();
      moves.add(normalisePsName(move));
    }
  }

  if (species.isEmpty) return null;

  return PsSlot(
    species: species,
    nickname: nickname,
    item: item,
    ability: ability,
    level: level,
    isShiny: isShiny,
    gender: gender,
    nature: nature,
    friendship: friendship,
    isGigantamax: isGigantamax,
    teraType: teraType,
    evs: evs,
    ivs: ivs,
    moves: moves.take(4).toList(),
  );
}

/// The value TeamSlots stores for a stat when the pasted export omits it.
/// Gen 1/2 slots store raw 0–15 DVs; Gen 3+ (and unknown/null gen) store
/// 0–31 IVs. Mirrors buildShowdownExport's ivDefault.
int psIvDefault(int? gen) => (gen == 1 || gen == 2) ? 15 : 31;

/// Converts a parsed PS IV value to the value TeamSlots stores for [gen].
/// PS's own file format always uses the doubled 0–31 IV scale, even for
/// Gen 1/2 (every IV value in a real Gen 1/2 Showdown export is even) — so
/// Gen 1/2 values are halved back to raw 0–15 DVs. Inverse of
/// buildShowdownExport's DV × 2 conversion.
int psIvToStored(int psIv, int? gen) =>
    (gen == 1 || gen == 2) ? psIv ~/ 2 : psIv;

/// Nulls out fields [slot] doesn't have a valid value for in [gen], mirroring
/// the same generation gates SlotConfigScreen uses to hide UI sections:
/// ability/nature (Gen 3+, `hasAbilities`), held item (Gen 2+, `hasItems`),
/// shiny (Gen 2+, `hasShiny`), Gigantamax (Gen 8 only, `hasGigantamax`), Tera
/// Type (Gen 9 only, `hasTeraType`), and gender/happiness (Gen 2+, no
/// dedicated mechanics flag — gated directly on `gen >= 2` like the UI does).
/// A null [gen] (unknown/no format) leaves every field untouched, matching
/// the UI's own `mechanics == null || ...` fallback.
PsSlot applyGenGates(PsSlot slot, int? gen) {
  if (gen == null) return slot;
  final mechanics = GenerationMechanics.forGen(gen);
  final hasGen2Plus = gen >= 2;
  return PsSlot(
    species: slot.species,
    nickname: slot.nickname,
    item: mechanics.hasItems ? slot.item : null,
    ability: mechanics.hasAbilities ? slot.ability : null,
    level: slot.level,
    isShiny: mechanics.hasShiny && slot.isShiny,
    gender: hasGen2Plus ? slot.gender : null,
    nature: mechanics.hasAbilities ? slot.nature : null,
    friendship: hasGen2Plus ? slot.friendship : null,
    isGigantamax: mechanics.hasGigantamax && slot.isGigantamax,
    teraType: mechanics.hasTeraType ? slot.teraType : null,
    evs: slot.evs,
    ivs: slot.ivs,
    moves: slot.moves,
  );
}

void _parseStatLine(String s, Map<String, int> target) {
  for (final part in s.split('/')) {
    final m = RegExp(r'(\d+)\s+(\w+)').firstMatch(part.trim());
    if (m != null) {
      final stat = _kStatMap[m.group(2)];
      if (stat != null) target[stat] = int.parse(m.group(1)!);
    }
  }
}
