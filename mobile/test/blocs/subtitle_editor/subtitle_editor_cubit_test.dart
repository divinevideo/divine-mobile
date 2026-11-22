// ABOUTME: Tests for SubtitleEditorCubit covering load, edit, and save flows.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';

class _MockRepo extends Mock implements SubtitleRepository {}

final _video = VideoEvent(
  id: 'v',
  pubkey: 'pk',
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  vineId: 'd1',
);

final VideoEvent _updatedVideo = _video.copyWith(
  id: 'updated',
  textTrackRef: 'https://media.divine.video/edited.vtt',
);

const _availableResult = SubtitleFetchResult(
  SubtitleFetchStatus.available,
  cues: [SubtitleCue(start: 0, end: 1000, text: 'a')],
);

void main() {
  setUpAll(() => registerFallbackValue(_video));

  group(SubtitleEditorCubit, () {
    late _MockRepo repo;
    setUp(() => repo = _MockRepo());

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load -> ready with cues',
      setUp: () => when(
        () => repo.loadCues(any()),
      ).thenAnswer((_) async => _availableResult),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.loading,
        ),
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.ready)
            .having((s) => s.cues.length, 'cues', 1),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load while transcription is running -> processing',
      setUp: () => when(() => repo.loadCues(any())).thenAnswer(
        (_) async => const SubtitleFetchResult(SubtitleFetchStatus.processing),
      ),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.loading,
        ),
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.processing,
        ),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load of a finished but cue-less track -> empty, not processing',
      setUp: () => when(() => repo.loadCues(any())).thenAnswer(
        (_) async => const SubtitleFetchResult(SubtitleFetchStatus.empty),
      ),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.loading,
        ),
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.empty,
        ),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load with no reachable track -> unavailable',
      setUp: () => when(() => repo.loadCues(any())).thenAnswer(
        (_) async => const SubtitleFetchResult(SubtitleFetchStatus.unavailable),
      ),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.loading,
        ),
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.unavailable,
        ),
      ],
    );

    test('a reload that finds no track drops the cues it had', () async {
      when(
        () => repo.loadCues(any()),
      ).thenAnswer((_) async => _availableResult);
      final cubit = SubtitleEditorCubit(repository: repo, video: _video);
      addTearDown(cubit.close);

      await cubit.load();
      cubit.updateCueText(0, 'corrected');
      expect(cubit.state.cues, hasLength(1));
      expect(cubit.state.isDirty, isTrue);

      when(() => repo.loadCues(any())).thenAnswer(
        (_) async => const SubtitleFetchResult(SubtitleFetchStatus.empty),
      );
      await cubit.load();

      expect(cubit.state.status, SubtitleEditorStatus.empty);
      expect(cubit.state.cues, isEmpty, reason: 'no stale cues underneath');
      expect(cubit.state.isDirty, isFalse);
    });

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load failure -> failure + reports error',
      setUp: () =>
          when(() => repo.loadCues(any())).thenThrow(Exception('boom')),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.loading,
        ),
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.failure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'updateCueText marks dirty',
      setUp: () => when(
        () => repo.loadCues(any()),
      ).thenAnswer((_) async => _availableResult),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        c.updateCueText(0, 'fixed');
      },
      verify: (c) {
        expect(c.state.isDirty, isTrue);
        expect(c.state.cues.first.text, 'fixed');
      },
    );

    group('loaded track', () {
      const fallbackRef = 'https://media.divine.video/english.vtt';
      const fallbackResult = SubtitleFetchResult(
        SubtitleFetchStatus.available,
        cues: [SubtitleCue(start: 0, end: 1000, text: 'a')],
        ref: fallbackRef,
      );

      test('save edits the track the cues were loaded from', () async {
        when(
          () => repo.loadCues(any()),
        ).thenAnswer((_) async => fallbackResult);
        when(
          () => repo.publishEditedSubtitles(
            video: any(named: 'video'),
            cues: any(named: 'cues'),
            loadedRef: any(named: 'loadedRef'),
          ),
        ).thenAnswer((_) async => _updatedVideo);
        final cubit = SubtitleEditorCubit(repository: repo, video: _video);
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.save();

        verify(
          () => repo.publishEditedSubtitles(
            video: any(named: 'video'),
            cues: any(named: 'cues'),
            loadedRef: fallbackRef,
          ),
        ).called(1);
      });

      test('a reload from embedded cues forgets the earlier track', () async {
        var result = fallbackResult;
        when(() => repo.loadCues(any())).thenAnswer((_) async => result);
        final cubit = SubtitleEditorCubit(repository: repo, video: _video);
        addTearDown(cubit.close);

        await cubit.load();
        expect(cubit.state.loadedTrackRef, fallbackRef);
        result = _availableResult;
        await cubit.load();

        expect(cubit.state.loadedTrackRef, isNull);
      });
    });

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'save success -> saving then success',
      setUp: () {
        when(
          () => repo.loadCues(any()),
        ).thenAnswer((_) async => _availableResult);
        when(
          () => repo.publishEditedSubtitles(
            video: any(named: 'video'),
            cues: any(named: 'cues'),
          ),
        ).thenAnswer((_) async => _updatedVideo);
      },
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        await c.save();
      },
      skip: 2,
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.saving,
        ),
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.success)
            .having((s) => s.isDirty, 'isDirty', false)
            .having((s) => s.updatedVideo, 'updatedVideo', _updatedVideo),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'save failure -> failure + reports error',
      setUp: () {
        when(
          () => repo.loadCues(any()),
        ).thenAnswer((_) async => _availableResult);
        when(
          () => repo.publishEditedSubtitles(
            video: any(named: 'video'),
            cues: any(named: 'cues'),
          ),
        ).thenThrow(SubtitleEditException('boom'));
      },
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        await c.save();
      },
      skip: 2,
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.saving,
        ),
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.failure,
        ),
      ],
      errors: () => [isA<SubtitleEditException>()],
    );

    group('authoring', () {
      test('addCue on an empty track starts a draft at 0', () async {
        when(() => repo.loadCues(any())).thenAnswer(
          (_) async => const SubtitleFetchResult(SubtitleFetchStatus.empty),
        );
        final cubit = SubtitleEditorCubit(repository: repo, video: _video);
        addTearDown(cubit.close);

        await cubit.load();
        expect(cubit.state.status, SubtitleEditorStatus.empty);

        cubit.addCue();

        expect(cubit.state.status, SubtitleEditorStatus.ready);
        expect(cubit.state.isDirty, isTrue);
        expect(cubit.state.cues.single.start, 0);
        expect(cubit.state.cues.single.end, 2000);
        expect(cubit.state.cues.single.text, isEmpty);
      });

      test('addCue appends after the previous cue', () async {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..addCue();
        addTearDown(cubit.close);

        expect(cubit.state.cues.map((c) => (c.start, c.end)), [
          (0, 2000),
          (2000, 4000),
        ]);
      });

      test('addCue stops once the cues reach the end of the video', () async {
        final cubit =
            SubtitleEditorCubit(
                repository: repo,
                video: _video.copyWith(duration: 4),
              )
              ..addCue()
              ..addCue();
        addTearDown(cubit.close);

        expect(cubit.state.cues.last.end, 4000, reason: 'fills the video');
        expect(cubit.state.canAddCue, isFalse);

        cubit.addCue();

        expect(cubit.state.cues, hasLength(2), reason: 'no cue past the end');
      });

      test('addCue keeps going when the duration is unknown', () async {
        final cubit =
            SubtitleEditorCubit(
                repository: repo,
                video: _video.copyWith(duration: 0),
              )
              ..addCue()
              ..addCue();
        addTearDown(cubit.close);

        expect(cubit.state.canAddCue, isTrue);
        expect(cubit.state.cues, hasLength(2));
      });

      test('addCue trims the new cue to the end of the video', () async {
        // Second cue would run 2.0s–4.0s, past the end of a 3s video.
        final cubit =
            SubtitleEditorCubit(
                repository: repo,
                video: _video.copyWith(duration: 3),
              )
              ..addCue()
              ..addCue();
        addTearDown(cubit.close);

        expect(cubit.state.cues.last.end, 3000);
      });

      test('removeCue drops the cue at the given index', () async {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..addCue()
          ..updateCueText(0, 'first')
          ..updateCueText(1, 'second')
          ..removeCue(0);
        addTearDown(cubit.close);

        expect(cubit.state.cues.single.text, 'second');
      });

      test('updateCueTiming leaves the untouched bound alone', () async {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..updateCueTiming(0, start: 500);
        addTearDown(cubit.close);

        expect(cubit.state.cues.single.start, 500);
        expect(cubit.state.cues.single.end, 2000);
      });

      test('a draft is invalid until every cue has text and length', () async {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue();
        addTearDown(cubit.close);

        expect(cubit.state.isValid, isFalse, reason: 'blank text');

        cubit.updateCueText(0, 'hello');
        expect(cubit.state.isValid, isTrue);

        cubit.updateCueTiming(0, end: 0);
        expect(cubit.state.isValid, isFalse, reason: 'ends before it starts');
      });

      test('save publishes hand-edited cues in timeline order', () async {
        when(
          () => repo.publishEditedSubtitles(
            video: any(named: 'video'),
            cues: any(named: 'cues'),
          ),
        ).thenAnswer((_) async => _updatedVideo);

        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..addCue()
          ..updateCueText(0, 'second')
          ..updateCueText(1, 'first')
          ..updateCueTiming(0, start: 3000, end: 4000)
          ..updateCueTiming(1, start: 0, end: 1000);
        addTearDown(cubit.close);

        await cubit.save();

        final published =
            verify(
                  () => repo.publishEditedSubtitles(
                    video: any(named: 'video'),
                    cues: captureAny(named: 'cues'),
                  ),
                ).captured.single
                as List<SubtitleCue>;

        expect(published.map((c) => c.text), ['first', 'second']);
      });

      test('edits made while a save is in flight are dropped', () async {
        final publish = Completer<VideoEvent>();
        when(
          () => repo.publishEditedSubtitles(
            video: any(named: 'video'),
            cues: any(named: 'cues'),
          ),
        ).thenAnswer((_) => publish.future);

        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..updateCueText(0, 'written');
        addTearDown(cubit.close);

        final saving = cubit.save();
        expect(cubit.state.status, SubtitleEditorStatus.saving);

        cubit
          ..addCue()
          ..updateCueText(0, 'clobbered')
          ..removeCue(0);

        // The busy state survives, so the spinner stays up and the save
        // button cannot re-enable for a second publish on top of the first.
        expect(cubit.state.status, SubtitleEditorStatus.saving);
        expect(cubit.state.cues.single.text, 'written');

        publish.complete(_updatedVideo);
        await saving;
        expect(cubit.state.status, SubtitleEditorStatus.success);
      });
    });

    test('load completes without emitting after close', () async {
      final completer = Completer<SubtitleFetchResult>();
      when(() => repo.loadCues(any())).thenAnswer((_) => completer.future);
      final cubit = SubtitleEditorCubit(repository: repo, video: _video);

      final loadFuture = cubit.load();
      expect(cubit.state.status, SubtitleEditorStatus.loading);

      await cubit.close();
      completer.complete(
        const SubtitleFetchResult(
          SubtitleFetchStatus.available,
          cues: [SubtitleCue(start: 0, end: 1000, text: 'late')],
        ),
      );

      await expectLater(loadFuture, completes);
    });

    test('save completes without emitting after close', () async {
      final completer = Completer<VideoEvent>();
      when(
        () => repo.publishEditedSubtitles(
          video: any(named: 'video'),
          cues: any(named: 'cues'),
        ),
      ).thenAnswer((_) => completer.future);
      final cubit = SubtitleEditorCubit(repository: repo, video: _video);

      final saveFuture = cubit.save();
      expect(cubit.state.status, SubtitleEditorStatus.saving);

      await cubit.close();
      completer.complete(_updatedVideo);

      await expectLater(saveFuture, completes);
    });

    group('selection', () {
      test('addCue hands the creator the cue it just made', () {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..addCue();
        addTearDown(cubit.close);

        expect(cubit.state.selectedCueIndex, 1);
      });

      test('removing an earlier cue keeps the selection on the same cue', () {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..addCue()
          ..addCue()
          ..selectCue(2)
          ..removeCue(0);
        addTearDown(cubit.close);

        // Cues are addressed positionally, so the third one is now second.
        expect(cubit.state.selectedCueIndex, 1);
      });

      test('removing the selected cue clears the selection', () {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..addCue()
          ..selectCue(0)
          ..removeCue(0);
        addTearDown(cubit.close);

        expect(cubit.state.selectedCueIndex, isNull);
      });

      test('an out-of-range selection is dropped, not stored', () {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue()
          ..selectCue(0)
          ..selectCue(7);
        addTearDown(cubit.close);

        expect(cubit.state.selectedCueIndex, isNull);
      });

      test(
        'a reload drops the selection with the cues it pointed at',
        () async {
          when(
            () => repo.loadCues(any()),
          ).thenAnswer((_) async => _availableResult);
          final cubit = SubtitleEditorCubit(repository: repo, video: _video)
            ..addCue()
            ..selectCue(0);
          addTearDown(cubit.close);

          await cubit.load();

          expect(cubit.state.selectedCueIndex, isNull);
        },
      );
    });

    group('timelineDurationMs', () {
      test('uses the video duration when the event declares one', () {
        final cubit = SubtitleEditorCubit(
          repository: repo,
          video: _video.copyWith(duration: 6),
        );
        addTearDown(cubit.close);

        expect(cubit.state.timelineDurationMs, 6000);
      });

      test('leaves room past the last cue when the duration is unknown', () {
        final cubit = SubtitleEditorCubit(repository: repo, video: _video)
          ..addCue();
        addTearDown(cubit.close);

        // Without headroom the axis would end on the cue, leaving nothing to
        // drag it into.
        expect(cubit.state.timelineDurationMs, greaterThan(2000));
      });
    });
  });
}
