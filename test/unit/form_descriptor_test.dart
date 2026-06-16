// test/unit/form_descriptor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/teams/data/form_descriptor.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  group('FormDescriptor.empty', () {
    test('isDefault is true', () {
      expect(FormDescriptor.empty().isDefault, isTrue);
    });

    test('effectiveApiName returns baseSpecies', () {
      expect(
        FormDescriptor.empty().effectiveApiName('charizard', null),
        'charizard',
      );
    });
  });

  group('FormDescriptor — variety form (formName set)', () {
    const descriptor = FormDescriptor(formName: 'aegislash-blade');

    test('isDefault is false', () {
      expect(descriptor.isDefault, isFalse);
    });

    test('effectiveApiName returns formName', () {
      expect(descriptor.effectiveApiName('aegislash', null), 'aegislash-blade');
    });
  });

  group('FormDescriptor — mega evolved', () {
    const descriptor = FormDescriptor(isMegaEvolved: true);

    test('effectiveApiName returns mega form name from kMegaStoneMap', () {
      expect(
        descriptor.effectiveApiName('charizard', 'charizardite-x'),
        'charizard-mega-x',
      );
    });

    test('effectiveApiName returns baseSpecies when heldItem is null', () {
      expect(descriptor.effectiveApiName('charizard', null), 'charizard');
    });

    test('effectiveApiName returns baseSpecies when item not in mega map', () {
      expect(descriptor.effectiveApiName('charizard', 'leftovers'), 'charizard');
    });
  });

  group('FormDescriptor — gigantamax enabled', () {
    const descriptor = FormDescriptor(gigantamaxEnabled: true);

    test('effectiveApiName returns baseSpecies (G-Max uses base stats)', () {
      expect(descriptor.effectiveApiName('charizard', null), 'charizard');
    });

    test('isDefault is false', () {
      expect(descriptor.isDefault, isFalse);
    });
  });

  group('FormDescriptor.copyWith', () {
    test('can clear formName to null', () {
      const d = FormDescriptor(formName: 'aegislash-blade');
      expect(d.copyWith(clearFormName: true).formName, isNull);
    });

    test('preserves unchanged fields', () {
      const d = FormDescriptor(formName: 'aegislash-blade', isShiny: true);
      final updated = d.copyWith(isShiny: false);
      expect(updated.formName, 'aegislash-blade');
      expect(updated.isShiny, isFalse);
    });
  });
}
