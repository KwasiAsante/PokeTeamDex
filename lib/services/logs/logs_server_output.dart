import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Posts buffered log lines to the PokeTeamDex backend /logs/device endpoint.
/// Flushes every [flushInterval] or when [batchSize] lines accumulate.
/// Drops silently on any network/server failure.
class LogsServerOutput extends LogOutput {
  LogsServerOutput({
    this.flushInterval = const Duration(seconds: 3),
    this.batchSize = 20,
  });

  final Duration flushInterval;
  final int batchSize;

  // Mutable URL — updated after the DB is ready via [updateLogsUrl].
  String _logsBaseUrl = 'https://poketeamdex.duckdns.org';
  String? _token;
  final List<String> _buffer = [];
  Timer? _flushTimer;

  static String get _deviceId {
    if (kIsWeb) return 'poketeamdex-web';
    try {
      if (defaultTargetPlatform == TargetPlatform.android) return 'poketeamdex-android';
      if (defaultTargetPlatform == TargetPlatform.iOS) return 'poketeamdex-ios';
      if (defaultTargetPlatform == TargetPlatform.windows) return 'poketeamdex-windows';
      if (defaultTargetPlatform == TargetPlatform.macOS) return 'poketeamdex-macos';
      if (defaultTargetPlatform == TargetPlatform.linux) return 'poketeamdex-linux';
    } catch (_) {}
    return 'poketeamdex-unknown';
  }

  void updateLogsUrl(String url) {
    _logsBaseUrl = url.isEmpty ? 'https://poketeamdex.duckdns.org' : url;
  }

  void updateToken(String? token) {
    _token = token;
  }

  @override
  Future<void> init() async {
    _flushTimer = Timer.periodic(flushInterval, (_) => _flush());
  }

  @override
  void output(OutputEvent event) {
    _buffer.addAll(event.lines);
    if (_buffer.length >= batchSize) _flush();
  }

  @override
  Future<void> destroy() async {
    _flushTimer?.cancel();
    _flush();
  }

  void _flush() {
    if (_buffer.isEmpty) return;
    final lines = List<String>.from(_buffer);
    _buffer.clear();
    _send(lines);
  }

  void _send(List<String> lines) {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final uri = Uri.parse('$_logsBaseUrl/logs/device')
        .replace(queryParameters: {'app_name': 'poketeamdex'});
    http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'x-device-id': _deviceId,
          },
          body: jsonEncode(lines),
        )
        .timeout(const Duration(seconds: 5))
        .ignore();
  }
}
