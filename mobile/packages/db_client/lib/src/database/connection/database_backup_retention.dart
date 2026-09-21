// ABOUTME: Retention policy for the database copies a recovery leaves behind.
// ABOUTME: Stamps each with a UTC time, keeps one per kind, expires the rest.

import 'dart:io';

import 'package:db_client/src/database/connection/database_sidecars.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Suffix for the plaintext original preserved by the one-time
/// plaintext→encrypted migration.
///
/// Deliberately not in [preservedDatabaseCopySuffixes]: it is plaintext at
/// rest, so it is deleted outright on the first keyed open rather than kept
/// for a retention window. See `cleanUpPreCipherMigrationBackups`.
const String preCipherMigrationBackupSuffix = '.pre_cipher_migration_backup';

/// Every suffix under which a recovery sets the shared database aside instead
/// of deleting it; newest-first retention applies to each independently.
///
/// Each entry is a whole database: the rename carries the rollback journal,
/// WAL and SHM with it, and nothing is ever overwritten. Keeping the bytes is
/// deliberate — a misclassified recovery is then not catastrophic — but the
/// preservation had no other end, so copies accumulated for the life of the
/// install and rode device backups forward to the next phone (#9392).
///
/// Every site that sets a database aside names its suffix from this list, so a
/// new preservation path cannot be added without the sweep learning about it.
const List<String> preservedDatabaseCopySuffixes = [
  keyLossWipeBackupSuffix,
  corruptionRecoveryBackupSuffix,
  legacyMigrationBackupSuffix,
  legacyConflictBackupSuffix,
];

/// The encrypted database replaced after its cipher key stopped opening it.
const String keyLossWipeBackupSuffix = '.pre_key_loss_wipe_backup';

/// The corrupt original a salvage rebuilt local-only data out of.
const String corruptionRecoveryBackupSuffix = '.pre_corruption_recovery_backup';

/// The Application Support database displaced by a populated legacy one.
const String legacyMigrationBackupSuffix = '.pre_legacy_migration_backup';

/// The legacy database kept when both it and its destination held local-only
/// data, so neither could be dropped.
const String legacyConflictBackupSuffix = '.legacy_conflict_backup';

/// How long the newest preserved copy of each kind is kept, measured from the
/// stamp in its name. A copy superseded by a newer one of its kind is deleted
/// at once, whatever its age; the window only ever applies to the survivor.
///
/// Long enough to cover a monthly-active user noticing their local-only data
/// is gone and reporting it; short enough that a full-size database is not
/// parked on the device for good. Nothing in the app reads a preserved copy
/// today, so the window buys the possibility of a hand-built recovery, not a
/// shipped one.
const Duration preservedDatabaseCopyRetention = Duration(days: 30);

/// Builds the path for a new preserved copy of [dbPath] under [suffix].
///
/// The name carries a UTC stamp — `divine_db.db.pre_key_loss_wipe_backup`
/// becomes `divine_db.db.pre_key_loss_wipe_backup.20260921T125817Z` — because
/// that is the only record of when the copy was set aside that survives the
/// trip it actually takes. `renameSync` keeps the database's own modification
/// time, which is its last *write*, and a device restore rewrites the change
/// time; the name is carried by both.
///
/// A second copy stamped in the same second (or a legacy name already sitting
/// there) falls back to appending `.1`, `.2`, … so a new copy never lands on
/// a name another file or its sidecars already own.
String nextPreservedDatabaseCopyPath(
  String dbPath, {
  required String suffix,
  DateTime? now,
}) {
  final stamped =
      '$dbPath$suffix.${formatDatabaseBackupStamp(now ?? DateTime.now())}';
  var candidate = stamped;
  var index = 1;
  while (_pathIsTaken(candidate)) {
    candidate = '$stamped.$index';
    index += 1;
  }
  return candidate;
}

bool _pathIsTaken(String path) =>
    File(path).existsSync() ||
    databaseSidecarSuffixes.any((suffix) => File('$path$suffix').existsSync());

/// Applies [preservedDatabaseCopyRetention] to every kind of preserved copy
/// beside [dbPath]: one copy per suffix survives, and it survives only until
/// the window closes.
///
/// Both halves are load-bearing. Expiry alone would let a device whose
/// keystore reads back empty on every launch — which takes the backup-and-
/// recreate path every launch — pile up a month of full-size databases.
/// Keeping one per suffix alone would bound the footprint at roughly twice the
/// database and never hand it back.
///
/// Call it wherever a keyed open has just succeeded. That is what makes the
/// clock honest: a device stuck failing to open its database never expires the
/// copy it may still need.
void sweepPreservedDatabaseCopies(
  String dbPath, {
  Duration retention = preservedDatabaseCopyRetention,
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  for (final suffix in preservedDatabaseCopySuffixes) {
    final found = findPreservedDatabaseCopies(dbPath, suffix: suffix);

    // Sidecars with no database beside them are the debris of a rename that
    // was interrupted, and they cannot be opened by anything. Dropping them
    // before ranking is what stops a half-moved copy from outranking — and so
    // deleting — the copy that still holds the database.
    final copies = <PreservedDatabaseCopy>[];
    for (final copy in found) {
      copy.hasDatabaseFile ? copies.add(copy) : _deleteCopy(copy);
    }
    if (copies.isEmpty) continue;

    // Ordered oldest-first, so every copy but the last is superseded.
    copies.take(copies.length - 1).forEach(_deleteCopy);

    final newest = copies.last;
    if (newest.stamp == null) {
      // Written by a build that did not stamp its copies, so there is no
      // honest age to measure. Adopting it into the current naming starts the
      // window now rather than deleting on the first launch after the update.
      _adoptLegacyCopy(
        newest,
        toName: p.basename(
          nextPreservedDatabaseCopyPath(dbPath, suffix: suffix, now: moment),
        ),
      );
      continue;
    }
    if (moment.difference(newest.stamp!) >= retention) {
      _deleteCopy(newest);
    }
  }
}

/// Deletes every preserved copy of [dbPath] under [suffix], sidecars included.
///
/// Used for the plaintext migration backup, which has no retention window —
/// leaving it in place would leave the old database readable at rest.
void deletePreservedDatabaseCopies(String dbPath, {required String suffix}) {
  findPreservedDatabaseCopies(dbPath, suffix: suffix).forEach(_deleteCopy);
}

/// A preserved copy of the shared database: its main file where one is still
/// present, plus the sidecars that were renamed with it.
@immutable
@visibleForTesting
class PreservedDatabaseCopy implements Comparable<PreservedDatabaseCopy> {
  const PreservedDatabaseCopy({
    required this.directory,
    required this.name,
    required this.stamp,
    required this.index,
    required this.fileNames,
  });

  /// The directory holding the copy — the shared database's own directory.
  final String directory;

  /// The copy's file name, sidecar suffix excluded. No file of this exact name
  /// need exist: only sidecars survive an interrupted rename.
  final String name;

  /// When the copy was set aside, or `null` for a copy named by a build that
  /// predates stamping.
  final DateTime? stamp;

  /// The `.1`, `.2`, … disambiguator, or 0 when the name carries none. Higher
  /// means written later, since the probe takes the lowest free index.
  final int index;

  /// Every file that belongs to this copy, by name — the database and the
  /// sidecars renamed with it.
  final List<String> fileNames;

  /// This copy's path, sidecar suffix excluded.
  String get path => p.join(directory, name);

  /// Whether the database itself is still here, rather than only sidecars.
  bool get hasDatabaseFile => fileNames.contains(name);

  /// Oldest first: an unstamped copy predates every stamped one by
  /// construction, since only an older build could have written it.
  @override
  int compareTo(PreservedDatabaseCopy other) {
    final stamps = switch ((stamp, other.stamp)) {
      (null, null) => 0,
      (null, _) => -1,
      (_, null) => 1,
      (final a?, final b?) => a.compareTo(b),
    };
    return stamps != 0 ? stamps : index.compareTo(other.index);
  }
}

/// Every preserved copy of [dbPath] under [suffix], oldest first.
///
/// Reads the directory rather than probing names, so a copy left by any build
/// is found. Anything whose name is not exactly a copy of this database under
/// this suffix — a `.pre_cipher_migration_backup_notes` beside it, say — is
/// not matched and is never touched.
@visibleForTesting
List<PreservedDatabaseCopy> findPreservedDatabaseCopies(
  String dbPath, {
  required String suffix,
}) {
  final directory = File(dbPath).parent;
  final List<FileSystemEntity> entries;
  try {
    entries = directory.listSync();
  } on FileSystemException {
    // No directory to sweep, or it cannot be read right now. The next keyed
    // open tries again.
    return const [];
  }

  final prefix = '${p.basename(dbPath)}$suffix';
  final grouped = <String, List<String>>{};
  for (final entry in entries) {
    if (entry is! File) continue;
    final name = p.basename(entry.path);
    final copyName = _preservedCopyName(name, prefix: prefix);
    if (copyName == null) continue;
    grouped.putIfAbsent(copyName, () => []).add(name);
  }

  final copies = [
    for (final MapEntry(key: name, value: fileNames) in grouped.entries)
      _describeCopy(
        directory: directory.path,
        name: name,
        tail: name.substring(prefix.length),
        fileNames: fileNames,
      ),
  ]..sort();
  return copies;
}

/// The copy name [name] belongs to — itself for a database file, the base name
/// for a sidecar — or `null` when it is not a preserved copy under [prefix].
String? _preservedCopyName(String name, {required String prefix}) {
  if (_isPreservedCopyName(name, prefix: prefix)) return name;
  for (final sidecar in databaseSidecarSuffixes) {
    if (!name.endsWith(sidecar) || name.length <= sidecar.length) continue;
    final base = name.substring(0, name.length - sidecar.length);
    if (_isPreservedCopyName(base, prefix: prefix)) return base;
  }
  return null;
}

/// Matches the four shapes a preserved copy's name can take: the bare prefix
/// and `prefix.<index>` written by builds before stamping, and `prefix.<stamp>`
/// and `prefix.<stamp>.<index>` written since.
bool _isPreservedCopyName(String name, {required String prefix}) {
  if (!name.startsWith(prefix)) return false;
  final tail = name.substring(prefix.length);
  if (tail.isEmpty) return true;
  if (_indexPattern.hasMatch(tail)) return true;
  final stamped = _stampedTailPattern.firstMatch(tail);
  return stamped != null && parseDatabaseBackupStamp(stamped[1]!) != null;
}

PreservedDatabaseCopy _describeCopy({
  required String directory,
  required String name,
  required String tail,
  required List<String> fileNames,
}) {
  final stamped = _stampedTailPattern.firstMatch(tail);
  final rawIndex = stamped != null
      ? stamped[2]
      : (_indexPattern.hasMatch(tail) ? tail.substring(1) : null);
  return PreservedDatabaseCopy(
    directory: directory,
    name: name,
    stamp: stamped == null ? null : parseDatabaseBackupStamp(stamped[1]!),
    index: rawIndex == null ? 0 : int.tryParse(rawIndex) ?? 0,
    fileNames: fileNames,
  );
}

final RegExp _indexPattern = RegExp(r'^\.\d+$');
final RegExp _stampedTailPattern = RegExp(r'^\.(\d{8}T\d{6}Z)(?:\.(\d+))?$');

/// Renders [when] as `20260921T125817Z` — ISO 8601's basic format, so the name
/// stays sortable, free of separators a filesystem objects to, and legible in
/// a directory listing a support report carries.
@visibleForTesting
String formatDatabaseBackupStamp(DateTime when) {
  final utc = when.toUtc();
  String pad(int value, int width) => value.toString().padLeft(width, '0');
  return '${pad(utc.year, 4)}${pad(utc.month, 2)}${pad(utc.day, 2)}'
      'T${pad(utc.hour, 2)}${pad(utc.minute, 2)}${pad(utc.second, 2)}Z';
}

/// Reads a stamp written by [formatDatabaseBackupStamp], or `null` when
/// [value] is not one.
///
/// Requires an exact round trip, so an out-of-range field — `20260231T000000Z`,
/// which `DateTime.utc` would silently roll into March — is rejected rather
/// than given a date it does not name.
@visibleForTesting
DateTime? parseDatabaseBackupStamp(String value) {
  if (value.length != 16) return null;
  int? field(int start, int end) => int.tryParse(value.substring(start, end));
  final year = field(0, 4);
  final month = field(4, 6);
  final day = field(6, 8);
  final hour = field(9, 11);
  final minute = field(11, 13);
  final second = field(13, 15);
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }
  final parsed = DateTime.utc(year, month, day, hour, minute, second);
  return formatDatabaseBackupStamp(parsed) == value ? parsed : null;
}

/// Renames an unstamped copy to [toName], sidecars included, so it carries a
/// start for its retention window.
///
/// [toName] comes from [nextPreservedDatabaseCopyPath] rather than being built
/// from the copy's own name: an indexed legacy copy would otherwise be adopted
/// as `…backup.2.<stamp>`, which no longer matches the naming, and the copy
/// would be invisible to every later sweep — preserved for good, which is the
/// bug this file exists to fix.
///
/// Best-effort: a rename that fails leaves the copy where it is for the next
/// keyed open to retry. An interruption part-way through leaves one group
/// without its database file, which the next sweep drops as debris.
void _adoptLegacyCopy(
  PreservedDatabaseCopy copy, {
  required String toName,
}) {
  for (final fileName in copy.fileNames) {
    final sidecar = fileName.substring(copy.name.length);
    try {
      File(
        p.join(copy.directory, fileName),
      ).renameSync(p.join(copy.directory, '$toName$sidecar'));
    } on FileSystemException {
      // Leave the rest of the copy where it is; the next sweep retries.
      return;
    }
  }
}

void _deleteCopy(PreservedDatabaseCopy copy) {
  for (final fileName in copy.fileNames) {
    try {
      File(p.join(copy.directory, fileName)).deleteSync();
    } on FileSystemException {
      // One undeletable file must not strand the rest of the sweep.
    }
  }
}
