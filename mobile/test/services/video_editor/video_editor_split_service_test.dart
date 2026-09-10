import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  MockPathProviderPlatform({required this.documentsPath});

  final String documentsPath;

  @override
  Future<String?> getApplicationCachePath() async {
    return '/cache';
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return documentsPath;
  }
}

class MockProVideoEditor extends ProVideoEditor {
  /// Records any native split request. A trim-based split must never issue
  /// one, so this stays empty — a non-empty list means a re-encode regressed.
  final List<SplitVideoModel> splitRequests = [];

  @override
  Stream<dynamic> initializeStream() {
    return const Stream.empty();
  }

  @override
  Future<List<String>> splitVideo(
    SplitVideoModel value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    splitRequests.add(value);
    return [value.startOutputPath, value.endOutputPath];
  }
}

DivineVideoClip _clip({
  required Duration duration,
  String id = 'test-clip',
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  ClipTransition? transition,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/test/video.mp4'),
    duration: duration,
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 9 / 16,
    trimStart: trimStart,
    trimEnd: trimEnd,
    transition: transition,
  );
}

void main() {
  late MockProVideoEditor mockProVideoEditor;
  late PathProviderPlatform originalPathProviderInstance;
  late ProVideoEditor originalProVideoEditorInstance;
  late Directory tempDir;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync(
      'openvine_split_service_test_',
    );
    originalPathProviderInstance = PathProviderPlatform.instance;
    PathProviderPlatform.instance = MockPathProviderPlatform(
      documentsPath: '${tempDir.path}/documents',
    );
    originalProVideoEditorInstance = ProVideoEditor.instance;
    mockProVideoEditor = MockProVideoEditor();
    ProVideoEditor.instance = mockProVideoEditor;
    mockProVideoEditor.splitRequests.clear();
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProviderInstance;
    ProVideoEditor.instance = originalProVideoEditorInstance;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('VideoEditorSplitService', () {
    group('isValidSplitPosition', () {
      test('returns true for valid split position', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        // Split at 2.5s - both clips will be 2.5s
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 2500),
          ),
          isTrue,
        );
      });

      test('returns false when start clip is too short', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        // Split at 20ms - start clip too short (min 30ms)
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 20),
          ),
          isFalse,
        );
      });

      test('returns false when end clip is too short', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        // Split at 980ms - end clip only 20ms (min 30ms)
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 980),
          ),
          isFalse,
        );
      });

      test('returns true for minimum valid durations', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(milliseconds: 60),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        // Split exactly at 30ms - both clips exactly minimum
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 30),
          ),
          isTrue,
        );
      });

      test('validates against trimmedDuration for trimmed clips', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
          trimStart: const Duration(seconds: 3),
          trimEnd: const Duration(seconds: 2),
        );

        // trimmedDuration = 10 - 3 - 2 = 5s
        // Split at 4.98s — end clip would only be 20ms (< 30ms min)
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 4980),
          ),
          isFalse,
        );

        // Split at 2.5s — both clips are 2.5s
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 2500),
          ),
          isTrue,
        );
      });
    });

    group('splitClip', () {
      test('throws ArgumentError for invalid split position', () async {
        final clip = _clip(duration: const Duration(seconds: 1));
        expect(
          () => VideoEditorSplitService.splitClip(
            sourceClip: clip,
            splitPosition: const Duration(milliseconds: 10),
            onClipsCreated: null,
            onThumbnailExtracted: null,
          ),
          throwsArgumentError,
        );
      });

      test(
        'creates two halves that share the source video (no re-encode)',
        () async {
          final clip = _clip(duration: const Duration(seconds: 5));
          DivineVideoClip? start;
          DivineVideoClip? end;
          await VideoEditorSplitService.splitClip(
            sourceClip: clip,
            splitPosition: const Duration(seconds: 2),
            onClipsCreated: (s, e) {
              start = s;
              end = e;
            },
            onThumbnailExtracted: null,
          );

          // Nothing is re-encoded; both halves keep the source file.
          expect(mockProVideoEditor.splitRequests, isEmpty);
          expect(start!.video?.file?.path, clip.video?.file?.path);
          expect(end!.video?.file?.path, clip.video?.file?.path);
        },
      );

      test('start half is capped at the split; end half starts at it', () async {
        final clip = _clip(duration: const Duration(seconds: 5));
        DivineVideoClip? start;
        DivineVideoClip? end;
        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (s, e) {
            start = s;
            end = e;
          },
          onThumbnailExtracted: null,
        );

        // Start half: [0, 2s], its duration caps the visible end at the split.
        expect(start!.duration, const Duration(seconds: 2));
        expect(start!.trimEnd, Duration.zero);
        expect(start!.trimmedDuration, const Duration(seconds: 2));
        // End half: [2s, 5s] on the full-length source.
        expect(end!.duration, const Duration(seconds: 5));
        expect(end!.trimStart, const Duration(seconds: 2));
        expect(end!.trimmedDuration, const Duration(seconds: 3));
      });

      test('end half carries a source floor at the split point', () async {
        final clip = _clip(duration: const Duration(seconds: 5));
        DivineVideoClip? end;
        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (_, e) => end = e,
          onThumbnailExtracted: null,
        );

        // So its left trim handle can't be dragged back before the split into
        // the start half's frames.
        expect(end!.minTrimStart, const Duration(seconds: 2));
      });

      test('splits a trimmed clip at the correct absolute position', () async {
        // 10s clip trimmed to 3s–8s (trimmedDuration = 5s), split 2s in.
        final clip = _clip(
          duration: const Duration(seconds: 10),
          trimStart: const Duration(seconds: 3),
          trimEnd: const Duration(seconds: 2),
        );
        DivineVideoClip? start;
        DivineVideoClip? end;
        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (s, e) {
            start = s;
            end = e;
          },
          onThumbnailExtracted: null,
        );

        // Absolute split = trimStart(3) + 2 = 5s.
        expect(start!.duration, const Duration(seconds: 5));
        expect(start!.trimStart, const Duration(seconds: 3));
        expect(start!.trimEnd, Duration.zero);
        expect(start!.trimmedDuration, const Duration(seconds: 2));
        expect(end!.duration, const Duration(seconds: 10));
        expect(end!.trimStart, const Duration(seconds: 5));
        expect(end!.trimEnd, const Duration(seconds: 2));
        expect(end!.minTrimStart, const Duration(seconds: 5));
        expect(end!.trimmedDuration, const Duration(seconds: 3));
        // Total trimmed duration preserved: 2 + 3 = 5s.
        expect(
          start!.trimmedDuration + end!.trimmedDuration,
          clip.trimmedDuration,
        );
      });

      test('start half drops the transition; end half keeps it', () async {
        const dissolve = ClipTransition(type: ClipTransitionType.dissolve);
        final clip = _clip(
          duration: const Duration(seconds: 5),
          transition: dissolve,
        );
        DivineVideoClip? start;
        DivineVideoClip? end;
        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (s, e) {
            start = s;
            end = e;
          },
          onThumbnailExtracted: null,
        );

        // The split point (A1 → A2) is a hard cut; A2 → B keeps the boundary.
        expect(start!.transition, isNull);
        expect(end!.transition, equals(dissolve));
      });

      test('re-splitting the end half floors it at the new split', () async {
        // First split at 2s of a 5s clip → end half [2s, 5s], floor 2s.
        final clip = _clip(duration: const Duration(seconds: 5));
        DivineVideoClip? firstEnd;
        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (_, e) => firstEnd = e,
          onThumbnailExtracted: null,
        );

        // Split the end half 1s in → absolute 3s.
        DivineVideoClip? secondStart;
        DivineVideoClip? secondEnd;
        await VideoEditorSplitService.splitClip(
          sourceClip: firstEnd!,
          splitPosition: const Duration(seconds: 1),
          onClipsCreated: (s, e) {
            secondStart = s;
            secondEnd = e;
          },
          onThumbnailExtracted: null,
        );

        // New start half inherits the first end's floor (2s), capped at 3s.
        expect(secondStart!.duration, const Duration(seconds: 3));
        expect(secondStart!.minTrimStart, const Duration(seconds: 2));
        // New end half is floored at the new split (3s).
        expect(secondEnd!.trimStart, const Duration(seconds: 3));
        expect(secondEnd!.minTrimStart, const Duration(seconds: 3));
      });

      test('generates unique IDs for split clips', () async {
        final clip = _clip(
          id: 'original-clip',
          duration: const Duration(seconds: 5),
        );
        DivineVideoClip? end1;
        DivineVideoClip? end2;
        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (_, e) => end1 = e,
          onThumbnailExtracted: null,
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (_, e) => end2 = e,
          onThumbnailExtracted: null,
        );
        expect(end1!.id, isNot(equals(end2!.id)));
      });
    });
  });
}
