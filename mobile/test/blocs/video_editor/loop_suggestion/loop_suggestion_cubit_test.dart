import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_editor/clip_loop_point_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  const s = Duration(seconds: 1);
  const ms = Duration(milliseconds: 1);

  final clip = DivineVideoClip(
    id: 'clip',
    video: EditorVideo.file(File('/docs/clip.mp4')),
    duration: s * 6,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );

  /// Finds [point] after reporting [progress].
  FindClipLoopPointFn finder(
    FutureOr<VideoLoopPoint> Function() point, {
    List<String>? taskIds,
    List<double> progress = const [],
  }) => ({required search, required taskId, onProgress}) async {
    taskIds?.add(taskId);
    progress.forEach(onProgress!.call);
    return point();
  };

  VideoLoopPoint point({
    required Duration end,
    required double difference,
    double currentDifference = 0.1,
  }) => VideoLoopPoint(
    start: Duration.zero,
    end: end,
    difference: difference,
    currentDifference: currentDifference,
  );

  group(LoopSuggestionCubit, () {
    group('search', () {
      final taskIds = <String>[];
      setUp(taskIds.clear);

      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'reports its progress, then the clip trimmed to a smoother end',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(
            () => point(end: ms * 4200, difference: 0.01),
            taskIds: taskIds,
            progress: const [0.5],
          ),
        ),
        act: (cubit) => cubit.search([clip]),
        expect: () => [
          isA<LoopSuggestionState>()
              .having((s) => s.status, 'status', LoopSuggestionStatus.searching)
              .having((s) => s.original, 'original', same(clip)),
          isA<LoopSuggestionState>().having((s) => s.progress, 'progress', 0.5),
          isA<LoopSuggestionState>()
              .having((s) => s.status, 'status', LoopSuggestionStatus.suggested)
              .having((s) => s.suggested?.trimEnd, 'trimEnd', ms * 1800)
              .having((s) => s.isCloseMatch, 'isCloseMatch', isTrue),
        ],
        verify: (_) =>
            expect(taskIds, [ClipLoopPointService.taskIdFor('clip')]),
      );

      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'calls a smoother end that still differs only the closest one',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(
            () => point(end: ms * 4200, difference: 0.05, currentDifference: 1),
          ),
        ),
        act: (cubit) => cubit.search([clip]),
        skip: 1,
        expect: () => [
          isA<LoopSuggestionState>()
              .having((s) => s.status, 'status', LoopSuggestionStatus.suggested)
              .having((s) => s.isCloseMatch, 'isCloseMatch', isFalse),
        ],
      );

      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'says the video already loops smoothly when no cut does much better',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(
            () => point(
              end: ms * 4200,
              difference: 0.008,
              currentDifference: 0.009,
            ),
          ),
        ),
        act: (cubit) => cubit.search([clip]),
        skip: 1,
        expect: () => [
          isA<LoopSuggestionState>()
              .having(
                (s) => s.status,
                'status',
                LoopSuggestionStatus.alreadySmooth,
              )
              .having((s) => s.suggested, 'suggested', isNull),
        ],
      );

      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'says nothing lines up when the motion never comes back around',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(
            () => point(
              end: ms * 3400,
              difference: 0.26,
              currentDifference: 0.28,
            ),
          ),
        ),
        act: (cubit) => cubit.search([clip]),
        skip: 1,
        expect: () => [
          isA<LoopSuggestionState>()
              .having((s) => s.status, 'status', LoopSuggestionStatus.noMatch)
              .having((s) => s.suggested, 'suggested', isNull),
        ],
      );

      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'says the video already loops smoothly when its end is the best one',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(
            () =>
                point(end: s * 6, difference: 0.001, currentDifference: 0.001),
          ),
        ),
        act: (cubit) => cubit.search([clip]),
        skip: 1,
        expect: () => [
          isA<LoopSuggestionState>().having(
            (s) => s.status,
            'status',
            LoopSuggestionStatus.alreadySmooth,
          ),
        ],
      );

      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'goes back to idle when cancelled',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(() => throw const RenderCanceledException()),
        ),
        act: (cubit) => cubit.search([clip]),
        skip: 1,
        expect: () => [const LoopSuggestionState()],
        errors: () => isEmpty,
      );

      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'fails without reporting a clip it cannot read',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(
            () => throw PlatformException(code: 'FRAME_STREAM_ERROR'),
          ),
        ),
        act: (cubit) => cubit.search([clip]),
        skip: 1,
        expect: () => [
          isA<LoopSuggestionState>().having(
            (s) => s.status,
            'status',
            LoopSuggestionStatus.failed,
          ),
        ],
        errors: () => [isA<PlatformException>()],
      );

      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'reports a failure of its own',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(() => throw StateError('no frames')),
        ),
        act: (cubit) => cubit.search([clip]),
        skip: 1,
        expect: () => [
          isA<LoopSuggestionState>().having(
            (s) => s.status,
            'status',
            LoopSuggestionStatus.failed,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );
    });

    group('resultHandled', () {
      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'forgets a suggestion once it was kept or dropped',
        build: () => LoopSuggestionCubit(
          findLoopPoint: finder(() => point(end: ms * 4200, difference: 0.01)),
        ),
        act: (cubit) async {
          await cubit.search([clip]);
          cubit.resultHandled();
        },
        skip: 2,
        expect: () => [const LoopSuggestionState()],
      );
    });
  });
}
