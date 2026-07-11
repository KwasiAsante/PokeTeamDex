// Regression tests for withBackendFallback's cache-layer robustness.
//
// Both bugs here were found by a full audit and had zero prior test coverage
// — that gap is exactly why they went undetected: a Hive write/read failure
// silently corrupted the fallback contract instead of degrading gracefully.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_team_dex/services/util/backend_provider_utils.dart';

class _MockBox extends Mock implements Box {}

void main() {
  group('withBackendFallback cache-layer robustness', () {
    test('cache-write failure does not discard a successful backendCall result', () async {
      final box = _MockBox();
      when(() => box.get(any())).thenReturn(null);
      when(() => box.put(any(), any())).thenThrow(Exception('box closed'));

      final result = await withBackendFallback<String>(
        cacheKey: 'k1',
        box: box,
        isOnline: () async => true,
        backendCall: () async => 'GOOD_BACKEND_RESULT',
        offlineFallback: () async => throw Exception('should never run'),
        fromJson: (j) => j['v'] as String,
        toJson: (v) => {'v': v},
      );

      expect(result, 'GOOD_BACKEND_RESULT');
    });

    test('cache-write failure does not discard a successful offlineFallback result', () async {
      final box = _MockBox();
      when(() => box.get(any())).thenReturn(null);
      when(() => box.put(any(), any())).thenThrow(Exception('box closed'));

      final result = await withBackendFallback<String>(
        cacheKey: 'k2',
        box: box,
        isOnline: () async => true,
        backendCall: () async => throw Exception('backend down'),
        offlineFallback: () async => 'GOOD_OFFLINE_RESULT',
        fromJson: (j) => j['v'] as String,
        toJson: (v) => {'v': v},
      );

      expect(result, 'GOOD_OFFLINE_RESULT');
    });

    test('malformed cache entry is treated as a miss, not a crash, and offlineFallback still runs', () async {
      final box = _MockBox();
      // Malformed: payload IS a Map (passes the `is! Map` guard) but is
      // missing the key fromJson expects, so `j['v'] as String` throws a
      // cast error — the case the existing type guard alone doesn't catch.
      when(() => box.get(any())).thenReturn({
        'payload': {'wrong_key': 'x'},
        'expiresAt': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      });
      when(() => box.put(any(), any())).thenAnswer((_) async {});

      var offlineCalled = false;
      final result = await withBackendFallback<String>(
        cacheKey: 'k3',
        box: box,
        isOnline: () async => true,
        backendCall: () async => throw Exception('backend down'),
        offlineFallback: () async {
          offlineCalled = true;
          return 'RECONSTRUCTED_OFFLINE';
        },
        fromJson: (j) => j['v'] as String,
        toJson: (v) => {'v': v},
      );

      expect(offlineCalled, isTrue);
      expect(result, 'RECONSTRUCTED_OFFLINE');
    });

    test('backend call still fails through to cache when backendCall throws and cache is valid', () async {
      final box = _MockBox();
      when(() => box.get(any())).thenReturn({
        'payload': {'v': 'CACHED_VALUE'},
        'expiresAt': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      });
      when(() => box.put(any(), any())).thenAnswer((_) async {});

      final result = await withBackendFallback<String>(
        cacheKey: 'k4',
        box: box,
        isOnline: () async => true,
        backendCall: () async => throw Exception('backend down'),
        offlineFallback: () async => throw Exception('should never run — cache should win'),
        fromJson: (j) => j['v'] as String,
        toJson: (v) => {'v': v},
      );

      expect(result, 'CACHED_VALUE');
    });

    test('no cache, no internet, backend down -> BackendUnavailableException', () async {
      final box = _MockBox();
      when(() => box.get(any())).thenReturn(null);
      when(() => box.put(any(), any())).thenAnswer((_) async {});

      expect(
        () => withBackendFallback<String>(
          cacheKey: 'k5',
          box: box,
          isOnline: () async => false,
          backendCall: () async => throw Exception('backend down'),
          offlineFallback: () async => throw Exception('should never run — no internet'),
          fromJson: (j) => j['v'] as String,
          toJson: (v) => {'v': v},
        ),
        throwsA(isA<BackendUnavailableException>()),
      );
    });
  });
}
