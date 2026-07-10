import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';

void main() {
  group('BackendMoveEntry', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'thunderbolt',
        'display_name': 'Thunderbolt',
        'gen': 1,
        'type': 'electric',
        'damage_class': 'special',
        'power': 90,
        'accuracy': 100,
        'pp': 15,
        'priority': 0,
        'is_z_move': false,
        'is_max_move': false,
        'z_move_base': null,
        'flags': {'contact': 0},
        'secondary': null,
        'contest_type': 'cool',
        'target': 'selected-pokemon',
        'effect_short': 'May paralyze target.',
        'effect': 'May paralyze the target.',
      };
      final entry = BackendMoveEntry.fromJson(json);
      expect(entry.name, 'thunderbolt');
      expect(entry.displayName, 'Thunderbolt');
      expect(entry.gen, 1);
      expect(entry.type, 'electric');
      expect(entry.damageClass, 'special');
      expect(entry.power, 90);
      expect(entry.accuracy, 100);
      expect(entry.pp, 15);
      expect(entry.isZMove, false);
      expect(entry.isMaxMove, false);
      expect(entry.effectShort, 'May paralyze target.');
    });

    test('toJson round-trips through fromJson', () {
      const entry = BackendMoveEntry(
        name: 'thunderbolt',
        displayName: 'Thunderbolt',
        gen: 1,
        type: 'electric',
        damageClass: 'special',
        power: 90,
        accuracy: 100,
        pp: 15,
      );
      final roundTripped = BackendMoveEntry.fromJson(entry.toJson());
      expect(roundTripped.name, entry.name);
      expect(roundTripped.gen, entry.gen);
      expect(roundTripped.type, entry.type);
      expect(roundTripped.damageClass, entry.damageClass);
      expect(roundTripped.power, entry.power);
    });
  });

  group('BackendItemEntry', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'leftovers',
        'display_name': 'Leftovers',
        'gen': 2,
        'category': 'held-items',
        'sprite': 'https://example.com/leftovers.png',
        'fling_power': 10,
        'is_mega_stone': false,
        'mega_species': null,
        'is_z_crystal': false,
        'is_berry': false,
        'is_plate': false,
        'is_memory': false,
        'effect_short': 'Restores 1/16 HP.',
        'effect': 'Restores 1/16 HP each turn.',
      };
      final entry = BackendItemEntry.fromJson(json);
      expect(entry.name, 'leftovers');
      expect(entry.gen, 2);
      expect(entry.category, 'held-items');
      expect(entry.isBerry, false);
      expect(entry.effectShort, 'Restores 1/16 HP.');
    });

    test('toJson round-trips through fromJson', () {
      const entry = BackendItemEntry(
        name: 'leftovers',
        displayName: 'Leftovers',
        gen: 2,
        category: 'held-items',
      );
      final roundTripped = BackendItemEntry.fromJson(entry.toJson());
      expect(roundTripped.name, entry.name);
      expect(roundTripped.gen, entry.gen);
      expect(roundTripped.category, entry.category);
    });
  });

  group('BackendAbilityEntry', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'blaze',
        'display_name': 'Blaze',
        'gen': 3,
        'effect_short': 'Powers up Fire moves in a pinch.',
        'effect': 'Powers up Fire-type moves in a pinch.',
        'slot': null,
        'is_hidden': false,
      };
      final entry = BackendAbilityEntry.fromJson(json);
      expect(entry.name, 'blaze');
      expect(entry.gen, 3);
      expect(entry.effectShort, 'Powers up Fire moves in a pinch.');
      expect(entry.isHidden, false);
    });

    test('toJson round-trips through fromJson', () {
      const entry = BackendAbilityEntry(
        name: 'levitate',
        displayName: 'Levitate',
        gen: 3,
      );
      final roundTripped = BackendAbilityEntry.fromJson(entry.toJson());
      expect(roundTripped.name, entry.name);
      expect(roundTripped.gen, entry.gen);
    });
  });

  group('PaginatedCatalogResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'items': [
          {
            'name': 'tackle',
            'display_name': 'Tackle',
            'gen': 1,
            'type': 'normal',
            'damage_class': 'physical',
            'power': 40,
            'accuracy': 100,
            'pp': 35,
            'priority': 0,
            'is_z_move': false,
            'is_max_move': false,
            'flags': {}
          },
        ],
        'total': 1,
        'page': 1,
        'page_size': 1,
        'total_pages': 1,
      };
      final response = PaginatedCatalogResponse.fromJson(
          json, (item) => BackendMoveEntry.fromJson(item as Map<String, dynamic>));
      expect(response.items.length, 1);
      expect(response.items[0].name, 'tackle');
      expect(response.total, 1);
    });
  });
}
