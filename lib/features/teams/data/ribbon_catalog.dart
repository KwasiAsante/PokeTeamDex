// Hardcoded ribbon catalog sourced from Bulbapedia.
// Ribbons are organized into display categories.
// Each ribbon has a stable id used for JSON storage, the generation it was
// first obtainable in (minGen), and an optional spriteName that maps to the
// pokesprite misc/ribbon image.

const _kSpriteBase =
    'https://raw.githubusercontent.com/msikma/pokesprite/master/misc/ribbon/';

class RibbonInfo {
  final String id;
  final String name;
  // Earliest generation this ribbon could be obtained.
  final int minGen;
  // Filename (without .png) under the pokesprite misc/ribbon folder.
  // null = no sprite available; fallback icon is shown instead.
  final String? spriteName;

  const RibbonInfo(this.id, this.name, this.minGen, [this.spriteName]);

  String? get spriteUrl =>
      spriteName != null ? '$_kSpriteBase$spriteName.png' : null;
}

class RibbonCategory {
  final String name;
  final List<RibbonInfo> ribbons;
  const RibbonCategory({required this.name, required this.ribbons});
}

const List<RibbonCategory> kRibbonCatalog = [
  // ── Battle ─────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Battle', ribbons: [
    RibbonInfo('champion',         'Champion Ribbon',          3, 'champion-ribbon'),
    RibbonInfo('sinnoh-champ',     'Sinnoh Champion Ribbon',   4, 'sinnoh-champion-ribbon'),
    RibbonInfo('kalos-champ',      'Kalos Champion Ribbon',    6, 'kalos-champion-ribbon'),
    RibbonInfo('alola-champ',      'Alola Champion Ribbon',    7, 'alola-champion-ribbon'),
    RibbonInfo('galar-champ',      'Galar Champion Ribbon',    8, 'galar-champion-ribbon'),
    RibbonInfo('regional-champ',   'Regional Champion Ribbon', 4, 'regional-champion-ribbon'),
    RibbonInfo('national-champ',   'National Champion Ribbon', 4, 'national-champion-ribbon'),
    RibbonInfo('world-champ',      'World Champion Ribbon',    4, 'world-champion-ribbon'),
    RibbonInfo('battle-champ',     'Battle Champion Ribbon',   4, 'battle-champion-ribbon'),
    RibbonInfo('bt-normal',        'Battle Tower (Normal)',     3, 'normal-ribbon'),
    RibbonInfo('bt-great',         'Battle Tower (Great)',      3, 'great-ribbon'),
    RibbonInfo('bt-ultra',         'Battle Tower (Ultra)',      3, 'ultra-ribbon'),
    RibbonInfo('bt-master',        'Battle Tower (Master)',     3, 'master-ribbon'),
    RibbonInfo('bf-ability',       'Battle Frontier — Ability',       3, 'ability-ribbon'),
    RibbonInfo('bf-great-ability', 'Battle Frontier — Great Ability', 3, 'great-ability-ribbon'),
    RibbonInfo('bf-double',        'Battle Frontier — Double',        3, 'double-ability-ribbon'),
    RibbonInfo('bf-multi',         'Battle Frontier — Multi',         3, 'multi-ability-ribbon'),
    RibbonInfo('bf-pair',          'Battle Frontier — Pair',          3, 'pair-ability-ribbon'),
    RibbonInfo('bf-world',         'Battle Frontier — World',         3, 'world-ability-ribbon'),
    RibbonInfo('btree-normal',     'Battle Tree (Normal)',  7, 'battle-tree-normal-ribbon'),
    RibbonInfo('btree-super',      'Battle Tree (Super)',   7, 'battle-tree-super-ribbon'),
    RibbonInfo('btree-master',     'Battle Tree (Master)',  7, 'battle-tree-master-ribbon'),
    RibbonInfo('legend',           'Legend Ribbon',         4, 'legend-ribbon'),
  ]),

  // ── Contest ────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Contest', ribbons: [
    RibbonInfo('cool-normal',       'Cool Ribbon',              3, 'cool-ribbon'),
    RibbonInfo('cool-great',        'Cool Ribbon (Super)',       3, 'cool-ribbon-super'),
    RibbonInfo('cool-ultra',        'Cool Ribbon (Hyper)',       3, 'cool-ribbon-hyper'),
    RibbonInfo('cool-master',       'Cool Ribbon (Master)',      3, 'cool-ribbon-master'),
    RibbonInfo('beautiful-normal',  'Beautiful Ribbon',          3, 'beautiful-ribbon'),
    RibbonInfo('beautiful-great',   'Beautiful Ribbon (Super)',  3, 'beautiful-ribbon-super'),
    RibbonInfo('beautiful-ultra',   'Beautiful Ribbon (Hyper)',  3, 'beautiful-ribbon-hyper'),
    RibbonInfo('beautiful-master',  'Beautiful Ribbon (Master)', 3, 'beautiful-ribbon-master'),
    RibbonInfo('cute-normal',       'Cute Ribbon',               3, 'cute-ribbon'),
    RibbonInfo('cute-great',        'Cute Ribbon (Super)',        3, 'cute-ribbon-super'),
    RibbonInfo('cute-ultra',        'Cute Ribbon (Hyper)',        3, 'cute-ribbon-hyper'),
    RibbonInfo('cute-master',       'Cute Ribbon (Master)',       3, 'cute-ribbon-master'),
    RibbonInfo('clever-normal',     'Clever Ribbon',              3, 'clever-ribbon'),
    RibbonInfo('clever-great',      'Clever Ribbon (Super)',      3, 'clever-ribbon-super'),
    RibbonInfo('clever-ultra',      'Clever Ribbon (Hyper)',      3, 'clever-ribbon-hyper'),
    RibbonInfo('clever-master',     'Clever Ribbon (Master)',     3, 'clever-ribbon-master'),
    RibbonInfo('tough-normal',      'Tough Ribbon',               3, 'tough-ribbon'),
    RibbonInfo('tough-great',       'Tough Ribbon (Super)',       3, 'tough-ribbon-super'),
    RibbonInfo('tough-ultra',       'Tough Ribbon (Hyper)',       3, 'tough-ribbon-hyper'),
    RibbonInfo('tough-master',      'Tough Ribbon (Master)',      3, 'tough-ribbon-master'),
    RibbonInfo('contest-memory',    'Contest Memory Ribbon',      6, 'contest-memory-ribbon'),
  ]),

  // ── Memorial ───────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Memorial', ribbons: [
    RibbonInfo('effort',         'Effort Ribbon',        3, 'effort-ribbon'),
    RibbonInfo('best-friend',    'Best Friends Ribbon',  6, 'best-friends-ribbon'),
    RibbonInfo('footprint',      'Footprint Ribbon',     4, 'footprint-ribbon'),
    RibbonInfo('alert',          'Alert Ribbon',         4, 'alert-ribbon'),
    RibbonInfo('shock',          'Shock Ribbon',         4, 'shock-ribbon'),
    RibbonInfo('downcast',       'Downcast Ribbon',      4, 'downcast-ribbon'),
    RibbonInfo('careless',       'Careless Ribbon',      4, 'careless-ribbon'),
    RibbonInfo('relax',          'Relax Ribbon',         4, 'relax-ribbon'),
    RibbonInfo('snooze',         'Snooze Ribbon',        4, 'snooze-ribbon'),
    RibbonInfo('smile',          'Smile Ribbon',         4, 'smile-ribbon'),
    RibbonInfo('royal',          'Royal Ribbon',         3, 'royal-ribbon'),
    RibbonInfo('gorgeous',       'Gorgeous Ribbon',      3, 'gorgeous-ribbon'),
    RibbonInfo('gorgeous-royal', 'Gorgeous Royal Ribbon',3, 'gorgeous-royal-ribbon'),
    RibbonInfo('classic',        'Classic Ribbon',       3, 'classic-ribbon'),
    RibbonInfo('premier',        'Premier Ribbon',       3, 'premier-ribbon'),
  ]),

  // ── Gift ───────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Gift', ribbons: [
    RibbonInfo('birthday',  'Birthday Ribbon',  4, 'birthday-ribbon'),
    RibbonInfo('special',   'Special Ribbon',   3, 'special-ribbon'),
    RibbonInfo('souvenir',  'Souvenir Ribbon',  3, 'souvenir-ribbon'),
    RibbonInfo('wishing',   'Wishing Ribbon',   3, 'wishing-ribbon'),
    RibbonInfo('country',   'Country Ribbon',   3, 'country-ribbon'),
    RibbonInfo('national',  'National Ribbon',  3, 'national-ribbon'),
    RibbonInfo('earth',     'Earth Ribbon',     3, 'earth-ribbon'),
    RibbonInfo('world',     'World Ribbon',     3, 'world-ribbon'),
    RibbonInfo('event',     'Event Ribbon',     3, 'event-ribbon'),
    RibbonInfo('festival',  'Festival Ribbon',  7, 'festival-ribbon'),
  ]),

  // ── Special ────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Special', ribbons: [
    RibbonInfo('twinkling-star', 'Twinkling Star Ribbon', 8, 'twinkling-star-ribbon'),
    RibbonInfo('master-rank',    'Master Rank Ribbon',    8, 'master-rank-ribbon'),
    RibbonInfo('once-in-day',    'Once in a Day Ribbon',  4, null),
    RibbonInfo('count-50',       'Count 50 Ribbon',       4, null),
    RibbonInfo('count-100',      'Count 100 Ribbon',      4, null),
    RibbonInfo('count-1000',     'Count 1000 Ribbon',     4, null),
    RibbonInfo('count-2000',     'Count 2000 Ribbon',     4, null),
    RibbonInfo('count-5000',     'Count 5000 Ribbon',     4, null),
    RibbonInfo('count-10000',    'Count 10000 Ribbon',    4, null),
    RibbonInfo('count-25000',    'Count 25000 Ribbon',    4, null),
    RibbonInfo('count-50000',    'Count 50000 Ribbon',    4, null),
    RibbonInfo('count-75000',    'Count 75000 Ribbon',    4, null),
    RibbonInfo('count-100000',   'Count 100000 Ribbon',   4, null),
  ]),
];

/// Flat lookup from id → RibbonInfo.
final Map<String, RibbonInfo> kRibbonById = {
  for (final cat in kRibbonCatalog)
    for (final r in cat.ribbons) r.id: r,
};
