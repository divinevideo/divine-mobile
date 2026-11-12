import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/services/video_editor/native_render_task_registry.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;

void main() {
  group(NativeRenderTaskRegistry, () {
    tearDown(NativeRenderTaskRegistry.reset);

    group('track', () {
      test('exposes the task as active while it is in flight', () async {
        final gate = Completer<String>();

        final tracked = NativeRenderTaskRegistry.track(
          'task-1',
          () => gate.future,
        );

        expect(NativeRenderTaskRegistry.activeTaskIds, contains('task-1'));

        gate.complete('done');
        await tracked;

        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });

      test('returns the operation result', () async {
        final result = await NativeRenderTaskRegistry.track(
          'task-1',
          () async => '/tmp/out.mp4',
        );

        expect(result, equals('/tmp/out.mp4'));
      });

      test('stops tracking a task that throws, and rethrows', () async {
        await expectLater(
          NativeRenderTaskRegistry.track<void>(
            'task-1',
            () async => throw StateError('render failed'),
          ),
          throwsStateError,
        );

        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });

      test('tracks concurrent tasks independently', () async {
        final first = Completer<void>();
        final second = Completer<void>();

        final tracked = [
          NativeRenderTaskRegistry.track('task-1', () => first.future),
          NativeRenderTaskRegistry.track('task-2', () => second.future),
        ];

        expect(
          NativeRenderTaskRegistry.activeTaskIds,
          containsAll(<String>['task-1', 'task-2']),
        );

        first.complete();
        await tracked.first;

        expect(NativeRenderTaskRegistry.activeTaskIds, equals({'task-2'}));

        second.complete();
        await Future.wait(tracked);
      });

      // A re-registered id belongs to the newer call, so the displaced one
      // must not remove it on the way out — otherwise the live task silently
      // stops being cancellable at teardown.
      test('keeps the newer registration when an id is reused', () async {
        final first = Completer<void>();
        final second = Completer<void>();

        final firstTracked = NativeRenderTaskRegistry.track(
          'task-1',
          () => first.future,
        );
        final secondTracked = NativeRenderTaskRegistry.track(
          'task-1',
          () => second.future,
        );

        first.complete();
        await firstTracked;

        expect(NativeRenderTaskRegistry.activeTaskIds, contains('task-1'));

        second.complete();
        await secondTracked;

        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });
    });

    group('trackExclusively', () {
      test('starts at once when no task holds the id', () async {
        final cancelled = <String>[];
        var started = false;

        final tracked = NativeRenderTaskRegistry.trackExclusively(
          'task-1',
          () async {
            started = true;
            return 'done';
          },
          cancel: (id) async => cancelled.add(id),
        );

        expect(started, isTrue);
        expect(await tracked, equals('done'));
        expect(cancelled, isEmpty);
      });

      test('cancels the task holding the id and starts once it has '
          'settled', () async {
        final first = Completer<void>();
        final cancelled = <String>[];
        var secondStarted = false;

        final firstTracked = NativeRenderTaskRegistry.trackExclusively(
          'task-1',
          () => first.future,
          cancel: (_) async {},
        );
        final secondTracked = NativeRenderTaskRegistry.trackExclusively(
          'task-1',
          () async => secondStarted = true,
          cancel: (id) async => cancelled.add(id),
        );
        await pumpEventQueue();

        expect(cancelled, equals(['task-1']));
        expect(
          secondStarted,
          isFalse,
          reason: 'the cancelled task still holds the id',
        );

        first.complete();
        await firstTracked;
        await secondTracked;

        expect(secondStarted, isTrue);
        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });

      // The loop alignment registers a render's id around the render it
      // starts under that same id. Waiting for that registration would mean
      // waiting for itself.
      test('runs inside a track registration of the same id', () async {
        final cancelled = <String>[];

        final result = await NativeRenderTaskRegistry.track(
          'task-1',
          () => NativeRenderTaskRegistry.trackExclusively(
            'task-1',
            () async => 'rendered',
            cancel: (id) async => cancelled.add(id),
          ),
        ).timeout(const Duration(seconds: 5));

        expect(result, equals('rendered'));
        expect(cancelled, equals(['task-1']));
        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });

      // A render the watchdog gave up on can stay unsettled, and a cancel
      // stuck on a blocked platform thread never answers. Neither may hold
      // up every later render under the id.
      group('starts anyway once the hand-over bound has passed', () {
        final justBefore =
            VideoEditorConstants.renderTaskHandoverTimeout -
            const Duration(milliseconds: 1);

        test('when the task holding the id never settles', () {
          fakeAsync((async) {
            var secondStarted = false;
            unawaited(
              NativeRenderTaskRegistry.trackExclusively<void>(
                'task-1',
                () => Completer<void>().future,
                cancel: (_) async {},
              ),
            );
            unawaited(
              NativeRenderTaskRegistry.trackExclusively(
                'task-1',
                () async => secondStarted = true,
                cancel: (_) async {},
              ),
            );

            async.elapse(justBefore);
            expect(secondStarted, isFalse);

            async.elapse(const Duration(milliseconds: 1));
            expect(secondStarted, isTrue);
          });
        });

        test('when the cancel of that task never comes back', () {
          fakeAsync((async) {
            final first = Completer<void>();
            var secondStarted = false;
            unawaited(
              NativeRenderTaskRegistry.trackExclusively(
                'task-1',
                () => first.future,
                cancel: (_) async {},
              ),
            );
            unawaited(
              NativeRenderTaskRegistry.trackExclusively(
                'task-1',
                () async => secondStarted = true,
                cancel: (_) => Completer<void>().future,
              ),
            );
            first.complete();

            async.elapse(justBefore);
            expect(secondStarted, isFalse);

            async.elapse(const Duration(milliseconds: 1));
            expect(secondStarted, isTrue);
          });
        });
      });

      test('starts only the newest of the calls waiting for an id', () async {
        final first = Completer<void>();
        final started = <String>[];

        final firstTracked = NativeRenderTaskRegistry.trackExclusively(
          'task-1',
          () => first.future,
          cancel: (_) async {},
        );
        final overtaken = NativeRenderTaskRegistry.trackExclusively(
          'task-1',
          () async => started.add('overtaken'),
          cancel: (_) async {},
        );
        final newest = NativeRenderTaskRegistry.trackExclusively(
          'task-1',
          () async => started.add('newest'),
          cancel: (_) async {},
        );
        final overtakenCancellation = expectLater(
          overtaken,
          throwsA(isA<RenderCanceledException>()),
        );

        first.complete();
        await firstTracked;
        await overtakenCancellation;
        await newest;

        expect(started, equals(['newest']));
        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });
    });
  });
}
