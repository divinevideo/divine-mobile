// ABOUTME: UI state model for the Clip Manager screen
// ABOUTME: Tracks clips, selection state, and duration calculations

import 'package:equatable/equatable.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';

/// In-flight soft-delete of a clip from the active recording session.
///
/// While present in [ClipManagerState.pendingDeletion], the clip is
/// hidden from `clips` and has been moved to library trash, but its
/// hard-deletion is deferred for an undo window. Tapping the snackbar
/// Undo within the window restores the clip to [originalIndex] and
/// pulls it back out of trash; ignoring the snackbar lets the clip
/// stay in trash where the 30-day retention window owns the next step.
class ClipPendingDeletion extends Equatable {
  const ClipPendingDeletion({required this.clip, required this.originalIndex});

  /// The clip that was just soft-deleted, preserved so Undo can
  /// reinsert it without re-reading from disk.
  final DivineVideoClip clip;

  /// Position the clip occupied in `clips` before deletion. Used to
  /// restore the original ordering on Undo.
  final int originalIndex;

  @override
  List<Object?> get props => [clip.id, originalIndex];
}

/// State model for the Clip Manager.
///
/// Manages the complete state of recorded video clips including:
/// - List of recorded clips
/// - Selection and preview states
/// - UI states (reordering, processing)
/// - Audio settings
/// - Duration tracking and calculations
class ClipManagerState {
  ClipManagerState({
    this.clips = const [],
    this.selectedClipId,
    this.previewingClipId,
    this.isReordering = false,
    this.isProcessing = false,
    this.errorMessage,
    this.muteOriginalAudio = false,
    this.activeRecordingDuration = .zero,
    this.mergeOutputPath,
    this.pendingDeletion,
    this.libraryRevision = 0,
  });

  /// List of all recorded clips in order.
  final List<DivineVideoClip> clips;

  /// Goes up each time this manager rewrites a clip in the library behind the
  /// library's back — a chroma-key take whose keyed file landed — so a library
  /// that is already on screen knows to load again.
  final int libraryRevision;

  /// ID of the currently selected clip for editing, or null if none selected.
  final String? selectedClipId;

  /// ID of the clip currently being previewed, or null if none previewing.
  final String? previewingClipId;

  /// Whether the user is actively reordering clips.
  final bool isReordering;

  /// Whether a long-running operation (e.g., processing, saving) is in progress.
  final bool isProcessing;

  /// Error message to display to the user, or null if no error.
  final String? errorMessage;

  /// Whether to mute the original audio from clips during playback.
  final bool muteOriginalAudio;

  /// Current duration of the active recording in progress.
  final Duration activeRecordingDuration;

  /// Cached merge-render output path.
  ///
  /// Set after clips are concatenated into a preview video. Cleared
  /// automatically whenever clips are added, removed, or reordered.
  final String? mergeOutputPath;

  /// A clip that was soft-deleted from the active session and is
  /// waiting in the undo window. Hidden from `clips` and present in
  /// library trash; UI uses this to drive the Undo snackbar.
  final ClipPendingDeletion? pendingDeletion;

  /// Total combined duration of all clips.
  Duration get totalDuration {
    return clips.fold(Duration.zero, (sum, clip) => sum + clip.budgetDuration);
  }

  /// Remaining recording time available before reaching max duration.
  ///
  /// Returns zero if max duration has been reached or exceeded.
  Duration get remainingDuration {
    final remaining = VideoEditorConstants.maxDuration - totalDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether more recording time is available.
  bool get canRecordMore => remainingDuration > Duration.zero;

  /// Whether at least one clip has been recorded.
  bool get hasClips => clips.isNotEmpty;

  /// The first clip in the list, or null when no clips are available.
  DivineVideoClip? get firstClipOrNull => clips.isEmpty ? null : clips.first;

  /// Total number of clips.
  int get clipCount => clips.length;

  /// The currently selected clip, or null if none selected or not found.
  DivineVideoClip? get selectedClip {
    if (selectedClipId == null) return null;
    try {
      return clips.firstWhere((c) => c.id == selectedClipId);
    } catch (_) {
      return null;
    }
  }

  /// The clip currently being previewed, or null if none previewing or not found.
  DivineVideoClip? get previewingClip {
    if (previewingClipId == null) return null;
    try {
      return clips.firstWhere((c) => c.id == previewingClipId);
    } catch (_) {
      return null;
    }
  }

  /// Creates a copy of this state with updated fields.
  ///
  /// Provides special flags to explicitly clear optional fields:
  /// - [clearSelection]: Sets selectedClipId to null
  /// - [clearPreview]: Sets previewingClipId to null
  /// - [clearError]: Sets errorMessage to null
  ClipManagerState copyWith({
    List<DivineVideoClip>? clips,
    String? selectedClipId,
    String? previewingClipId,
    bool? isReordering,
    bool? isProcessing,
    String? errorMessage,
    bool? muteOriginalAudio,
    bool clearSelection = false,
    bool clearPreview = false,
    bool clearError = false,
    Duration? activeRecordingDuration,
    String? mergeOutputPath,
    bool clearMergeOutputPath = false,
    ClipPendingDeletion? pendingDeletion,
    bool clearPendingDeletion = false,
    int? libraryRevision,
  }) {
    return ClipManagerState(
      clips: clips ?? this.clips,
      selectedClipId: clearSelection
          ? null
          : (selectedClipId ?? this.selectedClipId),
      previewingClipId: clearPreview
          ? null
          : (previewingClipId ?? this.previewingClipId),
      isReordering: isReordering ?? this.isReordering,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      muteOriginalAudio: muteOriginalAudio ?? this.muteOriginalAudio,
      activeRecordingDuration:
          activeRecordingDuration ?? this.activeRecordingDuration,
      mergeOutputPath: clearMergeOutputPath
          ? null
          : (mergeOutputPath ?? this.mergeOutputPath),
      pendingDeletion: clearPendingDeletion
          ? null
          : (pendingDeletion ?? this.pendingDeletion),
      libraryRevision: libraryRevision ?? this.libraryRevision,
    );
  }
}
