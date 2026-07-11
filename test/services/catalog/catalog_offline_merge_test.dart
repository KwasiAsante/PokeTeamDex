// Regression tests for the offline catalog builders' non-mainline exclusion.
//
// Found by audit: PokéAPI's raw /ability and /item lists include entries that
// aren't part of the mainline games — Pokémon Conquest warlord "abilities"
// (e.g. "Aqua Boost") and Conquest "Data Card" items — and neither the
// backend nor the offline fallback filtered them out. Both leak into the
// live catalog. Verified against the real PokéAPI: Aqua Boost reports
// is_main_series=false but a *valid* mainline generation (generation-v), so
// a gen-based filter can't catch it; Data Card items likewise carry valid
// mainline game_indices. is_main_series (abilities) and category=="data-cards"
// (items) are the only reliable signals.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/services/catalog/catalog_offline_merge.dart';
import 'package:poke_team_dex/services/pokeapi/models/ability_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/item_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';
import 'package:poke_team_dex/services/ps_data/ps_data_service.dart';

class _MockRepo extends Mock implements PokeApiRepository {}

class _MockPsData extends Mock implements PsDataService {}

void main() {
  late _MockRepo repo;
  late _MockPsData psData;

  setUp(() {
    repo = _MockRepo();
    psData = _MockPsData();
    when(() => psData.initialize()).thenAnswer((_) async {});
    when(() => psData.abilities).thenReturn(<String, dynamic>{});
    when(() => psData.items).thenReturn(<String, dynamic>{});
  });

  group('buildOfflineAbilityCatalog excludes non-mainline abilities', () {
    setUp(() {
      when(() => repo.fetchAbilityList())
          .thenAnswer((_) async => ['aqua-boost', 'intimidate']);
      when(() => repo.fetchAbility('aqua-boost')).thenAnswer((_) async =>
          const AbilityEntry(id: 302, name: 'aqua-boost', isMainSeries: false));
      when(() => repo.fetchAbility('intimidate')).thenAnswer((_) async =>
          const AbilityEntry(id: 22, name: 'intimidate', isMainSeries: true));
    });

    test('catalog list omits the Conquest ability but keeps the real one',
        () async {
      final result = await buildOfflineAbilityCatalog(repo, psData);
      final names = result.map((a) => a.name).toSet();
      expect(names, contains('intimidate'));
      expect(names, isNot(contains('aqua-boost')));
    });

    test('single-entry lookup throws for the Conquest ability', () async {
      expect(
        () => buildOfflineAbilityEntry(repo, psData, 'aqua-boost'),
        throwsException,
      );
    });

    test('single-entry lookup still resolves a real ability', () async {
      final result = await buildOfflineAbilityEntry(repo, psData, 'intimidate');
      expect(result.name, 'intimidate');
    });
  });

  group('buildOfflineItemCatalog excludes Conquest data cards', () {
    setUp(() {
      when(() => repo.fetchItemList())
          .thenAnswer((_) async => ['data-card-01', 'master-ball']);
      when(() => repo.fetchItem('data-card-01')).thenAnswer((_) async =>
          const ItemEntry(id: 663, name: 'data-card-01', category: 'data-cards'));
      when(() => repo.fetchItem('master-ball')).thenAnswer((_) async =>
          const ItemEntry(id: 3, name: 'master-ball', category: 'standard-balls'));
    });

    test('catalog list omits the data card but keeps the real item', () async {
      final result = await buildOfflineItemCatalog(repo, psData);
      final names = result.map((i) => i.name).toSet();
      expect(names, contains('master-ball'));
      expect(names, isNot(contains('data-card-01')));
    });

    test('single-entry lookup throws for the data card', () async {
      expect(
        () => buildOfflineItemEntry(repo, psData, 'data-card-01'),
        throwsException,
      );
    });

    test('single-entry lookup still resolves a real item', () async {
      final result = await buildOfflineItemEntry(repo, psData, 'master-ball');
      expect(result.name, 'master-ball');
    });
  });
}
