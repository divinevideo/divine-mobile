// ABOUTME: Tests for ClipsLibraryBloc - managing saved video clips
// ABOUTME: Tests loading, selection, deletion, and gallery export

import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _FakeEditorVideo extends Fake implements EditorVideo {}

class _CapturingObserver extends BlocObserver {
  final List<Object> errors = [];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEditorVideo());
  });

  group(ClipsLibraryBloc, () {
    late _MockClipLibraryService mockClipLibraryService;
    late _MockGallerySaveService mockGallerySaveService;
    late SharedPreferences sharedPreferences;

    DivineVideoClip createClip({
      String? id,
      Duration duration = const Duration(seconds: 5),
      DateTime? deletedAt,
    }) {
      return DivineVideoClip(
        id: id ?? 'clip-${DateTime.now().millisecondsSinceEpoch}',
        video: EditorVideo.file('/path/to/clip.mp4'),
        thumbnailPath: '/path/to/thumb.jpg',
        ghostFramePath: '/path/to/ghost.jpg',
        duration: duration,
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        deletedAt: deletedAt,
      );
    }

    setUp(() async {
      mockClipLibraryService = _MockClipLibraryService();
      mockGallerySaveService = _MockGallerySaveService();
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      // Stub recoverMissingAssets to mirror the real no-op: return the SAME
      // list instance when nothing is recovered. Returning a fresh list would
      // fail the `identical` check in `_recoverAndReload` and re-dispatch load
      // forever for clips with a null ghostFramePath (e.g. stop-motion stills).
      when(() => mockClipLibraryService.recoverMissingAssets(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as List<DivineVideoClip>,
      );
      // Every load also pulls the user's categories; tests that care stub
      // their own list over this default.
      when(
        () => mockClipLibraryService.getCategories(),
      ).thenAnswer((_) async => <ClipCategory>[]);
    });

    tearDown(() {
      StopMotionRenderService.assembleOverride = null;
      StopMotionRenderService.probeDurationOverride = null;
    });

    DivineVideoClip createStopMotionClip({
      String? id,
      Duration duration = const Duration(seconds: 1),
      DateTime? deletedAt,
    }) {
      return DivineVideoClip(
        id: id ?? 'sm-${DateTime.now().millisecondsSinceEpoch}',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/frames/f0.jpg',
            duration: Duration(milliseconds: 83),
          ),
        ],
        thumbnailPath: '/frames/f0.jpg',
        duration: duration,
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        deletedAt: deletedAt,
      );
    }

    ClipsLibraryBloc createBloc({
      LibraryClipTypeFilter clipTypeFilter = LibraryClipTypeFilter.all,
    }) => ClipsLibraryBloc(
      clipLibraryService: mockClipLibraryService,
      gallerySaveService: mockGallerySaveService,
      sharedPreferences: sharedPreferences,
      clipTypeFilter: clipTypeFilter,
    );

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state, const ClipsLibraryState());
      expect(bloc.state.status, ClipsLibraryStatus.initial);
      expect(bloc.state.clips, isEmpty);
      expect(bloc.state.selectedClipIds, isEmpty);
      bloc.close();
    });

    group('ClipsLibraryGridColumnsChanged', () {
      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits the new column count and persists it',
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryGridColumnsChanged(5)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.gridColumnCount,
            'gridColumnCount',
            5,
          ),
        ],
        verify: (_) => expect(
          sharedPreferences.getInt(ClipGridColumns.prefsKey),
          equals(5),
        ),
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'clamps a count outside the supported range',
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryGridColumnsChanged(42)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.gridColumnCount,
            'gridColumnCount',
            ClipGridColumns.max,
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits nothing when the count is unchanged',
        build: createBloc,
        act: (bloc) => bloc.add(
          const ClipsLibraryGridColumnsChanged(ClipGridColumns.initial),
        ),
        expect: () => <ClipsLibraryState>[],
      );

      test('restores the persisted column count on construction', () async {
        SharedPreferences.setMockInitialValues({
          ClipGridColumns.prefsKey: 4,
        });
        final bloc = ClipsLibraryBloc(
          clipLibraryService: mockClipLibraryService,
          gallerySaveService: mockGallerySaveService,
          sharedPreferences: await SharedPreferences.getInstance(),
        );

        expect(bloc.state.gridColumnCount, equals(4));
        await bloc.close();
      });

      test(
        'falls back to the default for an out-of-range stored value',
        () async {
          SharedPreferences.setMockInitialValues({
            ClipGridColumns.prefsKey: 0,
          });
          final bloc = ClipsLibraryBloc(
            clipLibraryService: mockClipLibraryService,
            gallerySaveService: mockGallerySaveService,
            sharedPreferences: await SharedPreferences.getInstance(),
          );

          expect(bloc.state.gridColumnCount, equals(ClipGridColumns.min));
          await bloc.close();
        },
      );
    });

    group('ClipsLibraryLoadRequested', () {
      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits [loading, loaded] with clips from service',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [createClip(id: 'clip1'), createClip(id: 'clip2')],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.clips.length, 'clips.length', 2),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits [loading, loaded] with empty list when no clips',
        setUp: () {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'pre-selects clips matching preSelectedIds',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [createClip(id: 'c1'), createClip(id: 'c2')],
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ClipsLibraryLoadRequested(preSelectedIds: {'c1'})),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having(
                (s) => s.selectedClipIds,
                'selectedClipIds',
                equals({'c1'}),
              )
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                const Duration(seconds: 5),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'ignores preSelectedIds that do not exist in loaded clips',
        setUp: () {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [createClip(id: 'c1')]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ClipsLibraryLoadRequested(
            preSelectedIds: {'c1', 'nonexistent'},
          ),
        ),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>()
              .having(
                (s) => s.selectedClipIds,
                'selectedClipIds',
                equals({'c1'}),
              )
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                const Duration(seconds: 5),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits [loading, error] when service throws',
        setUp: () {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenThrow(Exception('Load failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );

      test(
        'does not addError after close when _recoverAndReload completes '
        'post-close (regression #4605)',
        () async {
          // Clip with a missing ghost frame triggers the unawaited
          // _recoverAndReload background path. The recovery future is
          // held open via a Completer so we can close the bloc before
          // it resolves, then fail it — exercising the post-close race.
          final clipMissingGhost = DivineVideoClip(
            id: 'clip-missing-ghost',
            video: EditorVideo.file('/path/to/clip.mp4'),
            thumbnailPath: '/path/to/thumb.jpg',
            duration: const Duration(seconds: 5),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          final completer = Completer<List<DivineVideoClip>>();
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [clipMissingGhost]);
          when(
            () => mockClipLibraryService.recoverMissingAssets(any()),
          ).thenAnswer((_) => completer.future);

          final observer = _CapturingObserver();
          final priorObserver = Bloc.observer;
          Bloc.observer = observer;
          addTearDown(() => Bloc.observer = priorObserver);

          final bloc = createBloc()..add(const ClipsLibraryLoadRequested());
          // Let the handler reach unawaited(_recoverAndReload).
          await Future<void>.delayed(Duration.zero);

          await bloc.close();

          completer.completeError(Exception('Recovery failed'));
          await Future<void>.delayed(Duration.zero);

          expect(observer.errors, isEmpty);
        },
      );
    });

    group('ClipsLibraryToggleSelection', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clip2 = DivineVideoClip(
        id: 'clip2',
        video: EditorVideo.file('/path/to/clip2.mp4'),
        thumbnailPath: '/path/to/thumb2.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'adds clip to selection',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryToggleSelection(clip1)),
        expect: () => [
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            selectedClipIds: const {'clip1'},
            selectedDuration: const Duration(seconds: 5),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'removes clip from selection when already selected',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryToggleSelection(clip1)),
        expect: () => [
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'accumulates selected duration with multiple clips',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryToggleSelection(clip2)),
        expect: () => [
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            selectedClipIds: const {'clip1', 'clip2'},
            selectedDuration: const Duration(seconds: 8),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'ignores a clip of a different type than the current selection',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [
            clip1,
            createStopMotionClip(id: 'sm1'),
          ],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(
          ClipsLibraryToggleSelection(createStopMotionClip(id: 'sm1')),
        ),
        expect: () => <ClipsLibraryState>[],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'allows selecting a second clip of the same type',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [
            createStopMotionClip(id: 'sm1'),
            createStopMotionClip(id: 'sm2'),
          ],
          selectedClipIds: const {'sm1'},
          selectedDuration: const Duration(seconds: 1),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(
          ClipsLibraryToggleSelection(createStopMotionClip(id: 'sm2')),
        ),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds,
            'selectedClipIds',
            equals({'sm1', 'sm2'}),
          ),
        ],
      );
    });

    group('drag selection', () {
      DivineVideoClip gridClip(
        String id, {
        Duration duration = const Duration(seconds: 1),
        model.AspectRatio aspectRatio = .vertical,
        String? categoryId,
      }) => DivineVideoClip(
        id: id,
        video: EditorVideo.file('/path/to/$id.mp4'),
        thumbnailPath: '/path/to/$id.jpg',
        duration: duration,
        recordedAt: DateTime(2026),
        targetAspectRatio: aspectRatio,
        originalAspectRatio: 9 / 16,
        categoryId: categoryId,
      );

      final a = gridClip('a', duration: const Duration(seconds: 5));
      final b = gridClip('b', duration: const Duration(seconds: 3));
      final c = gridClip('c', duration: const Duration(seconds: 2));
      final d = gridClip('d', duration: const Duration(seconds: 4));

      ClipsLibraryState seedWith(
        List<DivineVideoClip> clips, {
        Set<String> selectedClipIds = const {},
        Set<String> disabledClipIds = const {},
      }) => ClipsLibraryState(
        status: ClipsLibraryStatus.loaded,
        clips: clips,
        sortedClips: clips,
        selectedClipIds: selectedClipIds,
        disabledClipIds: disabledClipIds,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'selects every clip between the anchor and the one under the finger',
        seed: () => seedWith([a, b, c, d]),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a))
          ..add(ClipsLibraryDragSelectionExtended(c)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['a']),
          ),
          isA<ClipsLibraryState>()
              .having(
                (s) => s.selectedClipIds.toList(),
                'selectedClipIds',
                equals(['a', 'b', 'c']),
              )
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                equals(const Duration(seconds: 10)),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'numbers the range from the anchor outwards when dragging back up',
        seed: () => seedWith([a, b, c, d]),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(d))
          ..add(ClipsLibraryDragSelectionExtended(b)),
        expect: () => [
          isA<ClipsLibraryState>(),
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['d', 'c', 'b']),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'drops the clips the finger has moved back past',
        seed: () => seedWith([a, b, c, d]),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a))
          ..add(ClipsLibraryDragSelectionExtended(d))
          ..add(ClipsLibraryDragSelectionExtended(b)),
        expect: () => [
          isA<ClipsLibraryState>(),
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['a', 'b', 'c', 'd']),
          ),
          isA<ClipsLibraryState>()
              .having(
                (s) => s.selectedClipIds.toList(),
                'selectedClipIds',
                equals(['a', 'b']),
              )
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                equals(const Duration(seconds: 8)),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'keeps what was selected before the drag',
        seed: () => seedWith([a, b, c, d], selectedClipIds: const {'d'}),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a))
          ..add(ClipsLibraryDragSelectionExtended(b)),
        expect: () => [
          isA<ClipsLibraryState>(),
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['d', 'a', 'b']),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'deselects the range when the drag starts on a selected clip',
        seed: () =>
            seedWith([a, b, c, d], selectedClipIds: const {'a', 'b', 'c'}),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a))
          ..add(ClipsLibraryDragSelectionExtended(b)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['b', 'c']),
          ),
          isA<ClipsLibraryState>()
              .having(
                (s) => s.selectedClipIds.toList(),
                'selectedClipIds',
                equals(['c']),
              )
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                equals(const Duration(seconds: 2)),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'passes over clips that would mix stop-motion into the selection',
        seed: () => seedWith([a, createStopMotionClip(id: 'sm1'), c]),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a))
          ..add(ClipsLibraryDragSelectionExtended(c)),
        expect: () => [
          isA<ClipsLibraryState>(),
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['a', 'c']),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'passes over clips of another aspect ratio than the editor holds',
        seed: () => seedWith([a, gridClip('sq', aspectRatio: .square), c]),
        build: createBloc,
        act: (bloc) => bloc
          ..add(
            // The editor's timeline is vertical, so the square clip in the
            // middle of the range cannot join it.
            ClipsLibraryDragSelectionStarted(a, targetAspectRatio: 9 / 16),
          )
          ..add(ClipsLibraryDragSelectionExtended(c)),
        expect: () => [
          isA<ClipsLibraryState>(),
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['a', 'c']),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'leaves clips already in the editor alone',
        seed: () => seedWith(
          [a, b, c],
          selectedClipIds: const {'b'},
          disabledClipIds: const {'b'},
        ),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a))
          ..add(ClipsLibraryDragSelectionExtended(c)),
        expect: () => [
          isA<ClipsLibraryState>(),
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['b', 'a', 'c']),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'opens selection mode when the press lands while browsing',
        seed: () => seedWith([a, b]),
        build: createBloc,
        act: (bloc) => bloc.add(
          ClipsLibraryDragSelectionStarted(a, selectionEnabled: false),
        ),
        expect: () => [
          isA<ClipsLibraryState>()
              .having(
                (s) => s.isLibrarySelectionMode,
                'isLibrarySelectionMode',
                isTrue,
              )
              .having(
                (s) => s.selectedClipIds.toList(),
                'selectedClipIds',
                equals(['a']),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'picks up a clip the editor pre-selected out of sight',
        // Opening the library from the editor pre-selects its clips with the
        // badges hidden, so this press has nothing visible to toggle off.
        seed: () => seedWith([a, b], selectedClipIds: const {'a'}),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a, selectionEnabled: false))
          ..add(ClipsLibraryDragSelectionExtended(b)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['a']),
          ),
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds.toList(),
            'selectedClipIds',
            equals(['a', 'b']),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'starts no drag on a clip already in the editor',
        seed: () => seedWith([a, b], disabledClipIds: const {'a'}),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryDragSelectionStarted(a)),
        expect: () => <ClipsLibraryState>[],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'forgets the drag when the filter swaps the list under it',
        seed: () => seedWith([a, b, gridClip('e', categoryId: 'cat')]),
        build: createBloc,
        // The chip row sits outside the drag region, so a second finger can
        // change the filter mid-drag. Without this the range would be walked
        // over the new list, covering clips the finger never crossed.
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a))
          ..add(
            const ClipsLibraryFilterChanged(ClipLibraryCategoryFilter('cat')),
          )
          ..add(ClipsLibraryDragSelectionExtended(gridClip('e'))),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.dragSelection,
            'dragSelection',
            isNotNull,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.dragSelection, 'dragSelection', isNull)
              .having(
                (s) => s.selectedClipIds.toList(),
                'selectedClipIds',
                equals(['a']),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'forgets the drag once the finger lifts',
        seed: () => seedWith([a, b]),
        build: createBloc,
        act: (bloc) => bloc
          ..add(ClipsLibraryDragSelectionStarted(a))
          ..add(const ClipsLibraryDragSelectionEnded()),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.dragSelection,
            'dragSelection',
            isNotNull,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.dragSelection, 'dragSelection', isNull)
              .having(
                (s) => s.selectedClipIds.toList(),
                'selectedClipIds',
                equals(['a']),
              ),
        ],
      );
    });

    group('clipTypeFilter', () {
      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'stopMotion filter loads only stop-motion clips',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [
              createClip(id: 'video1'),
              createStopMotionClip(id: 'sm1'),
              createClip(id: 'video2'),
            ],
          );
        },
        build: () =>
            createBloc(clipTypeFilter: LibraryClipTypeFilter.stopMotion),
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having(
                (s) => s.clips.map((c) => c.id).toList(),
                'clip ids',
                ['sm1'],
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'video filter loads only normal video clips',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [
              createClip(id: 'video1'),
              createStopMotionClip(id: 'sm1'),
            ],
          );
        },
        build: () => createBloc(clipTypeFilter: LibraryClipTypeFilter.video),
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>().having(
            (s) => s.clips.map((c) => c.id).toList(),
            'clip ids',
            ['video1'],
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'all filter loads both types',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [
              createClip(id: 'video1'),
              createStopMotionClip(id: 'sm1'),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>().having(
            (s) => s.clips.length,
            'clips.length',
            2,
          ),
        ],
      );
    });

    group('ClipsLibraryClearSelection', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'clears all selections',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryClearSelection()),
        expect: () => [
          ClipsLibraryState(status: ClipsLibraryStatus.loaded, clips: [clip1]),
        ],
      );
    });

    group('ClipsLibraryDeleteSelected', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clip2 = DivineVideoClip(
        id: 'clip2',
        video: EditorVideo.file('/path/to/clip2.mp4'),
        thumbnailPath: '/path/to/thumb2.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final travel = ClipCategory(
        id: 'cat-travel',
        name: 'Travel',
        createdAt: DateTime(2026),
      );

      final filedClip = DivineVideoClip(
        id: 'filed',
        video: EditorVideo.file('/path/to/filed.mp4'),
        thumbnailPath: '/path/to/filed.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        categoryId: travel.id,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'does nothing when no clips selected',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        expect: () => [],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'deletes selected clips and clears selection',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete('clip1'),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [clip2]);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.deleting,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.clips.length, 'clips.length', 1)
              .having((s) => s.selectedClipIds, 'selectedClipIds', isEmpty)
              .having((s) => s.lastDeletedCount, 'lastDeletedCount', 1),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.softDelete('clip1')).called(1);
        },
      );

      // A selection survives switching between active filters, so part of it
      // can be off screen when Delete is tapped. Only what the grid shows may
      // go to the trash.
      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'deletes only the selected clips the active filter shows',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete(any()),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [clip1]);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, filedClip],
          sortedClips: [filedClip],
          selectedClipIds: const {'clip1', 'filed'},
          selectedDuration: const Duration(seconds: 8),
          categories: [travel],
          filter: ClipLibraryCategoryFilter(travel.id),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        verify: (bloc) {
          verify(() => mockClipLibraryService.softDelete('filed')).called(1);
          verifyNever(() => mockClipLibraryService.softDelete('clip1'));
          expect(bloc.state.lastDeletedCount, 1);
          expect(bloc.state.lastDeletedClipIds, {'filed'});
          // The clip picked under the other filter was never in reach, so it
          // stays selected — and still counts towards the duration.
          expect(bloc.state.selectedClipIds, {'clip1'});
          expect(bloc.state.selectedDuration, clip1.duration);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'does nothing when the whole selection is hidden by the filter',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, filedClip],
          sortedClips: [filedClip],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
          categories: [travel],
          filter: ClipLibraryCategoryFilter(travel.id),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        expect: () => [],
        verify: (_) {
          verifyNever(() => mockClipLibraryService.softDelete(any()));
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error state when deletion fails',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete(any()),
          ).thenThrow(Exception('Delete failed'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.deleting,
          ),
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'ignores a multi-delete while a single-clip delete is in flight',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete(any()),
          ).thenAnswer((_) async => true);
        },
        // The two delete events use separate `droppable()` buckets, so only
        // the explicit in-flight check keeps them from overlapping.
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.deleting,
          clips: [clip1, clip2],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        expect: () => <ClipsLibraryState>[],
        verify: (_) {
          verifyNever(() => mockClipLibraryService.softDelete(any()));
        },
      );
    });

    group('ClipsLibraryDeleteClip', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'deletes single clip and reloads',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete('clip1'),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryDeleteClip(clip1)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.deleting,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.clips, 'clips', isEmpty)
              .having((s) => s.lastDeletedCount, 'lastDeletedCount', 1),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.softDelete('clip1')).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'clears stale deleted count so repeated single-delete results still emit',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete(any()),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          lastDeletedCount: 1,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryDeleteClip(clip1)),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.deleting)
              .having((s) => s.lastDeletedCount, 'lastDeletedCount', isNull),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.lastDeletedCount, 'lastDeletedCount', 1),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'removes clip from selection if it was selected',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete('clip1'),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryDeleteClip(clip1)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.deleting,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.selectedClipIds, 'selectedClipIds', isEmpty)
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                Duration.zero,
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'ignores a single-clip delete while a multi-delete is in flight',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete(any()),
          ).thenAnswer((_) async => true);
        },
        // Mirror of the multi-delete guard: the `droppable()` transformer only
        // excludes repeats of the same event type.
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.deleting,
          clips: [clip1],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryDeleteClip(clip1)),
        expect: () => <ClipsLibraryState>[],
        verify: (_) {
          verifyNever(() => mockClipLibraryService.softDelete(any()));
        },
      );
    });

    group('trash events', () {
      final activeClip = DivineVideoClip(
        id: 'active',
        video: EditorVideo.file('/path/to/active.mp4'),
        thumbnailPath: '/path/to/active.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final trashedClip = DivineVideoClip(
        id: 'trashed',
        video: EditorVideo.file('/path/to/trashed.mp4'),
        thumbnailPath: '/path/to/trashed.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        deletedAt: DateTime(2026, 5),
      );

      final trashedStopMotionClip = createStopMotionClip(
        id: 'trashed-sm',
        deletedAt: DateTime(2026, 5),
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'loads trashed clips',
        setUp: () {
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => [trashedClip]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryTrashLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.trashLoading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.trashLoaded)
              .having((s) => s.trashedClips, 'trashedClips', [trashedClip]),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'applies the type filter when loading trashed clips',
        setUp: () {
          when(() => mockClipLibraryService.getTrashedClips()).thenAnswer(
            (_) async => [trashedClip, trashedStopMotionClip],
          );
        },
        build: () =>
            createBloc(clipTypeFilter: LibraryClipTypeFilter.stopMotion),
        act: (bloc) => bloc.add(const ClipsLibraryTrashLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.trashLoading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.trashLoaded)
              .having(
                (s) => s.trashedClips.map((c) => c.id).toList(),
                'trashed clip ids',
                ['trashed-sm'],
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error when trash load fails',
        setUp: () {
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenThrow(Exception('Trash load failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryTrashLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.trashLoading),
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'restores clips and reloads active + trash lists from loaded state',
        setUp: () {
          when(
            () => mockClipLibraryService.restore('trashed'),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [activeClip, trashedClip]);
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          trashedClips: [trashedClip],
          lastDeletedClipIds: const {'trashed'},
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryRestoreClips({'trashed'})),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.clips, 'clips', [activeClip, trashedClip])
              .having((s) => s.trashedClips, 'trashedClips', isEmpty)
              .having(
                (s) => s.lastDeletedClipIds,
                'lastDeletedClipIds',
                isEmpty,
              ),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.restore('trashed')).called(1);
          verify(() => mockClipLibraryService.getAllClips()).called(1);
          verify(() => mockClipLibraryService.getTrashedClips()).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'applies the type filter after restoring from trash',
        setUp: () {
          when(
            () => mockClipLibraryService.restore('trashed-sm'),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [activeClip, trashedStopMotionClip]);
          when(() => mockClipLibraryService.getTrashedClips()).thenAnswer(
            (_) async => [trashedClip, trashedStopMotionClip],
          );
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedStopMotionClip],
        ),
        build: () =>
            createBloc(clipTypeFilter: LibraryClipTypeFilter.stopMotion),
        act: (bloc) => bloc.add(const ClipsLibraryRestoreClips({'trashed-sm'})),
        expect: () => [
          isA<ClipsLibraryState>()
              .having(
                (s) => s.clips.map((c) => c.id).toList(),
                'active clip ids',
                ['trashed-sm'],
              )
              .having(
                (s) => s.trashedClips.map((c) => c.id).toList(),
                'trashed clip ids',
                ['trashed-sm'],
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error when restore fails',
        setUp: () {
          when(
            () => mockClipLibraryService.restore(any()),
          ).thenThrow(Exception('Restore failed'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryRestoreClips({'trashed'})),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'hard-deletes a trashed clip and reloads trash list',
        setUp: () {
          when(
            () => mockClipLibraryService.hardDelete('trashed'),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryHardDeleteClip(trashedClip)),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.trashLoaded)
              .having((s) => s.trashedClips, 'trashedClips', isEmpty),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.hardDelete('trashed')).called(1);
          verify(() => mockClipLibraryService.getTrashedClips()).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error when hard delete fails',
        setUp: () {
          when(
            () => mockClipLibraryService.hardDelete(any()),
          ).thenThrow(Exception('Hard delete failed'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryHardDeleteClip(trashedClip)),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'empties trash and emits empty trashLoaded state',
        setUp: () {
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => [trashedClip]);
          when(
            () => mockClipLibraryService.hardDelete('trashed'),
          ).thenAnswer((_) async {});
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryEmptyTrash()),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.trashLoaded)
              .having((s) => s.trashedClips, 'trashedClips', isEmpty),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.getTrashedClips()).called(1);
          verify(() => mockClipLibraryService.hardDelete('trashed')).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'empty trash only purges clips matching the type filter',
        setUp: () {
          when(() => mockClipLibraryService.getTrashedClips()).thenAnswer(
            (_) async => [trashedClip, trashedStopMotionClip],
          );
          when(
            () => mockClipLibraryService.hardDelete('trashed-sm'),
          ).thenAnswer((_) async {});
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedStopMotionClip],
        ),
        build: () =>
            createBloc(clipTypeFilter: LibraryClipTypeFilter.stopMotion),
        act: (bloc) => bloc.add(const ClipsLibraryEmptyTrash()),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.trashLoaded)
              .having((s) => s.trashedClips, 'trashedClips', isEmpty),
        ],
        verify: (_) {
          verifyNever(() => mockClipLibraryService.hardDelete('trashed'));
          verify(
            () => mockClipLibraryService.hardDelete('trashed-sm'),
          ).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error when empty trash fails',
        setUp: () {
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenThrow(Exception('Empty trash failed'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryEmptyTrash()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );
    });

    group('ClipsLibrarySaveToGallery', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'does nothing when no clips selected',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        expect: () => [],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'saves selected clips to gallery',
        setUp: () {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.savingToGallery,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.selectedClipIds, 'selectedClipIds', isEmpty)
              .having(
                (s) => s.lastGallerySaveResult,
                'lastGallerySaveResult',
                isA<GallerySaveResultSuccess>()
                    .having((r) => r.successCount, 'successCount', 1)
                    .having((r) => r.failureCount, 'failureCount', 0),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'cleans up the transient mp4 after saving a stop-motion clip',
        setUp: () {
          final tempDir = Directory.systemTemp.createTempSync(
            'clips_library_stop_motion_gallery_test',
          );
          addTearDown(() async {
            if (tempDir.existsSync()) await tempDir.delete(recursive: true);
          });
          final output = File('${tempDir.path}/rendered.mp4')
            ..writeAsStringSync('rendered');
          StopMotionRenderService.assembleOverride = ({
            required frames,
            required aspectRatio,
            frameRate = StopMotionRenderService.defaultFrameRate,
            String? taskId,
          }) async => output.path;
          StopMotionRenderService.probeDurationOverride = (_) async => null;
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [createStopMotionClip(id: 'sm1')],
          selectedClipIds: const {'sm1'},
          selectedDuration: const Duration(seconds: 1),
        ),
        build: createBloc,
        // Wait for the save-result state before asserting on disk. The cleanup
        // runs in the save loop's `finally`, which the handler awaits before
        // emitting that state — but `blocTest` closes the bloc without waiting
        // for an in-flight handler, so a bare `add` would race the real (async)
        // file delete and see the mp4 still there.
        act: (bloc) async {
          final saved = bloc.stream.firstWhere(
            (s) => s.lastGallerySaveResult is GallerySaveResultSuccess,
          );
          bloc.add(const ClipsLibrarySaveToGallery());
          await saved;
        },
        verify: (_) {
          final captured =
              verify(
                    () =>
                        mockGallerySaveService.saveVideoToGallery(captureAny()),
                  ).captured.single
                  as EditorVideo;
          expect(File(captured.file!.path).existsSync(), isFalse);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'stops on permission denied',
        setUp: () {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySavePermissionDenied());
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.savingToGallery,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having(
                (s) => s.lastGallerySaveResult,
                'lastGallerySaveResult',
                isA<GallerySaveResultPermissionDenied>(),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error result when exception is thrown',
        setUp: () {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenThrow(Exception('Unexpected error'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.savingToGallery,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having(
                (s) => s.lastGallerySaveResult,
                'lastGallerySaveResult',
                isA<GallerySaveResultError>(),
              ),
        ],
      );
    });

    group('selectedClips', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clip2 = DivineVideoClip(
        id: 'clip2',
        video: EditorVideo.file('/path/to/clip2.mp4'),
        thumbnailPath: '/path/to/thumb2.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      test('returns empty list when no clips selected', () {
        final bloc = createBloc()
          ..emit(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1, clip2],
            ),
          );

        expect(bloc.state.selectedClips, isEmpty);
        bloc.close();
      });

      test('returns selected clips', () {
        final bloc = createBloc()
          ..emit(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1, clip2],
              selectedClipIds: const {'clip1'},
            ),
          );

        expect(bloc.state.selectedClips, [clip1]);
        bloc.close();
      });

      test('returns selected clips in selection order not list order', () {
        // selectedClipIds iteration order is clip2 then clip1
        final bloc = createBloc()
          ..emit(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1, clip2],
              selectedClipIds: const {'clip2', 'clip1'},
            ),
          );

        expect(bloc.state.selectedClips, [clip2, clip1]);
        bloc.close();
      });
    });

    group('library filters', () {
      DivineVideoClip organizedClip(
        String id, {
        String? categoryId,
        DateTime? archivedAt,
      }) => DivineVideoClip(
        id: id,
        video: EditorVideo.file('/path/$id.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026, 3, 5),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        categoryId: categoryId,
        archivedAt: archivedAt,
      );

      final travel = ClipCategory(
        id: 'cat-travel',
        name: 'Travel',
        createdAt: DateTime(2026, 3, 5),
      );

      final active = organizedClip('active');
      final filed = organizedClip('filed', categoryId: travel.id);
      final archived = organizedClip(
        'archived',
        archivedAt: DateTime(2026, 3, 6),
      );

      void stubLoad() {
        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [active, filed, archived]);
        when(
          () => mockClipLibraryService.getCategories(),
        ).thenAnswer((_) async => [travel]);
      }

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'All hides archived clips and load carries the categories',
        setUp: stubLoad,
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.categories, [travel]);
          expect(
            bloc.state.sortedClips.map((c) => c.id),
            unorderedEquals(['active', 'filed']),
          );
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'Archive shows only archived clips',
        setUp: stubLoad,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ClipsLibraryLoadRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            const ClipsLibraryFilterChanged(ClipLibraryArchiveFilter()),
          );
        },
        verify: (bloc) {
          expect(bloc.state.sortedClips.map((c) => c.id), ['archived']);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'a category shows only its own, unarchived clips',
        setUp: stubLoad,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ClipsLibraryLoadRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            ClipsLibraryFilterChanged(ClipLibraryCategoryFilter(travel.id)),
          );
        },
        verify: (bloc) {
          expect(bloc.state.sortedClips.map((c) => c.id), ['filed']);
          expect(bloc.state.activeCategory, travel);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'the Deleted filter loads the trash bin',
        setUp: () {
          stubLoad();
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => [organizedClip('trashed')]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ClipsLibraryFilterChanged(ClipLibraryTrashFilter()),
        ),
        verify: (bloc) {
          expect(bloc.state.isShowingTrash, isTrue);
          expect(bloc.state.trashedClips.map((c) => c.id), ['trashed']);
          // Trashed clips are held separately; the grid list stays empty.
          expect(bloc.state.sortedClips, isEmpty);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'entering the trash drops a selection made on active clips',
        setUp: () {
          stubLoad();
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [active],
          sortedClips: [active],
          selectedClipIds: const {'active'},
        ),
        act: (bloc) => bloc.add(
          const ClipsLibraryFilterChanged(ClipLibraryTrashFilter()),
        ),
        verify: (bloc) => expect(bloc.state.selectedClipIds, isEmpty),
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'switching between active filters keeps the selection',
        setUp: stubLoad,
        build: createBloc,
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [active, filed],
          sortedClips: [active, filed],
          selectedClipIds: const {'active'},
        ),
        act: (bloc) => bloc.add(
          ClipsLibraryFilterChanged(ClipLibraryCategoryFilter(travel.id)),
        ),
        verify: (bloc) => expect(bloc.state.selectedClipIds, {'active'}),
      );
    });

    group('category management', () {
      final travel = ClipCategory(
        id: 'cat-travel',
        name: 'Travel',
        createdAt: DateTime(2026, 3, 5),
      );

      DivineVideoClip clipNamed(String id) => DivineVideoClip(
        id: id,
        video: EditorVideo.file('/path/$id.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026, 3, 5),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final onScreen = clipNamed('on-screen');
      final offScreen = clipNamed('off-screen');

      setUp(() {
        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => []);
      });

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'ClipsLibraryCategoryCreated files the given clips into the new one',
        setUp: () {
          when(
            () => mockClipLibraryService.createCategory('Travel'),
          ).thenAnswer((_) async => travel);
          when(
            () => mockClipLibraryService.getCategories(),
          ).thenAnswer((_) async => [travel]);
          when(
            () => mockClipLibraryService.setClipCategory(
              clipId: any(named: 'clipId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ClipsLibraryCategoryCreated('Travel', clipIds: {'clip1'}),
        ),
        verify: (bloc) {
          verify(
            () => mockClipLibraryService.setClipCategory(
              clipId: 'clip1',
              categoryId: travel.id,
            ),
          ).called(1);
          expect(bloc.state.categories, [travel]);
          expect(
            bloc.state.lastOrganizeResult,
            const ClipsLibraryOrganizeResult(
              action: ClipsLibraryOrganizeAction.movedToCategory,
              clipIds: {'clip1'},
              categoryName: 'Travel',
            ),
          );
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'a blank category name is rejected without touching the library',
        setUp: () {
          when(
            () => mockClipLibraryService.createCategory('   '),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryCategoryCreated('   ')),
        expect: () => const <ClipsLibraryState>[],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'deleting the active category falls back to All',
        setUp: () {
          when(
            () => mockClipLibraryService.deleteCategory(travel.id),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getCategories(),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          categories: [travel],
          filter: ClipLibraryCategoryFilter(travel.id),
        ),
        act: (bloc) => bloc.add(ClipsLibraryCategoryDeleted(travel.id)),
        verify: (bloc) {
          expect(bloc.state.filter, const ClipLibraryAllFilter());
          expect(bloc.state.categories, isEmpty);
        },
      );

      // Deleting a category unfiles its clips rather than removing them, so
      // nothing the user picked has left the library and the selection has
      // no reason to reset.
      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'deleting a category keeps the clips selected',
        setUp: () {
          when(
            () => mockClipLibraryService.deleteCategory(travel.id),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getCategories(),
          ).thenAnswer((_) async => []);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [onScreen, offScreen]);
        },
        build: createBloc,
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [onScreen, offScreen],
          sortedClips: [onScreen, offScreen],
          selectedClipIds: const {'on-screen', 'off-screen'},
          selectedDuration: const Duration(seconds: 4),
          categories: [travel],
        ),
        act: (bloc) => bloc.add(ClipsLibraryCategoryDeleted(travel.id)),
        verify: (bloc) {
          expect(bloc.state.selectedClipIds, {'on-screen', 'off-screen'});
          expect(bloc.state.selectedDuration, const Duration(seconds: 4));
        },
      );

      // The toolbar hands over only the clips the grid is showing, so the
      // rest of a cross-filter selection has to come out the other side of
      // the reload intact.
      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'moving clips keeps a selection made under another filter',
        setUp: () {
          when(
            () => mockClipLibraryService.setClipCategory(
              clipId: any(named: 'clipId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getCategories(),
          ).thenAnswer((_) async => [travel]);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [onScreen, offScreen]);
        },
        build: createBloc,
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [onScreen, offScreen],
          sortedClips: [onScreen],
          selectedClipIds: const {'on-screen', 'off-screen'},
          selectedDuration: const Duration(seconds: 4),
          categories: [travel],
        ),
        act: (bloc) => bloc.add(
          const ClipsLibraryClipsMovedToCategory(
            clipIds: {'on-screen'},
            categoryId: 'cat-travel',
          ),
        ),
        verify: (bloc) {
          verify(
            () => mockClipLibraryService.setClipCategory(
              clipId: 'on-screen',
              categoryId: travel.id,
            ),
          ).called(1);
          verifyNever(
            () => mockClipLibraryService.setClipCategory(
              clipId: 'off-screen',
              categoryId: any(named: 'categoryId'),
            ),
          );
          expect(bloc.state.selectedClipIds, {'off-screen'});
          expect(bloc.state.selectedDuration, offScreen.duration);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'archiving unfiles the clips when the user asked for that',
        setUp: () {
          when(
            () => mockClipLibraryService.setClipArchived(
              clipId: any(named: 'clipId'),
              archived: any(named: 'archived'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.setClipCategory(
              clipId: any(named: 'clipId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getCategories(),
          ).thenAnswer((_) async => [travel]);
        },
        build: createBloc,
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [onScreen.copyWith(categoryId: travel.id)],
          categories: [travel],
        ),
        act: (bloc) => bloc.add(
          const ClipsLibraryClipsArchiveChanged(
            clipIds: {'on-screen'},
            archived: true,
            clearCategory: true,
          ),
        ),
        verify: (bloc) {
          verify(
            () => mockClipLibraryService.setClipCategory(
              clipId: 'on-screen',
              categoryId: null,
            ),
          ).called(1);
          // The undo needs to know where the clip came from.
          expect(bloc.state.lastOrganizeResult?.previousCategoryIds, {
            'on-screen': travel.id,
          });
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'archiving leaves the category alone when the user kept it',
        setUp: () {
          when(
            () => mockClipLibraryService.setClipArchived(
              clipId: any(named: 'clipId'),
              archived: any(named: 'archived'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getCategories(),
          ).thenAnswer((_) async => [travel]);
        },
        build: createBloc,
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [onScreen.copyWith(categoryId: travel.id)],
          categories: [travel],
        ),
        act: (bloc) => bloc.add(
          const ClipsLibraryClipsArchiveChanged(
            clipIds: {'on-screen'},
            archived: true,
          ),
        ),
        verify: (bloc) {
          verifyNever(
            () => mockClipLibraryService.setClipCategory(
              clipId: any(named: 'clipId'),
              categoryId: any(named: 'categoryId'),
            ),
          );
          expect(bloc.state.lastOrganizeResult?.previousCategoryIds, isEmpty);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'undoing an archive files the clips back into their category',
        setUp: () {
          when(
            () => mockClipLibraryService.setClipArchived(
              clipId: any(named: 'clipId'),
              archived: any(named: 'archived'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.setClipCategory(
              clipId: any(named: 'clipId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getCategories(),
          ).thenAnswer((_) async => [travel]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ClipsLibraryClipsArchiveChanged(
            clipIds: const {'on-screen'},
            archived: false,
            restoreCategoryIds: {'on-screen': travel.id},
          ),
        ),
        verify: (bloc) {
          verify(
            () => mockClipLibraryService.setClipCategory(
              clipId: 'on-screen',
              categoryId: travel.id,
            ),
          ).called(1);
          verify(
            () => mockClipLibraryService.setClipArchived(
              clipId: 'on-screen',
              archived: false,
            ),
          ).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'archiving reports the clips so the UI can offer an undo',
        setUp: () {
          when(
            () => mockClipLibraryService.setClipArchived(
              clipId: any(named: 'clipId'),
              archived: any(named: 'archived'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getCategories(),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ClipsLibraryClipsArchiveChanged(
            clipIds: {'clip1', 'clip2'},
            archived: true,
          ),
        ),
        verify: (bloc) {
          verify(
            () => mockClipLibraryService.setClipArchived(
              clipId: 'clip1',
              archived: true,
            ),
          ).called(1);
          expect(
            bloc.state.lastOrganizeResult,
            const ClipsLibraryOrganizeResult(
              action: ClipsLibraryOrganizeAction.archived,
              clipIds: {'clip1', 'clip2'},
            ),
          );
        },
      );
    });
  });
}
