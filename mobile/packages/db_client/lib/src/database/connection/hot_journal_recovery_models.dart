enum DatabaseHotJournalRecoveryStage {
  inspectHeader,
  validateCipherKey,
  createSnapshot,
  replayJournal,
  validateIntegrity,
  restoreSnapshot,
  retryClassification,
}

/// What a completed hot-journal replay left on disk.
enum HotJournalRecoveryResult {
  /// The journal replayed and the database passes `PRAGMA quick_check`.
  sound,

  /// The journal replayed, but the database fails `PRAGMA quick_check`.
  ///
  /// The journal is consumed either way: replay is deterministic, so putting
  /// it back would only replay to the same file on every later launch. The
  /// caller hands the file to corruption recovery instead.
  failedIntegrityCheck,
}

/// SQLite found a hot rollback journal, but safe recovery could not complete.
///
/// The diagnostic deliberately excludes paths, SQL text, and key material.
class DatabaseHotJournalRecoveryError implements Exception {
  const DatabaseHotJournalRecoveryError({
    required this.stage,
    this.extendedResultCode,
  });

  final DatabaseHotJournalRecoveryStage stage;
  final int? extendedResultCode;

  int? get resultCode =>
      extendedResultCode == null ? null : extendedResultCode! & 0xff;

  @override
  String toString() =>
      'DatabaseHotJournalRecoveryError: stage=${stage.name}, '
      'resultCode=$resultCode, extendedResultCode=$extendedResultCode; '
      'automatic reset was refused.';
}
