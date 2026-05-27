import 'package:hive_flutter/hive_flutter.dart';

class PokeApiCache {
  static final PokeApiCache _instance = PokeApiCache._internal();
  factory PokeApiCache() => _instance;
  PokeApiCache._internal();

  final Box _hive = Hive.box('pokeapi_cache');
  Box get hive => _hive;

  dynamic get(String key) {
    return _hive.get(key);
  }

  dynamic getIfValid(String key) {
    dynamic data = _hive.get(key);
    if (data is Map && data.containsKey('payload')) {
      if (data.containsKey('expiresAt') && data['expiresAt'] != null) {
        if (data['expiresAt'] > DateTime.now().millisecondsSinceEpoch) {
          return data['payload'];
        }
      }
    }
    
    return null;
  }

  void put(String key, dynamic value) {
    _hive.put(key, value);
  }

  void putWithTTL(String key, dynamic value, Duration ttl) {
    Map<String, dynamic> data = {
      'payload': value,
      'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
    };
    _hive.put(key, data);
  }
}
