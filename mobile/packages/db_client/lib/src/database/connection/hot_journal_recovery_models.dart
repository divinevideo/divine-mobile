enum DatabaseHotJournalRecoveryStage {
  inspectHeader,
  validateCipherKey,
  replayJournal,
  validateIntegrity,
  restoreSnapshot,
  retryClassification,
}

/// What a completed hot-journal replay left on disk.
enum HotJournalRecoveryResult {
  /// The journal replayed and the database passes `PRAGMA quick_check`.
  sound,

  /// The journal replayed, but the database fails `PRAGMA quick_check`, or
  /// SQLite could not read its schema once the rollback was done.
  ///
  /// The journal is consumed either way: replay is deterministic, so putting
  /// it back would only replay to the same file on every later launch. An
  /// encrypted file is opened like any other and recovered only if that
  /// fails. A plaintext one goes on to the migration, which rebuilds it and
  /// checks the copy.
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
