// ABOUTME: Sweeps every store that can reference a draft-local audio file
// ABOUTME: so an orphaned one can be reclaimed without deleting audio in use

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:openvine/extensions/draft_local_audio_extensions.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Basenames of draft-local audio still referenced on this device, plus
/// whether the sweep that produced them could read every store it found.
///
/// [isComplete] is the difference between "no reference exists" and "no
/// reference was *found*". A corrupt draft blob, an undecodable My Sounds
/// bucket, or a payload written by a newer build all leave a reference the
/// sweep cannot see, and a caller that deletes on the strength of the set
/// would then reclaim a file the user is still using. Callers that only widen
/// what they keep (draft deletion) may ignore it; callers that delete on the
/// absence of a reference must refuse when it is false.
typedef LocalAudioReferences = ({Set<String> filenames, bool isComplete});

/// Reference sweep over every store that can name a draft-local audio file.
///
/// Draft-local audio — imported tracks under `draft_audio_imports/`, committed
/// voice-over takes, and audio extracted from a draft's own clips — is
/// persisted inside the draft `data` blob and inside the My Sounds buckets,
/// neither of which is an indexed file column. So the indexed clip/draft
/// reference check that [FileCleanupService] applies to video and thumbnail
/// files cannot see any of it, and every caller that deletes such a file has
/// to be handed the basenames a scan of those blobs found.
///
/// One implementation, two directions: draft deletion asks which files a
/// *surviving* draft or saved sound still needs, and saved-sound removal asks
/// whether anything at all still needs the file the removed entry owned. A
/// second copy of this scan drifting from the first is exactly how a file the
/// user still plays gets deleted, so both go through here.
class LocalAudioCleanupService {
  LocalAudioCleanupService({
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
    SharedPreferences? preferences,
  }) : _draftsDao = draftsDao,
       _clipsDao = clipsDao,
       _preferences = preferences;

  final DraftsDao _draftsDao;
  final ClipsDao _clipsDao;

  /// Where My Sounds lives. Nullable so callers that never delete audio need
  /// not wire it; an instance without it cannot prove a file is unreferenced
  /// and therefore never reclaims one.
  final SharedPreferences? _preferences;

  static const _logName = 'LocalAudioCleanupService';

  /// Basenames of draft-local audio a saved sound points at, across every
  /// account bucket on this device.
  ///
  /// All accounts, not just the signed-in one: audio cleanup runs device-wide
  /// and a saved sound outlives the account switch that hides it.
  LocalAudioReferences savedSoundReferences() {
    final preferences = _preferences;
    return preferences == null
        ? (filenames: const <String>{}, isComplete: false)
        : SavedSoundsService.localAudioReferences(preferences);
  }

  /// Basenames of draft-local audio referenced by any draft still in the
  /// database or any saved sound, across all accounts.
  ///
  /// Scans the draft `data` blobs directly — audio paths live there, not in an
  /// indexed column — and never throws: a blob that will not parse is logged,
  /// skipped, and reported through [LocalAudioReferences.isComplete].
  ///
  /// Callers run this *after* removing the draft or saved sound they are
  /// cleaning up, so everything it sees is a survivor and there is nothing to
  /// exclude.
  Future<LocalAudioReferences> referencedAudioFilenames() async {
    final savedSounds = savedSoundReferences();
    final rows = await _draftsDao.getAllDrafts();
    final documentsPath = await getDocumentsPath();

    final filenames = <String>{...savedSounds.filenames};
    var isComplete = savedSounds.isComplete;

    for (final row in rows) {
      final DivineVideoDraft draft;
      try {
        draft = DivineVideoDraft.fromJson(
          json.decode(row.data) as Map<String, dynamic>,
          documentsPath,
        );
      } catch (e) {
        isComplete = false;
        Log.error(
          '🧹 Skipping draft ${row.id} during audio reference scan: $e',
          name: _logName,
          category: LogCategory.video,
        );
        continue;
      }
      for (final path in draft.localAudioFilePaths) {
        filenames.add(p.basename(path));
      }
    }

    return (filenames: filenames, isComplete: isComplete);
  }

  /// Deletes [audioFilePath] once nothing on this device references it.
  ///
  /// Called after a My Sounds entry is removed. Audio imported from the
  /// Library is written under whichever draft was open at the time, so the
  /// file the entry pointed at can equally be a draft's own track, a track a
  /// second saved sound shares, or nobody's — only the sweep can tell them
  /// apart. #8011 taught the draft side to keep a file My Sounds still names;
  /// without this the same file simply became a permanent orphan when the
  /// saved sound went instead.
  ///
  /// Refuses to delete whenever the sweep is incomplete: an unreadable store
  /// means the reference set is a lower bound, and a leaked file costs disk
  /// while a wrongly reclaimed one costs the user audio they still play. Also
  /// refuses any path outside this app's own audio storage — a stored
  /// `localFilePath` that never went through an importer is not ours to
  /// reclaim, whatever it points at.
  ///
  /// Throws:
  ///
  /// * Exceptions from the draft query or the filesystem existence check are
  ///   propagated. Deletion failures are logged by [FileCleanupService] and
  ///   otherwise ignored.
  Future<void> reclaimUnreferencedAudio(String? audioFilePath) async {
    if (audioFilePath == null || audioFilePath.isEmpty) return;

    if (!isDraftLocalAudioPath(audioFilePath)) {
      Log.warning(
        '🔒 Not draft-local audio storage, keeping file: $audioFilePath',
        name: _logName,
        category: LogCategory.video,
      );
      return;
    }

    final references = await referencedAudioFilenames();
    if (!references.isComplete) {
      Log.warning(
        '🔒 Audio reference scan incomplete, keeping file: $audioFilePath',
        name: _logName,
        category: LogCategory.video,
      );
      return;
    }

    await FileCleanupService.deleteDraftAudioFiles(
      [audioFilePath],
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
      referencedAudioFilenames: references.filenames,
    );
  }
}
