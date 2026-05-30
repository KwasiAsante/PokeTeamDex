/// A competitive or game-specific format that can be assigned to a team.
class GameFormat {
  final String id;
  final String name;
  final String short;       // abbreviation for tight UI spaces
  final FormatType type;    // general | game | competitive | custom
  final int gen;

  const GameFormat({
    required this.id,
    required this.name,
    required this.short,
    required this.type,
    required this.gen,
  });

  factory GameFormat.fromJson(Map<String, dynamic> j) => GameFormat(
        id: j['id'] as String,
        name: j['name'] as String,
        short: j['short'] as String,
        type: FormatType.values.firstWhere(
          (t) => t.name == (j['type'] as String),
          orElse: () => FormatType.general,
        ),
        gen: j['gen'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'short': short,
        'type': type.name,
        'gen': gen,
      };

  GenerationMechanics get mechanics => GenerationMechanics.forGen(gen);
}

enum FormatType { general, game, competitive, custom }

// ---------------------------------------------------------------------------
// Generation mechanics — Layer 1: what physically exists in each generation.
// This is distinct from format banlists (Layer 2).
// ---------------------------------------------------------------------------

class GenerationMechanics {
  final int gen;

  /// Whether held items exist in this generation.
  final bool hasItems;

  /// Whether abilities exist in this generation.
  final bool hasAbilities;

  /// Whether shininess is possible in this generation.
  final bool hasShiny;

  /// Whether Hidden Power exists (Gen 2–7; removed in Gen 8).
  final bool hasHiddenPower;

  /// Mega Stones are Gen 6–7 held items that trigger Mega Evolution.
  final bool hasMegaStone;

  /// Z-Crystals are Gen 7 held items that enable Z-Moves.
  final bool hasZCrystal;

  /// Gigantamax is Gen 8 — valid only for species that have a GMax form.
  final bool hasGigantamax;

  /// Tera Type is Gen 9 — an additional type the Pokémon can Terastallize into.
  final bool hasTeraType;

  /// How EVs/DVs work in this generation.
  final StatValueMode statMode;

  /// Maximum value per individual stat point (31 for IVs, 15 for DVs).
  final int statMax;

  /// Total EV cap across all stats (510 for Gen 3+, uncapped for Gen 1–2).
  final int? evTotalCap;

  /// Per-stat EV cap (252 for Gen 3+, uncapped for Gen 1–2).
  final int? evPerStatCap;

  const GenerationMechanics({
    required this.gen,
    required this.hasItems,
    required this.hasAbilities,
    required this.hasShiny,
    required this.hasHiddenPower,
    required this.hasMegaStone,
    required this.hasZCrystal,
    required this.hasGigantamax,
    required this.hasTeraType,
    required this.statMode,
    required this.statMax,
    this.evTotalCap,
    this.evPerStatCap,
  });

  static GenerationMechanics forGen(int gen) {
    return _mechanics[gen.clamp(1, 9)] ?? _mechanics[9]!;
  }

  static const Map<int, GenerationMechanics> _mechanics = {
    1: GenerationMechanics(
      gen: 1,
      hasItems: false,
      hasAbilities: false,
      hasShiny: false,
      hasHiddenPower: false,
      hasMegaStone: false,
      hasZCrystal: false,
      hasGigantamax: false,
      hasTeraType: false,
      statMode: StatValueMode.dvs,
      statMax: 15,
      evTotalCap: null,
      evPerStatCap: null,
    ),
    2: GenerationMechanics(
      gen: 2,
      hasItems: true,
      hasAbilities: false,
      hasShiny: true,
      hasHiddenPower: true,
      hasMegaStone: false,
      hasZCrystal: false,
      hasGigantamax: false,
      hasTeraType: false,
      statMode: StatValueMode.dvs,
      statMax: 15,
      evTotalCap: null,
      evPerStatCap: null,
    ),
    3: GenerationMechanics(
      gen: 3,
      hasItems: true,
      hasAbilities: true,
      hasShiny: true,
      hasHiddenPower: true,
      hasMegaStone: false,
      hasZCrystal: false,
      hasGigantamax: false,
      hasTeraType: false,
      statMode: StatValueMode.evs,
      statMax: 31,
      evTotalCap: 510,
      evPerStatCap: 252,
    ),
    4: GenerationMechanics(
      gen: 4,
      hasItems: true,
      hasAbilities: true,
      hasShiny: true,
      hasHiddenPower: true,
      hasMegaStone: false,
      hasZCrystal: false,
      hasGigantamax: false,
      hasTeraType: false,
      statMode: StatValueMode.evs,
      statMax: 31,
      evTotalCap: 510,
      evPerStatCap: 252,
    ),
    5: GenerationMechanics(
      gen: 5,
      hasItems: true,
      hasAbilities: true,
      hasShiny: true,
      hasHiddenPower: true,
      hasMegaStone: false,
      hasZCrystal: false,
      hasGigantamax: false,
      hasTeraType: false,
      statMode: StatValueMode.evs,
      statMax: 31,
      evTotalCap: 510,
      evPerStatCap: 252,
    ),
    6: GenerationMechanics(
      gen: 6,
      hasItems: true,
      hasAbilities: true,
      hasShiny: true,
      hasHiddenPower: true,
      hasMegaStone: true,
      hasZCrystal: false,
      hasGigantamax: false,
      hasTeraType: false,
      statMode: StatValueMode.evs,
      statMax: 31,
      evTotalCap: 510,
      evPerStatCap: 252,
    ),
    7: GenerationMechanics(
      gen: 7,
      hasItems: true,
      hasAbilities: true,
      hasShiny: true,
      hasHiddenPower: true,
      hasMegaStone: true,
      hasZCrystal: true,
      hasGigantamax: false,
      hasTeraType: false,
      statMode: StatValueMode.evs,
      statMax: 31,
      evTotalCap: 510,
      evPerStatCap: 252,
    ),
    8: GenerationMechanics(
      gen: 8,
      hasItems: true,
      hasAbilities: true,
      hasShiny: true,
      hasHiddenPower: false,
      hasMegaStone: false,
      hasZCrystal: false,
      hasGigantamax: true,
      hasTeraType: false,
      statMode: StatValueMode.evs,
      statMax: 31,
      evTotalCap: 510,
      evPerStatCap: 252,
    ),
    9: GenerationMechanics(
      gen: 9,
      hasItems: true,
      hasAbilities: true,
      hasShiny: true,
      hasHiddenPower: false,
      hasMegaStone: false,
      hasZCrystal: false,
      hasGigantamax: false,
      hasTeraType: true,
      statMode: StatValueMode.evs,
      statMax: 31,
      evTotalCap: 510,
      evPerStatCap: 252,
    ),
  };
}

enum StatValueMode {
  /// Gen 1–2: Determinant Values, 0–15 per stat, no total cap.
  dvs,
  /// Gen 3+: Effort Values, 0–252 per stat, 510 total cap.
  evs,
}

// ---------------------------------------------------------------------------
// PS data entry models (trimmed from sync script output)
// ---------------------------------------------------------------------------

class PsMoveEntry {
  final String id;
  final String name;
  final int gen;
  final String type;
  final String category; // Physical | Special | Status
  final int basePower;
  final int? accuracy;   // null = always hits
  final int pp;
  final bool isZMove;
  final bool isMaxMove;

  const PsMoveEntry({
    required this.id,
    required this.name,
    required this.gen,
    required this.type,
    required this.category,
    required this.basePower,
    this.accuracy,
    required this.pp,
    this.isZMove = false,
    this.isMaxMove = false,
  });

  factory PsMoveEntry.fromJson(String id, Map<String, dynamic> j) =>
      PsMoveEntry(
        id: id,
        name: j['name'] as String? ?? id,
        gen: j['gen'] as int? ?? 1,
        type: j['type'] as String? ?? 'normal',
        category: j['category'] as String? ?? 'Status',
        basePower: j['base_power'] as int? ?? 0,
        // PS stores accuracy as true (bool) for moves that always hit.
        accuracy: j['accuracy'] is int ? j['accuracy'] as int : null,
        pp: j['pp'] as int? ?? 0,
        isZMove: j['is_z_move'] as bool? ?? false,
        isMaxMove: j['is_max_move'] as bool? ?? false,
      );
}

class PsItemEntry {
  final String id;
  final String name;
  final int gen;
  final bool isMegaStone;
  final String? megaSpecies;
  final bool isZCrystal;
  final bool isBerry;
  final bool isPlate;
  final bool isMemory;

  const PsItemEntry({
    required this.id,
    required this.name,
    required this.gen,
    this.isMegaStone = false,
    this.megaSpecies,
    this.isZCrystal = false,
    this.isBerry = false,
    this.isPlate = false,
    this.isMemory = false,
  });

  factory PsItemEntry.fromJson(String id, Map<String, dynamic> j) =>
      PsItemEntry(
        id: id,
        name: j['name'] as String? ?? id,
        gen: j['gen'] as int? ?? 1,
        isMegaStone: j['is_mega_stone'] as bool? ?? false,
        megaSpecies: j['mega_species'] as String?,
        isZCrystal: j['is_z_crystal'] as bool? ?? false,
        isBerry: j['is_berry'] as bool? ?? false,
        isPlate: j['is_plate'] as bool? ?? false,
        isMemory: j['is_memory'] as bool? ?? false,
      );
}

class PsAbilityEntry {
  final String id;
  final String name;
  final int gen;

  const PsAbilityEntry({
    required this.id,
    required this.name,
    required this.gen,
  });

  factory PsAbilityEntry.fromJson(String id, Map<String, dynamic> j) =>
      PsAbilityEntry(
        id: id,
        name: j['name'] as String? ?? id,
        gen: j['gen'] as int? ?? 3,
      );
}
