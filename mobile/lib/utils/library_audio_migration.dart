// ABOUTME: Moves imported audio out of draft-owned storage into the library
// ABOUTME: One-shot, idempotent, basename-preserving migration for #8024

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Moves everything under `draft_audio_imports/` to `library_audio_imports/`.
///
/// Imports used to land under the draft that was open when the user picked the
/// file, so a track they later saved to My Sounds was stored inside something
/// with a shorter life than the track. New imports go straight to the library
/// root; this relocates the files already on disk so both shapes end up in one
/// place.
///
/// **The tail below the root is preserved exactly**, per-draft subdirectory
/// included. That is not tidiness left undone: it makes [resolveAudioPath]'s
/// rewrite of persisted paths a pure segment swap, which keeps a stored path
/// and its file pointing at the same place. It also prevents imports from
/// different drafts that share a basename from colliding during migration.
///
/// Directories are merged rather than skipped, for the same reason: a stored
/// path resolves to the library root whether or not this ran, so a source left
/// behind under a name the destination already uses would be a path that
/// resolves to somebody else's file. Merging removes that case except for two
/// files with the same basename, which cannot happen for two imports — the
/// name carries the import's millisecond timestamp.
///
/// Idempotent and best-effort: with nothing to move it does nothing and
/// nothing is ever overwritten or deleted. It runs on every launch, so a file
/// a transient I/O error stranded is picked up next time. A file it can never
/// move — the same-basename standoff — keeps its bytes but stops being
/// reachable through a persisted path, since [resolveAudioPath] rebases those
/// onto the library root either way. That is a leak of one file, not a loss
/// of one; the alternative is overwriting whichever copy the user still
/// plays.
Future<void> migrateDraftOwnedAudioImports({
  Directory? documentsDirectory,
}) async {
  if (kIsWeb) return;

  try {
    final documents =
        documentsDirectory ?? await getApplicationDocumentsDirectory();
    final source = Directory(p.join(documents.path, draftAudioImportsDirName));
    if (!source.existsSync()) return;

    final target = Directory(
      p.join(documents.path, libraryAudioImportsDirName),
    );
    final outcome = await _mergeInto(source, target);

    if (outcome.moved > 0 || outcome.blocked > 0) {
      Log.info(
        'Moved ${outcome.moved} imported-audio file(s) into library storage'
        '${outcome.blocked == 0 ? '' : ', ${outcome.blocked} left in place'}',
        name: 'LibraryAudioMigration',
        category: LogCategory.system,
      );
    }
    await _deleteIfEmpty(source);
  } catch (e, stackTrace) {
    // Best-effort: a failed migration is retried next launch and must never
    // take startup down with it.
    Log.error(
      'Imported-audio migration failed: $e',
      name: 'LibraryAudioMigration',
      category: LogCategory.system,
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// Moves every file under [source] to the same relative place under [target].
Future<({int moved, int blocked})> _mergeInto(
  Directory source,
  Directory target,
) async {
  var moved = 0;
  var blocked = 0;
  await target.create(recursive: true);

  for (final entity in source.listSync()) {
    final destination = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      final nested = await _mergeInto(entity, Directory(destination));
      moved += nested.moved;
      blocked += nested.blocked;
      await _deleteIfEmpty(entity);
      continue;
    }
    if (FileSystemEntity.typeSync(destination) !=
        FileSystemEntityType.notFound) {
      // Two files with the same basename. Overwriting would lose one and the
      // stored paths cannot distinguish them either, so leave the source.
      blocked += 1;
      Log.warning(
        'Left imported audio "${p.basename(entity.path)}" in draft storage: '
        'library storage already holds that name',
        name: 'LibraryAudioMigration',
        category: LogCategory.system,
      );
      continue;
    }
    try {
      await entity.rename(destination);
      moved += 1;
    } catch (e) {
      blocked += 1;
      Log.warning(
        'Could not move imported audio "${p.basename(entity.path)}" into '
        'library storage: $e',
        name: 'LibraryAudioMigration',
        category: LogCategory.system,
      );
    }
  }
  return (moved: moved, blocked: blocked);
}

Future<void> _deleteIfEmpty(Directory directory) async {
  if (!directory.existsSync()) return;
  if (directory.listSync().isNotEmpty) return;
  await directory.delete();
}
