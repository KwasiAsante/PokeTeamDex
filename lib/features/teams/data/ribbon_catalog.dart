// Hardcoded ribbon catalog sourced from Bulbapedia.
// Ribbons are organized into display categories.
// Each ribbon has a stable id used for JSON storage.

class RibbonInfo {
  final String id;
  final String name;
  const RibbonInfo(this.id, this.name);
}

class RibbonCategory {
  final String name;
  final List<RibbonInfo> ribbons;
  const RibbonCategory({required this.name, required this.ribbons});
}

const List<RibbonCategory> kRibbonCatalog = [
  // ── Battle ─────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Battle', ribbons: [
    RibbonInfo('champion',          'Champion Ribbon'),
    RibbonInfo('sinnoh-champ',      'Sinnoh Champion Ribbon'),
    RibbonInfo('kalos-champ',       'Kalos Champion Ribbon'),
    RibbonInfo('alola-champ',       'Alola Champion Ribbon'),
    RibbonInfo('galar-champ',       'Galar Champion Ribbon'),
    RibbonInfo('regional-champ',    'Regional Champion Ribbon'),
    RibbonInfo('national-champ',    'National Champion Ribbon'),
    RibbonInfo('world-champ',       'World Champion Ribbon'),
    RibbonInfo('battle-champ',      'Battle Champion Ribbon'),
    RibbonInfo('bt-normal',         'Battle Tower (Normal)'),
    RibbonInfo('bt-great',          'Battle Tower (Great)'),
    RibbonInfo('bt-ultra',          'Battle Tower (Ultra)'),
    RibbonInfo('bt-master',         'Battle Tower (Master)'),
    RibbonInfo('bf-ability',        'Battle Frontier — Ability'),
    RibbonInfo('bf-great-ability',  'Battle Frontier — Great Ability'),
    RibbonInfo('bf-double',         'Battle Frontier — Double'),
    RibbonInfo('bf-multi',          'Battle Frontier — Multi'),
    RibbonInfo('bf-pair',           'Battle Frontier — Pair'),
    RibbonInfo('bf-world',          'Battle Frontier — World'),
    RibbonInfo('btree-normal',      'Battle Tree (Normal)'),
    RibbonInfo('btree-super',       'Battle Tree (Super)'),
    RibbonInfo('btree-master',      'Battle Tree (Master)'),
    RibbonInfo('legend',            'Legend Ribbon'),
  ]),

  // ── Contest ────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Contest', ribbons: [
    RibbonInfo('cool-normal',       'Cool Ribbon'),
    RibbonInfo('cool-great',        'Cool Ribbon (Great)'),
    RibbonInfo('cool-ultra',        'Cool Ribbon (Ultra)'),
    RibbonInfo('cool-master',       'Cool Ribbon (Master)'),
    RibbonInfo('beautiful-normal',  'Beautiful Ribbon'),
    RibbonInfo('beautiful-great',   'Beautiful Ribbon (Great)'),
    RibbonInfo('beautiful-ultra',   'Beautiful Ribbon (Ultra)'),
    RibbonInfo('beautiful-master',  'Beautiful Ribbon (Master)'),
    RibbonInfo('cute-normal',       'Cute Ribbon'),
    RibbonInfo('cute-great',        'Cute Ribbon (Great)'),
    RibbonInfo('cute-ultra',        'Cute Ribbon (Ultra)'),
    RibbonInfo('cute-master',       'Cute Ribbon (Master)'),
    RibbonInfo('clever-normal',     'Clever Ribbon'),
    RibbonInfo('clever-great',      'Clever Ribbon (Great)'),
    RibbonInfo('clever-ultra',      'Clever Ribbon (Ultra)'),
    RibbonInfo('clever-master',     'Clever Ribbon (Master)'),
    RibbonInfo('tough-normal',      'Tough Ribbon'),
    RibbonInfo('tough-great',       'Tough Ribbon (Great)'),
    RibbonInfo('tough-ultra',       'Tough Ribbon (Ultra)'),
    RibbonInfo('tough-master',      'Tough Ribbon (Master)'),
    RibbonInfo('contest-memory',    'Contest Memory Ribbon'),
  ]),

  // ── Memorial ───────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Memorial', ribbons: [
    RibbonInfo('effort',      'Effort Ribbon'),
    RibbonInfo('best-friend', 'Best Friends Ribbon'),
    RibbonInfo('footprint',   'Footprint Ribbon'),
    RibbonInfo('alert',       'Alert Ribbon'),
    RibbonInfo('shock',       'Shock Ribbon'),
    RibbonInfo('downcast',    'Downcast Ribbon'),
    RibbonInfo('careless',    'Careless Ribbon'),
    RibbonInfo('relax',       'Relax Ribbon'),
    RibbonInfo('snooze',      'Snooze Ribbon'),
    RibbonInfo('smile',       'Smile Ribbon'),
    RibbonInfo('royal',       'Royal Ribbon'),
    RibbonInfo('gorgeous',    'Gorgeous Ribbon'),
    RibbonInfo('gorgeous-royal', 'Gorgeous Royal Ribbon'),
    RibbonInfo('classic',     'Classic Ribbon'),
    RibbonInfo('premier',     'Premier Ribbon'),
  ]),

  // ── Gift ───────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Gift', ribbons: [
    RibbonInfo('birthday',   'Birthday Ribbon'),
    RibbonInfo('special',    'Special Ribbon'),
    RibbonInfo('souvenir',   'Souvenir Ribbon'),
    RibbonInfo('wishing',    'Wishing Ribbon'),
    RibbonInfo('country',    'Country Ribbon'),
    RibbonInfo('national',   'National Ribbon'),
    RibbonInfo('earth',      'Earth Ribbon'),
    RibbonInfo('world',      'World Ribbon'),
    RibbonInfo('event',      'Event Ribbon'),
    RibbonInfo('festival',   'Festival Ribbon'),
  ]),

  // ── Special ────────────────────────────────────────────────────────────────
  RibbonCategory(name: 'Special', ribbons: [
    RibbonInfo('twinkling-star', 'Twinkling Star Ribbon'),
    RibbonInfo('master-rank',    'Master Rank Ribbon'),
    RibbonInfo('once-in-day',    'Once in a Day Ribbon'),
    RibbonInfo('count-50',       'Count 50 Ribbon'),
    RibbonInfo('count-100',      'Count 100 Ribbon'),
    RibbonInfo('count-1000',     'Count 1000 Ribbon'),
    RibbonInfo('count-2000',     'Count 2000 Ribbon'),
    RibbonInfo('count-5000',     'Count 5000 Ribbon'),
    RibbonInfo('count-10000',    'Count 10000 Ribbon'),
    RibbonInfo('count-25000',    'Count 25000 Ribbon'),
    RibbonInfo('count-50000',    'Count 50000 Ribbon'),
    RibbonInfo('count-75000',    'Count 75000 Ribbon'),
    RibbonInfo('count-100000',   'Count 100000 Ribbon'),
  ]),
];

/// Flat lookup from id → RibbonInfo.
final Map<String, RibbonInfo> kRibbonById = {
  for (final cat in kRibbonCatalog)
    for (final r in cat.ribbons) r.id: r,
};
