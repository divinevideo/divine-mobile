// ABOUTME: Persists a stop-motion capture session: the eager library upserts
// ABOUTME: while shooting, the final ingest into the clip manager, and cleanup.

import 'dart:async';
import 'dart:io';

import 'package:divine_camera/divine_camera.dart' show CameraLensMetadata;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';

/// The library-side lifetime of one stop-motion capture session.
///
/// A session is the ordered list of still paths the recorder has shot so far.
/// It is mirrored into the clip library on every still (so the recording is
/// preserved the instant it is shot), rewritten on undo, ingested into the
/// clip manager on assemble, and discarded — files and library row — when the
/// user walks away from it.
///
/// Every library write goes through one serialized queue: a still, an undo
/// and an assemble can each queue a write in quick succession, and the row is
/// keyed by [sessionId] so a later write simply supersedes an earlier one. A
/// failed write is logged and never blocks the next.
class StopMotionSessionStore {
  StopMotionSessionStore({
    required ClipManagerNotifier Function() readClipManager,
  }) : _readClipManager = readClipManager;

  static const _logName = 'StopMotionSessionStore';

  final ClipManagerNotifier Function() _readClipManager;
  Future<void> _write = Future.value();

  /// Completes once every library write queued so far has settled.
  Future<void> get idle => _write;

  /// Stable library-clip id for the capture session that begins with
  /// [firstFramePath]. The first frame's filename is unique per session and
  /// unchanged while the session grows, so the eager saves during capture and
  /// the final assemble all upsert the same library row (no duplicate).
  static String sessionId(String firstFramePath) =>
      'clip_sm_${p.basenameWithoutExtension(firstFramePath)}';

  /// Hold duration of one captured still in a session of [frameCount] stills,
  /// at the render frame rate, so the library preview, the timeline, and the
  /// assembled clip all agree.
  ///
  /// A session too short to fill a second on its own is stretched to it
  /// ([StopMotionFrameOps.initialHold]): three stills at the default hold play
  /// in an eighth of a second, which the editor only shows as a flicker.
  static Duration _hold(int frameCount) =>
      StopMotionFrameOps.initialHold(frameCount);

  /// Queues an upsert of the session at [framePaths] as a single library clip.
  /// Shared by capture and undo; keyed by [sessionId] so every call targets
  /// the same row.
  ///
  /// [framePaths] are taken as readable — each still is checked as it is
  /// captured, so re-sweeping the accumulated session on every shutter tap
  /// would stat the same files repeatedly without learning anything new. The
  /// assemble re-checks the whole set (see [ingest]), which is where a still
  /// that goes missing mid-session gets dropped.
  Future<void> persistSession(
    List<String> framePaths, {
    required model.AspectRatio aspectRatio,
    CameraLensMetadata? lensMetadata,
  }) {
    return _enqueue(() async {
      if (framePaths.isEmpty) return;
      final hold = _hold(framePaths.length);
      final frames = [
        for (final path in framePaths)
          StopMotionClipFrame(path: path, duration: hold),
      ];
      final saved = await _readClipManager().saveStopMotionSessionToLibrary(
        id: sessionId(framePaths.first),
        frames: frames,
        originalAspectRatio: aspectRatio.value,
        targetAspectRatio: aspectRatio,
        duration: StopMotionFrameOps.totalDuration(frames),
        thumbnailPath: frames.first.path,
        lensMetadata: lensMetadata,
      );
      if (!saved) {
        Log.warning(
          '⚠️ Stop-motion session save to library failed',
          name: _logName,
          category: LogCategory.video,
        );
      }
    });
  }

  /// Queues the removal of the library row of the session that began with
  /// [firstFramePath]. Row only — the caller owns the frame files.
  Future<void> removeSession(String firstFramePath) => _enqueue(
    () => _readClipManager().removeStopMotionSessionFromLibrary(
      sessionId(firstFramePath),
    ),
  );

  /// Adds the captured [framePaths] to the clip manager as a frames-based
  /// stop-motion clip and queues its library save. Frame files are kept (not
  /// deleted) since they are the clip's source of truth.
  ///
  /// Reuses the capture session's library id so the row already written during
  /// capture is updated in place rather than duplicated. That row exists by the
  /// time the user taps "Next" (capture upserts it on every still) and the
  /// editor reads the clip from the clip manager, not the library — so the save
  /// is queued behind the capture-time writes rather than awaited, and the
  /// handoff to the editor stays instant.
  ///
  /// Throws a [StateError] when no still in [framePaths] is readable.
  DivineVideoClip ingest(
    List<String> framePaths, {
    required model.AspectRatio aspectRatio,
    CameraLensMetadata? lensMetadata,
  }) {
    final clipManager = _readClipManager();

    // Drop unreadable captures; a session with no readable still is a failed
    // assemble (surfaced by the caller's failure snackbar). Filtered before the
    // hold is computed so the stretch to a minimum length counts only the
    // stills that actually make it into the clip.
    final readablePaths = [
      for (final path in framePaths)
        if (StopMotionFrameOps.isReadableImage(path)) path,
    ];
    if (readablePaths.isEmpty) {
      throw StateError('No readable stop-motion stills to assemble');
    }
    final hold = _hold(readablePaths.length);
    final frames = [
      for (final path in readablePaths)
        StopMotionClipFrame(path: path, duration: hold),
    ];

    final clip = clipManager.addStopMotionClip(
      id: sessionId(framePaths.first),
      frames: frames,
      originalAspectRatio: aspectRatio.value,
      targetAspectRatio: aspectRatio,
      duration: StopMotionFrameOps.totalDuration(frames),
      thumbnailPath: frames.first.path,
      lensMetadata: lensMetadata,
    );

    final updatedClip = clipManager.clips.firstWhere(
      (c) => c.id == clip.id,
      orElse: () => clip,
    );
    unawaited(
      _enqueue(() async {
        final saved = await clipManager.saveClipToLibrary(updatedClip);
        if (!saved) {
          Log.warning(
            '⚠️ Stop-motion clip save to library failed for ${clip.id}',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }),
    );
    return clip;
  }

  /// Discards an abandoned capture session: deletes its frame files and drops
  /// the library row eagerly saved during capture. A mode switch or reset
  /// otherwise leaves an orphaned library clip whose source frames are gone.
  Future<void> discardSession(List<String> framePaths) async {
    if (framePaths.isEmpty) return;
    for (final path in framePaths) {
      await deleteFrameFile(path);
    }
    await removeSession(framePaths.first);
  }

  /// Deletes a captured stop-motion frame file, ignoring errors.
  Future<void> deleteFrameFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      Log.warning(
        '⚠️ Failed to delete stop-motion frame $path: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final run = _write
        .catchError((Object e, StackTrace s) {
          Log.warning(
            '⚠️ Previous stop-motion session write failed: $e',
            name: _logName,
            category: LogCategory.video,
          );
        })
        .then((_) => operation());
    _write = run;
    return run;
  }
}
