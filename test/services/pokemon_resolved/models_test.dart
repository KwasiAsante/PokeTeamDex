import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/services/pokemon_resolved/models.dart';
import 'package:poke_team_dex/services/pokeapi/models/pokemon_species_entry.dart';

void main() {
  group('AbilityInfo', () {
    test('fromJson parses backend response format', () {
      final a = AbilityInfo.fromJson({
        'name': 'blaze',
        'is_hidden': false,
        'slot': 1,
      });
      expect(a.name, 'blaze');
      expect(a.isHidden, false);
      expect(a.slot, 1);
    });

    test('fromPokeApi parses PokéAPI format', () {
      final a = AbilityInfo.fromPokeApi({
        'ability': {'name': 'blaze', 'url': '...'},
        'is_hidden': false,
        'slot': 1,
      });
      expect(a.name, 'blaze');
      expect(a.isHidden, false);
    });

    test('toJson round-trips', () {
      final a = AbilityInfo(name: 'blaze', isHidden: false, slot: 1);
      final json = a.toJson();
      final b = AbilityInfo.fromJson(json);
      expect(b.name, 'blaze');
      expect(b.slot, 1);
    });
  });

  group('MoveSummary', () {
    test('fromPokeApi parses PokéAPI move format', () {
      final m = MoveSummary.fromPokeApi({
        'move': {'name': 'flamethrower', 'url': '...'},
        'version_group_details': [
          {
            'level_learned_at': 0,
            'move_learn_method': {'name': 'machine', 'url': '...'},
            'version_group': {'name': 'sword-shield', 'url': '...'},
          }
        ],
      });
      expect(m.name, 'flamethrower');
      expect(m.learnDetails.length, 1);
      expect(m.learnDetails[0].method, 'machine');
      expect(m.learnDetails[0].versionGroup, 'sword-shield');
      expect(m.learnDetails[0].level, 0);
    });

    test('fromJson parses backend format', () {
      final m = MoveSummary.fromJson({
        'name': 'flamethrower',
        'learn_details': [
          {'version_group': 'sword-shield', 'method': 'machine', 'level': 0}
        ],
      });
      expect(m.name, 'flamethrower');
      expect(m.learnDetails[0].versionGroup, 'sword-shield');
    });

    test('toJson round-trips', () {
      final m = MoveSummary(
        name: 'flamethrower',
        learnDetails: [
          MoveLearnDetail(versionGroup: 'sword-shield', method: 'machine', level: 0)
        ],
      );
      final json = m.toJson();
      final b = MoveSummary.fromJson(json);
      expect(b.name, 'flamethrower');
      expect(b.learnDetails[0].method, 'machine');
    });
  });

  group('SpriteUrlsFull', () {
    test('fromJson parses backend response', () {
      final s = SpriteUrlsFull.fromJson({
        'official_artwork': 'https://example.com/art/6.png',
        'home': 'https://example.com/home/6.png',
        'official_artwork_shiny': null,
        'home_shiny': null,
      });
      expect(s.officialArtwork, 'https://example.com/art/6.png');
      expect(s.home, 'https://example.com/home/6.png');
      expect(s.officialArtworkShiny, isNull);
    });
  });

  group('PokemonResolvedBackendResponse', () {
    test('fromJson parses minimal valid response', () {
      final json = _minimalResolvedJson();
      final r = PokemonResolvedBackendResponse.fromJson(json);
      expect(r.pokemonId, 6);
      expect(r.name, 'charizard');
      expect(r.types, ['fire', 'flying']);
      expect(r.abilities.length, 1);
      expect(r.abilities[0].name, 'blaze');
      expect(r.height, 17);
      expect(r.evolutionChainId, 2);
      expect(r.genus, 'Flame Pokémon');
    });

    test('toPokemonEntry constructs correct PokemonEntry', () {
      final r = PokemonResolvedBackendResponse.fromJson(_minimalResolvedJson());
      final entry = r.toPokemonEntry();
      expect(entry.id, 6);
      // types are lowercased in toPokemonEntry() for UI colour lookups
      expect(entry.types[0], 'fire');
      expect(entry.types[1], 'flying');
      // stats is now Map<String, int>
      expect(entry.stats['hp'], 78);
      // abilities is now List<AbilityInfo>
      expect(entry.abilities[0].name, 'blaze');
      expect(entry.formNames, ['charizard']);
    });

    test('toPokemonSpeciesEntry constructs correct PokemonSpeciesEntry', () {
      final r = PokemonResolvedBackendResponse.fromJson(_minimalResolvedJson());
      final species = r.toPokemonSpeciesEntry();
      expect(species.generationName, 'generation-i');
      expect(species.genderRate, 1);
      expect(species.evolutionChainId, 2);
      expect(species.eggGroups, ['monster', 'dragon']);
      expect(species.isLegendary, false);
    });

    test('toCosmeticForms filters out default form', () {
      final json = _minimalResolvedJson();
      (json['forms'] as List).add({
        'name': 'charizard-mega-x',
        'form_id': 10034,
        'is_default': false,
        'front_sprite_url': 'https://example.com/10034.png',
        'sprite_urls': null,
      });
      final r = PokemonResolvedBackendResponse.fromJson(json);
      final forms = r.toCosmeticForms();
      expect(forms.length, 1);
      expect(forms[0].name, 'charizard-mega-x');
    });
  });

  group('VarietyBackendData', () {
    test('fromJson normalises Showdown-style abbreviated stat keys', () {
      // Backend sends base_stats with Showdown-style abbreviated keys
      // (hp/atk/def/spa/spd/spe) for mega/form varieties, same as the
      // species' own base_stats. They must be normalised to PokéAPI-style
      // full keys so stat preview lookups (which use 'attack', 'special-
      // attack', etc.) don't silently miss and fall back to 0.
      final v = VarietyBackendData.fromJson({
        'name': 'sceptile-mega',
        'pokemon_id': 10063,
        'is_default': false,
        'base_stats': {
          'hp': 70, 'atk': 110, 'def': 75,
          'spa': 145, 'spd': 85, 'spe': 145,
        },
      });
      expect(v.baseStats, {
        'hp': 70,
        'attack': 110,
        'defense': 75,
        'special-attack': 145,
        'special-defense': 85,
        'speed': 145,
      });
    });

    test('fromJson handles missing base_stats', () {
      final v = VarietyBackendData.fromJson({
        'name': 'sceptile',
        'pokemon_id': 254,
        'is_default': true,
      });
      expect(v.baseStats, isNull);
    });
  });

  group('FlavorTextEntry.fromBackend', () {
    test('parses backend flavor text format', () {
      final entry = FlavorTextEntry.fromBackend({
        'text': 'A Flame Pokémon.',
        'language': 'en',
        'version': 'red',
      });
      expect(entry.text, 'A Flame Pokémon.');
      expect(entry.language, 'en');
      expect(entry.version, 'red');
    });

    test('toJson round-trips', () {
      final entry = FlavorTextEntry(
        text: 'A Flame Pokémon.',
        language: 'en',
        version: 'red',
      );
      final json = entry.toJson();
      final back = FlavorTextEntry.fromBackend(json);
      expect(back.text, 'A Flame Pokémon.');
      expect(back.language, 'en');
      expect(back.version, 'red');
    });
  });
}

Map<String, dynamic> _minimalResolvedJson() => {
  'pokemon_id': 6,
  'gen': 9,
  'name': 'charizard',
  'types': ['Fire', 'Flying'],
  'base_stats': {'hp': 78, 'attack': 84, 'defense': 78,
                 'special-attack': 109, 'special-defense': 85, 'speed': 100},
  'abilities': [
    {'name': 'blaze', 'is_hidden': false, 'slot': 1}
  ],
  'height': 17,
  'weight': 905,
  'base_experience': 240,
  'species_name': 'charizard',
  'moves': [],
  'moves_url': 'https://example.com/pokemon/6/moves',
  'supplement_moves': [],
  'smogon_analyses': null,
  'smogon_url': null,
  'varieties': [],
  'varieties_url': null,
  'forms': [
    {'name': 'charizard', 'form_id': 6, 'is_default': true,
     'front_sprite_url': 'https://example.com/6.png', 'sprite_urls': null}
  ],
  'forms_url': null,
  'sprite_urls': {
    'official_artwork': 'https://example.com/art/6.png',
    'official_artwork_shiny': null,
    'home': 'https://example.com/home/6.png',
    'home_shiny': null,
    'home_female': null,
    'home_female_shiny': null,
    'game_front': null,
    'game_front_shiny': null,
    'game_front_female': null,
    'game_front_female_shiny': null,
  },
  'resolved_at': '2026-06-18T12:00:00Z',
  'genus': 'Flame Pokémon',
  'generation_name': 'generation-i',
  'gender_rate': 1,
  'capture_rate': 45,
  'base_happiness': 70,
  'hatch_counter': 20,
  'growth_rate': 'medium-slow',
  'egg_groups': ['monster', 'dragon'],
  'flavor_text_entries': [],
  'flavor_text_url': 'https://example.com/pokemon/6/flavor-text',
  'is_baby': false,
  'is_legendary': false,
  'is_mythical': false,
  'evolution_chain_id': 2,
};
