# Video Editing Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Clip Manager, Sound Picker, and Text Overlay features to diVine's video creation flow.

**Architecture:** Two-screen editing flow (Clip Manager → Editor) inserted between recording and metadata entry. Uses existing Riverpod patterns, FFmpeg for audio mixing/concat, pro_video_editor for text overlay rendering.

**Tech Stack:** Flutter, Riverpod, FFmpeg (ffmpeg_kit_flutter_new), pro_video_editor, just_audio, video_player

---

## Phase 1: Clip Manager

### Task 1.1: Create RecordingClip Model

**Files:**
- Create: `lib/models/recording_clip.dart`
- Test: `test/models/recording_clip_test.dart`

**Step 1: Write the failing test**

```dart
// test/models/recording_clip_test.dart
// ABOUTME: Tests for RecordingClip model - segment data with thumbnail support
// ABOUTME: Validates serialization, ordering, and duration calculations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';

void main() {
  group('RecordingClip', () {
    test('creates clip with required fields', () {
      final clip = RecordingClip(
        id: 'clip_001',
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
        orderIndex: 0,
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
      );

      expect(clip.id, equals('clip_001'));
      expect(clip.filePath, equals('/path/to/video.mp4'));
      expect(clip.duration.inSeconds, equals(2));
      expect(clip.orderIndex, equals(0));
    });

    test('durationInSeconds returns correct value', () {
      final clip = RecordingClip(
        id: 'clip_001',
        filePath: '/path/to/video.mp4',
        duration: const Duration(milliseconds: 2500),
        orderIndex: 0,
        recordedAt: DateTime.now(),
      );

      expect(clip.durationInSeconds, equals(2.5));
    });

    test('copyWith creates new instance with updated fields', () {
      final clip = RecordingClip(
        id: 'clip_001',
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
        orderIndex: 0,
        recordedAt: DateTime.now(),
      );

      final updated = clip.copyWith(orderIndex: 3);

      expect(updated.orderIndex, equals(3));
      expect(updated.id, equals(clip.id));
      expect(updated.filePath, equals(clip.filePath));
    });

    test('toJson and fromJson roundtrip preserves data', () {
      final clip = RecordingClip(
        id: 'clip_001',
        filePath: '/path/to/video.mp4',
        duration: const Duration(milliseconds: 2500),
        orderIndex: 1,
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final json = clip.toJson();
      final restored = RecordingClip.fromJson(json);

      expect(restored.id, equals(clip.id));
      expect(restored.filePath, equals(clip.filePath));
      expect(restored.duration, equals(clip.duration));
      expect(restored.orderIndex, equals(clip.orderIndex));
      expect(restored.thumbnailPath, equals(clip.thumbnailPath));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/models/recording_clip_test.dart`
Expected: FAIL - "Target of URI doesn't exist: 'package:openvine/models/recording_clip.dart'"

**Step 3: Write minimal implementation**

```dart
// lib/models/recording_clip.dart
// ABOUTME: Data model for a recorded video segment in the Clip Manager
// ABOUTME: Supports ordering, thumbnails, and JSON serialization for persistence

import 'dart:convert';

class RecordingClip {
  RecordingClip({
    required this.id,
    required this.filePath,
    required this.duration,
    required this.orderIndex,
    required this.recordedAt,
    this.thumbnailPath,
  });

  final String id;
  final String filePath;
  final Duration duration;
  final int orderIndex;
  final DateTime recordedAt;
  final String? thumbnailPath;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  RecordingClip copyWith({
    String? id,
    String? filePath,
    Duration? duration,
    int? orderIndex,
    DateTime? recordedAt,
    String? thumbnailPath,
  }) {
    return RecordingClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      orderIndex: orderIndex ?? this.orderIndex,
      recordedAt: recordedAt ?? this.recordedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'durationMs': duration.inMilliseconds,
      'orderIndex': orderIndex,
      'recordedAt': recordedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
    };
  }

  factory RecordingClip.fromJson(Map<String, dynamic> json) {
    return RecordingClip(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      orderIndex: json['orderIndex'] as int,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  @override
  String toString() {
    return 'RecordingClip(id: $id, duration: ${durationInSeconds}s, order: $orderIndex)';
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/models/recording_clip_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/models/recording_clip.dart test/models/recording_clip_test.dart
git commit -m "feat(clip-manager): add RecordingClip model with tests"
```

---

### Task 1.2: Create ClipManagerState Model

**Files:**
- Create: `lib/models/clip_manager_state.dart`
- Test: `test/models/clip_manager_state_test.dart`

**Step 1: Write the failing test**

```dart
// test/models/clip_manager_state_test.dart
// ABOUTME: Tests for ClipManagerState - UI state for clip management screen
// ABOUTME: Validates duration calculations and clip operations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/clip_manager_state.dart';

void main() {
  group('ClipManagerState', () {
    final clip1 = RecordingClip(
      id: 'clip_001',
      filePath: '/path/to/video1.mp4',
      duration: const Duration(seconds: 2),
      orderIndex: 0,
      recordedAt: DateTime.now(),
    );

    final clip2 = RecordingClip(
      id: 'clip_002',
      filePath: '/path/to/video2.mp4',
      duration: const Duration(milliseconds: 1500),
      orderIndex: 1,
      recordedAt: DateTime.now(),
    );

    test('totalDuration sums all clip durations', () {
      final state = ClipManagerState(clips: [clip1, clip2]);

      expect(state.totalDuration, equals(const Duration(milliseconds: 3500)));
    });

    test('remainingDuration calculates correctly', () {
      final state = ClipManagerState(clips: [clip1, clip2]);

      // Max is 6.3 seconds = 6300ms, used is 3500ms, remaining is 2800ms
      expect(state.remainingDuration, equals(const Duration(milliseconds: 2800)));
    });

    test('canRecordMore is true when under limit', () {
      final state = ClipManagerState(clips: [clip1]);

      expect(state.canRecordMore, isTrue);
    });

    test('canRecordMore is false when at limit', () {
      final fullClip = RecordingClip(
        id: 'clip_full',
        filePath: '/path/to/video.mp4',
        duration: const Duration(milliseconds: 6300),
        orderIndex: 0,
        recordedAt: DateTime.now(),
      );
      final state = ClipManagerState(clips: [fullClip]);

      expect(state.canRecordMore, isFalse);
    });

    test('hasClips returns correct value', () {
      expect(ClipManagerState(clips: []).hasClips, isFalse);
      expect(ClipManagerState(clips: [clip1]).hasClips, isTrue);
    });

    test('sortedClips returns clips by orderIndex', () {
      final state = ClipManagerState(clips: [clip2, clip1]);

      final sorted = state.sortedClips;
      expect(sorted[0].id, equals('clip_001'));
      expect(sorted[1].id, equals('clip_002'));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/models/clip_manager_state_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/models/clip_manager_state.dart
// ABOUTME: UI state model for the Clip Manager screen
// ABOUTME: Tracks clips, selection state, and duration calculations

import 'package:openvine/models/recording_clip.dart';

class ClipManagerState {
  ClipManagerState({
    this.clips = const [],
    this.previewingClipId,
    this.isReordering = false,
    this.isProcessing = false,
    this.errorMessage,
  });

  final List<RecordingClip> clips;
  final String? previewingClipId;
  final bool isReordering;
  final bool isProcessing;
  final String? errorMessage;

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
    String? previewingClipId,
    bool? isReordering,
    bool? isProcessing,
    String? errorMessage,
    bool clearPreview = false,
    bool clearError = false,
  }) {
    return ClipManagerState(
      clips: clips ?? this.clips,
      previewingClipId: clearPreview ? null : (previewingClipId ?? this.previewingClipId),
      isReordering: isReordering ?? this.isReordering,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/models/clip_manager_state_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/models/clip_manager_state.dart test/models/clip_manager_state_test.dart
git commit -m "feat(clip-manager): add ClipManagerState model with tests"
```

---

### Task 1.3: Create ClipManagerService

**Files:**
- Create: `lib/services/clip_manager_service.dart`
- Test: `test/services/clip_manager_service_test.dart`

**Step 1: Write the failing test**

```dart
// test/services/clip_manager_service_test.dart
// ABOUTME: Tests for ClipManagerService - business logic for clip operations
// ABOUTME: Validates add, delete, reorder, and thumbnail generation

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/services/clip_manager_service.dart';

void main() {
  group('ClipManagerService', () {
    late ClipManagerService service;

    setUp(() {
      service = ClipManagerService();
    });

    tearDown(() {
      service.dispose();
    });

    test('starts with empty clips', () {
      expect(service.clips, isEmpty);
      expect(service.hasClips, isFalse);
    });

    test('addClip adds clip and notifies', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.addClip(
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
      );

      expect(service.clips.length, equals(1));
      expect(service.clips[0].filePath, equals('/path/to/video.mp4'));
      expect(notified, isTrue);
    });

    test('deleteClip removes clip by id', () {
      service.addClip(
        filePath: '/path/to/video1.mp4',
        duration: const Duration(seconds: 2),
      );
      service.addClip(
        filePath: '/path/to/video2.mp4',
        duration: const Duration(seconds: 1),
      );

      final clipToDelete = service.clips[0].id;
      service.deleteClip(clipToDelete);

      expect(service.clips.length, equals(1));
      expect(service.clips[0].filePath, equals('/path/to/video2.mp4'));
    });

    test('reorderClips updates orderIndex values', () {
      service.addClip(filePath: '/path/1.mp4', duration: const Duration(seconds: 1));
      service.addClip(filePath: '/path/2.mp4', duration: const Duration(seconds: 1));
      service.addClip(filePath: '/path/3.mp4', duration: const Duration(seconds: 1));

      final ids = service.clips.map((c) => c.id).toList();
      // Reverse the order
      service.reorderClips([ids[2], ids[1], ids[0]]);

      expect(service.clips[0].orderIndex, equals(2));
      expect(service.clips[2].orderIndex, equals(0));
    });

    test('totalDuration sums all clips', () {
      service.addClip(filePath: '/path/1.mp4', duration: const Duration(seconds: 2));
      service.addClip(filePath: '/path/2.mp4', duration: const Duration(milliseconds: 1500));

      expect(service.totalDuration, equals(const Duration(milliseconds: 3500)));
    });

    test('clearAll removes all clips', () {
      service.addClip(filePath: '/path/1.mp4', duration: const Duration(seconds: 1));
      service.addClip(filePath: '/path/2.mp4', duration: const Duration(seconds: 1));

      service.clearAll();

      expect(service.clips, isEmpty);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/services/clip_manager_service_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/services/clip_manager_service.dart
// ABOUTME: Service for managing recorded video clips in the Clip Manager
// ABOUTME: Handles add, delete, reorder operations with ChangeNotifier pattern

import 'package:flutter/foundation.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/unified_logger.dart';

class ClipManagerService extends ChangeNotifier {
  final List<RecordingClip> _clips = [];

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
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}',
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
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/services/clip_manager_service_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/services/clip_manager_service.dart test/services/clip_manager_service_test.dart
git commit -m "feat(clip-manager): add ClipManagerService with tests"
```

---

### Task 1.4: Create ClipManagerProvider (Riverpod)

**Files:**
- Create: `lib/providers/clip_manager_provider.dart`
- Test: `test/providers/clip_manager_provider_test.dart`

**Step 1: Write the failing test**

```dart
// test/providers/clip_manager_provider_test.dart
// ABOUTME: Tests for ClipManagerProvider - Riverpod state management
// ABOUTME: Validates state updates and provider lifecycle

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/models/clip_manager_state.dart';

void main() {
  group('ClipManagerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no clips', () {
      final state = container.read(clipManagerProvider);

      expect(state.clips, isEmpty);
      expect(state.hasClips, isFalse);
    });

    test('addClip updates state with new clip', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
      );

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
      expect(state.totalDuration, equals(const Duration(seconds: 2)));
    });

    test('deleteClip removes clip from state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        filePath: '/path/to/video1.mp4',
        duration: const Duration(seconds: 2),
      );
      notifier.addClip(
        filePath: '/path/to/video2.mp4',
        duration: const Duration(seconds: 1),
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.deleteClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test('setPreviewingClip updates preview state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.setPreviewingClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.previewingClipId, equals(clipId));
    });

    test('clearPreview removes preview state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.setPreviewingClip(clipId);
      notifier.clearPreview();

      final state = container.read(clipManagerProvider);
      expect(state.previewingClipId, isNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/providers/clip_manager_provider_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/providers/clip_manager_provider.dart
// ABOUTME: Riverpod provider for Clip Manager state management
// ABOUTME: Wraps ClipManagerService with reactive state updates

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
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
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/providers/clip_manager_provider_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/providers/clip_manager_provider.dart test/providers/clip_manager_provider_test.dart
git commit -m "feat(clip-manager): add ClipManagerProvider with Riverpod"
```

---

### Task 1.5: Create SegmentThumbnailWidget

**Files:**
- Create: `lib/widgets/clip_manager/segment_thumbnail.dart`
- Test: `test/widgets/segment_thumbnail_test.dart`

**Step 1: Write the failing test**

```dart
// test/widgets/segment_thumbnail_test.dart
// ABOUTME: Widget tests for SegmentThumbnail - clip grid item display
// ABOUTME: Validates thumbnail display, duration badge, delete button

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/widgets/clip_manager/segment_thumbnail.dart';

void main() {
  group('SegmentThumbnail', () {
    final testClip = RecordingClip(
      id: 'clip_001',
      filePath: '/path/to/video.mp4',
      duration: const Duration(milliseconds: 2500),
      orderIndex: 0,
      recordedAt: DateTime.now(),
    );

    testWidgets('displays duration badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentThumbnail(
              clip: testClip,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('2.5s'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentThumbnail(
              clip: testClip,
              onTap: () => tapped = true,
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SegmentThumbnail));
      expect(tapped, isTrue);
    });

    testWidgets('calls onDelete when delete button tapped', (tester) async {
      var deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentThumbnail(
              clip: testClip,
              onTap: () {},
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(deleted, isTrue);
    });

    testWidgets('shows play icon overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentThumbnail(
              clip: testClip,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/widgets/segment_thumbnail_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/widgets/clip_manager/segment_thumbnail.dart
// ABOUTME: Thumbnail widget for a single clip in the Clip Manager grid
// ABOUTME: Shows thumbnail image, duration badge, delete button, play icon

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';

class SegmentThumbnail extends StatelessWidget {
  const SegmentThumbnail({
    super.key,
    required this.clip,
    required this.onTap,
    required this.onDelete,
    this.isSelected = false,
  });

  final RecordingClip clip;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildThumbnail(),
            ),

            // Play icon overlay
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 40,
              ),
            ),

            // Duration badge
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${clip.durationInSeconds.toStringAsFixed(1)}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Delete button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (clip.thumbnailPath != null && File(clip.thumbnailPath!).existsSync()) {
      return Image.file(
        File(clip.thumbnailPath!),
        fit: BoxFit.cover,
      );
    }

    // Placeholder when no thumbnail
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.videocam,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/widgets/segment_thumbnail_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/widgets/clip_manager/segment_thumbnail.dart test/widgets/segment_thumbnail_test.dart
git commit -m "feat(clip-manager): add SegmentThumbnail widget"
```

---

### Task 1.6: Create SegmentPreviewModal

**Files:**
- Create: `lib/widgets/clip_manager/segment_preview_modal.dart`
- Test: `test/widgets/segment_preview_modal_test.dart`

**Step 1: Write the failing test**

```dart
// test/widgets/segment_preview_modal_test.dart
// ABOUTME: Widget tests for SegmentPreviewModal - video playback overlay
// ABOUTME: Validates video player display and close behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/widgets/clip_manager/segment_preview_modal.dart';

void main() {
  group('SegmentPreviewModal', () {
    final testClip = RecordingClip(
      id: 'clip_001',
      filePath: '/path/to/video.mp4',
      duration: const Duration(seconds: 2),
      orderIndex: 0,
      recordedAt: DateTime.now(),
    );

    testWidgets('displays close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentPreviewModal(
              clip: testClip,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onClose when close button tapped', (tester) async {
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentPreviewModal(
              clip: testClip,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });

    testWidgets('displays duration info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentPreviewModal(
              clip: testClip,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('2'), findsWidgets);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/widgets/segment_preview_modal_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/widgets/clip_manager/segment_preview_modal.dart
// ABOUTME: Modal overlay for previewing a single clip with looping playback
// ABOUTME: Uses video_player for playback, dark overlay background

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/unified_logger.dart';

class SegmentPreviewModal extends StatefulWidget {
  const SegmentPreviewModal({
    super.key,
    required this.clip,
    required this.onClose,
  });

  final RecordingClip clip;
  final VoidCallback onClose;

  @override
  State<SegmentPreviewModal> createState() => _SegmentPreviewModalState();
}

class _SegmentPreviewModalState extends State<SegmentPreviewModal> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = File(widget.clip.filePath);
      if (!file.existsSync()) {
        setState(() {
          _errorMessage = 'Video file not found';
        });
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      Log.error(
        'Failed to initialize video preview: $e',
        name: 'SegmentPreviewModal',
      );
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load video';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black87,
        child: Stack(
          children: [
            // Video player
            Center(
              child: _buildVideoPlayer(),
            ),

            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),

            // Duration indicator
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.clip.durationInSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/widgets/segment_preview_modal_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/widgets/clip_manager/segment_preview_modal.dart test/widgets/segment_preview_modal_test.dart
git commit -m "feat(clip-manager): add SegmentPreviewModal widget"
```

---

### Task 1.7: Create ClipManagerScreen

**Files:**
- Create: `lib/screens/clip_manager_screen.dart`
- Test: `test/screens/clip_manager_screen_test.dart`

**Step 1: Write the failing test**

```dart
// test/screens/clip_manager_screen_test.dart
// ABOUTME: Widget tests for ClipManagerScreen - main clip management UI
// ABOUTME: Validates grid display, navigation, and user interactions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/clip_manager_screen.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

void main() {
  group('ClipManagerScreen', () {
    testWidgets('shows empty state when no clips', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClipManagerScreen(),
          ),
        ),
      );

      expect(find.text('No clips'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
    });

    testWidgets('shows header with duration', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClipManagerScreen(),
          ),
        ),
      );

      expect(find.textContaining('0.0s'), findsOneWidget);
      expect(find.textContaining('6.3s'), findsOneWidget);
    });

    testWidgets('shows Next button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClipManagerScreen(),
          ),
        ),
      );

      expect(find.text('Next'), findsOneWidget);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/screens/clip_manager_screen_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/screens/clip_manager_screen.dart
// ABOUTME: Main screen for managing recorded video clips before editing
// ABOUTME: Displays thumbnail grid with reorder, delete, and preview functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/clip_manager/segment_thumbnail.dart';
import 'package:openvine/widgets/clip_manager/segment_preview_modal.dart';

class ClipManagerScreen extends ConsumerStatefulWidget {
  const ClipManagerScreen({
    super.key,
    this.onRecordMore,
    this.onNext,
    this.onDiscard,
  });

  final VoidCallback? onRecordMore;
  final VoidCallback? onNext;
  final VoidCallback? onDiscard;

  @override
  ConsumerState<ClipManagerScreen> createState() => _ClipManagerScreenState();
}

class _ClipManagerScreenState extends ConsumerState<ClipManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clipManagerProvider);
    final notifier = ref.read(clipManagerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onDiscard ?? () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${state.totalDuration.inMilliseconds / 1000}s / 6.3s',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: state.hasClips ? (widget.onNext ?? () {}) : null,
            child: Text(
              'Next',
              style: TextStyle(
                color: state.hasClips ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              Expanded(
                child: state.hasClips
                    ? _buildClipGrid(state, notifier)
                    : _buildEmptyState(),
              ),

              // Record more button
              if (state.canRecordMore) _buildRecordMoreButton(state),

              const SizedBox(height: 16),
            ],
          ),

          // Preview modal
          if (state.previewingClip != null)
            SegmentPreviewModal(
              clip: state.previewingClip!,
              onClose: () => notifier.clearPreview(),
            ),
        ],
      ),
    );
  }

  Widget _buildClipGrid(dynamic state, ClipManagerNotifier notifier) {
    final clips = state.sortedClips as List<RecordingClip>;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ReorderableGridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 9 / 16,
        ),
        itemCount: clips.length,
        itemBuilder: (context, index) {
          final clip = clips[index];
          return ReorderableGridDragStartListener(
            key: ValueKey(clip.id),
            index: index,
            child: SegmentThumbnail(
              clip: clip,
              onTap: () => notifier.setPreviewingClip(clip.id),
              onDelete: () => _confirmDelete(clip, notifier),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          final clips = state.sortedClips as List<RecordingClip>;
          final ids = clips.map((c) => c.id).toList();
          final item = ids.removeAt(oldIndex);
          if (newIndex > oldIndex) newIndex--;
          ids.insert(newIndex, item);
          notifier.reorderClips(ids);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off,
            color: Colors.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No clips',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: widget.onRecordMore,
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordMoreButton(dynamic state) {
    final remaining = state.remainingDuration as Duration;
    final seconds = remaining.inMilliseconds / 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white30),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: widget.onRecordMore,
          icon: const Icon(Icons.add),
          label: Text('Record (${seconds.toStringAsFixed(1)}s left)'),
        ),
      ),
    );
  }

  void _confirmDelete(RecordingClip clip, ClipManagerNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete clip?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteClip(clip.id);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple ReorderableGridView implementation
class ReorderableGridView extends StatelessWidget {
  const ReorderableGridView.builder({
    super.key,
    required this.gridDelegate,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
  });

  final SliverGridDelegate gridDelegate;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final void Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      onReorder: onReorder,
    );
  }
}

class ReorderableGridDragStartListener extends StatelessWidget {
  const ReorderableGridDragStartListener({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: child,
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/screens/clip_manager_screen_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/screens/clip_manager_screen.dart test/screens/clip_manager_screen_test.dart
git commit -m "feat(clip-manager): add ClipManagerScreen with grid UI"
```

---

## Phase 2: Sound Picker

### Task 2.1: Add just_audio dependency

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add dependency**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter pub add just_audio`

**Step 2: Verify installation**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter pub get`
Expected: SUCCESS

**Step 3: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add pubspec.yaml pubspec.lock
git commit -m "chore: add just_audio dependency for sound preview"
```

---

### Task 2.2: Create VineSound Model

**Files:**
- Create: `lib/models/vine_sound.dart`
- Test: `test/models/vine_sound_test.dart`

**Step 1: Write the failing test**

```dart
// test/models/vine_sound_test.dart
// ABOUTME: Tests for VineSound model - audio track metadata
// ABOUTME: Validates JSON serialization and property access

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_sound.dart';

void main() {
  group('VineSound', () {
    test('creates sound with required fields', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Classic Vine Sound',
        assetPath: 'assets/sounds/classic_001.mp3',
        duration: const Duration(seconds: 6),
      );

      expect(sound.id, equals('sound_001'));
      expect(sound.title, equals('Classic Vine Sound'));
      expect(sound.assetPath, equals('assets/sounds/classic_001.mp3'));
    });

    test('creates sound with optional fields', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Classic Vine Sound',
        assetPath: 'assets/sounds/classic_001.mp3',
        duration: const Duration(seconds: 6),
        artist: 'Unknown Artist',
        tags: ['meme', 'classic', 'funny'],
      );

      expect(sound.artist, equals('Unknown Artist'));
      expect(sound.tags, contains('meme'));
    });

    test('fromJson creates valid sound', () {
      final json = {
        'id': 'sound_001',
        'title': 'Test Sound',
        'assetPath': 'assets/sounds/test.mp3',
        'durationMs': 6000,
        'artist': 'Test Artist',
        'tags': ['test', 'demo'],
      };

      final sound = VineSound.fromJson(json);

      expect(sound.id, equals('sound_001'));
      expect(sound.title, equals('Test Sound'));
      expect(sound.artist, equals('Test Artist'));
      expect(sound.duration.inSeconds, equals(6));
    });

    test('toJson roundtrip preserves data', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Classic Vine Sound',
        assetPath: 'assets/sounds/classic_001.mp3',
        duration: const Duration(seconds: 6),
        artist: 'Artist Name',
        tags: ['tag1', 'tag2'],
      );

      final json = sound.toJson();
      final restored = VineSound.fromJson(json);

      expect(restored.id, equals(sound.id));
      expect(restored.title, equals(sound.title));
      expect(restored.artist, equals(sound.artist));
      expect(restored.tags, equals(sound.tags));
    });

    test('matchesSearch finds by title', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'What Are Those',
        assetPath: 'assets/sounds/what_are_those.mp3',
        duration: const Duration(seconds: 3),
        tags: ['meme', 'shoes'],
      );

      expect(sound.matchesSearch('what'), isTrue);
      expect(sound.matchesSearch('those'), isTrue);
      expect(sound.matchesSearch('WHAT'), isTrue); // case insensitive
      expect(sound.matchesSearch('xyz'), isFalse);
    });

    test('matchesSearch finds by tag', () {
      final sound = VineSound(
        id: 'sound_001',
        title: 'Some Sound',
        assetPath: 'assets/sounds/some.mp3',
        duration: const Duration(seconds: 3),
        tags: ['meme', 'funny'],
      );

      expect(sound.matchesSearch('meme'), isTrue);
      expect(sound.matchesSearch('funny'), isTrue);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/models/vine_sound_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/models/vine_sound.dart
// ABOUTME: Data model for classic Vine audio tracks in the Sound Picker
// ABOUTME: Supports metadata, tags for search, and JSON serialization

class VineSound {
  VineSound({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.duration,
    this.artist,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String assetPath;
  final Duration duration;
  final String? artist;
  final List<String> tags;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();

    if (title.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    if (artist != null && artist!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    for (final tag in tags) {
      if (tag.toLowerCase().contains(lowerQuery)) {
        return true;
      }
    }

    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'assetPath': assetPath,
      'durationMs': duration.inMilliseconds,
      'artist': artist,
      'tags': tags,
    };
  }

  factory VineSound.fromJson(Map<String, dynamic> json) {
    return VineSound(
      id: json['id'] as String,
      title: json['title'] as String,
      assetPath: json['assetPath'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      artist: json['artist'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  @override
  String toString() {
    return 'VineSound(id: $id, title: $title)';
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/models/vine_sound_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/models/vine_sound.dart test/models/vine_sound_test.dart
git commit -m "feat(sound-picker): add VineSound model with search support"
```

---

### Task 2.3: Create SoundLibraryService

**Files:**
- Create: `lib/services/sound_library_service.dart`
- Test: `test/services/sound_library_service_test.dart`

**Step 1: Write the failing test**

```dart
// test/services/sound_library_service_test.dart
// ABOUTME: Tests for SoundLibraryService - loads and searches bundled sounds
// ABOUTME: Validates manifest loading and search functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/services/sound_library_service.dart';

void main() {
  group('SoundLibraryService', () {
    test('parseManifest creates sounds from JSON', () {
      final manifestJson = '''
      {
        "sounds": [
          {
            "id": "sound_001",
            "title": "What Are Those",
            "assetPath": "assets/sounds/what_are_those.mp3",
            "durationMs": 3000,
            "tags": ["meme", "shoes"]
          },
          {
            "id": "sound_002",
            "title": "Road Work Ahead",
            "assetPath": "assets/sounds/road_work.mp3",
            "durationMs": 4000,
            "artist": "Drew Gooden",
            "tags": ["meme", "driving"]
          }
        ]
      }
      ''';

      final sounds = SoundLibraryService.parseManifest(manifestJson);

      expect(sounds.length, equals(2));
      expect(sounds[0].title, equals('What Are Those'));
      expect(sounds[1].artist, equals('Drew Gooden'));
    });

    test('searchSounds filters by query', () {
      final sounds = [
        VineSound(
          id: 'sound_001',
          title: 'What Are Those',
          assetPath: 'assets/sounds/what.mp3',
          duration: const Duration(seconds: 3),
          tags: ['shoes'],
        ),
        VineSound(
          id: 'sound_002',
          title: 'Road Work Ahead',
          assetPath: 'assets/sounds/road.mp3',
          duration: const Duration(seconds: 4),
          tags: ['driving'],
        ),
      ];

      final results = SoundLibraryService.searchSounds(sounds, 'road');

      expect(results.length, equals(1));
      expect(results[0].id, equals('sound_002'));
    });

    test('searchSounds returns all when query empty', () {
      final sounds = [
        VineSound(
          id: 'sound_001',
          title: 'Sound 1',
          assetPath: 'assets/sounds/1.mp3',
          duration: const Duration(seconds: 3),
        ),
        VineSound(
          id: 'sound_002',
          title: 'Sound 2',
          assetPath: 'assets/sounds/2.mp3',
          duration: const Duration(seconds: 4),
        ),
      ];

      final results = SoundLibraryService.searchSounds(sounds, '');

      expect(results.length, equals(2));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/services/sound_library_service_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/services/sound_library_service.dart
// ABOUTME: Service for loading and searching bundled Vine sounds from assets
// ABOUTME: Parses manifest JSON and provides search functionality

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/utils/unified_logger.dart';

class SoundLibraryService {
  static const String _manifestPath = 'assets/sounds/sounds_manifest.json';

  List<VineSound> _sounds = [];
  bool _isLoaded = false;

  List<VineSound> get sounds => List.unmodifiable(_sounds);
  bool get isLoaded => _isLoaded;

  Future<void> loadSounds() async {
    if (_isLoaded) return;

    try {
      final manifestJson = await rootBundle.loadString(_manifestPath);
      _sounds = parseManifest(manifestJson);
      _isLoaded = true;
      Log.info(
        '🔊 Loaded ${_sounds.length} sounds from manifest',
        name: 'SoundLibraryService',
      );
    } catch (e) {
      Log.error(
        '🔊 Failed to load sounds manifest: $e',
        name: 'SoundLibraryService',
      );
      _sounds = [];
      _isLoaded = true; // Mark as loaded even on error to prevent retries
    }
  }

  static List<VineSound> parseManifest(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final soundsJson = json['sounds'] as List<dynamic>;

    return soundsJson
        .map((s) => VineSound.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  List<VineSound> search(String query) {
    return searchSounds(_sounds, query);
  }

  static List<VineSound> searchSounds(List<VineSound> sounds, String query) {
    if (query.trim().isEmpty) {
      return sounds;
    }

    return sounds.where((sound) => sound.matchesSearch(query)).toList();
  }

  VineSound? getSoundById(String id) {
    try {
      return _sounds.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/services/sound_library_service_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
git add lib/services/sound_library_service.dart test/services/sound_library_service_test.dart
git commit -m "feat(sound-picker): add SoundLibraryService for asset loading"
```

---

## Phase 3: Remaining Tasks (Summary)

The following tasks follow the same TDD pattern. Each needs test file + implementation:

### Sound Picker (continued)
- **Task 2.4:** Create SoundPickerProvider (Riverpod)
- **Task 2.5:** Create SoundListItem widget
- **Task 2.6:** Create SoundPickerModal screen
- **Task 2.7:** Create SoundPreviewPlayer service (just_audio)
- **Task 2.8:** Create sample sounds_manifest.json and placeholder sounds

### Text Overlay
- **Task 3.1:** Add pro_video_editor dependency
- **Task 3.2:** Create TextOverlay model
- **Task 3.3:** Create TextOverlayEditor widget (input modal)
- **Task 3.4:** Create DraggableTextOverlay widget (positioning)
- **Task 3.5:** Create TextOverlayRenderer service (Flutter canvas → PNG)

### Editor Screen
- **Task 4.1:** Create EditorState model
- **Task 4.2:** Create EditorProvider (Riverpod)
- **Task 4.3:** Create VideoEditorScreen (main editor UI)
- **Task 4.4:** Integrate text overlay preview
- **Task 4.5:** Integrate sound picker button

### Export Pipeline
- **Task 5.1:** Create VideoExportService
- **Task 5.2:** Implement segment concatenation (FFmpeg)
- **Task 5.3:** Implement text overlay rendering (pro_video_editor)
- **Task 5.4:** Implement audio mixing (FFmpeg)
- **Task 5.5:** Create ExportProgressWidget
- **Task 5.6:** Wire export to VineDraft creation

### Integration
- **Task 6.1:** Update camera screen navigation to ClipManager
- **Task 6.2:** Wire ClipManager → Editor → Metadata flow
- **Task 6.3:** Integration tests for full flow

---

## Execution Notes

**Run all tests before each commit:**
```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test
```

**Run analyzer after changes:**
```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter analyze
```

**Current branch:** `feature/video-editing-tools`

**Key files to reference:**
- Existing provider pattern: `lib/providers/vine_recording_provider.dart`
- Existing service pattern: `lib/services/vine_recording_controller.dart`
- Theme colors: `lib/theme/vine_theme.dart`
- Logging: `lib/utils/unified_logger.dart`
