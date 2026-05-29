import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits [true] when online, [false] when offline.
/// On web, always emits [true] (connectivity_plus is unreliable there).
final isOnlineProvider = StreamProvider<bool>((ref) {
  if (kIsWeb) return Stream.value(true);

  return Connectivity().onConnectivityChanged.map(
        (results) => results.any((r) => r != ConnectivityResult.none),
      );
});
