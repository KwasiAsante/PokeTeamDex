// Gen III+ stat formulas.
// Extracted here so they can be unit-tested independently of the UI.

/// HP formula (Gen III+).
int calcHP(int base, int iv, int ev, int level) =>
    ((2 * base + iv + ev ~/ 4) * level) ~/ 100 + level + 10;

/// Non-HP stat formula (Gen III+).
int calcStat(int base, int iv, int ev, int level, double natureMod) {
  final inner = ((2 * base + iv + ev ~/ 4) * level) ~/ 100 + 5;
  return (inner * natureMod).floor();
}

/// Nature modifier: 1.1 if [statKey] is the boosted stat, 0.9 if lowered,
/// 1.0 for neutral or unknown nature.
double natureMod(String? natureName, String statKey) {
  if (natureName == null) return 1.0;
  final mods = _kNatureModifiers[natureName.toLowerCase()];
  if (mods == null) return 1.0;
  if (mods.$1 == statKey) return 1.1;
  if (mods.$2 == statKey) return 0.9;
  return 1.0;
}

const _kNatureModifiers = <String, (String?, String?)>{
  'hardy':   (null, null),
  'docile':  (null, null),
  'serious': (null, null),
  'bashful': (null, null),
  'quirky':  (null, null),
  'lonely':  ('attack', 'defense'),
  'brave':   ('attack', 'speed'),
  'adamant': ('attack', 'special-attack'),
  'naughty': ('attack', 'special-defense'),
  'bold':    ('defense', 'attack'),
  'relaxed': ('defense', 'speed'),
  'impish':  ('defense', 'special-attack'),
  'lax':     ('defense', 'special-defense'),
  'timid':   ('speed', 'attack'),
  'hasty':   ('speed', 'defense'),
  'jolly':   ('speed', 'special-attack'),
  'naive':   ('speed', 'special-defense'),
  'modest':  ('special-attack', 'attack'),
  'mild':    ('special-attack', 'defense'),
  'quiet':   ('special-attack', 'speed'),
  'rash':    ('special-attack', 'special-defense'),
  'calm':    ('special-defense', 'attack'),
  'gentle':  ('special-defense', 'defense'),
  'sassy':   ('special-defense', 'speed'),
  'careful': ('special-defense', 'special-attack'),
};
