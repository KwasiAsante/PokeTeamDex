import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/services/format/format_models.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  group('GenerationMechanics.forGen', () {
    test('gen 1 — no items, no abilities, no shiny, DVs, statMax 15, uncapped EVs', () {
      final m = GenerationMechanics.forGen(1);
      expect(m.gen, 1);
      expect(m.hasItems, isFalse);
      expect(m.hasAbilities, isFalse);
      expect(m.hasShiny, isFalse);
      expect(m.hasHiddenPower, isFalse);
      expect(m.hasMegaStone, isFalse);
      expect(m.hasZCrystal, isFalse);
      expect(m.hasGigantamax, isFalse);
      expect(m.hasTeraType, isFalse);
      expect(m.statMode, StatValueMode.dvs);
      expect(m.statMax, 15);
      expect(m.evTotalCap, isNull);
      expect(m.evPerStatCap, isNull);
    });

    test('gen 2 — items introduced, shiny introduced, still DVs', () {
      final m = GenerationMechanics.forGen(2);
      expect(m.hasItems, isTrue);
      expect(m.hasShiny, isTrue);
      expect(m.hasHiddenPower, isTrue);
      expect(m.hasAbilities, isFalse);
      expect(m.statMode, StatValueMode.dvs);
      expect(m.statMax, 15);
      expect(m.evTotalCap, isNull);
    });

    test('gen 3 — abilities, EVs, capped stat values', () {
      final m = GenerationMechanics.forGen(3);
      expect(m.hasAbilities, isTrue);
      expect(m.statMode, StatValueMode.evs);
      expect(m.statMax, 31);
      expect(m.evTotalCap, 510);
      expect(m.evPerStatCap, 252);
    });

    test('gen 6 — mega stones introduced', () {
      final m = GenerationMechanics.forGen(6);
      expect(m.hasMegaStone, isTrue);
      expect(m.hasZCrystal, isFalse);
      expect(m.hasHiddenPower, isTrue);
    });

    test('gen 7 — Z-crystals introduced, mega stones still present', () {
      final m = GenerationMechanics.forGen(7);
      expect(m.hasZCrystal, isTrue);
      expect(m.hasMegaStone, isTrue);
      expect(m.hasGigantamax, isFalse);
      expect(m.hasHiddenPower, isTrue);
    });

    test('gen 8 — Gigantamax, no hidden power, no mega stones, no Z-crystals', () {
      final m = GenerationMechanics.forGen(8);
      expect(m.hasGigantamax, isTrue);
      expect(m.hasHiddenPower, isFalse);
      expect(m.hasMegaStone, isFalse);
      expect(m.hasZCrystal, isFalse);
      expect(m.hasTeraType, isFalse);
    });

    test('gen 9 — Tera Type, no Gigantamax, no hidden power', () {
      final m = GenerationMechanics.forGen(9);
      expect(m.hasTeraType, isTrue);
      expect(m.hasGigantamax, isFalse);
      expect(m.hasHiddenPower, isFalse);
    });

    test('gen below 1 clamps to gen 1', () {
      final m = GenerationMechanics.forGen(0);
      expect(m.gen, 1);
      expect(m.statMode, StatValueMode.dvs);
    });

    test('gen above 9 clamps to gen 9', () {
      final m = GenerationMechanics.forGen(99);
      expect(m.gen, 9);
      expect(m.hasTeraType, isTrue);
    });
  });

  group('GameFormat.fromJson / toJson', () {
    test('roundtrip preserves all fields', () {
      final json = {
        'id': 'sv-ou',
        'name': 'SV OU',
        'short': 'OU',
        'type': 'competitive',
        'gen': 9,
      };
      final format = GameFormat.fromJson(json);
      expect(format.id, 'sv-ou');
      expect(format.name, 'SV OU');
      expect(format.short, 'OU');
      expect(format.type, FormatType.competitive);
      expect(format.gen, 9);
      expect(format.toJson(), json);
    });

    test('unknown type string falls back to FormatType.general', () {
      final format = GameFormat.fromJson({
        'id': 'x',
        'name': 'X',
        'short': 'X',
        'type': 'nonexistent',
        'gen': 8,
      });
      expect(format.type, FormatType.general);
    });

    test('mechanics property returns correct gen mechanics', () {
      final format = GameFormat.fromJson({
        'id': 'swsh',
        'name': 'SWSH',
        'short': 'SS',
        'type': 'game',
        'gen': 8,
      });
      expect(format.mechanics.hasGigantamax, isTrue);
    });

    test('all FormatType values roundtrip correctly', () {
      for (final type in FormatType.values) {
        final json = {
          'id': 'test',
          'name': 'Test',
          'short': 'T',
          'type': type.name,
          'gen': 9,
        };
        expect(GameFormat.fromJson(json).type, type);
      }
    });
  });

  group('PsMoveEntry.fromJson', () {
    test('parses all fields correctly', () {
      final entry = PsMoveEntry.fromJson('thunderbolt', {
        'name': 'Thunderbolt',
        'gen': 1,
        'type': 'Electric',
        'category': 'Special',
        'base_power': 90,
        'accuracy': 100,
        'pp': 15,
        'is_z_move': false,
        'is_max_move': false,
      });
      expect(entry.id, 'thunderbolt');
      expect(entry.name, 'Thunderbolt');
      expect(entry.gen, 1);
      expect(entry.type, 'electric'); // lowercased
      expect(entry.category, 'Special');
      expect(entry.basePower, 90);
      expect(entry.accuracy, 100);
      expect(entry.pp, 15);
      expect(entry.isZMove, isFalse);
      expect(entry.isMaxMove, isFalse);
    });

    test('accuracy: true (bool from PS) stored as null', () {
      final entry = PsMoveEntry.fromJson('swift', {
        'name': 'Swift',
        'gen': 1,
        'type': 'normal',
        'category': 'Special',
        'base_power': 60,
        'accuracy': true, // always hits
        'pp': 20,
      });
      expect(entry.accuracy, isNull);
    });

    test('isZMove flag is parsed', () {
      final entry = PsMoveEntry.fromJson('catastropika', {
        'name': 'Catastropika',
        'gen': 7,
        'type': 'electric',
        'category': 'Physical',
        'base_power': 210,
        'pp': 1,
        'is_z_move': true,
      });
      expect(entry.isZMove, isTrue);
      expect(entry.isMaxMove, isFalse);
    });

    test('isMaxMove flag is parsed', () {
      final entry = PsMoveEntry.fromJson('max-flare', {
        'name': 'Max Flare',
        'gen': 8,
        'type': 'fire',
        'category': 'Physical',
        'base_power': 140,
        'pp': 10,
        'is_max_move': true,
      });
      expect(entry.isMaxMove, isTrue);
      expect(entry.isZMove, isFalse);
    });

    test('missing optional fields use defaults', () {
      final entry = PsMoveEntry.fromJson('mystery', {});
      expect(entry.name, 'mystery'); // falls back to id
      expect(entry.gen, 1);
      expect(entry.type, 'normal');
      expect(entry.category, 'Status');
      expect(entry.basePower, 0);
      expect(entry.accuracy, isNull);
      expect(entry.pp, 0);
    });
  });

  group('PsItemEntry.fromJson', () {
    test('parses mega stone fields', () {
      final entry = PsItemEntry.fromJson('charizardite-x', {
        'name': 'Charizardite X',
        'gen': 6,
        'is_mega_stone': true,
        'mega_species': 'charizard',
      });
      expect(entry.isMegaStone, isTrue);
      expect(entry.megaSpecies, 'charizard');
      expect(entry.isZCrystal, isFalse);
    });

    test('parses Z-crystal flag', () {
      final entry = PsItemEntry.fromJson('electrium-z', {
        'name': 'Electrium Z',
        'gen': 7,
        'is_z_crystal': true,
      });
      expect(entry.isZCrystal, isTrue);
      expect(entry.isMegaStone, isFalse);
    });

    test('parses berry, plate, memory flags', () {
      final berry = PsItemEntry.fromJson('sitrus-berry', {'name': 'Sitrus Berry', 'gen': 3, 'is_berry': true});
      final plate = PsItemEntry.fromJson('flame-plate', {'name': 'Flame Plate', 'gen': 4, 'is_plate': true});
      final memory = PsItemEntry.fromJson('fire-memory', {'name': 'Fire Memory', 'gen': 7, 'is_memory': true});
      expect(berry.isBerry, isTrue);
      expect(plate.isPlate, isTrue);
      expect(memory.isMemory, isTrue);
    });

    test('missing optional fields default to false / null', () {
      final entry = PsItemEntry.fromJson('leftovers', {'name': 'Leftovers', 'gen': 2});
      expect(entry.isMegaStone, isFalse);
      expect(entry.megaSpecies, isNull);
      expect(entry.isZCrystal, isFalse);
      expect(entry.isBerry, isFalse);
      expect(entry.isPlate, isFalse);
      expect(entry.isMemory, isFalse);
    });
  });

  group('PsAbilityEntry.fromJson', () {
    test('parses id, name and gen', () {
      final entry = PsAbilityEntry.fromJson('levitate', {
        'name': 'Levitate',
        'gen': 3,
      });
      expect(entry.id, 'levitate');
      expect(entry.name, 'Levitate');
      expect(entry.gen, 3);
    });

    test('missing name falls back to id', () {
      final entry = PsAbilityEntry.fromJson('pressure', {});
      expect(entry.name, 'pressure');
    });

    test('missing gen defaults to 3', () {
      final entry = PsAbilityEntry.fromJson('intimidate', {'name': 'Intimidate'});
      expect(entry.gen, 3);
    });
  });

  group('PsEventEntry.fromJson', () {
    test('parses a real gift-Pokémon encounter (Crystal gift Dratini)', () {
      // Mirrors the actual eventData record for Dratini in PS's gen2 mod —
      // the motivating case for issue #103 (gift Dratini knows Extreme Speed).
      final entry = PsEventEntry.fromJson({
        'generation': 2,
        'level': 15,
        'moves': ['wrap', 'thunderwave', 'twister', 'extremespeed'],
        'shiny': 1,
      });
      expect(entry.generation, 2);
      expect(entry.level, 15);
      expect(entry.moves, ['wrap', 'thunderwave', 'twister', 'extremespeed']);
      expect(entry.shiny, isTrue);
      expect(entry.gender, isNull);
      expect(entry.isHidden, isFalse);
      expect(entry.pokeball, isNull);
    });

    test('parses gender, hidden-ability and pokeball fields', () {
      final entry = PsEventEntry.fromJson({
        'generation': 5,
        'level': 100,
        'moves': ['extremespeed', 'firepunch', 'dragondance', 'outrage'],
        'gender': 'M',
        'isHidden': true,
        'pokeball': 'cherishball',
      });
      expect(entry.gender, 'M');
      expect(entry.isHidden, isTrue);
      expect(entry.pokeball, 'cherishball');
      expect(entry.shiny, isFalse);
    });

    test('shiny: false is treated as not shiny', () {
      final entry = PsEventEntry.fromJson({
        'generation': 4,
        'level': 50,
        'moves': ['outrage'],
        'shiny': false,
      });
      expect(entry.shiny, isFalse);
    });

    test('missing fields default to generation 1, level 1, no moves', () {
      final entry = PsEventEntry.fromJson({});
      expect(entry.generation, 1);
      expect(entry.level, 1);
      expect(entry.moves, isEmpty);
      expect(entry.shiny, isFalse);
      expect(entry.isHidden, isFalse);
    });
  });

  group('genForVersionGroup', () {
    test('maps known version groups to their generation', () {
      expect(genForVersionGroup('red-blue'), 1);
      expect(genForVersionGroup('crystal'), 2);
      expect(genForVersionGroup('gold-silver'), 2);
      expect(genForVersionGroup('emerald'), 3);
      expect(genForVersionGroup('platinum'), 4);
      expect(genForVersionGroup('black-2-white-2'), 5);
      expect(genForVersionGroup('omega-ruby-alpha-sapphire'), 6);
      expect(genForVersionGroup('ultra-sun-ultra-moon'), 7);
      expect(genForVersionGroup('legends-arceus'), 8);
      expect(genForVersionGroup('scarlet-violet'), 9);
    });

    test('unknown version group returns null', () {
      expect(genForVersionGroup('lets-go-pikachu-lets-go-eevee'), isNull);
      expect(genForVersionGroup('not-a-real-version-group'), isNull);
    });
  });
}
