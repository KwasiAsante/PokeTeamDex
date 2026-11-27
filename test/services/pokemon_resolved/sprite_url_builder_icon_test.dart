import 'package:flutter_test/flutter_test.dart';
import 'package:poke_team_dex/services/pokemon_resolved/sprite_url_builder.dart';

// Icon URL selection after PokeAPI/sprites removed generation-viii/icons (#327).
const _v =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions';
const _swsh = '$_v/generation-viii/sword-shield/icons';
const _gen7 = '$_v/generation-vii/icons';
const _sv = '$_v/generation-ix/scarlet-violet/icons';

void main() {
  group('iconUrlCandidates', () {
    test('rewrites a deleted generation-viii/icons URL into the full chain', () {
      expect(iconUrlCandidates('$_v/generation-viii/icons/10033.png'), [
        '$_swsh/10033.png',
        '$_gen7/10033.png',
        '$_sv/10033.png',
      ]);
    });

    test('keeps the female/ prefix', () {
      expect(iconUrlCandidates('$_v/generation-viii/icons/female/876.png'), [
        '$_swsh/female/876.png',
        '$_gen7/female/876.png',
        '$_sv/female/876.png',
      ]);
    });

    test('tries the given live folder first, then the rest in order', () {
      expect(iconUrlCandidates('$_sv/1025.png'), [
        '$_sv/1025.png',
        '$_swsh/1025.png',
        '$_gen7/1025.png',
      ]);
    });

    test('passes non-icon URLs through unchanged', () {
      const front =
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png';
      expect(iconUrlCandidates(front), [front]);
      expect(iconUrlCandidates('$_v/generation-v/icons/25.png'),
          ['$_v/generation-v/icons/25.png']);
    });

    test('drops null and empty input', () {
      expect(iconUrlCandidates(null), isEmpty);
      expect(iconUrlCandidates(''), isEmpty);
    });
  });

  group('genderedIconUrlCandidates', () {
    test('tries female then male within each folder (Ambipom case)', () {
      // Backend gives Ambipom: icon = gen VII (no Sword/Shield icon at all),
      // iconFemale = Scarlet/Violet (the only female icon). The pixel gen VII
      // male icon must come before the HD Scarlet/Violet female one.
      final urls = genderedIconUrlCandidates(
        female: '$_sv/female/424.png',
        male: '$_gen7/424.png',
      );
      expect(urls, [
        '$_swsh/female/424.png',
        '$_swsh/424.png',
        '$_gen7/female/424.png',
        '$_gen7/424.png',
        '$_sv/female/424.png',
        '$_sv/424.png',
      ]);
    });

    test('without a female icon it is just the male chain', () {
      expect(genderedIconUrlCandidates(male: '$_gen7/424.png'),
          iconUrlCandidates('$_gen7/424.png').toSet().toList()
            ..sort((a, b) => _order(a).compareTo(_order(b))));
    });

    test('non-icon URLs are kept after the icon chain', () {
      const front =
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/424.png';
      expect(genderedIconUrlCandidates(male: front), [front]);
    });
  });

  group('buildIconUrl', () {
    test('gen 8+ and no-gen use Sword/Shield icons', () {
      expect(buildIconUrl(25, null), '$_swsh/25.png');
      expect(buildIconUrl(25, 9), '$_swsh/25.png');
      expect(buildIconUrl(876, 8, female: true), '$_swsh/female/876.png');
    });

    test('gen 7 still uses generation-vii/icons', () {
      expect(buildIconUrl(25, 7), '$_gen7/25.png');
    });
  });

  group('apiIconUrl', () {
    Map<String, dynamic> sprites({String? swsh, String? gen7, String? sv}) => {
          'versions': {
            'generation-vii': {
              'icons': {'front_default': gen7},
            },
            'generation-viii': {
              'sword-shield': {
                'icons': {'front_default': swsh},
              },
            },
            'generation-ix': {
              'scarlet-violet': {
                'icons': {'front_default': sv},
              },
            },
          },
        };

    test('prefers Sword/Shield, then gen VII, then Scarlet/Violet', () {
      expect(apiIconUrl(sprites(swsh: 'a', gen7: 'b', sv: 'c')), 'a');
      expect(apiIconUrl(sprites(gen7: 'b', sv: 'c')), 'b'); // Megas
      expect(apiIconUrl(sprites(sv: 'c')), 'c'); // Gen 9
    });

    test('returns null when the response has no icons', () {
      expect(apiIconUrl(sprites()), isNull);
      expect(apiIconUrl(const {}), isNull);
    });

    test('ignores the removed generation-viii.icons key', () {
      expect(
        apiIconUrl({
          'versions': {
            'generation-viii': {
              'icons': {'front_default': '$_v/generation-viii/icons/25.png'},
            },
          },
        }),
        isNull,
      );
    });
  });
}

int _order(String url) =>
    kIconFolders.indexWhere((f) => url.contains('/versions/$f/'));
