// ABOUTME: Riverpod provider for Clip Manager state management
// ABOUTME: Manages recorded video clips with modern Notifier pattern

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:divine_camera/divine_camera.dart' show CameraLensMetadata;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/editor_background_work.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:unified_logger/unified_logger.dart';

final clipManagerProvider =
    NotifierProvider<ClipManagerNotifier, ClipManagerState>(
      ClipManagerNotifier.new,
    );

/// Manages recorded video clips for the video editor.
///
/// Handles clip recording, organization, and state management including:
/// - Recording timer and duration tracking
/// - Clip addition, deletion, and reordering
/// - Thumbnail and metadata updates
/// - Draft and library persistence
class ClipManagerNotifier extends Notifier<ClipManagerState> {
  int _clipCounter = 0;
  Timer? _recordingDurationTimer;
  final _recordStopwatch = Stopwatch();
  final List<DivineVideoClip> _clips = [];
  Timer? _pendingDeletionTimer;

  /// Not `late final`: Riverpod reuses this notifier instance when the
  /// provider is invalidated and calls [build] again, and a second
  /// assignment to a `late final` field throws `LateInitializationError`.
  late EditorBackgroundWork _backgroundWork;

  /// Undo window before a scheduled deletion is committed to library
  /// trash for good. The snackbar must outlast this so the user can
  /// always tap Undo while the option is shown.
  static const pendingDeletionWindow = Duration(seconds: 5);

  /// Returns an unmodifiable view of all clips.
  List<DivineVideoClip> get clips => List.unmodifiable(_clips);

  /// Calculates the remaining recording time available.
  ///
  /// Returns the difference between [maxDuration] and the sum of all clip
  /// durations.
  Duration get remainingDuration {
    return VideoEditorConstants.maxDuration - totalDuration;
  }

  /// Calculates the total duration of all recorded clips.
  Duration get totalDuration {
    return _clips.fold<Duration>(
      Duration.zero,
      (sum, clip) => sum + clip.budgetDuration,
    );
  }

  @override
  ClipManagerState build() {
    _backgroundWork = ref.read(editorBackgroundWorkProvider);
    ref.onDispose(() {
      _recordingDurationTimer?.cancel();
      _pendingDeletionTimer?.cancel();
      _pendingDeletionTimer = null;
      _recordStopwatch.stop();
      _clips.clear();
      Log.debug(
        '🧹 ClipManagerNotifier disposed',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    });
    return ClipManagerState();
  }

  /// Trigger autosave via VideoEditorProvider (debounced).
  ///
  /// Also clears the cached merge output since clips have changed.
  void _triggerAutosave() {
    final notifier = ref.read(videoEditorProvider.notifier);

    notifier.invalidateFinalRenderedClip();
    notifier.triggerAutosave();

    state = state.copyWith(clearMergeOutputPath: true);
  }

  /// Force immediate autosave without debounce.
  /// Use this before file cleanup to ensure references are updated.
  Future<void> _forceAutosave() =>
      ref.read(videoEditorProvider.notifier).autosaveChanges();

  /// Caches the merge-render output path so the video editor can skip
  /// re-rendering when the screen is re-opened with unchanged clips.
  void cacheMergeOutput(String outputPath) {
    state = state.copyWith(mergeOutputPath: outputPath);
  }

  /// Manually trigger a state refresh with current clips.
  ///
  /// Forces a rebuild of consumers without modifying clip data.
  void refreshClips() {
    state = state.copyWith(clips: List.unmodifiable(_clips));
    Log.debug(
      '🔄 Refreshed clips state',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Start recording timer for active clip duration tracking.
  void startRecording() {
    _recordStopwatch
      ..reset()
      ..start();

    Log.debug(
      '▶️  Recording timer started',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    // Update activeRecordingDuration every 16ms (~60fps).
    // We ONLY rebuild with that logic, the progress inside of the segment-bar.
    _recordingDurationTimer = Timer.periodic(const Duration(milliseconds: 16), (
      _,
    ) {
      if (_recordStopwatch.isRunning) {
        state = state.copyWith(
          activeRecordingDuration: _recordStopwatch.elapsed,
        );
      }
    });
  }

  /// Stop recording timer and freeze duration.
  void stopRecording() {
    _recordStopwatch.stop();
    _recordingDurationTimer?.cancel();

    Log.debug(
      '⏸️  Recording timer stopped at '
      '${_recordStopwatch.elapsed.inMilliseconds}ms',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Reset recording stopwatch to zero.
  void resetRecording() {
    _recordStopwatch.reset();
    Log.debug(
      '🔄 Recording timer reset',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Add a new recorded clip to the list.
  ///
  /// If the clip duration exceeds [remainingDuration], it will be automatically
  /// trimmed to fit within the max duration limit. The trimming happens
  /// asynchronously in the background while the clip is displayed immediately.
  ///
  /// After recording (and optional trimming), a ProofMode / C2PA attestation
  /// is generated for the clip's video file. The clip is updated with the
  /// resulting [proofManifestJson] once generation completes.
  ///
  /// Returns the created clip with unique ID.
  DivineVideoClip addClip({
    required EditorVideo video,
    required double originalAspectRatio,
    required model.AspectRatio targetAspectRatio,
    required bool limitClipDuration,
    Duration? duration,
    String? thumbnailPath,
    CameraLensMetadata? lensMetadata,
  }) {
    // A new recording supersedes any pending undo from a previous tap.
    if (state.pendingDeletion != null) {
      _cancelPendingDeletionTimer();
      unawaited(commitPendingDeletion());
    }

    final clipDuration =
        duration ??
        Duration(microseconds: _recordStopwatch.elapsedMicroseconds);
    final remainingDuration = this.remainingDuration;

    // Check if clip needs to be trimmed to fit within max duration
    final isClipTooLong = limitClipDuration && clipDuration > remainingDuration;

    // Create a completer to track async trimming progress only when needed.
    // Proof generation runs independently and does not block the UI.
    final processingCompleter = isClipTooLong ? Completer<bool>() : null;

    var clip = DivineVideoClip(
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}_${_clipCounter++}',
      video: video,
      duration: isClipTooLong ? remainingDuration : clipDuration,
      recordedAt: .now(),
      thumbnailPath: thumbnailPath,
      targetAspectRatio: targetAspectRatio,
      originalAspectRatio: originalAspectRatio,
      processingCompleter: processingCompleter,
      lensMetadata: lensMetadata,
    );

    // Asynchronously trim the clip if it exceeds remaining duration
    if (isClipTooLong) {
      unawaited(
        VideoEditorRenderService.limitClipDuration(
          clip: clip,
          duration: remainingDuration,
          onComplete: (success) async {
            if (!ref.mounted) return;
            processingCompleter!.complete(success);

            /// If the clip exists already we use the newest thumbnail
            /// from that clip.
            final existingClip = getClipById(clip.id);
            if (existingClip != null) {
              clip = clip.copyWith(
                thumbnailPath: existingClip.thumbnailPath,
                thumbnailTimestamp: existingClip.thumbnailTimestamp,
              );
            }

            refreshClip(clip);
          },
        ),
      );
    }

    _clips.add(clip);
    Log.info(
      '📎 Added clip: ${clip.id}, duration: ${clip.durationInSeconds}s',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    if (duration == null) {
      resetRecording();
    }
    state = state.copyWith(
      clips: List.unmodifiable(_clips),
      activeRecordingDuration: .zero,
    );

    _triggerAutosave();

    // Fire-and-forget: generate proof attestation without blocking the UI.
    // This runs after trimming (if any) completes via the processingCompleter.
    _backgroundWork.track(_generateClipProof(clip));

    return clip;
  }

  /// Adds a frames-based stop-motion clip to the manager.
  ///
  /// The captured stills ([frames]) are the clip's source of truth; no mp4
  /// exists yet — the editor previews the frames via the stop-motion player and
  /// an mp4 is rendered only at publish. Trimming and proof generation are
  /// skipped (both operate on a rendered video).
  DivineVideoClip addStopMotionClip({
    required List<StopMotionClipFrame> frames,
    required double originalAspectRatio,
    required model.AspectRatio targetAspectRatio,
    required Duration duration,
    String? id,
    String? thumbnailPath,
    CameraLensMetadata? lensMetadata,
  }) {
    // A new clip supersedes any pending undo from a previous tap.
    if (state.pendingDeletion != null) {
      _cancelPendingDeletionTimer();
      unawaited(commitPendingDeletion());
    }

    final clip = DivineVideoClip(
      // Reuse the session id when the frames were already persisted to the
      // library during capture, so assembling updates that row instead of
      // creating a second one.
      id:
          id ??
          'clip_${DateTime.now().millisecondsSinceEpoch}_${_clipCounter++}',
      stopMotionFrames: frames,
      duration: duration,
      recordedAt: .now(),
      thumbnailPath: thumbnailPath,
      targetAspectRatio: targetAspectRatio,
      originalAspectRatio: originalAspectRatio,
      lensMetadata: lensMetadata,
    );

    _clips.add(clip);
    Log.info(
      '📎 Added stop-motion clip: ${clip.id}, ${frames.length} frame(s)',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    state = state.copyWith(
      clips: List.unmodifiable(_clips),
      activeRecordingDuration: .zero,
    );

    _triggerAutosave();

    return clip;
  }

  /// Generates a ProofMode / C2PA attestation for a single clip.
  ///
  /// Waits for any pending processing (e.g. trimming) to finish first,
  /// then generates the proof and updates the clip via [refreshClip].
  /// Failures are logged but do not block clip usage.
  Future<void> _generateClipProof(DivineVideoClip clip) async {
    try {
      // Wait for trimming to finish before proofing the final file
      await clip.processingCompleter?.future;

      final videoFile = clip.video?.file;
      if (videoFile == null) return;

      Log.debug(
        '🔐 Generating proof attestation for clip ${clip.id}',
        name: 'ClipManagerNotifier',
        category: .video,
      );

      final proofData = await NativeProofModeService.proofFile(
        File(videoFile.path),
      );

      if (!ref.mounted) return;

      if (proofData != null) {
        // Merge with latest clip state (thumbnail may have been updated).
        // If the clip was deleted while proof generation was in progress,
        // skip the update entirely.
        final current = getClipById(clip.id);
        if (current == null) return;
        refreshClip(current.copyWith(proofManifestJson: jsonEncode(proofData)));
        _triggerAutosave();

        Log.info(
          '✅ Proof attestation generated for clip ${clip.id}',
          name: 'ClipManagerNotifier',
          category: .video,
        );
      } else {
        Log.warning(
          '⚠️ No proof data available for clip ${clip.id}',
          name: 'ClipManagerNotifier',
          category: .video,
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to generate proof for clip ${clip.id}: $e',
        name: 'ClipManagerNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Insert a clip at a specific position.
  ///
  /// Adds [clip] at [index], shifting subsequent clips forward.
  /// Returns the inserted clip.
  DivineVideoClip insertClip(int index, DivineVideoClip clip) {
    _clips.insert(index, clip);
    Log.info(
      '📎 Insert clip: ${clip.id}, '
      'position: $index '
      'duration: ${clip.durationInSeconds}s',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    state = state.copyWith(clips: List.unmodifiable(_clips));

    _triggerAutosave();
    return clip;
  }

  /// Add multiple clips at once (e.g., from draft restoration).
  ///
  /// Appends all clips to the end of the current clip list and updates state.
  /// Used when restoring drafts or importing multiple clips from library.
  void addMultipleClips(List<DivineVideoClip> clips) {
    if (clips.isEmpty) {
      Log.debug(
        '📎 No clips to add - empty list provided',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return;
    }

    final previousCount = _clips.length;
    _clips.addAll(clips);

    Log.info(
      '📎 Added ${clips.length} clips '
      '($previousCount → ${_clips.length} total)',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    state = state.copyWith(clips: List.unmodifiable(_clips));
    _triggerAutosave();
  }

  /// Replace all clips at once.
  ///
  /// Clears the current clip list and installs [clips] in a single state
  /// update so consumers never observe an intermediate empty-then-populated
  /// transition during restoration flows.
  ///
  /// Pass [autosave] as `false` when installing clips that reflect no user
  /// edit — e.g. restoring a draft for viewing. An autosave there would bump
  /// the draft's `lastModified` (reordering it to the top of the drafts list
  /// as if freshly saved) and invalidate/delete the just-restored
  /// `finalRenderedClip`, mutating a draft the user only opened to watch.
  void replaceClips(List<DivineVideoClip> clips, {bool autosave = true}) {
    final previousCount = _clips.length;
    _clips
      ..clear()
      ..addAll(clips);

    Log.info(
      '📎 Replaced $previousCount clips with ${clips.length} clip(s)',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    state = state.copyWith(clips: List.unmodifiable(_clips));
    if (autosave) _triggerAutosave();
  }

  /// Delete a clip by ID.
  ///
  /// Returns true if the clip was successfully deleted, false if not found.
  /// Also deletes associated files if not referenced elsewhere.
  Future<bool> removeClipById(String clipId) async {
    if (state.pendingDeletion != null) {
      _cancelPendingDeletionTimer();
      await commitPendingDeletion();
    }

    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index == -1) {
      Log.warning(
        '⚠️ Cannot delete - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return false;
    }

    ref.read(videoEditorProvider.notifier).invalidateFinalRenderedClip();

    final clip = _clips[index];
    _clips.removeAt(index);
    Log.info(
      '🗑️  Deleted clip: $clipId (${_clips.length} remaining)',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    state = state.copyWith(
      clips: List.unmodifiable(_clips),
      clearMergeOutputPath: true,
    );

    // Guard against provider disposal during the async gap above: both
    // branches below reach for providers through `ref` and would throw on a
    // disposed notifier.
    if (!ref.mounted) return true;

    // Force immediate autosave so draft references are updated before cleanup.
    // The last clip is different: an empty autosave is not recoverable, so clear
    // the session instead of writing a zero-clip draft that the reaper later
    // treats as corruption.
    if (_clips.isEmpty) {
      await _clearProviders();
    } else {
      await _forceAutosave();
    }

    // Persisting above is another async gap.
    if (!ref.mounted) return true;

    // File cleanup is best-effort: the clip is already gone from state and
    // the autosave above persists that. A failure here (database init
    // hiccup, missing file, etc.) must not turn this method into a
    // rejection — callers and tests rely on the state-mutation contract,
    // not on disk effects.
    try {
      final db = ref.read(databaseProvider);
      await FileCleanupService.deleteRecordingClipFiles(
        clip,
        draftsDao: db.draftsDao,
        clipsDao: db.clipsDao,
      );
    } catch (e, stackTrace) {
      Log.error(
        '⚠️ Best-effort cleanup after deleting $clipId failed: $e',
        name: 'ClipManagerNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  /// Reorder a single clip from oldIndex to newIndex.
  ///
  /// Moves the clip at [oldIndex] to [newIndex], shifting other clips
  /// accordingly.
  void reorderClip(int oldIndex, int newIndex) {
    if (state.pendingDeletion != null) {
      _cancelPendingDeletionTimer();
      unawaited(commitPendingDeletion());
    }

    if (oldIndex < 0 ||
        oldIndex >= _clips.length ||
        newIndex < 0 ||
        newIndex >= _clips.length) {
      Log.warning(
        '⚠️ Invalid reorder indices: $oldIndex → $newIndex '
        '(length: ${_clips.length})',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return;
    }

    if (oldIndex == newIndex) return;

    final clip = _clips.removeAt(oldIndex);
    _clips.insert(newIndex, clip);

    Log.info(
      '📎 Reordered clip ${clip.id}: $oldIndex → $newIndex',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    state = state.copyWith(clips: List.unmodifiable(_clips));
    _triggerAutosave();
  }

  /// Update thumbnail path for a clip.
  void updateThumbnail({
    required String clipId,
    required String thumbnailPath,
    required Duration thumbnailTimestamp,
  }) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(
        thumbnailPath: thumbnailPath,
        thumbnailTimestamp: thumbnailTimestamp,
      );
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '🖼️  Updated thumbnail for clip: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update thumbnail - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Mutes every clip by setting its volume to zero.
  ///
  /// Used by lip-sync mode before handing off to the editor so the recorded
  /// clips are silent and only the selected sound is audible.
  void muteAllClips() {
    if (_clips.isEmpty || _clips.every((c) => c.volume == 0)) return;
    for (var i = 0; i < _clips.length; i++) {
      _clips[i] = _clips[i].copyWith(volume: 0);
    }
    state = state.copyWith(clips: List.unmodifiable(_clips));
    Log.debug(
      '🔇 Muted all clips for lip-sync',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    _triggerAutosave();
  }

  /// Update ghost frame path for a clip.
  void updateGhostFrame({
    required String clipId,
    required String ghostFramePath,
  }) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(ghostFramePath: ghostFramePath);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '👻 Updated ghost frame for clip: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update ghost frame - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
  }

  /// Update duration for a clip (from metadata extraction).
  void updateClipDuration(String clipId, Duration duration) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(duration: duration);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '⏱️  Updated duration for clip: $clipId → ${duration.inMilliseconds}ms',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update duration - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Update video for a clip (e.g., after trimming or editing).
  ///
  /// Replaces the EditorVideo instance for the clip with [clipId].
  void updateClipVideo(String clipId, EditorVideo video) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(video: video);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '🎬 Updated video for clip: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update video - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Update thumbnail path for a clip.
  ///
  /// Alternative method to [updateThumbnail] with same functionality.
  void updateClipThumbnail(String clipId, String thumbnailPath) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(thumbnailPath: thumbnailPath);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '🖼️  Updated thumbnail for clip: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update thumbnail - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Refresh an existing clip with new data.
  ///
  /// Replaces the entire clip instance at the matching ID position.
  void refreshClip(
    DivineVideoClip clip, {
    String? newId,
    bool createNewClipId = false,
  }) {
    final index = _clips.indexWhere((c) => c.id == clip.id);
    if (index != -1) {
      final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
      final newClipId = newId ?? (createNewClipId ? timestamp : null);

      _clips[index] = clip.copyWith(id: newClipId);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '⏱️  Refreshed clip: ${clip.id}',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot refresh - clip not found: ${clip.id}',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Select a clip for editing.
  ///
  /// Sets the currently selected clip ID. Pass null to deselect.
  void selectClip(String? clipId) {
    state = state.copyWith(selectedClipId: clipId);
    Log.debug(
      clipId == null ? '🔽 Deselected clip' : '🔼 Selected clip: $clipId',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Get a clip by its ID.
  ///
  /// Returns the clip with [clipId], or null if not found.
  DivineVideoClip? getClipById(String clipId) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    return index >= 0 ? _clips[index] : null;
  }

  /// Schedule a soft-delete of the most recent clip.
  ///
  /// Removes the clip from the visible tray immediately and marks it
  /// as trashed in the library (with its `draft_id` cleared, so a
  /// restore later lands in the library rather than a stale session).
  /// Hard-deletion is deferred to the trash retention window — the
  /// snackbar Undo path calls [undoPendingDeletion] to roll back.
  ///
  /// If a previous deletion is still pending, it is committed
  /// synchronously first: tapping the button again means the user has
  /// moved on from the previous undo opportunity.
  ///
  /// No-ops when the clip list is empty.
  Future<void> scheduleDeleteLastClip() async {
    if (_clips.isEmpty) {
      Log.debug(
        '⚠️ Cannot delete last clip - no clips available',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return;
    }

    // Commit any in-flight pending deletion first so we never lose
    // its draft-decoupling effect by overwriting state.pendingDeletion.
    if (state.pendingDeletion != null) {
      _cancelPendingDeletionTimer();
      await commitPendingDeletion();
    }

    final lastIndex = _clips.length - 1;
    final lastClip = _clips[lastIndex];

    Log.info(
      '🗑️  Scheduling delete of last clip: ${lastClip.id}',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    _clips.removeAt(lastIndex);
    state = state.copyWith(
      clips: List.unmodifiable(_clips),
      pendingDeletion: ClipPendingDeletion(
        clip: lastClip,
        originalIndex: lastIndex,
      ),
      clearMergeOutputPath: true,
    );

    final clipLibraryService = ref.read(clipLibraryServiceProvider);
    await clipLibraryService.softDelete(lastClip.id, clearDraftId: true);
    await _forceAutosave();
    if (!ref.mounted) return;

    _pendingDeletionTimer = Timer(pendingDeletionWindow, () {
      _pendingDeletionTimer = null;
      unawaited(commitPendingDeletion());
    });
  }

  /// Reverse the pending deletion within the undo window. Restores
  /// the clip to its original position in [clips] and brings it back
  /// out of library trash. No-ops if no deletion is pending.
  Future<void> undoPendingDeletion() async {
    final pending = state.pendingDeletion;
    if (pending == null) return;

    _cancelPendingDeletionTimer();

    Log.info(
      '↩️  Undoing scheduled delete: ${pending.clip.id}',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    final insertIndex = pending.originalIndex.clamp(0, _clips.length);
    _clips.insert(insertIndex, pending.clip);
    state = state.copyWith(
      clips: List.unmodifiable(_clips),
      clearPendingDeletion: true,
      clearMergeOutputPath: true,
    );

    final clipLibraryService = ref.read(clipLibraryServiceProvider);
    await clipLibraryService.restore(pending.clip.id);
    await _forceAutosave();
  }

  void _cancelPendingDeletionTimer() {
    _pendingDeletionTimer?.cancel();
    _pendingDeletionTimer = null;
  }

  /// Drop the pending-deletion marker. The clip stays in library trash
  /// and the 30-day retention window owns hard-deletion from here.
  ///
  /// Called internally when the user moves on from the undo opportunity
  /// (new recording, reorder, another delete), and by the recorder-exit
  /// navigation before the next step snapshots the clip list. No-ops
  /// when no deletion is pending.
  Future<void> commitPendingDeletion() async {
    final pending = state.pendingDeletion;
    if (pending == null) return;
    _cancelPendingDeletionTimer();
    state = state.copyWith(clearPendingDeletion: true);
    Log.debug(
      '✅ Committed scheduled delete: ${pending.clip.id}',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Clear all clips without deleting files or autosave.
  ///
  /// Used when restoring a draft to prevent clip duplication.
  void clearClips() {
    _cancelPendingDeletionTimer();
    final clipCount = _clips.length;
    _clips.clear();
    Log.debug(
      '🔄 Cleared $clipCount clips (files preserved)',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    state = ClipManagerState();
  }

  /// Remove all clips without resetting peer providers or deleting autosave.
  ///
  /// Used by higher-level teardown coordinators that own the rest of the
  /// session cleanup.
  Future<void> clearSessionClips() async {
    _cancelPendingDeletionTimer();
    if (state.pendingDeletion != null) {
      await commitPendingDeletion();
    }
    _clearLocalClipState();
  }

  void _clearLocalClipState() {
    final clipCount = _clips.length;
    _clips.clear();
    Log.info(
      '🗑️  Cleared all clips (removed $clipCount clips)',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    state = ClipManagerState();
  }

  /// Remove all clips and reset state.
  ///
  /// Clears all recorded clips and resets to initial state.
  /// Also deletes the autosave draft unless [keepAutosavedDraft] is true.
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    await clearSessionClips();
    await _clearProviders(keepAutosavedDraft: keepAutosavedDraft);
  }

  Future<void> _clearProviders({bool keepAutosavedDraft = false}) async {
    ref.read(videoPublishProvider.notifier).reset();
    await ref
        .read(videoEditorProvider.notifier)
        .reset(keepAutosavedDraft: keepAutosavedDraft);
  }

  /// Save clip(s) to library.
  ///
  /// Iterates through all clips and saves them to the persistent clip library.
  /// Continues saving remaining clips even if individual saves fail.
  Future<bool> saveClipsToLibrary() async {
    Log.info(
      '💾 Starting to save ${_clips.length} clips to library',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    try {
      // IMPORTANT: Do not change to Future.wait or parallel execution.
      // Sequential saving ensures each clip is fully persisted before the next,
      // preventing file conflicts and ensuring data integrity.
      for (final clip in _clips) {
        await saveClipToLibrary(clip);
      }

      Log.info(
        '💾 Successfully saved clips to library',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to save clips to library: $e',
        name: 'ClipManagerNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Save specific clip to library.
  ///
  /// Returns true if the clip was successfully saved, false otherwise.
  Future<bool> saveClipToLibrary(DivineVideoClip clip) async {
    Log.info(
      '💾 Starting to save clip to library',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    try {
      final clipService = ref.read(clipLibraryServiceProvider);

      await clipService.saveClip(clip);

      Log.debug(
        '✅ Saved clip ${clip.id} to library (${clip.durationInSeconds}s)',
        name: 'ClipManagerNotifier',
        category: .video,
      );

      Log.info(
        '💾 Successfully saved clip to library',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to save clip ${clip.id}: $e',
        name: 'ClipManagerNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Persists the in-progress stop-motion capture session as a single library
  /// clip so the recording is preserved the instant it is shot — before the
  /// user assembles it and opens the editor.
  ///
  /// [id] is stable for the lifetime of a capture session (derived from the
  /// first frame), so repeated calls upsert the same library row as frames are
  /// added. Assembling later reuses the same [id] (see [addStopMotionClip]),
  /// updating this row rather than creating a duplicate.
  ///
  /// Returns true if the row was saved.
  Future<bool> saveStopMotionSessionToLibrary({
    required String id,
    required List<StopMotionClipFrame> frames,
    required double originalAspectRatio,
    required model.AspectRatio targetAspectRatio,
    required Duration duration,
    String? thumbnailPath,
    CameraLensMetadata? lensMetadata,
  }) {
    final clip = DivineVideoClip(
      id: id,
      stopMotionFrames: frames,
      duration: duration,
      recordedAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
      targetAspectRatio: targetAspectRatio,
      originalAspectRatio: originalAspectRatio,
      lensMetadata: lensMetadata,
    );
    return saveClipToLibrary(clip);
  }

  /// Removes an abandoned stop-motion session's library row (its frames were
  /// all undone). Deletes the row only; the frame files are owned and cleaned
  /// up by the recorder.
  Future<void> removeStopMotionSessionFromLibrary(String id) async {
    try {
      await ref.read(clipLibraryServiceProvider).deleteClipRow(id);
    } catch (e) {
      Log.warning(
        '⚠️ Failed to remove stop-motion session $id from library: $e',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
  }
}
