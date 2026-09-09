// ABOUTME: Tests for ClipEditorBloc - clip CRUD, editing mode,
// ABOUTME: trimming, and split operations.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/editor_overlay_snapshot.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show ExportedLayer, Layer;
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

class _MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/documents';
}

class _MockSplitProVideoEditor extends ProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Future<String> renderVideoToFile(
    String outputPath,
    VideoRenderData renderData, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    return outputPath;
  }
}

DivineVideoClip _createClip({
  String id = 'clip-1',
  Duration duration = const Duration(seconds: 3),
  double? playbackSpeed,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/path/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
    playbackSpeed: playbackSpeed,
  );
}

DivineVideoClip _createClipWithFile({
  String id = 'clip-local',
  Duration duration = const Duration(seconds: 5),
  Duration trimStart = const Duration(seconds: 1),
  Duration trimEnd = const Duration(milliseconds: 500),
  double? playbackSpeed,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/path/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
    playbackSpeed: playbackSpeed,
  ).copyWith(trimStart: trimStart, trimEnd: trimEnd);
}

DivineVideoClip _createClipNoFile({String id = 'clip-no-file'}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.network('https://example.com/vid.mp4'),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );
}

DivineVideoClip _createStopMotionClip({String id = 'sm', int frameCount = 3}) {
  final frames = [
    for (var i = 0; i < frameCount; i++)
      StopMotionClipFrame(
        path: '$id-$i.jpg',
        duration: StopMotionFrameOps.framesPerImageToDuration(1),
      ),
  ];
  return DivineVideoClip(
    id: id,
    stopMotionFrames: frames,
    duration: StopMotionFrameOps.totalDuration(frames),
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );
}

/// Pure-Dart fake of [VideoEditorSplitService.splitClip] for tests.
///
/// Mirrors the real service's clip-id and duration math so the bloc behaves
/// identically without touching `path_provider` or `pro_video_editor`
/// plugins. Without this seam, the real service awaits
/// `getApplicationDocumentsDirectory()` before invoking `onClipsCreated`,
/// which hangs on Linux CI when sibling tests in the VGV-merged bundle
/// leave the global plugin mocks in a broken state.
Future<void> _fakeSplitClip({
  required DivineVideoClip sourceClip,
  required Duration splitPosition,
  required void Function(DivineVideoClip startClip, DivineVideoClip endClip)?
  onClipsCreated,
  required void Function(DivineVideoClip clip, String thumbnailPath)?
  onThumbnailExtracted,
}) async {
  final absoluteSplitPos = sourceClip.trimStart + splitPosition;
  final timestampMs = DateTime.now().microsecondsSinceEpoch;
  final startClip = sourceClip.copyWith(
    id: '${timestampMs}_start',
    duration: absoluteSplitPos,
    trimEnd: Duration.zero,
  );
  final endClip = sourceClip.copyWith(
    id: '${timestampMs}_end',
    trimStart: absoluteSplitPos,
    minTrimStart: absoluteSplitPos,
  );
  onClipsCreated?.call(startClip, endClip);
}

Future<void> _fakeSplitClipThenFail({
  required DivineVideoClip sourceClip,
  required Duration splitPosition,
  required void Function(DivineVideoClip startClip, DivineVideoClip endClip)?
  onClipsCreated,
  required void Function(DivineVideoClip clip, String thumbnailPath)?
  onThumbnailExtracted,
}) async {
  await _fakeSplitClip(
    sourceClip: sourceClip,
    splitPosition: splitPosition,
    onClipsCreated: onClipsCreated,
    onThumbnailExtracted: onThumbnailExtracted,
  );
  throw StateError('render failed');
}

/// Fake split that mirrors the real service: it returns immediately and fires
/// the thumbnail fire-and-forget, so [onThumbnailExtracted] lands *after* the
/// split handler completes (its emitter is done).
Future<void> _fakeSplitClipThenLateThumbnail({
  required DivineVideoClip sourceClip,
  required Duration splitPosition,
  required void Function(DivineVideoClip startClip, DivineVideoClip endClip)?
  onClipsCreated,
  required void Function(DivineVideoClip clip, String thumbnailPath)?
  onThumbnailExtracted,
}) async {
  final absoluteSplitPos = sourceClip.trimStart + splitPosition;
  final ts = DateTime.now().microsecondsSinceEpoch;
  final endClip = sourceClip.copyWith(
    id: '${ts}_end',
    trimStart: absoluteSplitPos,
    minTrimStart: absoluteSplitPos,
  );
  onClipsCreated?.call(
    sourceClip.copyWith(
      id: '${ts}_start',
      duration: absoluteSplitPos,
      trimEnd: Duration.zero,
    ),
    endClip,
  );
  unawaited(
    Future<void>.microtask(
      () => onThumbnailExtracted?.call(endClip, '/thumbs/end.jpg'),
    ),
  );
}

Future<EditorVideo> _fakeReverseClip({
  required DivineVideoClip sourceClip,
  required String renderId,
}) async {
  return EditorVideo.file('/reversed/${sourceClip.id}_$renderId.mp4');
}

Future<EditorVideo> _fakeTransformClip({
  required DivineVideoClip sourceClip,
  required ExportTransform transform,
  required String renderId,
}) async {
  return EditorVideo.file('/transformed/${sourceClip.id}_$renderId.mp4');
}

/// Pure-Dart fake of [VideoEditorMergeService.mergeClips] for tests. Returns a
/// single clip whose duration is the sum of the inputs' playback durations.
Future<DivineVideoClip?> _fakeMergeClips({
  required List<DivineVideoClip> clips,
  required String renderId,
}) async {
  final duration = clips.fold(
    Duration.zero,
    (sum, clip) => sum + clip.playbackDuration,
  );
  return _createClip(id: 'merged-clip', duration: duration);
}

/// Fake merge that fails (renders to a null output / cancelled).
Future<DivineVideoClip?> _fakeMergeClipsFail({
  required List<DivineVideoClip> clips,
  required String renderId,
}) async {
  return null;
}

/// Fake merge that throws — exercises the BLoC's catch / [Reportable] path.
Future<DivineVideoClip?> _fakeMergeClipsThrow({
  required List<DivineVideoClip> clips,
  required String renderId,
}) async {
  throw StateError('merge boom');
}

/// Pure-Dart fake of
/// [VideoEditorClipLibrarySaveService.flattenClipForLibrary]. Returns a fresh
/// clip carrying no residual trim, as the real re-encode does.
Future<DivineVideoClip?> _fakeFlattenClipForLibrary({
  required DivineVideoClip clip,
  required String renderId,
  EditorOverlaySnapshot? overlays,
}) async {
  return _createClip(
    id: 'flattened-${clip.id}',
    duration: clip.playbackDuration,
  );
}

/// Fake flatten that fails (render cancelled / null output path).
Future<DivineVideoClip?> _fakeFlattenClipForLibraryFail({
  required DivineVideoClip clip,
  required String renderId,
  EditorOverlaySnapshot? overlays,
}) async {
  return null;
}

/// Fake flatten that throws — exercises the BLoC's catch / [Reportable] path.
Future<DivineVideoClip?> _fakeFlattenClipForLibraryThrow({
  required DivineVideoClip clip,
  required String renderId,
  EditorOverlaySnapshot? overlays,
}) async {
  throw StateError('flatten boom');
}

void main() {
  group(ClipEditorBloc, () {
    late List<DivineVideoClip> twoClips;
    late List<DivineVideoClip> threeClips;
    late PathProviderPlatform originalPathProviderInstance;
    late ProVideoEditor originalProVideoEditor;

    setUp(() {
      originalPathProviderInstance = PathProviderPlatform.instance;
      originalProVideoEditor = ProVideoEditor.instance;
      PathProviderPlatform.instance = _MockPathProviderPlatform();
      ProVideoEditor.instance = _MockSplitProVideoEditor();
      twoClips = [
        _createClip(id: 'a', duration: const Duration(seconds: 2)),
        _createClip(id: 'b'),
      ];
      threeClips = [
        _createClip(id: 'a', duration: const Duration(seconds: 2)),
        _createClip(id: 'b', duration: const Duration(seconds: 1)),
        _createClip(id: 'c'),
      ];
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProviderInstance;
      ProVideoEditor.instance = originalProVideoEditor;
    });

    ClipEditorBloc buildBloc({
      AudioExtractionService? audioExtractionService,
      SplitClipFn? splitClip,
      ReverseClipFn? reverseClip,
      TransformClipFn? transformClip,
      ChromaKeyBakeFn? bakeChromaKey,
      MergeClipsFn? mergeClips,
      FlattenClipForLibraryFn? flattenClipForLibrary,
      CleanupFlattenedClipFn? cleanupFlattenedClip,
      DeferFileCleanupFn? deferFileCleanup,
      SaveClipToLibraryFn? saveClipToLibrary,
      WriteStopMotionFrameFn? writeStopMotionFrame,
      void Function()? onFinalClipInvalidated,
    }) {
      return ClipEditorBloc(
        onFinalClipInvalidated: onFinalClipInvalidated ?? () {},
        writeStopMotionFrame: writeStopMotionFrame,
        audioExtractionService: audioExtractionService,
        splitClip: splitClip,
        reverseClip: reverseClip,
        transformClip: transformClip,
        bakeChromaKey: bakeChromaKey,
        mergeClips: mergeClips,
        flattenClipForLibrary: flattenClipForLibrary,
        // Defaults to a no-op so tests that don't exercise the non-landing
        // paths never touch the file system.
        cleanupFlattenedClip:
            cleanupFlattenedClip ?? (clip, {keepThumbnailPath}) async {},
        deferFileCleanup: deferFileCleanup,
        // Defaults to "the library rejected it" so a test that never opts in
        // can't silently pass a save it didn't wire up.
        saveClipToLibrary:
            saveClipToLibrary ?? ({required clip}) async => false,
      );
    }

    test('initial state has correct defaults', () {
      final bloc = buildBloc();
      expect(bloc.state.clips, isEmpty);
      expect(bloc.state.currentClipIndex, equals(0));
      expect(bloc.state.splitPosition, equals(Duration.zero));
      expect(bloc.state.isEditing, isFalse);
      expect(bloc.state.isTrimDragging, isFalse);
      expect(bloc.state.isReversing, isFalse);
      expect(bloc.state.totalDuration, equals(Duration.zero));
      bloc.close();
    });

    // =========================================================
    // CLIP DATA
    // =========================================================

    group('ClipEditorInitialized', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'populates clips from provided list',
        build: buildBloc,
        act: (bloc) => bloc.add(ClipEditorInitialized(twoClips)),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.clips.first.id, 'first id', 'a')
              .having((s) => s.clips.last.id, 'last id', 'b'),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets clips as unmodifiable list',
        build: buildBloc,
        act: (bloc) => bloc.add(ClipEditorInitialized(twoClips)),
        verify: (bloc) {
          expect(
            () => (bloc.state.clips as List).add(_createClip()),
            throwsUnsupportedError,
          );
        },
      );
    });

    group('ClipEditorClipRemoved', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'removes clip by ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('a')),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(1))
              .having((s) => s.clips.first.id, 'remaining id', 'b'),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for unknown clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('unknown')),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorClipInserted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'inserts clip at specified index',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipInserted(index: 1, clip: _createClip(id: 'new')),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(3))
              .having((s) => s.clips[1].id, 'inserted id', 'new'),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps index to valid range when too large',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipInserted(index: 100, clip: _createClip(id: 'end')),
        ),
        verify: (bloc) {
          expect(bloc.state.clips.last.id, equals('end'));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps negative index to 0',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipInserted(index: -5, clip: _createClip(id: 'first')),
        ),
        verify: (bloc) {
          expect(bloc.state.clips.first.id, equals('first'));
        },
      );
    });

    group('ClipEditorClipUpdated', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'replaces clip data for existing clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipUpdated(
            clipId: 'a',
            clip: twoClips.first.copyWith(
              duration: const Duration(seconds: 10),
            ),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.duration.inSeconds, 'duration', 10)
              .having((s) => s.clips, 'clips', hasLength(2)),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for unknown clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipUpdated(
            clipId: 'unknown',
            clip: _createClip(id: 'unknown'),
          ),
        ),
        expect: () => <ClipEditorState>[],
      );
    });

    // =========================================================
    // CLIP SELECTION
    // =========================================================

    group('ClipEditorClipSelected', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets index and resets split position',
        build: buildBloc,
        seed: () => ClipEditorState(clips: threeClips),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(1)),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.currentClipIndex, 'index', 1)
              .having(
                (s) => s.splitPosition,
                'splitPosition',
                equals(Duration.zero),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for negative index',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(-1)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when index >= clip count',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(5)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clears a stop-motion frame selection',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          selectedFrameIndex: 2,
        ),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(0)),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.selectedFrameIndex,
            'selectedFrameIndex',
            isNull,
          ),
        ],
      );
    });

    group('ClipEditorFrameSelected', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'selects the frame and enters editing on a stop-motion clip',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createStopMotionClip()]),
        act: (bloc) => bloc.add(const ClipEditorFrameSelected(1)),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.selectedFrameIndex, 'selectedFrameIndex', 1)
              .having((s) => s.isEditing, 'isEditing', isTrue)
              .having((s) => s.currentClipIndex, 'currentClipIndex', 0),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is a no-op for a normal video composition',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorFrameSelected(0)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is a no-op for an out-of-range frame index',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createStopMotionClip()]),
        act: (bloc) => bloc.add(const ClipEditorFrameSelected(9)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps the selection when a frame delete shrinks the clip',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          selectedFrameIndex: 2,
          isEditing: true,
        ),
        act: (bloc) {
          final clip = bloc.state.clips.first;
          final shorter = StopMotionFrameOps.clipWithFrames(
            clip,
            StopMotionFrameOps.removeFrame(clip.stopMotionFrames!, 2),
          );
          bloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: shorter));
        },
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.selectedFrameIndex,
            'selectedFrameIndex',
            1,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clears the selection when a frame update leaves the clip empty',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          selectedFrameIndex: 0,
          isEditing: true,
        ),
        act: (bloc) {
          final clip = bloc.state.clips.first;
          final empty = DivineVideoClip(
            id: clip.id,
            stopMotionFrames: const [],
            duration: Duration.zero,
            recordedAt: clip.recordedAt,
            targetAspectRatio: clip.targetAspectRatio,
            originalAspectRatio: clip.originalAspectRatio,
          );
          bloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: empty));
        },
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.selectedFrameIndex,
            'selectedFrameIndex',
            isNull,
          ),
        ],
      );
    });

    group('frame multi-select', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'starts with the current frame pre-selected and exits editing',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          selectedFrameIndex: 1,
          isEditing: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorFrameMultiSelectStarted(1)),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isMultiSelectMode, 'isMultiSelectMode', isTrue)
              .having((s) => s.isEditing, 'isEditing', isFalse)
              .having((s) => s.selectedFrameIndex, 'selectedFrameIndex', isNull)
              .having((s) => s.selectedFrameIndexes, 'selectedFrameIndexes', {
                1,
              }),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is a no-op for a normal video composition',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorFrameMultiSelectStarted(0)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'toggling adds and removes stills from the selection',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          isMultiSelectMode: true,
          selectedFrameIndexes: const {0},
        ),
        act: (bloc) => bloc
          ..add(const ClipEditorFrameMultiSelectToggled(2))
          ..add(const ClipEditorFrameMultiSelectToggled(0)),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.selectedFrameIndexes,
            'selectedFrameIndexes',
            {0, 2},
          ),
          isA<ClipEditorState>().having(
            (s) => s.selectedFrameIndexes,
            'selectedFrameIndexes',
            {2},
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'ignores an out-of-range toggle',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          isMultiSelectMode: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorFrameMultiSelectToggled(9)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'cancelling clears the frame selection and exits the mode',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          isMultiSelectMode: true,
          selectedFrameIndexes: const {0, 1},
        ),
        act: (bloc) => bloc.add(const ClipEditorMultiSelectCancelled()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isMultiSelectMode, 'isMultiSelectMode', isFalse)
              .having(
                (s) => s.selectedFrameIndexes,
                'selectedFrameIndexes',
                isEmpty,
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'replaces the selection wholesale after a block move',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          isMultiSelectMode: true,
          selectedFrameIndexes: const {0, 1},
        ),
        act: (bloc) => bloc.add(const ClipEditorFrameMultiSelectionSet({1, 2})),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.selectedFrameIndexes,
            'selectedFrameIndexes',
            {1, 2},
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'ignores a selection-set with out-of-range indexes',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          isMultiSelectMode: true,
          selectedFrameIndexes: const {0},
        ),
        act: (bloc) => bloc.add(const ClipEditorFrameMultiSelectionSet({0, 9})),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'prunes out-of-range indexes when a frame delete shrinks the clip',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createStopMotionClip()],
          isMultiSelectMode: true,
          selectedFrameIndexes: const {0, 2},
        ),
        act: (bloc) {
          final clip = bloc.state.clips.first;
          final shorter = StopMotionFrameOps.clipWithFrames(
            clip,
            StopMotionFrameOps.removeFrame(clip.stopMotionFrames!, 2),
          );
          bloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: shorter));
        },
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.selectedFrameIndexes,
            'selectedFrameIndexes',
            {0},
          ),
        ],
      );
    });

    // =========================================================
    // EDITING MODE
    // =========================================================

    group('ClipEditorEditingStarted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'enters editing mode and sets split position to half duration',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(duration: const Duration(seconds: 4))],
        ),
        act: (bloc) => bloc.add(const ClipEditorEditingStarted()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isTrue)
              .having(
                (s) => s.splitPosition,
                'splitPosition',
                equals(const Duration(seconds: 2)),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when currentClipIndex >= clips.length',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips, currentClipIndex: 5),
        act: (bloc) => bloc.add(const ClipEditorEditingStarted()),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorEditingStopped', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'exits editing mode',
        build: buildBloc,
        seed: () => const ClipEditorState(isEditing: true),
        act: (bloc) => bloc.add(const ClipEditorEditingStopped()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isEditing,
            'isEditing',
            isFalse,
          ),
        ],
      );
    });

    group('ClipEditorEditingToggled', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'starts editing when not editing',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(duration: const Duration(seconds: 2))],
        ),
        act: (bloc) => bloc.add(const ClipEditorEditingToggled()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isEditing,
            'isEditing',
            isTrue,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'stops editing when already editing',
        build: buildBloc,
        seed: () => const ClipEditorState(isEditing: true),
        act: (bloc) => bloc.add(const ClipEditorEditingToggled()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isEditing,
            'isEditing',
            isFalse,
          ),
        ],
      );
    });

    group('ClipEditorSplitPositionChanged', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'updates split position',
        build: buildBloc,
        seed: () => const ClipEditorState(),
        act: (bloc) => bloc.add(
          const ClipEditorSplitPositionChanged(Duration(seconds: 1)),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.splitPosition,
            'splitPosition',
            equals(const Duration(seconds: 1)),
          ),
        ],
      );
    });

    // =========================================================
    // SPLIT
    // =========================================================

    group('ClipEditorOriginalClipReplaced', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'replaces source clip with start and end clips',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) {
          final startClip = _createClip(
            id: 'a-start',
            duration: const Duration(seconds: 1),
          );
          final endClip = _createClip(
            id: 'a-end',
            duration: const Duration(seconds: 1),
          );
          bloc.add(
            ClipEditorOriginalClipReplaced(
              sourceClipId: 'a',
              startClip: startClip,
              endClip: endClip,
            ),
          );
        },
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(3))
              .having((s) => s.clips[0].id, 'first id', 'a-start')
              .having((s) => s.clips[1].id, 'second id', 'a-end')
              .having((s) => s.clips[2].id, 'third id', 'b'),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when source clip id is not found',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) {
          bloc.add(
            ClipEditorOriginalClipReplaced(
              sourceClipId: 'nonexistent',
              startClip: _createClip(id: 'x'),
              endClip: _createClip(id: 'y'),
            ),
          );
        },
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorSplitRequested', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'stops editing and replaces clip when split position is valid',
        build: () => buildBloc(splitClip: _fakeSplitClip),
        seed: () {
          final clip = _createClip(
            id: 'split-me',
            duration: const Duration(seconds: 2),
          );
          // Position at 1s is valid (both halves >= 30ms)
          return ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(seconds: 1),
          );
        },
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isFalse)
              .having((s) => s.isSplitting, 'isSplitting', isTrue)
              .having((s) => s.splittingClipId, 'splittingClipId', 'split-me')
              .having((s) => s.isTrimDragging, 'isTrimDragging', isFalse),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isTrue)
              .having(
                (s) => s.clips.first.duration,
                'start duration',
                const Duration(seconds: 1),
              )
              .having(
                (s) => s.clips.last.duration,
                'end duration',
                const Duration(seconds: 2),
              )
              .having(
                (s) => s.clips.last.trimmedDuration,
                'end trimmedDuration',
                const Duration(seconds: 1),
              ),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isFalse)
              .having((s) => s.splittingClipId, 'splittingClipId', isNull),
        ],
      );

      // A queued split must hit the clip captured at dispatch, not whatever is
      // selected when the (sequential) handler runs.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'splits the clip named by the event, not the current selection',
        build: () => buildBloc(splitClip: _fakeSplitClip),
        seed: () => ClipEditorState(
          clips: [
            _createClip(id: 'a', duration: const Duration(seconds: 4)),
            _createClip(id: 'b', duration: const Duration(seconds: 4)),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorSplitRequested(
            clipId: 'b',
            splitPosition: Duration(seconds: 2),
          ),
        ),
        wait: const Duration(milliseconds: 1),
        verify: (bloc) {
          final clips = bloc.state.clips;
          expect(clips, hasLength(3));
          // 'a' (the selected clip) is untouched; 'b' was split into two.
          expect(clips.first.id, equals('a'));
          expect(clips.any((c) => c.id == 'b'), isFalse);
        },
      );

      // A queued split on a clip *before* the current selection must not shift
      // the selection onto a different clip — currentClipIndex follows the same
      // clip after the inserted tail pushes later indices down.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'keeps the selection on the same clip when an earlier clip is split',
        build: () => buildBloc(splitClip: _fakeSplitClip),
        seed: () => ClipEditorState(
          currentClipIndex: 2,
          clips: [
            _createClip(id: 'a', duration: const Duration(seconds: 4)),
            _createClip(id: 'b', duration: const Duration(seconds: 4)),
            _createClip(id: 'c', duration: const Duration(seconds: 4)),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorSplitRequested(
            clipId: 'a',
            splitPosition: Duration(seconds: 2),
          ),
        ),
        wait: const Duration(milliseconds: 1),
        verify: (bloc) {
          final state = bloc.state;
          // 'a' became two clips, so 'c' moved from index 2 to index 3.
          expect(state.clips, hasLength(4));
          expect(state.clips.last.id, equals('c'));
          // The selection still points at 'c', not the clip now at index 2.
          expect(state.clips[state.currentClipIndex].id, equals('c'));
        },
      );

      test('uses state splitPosition for resulting clip durations', () async {
        final clip = _createClip(id: 'x', duration: const Duration(seconds: 2));

        final bloc = buildBloc(splitClip: _fakeSplitClip);

        bloc.emit(
          ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(milliseconds: 500),
          ),
        );

        bloc.add(const ClipEditorSplitRequested());
        final states = await bloc.stream.take(2).toList();

        final replacedState = states.last;

        expect(replacedState.clips, hasLength(2));
        expect(
          replacedState.clips.first.duration,
          equals(const Duration(milliseconds: 500)),
        );
        expect(
          replacedState.clips.last.trimmedDuration,
          equals(const Duration(milliseconds: 1500)),
        );

        await bloc.close();
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits nothing when split position is invalid',
        build: buildBloc,
        seed: () {
          final clip = _createClip(
            id: 'tiny',
            duration: const Duration(seconds: 2),
          );
          // 5ms is below minClipDuration (30ms) for either half
          return ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(milliseconds: 5),
          );
        },
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when currentClipIndex >= clips.length',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
          currentClipIndex: 10,
          isEditing: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'stops editing and performs split with injected splitter',
        build: () => buildBloc(splitClip: _fakeSplitClip),
        seed: () {
          final clip = _createClip(duration: const Duration(seconds: 2));
          return ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(seconds: 1),
          );
        },
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isFalse)
              .having((s) => s.isSplitting, 'isSplitting', isTrue),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isTrue),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isFalse),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'rolls back created split clips when render fails',
        build: () => buildBloc(splitClip: _fakeSplitClipThenFail),
        seed: () {
          final clip = _createClip(
            id: 'source-clip',
            duration: const Duration(seconds: 2),
          );
          return ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(seconds: 1),
          );
        },
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isFalse)
              .having((s) => s.isSplitting, 'isSplitting', isTrue)
              .having(
                (s) => s.clips.single.id,
                'source clip id',
                'source-clip',
              ),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isTrue)
              .having((s) => s.lastSplit, 'lastSplit', isNotNull),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(1))
              .having(
                (s) => s.clips.single.id,
                'restored source clip id',
                'source-clip',
              )
              .having((s) => s.isSplitting, 'isSplitting', isFalse)
              .having((s) => s.lastSplit, 'lastSplit', isNull)
              .having(
                (s) => s.lastSplitFailure,
                'lastSplitFailure',
                isA<ClipSplitFailure>(),
              ),
        ],
        errors: () => [isA<StateError>()],
      );

      test(
        'a second split after the first completes still works (#4801)',
        () async {
          final bloc = buildBloc(splitClip: _fakeSplitClip);
          bloc.emit(
            ClipEditorState(
              clips: [
                _createClip(id: 'source', duration: const Duration(seconds: 4)),
              ],
              isEditing: true,
              splitPosition: const Duration(seconds: 2),
            ),
          );

          bloc.add(const ClipEditorSplitRequested());
          await bloc.stream.firstWhere(
            (s) => !s.isSplitting && s.clips.length == 2,
          );

          // The split future always resolves now, so isSplitting resets and the
          // sequential() transformer runs the next split request in turn.
          bloc
            ..emit(
              bloc.state.copyWith(
                currentClipIndex: 0,
                isEditing: true,
                splitPosition: const Duration(seconds: 1),
              ),
            )
            ..add(const ClipEditorSplitRequested());
          await bloc.stream.firstWhere(
            (s) => !s.isSplitting && s.clips.length == 3,
          );

          expect(bloc.state.clips, hasLength(3));
          expect(bloc.state.isSplitting, isFalse);

          await bloc.close();
        },
      );

      // The split's thumbnail decode is fire-and-forget, so it lands after the
      // split handler completes. It must still update the poster via a fresh
      // event rather than a done emitter (otherwise the refresh is dropped).
      test(
        'applies the background thumbnail after the split completes',
        () async {
          final bloc = buildBloc(splitClip: _fakeSplitClipThenLateThumbnail);
          bloc.emit(
            ClipEditorState(
              clips: [
                _createClip(id: 'source', duration: const Duration(seconds: 4)),
              ],
              isEditing: true,
              splitPosition: const Duration(seconds: 2),
            ),
          );

          bloc.add(const ClipEditorSplitRequested());
          // The fire-and-forget thumbnail lands after the split settles and
          // must still reach the poster (the old done-emitter path dropped it,
          // which would leave this firstWhere waiting forever).
          await bloc.stream.firstWhere(
            (s) =>
                !s.isSplitting &&
                s.clips.length == 2 &&
                s.clips.last.thumbnailPath == '/thumbs/end.jpg',
          );
          expect(bloc.state.clips.last.thumbnailPath, '/thumbs/end.jpg');
          expect(bloc.state.isSplitting, isFalse);

          await bloc.close();
        },
      );

      // Regression: a queued split silently vanished because the editor→bloc
      // re-sync (ClipEditorInitialized, dispatched by the canvas after the
      // previous split committed) carried a stale pre-split snapshot and
      // overwrote the just-applied split. While a split is in flight the bloc
      // owns the clip list, so a re-init must be ignored.
      test(
        'ignores ClipEditorInitialized while a split is in flight',
        () async {
          final gate = Completer<void>();

          Future<void> gatedSplit({
            required DivineVideoClip sourceClip,
            required Duration splitPosition,
            required void Function(
              DivineVideoClip startClip,
              DivineVideoClip endClip,
            )?
            onClipsCreated,
            required void Function(DivineVideoClip clip, String thumbnailPath)?
            onThumbnailExtracted,
          }) async {
            final absoluteSplitPos = sourceClip.trimStart + splitPosition;
            final ts = DateTime.now().microsecondsSinceEpoch;
            onClipsCreated?.call(
              sourceClip.copyWith(
                id: '${ts}_start',
                duration: absoluteSplitPos,
                trimEnd: Duration.zero,
              ),
              sourceClip.copyWith(
                id: '${ts}_end',
                trimStart: absoluteSplitPos,
                minTrimStart: absoluteSplitPos,
              ),
            );
            await gate.future;
          }

          final bloc = buildBloc(splitClip: gatedSplit);
          bloc.emit(
            ClipEditorState(
              clips: [
                _createClip(id: 'source', duration: const Duration(seconds: 4)),
              ],
              isEditing: true,
              splitPosition: const Duration(seconds: 2),
            ),
          );

          bloc.add(const ClipEditorSplitRequested());
          await bloc.stream.firstWhere(
            (s) => s.clips.length == 2 && s.isSplitting,
          );

          // A stale editor re-sync lands mid-split — it would revert to 1 clip.
          bloc.add(
            ClipEditorInitialized([
              _createClip(id: 'stale', duration: const Duration(seconds: 4)),
            ]),
          );
          await pumpEventQueue();

          // The in-flight split's clips are preserved; the stale snapshot is
          // ignored.
          expect(bloc.state.clips, hasLength(2));
          expect(bloc.state.isSplitting, isTrue);

          gate.complete();
          await pumpEventQueue();
          await bloc.close();
        },
      );

      test('validates using VideoEditorSplitService.isValidSplitPosition', () {
        final clip = _createClip(duration: const Duration(seconds: 2));

        // Valid: both halves > 30ms
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(seconds: 1),
          ),
          isTrue,
        );

        // Invalid: left side too short
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 10),
          ),
          isFalse,
        );

        // Invalid: right side too short
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            Duration(milliseconds: clip.duration.inMilliseconds - 10),
          ),
          isFalse,
        );
      });

      test(
        'sets lastSplit with correct ids and position after split',
        () async {
          final clip = _createClip(
            id: 'source-clip',
            duration: const Duration(seconds: 2),
          );
          final bloc = buildBloc(splitClip: _fakeSplitClip)
            ..emit(
              ClipEditorState(
                clips: [clip],
                isEditing: true,
                splitPosition: const Duration(seconds: 1),
              ),
            );

          bloc.add(const ClipEditorSplitRequested());
          // First emit: isEditing=false. Second: onClipsCreated with lastSplit.
          final states = await bloc.stream.take(2).toList();
          final splitState = states.last;

          expect(splitState.lastSplit, isNotNull);
          expect(splitState.lastSplit!.sourceClipId, equals('source-clip'));
          expect(
            splitState.lastSplit!.startClipId,
            equals(splitState.clips.first.id),
          );
          expect(
            splitState.lastSplit!.endClipId,
            equals(splitState.clips.last.id),
          );

          await bloc.close();
        },
      );

      test('absoluteSplitPosition equals trimStart + splitPosition', () async {
        final clip = _createClip(
          id: 'c',
          duration: const Duration(seconds: 4),
        ).copyWith(trimStart: const Duration(milliseconds: 500));

        final bloc = buildBloc(splitClip: _fakeSplitClip)
          ..emit(
            ClipEditorState(
              clips: [clip],
              isEditing: true,
              // 1 s into the trimmed view
              splitPosition: const Duration(seconds: 1),
            ),
          );

        bloc.add(const ClipEditorSplitRequested());
        final states = await bloc.stream.take(2).toList();
        final split = states.last.lastSplit!;

        expect(
          split.absoluteSplitPosition,
          // trimStart(500ms) + splitPosition(1000ms)
          equals(const Duration(milliseconds: 1500)),
        );

        await bloc.close();
      });

      test('lastSplit captures source trim bounds', () async {
        final clip = _createClip(id: 'c', duration: const Duration(seconds: 10))
            .copyWith(
              trimStart: const Duration(seconds: 3),
              trimEnd: const Duration(seconds: 2),
            );

        final bloc = buildBloc(splitClip: _fakeSplitClip)
          ..emit(
            ClipEditorState(
              clips: [clip],
              isEditing: true,
              splitPosition: const Duration(seconds: 2),
            ),
          );

        bloc.add(const ClipEditorSplitRequested());
        final states = await bloc.stream.take(2).toList();
        final split = states.last.lastSplit!;

        expect(split.sourceTrimStart, equals(const Duration(seconds: 3)));
        expect(split.sourceTrimEnd, equals(const Duration(seconds: 2)));

        await bloc.close();
      });
    });

    // =========================================================
    // STATE HELPERS
    // =========================================================

    group('ClipEditorState', () {
      test('totalDuration sums all clip durations', () {
        final state = ClipEditorState(clips: threeClips);
        // 2s + 1s + 3s = 6s
        expect(state.totalDuration, equals(const Duration(seconds: 6)));
      });

      test('totalDuration is zero for empty clips', () {
        const state = ClipEditorState();
        expect(state.totalDuration, equals(Duration.zero));
      });

      test('copyWith preserves all fields when no overrides given', () {
        final original = ClipEditorState(
          clips: twoClips,
          currentClipIndex: 1,
          splitPosition: const Duration(seconds: 1),
          isEditing: true,
          isTrimDragging: true,
        );

        final copy = original.copyWith();
        expect(copy, equals(original));
      });

      test('copyWith replaces individual fields', () {
        const original = ClipEditorState();
        final updated = original.copyWith(
          isEditing: true,
          isTrimDragging: true,
        );
        expect(updated.isEditing, isTrue);
        expect(updated.isTrimDragging, isTrue);
        // Other fields unchanged
        expect(updated.currentClipIndex, equals(0));
      });

      test('lastSplit defaults to null', () {
        const state = ClipEditorState();
        expect(state.lastSplit, isNull);
      });

      test('copyWith sets lastSplit', () {
        const state = ClipEditorState();
        final split = ClipSplitEvent(
          sourceClipId: 'src',
          startClipId: 'start',
          endClipId: 'end',
          absoluteSplitPosition: const Duration(seconds: 1),
          sourceDuration: const Duration(seconds: 2),
        );

        final updated = state.copyWith(lastSplit: split);

        expect(updated.lastSplit, same(split));
      });

      test(
        'two ClipSplitEvents with identical fields are treated as distinct',
        () {
          final split1 = ClipSplitEvent(
            sourceClipId: 'src',
            startClipId: 'start',
            endClipId: 'end',
            absoluteSplitPosition: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 2),
          );
          final split2 = ClipSplitEvent(
            sourceClipId: 'src',
            startClipId: 'start',
            endClipId: 'end',
            absoluteSplitPosition: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 2),
          );

          final state1 = ClipEditorState(lastSplit: split1);
          final state2 = ClipEditorState(lastSplit: split2);

          // Identity hash differs between instances → props differ → not equal
          expect(state1, isNot(equals(state2)));
        },
      );
    });

    // =========================================================
    // TRIM
    // =========================================================

    group('ClipEditorTrimUpdated', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'updates trimStart and trimEnd on target clip',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            isStart: true,
            trimStart: Duration(milliseconds: 500),
            trimEnd: Duration(milliseconds: 300),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                const Duration(milliseconds: 500),
              )
              .having(
                (s) => s.clips.first.trimEnd,
                'trimEnd',
                const Duration(milliseconds: 300),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'no-op for unknown clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'unknown',
            isStart: true,
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
          ),
        ),
        expect: () => <ClipEditorState>[],
      );

      // A trim-based split's end half floors trimStart at the split point so
      // its left handle can't be dragged back into the start half's frames.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps trimStart to the clip minTrimStart floor',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [
            _createClip(
              id: 'end-half',
              duration: const Duration(seconds: 5),
            ).copyWith(
              trimStart: const Duration(seconds: 2),
              minTrimStart: const Duration(seconds: 2),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'end-half',
            isStart: true,
            trimStart: Duration(milliseconds: 500),
            trimEnd: Duration.zero,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.clips.first.trimStart,
            'clamped trimStart',
            const Duration(seconds: 2),
          ),
        ],
      );

      // Regression: the split guard allows a 40ms half, but the upper trim
      // bound (duration - minTrimDuration - trimEnd) then dips below the
      // minTrimStart floor. The floor must stay authoritative so the clamp
      // never emits a trimStart below it (which would show the sibling's
      // frames).
      blocTest<ClipEditorBloc, ClipEditorState>(
        'never emits a trimStart below the floor for a sub-60ms end half',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [
            _createClip(
              id: 'tiny-end',
              duration: const Duration(seconds: 2),
            ).copyWith(
              trimStart: const Duration(milliseconds: 1970),
              minTrimStart: const Duration(milliseconds: 1970),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'tiny-end',
            isStart: true,
            trimStart: Duration(milliseconds: 1980),
            trimEnd: Duration.zero,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) =>
                s.clips.first.trimStart >= const Duration(milliseconds: 1970),
            'trimStart stays at/above the floor',
            isTrue,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'updates totalDuration to reflect trimmed clips',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            isStart: true,
            trimStart: Duration(milliseconds: 500),
            trimEnd: Duration.zero,
          ),
        ),
        verify: (bloc) {
          // Clip 'a' was 2s, now trimmed by 500ms = 1.5s
          // Clip 'b' is 3s, unchanged
          // Total should be 4.5s
          expect(
            bloc.state.totalDuration,
            equals(const Duration(milliseconds: 4500)),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does not affect other clips',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            isStart: true,
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.clips.last.trimStart, equals(Duration.zero));
          expect(bloc.state.clips.last.trimEnd, equals(Duration.zero));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets trimmingClipId and trimPosition to clampedStart when isStart',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            isStart: true,
            trimStart: Duration(milliseconds: 500),
            trimEnd: Duration.zero,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.trimmingClipId, 'trimmingClipId', 'a')
              .having(
                (s) => s.trimPosition,
                'trimPosition',
                const Duration(milliseconds: 500),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets trimPosition to clip.duration - clampedEnd when !isStart',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          // Clip 'a' has duration 2s; trimEnd 500ms → trimPosition 1.5s
          const ClipEditorTrimUpdated(
            clipId: 'a',
            isStart: false,
            trimStart: Duration.zero,
            trimEnd: Duration(milliseconds: 500),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.trimmingClipId, 'trimmingClipId', 'a')
              .having(
                (s) => s.trimPosition,
                'trimPosition',
                const Duration(milliseconds: 1500),
              ),
        ],
      );
    });

    group('ClipEditorTrimDragStarted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets isTrimDragging to true',
        build: buildBloc,
        act: (bloc) => bloc.add(const ClipEditorTrimDragStarted()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isTrimDragging,
            'isTrimDragging',
            isTrue,
          ),
        ],
      );
    });

    group('ClipEditorTrimDragEnded', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets isTrimDragging to false',
        build: buildBloc,
        seed: () => const ClipEditorState(isTrimDragging: true),
        act: (bloc) => bloc.add(const ClipEditorTrimDragEnded()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isTrimDragging,
            'isTrimDragging',
            isFalse,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clears trimPosition and trimmingClipId',
        build: buildBloc,
        seed: () => const ClipEditorState(
          isTrimDragging: true,
          trimmingClipId: 'a',
          trimPosition: Duration(milliseconds: 500),
        ),
        act: (bloc) => bloc.add(const ClipEditorTrimDragEnded()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.trimmingClipId, 'trimmingClipId', isNull)
              .having((s) => s.trimPosition, 'trimPosition', isNull),
        ],
      );
    });

    group('ClipEditorClipVolumeChanged', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps volume, bumps revision, and keeps clips unmodifiable',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipVolumeChanged(clipId: 'a', volume: -1.0),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.volume, 'volume', 0.0)
              .having((s) => s.clipsVolumeRevision, 'clipsVolumeRevision', 1),
        ],
        verify: (bloc) {
          expect(
            () => (bloc.state.clips as List).add(_createClip(id: 'extra')),
            throwsUnsupportedError,
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when clamped volume matches current volume',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipVolumeChanged(clipId: 'a', volume: 2.0),
        ),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for unknown clip id',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipVolumeChanged(clipId: 'missing', volume: 0.4),
        ),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorAllClipsVolumeChanged', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps below 0 to 0 on every clip, bumps revision, '
        'keeps clips unmodifiable',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) =>
            bloc.add(const ClipEditorAllClipsVolumeChanged(volume: -1.0)),
        expect: () => [
          isA<ClipEditorState>()
              .having(
                (s) => s.clips.map((c) => c.volume).toList(),
                'clip volumes',
                [0.0, 0.0],
              )
              .having((s) => s.clipsVolumeRevision, 'clipsVolumeRevision', 1),
        ],
        verify: (bloc) {
          expect(
            () => (bloc.state.clips as List).add(_createClip(id: 'extra')),
            throwsUnsupportedError,
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps above 1 to 1 on every clip',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips
              .map((c) => c.copyWith(volume: 0.5))
              .toList(growable: false),
        ),
        act: (bloc) =>
            bloc.add(const ClipEditorAllClipsVolumeChanged(volume: 2.0)),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.clips.map((c) => c.volume).toList(),
            'clip volumes',
            [1.0, 1.0],
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when there are no clips',
        build: buildBloc,
        seed: () => const ClipEditorState(),
        act: (bloc) =>
            bloc.add(const ClipEditorAllClipsVolumeChanged(volume: 0.0)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when every clip already has the clamped target volume',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) =>
            bloc.add(const ClipEditorAllClipsVolumeChanged(volume: 2.0)),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorClipReverseRequested', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits no-local-file result when clip has no local file',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createClipNoFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-no-file'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.lastReverseResult,
            'lastReverseResult',
            isA<ClipReverseNoLocalFile>(),
          ),
        ],
      );

      // A trimmed clip (5s, trimmed 1s/0.5s → 3.5s visible) bakes into a
      // standalone reversed clip: trims reset, duration becomes the window
      // length, the split floor clears, and — because the forward clip was
      // trimmed — the swap-based cache is dropped so the toggle re-renders.
      final reversedCleanupPaths = <String>[];
      blocTest<ClipEditorBloc, ClipEditorState>(
        'bakes the visible window into a standalone reversed clip',
        build: () => buildBloc(
          reverseClip: _fakeReverseClip,
          deferFileCleanup: (paths) =>
              reversedCleanupPaths.addAll(paths.whereType<String>()),
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              chromaKey: const ClipChromaKey(key: ChromaKey.greenScreen()),
              chromaKeySourcePath: '/path/pre-key.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isReversing, 'isReversing', isTrue)
              .having(
                (s) => s.reversingClipId,
                'reversingClipId',
                'clip-local',
              ),
          isA<ClipEditorState>()
              .having((s) => s.isReversing, 'isReversing', isFalse)
              .having((s) => s.reversingClipId, 'reversingClipId', isNull)
              .having((s) => s.clips.first.reversed, 'reversed', isTrue)
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                Duration.zero,
              )
              .having((s) => s.clips.first.trimEnd, 'trimEnd', Duration.zero)
              .having(
                (s) => s.clips.first.minTrimStart,
                'minTrimStart',
                Duration.zero,
              )
              .having(
                (s) => s.clips.first.duration,
                'duration',
                const Duration(milliseconds: 3500),
              )
              .having(
                (s) => s.clips.first.forwardVideoPath,
                'forwardVideoPath',
                isNull,
              )
              .having(
                (s) => s.clips.first.reversedVideoPath,
                'reversedVideoPath',
                isNull,
              )
              // The reversed render is a new file; re-keying from the recorded
              // un-reversed source would undo the reverse.
              .having((s) => s.clips.first.chromaKey, 'chromaKey', isNull)
              .having(
                (s) => s.clips.first.chromaKeySourcePath,
                'chromaKeySourcePath',
                isNull,
              )
              .having(
                (s) => s.lastReverseResult,
                'lastReverseResult',
                isA<ClipReverseSuccess>(),
              ),
        ],
        verify: (bloc) {
          expect(
            bloc.state.clips.first.requireVideo.file?.path,
            equals('/reversed/clip-local_clip-local.mp4'),
          );
          expect(reversedCleanupPaths, contains('/path/pre-key.mp4'));
        },
      );

      // Regression for the critical reverse×split bug: a split end half
      // (shares the source file, floored at the split) must reverse into a
      // standalone clip — floor cleared, trims reset — so it can never expose
      // the sibling start half's frames in preview or export.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'reversing a split end half clears the floor and produces a '
        'standalone clip',
        build: () => buildBloc(reverseClip: _fakeReverseClip),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile(
              trimStart: const Duration(seconds: 2),
              trimEnd: Duration.zero,
            ).copyWith(minTrimStart: const Duration(seconds: 2)),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isReversing,
            'isReversing',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.clips.first.reversed, 'reversed', isTrue)
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                Duration.zero,
              )
              .having(
                (s) => s.clips.first.minTrimStart,
                'minTrimStart (floor cleared)',
                Duration.zero,
              )
              .having(
                (s) => s.clips.first.duration,
                'duration is the visible window',
                const Duration(seconds: 3),
              )
              .having(
                (s) => s.clips.first.forwardVideoPath,
                'forwardVideoPath (cache cleared)',
                isNull,
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'restores cached forward clip without calling reverse service',
        build: () => buildBloc(
          reverseClip: ({required sourceClip, required renderId}) async {
            throw StateError('reverse service should not be called');
          },
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              video: EditorVideo.file('/reversed/clip-local_clip-local.mp4'),
              trimStart: const Duration(milliseconds: 500),
              trimEnd: const Duration(seconds: 1),
              reversed: true,
              forwardVideoPath: '/path/clip-local.mp4',
              reversedVideoPath: '/reversed/clip-local_clip-local.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.reversed, 'reversed', isFalse)
              .having(
                (s) => s.clips.first.requireVideo.file?.path,
                'videoPath',
                '/path/clip-local.mp4',
              )
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                const Duration(seconds: 1),
              )
              .having(
                (s) => s.clips.first.trimEnd,
                'trimEnd',
                const Duration(milliseconds: 500),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'reuses cached reversed clip and swaps trim bounds',
        build: () => buildBloc(
          reverseClip: ({required sourceClip, required renderId}) async {
            throw StateError('reverse service should not be called');
          },
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              forwardVideoPath: '/path/clip-local.mp4',
              reversedVideoPath: '/reversed/clip-local_clip-local.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.reversed, 'reversed', isTrue)
              .having(
                (s) => s.clips.first.requireVideo.file?.path,
                'videoPath',
                '/reversed/clip-local_clip-local.mp4',
              )
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                const Duration(milliseconds: 500),
              )
              .having(
                (s) => s.clips.first.trimEnd,
                'trimEnd',
                const Duration(seconds: 1),
              )
              .having(
                (s) => s.clips.first.duration,
                'duration',
                const Duration(seconds: 5),
              ),
        ],
      );

      // Regression test: a duplicate/split of a reversed clip preserves
      // `reversed: true` but clears both cache paths, so the fresh-render
      // branch is reached with reversed input. The render output is forward
      // content and must be cached as `forwardVideoPath`; the reversed input
      // must be cached as `reversedVideoPath`. Mapping by output direction
      // would invert both and make later cached toggles play the wrong way.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'caches forward/reversed paths in the correct direction when fresh '
        'rendering an untrimmed reversed clip with no cache',
        build: () => buildBloc(reverseClip: _fakeReverseClip),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile(
              trimStart: Duration.zero,
              trimEnd: Duration.zero,
            ).copyWith(
              video: EditorVideo.file('/path/clip-local-reversed.mp4'),
              reversed: true,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isReversing,
            'isReversing',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isReversing, 'isReversing', isFalse)
              .having((s) => s.clips.first.reversed, 'reversed', isFalse)
              .having(
                (s) => s.clips.first.forwardVideoPath,
                'forwardVideoPath',
                '/reversed/clip-local_clip-local.mp4',
              )
              .having(
                (s) => s.clips.first.reversedVideoPath,
                'reversedVideoPath',
                '/path/clip-local-reversed.mp4',
              )
              .having(
                (s) => s.lastReverseResult,
                'lastReverseResult',
                isA<ClipReverseSuccess>(),
              ),
        ],
        verify: (bloc) {
          expect(
            bloc.state.clips.first.requireVideo.file?.path,
            equals('/reversed/clip-local_clip-local.mp4'),
          );
        },
      );

      // Splitting a reversed clip accumulates sourceStartOffset in
      // reversed-file coordinates and clears both cache paths, so
      // un-reversing goes through the render path. The fresh forward mirror
      // has no recording continuity — keeping the stale offset would
      // phase-shift its thumbnail raster by a meaningless amount.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'zeroes sourceStartOffset when un-reversing renders a fresh '
        'forward file',
        build: () => buildBloc(reverseClip: _fakeReverseClip),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              video: EditorVideo.file('/path/clip-local-reversed.mp4'),
              reversed: true,
              sourceStartOffset: const Duration(milliseconds: 1300),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isReversing,
            'isReversing',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.clips.first.reversed, 'reversed', isFalse)
              .having(
                (s) => s.clips.first.sourceStartOffset,
                'sourceStartOffset',
                Duration.zero,
              ),
        ],
      );

      // The baked reversed file starts at zero, so a forward → reversed render
      // drops any prior sourceStartOffset too — the standalone reversed clip
      // anchors its thumbnail raster at the new file's start.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'zeroes sourceStartOffset when reversing a forward clip into a '
        'baked standalone file',
        build: () => buildBloc(reverseClip: _fakeReverseClip),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              sourceStartOffset: const Duration(milliseconds: 1300),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isReversing,
            'isReversing',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.clips.first.reversed, 'reversed', isTrue)
              .having(
                (s) => s.clips.first.sourceStartOffset,
                'sourceStartOffset',
                Duration.zero,
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits failure result and reports unexpected errors when the reverse '
        'render throws',
        build: () => buildBloc(
          reverseClip: ({required sourceClip, required renderId}) async {
            throw StateError('reverse render failed');
          },
        ),
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isReversing,
            'isReversing',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isReversing, 'isReversing', isFalse)
              .having((s) => s.reversingClipId, 'reversingClipId', isNull)
              .having(
                (s) => s.lastReverseResult,
                'lastReverseResult',
                isA<ClipReverseFailure>(),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having((r) => r.unwrap(), 'unwrap', isA<StateError>())
              .having((r) => r.context, 'context', '_onClipReverseRequested'),
        ],
      );

      test(
        'discards reverse result when source clip is removed in-flight',
        () async {
          final completer = Completer<EditorVideo>();
          final queued = <String>[];
          final clip = _createClipWithFile();
          final bloc = buildBloc(
            reverseClip: ({required sourceClip, required renderId}) =>
                completer.future,
            deferFileCleanup: (paths) =>
                queued.addAll(paths.whereType<String>()),
          );

          bloc.add(ClipEditorInitialized([clip]));
          await Future<void>.delayed(Duration.zero);

          bloc.add(const ClipEditorClipReverseRequested(clipId: 'clip-local'));
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.isReversing, isTrue);

          bloc.add(const ClipEditorClipRemoved('clip-local'));
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.clips, isEmpty);

          completer.complete(EditorVideo.file('/reversed/discarded.mp4'));
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.isReversing, isFalse);
          expect(bloc.state.reversingClipId, isNull);
          expect(bloc.state.clips, isEmpty);
          expect(bloc.state.lastReverseResult, isA<ClipReverseDiscarded>());
          // Render never landed on a clip — session cleanup is the only reaper.
          expect(queued, ['/reversed/discarded.mp4']);

          await bloc.close();
        },
      );
    });

    group('ClipEditorChromaKeyRequested', () {
      const key = ClipChromaKey(key: ChromaKey.greenScreen());

      blocTest<ClipEditorBloc, ClipEditorState>(
        'swaps the clip video for the keyed render',
        build: () => buildBloc(
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async => (
                video: EditorVideo.file('/path/keyed.mp4'),
                source: sourceClip.chromaKeySourcePath ?? '/path/clip-1.mp4',
              ),
        ),
        seed: () => ClipEditorState(clips: [_createClip()]),
        act: (bloc) => bloc.add(
          const ClipEditorChromaKeyRequested(clipId: 'clip-1', chromaKey: key),
        ),
        expect: () => [
          // The clip id and the render id are separate on purpose: the screen
          // matches the first against its own clip to decide whether to block,
          // and subscribes to the renderer's progress under the second.
          // Collapsing them leaves the overlay watching the wrong id.
          isA<ClipEditorState>()
              .having((s) => s.isChromaKeying, 'isChromaKeying', isTrue)
              .having((s) => s.chromaKeyingClipId, 'clipId', 'clip-1')
              .having(
                (s) => s.chromaKeyingRenderId,
                'renderId',
                ChromaKeyBakeService.renderIdFor('clip-1'),
              ),
          isA<ClipEditorState>()
              .having(
                (s) => s.clips.single.video?.file?.path,
                'video',
                '/path/keyed.mp4',
              )
              .having((s) => s.isChromaKeying, 'isChromaKeying', isFalse)
              .having(
                (s) => s.lastChromaKeyResult,
                'lastChromaKeyResult',
                isA<ChromaKeySuccess>(),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'records the settings and the footage they were applied to',
        build: () => buildBloc(
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async => (
                video: EditorVideo.file('/path/keyed.mp4'),
                source: '/path/clip-1.mp4',
              ),
        ),
        seed: () => ClipEditorState(clips: [_createClip()]),
        act: (bloc) => bloc.add(
          const ClipEditorChromaKeyRequested(clipId: 'clip-1', chromaKey: key),
        ),
        verify: (bloc) {
          // Re-opening the editor restores these instead of starting over, and
          // re-keying renders from the recorded source rather than stacking a
          // second key on already-baked pixels.
          expect(bloc.state.clips.single.chromaKey, key);
          expect(
            bloc.state.clips.single.chromaKeySourcePath,
            '/path/clip-1.mp4',
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        're-keys from the recorded source, not the baked video',
        build: () => buildBloc(
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async {
                // The service resolves this itself; asserting the clip carries
                // it is what proves the second pass starts from clean footage.
                expect(sourceClip.chromaKeySourcePath, '/path/original.mp4');
                return (
                  video: EditorVideo.file('/path/keyed-again.mp4'),
                  source: '/path/original.mp4',
                );
              },
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClip().copyWith(
              video: EditorVideo.file('/path/keyed.mp4'),
              chromaKey: key,
              chromaKeySourcePath: '/path/original.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorChromaKeyRequested(clipId: 'clip-1', chromaKey: key),
        ),
        verify: (bloc) => expect(
          bloc.state.clips.single.chromaKeySourcePath,
          '/path/original.mp4',
        ),
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clears the cached reverse paths so a later reverse keeps the key',
        build: () => buildBloc(
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async => (
                video: EditorVideo.file('/path/keyed.mp4'),
                source: sourceClip.chromaKeySourcePath ?? '/path/clip-1.mp4',
              ),
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClip().copyWith(
              forwardVideoPath: '/path/forward.mp4',
              reversedVideoPath: '/path/reversed.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorChromaKeyRequested(clipId: 'clip-1', chromaKey: key),
        ),
        verify: (bloc) {
          // Those files still have the screen in them; restoring one would
          // silently undo the key.
          expect(bloc.state.clips.single.forwardVideoPath, isNull);
          expect(bloc.state.clips.single.reversedVideoPath, isNull);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'keeps the original clip when the render fails',
        build: () => buildBloc(
          bakeChromaKey: ({
            required sourceClip,
            required chromaKey,
            required renderId,
          }) async => throw Exception('render failed'),
        ),
        seed: () => ClipEditorState(clips: [_createClip()]),
        act: (bloc) => bloc.add(
          const ClipEditorChromaKeyRequested(clipId: 'clip-1', chromaKey: key),
        ),
        errors: () => [isA<Exception>()],
        verify: (bloc) {
          expect(bloc.state.clips.single.video?.file?.path, '/path/clip-1.mp4');
          expect(bloc.state.isChromaKeying, isFalse);
          expect(bloc.state.lastChromaKeyResult, isA<ChromaKeyFailure>());
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'treats a missing backdrop clip as expected IO',
        build: () => buildBloc(
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async => throw const ChromaKeyBackdropMissingException(
                '/path/deleted-backdrop.mp4',
              ),
        ),
        seed: () => ClipEditorState(clips: [_createClip()]),
        act: (bloc) => bloc.add(
          const ClipEditorChromaKeyRequested(clipId: 'clip-1', chromaKey: key),
        ),
        errors: () => [
          isA<ChromaKeyBackdropMissingException>().having(
            (e) => e,
            'reportable marker',
            isNot(isA<ReportableError>()),
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.clips.single.video?.file?.path, '/path/clip-1.mp4');
          expect(bloc.state.isChromaKeying, isFalse);
          expect(bloc.state.lastChromaKeyResult, isA<ChromaKeyFailure>());
        },
      );

      final discardedChromaPaths = <String>[];
      blocTest<ClipEditorBloc, ClipEditorState>(
        'discards the render when the clip is gone',
        build: () => buildBloc(
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async {
                await Future<void>.delayed(const Duration(milliseconds: 10));
                return (
                  video: EditorVideo.file('/path/keyed.mp4'),
                  source: '/path/clip-1.mp4',
                );
              },
          deferFileCleanup: (paths) =>
              discardedChromaPaths.addAll(paths.whereType<String>()),
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClip(),
            _createClip(id: 'clip-2'),
          ],
        ),
        act: (bloc) async {
          bloc.add(
            const ClipEditorChromaKeyRequested(
              clipId: 'clip-1',
              chromaKey: key,
            ),
          );
          await Future<void>.delayed(Duration.zero);
          bloc.add(const ClipEditorClipRemoved('clip-1'));
        },
        // Outlast the fake render so `verify` sees the settled state.
        wait: const Duration(milliseconds: 50),
        verify: (bloc) {
          expect(bloc.state.lastChromaKeyResult, isA<ChromaKeyDiscarded>());
          // Queues the baked output only — not the pre-key source path.
          expect(discardedChromaPaths, ['/path/keyed.mp4']);
        },
      );
    });

    group('ClipEditorChromaKeyRemoved', () {
      late Directory tempDir;
      late String sourcePath;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('chroma_remove_test');
        sourcePath = '${tempDir.path}/original.mp4';
        await File(sourcePath).writeAsBytes(const [0]);
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      DivineVideoClip keyedClip() => _createClip().copyWith(
        video: EditorVideo.file('/path/keyed.mp4'),
        chromaKey: const ClipChromaKey(key: ChromaKey.greenScreen()),
        chromaKeySourcePath: sourcePath,
      );

      final removeCleanupPaths = <String>[];
      blocTest<ClipEditorBloc, ClipEditorState>(
        'restores the pre-key footage without rendering',
        build: () => buildBloc(
          bakeChromaKey: ({
            required sourceClip,
            required chromaKey,
            required renderId,
          }) async => throw StateError('removal must not render'),
          deferFileCleanup: (paths) =>
              removeCleanupPaths.addAll(paths.whereType<String>()),
        ),
        seed: () => ClipEditorState(clips: [keyedClip()]),
        act: (bloc) => bloc.add(const ClipEditorChromaKeyRemoved('clip-1')),
        verify: (bloc) {
          final clip = bloc.state.clips.single;
          expect(clip.video?.file?.path, sourcePath);
          expect(clip.chromaKey, isNull);
          expect(clip.chromaKeySourcePath, isNull);
          expect(bloc.state.lastChromaKeyResult, isA<ChromaKeySuccess>());
          // The keyed render is what this drops; the pre-key file is what the
          // clip now plays, so queuing it would be queuing the live video.
          expect(removeCleanupPaths, contains('/path/keyed.mp4'));
          expect(removeCleanupPaths, isNot(contains(sourcePath)));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'reports a failure when the pre-key footage is gone',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [keyedClip().copyWith(chromaKeySourcePath: '/gone.mp4')],
        ),
        act: (bloc) => bloc.add(const ClipEditorChromaKeyRemoved('clip-1')),
        verify: (bloc) {
          // Nothing to restore, so the clip must keep the keyed video rather
          // than be pointed at a file that does not exist.
          expect(bloc.state.clips.single.video?.file?.path, '/path/keyed.mp4');
          // Its own result type, not the bake's: the two drive opposite copy,
          // and reusing ChromaKeyFailure told the user we could not *apply* a
          // key they were trying to remove.
          expect(bloc.state.lastChromaKeyResult, isA<ChromaKeyRemoveFailure>());
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'ignores a clip that carries no key',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createClip()]),
        act: (bloc) => bloc.add(const ClipEditorChromaKeyRemoved('clip-1')),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorStopMotionFrameTransformed', () {
      final bytes = Uint8List.fromList([1, 2, 3]);

      blocTest<ClipEditorBloc, ClipEditorState>(
        'repoints only the edited still, keeping its hold and the others',
        build: () => buildBloc(
          writeStopMotionFrame: (_) async => 'transformed.jpg',
        ),
        seed: () => ClipEditorState(clips: [_createStopMotionClip()]),
        act: (bloc) => bloc.add(
          ClipEditorStopMotionFrameTransformed(
            clipId: 'sm',
            frameIndex: 1,
            imageBytes: bytes,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.clips.first.stopMotionFrames,
            'frames',
            [
              isA<StopMotionClipFrame>().having(
                (f) => f.path,
                'path',
                'sm-0.jpg',
              ),
              isA<StopMotionClipFrame>()
                  .having((f) => f.path, 'path', 'transformed.jpg')
                  .having(
                    (f) => f.duration,
                    'hold',
                    StopMotionFrameOps.framesPerImageToDuration(1),
                  ),
              isA<StopMotionClipFrame>().having(
                (f) => f.path,
                'path',
                'sm-2.jpg',
              ),
            ],
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'leaves the composition length alone — only the pixels changed',
        build: () => buildBloc(
          writeStopMotionFrame: (_) async => 'transformed.jpg',
        ),
        seed: () => ClipEditorState(clips: [_createStopMotionClip()]),
        act: (bloc) => bloc.add(
          ClipEditorStopMotionFrameTransformed(
            clipId: 'sm',
            frameIndex: 0,
            imageBytes: bytes,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.clips.first.duration,
            'duration',
            _createStopMotionClip().duration,
          ),
        ],
      );

      test('writes the change to editor history so undo can reach the old '
          'still', () async {
        var invalidated = 0;
        final bloc = buildBloc(
          writeStopMotionFrame: (_) async => 'transformed.jpg',
          onFinalClipInvalidated: () => invalidated++,
        )..emit(ClipEditorState(clips: [_createStopMotionClip()]));

        bloc.add(
          ClipEditorStopMotionFrameTransformed(
            clipId: 'sm',
            frameIndex: 0,
            imageBytes: bytes,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(invalidated, 1);
        await bloc.close();
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'reports a failure instead of repointing when the write throws',
        build: () => buildBloc(
          writeStopMotionFrame: (_) async =>
              throw const FileSystemException('disk full'),
        ),
        seed: () => ClipEditorState(clips: [_createStopMotionClip()]),
        act: (bloc) => bloc.add(
          ClipEditorStopMotionFrameTransformed(
            clipId: 'sm',
            frameIndex: 0,
            imageBytes: bytes,
          ),
        ),
        errors: () => [isA<FileSystemException>()],
        expect: () => [
          isA<ClipEditorState>()
              .having(
                (s) => s.lastTransformResult,
                'result',
                isA<ClipTransformFrameFailure>(),
              )
              .having(
                (s) => s.clips.first.stopMotionFrames!.first.path,
                'untouched still',
                'sm-0.jpg',
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'ignores an out-of-range still without writing anything',
        build: () => buildBloc(
          writeStopMotionFrame: (_) async =>
              throw StateError('must not be called'),
        ),
        seed: () => ClipEditorState(clips: [_createStopMotionClip()]),
        act: (bloc) => bloc.add(
          ClipEditorStopMotionFrameTransformed(
            clipId: 'sm',
            frameIndex: 9,
            imageBytes: bytes,
          ),
        ),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'reports a failure when the editor rasterized nothing',
        // `CropRotateEditor.done` retries its screenshot, then closes with an
        // empty list anyway. Writing it would point the frame at a broken
        // image; dropping it silently would leave the user with an unchanged
        // still and no explanation after a visible wait.
        build: () => buildBloc(
          writeStopMotionFrame: (_) async =>
              throw StateError('must not be called'),
        ),
        seed: () => ClipEditorState(clips: [_createStopMotionClip()]),
        act: (bloc) => bloc.add(
          ClipEditorStopMotionFrameTransformed(
            clipId: 'sm',
            frameIndex: 0,
            imageBytes: Uint8List(0),
          ),
        ),
        // Rejected before the write, not by it: reaching the writer and
        // failing there would produce the same state off a thrown error.
        errors: () => <Object>[],
        expect: () => [
          isA<ClipEditorState>()
              .having(
                (s) => s.lastTransformResult,
                'result',
                isA<ClipTransformFrameFailure>(),
              )
              .having(
                (s) => s.clips.first.stopMotionFrames!.first.path,
                'untouched still',
                'sm-0.jpg',
              ),
        ],
      );

      test('queues the still it replaced for cleanup', () async {
        final queued = <String>[];
        final bloc = buildBloc(
          writeStopMotionFrame: (_) async => 'transformed.jpg',
          deferFileCleanup: (paths) => queued.addAll(paths.whereType<String>()),
        )..emit(ClipEditorState(clips: [_createStopMotionClip()]));

        bloc.add(
          ClipEditorStopMotionFrameTransformed(
            clipId: 'sm',
            frameIndex: 1,
            imageBytes: bytes,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(queued, ['sm-1.jpg']);
        await bloc.close();
      });

      test('keeps the replaced still while a duplicate of it is on the '
          'timeline', () async {
        // Duplicating a still shares its file, so the copy is the only thing
        // between "reclaim the superseded frame" and "delete a frame the user
        // is still looking at".
        final queued = <String>[];
        final withDuplicate = StopMotionFrameOps.clipWithFrames(
          _createStopMotionClip(),
          [
            ..._createStopMotionClip().stopMotionFrames!.take(2),
            _createStopMotionClip().stopMotionFrames![1],
          ],
        );
        final bloc = buildBloc(
          writeStopMotionFrame: (_) async => 'transformed.jpg',
          deferFileCleanup: (paths) => queued.addAll(paths.whereType<String>()),
        )..emit(ClipEditorState(clips: [withDuplicate]));

        bloc.add(
          ClipEditorStopMotionFrameTransformed(
            clipId: 'sm',
            frameIndex: 1,
            imageBytes: bytes,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.clips.first.stopMotionFrames!.map((f) => f.path), [
          'sm-0.jpg',
          'transformed.jpg',
          'sm-1.jpg',
        ]);
        expect(queued, isEmpty);
        await bloc.close();
      });

      test(
        'discards the write when the still moved out from under it',
        () async {
          // The write is awaited, so a frame delete can land in between. The
          // index alone then names a different still, and repointing it would
          // apply the crop to whatever moved in.
          final queued = <String>[];
          final gate = Completer<String>();
          final bloc = buildBloc(
            writeStopMotionFrame: (_) => gate.future,
            deferFileCleanup: (paths) =>
                queued.addAll(paths.whereType<String>()),
          )..emit(ClipEditorState(clips: [_createStopMotionClip()]));

          bloc.add(
            ClipEditorStopMotionFrameTransformed(
              clipId: 'sm',
              frameIndex: 1,
              imageBytes: bytes,
            ),
          );
          await Future<void>.delayed(Duration.zero);

          // Frame 0 goes away, so the still the user transformed slides to 0 and
          // index 1 now holds the one that was at 2.
          final shifted = StopMotionFrameOps.clipWithFrames(
            bloc.state.clips.first,
            StopMotionFrameOps.removeFrame(
              bloc.state.clips.first.stopMotionFrames!,
              0,
            ),
          );
          bloc.emit(ClipEditorState(clips: [shifted]));

          gate.complete('transformed.jpg');
          await Future<void>.delayed(Duration.zero);

          expect(
            bloc.state.clips.first.stopMotionFrames!.map((f) => f.path),
            ['sm-1.jpg', 'sm-2.jpg'],
          );
          // The abandoned render never reached a clip, so this queue is the
          // only thing that can still name it.
          expect(queued, ['transformed.jpg']);
          await bloc.close();
        },
      );

      test(
        'discards the write when the whole clip is removed in-flight',
        () async {
          final queued = <String>[];
          final gate = Completer<String>();
          final bloc = buildBloc(
            writeStopMotionFrame: (_) => gate.future,
            deferFileCleanup: (paths) =>
                queued.addAll(paths.whereType<String>()),
          )..emit(ClipEditorState(clips: [_createStopMotionClip()]));

          bloc.add(
            ClipEditorStopMotionFrameTransformed(
              clipId: 'sm',
              frameIndex: 1,
              imageBytes: bytes,
            ),
          );
          await Future<void>.delayed(Duration.zero);

          bloc.emit(const ClipEditorState());
          gate.complete('transformed.jpg');
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.clips, isEmpty);
          expect(queued, ['transformed.jpg']);
          await bloc.close();
        },
      );
    });

    group('ClipEditorClipTransformRequested', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits no-local-file result when clip has no local file',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createClipNoFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip-no-file',
            transform: ExportTransform(),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.lastTransformResult,
            'lastTransformResult',
            isA<ClipTransformNoLocalFile>(),
          ),
        ],
      );

      final transformCleanupPaths = <String>[];
      blocTest<ClipEditorBloc, ClipEditorState>(
        'renders transformed clip, swaps the file, and clears reverse caches',
        build: () => buildBloc(
          transformClip: _fakeTransformClip,
          deferFileCleanup: (paths) =>
              transformCleanupPaths.addAll(paths.whereType<String>()),
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              forwardVideoPath: '/path/clip-local.mp4',
              reversedVideoPath: '/reversed/clip-local.mp4',
              chromaKey: const ClipChromaKey(key: ChromaKey.greenScreen()),
              chromaKeySourcePath: '/path/pre-key.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip-local',
            transform: ExportTransform(),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isTransforming, 'isTransforming', isTrue)
              .having(
                (s) => s.transformingClipId,
                'transformingClipId',
                'clip-local_transform',
              ),
          isA<ClipEditorState>()
              .having((s) => s.isTransforming, 'isTransforming', isFalse)
              .having((s) => s.transformingClipId, 'transformingClipId', isNull)
              .having(
                (s) => s.clips.first.forwardVideoPath,
                'forwardVideoPath',
                isNull,
              )
              .having(
                (s) => s.clips.first.reversedVideoPath,
                'reversedVideoPath',
                isNull,
              )
              // The transform re-rendered the geometry, so re-keying from the
              // recorded pre-key file would silently drop the crop. Both halves
              // of the key have to go with it.
              .having((s) => s.clips.first.chromaKey, 'chromaKey', isNull)
              .having(
                (s) => s.clips.first.chromaKeySourcePath,
                'chromaKeySourcePath',
                isNull,
              )
              .having(
                (s) => s.lastTransformResult,
                'lastTransformResult',
                isA<ClipTransformSuccess>(),
              ),
        ],
        verify: (bloc) {
          expect(
            bloc.state.clips.first.requireVideo.file?.path,
            equals('/transformed/clip-local_clip-local_transform.mp4'),
          );
          expect(transformCleanupPaths, contains('/path/pre-key.mp4'));
        },
      );

      final supersededPaths = <String>[];
      blocTest<ClipEditorBloc, ClipEditorState>(
        'queues the render it superseded, cached reverses included',
        build: () => buildBloc(
          transformClip: _fakeTransformClip,
          deferFileCleanup: (paths) =>
              supersededPaths.addAll(paths.whereType<String>()),
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              // Distinct from `video` (`/path/clip-local.mp4`) so the
              // forward-cache yield is what makes the expectation pass —
              // a same-path seed would already be covered by the video yield.
              forwardVideoPath: '/forward/clip-local-cache.mp4',
              reversedVideoPath: '/reversed/clip-local.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip-local',
            transform: ExportTransform(),
          ),
        ),
        verify: (_) {
          expect(
            supersededPaths,
            containsAll(<String>[
              '/path/clip-local.mp4',
              '/forward/clip-local-cache.mp4',
              '/reversed/clip-local.mp4',
            ]),
          );
          expect(
            supersededPaths,
            isNot(contains('/transformed/clip-local_clip-local_transform.mp4')),
          );
        },
      );

      final sharedFilePaths = <String>[];
      blocTest<ClipEditorBloc, ClipEditorState>(
        'keeps the superseded file when a second clip still plays it',
        // Duplicating a clip shares its file. The database check the reaper
        // runs lags the editor by an autosave, so the live clip list is what
        // stands between reclaiming a render and deleting one still in use.
        build: () => buildBloc(
          transformClip: _fakeTransformClip,
          deferFileCleanup: (paths) =>
              sharedFilePaths.addAll(paths.whereType<String>()),
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile(),
            _createClipWithFile(id: 'clip-copy').copyWith(
              video: EditorVideo.file('/path/clip-local.mp4'),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip-local',
            transform: ExportTransform(),
          ),
        ),
        verify: (_) => expect(sharedFilePaths, isEmpty),
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits failure and reports a Reportable on a render error',
        build: () => buildBloc(
          transformClip: ({
            required sourceClip,
            required transform,
            required renderId,
          }) async => throw StateError('transform render failed'),
        ),
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip-local',
            transform: ExportTransform(),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isTransforming,
            'isTransforming',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isTransforming, 'isTransforming', isFalse)
              .having((s) => s.transformingClipId, 'transformingClipId', isNull)
              .having(
                (s) => s.lastTransformResult,
                'lastTransformResult',
                isA<ClipTransformFailure>(),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having((r) => r.unwrap(), 'unwrap', isA<StateError>())
              .having((r) => r.context, 'context', '_onClipTransformRequested'),
        ],
      );

      test(
        'discards transform result when source clip is removed in-flight',
        () async {
          final completer = Completer<EditorVideo>();
          final queued = <String>[];
          final clip = _createClipWithFile();
          final bloc = buildBloc(
            transformClip: ({
              required sourceClip,
              required transform,
              required renderId,
            }) => completer.future,
            deferFileCleanup: (paths) =>
                queued.addAll(paths.whereType<String>()),
          );

          bloc.add(ClipEditorInitialized([clip]));
          await Future<void>.delayed(Duration.zero);

          bloc.add(
            const ClipEditorClipTransformRequested(
              clipId: 'clip-local',
              transform: ExportTransform(),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.isTransforming, isTrue);

          bloc.add(const ClipEditorClipRemoved('clip-local'));
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.clips, isEmpty);

          completer.complete(EditorVideo.file('/transformed/discarded.mp4'));
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.isTransforming, isFalse);
          expect(bloc.state.transformingClipId, isNull);
          expect(bloc.state.clips, isEmpty);
          expect(bloc.state.lastTransformResult, isA<ClipTransformDiscarded>());
          expect(queued, ['/transformed/discarded.mp4']);

          await bloc.close();
        },
      );

      test(
        'queues the transform output when the bloc is closed mid-render',
        () async {
          // Screen dispose closes the bloc while a long encode can still finish.
          // The new file is on disk either way and must still reach deferred
          // cleanup — the path that used to drop on `if (!mounted) return`.
          final completer = Completer<EditorVideo>();
          final queued = <String>[];
          final bloc = buildBloc(
            transformClip: ({
              required sourceClip,
              required transform,
              required renderId,
            }) => completer.future,
            deferFileCleanup: (paths) =>
                queued.addAll(paths.whereType<String>()),
          );

          bloc.add(ClipEditorInitialized([_createClipWithFile()]));
          await Future<void>.delayed(Duration.zero);

          bloc.add(
            const ClipEditorClipTransformRequested(
              clipId: 'clip-local',
              transform: ExportTransform(),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.isTransforming, isTrue);

          final closed = bloc.close();
          completer.complete(EditorVideo.file('/transformed/after-close.mp4'));
          await closed;
          await Future<void>.delayed(Duration.zero);

          expect(queued, ['/transformed/after-close.mp4']);
        },
      );
    });

    // =========================================================
    // EVENT EQUALITY
    // =========================================================

    group('event equality', () {
      test('$ClipEditorInitialized with same clips are equal', () {
        final clips = [_createClip()];
        expect(
          ClipEditorInitialized(clips),
          equals(ClipEditorInitialized(clips)),
        );
      });

      test('$ClipEditorClipRemoved with same id are equal', () {
        expect(
          const ClipEditorClipRemoved('x'),
          equals(const ClipEditorClipRemoved('x')),
        );
      });

      test('$ClipEditorClipSelected with same index are equal', () {
        expect(
          const ClipEditorClipSelected(2),
          equals(const ClipEditorClipSelected(2)),
        );
      });

      test('$ClipEditorSplitPositionChanged with same position are equal', () {
        expect(
          const ClipEditorSplitPositionChanged(Duration(seconds: 1)),
          equals(const ClipEditorSplitPositionChanged(Duration(seconds: 1))),
        );
      });

      test('$ClipEditorClipReverseRequested with same id are equal', () {
        expect(
          const ClipEditorClipReverseRequested(clipId: 'x'),
          equals(const ClipEditorClipReverseRequested(clipId: 'x')),
        );
      });

      test('$ClipEditorOriginalClipReplaced with same values are equal', () {
        final clip1 = _createClip(id: 'start');
        final clip2 = _createClip(id: 'end');
        expect(
          ClipEditorOriginalClipReplaced(
            sourceClipId: 'src',
            startClip: clip1,
            endClip: clip2,
          ),
          equals(
            ClipEditorOriginalClipReplaced(
              sourceClipId: 'src',
              startClip: clip1,
              endClip: clip2,
            ),
          ),
        );
      });

      test('singleton events are equal', () {
        expect(
          const ClipEditorEditingStarted(),
          equals(const ClipEditorEditingStarted()),
        );
        expect(
          const ClipEditorEditingStopped(),
          equals(const ClipEditorEditingStopped()),
        );
        expect(
          const ClipEditorEditingToggled(),
          equals(const ClipEditorEditingToggled()),
        );
        expect(
          const ClipEditorSplitRequested(),
          equals(const ClipEditorSplitRequested()),
        );
        expect(
          const ClipEditorTrimDragStarted(),
          equals(const ClipEditorTrimDragStarted()),
        );
        expect(
          const ClipEditorTrimDragEnded(),
          equals(const ClipEditorTrimDragEnded()),
        );
        expect(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            isStart: true,
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
          ),
          equals(
            const ClipEditorTrimUpdated(
              clipId: 'a',
              isStart: true,
              trimStart: Duration(seconds: 1),
              trimEnd: Duration.zero,
            ),
          ),
        );
      });
    });

    // =========================================================
    // AUDIO EXTRACTION
    // =========================================================

    group('ClipEditorAudioExtractionRequested', () {
      late _MockAudioExtractionService mockService;

      setUp(() {
        mockService = _MockAudioExtractionService();
        when(
          () => mockService.cleanupAudioFile(any()),
        ).thenAnswer((_) async {});
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits ClipAudioExtractionNoLocalFile when clip has no local file',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createClipNoFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.lastAudioExtraction,
            'lastAudioExtraction',
            isA<ClipAudioExtractionNoLocalFile>(),
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits isExtractingAudio then success with muted clip and correct endTime',
        build: () {
          when(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isExtractingAudio, 'isExtractingAudio', isTrue)
              .having(
                (s) => s.extractingAudioClipId,
                'extractingAudioClipId',
                'clip-local',
              ),
          isA<ClipEditorState>()
              .having((s) => s.isExtractingAudio, 'isExtractingAudio', isFalse)
              .having(
                (s) => s.extractingAudioClipId,
                'extractingAudioClipId',
                isNull,
              )
              .having((s) => s.clips.first.volume, 'volume', 0)
              .having(
                (s) => s.lastAudioExtraction,
                'lastAudioExtraction',
                isA<ClipAudioExtractionSuccess>(),
              ),
        ],
        verify: (bloc) {
          final result =
              bloc.state.lastAudioExtraction! as ClipAudioExtractionSuccess;
          final clip = _createClipWithFile();
          // endTime must use playbackDuration, not raw duration.
          expect(result.audioEvent.endTime, equals(clip.playbackDuration));
          expect(result.audioEvent.duration, equals(5.0));
          expect(result.audioEvent.startOffset, equals(clip.trimStart));
          // Extracted audio is anchored to its source clip by default.
          expect(result.audioEvent.anchorClipId, equals(clip.id));
          expect(result.audioEvent.isAnchored, isTrue);
          verify(
            () => mockService.extractAudioForDraft(
              videoPath: '/path/clip-local.mp4',
              speed: any(named: 'speed'),
            ),
          ).called(1);
        },
      );

      // A queued extraction must hit the clip captured at dispatch, not
      // whatever is selected when the (sequential) handler runs.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'extracts audio from the clip named by the event, not the selection',
        build: () {
          when(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile(id: 'a'),
            _createClipWithFile(id: 'b'),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(
            clipId: 'b',
            clipTitle: 'Test',
          ),
        ),
        wait: const Duration(milliseconds: 1),
        verify: (bloc) {
          final clips = bloc.state.clips;
          // 'b' (named by the event) is muted; 'a' (selected) is untouched.
          expect(clips.firstWhere((c) => c.id == 'b').volume, equals(0));
          expect(clips.firstWhere((c) => c.id == 'a').volume, equals(1.0));
          verify(
            () => mockService.extractAudioForDraft(
              videoPath: '/path/b.mp4',
              speed: any(named: 'speed'),
            ),
          ).called(1);
        },
      );

      // Regression: a rapid double-tap of Extract on the same clip enqueues two
      // requests (sequential handler). The second must be deduped once the
      // first mutes the clip, so it does not extract again and add a duplicate
      // audio track.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'dedupes a queued re-extraction of an already-extracted clip',
        build: () {
          when(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(clips: [_createClipWithFile(id: 'b')]),
        act: (bloc) => bloc
          ..add(
            const ClipEditorAudioExtractionRequested(
              clipId: 'b',
              clipTitle: 'Test',
            ),
          )
          ..add(
            const ClipEditorAudioExtractionRequested(
              clipId: 'b',
              clipTitle: 'Test',
            ),
          ),
        wait: const Duration(milliseconds: 1),
        verify: (bloc) {
          expect(bloc.state.clips.single.volume, equals(0));
          expect(bloc.state.extractedAudioClipIds, contains('b'));
          // Extraction ran exactly once despite two queued requests.
          verify(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).called(1);
        },
      );

      // A deliberate re-extraction after a manual un-mute must still run — the
      // dedupe guard is lifted once the clip's volume is restored.
      blocTest<ClipEditorBloc, ClipEditorState>(
        're-extracts after the clip is manually un-muted',
        build: () {
          when(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(
          clips: [_createClipWithFile(id: 'b')],
          extractedAudioClipIds: const {'b'},
        ),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(
            clipId: 'b',
            clipTitle: 'Test',
          ),
        ),
        wait: const Duration(milliseconds: 1),
        verify: (bloc) {
          // 'b' seeded at default volume 1.0 (un-muted), so extraction runs
          // even though it is already in extractedAudioClipIds.
          expect(bloc.state.clips.single.volume, equals(0));
          verify(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).called(1);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'uses playback duration and forwards speed for extracted source clip',
        build: () {
          when(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 2.5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () =>
            ClipEditorState(clips: [_createClipWithFile(playbackSpeed: 2.0)]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        verify: (bloc) {
          final result =
              bloc.state.lastAudioExtraction! as ClipAudioExtractionSuccess;
          final clip = _createClipWithFile(playbackSpeed: 2.0);
          expect(result.audioEvent.startTime, equals(Duration.zero));
          expect(result.audioEvent.endTime, equals(clip.playbackDuration));
          expect(result.audioEvent.duration, equals(2.5));
          expect(
            result.audioEvent.startOffset,
            equals(clip.sourceDurationToPlaybackDuration(clip.trimStart)),
          );
          expect(
            result.audioEvent.endTime! - result.audioEvent.startTime,
            equals(clip.playbackDuration),
          );
          verify(
            () => mockService.extractAudioForDraft(
              videoPath: '/path/clip-local.mp4',
              speed: 2.0,
            ),
          ).called(1);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'uses playback-time offsets when an extracted clip follows a slowed clip',
        build: () {
          when(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(
          clips: [
            _createClip(
              id: 'slow',
              duration: const Duration(seconds: 4),
              playbackSpeed: 0.5,
            ),
            _createClipWithFile(id: 'target'),
          ],
          currentClipIndex: 1,
        ),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        verify: (bloc) {
          final result =
              bloc.state.lastAudioExtraction! as ClipAudioExtractionSuccess;
          final targetClip = _createClipWithFile(id: 'target');
          expect(
            result.audioEvent.startTime,
            equals(const Duration(seconds: 8)),
          );
          expect(
            result.audioEvent.endTime,
            equals(const Duration(milliseconds: 11500)),
          );
          expect(
            result.audioEvent.endTime! - result.audioEvent.startTime,
            equals(targetClip.playbackDuration),
          );
        },
      );

      test('discards extraction result when clip speed changes during '
          'in-flight extraction', () async {
        final completer = Completer<AudioExtractionResult>();
        when(
          () => mockService.extractAudioForDraft(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        ).thenAnswer((_) => completer.future);

        final clip = _createClipWithFile(playbackSpeed: 2.0);
        final bloc = buildBloc(audioExtractionService: mockService);

        bloc.add(ClipEditorInitialized([clip]));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ClipEditorAudioExtractionRequested(clipTitle: 'Test'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.isExtractingAudio, isTrue);

        bloc.add(
          ClipEditorClipUpdated(
            clipId: clip.id,
            clip: clip.copyWith(playbackSpeed: 0.5),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        completer.complete(
          const AudioExtractionResult(
            audioFilePath: '/tmp/stale-speed-audio.wav',
            duration: 2.5,
            fileSize: 12345,
            sha256Hash: 'abc123',
            mimeType: 'audio/wav',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.isExtractingAudio, isFalse);
        expect(bloc.state.clips.single.volume, equals(1));
        expect(
          bloc.state.lastAudioExtraction,
          isA<ClipAudioExtractionDiscarded>(),
        );
        verify(
          () => mockService.extractAudioForDraft(
            videoPath: '/path/clip-local.mp4',
            speed: 2.0,
          ),
        ).called(1);
        verify(
          () => mockService.cleanupAudioFile('/tmp/stale-speed-audio.wav'),
        ).called(1);

        await bloc.close();
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits isExtractingAudio then ClipAudioExtractionFailure on AudioExtractionException',
        build: () {
          when(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenThrow(const AudioExtractionException('Extraction failed'));
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isExtractingAudio,
            'isExtractingAudio',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isExtractingAudio, 'isExtractingAudio', isFalse)
              .having(
                (s) => s.lastAudioExtraction,
                'lastAudioExtraction',
                isA<ClipAudioExtractionFailure>(),
              ),
        ],
        errors: () => [isA<AudioExtractionException>()],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'wraps unexpected extraction errors in Reportable with context',
        build: () {
          when(
            () => mockService.extractAudioForDraft(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenThrow(StateError('boom'));
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isExtractingAudio,
            'isExtractingAudio',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isExtractingAudio, 'isExtractingAudio', isFalse)
              .having(
                (s) => s.lastAudioExtraction,
                'lastAudioExtraction',
                isA<ClipAudioExtractionFailure>(),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having((r) => r.unwrap(), 'unwrap', isA<StateError>())
              .having(
                (r) => r.context,
                'context',
                '_onAudioExtractionRequested',
              ),
        ],
      );

      // Regression test for Fix 1: the handler must re-read `state.clips` after
      // the await and abort when the source clip no longer exists.
      test('discards extraction result and emits ClipAudioExtractionDiscarded '
          'when source clip is removed during in-flight extraction', () async {
        final completer = Completer<AudioExtractionResult>();
        when(
          () => mockService.extractAudioForDraft(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        ).thenAnswer((_) => completer.future);

        final clip = _createClipWithFile();
        final bloc = buildBloc(audioExtractionService: mockService);

        // Bring bloc to the expected initial state via event.
        bloc.add(ClipEditorInitialized([clip]));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ClipEditorAudioExtractionRequested(clipTitle: 'Test'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.isExtractingAudio, isTrue);

        // Remove the clip while extraction is awaiting the service.
        bloc.add(ClipEditorClipRemoved(clip.id));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.clips, isEmpty);

        // Complete the service call — bloc must discard the stale result.
        completer.complete(
          const AudioExtractionResult(
            audioFilePath: '/tmp/audio.m4a',
            duration: 5,
            fileSize: 12345,
            sha256Hash: 'abc123',
            mimeType: 'audio/mp4',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.isExtractingAudio, isFalse);
        expect(
          bloc.state.clips,
          isEmpty,
          reason: 'deleted clip must not be resurrected by the result',
        );
        expect(
          bloc.state.lastAudioExtraction,
          isA<ClipAudioExtractionDiscarded>(),
        );
        verify(() => mockService.cleanupAudioFile('/tmp/audio.m4a')).called(1);

        await bloc.close();
      });
    });

    // =========================================================
    // MULTI-SELECT
    // =========================================================

    group('multi-select', () {
      // Backs the deferred merge fake in the mid-render discard test; assigned
      // in that test's act before the merge handler reads its future.
      late Completer<DivineVideoClip?> mergeCompleter;

      blocTest<ClipEditorBloc, ClipEditorState>(
        'starts multi-select with the initial clip pre-selected and exits '
        'editing',
        build: buildBloc,
        seed: () => ClipEditorState(clips: threeClips, isEditing: true),
        act: (bloc) => bloc.add(const ClipEditorMultiSelectStarted('b')),
        verify: (bloc) {
          expect(bloc.state.isMultiSelectMode, isTrue);
          expect(bloc.state.isEditing, isFalse);
          expect(bloc.state.selectedClipIds, equals({'b'}));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'ignores an unknown initial clip id',
        build: buildBloc,
        seed: () => ClipEditorState(clips: threeClips),
        act: (bloc) => bloc.add(const ClipEditorMultiSelectStarted('missing')),
        verify: (bloc) {
          expect(bloc.state.isMultiSelectMode, isTrue);
          expect(bloc.state.selectedClipIds, isEmpty);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'toggles clip membership in the selection',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a'},
        ),
        act: (bloc) => bloc
          ..add(const ClipEditorMultiSelectClipToggled('b'))
          ..add(const ClipEditorMultiSelectClipToggled('a')),
        verify: (bloc) {
          expect(bloc.state.selectedClipIds, equals({'b'}));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'cancel exits multi-select and clears the selection',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
        act: (bloc) => bloc.add(const ClipEditorMultiSelectCancelled()),
        verify: (bloc) {
          expect(bloc.state.isMultiSelectMode, isFalse);
          expect(bloc.state.selectedClipIds, isEmpty);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'removes the selected clips and exits multi-select',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'c'},
        ),
        act: (bloc) => bloc.add(const ClipEditorSelectedClipsRemoved()),
        verify: (bloc) {
          expect(bloc.state.clips.map((c) => c.id), equals(['b']));
          expect(bloc.state.isMultiSelectMode, isFalse);
          expect(bloc.state.selectedClipIds, isEmpty);
          // The widget layer commits the removal via this one-shot signal,
          // which carries the pre-removal clips for marker rebasing.
          final result = bloc.state.lastClipsRemovedResult;
          expect(result, isNotNull);
          expect(
            result!.previousClips.map((c) => c.id),
            equals(['a', 'b', 'c']),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does not remove clips when the selection covers the whole timeline',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b', 'c'},
        ),
        act: (bloc) => bloc.add(const ClipEditorSelectedClipsRemoved()),
        verify: (bloc) {
          expect(bloc.state.clips, hasLength(3));
          expect(bloc.state.isMultiSelectMode, isTrue);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'merges the selected clips into one at the earliest position',
        build: () => buildBloc(mergeClips: _fakeMergeClips),
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'c'},
        ),
        act: (bloc) => bloc.add(const ClipEditorSelectedClipsMergeRequested()),
        verify: (bloc) {
          expect(
            bloc.state.clips.map((c) => c.id),
            equals(['merged-clip', 'b']),
          );
          expect(bloc.state.isMerging, isFalse);
          expect(bloc.state.isMultiSelectMode, isFalse);
          expect(bloc.state.selectedClipIds, isEmpty);
          expect(bloc.state.currentClipIndex, equals(0));
          final result = bloc.state.lastMergeResult;
          expect(result, isA<ClipMergeSuccess>());
          expect(
            (result! as ClipMergeSuccess).previousClips.map((c) => c.id),
            equals(['a', 'b', 'c']),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does nothing when fewer than two clips are selected',
        build: () => buildBloc(mergeClips: _fakeMergeClips),
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a'},
        ),
        act: (bloc) => bloc.add(const ClipEditorSelectedClipsMergeRequested()),
        verify: (bloc) {
          expect(bloc.state.clips, hasLength(3));
          expect(bloc.state.isMerging, isFalse);
          expect(bloc.state.lastMergeResult, isNull);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits a failure result and stays in multi-select when merge fails',
        build: () => buildBloc(mergeClips: _fakeMergeClipsFail),
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
        act: (bloc) => bloc.add(const ClipEditorSelectedClipsMergeRequested()),
        verify: (bloc) {
          expect(bloc.state.clips, hasLength(3));
          expect(bloc.state.isMerging, isFalse);
          expect(bloc.state.isMultiSelectMode, isTrue);
          expect(bloc.state.lastMergeResult, isA<ClipMergeFailure>());
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'reports the error and emits failure when the merge render throws',
        build: () => buildBloc(mergeClips: _fakeMergeClipsThrow),
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
        act: (bloc) => bloc.add(const ClipEditorSelectedClipsMergeRequested()),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.clips, hasLength(3));
          expect(bloc.state.isMerging, isFalse);
          expect(bloc.state.lastMergeResult, isA<ClipMergeFailure>());
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'discards the merge result when a selected clip is removed mid-render',
        build: () => buildBloc(
          mergeClips: ({required clips, required renderId}) =>
              mergeCompleter.future,
        ),
        seed: () => ClipEditorState(
          clips: threeClips,
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'c'},
        ),
        act: (bloc) async {
          mergeCompleter = Completer<DivineVideoClip?>();
          bloc.add(const ClipEditorSelectedClipsMergeRequested());
          // Let the merge start (emits isMerging) and suspend on the completer.
          await Future<void>.delayed(Duration.zero);
          // A selected clip disappears while the render is in flight.
          bloc.add(const ClipEditorClipRemoved('a'));
          await Future<void>.delayed(Duration.zero);
          mergeCompleter.complete(
            _createClip(
              id: 'merged-clip',
              duration: const Duration(seconds: 2),
            ),
          );
        },
        verify: (bloc) {
          expect(bloc.state.lastMergeResult, isA<ClipMergeDiscarded>());
          // The merged clip must not be inserted.
          expect(
            bloc.state.clips.map((c) => c.id),
            isNot(contains('merged-clip')),
          );
          expect(bloc.state.isMerging, isFalse);
          expect(bloc.state.isMultiSelectMode, isFalse);
        },
      );
    });

    group('ClipEditorSaveClipToLibraryRequested', () {
      late List<DivineVideoClip> twoClips;
      late List<DivineVideoClip> savedToLibrary;
      late Completer<DivineVideoClip?> flattenCompleter;

      /// Records what the BLoC handed to the library.
      Future<bool> recordSave({required DivineVideoClip clip}) async {
        savedToLibrary.add(clip);
        return true;
      }

      setUp(() {
        twoClips = [
          _createClip(id: 'a', duration: const Duration(seconds: 2)),
          _createClip(id: 'b', duration: const Duration(seconds: 4)),
        ];
        savedToLibrary = [];
      });

      group('overlay windowing', () {
        late EditorOverlaySnapshot? forwardedOverlays;

        /// Captures the overlays the BLoC windowed for the render.
        Future<DivineVideoClip?> recordOverlays({
          required DivineVideoClip clip,
          required String renderId,
          EditorOverlaySnapshot? overlays,
        }) async {
          forwardedOverlays = overlays;
          return _createClip(id: 'flattened-${clip.id}');
        }

        /// A layer spanning 3s-4s of the editor timeline. Clip 'a' occupies
        /// 0s-2s and clip 'b' 2s-6s, so this sits over 'b' only — one second in.
        EditorOverlaySnapshot snapshotWithLayerAt3to4() {
          return EditorOverlaySnapshot(
            bodySize: const Size(100, 200),
            capturedLayers: [
              ExportedLayer(
                layer: Layer(
                  id: 'text',
                  startTime: const Duration(seconds: 3),
                  endTime: const Duration(seconds: 4),
                ),
                bytes: Uint8List.fromList([1]),
                logicalSize: const Size(10, 10),
              ),
            ],
          );
        }

        setUp(() => forwardedOverlays = null);

        blocTest<ClipEditorBloc, ClipEditorState>(
          'rebases a layer onto the saved clip position on the timeline',
          build: () => buildBloc(
            flattenClipForLibrary: recordOverlays,
            saveClipToLibrary: recordSave,
          ),
          seed: () => ClipEditorState(clips: twoClips),
          act: (bloc) => bloc.add(
            ClipEditorSaveClipToLibraryRequested(
              clipId: 'b',
              overlays: snapshotWithLayerAt3to4(),
            ),
          ),
          verify: (bloc) {
            // Clip 'b' starts 2s into the composition, so a layer at 3s-4s
            // must land at 1s-2s of the standalone clip.
            final layer = forwardedOverlays!.capturedLayers.single.layer;
            expect(layer.startTime, equals(const Duration(seconds: 1)));
            expect(layer.endTime, equals(const Duration(seconds: 2)));
          },
        );

        blocTest<ClipEditorBloc, ClipEditorState>(
          'drops a layer that was never over the saved clip',
          build: () => buildBloc(
            flattenClipForLibrary: recordOverlays,
            saveClipToLibrary: recordSave,
          ),
          seed: () => ClipEditorState(clips: twoClips),
          act: (bloc) => bloc.add(
            ClipEditorSaveClipToLibraryRequested(
              clipId: 'a',
              overlays: snapshotWithLayerAt3to4(),
            ),
          ),
          verify: (bloc) {
            // Clip 'a' is 0s-2s; the layer only shows from 3s.
            expect(forwardedOverlays!.capturedLayers, isEmpty);
          },
        );

        blocTest<ClipEditorBloc, ClipEditorState>(
          'forwards no overlays when the editor had none to capture',
          build: () => buildBloc(
            flattenClipForLibrary: recordOverlays,
            saveClipToLibrary: recordSave,
          ),
          seed: () => ClipEditorState(clips: twoClips),
          act: (bloc) =>
              bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
          verify: (bloc) {
            expect(forwardedOverlays, isNull);
          },
        );
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'stores the flattened clip and emits success',
        build: () => buildBloc(
          flattenClipForLibrary: _fakeFlattenClipForLibrary,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) =>
            bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
        verify: (bloc) {
          expect(savedToLibrary.map((c) => c.id), equals(['flattened-a']));
          expect(bloc.state.lastClipLibrarySave, isA<ClipLibrarySaveSuccess>());
          expect(bloc.state.isSavingClipToLibrary, isFalse);
          expect(bloc.state.savingClipToLibraryClipId, isNull);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'leaves the timeline untouched — saving only copies to the library',
        build: () => buildBloc(
          flattenClipForLibrary: _fakeFlattenClipForLibrary,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips, currentClipIndex: 1),
        act: (bloc) =>
            bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'b')),
        verify: (bloc) {
          expect(bloc.state.clips.map((c) => c.id), equals(['a', 'b']));
          expect(bloc.state.currentClipIndex, equals(1));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'saves the clip named by the event, not the current selection',
        build: () => buildBloc(
          flattenClipForLibrary: _fakeFlattenClipForLibrary,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips, currentClipIndex: 1),
        act: (bloc) =>
            bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
        verify: (bloc) {
          expect(savedToLibrary.map((c) => c.id), equals(['flattened-a']));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does nothing when the requested clip does not exist',
        build: () => buildBloc(
          flattenClipForLibrary: _fakeFlattenClipForLibrary,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorSaveClipToLibraryRequested(clipId: 'missing'),
        ),
        verify: (bloc) {
          expect(savedToLibrary, isEmpty);
          expect(bloc.state.lastClipLibrarySave, isNull);
          expect(bloc.state.isSavingClipToLibrary, isFalse);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits failure and stores nothing when the re-encode fails',
        build: () => buildBloc(
          flattenClipForLibrary: _fakeFlattenClipForLibraryFail,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) =>
            bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
        verify: (bloc) {
          expect(savedToLibrary, isEmpty);
          expect(bloc.state.lastClipLibrarySave, isA<ClipLibrarySaveFailure>());
          expect(bloc.state.isSavingClipToLibrary, isFalse);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits failure when the library rejects the write',
        build: () => buildBloc(
          flattenClipForLibrary: _fakeFlattenClipForLibrary,
          saveClipToLibrary: ({required clip}) async => false,
        ),
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) =>
            bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
        verify: (bloc) {
          expect(bloc.state.lastClipLibrarySave, isA<ClipLibrarySaveFailure>());
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'reports the error and emits failure when the re-encode throws',
        build: () => buildBloc(
          flattenClipForLibrary: _fakeFlattenClipForLibraryThrow,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) =>
            bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        verify: (bloc) {
          expect(savedToLibrary, isEmpty);
          expect(bloc.state.lastClipLibrarySave, isA<ClipLibrarySaveFailure>());
          expect(bloc.state.isSavingClipToLibrary, isFalse);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'discards the result when the source clip is removed mid-render',
        build: () => buildBloc(
          flattenClipForLibrary: ({
            required clip,
            required renderId,
            overlays,
          }) => flattenCompleter.future,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) async {
          flattenCompleter = Completer<DivineVideoClip?>();
          bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a'));
          // Let the save start (emits isSavingClipToLibrary) and suspend.
          await Future<void>.delayed(Duration.zero);
          bloc.add(const ClipEditorClipRemoved('a'));
          await Future<void>.delayed(Duration.zero);
          flattenCompleter.complete(_createClip(id: 'flattened-a'));
        },
        verify: (bloc) {
          // The user deleted the clip they asked to save — storing it anyway
          // would resurrect it in the library.
          expect(savedToLibrary, isEmpty);
          expect(
            bloc.state.lastClipLibrarySave,
            isA<ClipLibrarySaveDiscarded>(),
          );
          expect(bloc.state.isSavingClipToLibrary, isFalse);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'drops a second request while one is in flight (no duplicate copy)',
        build: () => buildBloc(
          flattenClipForLibrary: ({
            required clip,
            required renderId,
            overlays,
          }) => flattenCompleter.future,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) async {
          flattenCompleter = Completer<DivineVideoClip?>();
          bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a'));
          await Future<void>.delayed(Duration.zero);
          // A double-tap while the first render is still running.
          bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a'));
          await Future<void>.delayed(Duration.zero);
          flattenCompleter.complete(_createClip(id: 'flattened-a'));
          await Future<void>.delayed(Duration.zero);
        },
        verify: (bloc) {
          expect(savedToLibrary.map((c) => c.id), equals(['flattened-a']));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'marks the in-flight clip while the re-encode runs',
        build: () => buildBloc(
          flattenClipForLibrary: ({
            required clip,
            required renderId,
            overlays,
          }) => flattenCompleter.future,
          saveClipToLibrary: recordSave,
        ),
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) async {
          flattenCompleter = Completer<DivineVideoClip?>();
          bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a'));
          await Future<void>.delayed(Duration.zero);
          // Assert mid-flight: Save is disabled on every clip, and this id
          // marks which one shows the spinner.
          expect(bloc.state.isSavingClipToLibrary, isTrue);
          expect(bloc.state.savingClipToLibraryClipId, equals('a'));
          flattenCompleter.complete(null);
        },
        verify: (bloc) {
          expect(bloc.state.isSavingClipToLibrary, isFalse);
          expect(bloc.state.savingClipToLibraryClipId, isNull);
        },
      );

      group('render id', () {
        late String? forwardedRenderId;

        setUp(() => forwardedRenderId = null);

        blocTest<ClipEditorBloc, ClipEditorState>(
          'namespaces the render id so a save cannot cancel a reverse render',
          build: () => buildBloc(
            flattenClipForLibrary:
                ({required clip, required renderId, overlays}) async {
                  forwardedRenderId = renderId;
                  return _createClip(id: 'flattened-${clip.id}');
                },
            saveClipToLibrary: recordSave,
          ),
          seed: () => ClipEditorState(clips: twoClips),
          act: (bloc) =>
              bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
          verify: (bloc) {
            // The bare clip id keys the reverse render, which the native layer
            // cancels on a colliding id — so the save id must be namespaced.
            expect(forwardedRenderId, equals('a_clip_library_save'));
          },
        );
      });

      group('orphan cleanup', () {
        late List<DivineVideoClip> cleanedUp;

        /// Records which flattened clips the BLoC asked the service to delete.
        Future<void> recordCleanup(
          DivineVideoClip clip, {
          String? keepThumbnailPath,
        }) async {
          cleanedUp.add(clip);
        }

        setUp(() => cleanedUp = []);

        blocTest<ClipEditorBloc, ClipEditorState>(
          'deletes the flattened file when the library rejects the write',
          build: () => buildBloc(
            flattenClipForLibrary: _fakeFlattenClipForLibrary,
            cleanupFlattenedClip: recordCleanup,
            saveClipToLibrary: ({required clip}) async => false,
          ),
          seed: () => ClipEditorState(clips: twoClips),
          act: (bloc) =>
              bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
          verify: (bloc) {
            // Rejected write leaves a documents-dir file nothing references.
            expect(cleanedUp.map((c) => c.id), equals(['flattened-a']));
          },
        );

        blocTest<ClipEditorBloc, ClipEditorState>(
          'deletes the flattened file when the source clip was removed',
          build: () => buildBloc(
            flattenClipForLibrary: ({
              required clip,
              required renderId,
              overlays,
            }) => flattenCompleter.future,
            cleanupFlattenedClip: recordCleanup,
            saveClipToLibrary: recordSave,
          ),
          seed: () => ClipEditorState(clips: twoClips),
          act: (bloc) async {
            flattenCompleter = Completer<DivineVideoClip?>();
            bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a'));
            await Future<void>.delayed(Duration.zero);
            bloc.add(const ClipEditorClipRemoved('a'));
            await Future<void>.delayed(Duration.zero);
            flattenCompleter.complete(_createClip(id: 'flattened-a'));
          },
          verify: (bloc) {
            expect(savedToLibrary, isEmpty);
            expect(cleanedUp.map((c) => c.id), equals(['flattened-a']));
          },
        );

        blocTest<ClipEditorBloc, ClipEditorState>(
          'keeps the flattened file when the save succeeds',
          build: () => buildBloc(
            flattenClipForLibrary: _fakeFlattenClipForLibrary,
            cleanupFlattenedClip: recordCleanup,
            saveClipToLibrary: recordSave,
          ),
          seed: () => ClipEditorState(clips: twoClips),
          act: (bloc) =>
              bloc.add(const ClipEditorSaveClipToLibraryRequested(clipId: 'a')),
          verify: (bloc) {
            // Success hands the file to the library, which now references it.
            expect(cleanedUp, isEmpty);
          },
        );
      });
    });
  });
}
