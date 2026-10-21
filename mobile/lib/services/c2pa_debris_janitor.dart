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

  /// Whether [name] is the unsigned original of a signed video, such as
  /// `VID_<timestamp>.mp4.old`.
  ///
  /// Builds up to 1.0.19 renamed the recording to `<name>.old` before moving
  /// the signed copy into its place, and never deleted it. Nothing reads these
  /// files: each is a full-size duplicate of the signed video beside it.
  static bool isUnsignedOriginalName(String name) =>
      _unsignedOriginalName.hasMatch(name);

  /// Deletes stale signing debris directly inside [directory]: empty
  /// `c2pa_signed_<ms>.mp4` destinations of failed signs, and the unsigned
  /// originals described at [isUnsignedOriginalName].
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
        if (!isFailedOutput && !isUnsignedOriginalName(name)) continue;

        try {
          final stat = entity.statSync();
          if (stat.type != FileSystemEntityType.file) continue;
          if (isFailedOutput && stat.size != 0) continue;
          if (!stat.modified.isBefore(cutoff)) continue;

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
