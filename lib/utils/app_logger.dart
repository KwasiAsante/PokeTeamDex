import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poke_team_dex/services/logs/logs_server_output.dart';

/// Singleton logger with three independent sinks:
///   • console (debug builds only)
///   • daily rotating file (non-web)
///   • HTTP push to PokeTeamDex backend /logs/device
///
/// Usage:
///   AppLogger().i('message');
///   AppLogger().e('error', error: e, stackTrace: st);
///
/// After the DB is ready, wire in the dynamic URL and auth token:
///   AppLogger.configure(await configRepo.getApiBaseUrl());
///   AppLogger.configureToken(storedToken);
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;

  late final Logger _logger;
  late final Logger _consoleLogger;
  late final LogsServerOutput _serverOutput;

  static PrettyPrinter get _printer => PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  );

  // Calls (`d`/`i`/`w`/`e`) only enqueue a closure — formatting (the printer
  // builds padded/joined strings, e.g. full Dio request/response dumps) and
  // sink dispatch (file I/O, HTTP buffering) happen later in [_drain], run
  // from a microtask so the calling code's synchronous frame work (a build
  // method, an event handler) is never extended by log processing.
  final List<void Function()> _queue = [];

  void _enqueue(void Function() dispatch) {
    final wasEmpty = _queue.isEmpty;
    _queue.add(dispatch);
    if (wasEmpty) scheduleMicrotask(_drain);
  }

  void _drain() {
    final batch = _queue.toList(growable: false);
    _queue.clear();
    for (final dispatch in batch) {
      dispatch();
    }
  }

  AppLogger._internal() {
    _serverOutput = LogsServerOutput();

    final outputs = <LogOutput>[
      if (kDebugMode) ConsoleOutput(),
      if (!kIsWeb) _FileLogOutput(),
      _serverOutput,
    ];

    _logger = Logger(
      filter: ProductionFilter(),
      printer: _SimplePrinter(),
      output: MultiOutput(outputs),
      level: kDebugMode ? Level.debug : Level.info,
    );

    if (kDebugMode) {
      _consoleLogger = Logger(
        filter: ProductionFilter(),
        printer: _printer,
        output: ConsoleOutput(),
        level: Level.debug,
      );
    }
  }

  /// Update the backend URL at runtime (called after DB loads).
  static void configure(String url) {
    _instance._serverOutput.updateLogsUrl(url);
  }

  /// Update the auth token at runtime (call after login/logout).
  static void configureToken(String? token) {
    _instance._serverOutput.updateToken(token);
  }

  void d(String message, {Object? error, StackTrace? stackTrace}) =>
      _enqueue(() {
        _logger.d(message, error: error, stackTrace: stackTrace);
        if (kDebugMode) {
          _consoleLogger.d(message, error: error, stackTrace: stackTrace);
        }
      });

  void i(String message, {Object? error, StackTrace? stackTrace}) =>
      _enqueue(() {
        _logger.i(message, error: error, stackTrace: stackTrace);
        if (kDebugMode) {
          _consoleLogger.i(message, error: error, stackTrace: stackTrace);
        }
      });

  void w(String message, {Object? error, StackTrace? stackTrace}) =>
      _enqueue(() {
        _logger.w(message, error: error, stackTrace: stackTrace);
        if (kDebugMode) {
          _consoleLogger.w(message, error: error, stackTrace: stackTrace);
        }
      });

  void e(String message, {Object? error, StackTrace? stackTrace}) =>
      _enqueue(() {
        _logger.e(message, error: error, stackTrace: stackTrace);
        if (kDebugMode) {
          _consoleLogger.e(message, error: error, stackTrace: stackTrace);
        }
      });
}

// ── Printers / outputs ────────────────────────────────────────────────────────

class _SimplePrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final level = event.level.name.toUpperCase().padRight(5);
    final msg = event.message;
    final err = event.error != null ? '\n  error: ${event.error}' : '';
    final st =
        (event.stackTrace != null && event.level.index >= Level.warning.index)
        ? '\n${event.stackTrace}'
        : '';
    return ['[$level] $msg$err$st'];
  }
}

class _FileLogOutput extends LogOutput {
  File? _file;
  String? _currentDay;

  static Future<Directory> _logsDir() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final appDoc = await getApplicationDocumentsDirectory();
      return Directory('${appDoc.path}/PokeTeamDex/logs');
    }
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/logs');
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<File> _currentFile() async {
    final day = _today();
    if (_currentDay != day || _file == null) {
      _currentDay = day;
      final dir = await _logsDir();
      await dir.create(recursive: true);
      _file = File('${dir.path}/$day.log');

      // Rotate when the file exceeds 5 MB. Async stat calls — `existsSync`/
      // `lengthSync` block the calling isolate on the filesystem syscall.
      if (await _file!.exists() && await _file!.length() > 5 * 1024 * 1024) {
        _file = File('${dir.path}/${day}_1.log');
      }
    }
    return _file!;
  }

  @override
  void output(OutputEvent event) async {
    try {
      final file = await _currentFile();
      final sink = file.openWrite(mode: FileMode.append);
      for (final line in event.lines) {
        sink.writeln(line);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      // File logging is best-effort.
    }
  }
}
