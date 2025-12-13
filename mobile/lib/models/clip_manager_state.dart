// ABOUTME: UI state model for the Clip Manager screen
// ABOUTME: Tracks clips, selection state, and duration calculations

import 'package:openvine/models/recording_clip.dart';

class ClipManagerState {
  ClipManagerState({
    this.clips = const [],
    this.selectedClipId,
    this.previewingClipId,
    this.isReordering = false,
    this.isProcessing = false,
    this.errorMessage,
    this.muteOriginalAudio = false,
  });

  final List<RecordingClip> clips;
  final String? selectedClipId;
  final String? previewingClipId;
  final bool isReordering;
  final bool isProcessing;
  final String? errorMessage;
  final bool muteOriginalAudio;

  static const Duration maxDuration = Duration(milliseconds: 6300);

  Duration get totalDuration {
    return clips.fold(
      Duration.zero,
      (sum, clip) => sum + clip.duration,
    );
  }

  Duration get remainingDuration {
    final remaining = maxDuration - totalDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canRecordMore => remainingDuration > Duration.zero;

  bool get hasClips => clips.isNotEmpty;

  int get clipCount => clips.length;

  List<RecordingClip> get sortedClips {
    final sorted = List<RecordingClip>.from(clips);
    sorted.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sorted;
  }

  RecordingClip? get selectedClip {
    if (selectedClipId == null) return null;
    try {
      return clips.firstWhere((c) => c.id == selectedClipId);
    } catch (_) {
      return null;
    }
  }

  RecordingClip? get previewingClip {
    if (previewingClipId == null) return null;
    try {
      return clips.firstWhere((c) => c.id == previewingClipId);
    } catch (_) {
      return null;
    }
  }

  ClipManagerState copyWith({
    List<RecordingClip>? clips,
    String? selectedClipId,
    String? previewingClipId,
    bool? isReordering,
    bool? isProcessing,
    String? errorMessage,
    bool? muteOriginalAudio,
    bool clearSelection = false,
    bool clearPreview = false,
    bool clearError = false,
  }) {
    return ClipManagerState(
      clips: clips ?? this.clips,
      selectedClipId: clearSelection ? null : (selectedClipId ?? this.selectedClipId),
      previewingClipId: clearPreview ? null : (previewingClipId ?? this.previewingClipId),
      isReordering: isReordering ?? this.isReordering,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      muteOriginalAudio: muteOriginalAudio ?? this.muteOriginalAudio,
    );
  }
}
