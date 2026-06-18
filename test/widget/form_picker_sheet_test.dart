import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/pokedex/presentation/widget/form_picker_sheet.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

class _MockPokeApiRepository extends Mock implements PokeApiRepository {}

PokemonEntry _entry(String name) => PokemonEntry(
      id: 487,
      name: name,
      height: 69,
      weight: 7500,
      types: ['ghost', 'dragon'],
    );

const _giratinaForms = [
  (null as String?, 'Altered', null as String?),
  ('giratina-origin', 'Origin', null as String?),
];

void main() {
  late _MockPokeApiRepository mockApi;

  setUp(() {
    mockApi = _MockPokeApiRepository();
    when(() => mockApi.fetchPokemonByNameOrDefault(any()))
        .thenAnswer((inv) async => _entry(inv.positionalArguments[0] as String));
  });

  group('FormPickerSheet', () {
    testWidgets('renders Select Form title and all form labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pokeApiRepositoryProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: Scaffold(
              body: FormPickerSheet(
                allForms: _giratinaForms,
                selectedFormName: null,
                shiny: false,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Form'), findsOneWidget);
      expect(find.text('Altered'), findsOneWidget);
      expect(find.text('Origin'), findsOneWidget);
    });

    testWidgets('tapping a named form tile calls onSelect with that form name',
        (tester) async {
      String? received = 'sentinel';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pokeApiRepositoryProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: Scaffold(
              body: FormPickerSheet(
                allForms: _giratinaForms,
                selectedFormName: null,
                shiny: false,
                onSelect: (name) => received = name,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Origin'));
      expect(received, 'giratina-origin');
    });

    testWidgets('tapping the base form tile calls onSelect with null',
        (tester) async {
      String? received = 'sentinel';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pokeApiRepositoryProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: Scaffold(
              body: FormPickerSheet(
                allForms: _giratinaForms,
                selectedFormName: 'giratina-origin',
                shiny: false,
                onSelect: (name) => received = name,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Altered'));
      expect(received, isNull);
    });

    testWidgets('renders multiple forms without crashing', (tester) async {
      const ogerponForms = [
        (null as String?, 'Teal Mask', null as String?),
        ('ogerpon-wellspring-mask', 'Wellspring Mask', null as String?),
        ('ogerpon-hearthflame-mask', 'Hearthflame Mask', null as String?),
        ('ogerpon-cornerstone-mask', 'Cornerstone Mask', null as String?),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [pokeApiRepositoryProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: Scaffold(
              body: FormPickerSheet(
                allForms: ogerponForms,
                selectedFormName: null,
                shiny: false,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Form'), findsOneWidget);
      expect(find.text('Teal Mask'), findsOneWidget);
      expect(find.text('Wellspring Mask'), findsOneWidget);
      expect(find.text('Hearthflame Mask'), findsOneWidget);
      expect(find.text('Cornerstone Mask'), findsOneWidget);
    });

    testWidgets('base form tile does not trigger a provider fetch', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pokeApiRepositoryProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: Scaffold(
              body: FormPickerSheet(
                allForms: const [(null, 'Base', null)],
                baseSpriteUrl: 'https://example.com/sprite.png',
                selectedFormName: null,
                shiny: false,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The base tile uses overrideSpriteUrl; pokemonByNameProvider must not fire.
      verifyNever(() => mockApi.fetchPokemonByNameOrDefault(any()));
    });

    testWidgets(
        'cosmetic form entry with sprite override does not call pokemonByNameProvider',
        (tester) async {
      // Shellos East Sea is a pokemon-form name, not a /pokemon resource.
      // The sprite override must be used and no provider fetch triggered.
      const shellosEastForms = [
        (null as String?, 'West Sea', null as String?),
        ('shellos-east-sea', 'East Sea', 'https://example.com/east-sea-sprite.png'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [pokeApiRepositoryProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: Scaffold(
              body: FormPickerSheet(
                allForms: shellosEastForms,
                selectedFormName: null,
                shiny: false,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('West Sea'), findsOneWidget);
      expect(find.text('East Sea'), findsOneWidget);
      // The East Sea tile has a sprite override; pokemonByNameProvider must NOT
      // be called with 'shellos-east-sea' (that endpoint doesn't exist).
      verifyNever(() => mockApi.fetchPokemonByNameOrDefault('shellos-east-sea'));
    });

    testWidgets('tapping cosmetic form tile calls onSelect with form name',
        (tester) async {
      const shellosEastForms = [
        (null as String?, 'West Sea', null as String?),
        ('shellos-east-sea', 'East Sea', 'https://example.com/east-sea-sprite.png'),
      ];

      String? received = 'sentinel';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pokeApiRepositoryProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: Scaffold(
              body: FormPickerSheet(
                allForms: shellosEastForms,
                selectedFormName: null,
                shiny: false,
                onSelect: (name) => received = name,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('East Sea'));
      expect(received, 'shellos-east-sea');
    });
  });
}
