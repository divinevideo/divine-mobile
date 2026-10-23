// ABOUTME: Removes stale files left by legacy C2PA signing: empty failed
// ABOUTME: outputs and the unsigned `.old` originals older builds kept.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';

/// Best-effort cleanup for files C2PA signing left behind.
abstract final class C2paDebrisJanitor {
  /// Files newer than this may still belong to an active signing operation.
  static const staleDebrisAge = Duration(hours: 1);

  static final RegExp _debrisName = RegExp(r'^c2pa_signed_[0-9]+\.mp4$');

  static final RegExp _unsignedOriginalName = RegExp(
    r'.\.(mp4|mov|m4v)\.old$',
    caseSensitive: false,
  );

  /// Whether [file] is the unsigned original of a signed video, such as
  /// `VID_<timestamp>.mp4.old`, whose signed replacement sits beside it.
  ///
  /// Builds up to 1.0.19 replaced a recording with two renames: the original
  /// to `<name>.old`, then the signed copy to `<name>`. They never deleted the
  /// `.old` file, so after a completed replacement it is a full-size duplicate
  /// nothing reads. A failure between the two renames was not rolled back and
  /// left the `.old` file as the only copy of the recording, so one whose
  /// replacement is missing or empty is never redundant.
  static bool isRedundantUnsignedOriginal(File file) {
    if (!_unsignedOriginalName.hasMatch(p.basename(file.path))) return false;
    try {
      final replacement = File(p.withoutExtension(file.path)).statSync();
      return replacement.type == FileSystemEntityType.file &&
          replacement.size > 0;
    } on Object {
      // A replacement we cannot inspect does not prove the original redundant.
      return false;
    }
  }

  /// Deletes stale signing debris directly inside [directory]: empty
  /// `c2pa_signed_<ms>.mp4` destinations of failed signs, and the unsigned
  /// originals described at [isRedundantUnsignedOriginal].
  ///
  /// This is intentionally non-recursive and best-effort: inaccessible files
  /// are retried on a later launch, and filesystem failures never reach the
  /// startup coordinator.
  static void deleteStaleDebris(
    Directory directory, {
    DateTime? now,
    Duration staleAge = staleDebrisAge,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(staleAge);
    var deletedCount = 0;
    var freedBytes = 0;

    try {
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final isFailedOutput = _debrisName.hasMatch(name);
        if (!isFailedOutput && !_unsignedOriginalName.hasMatch(name)) continue;

        try {
          final stat = entity.statSync();
          if (stat.type != FileSystemEntityType.file) continue;
          if (isFailedOutput && stat.size != 0) continue;
          if (!stat.modified.isBefore(cutoff)) continue;
          if (!isFailedOutput && !isRedundantUnsignedOriginal(entity)) continue;

          entity.deleteSync();
          deletedCount++;
          freedBytes += stat.size;
        } on Object {
          // Best-effort; a file we cannot delete is retried next launch.
          Log.debug(
            'Could not remove C2PA signing debris at ${entity.path}',
            name: 'C2paDebrisJanitor',
            category: LogCategory.video,
          );
        }
      }
    } on Object catch (error, stackTrace) {
      // Best-effort; a listing failure must not block startup, but a janitor
      // that can never list its directory should be visible in logs rather
      // than indistinguishable from a clean device.
      Log.warning(
        'Could not list ${directory.path} while sweeping C2PA signing debris',
        name: 'C2paDebrisJanitor',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (deletedCount > 0) {
      Log.info(
        'Removed $deletedCount stale C2PA signing file(s), $freedBytes bytes, '
        'from ${directory.path}',
        name: 'C2paDebrisJanitor',
        category: LogCategory.video,
      );
    }
  }
}
