// Hardcoded ribbon catalog sourced from Bulbapedia.
// Ribbons are organized into display categories.
// Each ribbon has a stable id used for JSON storage and an optional
// spriteName that maps to the pokesprite misc/ribbon image.

const _kSpriteBase =
    'https://raw.githubusercontent.com/msikma/pokesprite/master/misc/ribbon/';

class RibbonInfo {
  final String id;
  final String name;
  // Filename (without .png) under the pokesprite misc/ribbon folder.
  // null = no sprite available; fallback icon is shown instead.
  final String? spriteName;

  const RibbonInfo(this.id, this.name, [this.spriteName]);

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
    RibbonInfo('champion',         'Champion Ribbon',          'champion-ribbon'),
    RibbonInfo('sinnoh-champ',     'Sinnoh Champion Ribbon',   'sinnoh-champion-ribbon'),
    RibbonInfo('kalos-champ',      'Kalos Champion Ribbon',    'kalos-champion-ribbon'),
    RibbonInfo('alola-champ',      'Alola Champion Ribbon',    'alola-champion-ribbon'),
    RibbonInfo('galar-champ',      'Galar Champion Ribbon',    'galar-champion-ribbon'),
    RibbonInfo('regional-champ',   'Regional Champion Ribbon', 'regional-champion-ribbon'),
    RibbonInfo('national-champ',   'National Champion Ribbon', 'national-champion-ribbon'),
    RibbonInfo('world-champ',      'World Champion Ribbon',    'world-champion-ribbon'),
    RibbonInfo('battle-champ',     'Battle Champion Ribbon',   'battle-champion-ribbon'),
    RibbonInfo('bt-normal',        'Battle Tower (Normal)',     'normal-ribbon'),
    RibbonInfo('bt-great',         'Battle Tower (Great)',      'great-ribbon'),
    RibbonInfo('bt-ultra',         'Battle Tower (Ultra)',      'ultra-ribbon'),
    RibbonInfo('bt-master',        'Battle Tower (Master)',     'master-ribbon'),
    RibbonInfo('bf-ability',       'Battle Frontier — Ability',       'ability-ribbon'),
    RibbonInfo('bf-great-ability', 'Battle Frontier — Great Ability', 'great-ability-ribbon'),
    RibbonInfo('bf-double',        'Battle Frontier — Double',        'double-ability-ribbon'),
    RibbonInfo('bf-multi',         'Battle Frontier — Multi',         'multi-ability-ribbon'),
    RibbonInfo('bf-pair',          'Battle Frontier — Pair',          'pair-ability-ribbon'),
    RibbonInfo('bf-world',         'Battle Frontier — World',         'world-ability-ribbon'),
    RibbonInfo('btree-normal',     'Battle Tree (Normal)',  'battle-tree-normal-ribbon'),
    RibbonInfo('btree-super',      'Battle Tree (Super)',   'battle-tree-super-ribbon'),
    RibbonInfo('btree-master',     'Battle Tree (Master)',  'battle-tree-master-ribbon'),
    RibbonInfo('legend',           'Legend Ribbon',         'legend-ribbon'),
  ]),

  // ── Contest ────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Contest', ribbons: [
    RibbonInfo('cool-normal',       'Cool Ribbon',              'cool-ribbon'),
    RibbonInfo('cool-great',        'Cool Ribbon (Super)',       'cool-ribbon-super'),
    RibbonInfo('cool-ultra',        'Cool Ribbon (Hyper)',       'cool-ribbon-hyper'),
    RibbonInfo('cool-master',       'Cool Ribbon (Master)',      'cool-ribbon-master'),
    RibbonInfo('beautiful-normal',  'Beautiful Ribbon',          'beautiful-ribbon'),
    RibbonInfo('beautiful-great',   'Beautiful Ribbon (Super)',  'beautiful-ribbon-super'),
    RibbonInfo('beautiful-ultra',   'Beautiful Ribbon (Hyper)',  'beautiful-ribbon-hyper'),
    RibbonInfo('beautiful-master',  'Beautiful Ribbon (Master)', 'beautiful-ribbon-master'),
    RibbonInfo('cute-normal',       'Cute Ribbon',               'cute-ribbon'),
    RibbonInfo('cute-great',        'Cute Ribbon (Super)',        'cute-ribbon-super'),
    RibbonInfo('cute-ultra',        'Cute Ribbon (Hyper)',        'cute-ribbon-hyper'),
    RibbonInfo('cute-master',       'Cute Ribbon (Master)',       'cute-ribbon-master'),
    RibbonInfo('clever-normal',     'Clever Ribbon',              'clever-ribbon'),
    RibbonInfo('clever-great',      'Clever Ribbon (Super)',      'clever-ribbon-super'),
    RibbonInfo('clever-ultra',      'Clever Ribbon (Hyper)',      'clever-ribbon-hyper'),
    RibbonInfo('clever-master',     'Clever Ribbon (Master)',     'clever-ribbon-master'),
    RibbonInfo('tough-normal',      'Tough Ribbon',               'tough-ribbon'),
    RibbonInfo('tough-great',       'Tough Ribbon (Super)',       'tough-ribbon-super'),
    RibbonInfo('tough-ultra',       'Tough Ribbon (Hyper)',       'tough-ribbon-hyper'),
    RibbonInfo('tough-master',      'Tough Ribbon (Master)',      'tough-ribbon-master'),
    RibbonInfo('contest-memory',    'Contest Memory Ribbon',      'contest-memory-ribbon'),
  ]),

  // ── Memorial ───────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Memorial', ribbons: [
    RibbonInfo('effort',         'Effort Ribbon',        'effort-ribbon'),
    RibbonInfo('best-friend',    'Best Friends Ribbon',  'best-friends-ribbon'),
    RibbonInfo('footprint',      'Footprint Ribbon',     'footprint-ribbon'),
    RibbonInfo('alert',          'Alert Ribbon',         'alert-ribbon'),
    RibbonInfo('shock',          'Shock Ribbon',         'shock-ribbon'),
    RibbonInfo('downcast',       'Downcast Ribbon',      'downcast-ribbon'),
    RibbonInfo('careless',       'Careless Ribbon',      'careless-ribbon'),
    RibbonInfo('relax',          'Relax Ribbon',         'relax-ribbon'),
    RibbonInfo('snooze',         'Snooze Ribbon',        'snooze-ribbon'),
    RibbonInfo('smile',          'Smile Ribbon',         'smile-ribbon'),
    RibbonInfo('royal',          'Royal Ribbon',         'royal-ribbon'),
    RibbonInfo('gorgeous',       'Gorgeous Ribbon',      'gorgeous-ribbon'),
    RibbonInfo('gorgeous-royal', 'Gorgeous Royal Ribbon','gorgeous-royal-ribbon'),
    RibbonInfo('classic',        'Classic Ribbon',       'classic-ribbon'),
    RibbonInfo('premier',        'Premier Ribbon',       'premier-ribbon'),
  ]),

  // ── Gift ───────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Gift', ribbons: [
    RibbonInfo('birthday',  'Birthday Ribbon',  'birthday-ribbon'),
    RibbonInfo('special',   'Special Ribbon',   'special-ribbon'),
    RibbonInfo('souvenir',  'Souvenir Ribbon',  'souvenir-ribbon'),
    RibbonInfo('wishing',   'Wishing Ribbon',   'wishing-ribbon'),
    RibbonInfo('country',   'Country Ribbon',   'country-ribbon'),
    RibbonInfo('national',  'National Ribbon',  'national-ribbon'),
    RibbonInfo('earth',     'Earth Ribbon',     'earth-ribbon'),
    RibbonInfo('world',     'World Ribbon',     'world-ribbon'),
    RibbonInfo('event',     'Event Ribbon',     'event-ribbon'),
    RibbonInfo('festival',  'Festival Ribbon',  'festival-ribbon'),
  ]),

  // ── Special ────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Special', ribbons: [
    RibbonInfo('twinkling-star', 'Twinkling Star Ribbon', 'twinkling-star-ribbon'),
    RibbonInfo('master-rank',    'Master Rank Ribbon',    'master-rank-ribbon'),
    RibbonInfo('once-in-day',    'Once in a Day Ribbon',  null),
    RibbonInfo('count-50',       'Count 50 Ribbon',       null),
    RibbonInfo('count-100',      'Count 100 Ribbon',      null),
    RibbonInfo('count-1000',     'Count 1000 Ribbon',     null),
    RibbonInfo('count-2000',     'Count 2000 Ribbon',     null),
    RibbonInfo('count-5000',     'Count 5000 Ribbon',     null),
    RibbonInfo('count-10000',    'Count 10000 Ribbon',    null),
    RibbonInfo('count-25000',    'Count 25000 Ribbon',    null),
    RibbonInfo('count-50000',    'Count 50000 Ribbon',    null),
    RibbonInfo('count-75000',    'Count 75000 Ribbon',    null),
    RibbonInfo('count-100000',   'Count 100000 Ribbon',   null),
  ]),
];

/// Flat lookup from id → RibbonInfo.
final Map<String, RibbonInfo> kRibbonById = {
  for (final cat in kRibbonCatalog)
    for (final r in cat.ribbons) r.id: r,
};
