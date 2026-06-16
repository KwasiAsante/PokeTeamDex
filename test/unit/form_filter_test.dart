import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/teams/data/form_filter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  group('filterFormChips — empty / trivial', () {
    test('returns empty when varieties is empty', () {
      expect(filterFormChips(varieties: [], heldItem: null, abilityName: null), isEmpty);
    });

    test('returns empty when varieties has only the default form', () {
      expect(filterFormChips(varieties: ['bulbasaur'], heldItem: null, abilityName: null), isEmpty);
    });

    test('default form (first entry) is never included', () {
      final result = filterFormChips(
        varieties: ['rotom', 'rotom-heat', 'rotom-wash'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('rotom')));
      expect(result, containsAll(['rotom-heat', 'rotom-wash']));
    });
  });

  group('filterFormChips — always-exclude suffixes', () {
    test('excludes -mega forms', () {
      final result = filterFormChips(
        varieties: ['charizard', 'charizard-mega-x', 'charizard-mega-y'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isEmpty);
    });

    test('excludes -gmax forms', () {
      final result = filterFormChips(
        varieties: ['charizard', 'charizard-gmax'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isEmpty);
    });

    test('excludes -eternamax forms', () {
      final result = filterFormChips(
        varieties: ['eternatus', 'eternatus-eternamax'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isEmpty);
    });

    test('excludes -female suffix forms', () {
      final result = filterFormChips(
        varieties: ['meowstic', 'meowstic-female'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isEmpty);
    });
  });

  group('filterFormChips — always-exclude set', () {
    test('excludes indeedee-female', () {
      final result = filterFormChips(
        varieties: ['indeedee', 'indeedee-female'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('indeedee-female')));
    });

    test('excludes basculegion-female', () {
      final result = filterFormChips(
        varieties: ['basculegion', 'basculegion-female'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('basculegion-female')));
    });

    test('excludes oinkologne-female', () {
      final result = filterFormChips(
        varieties: ['oinkologne', 'oinkologne-female'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('oinkologne-female')));
    });
  });

  group('filterFormChips — ability-gated forms', () {
    test('aegislash-blade shown when stance-change is selected', () {
      final result = filterFormChips(
        varieties: ['aegislash', 'aegislash-blade'],
        heldItem: null,
        abilityName: 'stance-change',
      );
      expect(result, contains('aegislash-blade'));
    });

    test('aegislash-blade hidden without the matching ability', () {
      final result = filterFormChips(
        varieties: ['aegislash', 'aegislash-blade'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('aegislash-blade')));
    });

    test('aegislash-blade hidden with wrong ability', () {
      final result = filterFormChips(
        varieties: ['aegislash', 'aegislash-blade'],
        heldItem: null,
        abilityName: 'pressure',
      );
      expect(result, isNot(contains('aegislash-blade')));
    });

    test('darmanitan-zen shown with zen-mode ability', () {
      final result = filterFormChips(
        varieties: ['darmanitan', 'darmanitan-zen'],
        heldItem: null,
        abilityName: 'zen-mode',
      );
      expect(result, contains('darmanitan-zen'));
    });

    test('all minior core forms shown when shields-down selected', () {
      final cores = [
        'minior-red-core', 'minior-orange-core', 'minior-yellow-core',
        'minior-green-core', 'minior-blue-core', 'minior-indigo-core',
        'minior-violet-core',
      ];
      final result = filterFormChips(
        varieties: ['minior', ...cores],
        heldItem: null,
        abilityName: 'shields-down',
      );
      for (final core in cores) {
        expect(result, contains(core), reason: '$core should appear');
      }
    });

    test('ability check is case-insensitive', () {
      final result = filterFormChips(
        varieties: ['aegislash', 'aegislash-blade'],
        heldItem: null,
        abilityName: 'Stance-Change',
      );
      expect(result, contains('aegislash-blade'));
    });
  });

  group('filterFormChips — simple item-gated forms', () {
    test('giratina-origin shown when holding griseous-orb', () {
      final result = filterFormChips(
        varieties: ['giratina', 'giratina-origin'],
        heldItem: 'griseous-orb',
        abilityName: null,
      );
      expect(result, contains('giratina-origin'));
    });

    test('giratina-origin shown when holding griseous-core (Gen 9 renamed item)', () {
      final result = filterFormChips(
        varieties: ['giratina', 'giratina-origin'],
        heldItem: 'griseous-core',
        abilityName: null,
      );
      expect(result, contains('giratina-origin'));
    });

    test('giratina-origin hidden without the item', () {
      final result = filterFormChips(
        varieties: ['giratina', 'giratina-origin'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('giratina-origin')));
    });

    test('zacian-crowned shown with rusted-sword', () {
      final result = filterFormChips(
        varieties: ['zacian', 'zacian-crowned'],
        heldItem: 'rusted-sword',
        abilityName: null,
      );
      expect(result, contains('zacian-crowned'));
    });

    test('item check is case-insensitive', () {
      final result = filterFormChips(
        varieties: ['giratina', 'giratina-origin'],
        heldItem: 'Griseous-Orb',
        abilityName: null,
      );
      expect(result, contains('giratina-origin'));
    });
  });

  group('filterFormChips — Primal Reversion (item-gated, not blanket-excluded)', () {
    // Unlike Mega Evolution (an optional in-battle action modelled as a
    // separate toggle), Primal Reversion triggers automatically and
    // unavoidably while Primal Groudon/Kyogre holds its orb — mechanically
    // identical to Giratina's Origin Forme, so it's gated the same way
    // rather than blanket-excluded by its `-primal` suffix.
    test('groudon-primal shown when holding red-orb', () {
      final result = filterFormChips(
        varieties: ['groudon', 'groudon-primal'],
        heldItem: 'red-orb',
        abilityName: null,
      );
      expect(result, contains('groudon-primal'));
    });

    test('groudon-primal hidden without the orb', () {
      final result = filterFormChips(
        varieties: ['groudon', 'groudon-primal'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('groudon-primal')));
    });

    test('kyogre-primal shown when holding blue-orb', () {
      final result = filterFormChips(
        varieties: ['kyogre', 'kyogre-primal'],
        heldItem: 'blue-orb',
        abilityName: null,
      );
      expect(result, contains('kyogre-primal'));
    });

    test('kyogre-primal hidden without the orb', () {
      final result = filterFormChips(
        varieties: ['kyogre', 'kyogre-primal'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('kyogre-primal')));
    });

    test('kyogre-primal hidden when holding the wrong orb', () {
      final result = filterFormChips(
        varieties: ['kyogre', 'kyogre-primal'],
        heldItem: 'red-orb',
        abilityName: null,
      );
      expect(result, isNot(contains('kyogre-primal')));
    });
  });

  group('filterFormChips — Arceus plate forms', () {
    test('arceus-fire shown when holding flame-plate', () {
      final result = filterFormChips(
        varieties: ['arceus', 'arceus-fire', 'arceus-water'],
        heldItem: 'flame-plate',
        abilityName: null,
      );
      expect(result, contains('arceus-fire'));
      expect(result, isNot(contains('arceus-water')));
    });

    test('arceus-fairy shown with pixie-plate', () {
      final result = filterFormChips(
        varieties: ['arceus', 'arceus-fairy'],
        heldItem: 'pixie-plate',
        abilityName: null,
      );
      expect(result, contains('arceus-fairy'));
    });

    test('no arceus forms shown without a plate', () {
      final result = filterFormChips(
        varieties: ['arceus', 'arceus-fire'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, isNot(contains('arceus-fire')));
    });
  });

  group('filterFormChips — Silvally memory forms', () {
    test('silvally-water shown when holding water-memory', () {
      final result = filterFormChips(
        varieties: ['silvally', 'silvally-water', 'silvally-fire'],
        heldItem: 'water-memory',
        abilityName: null,
      );
      expect(result, contains('silvally-water'));
      expect(result, isNot(contains('silvally-fire')));
    });

    test('silvally-dark shown with dark-memory', () {
      final result = filterFormChips(
        varieties: ['silvally', 'silvally-dark'],
        heldItem: 'dark-memory',
        abilityName: null,
      );
      expect(result, contains('silvally-dark'));
    });
  });

  group('filterFormChips — free chips', () {
    test('unrecognised alternate forms always shown', () {
      final result = filterFormChips(
        varieties: ['rotom', 'rotom-heat', 'rotom-wash', 'rotom-frost'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, containsAll(['rotom-heat', 'rotom-wash', 'rotom-frost']));
    });
  });

  group('filterFormChips — cosmetic forms', () {
    // Cosmetic-form species (Burmy, Shellos, Deerling, Cherrim, Xerneas, Unown,
    // …) have only ONE variety — the candidate list comes entirely from
    // [cosmeticForms], run through the same gating rules as varieties.
    test('cosmetic forms shown freely when unrecognised (Burmy cloaks)', () {
      final result = filterFormChips(
        varieties: ['burmy'],
        cosmeticForms: ['burmy-sandy', 'burmy-trash'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, containsAll(['burmy-sandy', 'burmy-trash']));
    });

    test('cosmetic forms shown freely when unrecognised (Shellos seas)', () {
      final result = filterFormChips(
        varieties: ['shellos'],
        cosmeticForms: ['shellos-east'],
        heldItem: null,
        abilityName: null,
      );
      expect(result, contains('shellos-east'));
    });

    test('cherrim-sunshine gated on flower-gift ability (cosmetic form)', () {
      final shown = filterFormChips(
        varieties: ['cherrim'],
        cosmeticForms: ['cherrim-sunshine'],
        heldItem: null,
        abilityName: 'flower-gift',
      );
      expect(shown, contains('cherrim-sunshine'));

      final hidden = filterFormChips(
        varieties: ['cherrim'],
        cosmeticForms: ['cherrim-sunshine'],
        heldItem: null,
        abilityName: null,
      );
      expect(hidden, isNot(contains('cherrim-sunshine')));
    });

    test('returns empty when there are no varieties and no cosmetic forms', () {
      expect(
        filterFormChips(varieties: ['ditto'], heldItem: null, abilityName: null),
        isEmpty,
      );
    });

    test('combines variety-based and cosmetic candidates', () {
      final result = filterFormChips(
        varieties: ['aegislash', 'aegislash-blade'],
        cosmeticForms: ['burmy-sandy'],
        heldItem: null,
        abilityName: 'stance-change',
      );
      expect(result, containsAll(['aegislash-blade', 'burmy-sandy']));
    });
  });

  group('filterFormChips — generation-gated forms', () {
    const unownVarieties = [
      'unown', 'unown-b', 'unown-exclamation', 'unown-question',
    ];

    test('unown-exclamation and unown-question hidden in Gen 2', () {
      final result = filterFormChips(
        varieties: unownVarieties,
        heldItem: null,
        abilityName: null,
        gen: 2,
      );
      expect(result, isNot(contains('unown-exclamation')));
      expect(result, isNot(contains('unown-question')));
      expect(result, contains('unown-b'));
    });

    test('unown-exclamation and unown-question shown in Gen 3', () {
      final result = filterFormChips(
        varieties: unownVarieties,
        heldItem: null,
        abilityName: null,
        gen: 3,
      );
      expect(result, contains('unown-exclamation'));
      expect(result, contains('unown-question'));
    });

    test('unown-exclamation and unown-question shown when no gen (no format)', () {
      final result = filterFormChips(
        varieties: unownVarieties,
        heldItem: null,
        abilityName: null,
      );
      expect(result, contains('unown-exclamation'));
      expect(result, contains('unown-question'));
    });
  });

  group('filterFormChips — regional form gen gating', () {
    // ── Alolan forms (min gen 7) ──────────────────────────────────────────
    test('alolan forms hidden in Gen 6', () {
      final result = filterFormChips(
        varieties: ['meowth', 'meowth-alola', 'meowth-galar'],
        heldItem: null,
        abilityName: null,
        gen: 6,
      );
      expect(result, isNot(contains('meowth-alola')));
      expect(result, isNot(contains('meowth-galar')));
    });

    test('alolan forms shown in Gen 7', () {
      final result = filterFormChips(
        varieties: ['meowth', 'meowth-alola'],
        heldItem: null,
        abilityName: null,
        gen: 7,
      );
      expect(result, contains('meowth-alola'));
    });

    // ── Galarian forms (min gen 8) ────────────────────────────────────────
    test('galarian forms hidden in Gen 7', () {
      final result = filterFormChips(
        varieties: ['ponyta', 'ponyta-galar'],
        heldItem: null,
        abilityName: null,
        gen: 7,
      );
      expect(result, isNot(contains('ponyta-galar')));
    });

    test('galarian forms shown in Gen 8', () {
      final result = filterFormChips(
        varieties: ['ponyta', 'ponyta-galar'],
        heldItem: null,
        abilityName: null,
        gen: 8,
      );
      expect(result, contains('ponyta-galar'));
    });

    test('galarian infix form (darmanitan-galar-zen) hidden below Gen 8', () {
      final result = filterFormChips(
        varieties: ['darmanitan-galar', 'darmanitan-galar-zen'],
        heldItem: null,
        abilityName: 'zen-mode',
        gen: 7,
      );
      expect(result, isNot(contains('darmanitan-galar-zen')));
    });

    test('galarian infix form (darmanitan-galar-zen) shown in Gen 8 with zen-mode', () {
      final result = filterFormChips(
        varieties: ['darmanitan-galar', 'darmanitan-galar-zen'],
        heldItem: null,
        abilityName: 'zen-mode',
        gen: 8,
      );
      expect(result, contains('darmanitan-galar-zen'));
    });

    // ── Hisuian forms (min gen 9) ─────────────────────────────────────────
    test('hisuian forms hidden in Gen 8', () {
      final result = filterFormChips(
        varieties: ['typhlosion', 'typhlosion-hisui'],
        heldItem: null,
        abilityName: null,
        gen: 8,
      );
      expect(result, isNot(contains('typhlosion-hisui')));
    });

    test('hisuian forms hidden in Gen 1 (original issue)', () {
      final result = filterFormChips(
        varieties: ['typhlosion', 'typhlosion-hisui'],
        heldItem: null,
        abilityName: null,
        gen: 1,
      );
      expect(result, isNot(contains('typhlosion-hisui')));
    });

    test('hisuian forms shown in Gen 9', () {
      final result = filterFormChips(
        varieties: ['typhlosion', 'typhlosion-hisui'],
        heldItem: null,
        abilityName: null,
        gen: 9,
      );
      expect(result, contains('typhlosion-hisui'));
    });

    // ── Paldean forms (min gen 9) ─────────────────────────────────────────
    test('paldean forms hidden in Gen 8', () {
      final result = filterFormChips(
        varieties: ['tauros', 'tauros-paldea-combat', 'tauros-paldea-blaze', 'tauros-paldea-aqua'],
        heldItem: null,
        abilityName: null,
        gen: 8,
      );
      expect(result, isNot(contains('tauros-paldea-combat')));
      expect(result, isNot(contains('tauros-paldea-blaze')));
      expect(result, isNot(contains('tauros-paldea-aqua')));
    });

    test('paldean forms shown in Gen 9', () {
      final result = filterFormChips(
        varieties: ['tauros', 'tauros-paldea-combat'],
        heldItem: null,
        abilityName: null,
        gen: 9,
      );
      expect(result, contains('tauros-paldea-combat'));
    });

    // ── No-format (no gen restriction) ───────────────────────────────────
    test('all regional forms shown when no format (gen is null)', () {
      final result = filterFormChips(
        varieties: [
          'meowth', 'meowth-alola', 'meowth-galar',
          'typhlosion', 'typhlosion-hisui',
        ],
        heldItem: null,
        abilityName: null,
      );
      expect(result, containsAll(['meowth-alola', 'meowth-galar', 'typhlosion-hisui']));
    });
  });
}
