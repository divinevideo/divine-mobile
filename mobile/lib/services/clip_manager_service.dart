// ABOUTME: Service for managing recorded video clips in the Clip Manager
// ABOUTME: Handles add, delete, reorder operations with ChangeNotifier pattern

import 'package:flutter/foundation.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/unified_logger.dart';

class ClipManagerService extends ChangeNotifier {
  final List<RecordingClip> _clips = [];
  int _clipCounter = 0;

  List<RecordingClip> get clips => List.unmodifiable(_clips);

  bool get hasClips => _clips.isNotEmpty;

  int get clipCount => _clips.length;

  Duration get totalDuration {
    return _clips.fold(Duration.zero, (sum, clip) => sum + clip.duration);
  }

  static const Duration maxDuration = Duration(milliseconds: 6300);

  Duration get remainingDuration {
    final remaining = maxDuration - totalDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canRecordMore => remainingDuration > Duration.zero;

  void addClip({
    required String filePath,
    required Duration duration,
    String? thumbnailPath,
  }) {
    final clip = RecordingClip(
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}_${_clipCounter++}',
      filePath: filePath,
      duration: duration,
      orderIndex: _clips.length,
      recordedAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );

    _clips.add(clip);
    Log.info(
      '📎 Added clip: ${clip.id}, duration: ${clip.durationInSeconds}s',
      name: 'ClipManagerService',
    );
    notifyListeners();
  }

  void deleteClip(String clipId) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index == -1) {
      Log.warning(
        '📎 Clip not found for deletion: $clipId',
        name: 'ClipManagerService',
      );
      return;
    }

    _clips.removeAt(index);
    _reindexClips();
    Log.info(
      '📎 Deleted clip: $clipId, remaining: ${_clips.length}',
      name: 'ClipManagerService',
    );
    notifyListeners();
  }

  void reorderClips(List<String> orderedIds) {
    for (var i = 0; i < orderedIds.length; i++) {
      final clipIndex = _clips.indexWhere((c) => c.id == orderedIds[i]);
      if (clipIndex != -1) {
        _clips[clipIndex] = _clips[clipIndex].copyWith(orderIndex: i);
      }
    }
    Log.info(
      '📎 Reordered ${orderedIds.length} clips',
      name: 'ClipManagerService',
    );
    notifyListeners();
  }

  void updateThumbnail(String clipId, String thumbnailPath) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(thumbnailPath: thumbnailPath);
      notifyListeners();
    }
  }

  void clearAll() {
    _clips.clear();
    Log.info('📎 Cleared all clips', name: 'ClipManagerService');
    notifyListeners();
  }

  void _reindexClips() {
    for (var i = 0; i < _clips.length; i++) {
      _clips[i] = _clips[i].copyWith(orderIndex: i);
    }
  }

  List<RecordingClip> get sortedClips {
    final sorted = List<RecordingClip>.from(_clips);
    sorted.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sorted;
  }

  @override
  void dispose() {
    _clips.clear();
    super.dispose();
  }
}
