// Regression test for cosmeticFormsProvider's per-form failure isolation.
//
// Found by audit: a single failing /pokemon-form/{name} fetch previously
// rejected the whole Future.wait, discarding every other successfully-fetched
// form — and since resolvedPokemonProvider/pokemonFormsProvider await this
// with no try/catch of their own, it took down the entire offline Pokémon
// resolution (types/stats/abilities/moves/sprites), not just the form chips.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/features/pokedex/providers/pokemon_detail_provider.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_form_entry.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_providers.dart';
import 'package:poke_team_dex/services/pokeapi/poke_api_repository.dart';

class _MockRepo extends Mock implements PokeApiRepository {}

void main() {
  test('cosmeticFormsProvider isolates a single failing form fetch', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // A 3-form species: base (default), "shellos-east" (fails), "shellos-west" (succeeds).
    final pokemon = PokemonEntry(
      id: 422,
      name: 'shellos',
      height: 3,
      weight: 63,
      types: const ['water'],
      formNames: const ['shellos', 'shellos-east', 'shellos-west'],
    );
    const species = PokemonSpeciesEntry(
      id: 422,
      name: 'shellos',
      eggGroups: [],
      flavorTextEntries: [],
      varieties: [PokemonVariety(isDefault: true, name: 'shellos')],
    );

    final repo = _MockRepo();
    when(() => repo.fetchPokemonByName('shellos')).thenAnswer((_) async => pokemon);
    when(() => repo.fetchPokemonSpecies(422)).thenAnswer((_) async => species);
    when(() => repo.fetchPokemonForm('shellos-east'))
        .thenThrow(Exception('simulated transient PokéAPI failure'));
    when(() => repo.fetchPokemonForm('shellos-west')).thenAnswer((_) async =>
        PokemonFormEntry(id: 422, name: 'shellos-west', formName: 'west', isDefault: false));

    final container = ProviderContainer(overrides: [
      pokeApiRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final forms = await container.read(cosmeticFormsProvider('shellos').future);

    // The failing form is skipped, but the successful one still comes
    // through — the call must NOT reject just because one form fetch failed.
    expect(forms.length, 1);
    expect(forms.single.name, 'shellos-west');
  });
}
