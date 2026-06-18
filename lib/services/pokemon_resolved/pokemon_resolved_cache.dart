import 'package:hive_flutter/hive_flutter.dart';

class PokemonResolvedCache {
  static final PokemonResolvedCache _instance = PokemonResolvedCache._internal();
  factory PokemonResolvedCache() => _instance;
  PokemonResolvedCache._internal();

  Box get _hive => Hive.box('pokemon_resolved_cache');

  Map<String, dynamic>? getIfValid(String key) {
    final data = _hive.get(key);
    if (data is Map) {
      final payload = data['payload'];
      final expiresAt = data['expiresAt'] as int?;
      if (payload is Map && expiresAt != null &&
          expiresAt > DateTime.now().millisecondsSinceEpoch) {
        return Map<String, dynamic>.from(payload as Map);
      }
    }
    return null;
  }

  void putWithTTL(String key, Map<String, dynamic> value, Duration ttl) {
    _hive.put(key, {
      'payload': value,
      'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
    });
  }
}
