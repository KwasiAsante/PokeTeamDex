import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/features/teams/data/form_filter.dart';

void main() {
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

    test('excludes -primal forms', () {
      final result = filterFormChips(
        varieties: ['kyogre', 'kyogre-primal'],
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
}
