import 'package:divine_video_player/divine_video_player.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/services/stale_playback_detector.dart';

import '../../helpers/fake_controller.dart';

StalePlaybackDetector _makeDetector({
  List<(int, int)>? seekEvents,
  List<int>? failoverEvents,
  List<String>? logs,
  bool watchesBuffering = false,
}) => StalePlaybackDetector(
  onSeekRecovery: (i, pos) => seekEvents?.add((i, pos)),
  onSourceFailover: (i) => failoverEvents?.add(i),
  log: (msg) => logs?.add(msg),
  watchesBuffering: watchesBuffering,
);

/// Advances time to trigger [ticks] heartbeat intervals.
void _tick(FakeAsync async, int ticks) =>
    async.elapse(StalePlaybackDetector.interval * ticks);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(StalePlaybackDetector, () {
    group('start with null controller', () {
      test('does nothing', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final det = _makeDetector(seekEvents: seeks)..start(0, null);
          _tick(async, 20);

          expect(seeks, isEmpty);
          det.disposeAll();
        });
      });
    });

    group('grace period', () {
      test('does not fire during grace period even if position stalls', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final controller = FakeController();
          final det = _makeDetector(seekEvents: seeks)..start(0, controller);

          // Push playing state with stalled position during grace.
          for (var i = 0; i < StalePlaybackDetector.graceAfterPlay; i++) {
            controller.pushState(
              const DivineVideoPlayerState(
                status: PlaybackStatus.playing,
                position: Duration(seconds: 1),
              ),
            );
            _tick(async, 1);
          }

          expect(seeks, isEmpty);
          det.disposeAll();
        });
      });
    });

    group('stale detection → seek recovery', () {
      test('fires onSeekRecovery after heartbeatThreshold frozen ticks', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final controller = FakeController();
          final det = _makeDetector(seekEvents: seeks)..start(0, controller);

          // Burn through grace period with advancing position.
          for (var i = 0; i < StalePlaybackDetector.graceAfterPlay + 1; i++) {
            controller.pushState(
              DivineVideoPlayerState(
                status: PlaybackStatus.playing,
                position: Duration(milliseconds: i * 100),
              ),
            );
            _tick(async, 1);
          }

          // Now stall at the same position.
          const stalePosMs = 500;
          for (var i = 0; i < StalePlaybackDetector.heartbeatThreshold; i++) {
            controller.pushState(
              const DivineVideoPlayerState(
                status: PlaybackStatus.playing,
                position: Duration(milliseconds: stalePosMs),
              ),
            );
            _tick(async, 1);
          }

          expect(seeks, isNotEmpty);
          expect(seeks.first.$1, equals(0));
          det.disposeAll();
        });
      });
    });

    group('stale detection → source failover', () {
      test(
        'fires onSourceFailover after maxRecoveryAttempts seek attempts',
        () {
          fakeAsync((async) {
            final seeks = <(int, int)>[];
            final failovers = <int>[];
            final controller = FakeController();
            final det = _makeDetector(
              seekEvents: seeks,
              failoverEvents: failovers,
            )..start(0, controller);

            // Helper: burn grace + trigger one stall cycle.
            void burnGraceAndStall({required int startMs}) {
              for (
                var i = 0;
                i < StalePlaybackDetector.graceAfterPlay + 1;
                i++
              ) {
                controller.pushState(
                  DivineVideoPlayerState(
                    status: PlaybackStatus.playing,
                    position: Duration(milliseconds: startMs + i),
                  ),
                );
                _tick(async, 1);
              }
              for (
                var i = 0;
                i < StalePlaybackDetector.heartbeatThreshold;
                i++
              ) {
                controller.pushState(
                  DivineVideoPlayerState(
                    status: PlaybackStatus.playing,
                    position: Duration(milliseconds: startMs),
                  ),
                );
                _tick(async, 1);
              }
            }

            // Exhaust all recovery attempts.
            for (
              var attempt = 0;
              attempt <= StalePlaybackDetector.maxRecoveryAttempts;
              attempt++
            ) {
              burnGraceAndStall(startMs: attempt * 10000);
            }

            expect(failovers, isNotEmpty);
            expect(failovers.first, equals(0));
            det.disposeAll();
          });
        },
      );
    });

    group('stop', () {
      test('cancels the timer', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final controller = FakeController();
          final det = _makeDetector(seekEvents: seeks)
            ..start(0, controller)
            ..stop();
          _tick(async, 20);

          expect(seeks, isEmpty);
          det.disposeAll();
        });
      });

      test('is safe to call when no timer is running', () {
        fakeAsync((async) {
          final det = _makeDetector();
          expect(det.stop, returnsNormally);
          det.disposeAll();
        });
      });
    });

    group('resetGrace', () {
      test('resets grace heartbeat counter', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final controller = FakeController();
          final det = _makeDetector(seekEvents: seeks)..start(0, controller);
          // Burn part of grace.
          controller.pushState(
            const DivineVideoPlayerState(
              status: PlaybackStatus.playing,
              position: Duration(milliseconds: 100),
            ),
          );
          _tick(async, 3);

          // Reset grace — counters go back to graceAfterPlay.
          det.resetGrace();

          // Stall immediately after reset → should NOT fire (still in grace).
          for (var i = 0; i < StalePlaybackDetector.heartbeatThreshold; i++) {
            controller.pushState(
              const DivineVideoPlayerState(
                status: PlaybackStatus.playing,
                position: Duration(milliseconds: 100),
              ),
            );
            _tick(async, 1);
          }

          expect(seeks, isEmpty);
          det.disposeAll();
        });
      });
    });

    group('forget', () {
      test('removes recovery counter for the index', () {
        final det = _makeDetector();
        // Accessing internal state indirectly: forget must not throw.
        expect(() => det.forget(0), returnsNormally);
        det.disposeAll();
      });
    });

    group('disposeAll', () {
      test('stops the timer and clears recovery counters', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final controller = FakeController();
          _makeDetector(seekEvents: seeks)
            ..start(0, controller)
            ..disposeAll();
          _tick(async, 20);

          expect(seeks, isEmpty);
        });
      });
    });

    group('non-playing state resets heartbeat', () {
      test('pauses polling and waits for a new stall after resume', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          const stalled = DivineVideoPlayerState(
            status: PlaybackStatus.playing,
            position: Duration(seconds: 1),
          );
          final controller = FakeController()..pushState(stalled);
          final det = _makeDetector(seekEvents: seeks)..start(0, controller);
          const threshold = StalePlaybackDetector.heartbeatThreshold;

          // Pause one heartbeat before recovery would have fired.
          _tick(async, StalePlaybackDetector.graceAfterPlay + threshold - 1);
          expect(seeks, isEmpty);
          controller.pushState(
            const DivineVideoPlayerState(status: PlaybackStatus.paused),
          );
          _tick(async, 1);
          expect(async.periodicTimerCount, 0);

          controller.pushState(stalled);
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 1);

          // The first tick observes the position and the next eight establish
          // a new stall. No heartbeat from before the pause counts here.
          _tick(async, threshold);
          expect(seeks, isEmpty);
          _tick(async, 1);
          expect(seeks, [(0, 1000)]);
          det.disposeAll();
        });
      });

      test('starts heartbeat timer immediately when already playing', () {
        fakeAsync((async) {
          final controller = FakeController()
            ..pushState(
              const DivineVideoPlayerState(
                status: PlaybackStatus.playing,
                position: Duration(milliseconds: 500),
              ),
            );
          final det = _makeDetector()..start(0, controller);

          expect(async.periodicTimerCount, equals(1));
          det.disposeAll();
        });
      });
    });

    group('heartbeat timer lifecycle', () {
      test('arms no timer and fires no recovery for an idle controller', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final controller = FakeController();
          final det = _makeDetector(seekEvents: seeks)..start(0, controller);

          expect(async.periodicTimerCount, equals(0));
          _tick(
            async,
            StalePlaybackDetector.graceAfterPlay +
                StalePlaybackDetector.heartbeatThreshold +
                2,
          );

          expect(seeks, isEmpty);
          det.disposeAll();
        });
      });

      test(
        'fires recovery when frozen playing updates arrive faster than '
        'the heartbeat',
        () {
          fakeAsync((async) {
            final seeks = <(int, int)>[];
            final controller = FakeController();
            final det = _makeDetector(seekEvents: seeks)..start(0, controller);
            // Android reports state every 200 ms, faster than the heartbeat,
            // so each update must not restart the periodic timer.
            const updateEvery = Duration(milliseconds: 200);
            const ticksNeeded =
                StalePlaybackDetector.graceAfterPlay +
                StalePlaybackDetector.heartbeatThreshold +
                1;
            final updates =
                (StalePlaybackDetector.interval * ticksNeeded).inMicroseconds ~/
                    updateEvery.inMicroseconds +
                1;

            for (var i = 0; i < updates; i++) {
              controller.pushState(
                const DivineVideoPlayerState(
                  status: PlaybackStatus.playing,
                  position: Duration(milliseconds: 500),
                ),
              );
              async.elapse(updateEvery);
            }

            expect(seeks, equals([(0, 500)]));
            det.disposeAll();
          });
        },
      );
    });

    group('watchesBuffering', () {
      const playing = DivineVideoPlayerState(
        status: PlaybackStatus.playing,
        position: Duration(seconds: 1),
      );
      const waiting = DivineVideoPlayerState(
        status: PlaybackStatus.buffering,
        position: Duration(seconds: 1),
      );
      const threshold = StalePlaybackDetector.heartbeatThreshold;

      test('recovers a wait for data after playback started', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final failovers = <int>[];
          final controller = FakeController()..pushState(playing);
          final det = _makeDetector(
            seekEvents: seeks,
            failoverEvents: failovers,
            watchesBuffering: true,
          )..start(0, controller);

          controller.pushState(waiting);
          _tick(async, StalePlaybackDetector.graceAfterPlay + threshold);
          expect(seeks, [(0, 1000)]);

          // Two seeks later the wait still holds: try the next source.
          _tick(async, 2 * (StalePlaybackDetector.graceAfterPlay + threshold));
          expect(seeks, hasLength(StalePlaybackDetector.maxRecoveryAttempts));
          expect(failovers, [0]);
          det.disposeAll();
        });
      });

      test('leaves buffering before playback started alone', () {
        fakeAsync((async) {
          final seeks = <(int, int)>[];
          final controller = FakeController()..pushState(waiting);
          final det = _makeDetector(seekEvents: seeks, watchesBuffering: true)
            ..start(0, controller);

          _tick(async, StalePlaybackDetector.graceAfterPlay + threshold + 2);
          expect(async.periodicTimerCount, 0);
          expect(seeks, isEmpty);
          det.disposeAll();
        });
      });

      test('treats the next source as not yet played after resetGrace', () {
        fakeAsync((async) {
          final controller = FakeController()..pushState(playing);
          final det = _makeDetector(watchesBuffering: true)
            ..start(0, controller);
          controller.pushState(waiting);
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 1);

          det.resetGrace();
          controller.pushState(waiting);
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 0);
          det.disposeAll();
        });
      });

      test('is off by default, so buffering pauses the heartbeat', () {
        fakeAsync((async) {
          final controller = FakeController()..pushState(playing);
          final det = _makeDetector()..start(0, controller);
          expect(async.periodicTimerCount, 1);

          controller.pushState(waiting);
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 0);
          det.disposeAll();
        });
      });
    });
  });
}
