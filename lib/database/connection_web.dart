import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

// opfsShared uses a SharedWorker with createSyncAccessHandle(), which Firefox
// rejects per spec — sync access handles are only allowed in dedicated workers.
// We probe available implementations and exclude opfsShared, then pick the
// next best option (opfsLocks → sharedIndexedDb → unsafeIndexedDb).
Future<QueryExecutor> openDatabaseConnection() async {
  final probed = await WasmDatabase.probe(
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    databaseName: 'poketeamdex',
  );

  final candidates = probed.availableStorages
      .where((impl) => impl != WasmStorageImplementation.opfsShared)
      .toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  final selected = candidates.isNotEmpty
      ? candidates.first
      : WasmStorageImplementation.unsafeIndexedDb;

  return probed.open(selected, 'poketeamdex');
}
