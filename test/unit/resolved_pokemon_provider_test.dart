// test/unit/resolved_pokemon_provider_test.dart
//
// Tests for resolvedPokemonProvider and the ResolvedPokemon value object.
//
// Covers:
//   • Happy path: detail + species + cosmetic forms are merged correctly
//   • Female sprite URL patch: null spriteUrl on a female form is replaced
//   • cosmeticGenderDiffPokemon: synthetic female entry is appended
//   • noCosmeticFormsPokemon: cosmetic forms are skipped entirely (no API call)
//   • Single-form species: cosmeticForms is empty (provider short-circuits)
//   • keepAlive: provider is not autoDispose
//   • gen parameter: provider accepts ({int id, int? gen}) named-record parameter

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/features/pokedex/models/resolved_pokemon.dart';
import 'package:poke_team_dex/features/pokedex/providers/resolved_pokemon_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_backend_repository.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_cache.dart';
import 'package:poke_team_dex/services/pokemon_resolved/pokemon_resolved_providers.dart';

class _MockRepo extends Mock implements PokeApiRepository {}
class _MockBackendRepo extends Mock implements PokemonBackendRepository {}
class _MockCache extends Mock implements PokemonResolvedCache {}

// ── Fixture helpers ────────────────────────────────────────────────────────

PokemonEntry _detail(int id, String name, {List<String>? formNames}) =>
    PokemonEntry(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: ['water'],
      formNames: formNames ?? [name],
    );

PokemonSpeciesEntry _species(int id, String name,
        {List<PokemonVariety>? varieties}) =>
    PokemonSpeciesEntry(
      id: id,
      name: name,
      eggGroups: [],
      flavorTextEntries: [],
      varieties:
          varieties ?? [const PokemonVariety(isDefault: true, name: 'base')],
    );

PokemonFormEntry _form(String name, String formName,
        {bool isDefault = false, String? spriteUrl}) =>
    PokemonFormEntry(
      id: 1,
      name: name,
      formName: formName,
      isDefault: isDefault,
      spriteUrl: spriteUrl,
    );

/// Builds a [ProviderContainer] with the mock repositories wired in.
/// The cache always returns null (miss) and the backend always throws,
/// so these tests exercise the PokéAPI offline fallback path.
ProviderContainer _container(_MockRepo repo) {
  final backendRepo = _MockBackendRepo();
  final cache = _MockCache();
  when(() => cache.getIfValid(any())).thenReturn(null);
  when(() => backendRepo.fetchResolved(any(), gen: any(named: 'gen')))
      .thenThrow(Exception('test: backend disabled'));
  return ProviderContainer(
    overrides: [
      pokeApiRepositoryProvider.overrideWithValue(repo),
      pokemonBackendRepositoryProvider.overrideWithValue(backendRepo),
      pokemonResolvedCacheProvider.overrideWithValue(cache),
    ],
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
    registerFallbackValue('');
    registerFallbackValue(0);
  });

  group('resolvedPokemonProvider', () {
    // ── 1. Happy path — no cosmetic forms ───────────────────────────────────

    test('resolves detail and species when species has a single variety', () async {
      final repo = _MockRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      final detailEntry = _detail(1, 'bulbasaur');
      final speciesEntry = _species(1, 'bulbasaur');

      when(() => repo.fetchPokemon(1)).thenAnswer((_) async => detailEntry);
      when(() => repo.fetchPokemonSpecies(1)).thenAnswer((_) async => speciesEntry);
      // cosmeticFormsProvider calls fetchPokemonByName; formNames.length == 1
      // so it returns [] immediately after this call.
      when(() => repo.fetchPokemonByName('bulbasaur'))
          .thenAnswer((_) async => detailEntry);

      final resolved = await container.read(resolvedPokemonProvider((id: 1, gen: null)).future);

      expect(resolved, isA<ResolvedPokemon>());
      expect(resolved.detail, same(detailEntry));
      expect(resolved.species, same(speciesEntry));
      expect(resolved.cosmeticForms, isEmpty);
    });

    // ── 2. Cosmetic forms are included ──────────────────────────────────────

    test('cosmetic form entries from the API are included in cosmeticForms', () async {
      final repo = _MockRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      // A fake species with two form names and a single variety (so cosmeticFormsProvider
      // will proceed to fetch forms instead of returning [] for variety-based forms).
      final pokemonEntry = _detail(422, 'shellos',
          formNames: ['shellos', 'shellos-east-sea']);
      final speciesEntry = _species(422, 'shellos',
          varieties: [const PokemonVariety(isDefault: true, name: 'shellos')]);

      when(() => repo.fetchPokemon(422)).thenAnswer((_) async => pokemonEntry);
      when(() => repo.fetchPokemonSpecies(422)).thenAnswer((_) async => speciesEntry);
      when(() => repo.fetchPokemonByName('shellos')).thenAnswer((_) async => pokemonEntry);
      when(() => repo.fetchPokemonForm('shellos'))
          .thenAnswer((_) async => _form('shellos', '', isDefault: true));
      when(() => repo.fetchPokemonForm('shellos-east-sea'))
          .thenAnswer((_) async => _form('shellos-east-sea', 'east-sea',
              spriteUrl: 'https://example.com/east-sea.png'));

      final resolved = await container.read(resolvedPokemonProvider((id: 422, gen: null)).future);

      expect(resolved.cosmeticForms, hasLength(1));
      expect(resolved.cosmeticForms.first.name, 'shellos-east-sea');
      expect(resolved.cosmeticForms.first.formName, 'east-sea');
    });

    // ── 3. Female sprite URL patch ───────────────────────────────────────────

    test('patches null spriteUrl on a female form entry', () async {
      final repo = _MockRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      const id = 592;
      final pokemonEntry = _detail(id, 'frillish',
          formNames: ['frillish', 'frillish-female']);
      final speciesEntry = _species(id, 'frillish',
          varieties: [const PokemonVariety(isDefault: true, name: 'frillish')]);

      when(() => repo.fetchPokemon(id)).thenAnswer((_) async => pokemonEntry);
      when(() => repo.fetchPokemonSpecies(id)).thenAnswer((_) async => speciesEntry);
      when(() => repo.fetchPokemonByName('frillish'))
          .thenAnswer((_) async => pokemonEntry);
      when(() => repo.fetchPokemonForm('frillish'))
          .thenAnswer((_) async => _form('frillish', '', isDefault: true));
      // Female form has no sprite URL — simulates the real API response.
      when(() => repo.fetchPokemonForm('frillish-female'))
          .thenAnswer((_) async => _form('frillish-female', 'female', spriteUrl: null));

      final resolved = await container.read(resolvedPokemonProvider((id: id, gen: null)).future);

      expect(resolved.cosmeticForms, hasLength(1));
      final femaleEntry = resolved.cosmeticForms.first;
      expect(femaleEntry.formName, 'female');
      expect(femaleEntry.spriteUrl,
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/female/$id.png');
      expect(femaleEntry.spriteShinyUrl,
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/shiny/female/$id.png');
    });

    // ── 4. cosmeticGenderDiffPokemon — synthetic female entry added ──────────

    test('appends synthetic female entry for cosmeticGenderDiffPokemon species', () async {
      final repo = _MockRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      // Pick a known member of cosmeticGenderDiffPokemon from the registry.
      final genderDiffName =
          PokemonDataRegistry.instance.cosmeticGenderDiffPokemon.first;
      const id = 521;

      // Single form name → cosmeticFormsProvider returns [] immediately.
      final pokemonEntry = _detail(id, genderDiffName);
      final speciesEntry = _species(id, genderDiffName);

      when(() => repo.fetchPokemon(id)).thenAnswer((_) async => pokemonEntry);
      when(() => repo.fetchPokemonSpecies(id)).thenAnswer((_) async => speciesEntry);
      when(() => repo.fetchPokemonByName(genderDiffName))
          .thenAnswer((_) async => pokemonEntry);

      final resolved = await container.read(resolvedPokemonProvider((id: id, gen: null)).future);

      // The synthetic female entry must be present.
      expect(resolved.cosmeticForms, hasLength(1));
      final synthetic = resolved.cosmeticForms.first;
      expect(synthetic.formName, 'female');
      expect(synthetic.name, '$genderDiffName-female');
      expect(synthetic.spriteUrl,
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/female/$id.png');
    });

    // ── 5. noCosmeticFormsPokemon — no form fetch is made ───────────────────

    test('returns empty cosmeticForms and never calls fetchPokemonByName for noCosmeticFormsPokemon species',
        () async {
      final repo = _MockRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      final noCosmeticName =
          PokemonDataRegistry.instance.noCosmeticFormsPokemon.first;
      const id = 414;

      final pokemonEntry = _detail(id, noCosmeticName,
          formNames: [noCosmeticName, '$noCosmeticName-form']);
      final speciesEntry = _species(id, noCosmeticName);

      when(() => repo.fetchPokemon(id)).thenAnswer((_) async => pokemonEntry);
      when(() => repo.fetchPokemonSpecies(id)).thenAnswer((_) async => speciesEntry);

      final resolved = await container.read(resolvedPokemonProvider((id: id, gen: null)).future);

      expect(resolved.cosmeticForms, isEmpty);
      // fetchPokemonByName must NOT be called — the noCosmeticFormsPokemon
      // guard short-circuits before cosmeticFormsProvider fires.
      verifyNever(() => repo.fetchPokemonByName(any()));
    });

    // ── 6. keepAlive — provider is not autoDispose ───────────────────────────

    test('provider is keepAlive (does not autoDispose after listeners leave)', () async {
      final repo = _MockRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      final pokemonEntry = _detail(1, 'bulbasaur');
      final speciesEntry = _species(1, 'bulbasaur');

      when(() => repo.fetchPokemon(1)).thenAnswer((_) async => pokemonEntry);
      when(() => repo.fetchPokemonSpecies(1)).thenAnswer((_) async => speciesEntry);
      when(() => repo.fetchPokemonByName('bulbasaur'))
          .thenAnswer((_) async => pokemonEntry);

      // First resolution — warms the cache.
      await container.read(resolvedPokemonProvider((id: 1, gen: null)).future);

      // Re-read without a listener: a keepAlive provider returns the cached
      // AsyncData immediately without re-fetching.
      final second = container.read(resolvedPokemonProvider((id: 1, gen: null)));
      expect(second, isA<AsyncData<ResolvedPokemon>>());

      // Repository was called exactly once per method — no re-fetch.
      verify(() => repo.fetchPokemon(1)).called(1);
    });
  });
}
