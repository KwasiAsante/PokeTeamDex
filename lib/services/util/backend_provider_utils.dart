import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:poke_team_dex/utils/app_logger.dart';

/// Hive box name for [withBackendFallback]'s cache. Opened once at app
/// startup (see `main.dart`) alongside the other Hive boxes.
const kBackendFallbackBoxName = 'backend_fallback_cache';

/// Bump whenever a cached payload's schema changes in a way that makes
/// existing Hive entries unreadable or stale (new fields, renamed keys,
/// etc.) — `main.dart` clears the box on the next app start when this
/// doesn't match the stored version.
const kBackendFallbackCacheVersion = 1;

/// Clears [kBackendFallbackBoxName] when [kBackendFallbackCacheVersion] has
/// been bumped since the last run. Call once at startup, after the box has
/// been opened.
Future<void> clearBackendFallbackCacheIfStale() async {
  final box = Hive.box(kBackendFallbackBoxName);
  const versionKey = '__version__';
  final storedVersion = box.get(versionKey) as int? ?? 0;
  if (storedVersion != kBackendFallbackCacheVersion) {
    await box.clear();
    await box.put(versionKey, kBackendFallbackCacheVersion);
  }
}

/// TTL applied when a backend call succeeds — matches the TTL used
/// elsewhere for backend-sourced data (e.g. [PokemonResolvedCache]).
const _kFreshTTL = Duration(days: 7);

/// TTL applied to a freshly-computed [offlineFallback] result, and the grace
/// window during which an expired cache entry is still accepted rather than
/// treated as a miss (step 2 of the contract below).
const _kStaleTTL = Duration(hours: 24);

/// Thrown when a backend call fails, no usable cache entry exists, and the
/// device has no internet connection to run [offlineFallback] with. Carries
/// a user-visible message — callers should surface it rather than swallow it.
class BackendUnavailableException implements Exception {
  const BackendUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Single fallback contract for every Riverpod provider that reads from the
/// backend catalog/resolver endpoints. Replaces the ad-hoc inline try/catch
/// each provider used to write for itself.
///
/// 1. Try [backendCall]. On success, cache the result for 7 days and return it.
/// 2. On failure, check the Hive cache for [cacheKey]. An entry is accepted
///    even up to 24h past its own expiry (better slightly-stale data than a
///    failed load), matching [_kStaleTTL].
/// 3. If there is no usable cache entry and the device has internet access,
///    run [offlineFallback] — a full, non-degraded reconstruction of the data
///    from PokéAPI + bundled PS data — and cache the result for 24h.
/// 4. If there is no cache entry and no internet, or [offlineFallback] itself
///    fails, throw [BackendUnavailableException] with a user-visible message.
///    Callers must never fabricate an empty/sentinel result here.
///
/// [fromJson]/[toJson] convert between [T] and the `Map<String, dynamic>`
/// wire format stored in the cache — callers whose [T] is a `List` (the
/// common case for catalog providers) should wrap/unwrap it under a single
/// key, e.g. `{'items': [...]}`.
///
/// [box] and [isOnline] default to the real Hive box and a live connectivity
/// check — tests should override both to avoid touching platform channels
/// and to control the online/offline branch deterministically.
Future<T> withBackendFallback<T>({
  required String cacheKey,
  required Future<T> Function() backendCall,
  required Future<T> Function() offlineFallback,
  required T Function(Map<String, dynamic> json) fromJson,
  required Map<String, dynamic> Function(T value) toJson,
  Box? box,
  Future<bool> Function()? isOnline,
}) async {
  final resolvedBox = box ?? Hive.box(kBackendFallbackBoxName);

  T? readCache() {
    try {
      final data = resolvedBox.get(cacheKey);
      if (data is! Map) return null;
      final payload = data['payload'];
      final expiresAt = data['expiresAt'] as int?;
      if (payload is! Map || expiresAt == null) return null;
      final graceDeadline = expiresAt + _kStaleTTL.inMilliseconds;
      if (DateTime.now().millisecondsSinceEpoch > graceDeadline) return null;
      // JSON round-trip guarantees nested maps are Map<String,dynamic> — Hive on
      // web (IndexedDB/MessagePack) deserialises them as Map<dynamic,dynamic>,
      // which crashes fromJson casts. Same pattern as PokemonResolvedCache.
      final normalized = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      return fromJson(normalized);
    } catch (e, st) {
      // A malformed/corrupted/schema-drifted entry must be treated as a
      // cache miss (falling through to offlineFallback below), not allowed
      // to propagate out of withBackendFallback entirely — that would skip
      // the offline-reconstruction step even though the device is online
      // and perfectly capable of rebuilding the data.
      AppLogger().w(
          '[withBackendFallback] cache read failed for "$cacheKey" (treating as miss)',
          error: e, stackTrace: st);
      return null;
    }
  }

  // Writing to the cache is a best-effort side-effect, never a condition for
  // success — a Hive write failure (closed box, disk full, serialization
  // error) must never discard an already-obtained result.
  void writeCache(T value, Duration ttl) {
    try {
      resolvedBox.put(cacheKey, {
        'payload': toJson(value),
        'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
      });
    } catch (e, st) {
      AppLogger().w('[withBackendFallback] cache write failed for "$cacheKey"',
          error: e, stackTrace: st);
    }
  }

  try {
    final result = await backendCall();
    writeCache(result, _kFreshTTL);
    return result;
  } catch (e, st) {
    AppLogger().w('[withBackendFallback] backend call failed for "$cacheKey"',
        error: e, stackTrace: st);
  }

  final cached = readCache();
  if (cached != null) {
    AppLogger().d('[withBackendFallback] serving cached data for "$cacheKey"');
    return cached;
  }

  final online = await (isOnline ?? _defaultIsOnline)();
  if (online) {
    AppLogger().d('[withBackendFallback] running offline fallback for "$cacheKey"');
    try {
      final result = await offlineFallback();
      writeCache(result, _kStaleTTL);
      return result;
    } catch (e, st) {
      AppLogger().w('[withBackendFallback] offline fallback failed for "$cacheKey"',
          error: e, stackTrace: st);
      throw BackendUnavailableException(
        'Unable to load data — the server is unreachable and the offline data load failed.',
      );
    }
  }

  throw BackendUnavailableException(
    'Unable to load data — no internet connection and no cached data available.',
  );
}

Future<bool> _defaultIsOnline() async {
  if (kIsWeb) return true; // connectivity_plus is unreliable on web.
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}

/// The real Hive box for [withBackendFallback]'s cache — a provider so tests
/// can override it with a fake/mock instead of touching real Hive storage.
final backendFallbackBoxProvider = Provider<Box>((ref) => Hive.box(kBackendFallbackBoxName));

/// One-shot connectivity check for [withBackendFallback] — a provider so
/// tests can override it and avoid the `connectivity_plus` platform channel.
final backendFallbackIsOnlineProvider =
    Provider<Future<bool> Function()>((ref) => _defaultIsOnline);
