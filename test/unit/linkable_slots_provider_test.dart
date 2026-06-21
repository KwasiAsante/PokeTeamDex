// Tests for linkableSlotsProvider's regional-form matching (team_detail_providers.dart).
//
// Regional forms (Alolan/Galarian/Hisuian/Paldean) are stored on TeamSlot as
// pokemonId = base species id + formName = full PokeAPI variety name (e.g.
// pokemonId=37, formName="vulpix-alola"). Cross-species evolution targets
// must be matched by REGION SUFFIX ("alola"), not literal formName equality
// ("vulpix-alola" != "ninetales-alola") — that mismatch previously made the
// instance picker return an empty list for any regional-form evolution chain.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/data/pokemon_data_registry.dart';
import 'package:poke_team_dex/database/app_database.dart';
import 'package:poke_team_dex/database/database_providers.dart';
import 'package:poke_team_dex/features/teams/providers/team_detail_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

import '../helpers/test_database.dart';

class _MockPokeApi extends Mock implements PokeApiRepository {}

Future<int> _mkTeam(AppDatabase db) => db.into(db.teams).insert(TeamsCompanion(
      name: const Value('Test Team'),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));

Future<int> _mkSlot(
  AppDatabase db, {
  required int teamId,
  required int slot,
  required int pokemonId,
  String? formName,
}) =>
    db.into(db.teamSlots).insert(TeamSlotsCompanion(
          teamId: Value(teamId),
          slot: Value(slot),
          pokemonId: Value(pokemonId),
          formName: Value(formName),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

ProviderContainer _container(AppDatabase db, _MockPokeApi pokeApi) {
  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    pokeApiRepositoryProvider.overrideWithValue(pokeApi),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PokemonDataRegistry.initialize();
  });

  late AppDatabase db;
  late _MockPokeApi pokeApi;

  setUp(() {
    db = openTestDatabase();
    pokeApi = _MockPokeApi();
  });

  tearDown(() => db.close());

  test(
      'forward: candidate carrying the same regional form is matched by '
      'suffix, and the bare default-form slot of that species is suppressed',
      () async {
    // Vulpix-Alola (origin) -> Ninetales species has both a plain slot and
    // an Alolan slot; only the Alolan one should be offered.
    when(() => pokeApi.fetchForwardEvolutionInfo(37)).thenAnswer(
        (_) async => (forwardSpeciesIds: {37, 38}, originSpeciesId: 37));
    when(() => pokeApi.fetchSpeciesHasForm(38, 'vulpix-alola'))
        .thenAnswer((_) async => true);

    final teamA = await _mkTeam(db);
    final teamB = await _mkTeam(db);
    final teamC = await _mkTeam(db);
    final originSlot = await _mkSlot(db,
        teamId: teamA, slot: 0, pokemonId: 37, formName: 'vulpix-alola');
    await _mkSlot(db,
        teamId: teamB, slot: 0, pokemonId: 38, formName: 'ninetales-alola');
    await _mkSlot(db, teamId: teamC, slot: 0, pokemonId: 38); // bare Ninetales

    final container = _container(db, pokeApi);
    final result = await container.read(linkableSlotsProvider((
      originPokemonId: 37,
      currentSlotId: originSlot,
      originFormName: 'vulpix-alola',
      originGender: null,
      forwardDirection: true,
    )).future);

    expect(result.map((s) => s.formName), ['ninetales-alola']);
  });

  test(
      'forward: regional origin still reaches a single-form evolution branch '
      'that has no region-specific variety of its own',
      () async {
    // Galarian Meowth -> Perrserker has no "-galar" variety; the bare slot
    // must still be offered (documented behaviour for issue #102).
    when(() => pokeApi.fetchForwardEvolutionInfo(52)).thenAnswer((_) async =>
        (forwardSpeciesIds: {52, 863}, originSpeciesId: 52));
    when(() => pokeApi.fetchSpeciesHasForm(863, 'meowth-galar'))
        .thenAnswer((_) async => false);

    final teamA = await _mkTeam(db);
    final teamB = await _mkTeam(db);
    final originSlot = await _mkSlot(db,
        teamId: teamA, slot: 0, pokemonId: 52, formName: 'meowth-galar');
    await _mkSlot(db, teamId: teamB, slot: 0, pokemonId: 863); // Perrserker

    final container = _container(db, pokeApi);
    final result = await container.read(linkableSlotsProvider((
      originPokemonId: 52,
      currentSlotId: originSlot,
      originFormName: 'meowth-galar',
      originGender: null,
      forwardDirection: true,
    )).future);

    expect(result.map((s) => s.pokemonId), [863]);
  });

  test(
      'backward: ancestor carrying the same regional form is matched by '
      'suffix, and the bare default-form ancestor slot is suppressed',
      () async {
    when(() => pokeApi.fetchBackwardEvolutionInfo(38)).thenAnswer(
        (_) async => (ancestorSpeciesIds: {37, 38}, originSpeciesId: 38));
    when(() => pokeApi.fetchSpeciesHasForm(37, 'ninetales-alola'))
        .thenAnswer((_) async => true);

    final teamA = await _mkTeam(db);
    final teamB = await _mkTeam(db);
    final teamC = await _mkTeam(db);
    final originSlot = await _mkSlot(db,
        teamId: teamA, slot: 0, pokemonId: 38, formName: 'ninetales-alola');
    await _mkSlot(db,
        teamId: teamB, slot: 0, pokemonId: 37, formName: 'vulpix-alola');
    await _mkSlot(db, teamId: teamC, slot: 0, pokemonId: 37); // bare Vulpix

    final container = _container(db, pokeApi);
    final result = await container.read(linkableSlotsProvider((
      originPokemonId: 38,
      currentSlotId: originSlot,
      originFormName: 'ninetales-alola',
      originGender: null,
      forwardDirection: false,
    )).future);

    expect(result.map((s) => s.formName), ['vulpix-alola']);
  });

  test('forward: plain (non-form) same-species linking across teams still works',
      () async {
    when(() => pokeApi.fetchForwardEvolutionInfo(25)).thenAnswer(
        (_) async => (forwardSpeciesIds: {25}, originSpeciesId: 25));

    final teamA = await _mkTeam(db);
    final teamB = await _mkTeam(db);
    final originSlot =
        await _mkSlot(db, teamId: teamA, slot: 0, pokemonId: 25);
    await _mkSlot(db, teamId: teamB, slot: 0, pokemonId: 25);

    final container = _container(db, pokeApi);
    final result = await container.read(linkableSlotsProvider((
      originPokemonId: 25,
      currentSlotId: originSlot,
      originFormName: null,
      originGender: null,
      forwardDirection: true,
    )).future);

    expect(result.map((s) => s.pokemonId), [25]);
  });
}
