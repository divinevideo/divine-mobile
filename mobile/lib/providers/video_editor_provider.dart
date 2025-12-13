// ABOUTME: Riverpod provider for managing video editor state including text overlays and sound selection
// ABOUTME: Manages video editing session state, text overlays list, and selected background sound

import 'package:flutter_riverpod/legacy.dart';
import 'package:openvine/models/text_overlay.dart';

final videoEditorProvider = StateNotifierProvider.autoDispose
    .family<VideoEditorNotifier, VideoEditorState, String>(
  (ref, videoPath) => VideoEditorNotifier(videoPath: videoPath),
);

class VideoEditorState {
  final String videoPath;
  final List<TextOverlay> textOverlays;
  final String? selectedSoundId;

  const VideoEditorState({
    required this.videoPath,
    this.textOverlays = const [],
    this.selectedSoundId,
  });

  VideoEditorState copyWith({
    String? videoPath,
    List<TextOverlay>? textOverlays,
    String? selectedSoundId,
    bool clearSound = false,
  }) {
    return VideoEditorState(
      videoPath: videoPath ?? this.videoPath,
      textOverlays: textOverlays ?? this.textOverlays,
      selectedSoundId: clearSound ? null : (selectedSoundId ?? this.selectedSoundId),
    );
  }
}

class VideoEditorNotifier extends StateNotifier<VideoEditorState> {
  VideoEditorNotifier({required String videoPath})
      : super(VideoEditorState(videoPath: videoPath));

  void addTextOverlay(TextOverlay overlay) {
    state = state.copyWith(
      textOverlays: [...state.textOverlays, overlay],
    );
  }

  void updateTextOverlay(String id, TextOverlay updatedOverlay) {
    state = state.copyWith(
      textOverlays: state.textOverlays
          .map((overlay) => overlay.id == id ? updatedOverlay : overlay)
          .toList(),
    );
  }

  void removeTextOverlay(String id) {
    state = state.copyWith(
      textOverlays: state.textOverlays.where((o) => o.id != id).toList(),
    );
  }

  void selectSound(String? soundId) {
    state = state.copyWith(
      selectedSoundId: soundId,
      clearSound: soundId == null,
    );
  }
}
