import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

Future<QueryExecutor> openDatabaseConnection() async =>
    driftDatabase(name: 'poketeamdex');
