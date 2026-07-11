/// Type names for the 16 possible Hidden Power types (indices 0–15).
const kHiddenPowerTypeNames = [
  'Fighting', 'Flying', 'Poison', 'Ground', 'Rock', 'Bug',
  'Ghost',    'Steel',  'Fire',   'Water',  'Grass', 'Electric',
  'Psychic',  'Ice',    'Dragon', 'Dark',
];

/// Returns the 0–15 Hidden Power type index for the given per-stat values.
/// Unset values default to 31, the standard competitive default outside
/// Gen 2 — where the same fields instead hold 0–15 DVs (see
/// slot_config_screen.dart's StatValueMode.dvs gating).
///   Gen 2: type = (Atk DV mod 4)*4 + (Def DV mod 4).
///   Gen 3+: LSB of HP/Atk/Def/Spe/SpA/SpD, weighted 1/2/4/8/16/32.
int hiddenPowerTypeIndex({
  int? ivHp,
  int? ivAtk,
  int? ivDef,
  int? ivSpa,
  int? ivSpd,
  int? ivSpe,
  int? gen,
}) {
  final hp = ivHp ?? 31;
  final atk = ivAtk ?? 31;
  final def = ivDef ?? 31;
  final spa = ivSpa ?? 31;
  final spd = ivSpd ?? 31;
  final spe = ivSpe ?? 31;
  if (gen == 2) {
    return (atk % 4) * 4 + (def % 4);
  }
  final n = (hp & 1) +
      (atk & 1) * 2 +
      (def & 1) * 4 +
      (spe & 1) * 8 +
      (spa & 1) * 16 +
      (spd & 1) * 32;
  return (n * 15) ~/ 63;
}

/// Returns the Hidden Power type name for the given per-stat values.
String hiddenPowerTypeName({
  int? ivHp,
  int? ivAtk,
  int? ivDef,
  int? ivSpa,
  int? ivSpd,
  int? ivSpe,
  int? gen,
}) =>
    kHiddenPowerTypeNames[hiddenPowerTypeIndex(
      ivHp: ivHp,
      ivAtk: ivAtk,
      ivDef: ivDef,
      ivSpa: ivSpa,
      ivSpd: ivSpd,
      ivSpe: ivSpe,
      gen: gen,
    )];

/// Returns Hidden Power's power. Gen 6+ is fixed at 60. Gen 3–5 ranges
/// 30–70 using the second-lowest bit of each IV. Gen 2 ranges 31–70 using
/// DV MSBs (Special DV stands in for SpA/SpD, matching Gen 2's unified
/// Special stat).
int hiddenPowerPower({
  int? ivHp,
  int? ivAtk,
  int? ivDef,
  int? ivSpa,
  int? ivSpd,
  int? ivSpe,
  int? gen,
}) {
  if (gen != null && gen >= 6) return 60;
  final hp = ivHp ?? 31;
  final atk = ivAtk ?? 31;
  final def = ivDef ?? 31;
  final spa = ivSpa ?? 31;
  final spe = ivSpe ?? 31;
  if (gen == 2) {
    final v = spa >= 8 ? 1 : 0;
    final w = spe >= 8 ? 1 : 0;
    final x = def >= 8 ? 1 : 0;
    final y = atk >= 8 ? 1 : 0;
    final z = spa % 4;
    return (5 * (v + 2 * w + 4 * x + 8 * y) + z) ~/ 2 + 31;
  }
  final spd = ivSpd ?? 31;
  final u = ((hp >> 1) & 1) +
      ((atk >> 1) & 1) * 2 +
      ((def >> 1) & 1) * 4 +
      ((spe >> 1) & 1) * 8 +
      ((spa >> 1) & 1) * 16 +
      ((spd >> 1) & 1) * 32;
  return (u * 40) ~/ 63 + 30;
}
