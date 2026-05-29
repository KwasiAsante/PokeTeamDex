enum SyncStatus { idle, syncing, success, error }

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncAt,
    this.errorMessage,
  });

  final SyncStatus status;
  final DateTime? lastSyncAt;
  final String? errorMessage;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncAt,
    String? errorMessage,
  }) =>
      SyncState(
        status: status ?? this.status,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
