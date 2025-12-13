// ABOUTME: Riverpod provider for managing video editor state with text overlays and export tracking
// ABOUTME: Exposes EditorNotifier for state mutations and reactive EditorState updates

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/editor_state.dart';
import 'package:openvine/models/text_overlay.dart';

final editorProvider = NotifierProvider<EditorNotifier, EditorState>(() {
  return EditorNotifier();
});

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() {
    return EditorState();
  }

  void addTextOverlay(TextOverlay overlay) {
    state = state.copyWith(
      textOverlays: [...state.textOverlays, overlay],
    );
  }

  void updateTextOverlay(String id, TextOverlay overlay) {
    final index = state.textOverlays.indexWhere((o) => o.id == id);
    if (index == -1) return;

    final overlays = [...state.textOverlays];
    overlays[index] = overlay;

    state = state.copyWith(textOverlays: overlays);
  }

  void removeTextOverlay(String id) {
    final overlays = state.textOverlays.where((o) => o.id != id).toList();

    state = state.copyWith(
      textOverlays: overlays,
      selectedTextId: state.selectedTextId == id ? null : state.selectedTextId,
    );
  }

  void selectText(String? id) {
    state = state.copyWith(selectedTextId: id);
  }

  void setSound(String? soundId) {
    state = state.copyWith(selectedSoundId: soundId);
  }

  void setExportStage(ExportStage stage, double progress) {
    final isProcessing = stage != ExportStage.complete && stage != ExportStage.error;

    state = state.copyWith(
      exportStage: stage,
      exportProgress: progress,
      isProcessing: isProcessing,
      errorMessage: null,
    );
  }

  void setError(String? message) {
    state = state.copyWith(
      errorMessage: message,
      exportStage: message != null ? ExportStage.error : state.exportStage,
      isProcessing: false,
    );
  }

  void reset() {
    state = EditorState();
  }
}
