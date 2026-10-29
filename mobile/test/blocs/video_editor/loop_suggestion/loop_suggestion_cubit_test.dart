import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:unified_logger/unified_logger.dart';

class _Repository extends Mock implements LoopAlignmentRepository {}

LoopRepairInput _input(String revision) => LoopRepairInput(
  clips: const [
    LoopClipInput(
      clipId: 'clip',
      path: '/documents/clip.mp4',
      sourceStart: Duration.zero,
      sourceEnd: Duration(seconds: 2),
      speed: 1,
      width: 180,
      height: 320,
    ),
  ],
  revision: revision,
);
LoopRepairResult _repaired() => LoopRepairResult(
  status: .repaired,
  output: LoopRenderedOutput(
    paths: const {'clip': '/documents/out.mp4'},
    metadata: const {},
  ),
);
void main() {
  late _Repository repository;
  setUpAll(() {
    registerFallbackValue(_input('fallback'));
    registerFallbackValue(const LoopRepairResult(status: .noMatch));
  });
  setUp(() async {
    await LogCaptureService().clearAllLogs();
    repository = _Repository();
    when(() => repository.cancel(any())).thenAnswer((_) async {});
    when(() => repository.discard(any())).thenAnswer((_) async {});
  });
  group('LoopSuggestionCubit.fix', () {
    for (final entry in {
      LoopRepairStatus.repaired: LoopSuggestionStatus.repaired,
      LoopRepairStatus.alreadySmooth: LoopSuggestionStatus.alreadySmooth,
      LoopRepairStatus.noMatch: LoopSuggestionStatus.noMatch,
      LoopRepairStatus.unsupported: LoopSuggestionStatus.unsupported,
    }.entries) {
      test(
        'presents ${entry.key} and transfers handled result ownership',
        () async {
          final result = LoopRepairResult(status: entry.key);
          when(
            () => repository.repair(
              any(),
              taskId: any(named: 'taskId'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((_) async => result);
          const revision = 'rev-0b7d2f';
          final cubit = LoopSuggestionCubit(repository: repository);
          addTearDown(cubit.close);
          await cubit.fix(_input(revision));
          expect(cubit.state.status, entry.value);
          final logs = (await LogCaptureService().getAllLogsAsText()).join(
            '\n',
          );
          expect(logs, contains('status=${entry.key.name}'));
          expect(logs, isNot(contains('/documents/clip.mp4')));
          expect(logs, isNot(contains(revision)));
          cubit.resultHandled();
          expect(cubit.state.status, LoopSuggestionStatus.idle);
        },
      );
    }
    test('repeated taps start exactly one job', () async {
      final gate = Completer<LoopRepairResult>();
      var calls = 0;
      when(
        () => repository.repair(
          any(),
          taskId: any(named: 'taskId'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) {
        calls++;
        return gate.future;
      });
      final cubit = LoopSuggestionCubit(repository: repository);
      addTearDown(cubit.close);
      final operation = cubit.fix(_input('one'));
      await cubit.fix(_input('one'));
      expect(calls, 1);
      gate.complete(const LoopRepairResult(status: .alreadySmooth));
      await operation;
      expect(cubit.state.status, LoopSuggestionStatus.alreadySmooth);
    });
    test(
      'cancelled late result is discarded and cannot overwrite a new job',
      () async {
        final gates = [
          Completer<LoopRepairResult>(),
          Completer<LoopRepairResult>(),
        ];
        final progress = <void Function(double)>[];
        var calls = 0;
        when(
          () => repository.repair(
            any(),
            taskId: any(named: 'taskId'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((call) {
          progress.add(
            call.namedArguments[#onProgress] as void Function(double),
          );
          return gates[calls++].future;
        });
        final cubit = LoopSuggestionCubit(repository: repository);
        addTearDown(cubit.close);
        final old = cubit.fix(_input('one'));
        await cubit.cancel();
        final current = cubit.fix(_input('two'));
        progress[0](.9);
        expect(cubit.state.progress, 0);
        final late = _repaired();
        gates[0].complete(late);
        await old;
        expect(cubit.state.status, LoopSuggestionStatus.searching);
        expect(cubit.state.request?.revision, 'two');
        verify(() => repository.discard(late)).called(1);
        progress[1](.4);
        expect(cubit.state.progress, .4);
        gates[1].complete(const LoopRepairResult(status: .noMatch));
        await current;
      },
    );
    test('composition invalidation and close suppress completion', () async {
      final gate = Completer<LoopRepairResult>();
      when(
        () => repository.repair(
          any(),
          taskId: any(named: 'taskId'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) => gate.future);
      final cubit = LoopSuggestionCubit(repository: repository);
      final operation = cubit.fix(_input('one'));
      cubit.compositionChanged('different');
      expect(cubit.state.status, LoopSuggestionStatus.idle);
      await cubit.close();
      final late = _repaired();
      gate.complete(late);
      await operation;
      verify(() => repository.discard(late)).called(1);
    });
    for (final error in [
      const LoopAlignmentFailure('decode'),
      const LoopAlignmentTimeout(),
    ]) {
      blocTest<LoopSuggestionCubit, LoopSuggestionState>(
        'reports technical ${error.runtimeType} separately from no match',
        build: () {
          when(
            () => repository.repair(
              any(),
              taskId: any(named: 'taskId'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenThrow(error);
          return LoopSuggestionCubit(repository: repository);
        },
        act: (cubit) => cubit.fix(_input('one')),
        expect: () => [
          isA<LoopSuggestionState>().having(
            (s) => s.status,
            'busy',
            LoopSuggestionStatus.searching,
          ),
          isA<LoopSuggestionState>().having(
            (s) => s.status,
            'failure',
            error is LoopAlignmentTimeout
                ? LoopSuggestionStatus.timedOut
                : LoopSuggestionStatus.failed,
          ),
        ],
        errors: () => [error],
      );
    }
    blocTest<LoopSuggestionCubit, LoopSuggestionState>(
      'failed native cancellation still invalidates ownership and reports the error',
      build: () {
        when(
          () => repository.repair(
            any(),
            taskId: any(named: 'taskId'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) => Completer<LoopRepairResult>().future);
        when(() => repository.cancel(any()))
            .thenThrow(const LoopAlignmentFailure('cancel'));
        return LoopSuggestionCubit(repository: repository);
      },
      act: (cubit) async {
        unawaited(cubit.fix(_input('one')));
        await expectLater(cubit.cancel(), completes);
      },
      expect: () => [
        isA<LoopSuggestionState>().having((s) => s.isSearching, 'busy', true),
        isA<LoopSuggestionState>().having(
          (s) => s.status,
          'idle',
          LoopSuggestionStatus.idle,
        ),
      ],
      errors: () => [isA<LoopAlignmentFailure>()],
    );
  });
}
