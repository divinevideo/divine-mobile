// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

import 'package:openvine/models/text_overlay.dart';

enum ExportStage {
  concatenating,
  applyingTextOverlay,
  mixingAudio,
  generatingThumbnail,
  complete,
  error,
}

class EditorState {
  final List<TextOverlay> textOverlays;
  final String? selectedTextId;
  final String? selectedSoundId;
  final bool isProcessing;
  final ExportStage? exportStage;
  final double exportProgress;
  final String? errorMessage;

  EditorState({
    List<TextOverlay>? textOverlays,
    this.selectedTextId,
    this.selectedSoundId,
    this.isProcessing = false,
    this.exportStage,
    this.exportProgress = 0.0,
    this.errorMessage,
  }) : textOverlays = textOverlays ?? [];

  bool get hasTextOverlays => textOverlays.isNotEmpty;
  bool get hasSound => selectedSoundId != null;
  bool get canExport => !isProcessing;

  EditorState copyWith({
    List<TextOverlay>? textOverlays,
    Object? selectedTextId = _notProvided,
    Object? selectedSoundId = _notProvided,
    bool? isProcessing,
    Object? exportStage = _notProvided,
    double? exportProgress,
    Object? errorMessage = _notProvided,
  }) {
    return EditorState(
      textOverlays: textOverlays ?? this.textOverlays,
      selectedTextId: selectedTextId == _notProvided
          ? this.selectedTextId
          : selectedTextId as String?,
      selectedSoundId: selectedSoundId == _notProvided
          ? this.selectedSoundId
          : selectedSoundId as String?,
      isProcessing: isProcessing ?? this.isProcessing,
      exportStage: exportStage == _notProvided
          ? this.exportStage
          : exportStage as ExportStage?,
      exportProgress: exportProgress ?? this.exportProgress,
      errorMessage: errorMessage == _notProvided
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _notProvided = Object();
