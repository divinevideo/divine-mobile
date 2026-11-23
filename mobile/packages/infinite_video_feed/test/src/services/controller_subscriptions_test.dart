import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/services/controller_subscriptions.dart';

import '../../helpers/fake_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(ControllerSubscriptions, () {
    late ControllerSubscriptions subs;

    setUp(() => subs = ControllerSubscriptions());
    tearDown(() => subs.disposeAll());

    // ------------------------------------------------------------------
    group('subscribeToPlaybackErrors', () {
      test(
        'handles an existing failure once and observes a later failure',
        () async {
          final controller = FakeController();
          addTearDown(controller.dispose);
          const failure = DivineVideoPlayerState(
            status: PlaybackStatus.error,
            errorMessage: 'Synthetic renderer unavailable',
          );
          controller.pushState(failure);
          final errors = <String?>[];

          subs.subscribeToPlaybackErrors(
            0,
            controller,
            isAlreadyError: () => false,
            onError: (_, message) => errors.add(message),
          );
          expect(errors, ['Synthetic renderer unavailable']);
          controller.pushState(failure);
          await pumpEventQueue();
          expect(errors, hasLength(1));

          controller
            ..pushState(
              const DivineVideoPlayerState(status: PlaybackStatus.playing),
            )
            ..pushState(failure);
          await pumpEventQueue();
          expect(errors, [
            'Synthetic renderer unavailable',
            'Synthetic renderer unavailable',
          ]);
        },
      );

      test(
        'does not repeat an existing failure already handled by the feed',
        () {
          final controller = FakeController()
            ..pushState(
              const DivineVideoPlayerState(status: PlaybackStatus.error),
            );
          addTearDown(controller.dispose);
          final errors = <String?>[];

          subs.subscribeToPlaybackErrors(
            0,
            controller,
            isAlreadyError: () => true,
            onError: (_, message) => errors.add(message),
          );

          expect(errors, isEmpty);
        },
      );

      test('fires onError when controller emits error state', () async {
        final controller = FakeController();
        final errors = <(NativePlayerErrorCode?, String?)>[];

        subs.subscribeToPlaybackErrors(
          0,
          controller,
          isAlreadyError: () => false,
          onError: (code, msg) => errors.add((code, msg)),
        );

        controller.pushState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.error,
            errorMessage: 'oops',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(errors, hasLength(1));
        expect(errors.first.$2, equals('oops'));
      });

      test('does not fire when isAlreadyError returns true', () async {
        final controller = FakeController();
        final errors = <(NativePlayerErrorCode?, String?)>[];

        subs.subscribeToPlaybackErrors(
          0,
          controller,
          isAlreadyError: () => true,
          onError: (code, msg) => errors.add((code, msg)),
        );

        controller.pushState(
          const DivineVideoPlayerState(status: PlaybackStatus.error),
        );
        await Future<void>.delayed(Duration.zero);

        expect(errors, isEmpty);
      });

      test('does not fire for non-error states', () async {
        final controller = FakeController();
        final errors = <Object>[];

        subs.subscribeToPlaybackErrors(
          0,
          controller,
          isAlreadyError: () => false,
          onError: (_, _) => errors.add(0),
        );

        controller.pushState(
          const DivineVideoPlayerState(status: PlaybackStatus.playing),
        );
        await Future<void>.delayed(Duration.zero);

        expect(errors, isEmpty);
      });
    });

    // ------------------------------------------------------------------
    group('subscribeToAutoAdvance', () {
      test(
        'fires onLoopCompleted when position resets from near end',
        () async {
          final controller = FakeController();
          var loopFired = false;

          subs.subscribeToAutoAdvance(
            0,
            controller,
            endThreshold: const Duration(milliseconds: 200),
            startThreshold: const Duration(milliseconds: 100),
            isCurrent: () => true,
            onLoopCompleted: () => loopFired = true,
          );

          // Push state near end to arm.
          controller.pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 9900),
              duration: Duration(seconds: 10),
            ),
          );
          await Future<void>.delayed(Duration.zero);

          // Push reset back to near zero.
          controller.pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 50),
              duration: Duration(seconds: 10),
            ),
          );
          await Future<void>.delayed(Duration.zero);

          expect(loopFired, isTrue);
        },
      );

      test(
        'fires when subscription starts while controller is near end',
        () async {
          final controller = FakeController()
            ..pushState(
              const DivineVideoPlayerState(
                status: PlaybackStatus.playing,
                position: Duration(milliseconds: 9900),
                duration: Duration(seconds: 10),
              ),
            );
          var loopFired = false;

          subs.subscribeToAutoAdvance(
            0,
            controller,
            endThreshold: const Duration(milliseconds: 200),
            startThreshold: const Duration(milliseconds: 100),
            isCurrent: () => true,
            onLoopCompleted: () => loopFired = true,
          );

          controller.pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 50),
              duration: Duration(seconds: 10),
            ),
          );
          await Future<void>.delayed(Duration.zero);

          expect(loopFired, isTrue);
        },
      );

      test(
        'does not fire when the reset position repeats without moving backward',
        () async {
          final controller = FakeController();
          var loopFired = false;

          subs.subscribeToAutoAdvance(
            0,
            controller,
            endThreshold: const Duration(milliseconds: 200),
            startThreshold: const Duration(milliseconds: 100),
            isCurrent: () => true,
            onLoopCompleted: () => loopFired = true,
          );

          controller.pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 9900),
              duration: Duration(seconds: 10),
            ),
          );
          await Future<void>.delayed(Duration.zero);

          controller.pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 50),
              duration: Duration(seconds: 10),
            ),
          );
          await Future<void>.delayed(Duration.zero);

          loopFired = false;

          controller.pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 50),
              duration: Duration(seconds: 10),
            ),
          );
          await Future<void>.delayed(Duration.zero);

          expect(loopFired, isFalse);
        },
      );

      test('does not fire when the jump back starts mid-clip', () async {
        final controller = FakeController();
        var loopFired = false;

        subs.subscribeToAutoAdvance(
          0,
          controller,
          endThreshold: const Duration(milliseconds: 200),
          startThreshold: const Duration(milliseconds: 100),
          isCurrent: () => true,
          onLoopCompleted: () => loopFired = true,
        );

        // A stale-playback recovery seek jumps backward from the middle of
        // the clip. Arming on that would auto-advance a video the viewer is
        // still watching.
        controller
          ..pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(seconds: 1),
              duration: Duration(seconds: 10),
            ),
          )
          ..pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 50),
              duration: Duration(seconds: 10),
            ),
          );
        await Future<void>.delayed(Duration.zero);

        expect(loopFired, isFalse);
      });

      test('does not fire when not current', () async {
        final controller = FakeController();
        var loopFired = false;

        subs.subscribeToAutoAdvance(
          0,
          controller,
          endThreshold: const Duration(milliseconds: 200),
          startThreshold: const Duration(milliseconds: 100),
          isCurrent: () => false,
          onLoopCompleted: () => loopFired = true,
        );

        controller
          ..pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 9900),
              duration: Duration(seconds: 10),
            ),
          )
          ..pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 10),
              duration: Duration(seconds: 10),
            ),
          );
        await Future<void>.delayed(Duration.zero);

        expect(loopFired, isFalse);
      });
    });

    // ------------------------------------------------------------------
    group('subscribeToDimensions', () {
      test('fires onDimensionsReady when dimensions arrive', () async {
        final controller = FakeController();
        var fired = false;

        subs.subscribeToDimensions(
          0,
          controller,
          onDimensionsReady: () => fired = true,
        );

        controller.pushState(
          const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
        );
        await Future<void>.delayed(Duration.zero);

        expect(fired, isTrue);
      });

      test(
        'fires onDimensionsReady synchronously when already known',
        () async {
          final controller = FakeController()
            ..pushState(
              const DivineVideoPlayerState(videoWidth: 1280, videoHeight: 720),
            );
          var count = 0;

          subs.subscribeToDimensions(
            0,
            controller,
            onDimensionsReady: () => count++,
          );

          // Synchronous fire — no async gap needed.
          expect(count, equals(1));

          // Further state pushes must not re-fire (no subscription was
          // created).
          controller.pushState(
            const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
          );
          await Future<void>.delayed(Duration.zero);
          expect(count, equals(1));
        },
      );

      test('fires only once even on further state updates', () async {
        final controller = FakeController();
        var count = 0;

        subs.subscribeToDimensions(
          0,
          controller,
          onDimensionsReady: () => count++,
        );

        controller.pushState(
          const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
        );
        await Future<void>.delayed(Duration.zero);
        controller.pushState(
          const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
        );
        await Future<void>.delayed(Duration.zero);

        expect(count, equals(1));
      });
    });

    // ------------------------------------------------------------------
    group('subscribeToFirstFrame', () {
      test('fires onFirstFrame when first-frame flag flips to true', () async {
        final controller = FakeController();
        var fired = false;

        subs.subscribeToFirstFrame(
          0,
          controller,
          onFirstFrame: () => fired = true,
        );

        controller.pushState(
          const DivineVideoPlayerState(isFirstFrameRendered: true),
        );
        await Future<void>.delayed(Duration.zero);

        expect(fired, isTrue);
      });

      test('fires onFirstFrame synchronously when already rendered', () async {
        final controller = FakeController()
          ..pushState(const DivineVideoPlayerState(isFirstFrameRendered: true));
        var count = 0;

        subs.subscribeToFirstFrame(0, controller, onFirstFrame: () => count++);

        // Synchronous fire — no async gap needed.
        expect(count, equals(1));

        // Further state pushes must not re-fire (no subscription was
        // created).
        controller.pushState(
          const DivineVideoPlayerState(isFirstFrameRendered: true),
        );
        await Future<void>.delayed(Duration.zero);
        expect(count, equals(1));
      });

      test('fires only once even on further state updates', () async {
        final controller = FakeController();
        var count = 0;

        subs.subscribeToFirstFrame(0, controller, onFirstFrame: () => count++);

        controller.pushState(
          const DivineVideoPlayerState(isFirstFrameRendered: true),
        );
        await Future<void>.delayed(Duration.zero);
        controller.pushState(
          const DivineVideoPlayerState(isFirstFrameRendered: true),
        );
        await Future<void>.delayed(Duration.zero);

        expect(count, equals(1));
      });

      test('does not fire while first-frame flag is still false', () async {
        final controller = FakeController();
        var fired = false;

        subs.subscribeToFirstFrame(
          0,
          controller,
          onFirstFrame: () => fired = true,
        );

        controller.pushState(
          const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
        );
        await Future<void>.delayed(Duration.zero);

        expect(fired, isFalse);
      });
    });

    // ------------------------------------------------------------------
    group('unsubscribe', () {
      test('cancels subscriptions for a specific index', () async {
        final controller = FakeController();
        final errors = <Object>[];

        subs
          ..subscribeToPlaybackErrors(
            1,
            controller,
            isAlreadyError: () => false,
            onError: (_, _) => errors.add(0),
          )
          ..unsubscribe(1);

        controller.pushState(
          const DivineVideoPlayerState(status: PlaybackStatus.error),
        );
        await Future<void>.delayed(Duration.zero);

        expect(errors, isEmpty);
      });
    });

    // ------------------------------------------------------------------
    group('disposeAll', () {
      test('cancels all subscriptions', () async {
        final c0 = FakeController();
        final c1 = FakeController();
        final events = <int>[];

        subs
          ..subscribeToPlaybackErrors(
            0,
            c0,
            isAlreadyError: () => false,
            onError: (_, _) => events.add(0),
          )
          ..subscribeToPlaybackErrors(
            1,
            c1,
            isAlreadyError: () => false,
            onError: (_, _) => events.add(1),
          )
          ..disposeAll();

        c0.pushState(
          const DivineVideoPlayerState(status: PlaybackStatus.error),
        );
        c1.pushState(
          const DivineVideoPlayerState(status: PlaybackStatus.error),
        );
        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
      });

      test('cancels all four subscription types', () async {
        final controller = FakeController();
        var errorCalled = false;
        var loopFired = false;
        var dimCalled = false;
        var firstFrameCalled = false;

        subs
          ..subscribeToPlaybackErrors(
            0,
            controller,
            isAlreadyError: () => false,
            onError: (_, _) => errorCalled = true,
          )
          ..subscribeToAutoAdvance(
            0,
            controller,
            endThreshold: const Duration(milliseconds: 200),
            startThreshold: const Duration(milliseconds: 100),
            isCurrent: () => true,
            onLoopCompleted: () => loopFired = true,
          )
          ..subscribeToDimensions(
            0,
            controller,
            onDimensionsReady: () => dimCalled = true,
          )
          ..subscribeToFirstFrame(
            0,
            controller,
            onFirstFrame: () => firstFrameCalled = true,
          )
          ..disposeAll();

        // After disposeAll none of the callbacks should fire.
        controller
          ..pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 9900),
              duration: Duration(seconds: 10),
            ),
          )
          ..pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 50),
              duration: Duration(seconds: 10),
            ),
          )
          ..pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.error,
              videoWidth: 1920,
              videoHeight: 1080,
              isFirstFrameRendered: true,
            ),
          );
        await Future<void>.delayed(Duration.zero);

        expect(errorCalled, isFalse);
        expect(loopFired, isFalse);
        expect(dimCalled, isFalse);
        expect(firstFrameCalled, isFalse);
      });
    });
  });
}
