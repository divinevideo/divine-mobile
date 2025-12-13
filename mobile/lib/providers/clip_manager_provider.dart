// ABOUTME: Riverpod provider for Clip Manager state management
// ABOUTME: Wraps ClipManagerService with reactive state updates

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/services/clip_manager_service.dart';

final clipManagerServiceProvider = Provider<ClipManagerService>((ref) {
  final service = ClipManagerService();
  ref.onDispose(() => service.dispose());
  return service;
});

final clipManagerProvider =
    StateNotifierProvider<ClipManagerNotifier, ClipManagerState>((ref) {
  final service = ref.watch(clipManagerServiceProvider);
  return ClipManagerNotifier(service);
});

class ClipManagerNotifier extends StateNotifier<ClipManagerState> {
  ClipManagerNotifier(this._service) : super(ClipManagerState()) {
    _service.addListener(_updateState);
    _updateState();
  }

  final ClipManagerService _service;

  void _updateState() {
    state = state.copyWith(
      clips: _service.clips,
    );
  }

  void addClip({
    required String filePath,
    required Duration duration,
    String? thumbnailPath,
  }) {
    _service.addClip(
      filePath: filePath,
      duration: duration,
      thumbnailPath: thumbnailPath,
    );
  }

  void deleteClip(String clipId) {
    _service.deleteClip(clipId);
  }

  void reorderClips(List<String> orderedIds) {
    _service.reorderClips(orderedIds);
  }

  void updateThumbnail(String clipId, String thumbnailPath) {
    _service.updateThumbnail(clipId, thumbnailPath);
  }

  void setPreviewingClip(String? clipId) {
    state = state.copyWith(previewingClipId: clipId);
  }

  void clearPreview() {
    state = state.copyWith(clearPreview: true);
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void setError(String? message) {
    state = state.copyWith(errorMessage: message, clearError: message == null);
  }

  void clearAll() {
    _service.clearAll();
    state = ClipManagerState();
  }

  @override
  void dispose() {
    _service.removeListener(_updateState);
    super.dispose();
  }
}
