import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide AudioTrack;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MediaKitLinuxVideoPlayerBackend.resetInitializationForTesting);
  tearDown(MediaKitLinuxVideoPlayerBackend.resetInitializationForTesting);

  group('public firstFrameRendered', () {
    for (final transition in ['stop', 'replacement']) {
      testWidgets('keeps a fresh poster during $transition retirement', (
        tester,
      ) async {
        final players = <_FakePlatformPlayer>[];
        final outputs = <_FakeVideoController>[];
        MediaKitLinuxVideoPlayerBackend createBackend() =>
            MediaKitLinuxVideoPlayerBackend(
              mediaKitInitializer: _noop,
              playerFactory: () {
                final player = _FakePlatformPlayer();
                players.add(player);
                return Player(platformPlayer: player);
              },
              videoControllerFactory: (_) {
                final output = _FakeVideoController();
                outputs.add(output);
                return output;
              },
              videoControllerReady: (output) =>
                  (output as _FakeVideoController).ready.future,
              videoViewBuilder: (_) => const SizedBox.expand(),
            );
        final savedFactory = DivineVideoPlayerController.linuxBackendFactory;
        final savedForced = DivineVideoPlayerController.debugForceLinuxBackend;
        DivineVideoPlayerController.debugForceLinuxBackend = true;
        DivineVideoPlayerController.linuxBackendFactory = createBackend;
        late DivineVideoPlayerController controller;
        late Completer<void> disposal;
        Future<void>? replacing;
        try {
          await tester.runAsync(() async {
            controller = DivineVideoPlayerController();
            disposal = Completer<void>();
            await controller.initialize();
            await controller.setSource(
              const VideoClip(
                uri: 'file:///first.mp4',
                end: Duration(seconds: 1),
              ),
            );
            outputs.single.ready.complete();
            final rendered = controller.firstFrameRendered;
            expect(await rendered, isTrue);
            if (transition == 'replacement') {
              players.first.disposalGate = disposal;
              replacing = controller.setSource(
                const VideoClip(
                  uri: 'file:///second.mp4',
                  end: Duration(seconds: 1),
                ),
              );
              await players.first.disposalStarted.future;
            } else {
              await controller.stop();
            }
            // Existing holders retain the result for the frame they observed.
            expect(await rendered, isTrue);
            expect(controller.state.isFirstFrameRendered, isFalse);
            expect(controller.state.clipCount, 0);
            var freshSuccess = false;
            unawaited(
              controller.firstFrameRendered.then(
                (value) => freshSuccess = value,
              ),
            );
            await pumpEventQueue();
            expect(freshSuccess, isFalse);
          });
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: DivineVideoPlayer(
                  controller: controller,
                  placeholder: const Text('Replacement poster'),
                ),
              ),
            ),
          );
          await tester.runAsync(pumpEventQueue);
          await tester.pumpAndSettle();
          expect(find.text('Replacement poster'), findsOneWidget);
          await tester.runAsync(() async {
            disposal.complete();
            if (replacing != null) {
              await replacing;
            } else {
              await controller.setSource(
                const VideoClip(
                  uri: 'file:///second.mp4',
                  end: Duration(seconds: 1),
                ),
              );
            }
          });
          await tester.pumpAndSettle();
          expect(find.text('Replacement poster'), findsOneWidget);
          await tester.runAsync(() async {
            outputs.last.ready.complete();
            expect(await controller.firstFrameRendered, isTrue);
            await pumpEventQueue();
          });
          await tester.pumpAndSettle();
          expect(find.text('Replacement poster'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(() async {
            if (!disposal.isCompleted) disposal.complete();
            await replacing;
            await controller.dispose();
          });
          DivineVideoPlayerController.linuxBackendFactory = savedFactory;
          DivineVideoPlayerController.debugForceLinuxBackend = savedForced;
        }
      });
    }

    test('preserves failure during replacement volume restoration', () async {
      final players = <_FakePlatformPlayer>[];
      final outputs = <_FakeVideoController>[];
      final gate = Completer<void>();
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () {
          final player = _FakePlatformPlayer();
          if (players.isNotEmpty) player.volumeReady = gate.future;
          players.add(player);
          return Player(platformPlayer: player);
        },
        videoControllerFactory: (_) {
          final output = _FakeVideoController();
          outputs.add(output);
          return output;
        },
        videoControllerReady: (output) =>
            (output as _FakeVideoController).ready.future,
      );
      await _withDesktopController(backend, (controller) async {
        await controller.setSource(
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 1)),
        );
        final replacing = controller.setSource(
          const VideoClip(uri: 'file:///second.mp4', end: Duration(seconds: 2)),
        );
        await pumpEventQueue();
        try {
          expect(players, hasLength(2));
          outputs.last.ready.completeError(StateError('Replacement failed'));
          await pumpEventQueue();
          final failed = controller.firstFrameRendered;
          expect(await failed, isFalse);
          gate.complete();
          await replacing;

          expect(controller.state.status, PlaybackStatus.error);
          expect(controller.firstFrameRendered, same(failed));
          expect(await controller.firstFrameRendered, isFalse);
        } finally {
          if (!gate.isCompleted) gate.complete();
          await replacing;
        }
      });
    });

    test('preserves the active wait until replacement acceptance', () async {
      final players = <_FakePlatformPlayer>[];
      final outputs = <_FakeVideoController>[];
      final probe = Completer<Duration>();
      final probing = Completer<void>();
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () {
          final player = _FakePlatformPlayer();
          players.add(player);
          return Player(platformPlayer: player);
        },
        videoControllerFactory: (_) {
          final output = _FakeVideoController();
          outputs.add(output);
          return output;
        },
        videoControllerReady: (output) =>
            (output as _FakeVideoController).ready.future,
        durationProbe: (_) {
          probing.complete();
          return probe.future;
        },
      );
      await _withDesktopController(backend, (controller) async {
        await controller.setSource(
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 2)),
        );
        outputs.single.ready.complete();
        await pumpEventQueue();
        final first = controller.firstFrameRendered;
        expect(await first, isTrue);
        final replacing = controller.setSource(
          const VideoClip(uri: 'file:///second.mp4'),
        );
        await probing.future;
        try {
          expect(controller.firstFrameRendered, same(first));
          players.first.emitState(
            players.first.state.copyWith(
              position: const Duration(milliseconds: 20),
            ),
          );
          await pumpEventQueue();
        } finally {
          probe.complete(const Duration(seconds: 3));
          await replacing;
        }
        final second = controller.firstFrameRendered;
        var completed = false;
        unawaited(second.then((_) => completed = true));
        await pumpEventQueue();

        expect(second, isNot(same(first)));
        expect(completed, isFalse);
        expect(controller.state.isFirstFrameRendered, isFalse);
        outputs.last.ready.complete();
        expect(await second, isTrue);
      });
    });

    test('cancels an unrendered output when it is retired', () async {
      final outputs = <_FakeVideoController>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
        videoControllerFactory: (_) {
          final output = _FakeVideoController();
          outputs.add(output);
          return output;
        },
        videoControllerReady: (output) =>
            (output as _FakeVideoController).ready.future,
      );
      await _withDesktopController(backend, (controller) async {
        await controller.setSource(
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 2)),
        );
        final first = controller.firstFrameRendered;
        bool? result;
        unawaited(first.then((value) => result = value));
        await controller.setSource(
          const VideoClip(uri: 'file:///second.mp4', end: Duration(seconds: 3)),
        );
        await pumpEventQueue();

        expect(result, isFalse);
        expect(controller.firstFrameRendered, isNot(same(first)));
        outputs.first.ready.complete();
        await pumpEventQueue();
        expect(controller.state.isFirstFrameRendered, isFalse);
        outputs.last.ready.complete();
        expect(await controller.firstFrameRendered, isTrue);
      });
    });

    test('keeps the active wait when replacement validation rejects', () async {
      final output = _FakeVideoController();
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
        videoControllerFactory: (_) => output,
        videoControllerReady: (_) => output.ready.future,
        durationProbe: (_) =>
            Future<Duration>.error(StateError('Invalid replacement')),
      );
      await _withDesktopController(backend, (controller) async {
        await controller.setSource(
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 2)),
        );
        output.ready.complete();
        await pumpEventQueue();
        final first = controller.firstFrameRendered;
        expect(await first, isTrue);

        await expectLater(
          controller.setSource(const VideoClip(uri: 'file:///missing.mp4')),
          throwsStateError,
        );

        expect(controller.firstFrameRendered, same(first));
        expect(await controller.firstFrameRendered, isTrue);
      });
    });

    for (final action in ['stop', 'dispose']) {
      test('settles an unrendered wait on $action', () async {
        final output = _FakeVideoController();
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) => output,
          videoControllerReady: (_) => output.ready.future,
        );
        await _withDesktopController(backend, (controller) async {
          await controller.setSource(
            const VideoClip(
              uri: 'file:///first.mp4',
              end: Duration(seconds: 2),
            ),
          );
          bool? result;
          unawaited(
            controller.firstFrameRendered.then((value) => result = value),
          );
          if (action == 'stop') {
            await controller.stop();
          } else {
            await controller.dispose();
          }
          output.ready.complete();
          await pumpEventQueue();

          expect(result, isFalse);
        });
      });
    }
  });

  group(MediaKitLinuxVideoPlayerBackend, () {
    test('publishes output readiness after observed source recovery', () async {
      final player = _FakePlatformPlayer();
      final output = _FakeVideoController();
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: player),
        videoControllerFactory: (_) => output,
        videoControllerReady: (_) => output.ready.future,
      );
      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
      addTearDown(backend.dispose);
      await backend.setClips([
        const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 2)),
      ]);
      bool? rendered;
      unawaited(backend.firstFrameRendered.then((value) => rendered = value));
      player.emitPlaybackError('Source interruption');
      await pumpEventQueue();
      output.ready.complete();
      await pumpEventQueue();
      expect(rendered, isNull);
      player.emitState(
        player.state.copyWith(playing: true, position: 1.seconds),
      );
      await pumpEventQueue();

      expect(rendered, isTrue);
    });

    test('preserves renderer failure when native pause rejects', () async {
      final player = _FakePlatformPlayer()
        ..pauseError = StateError('Pause lost');
      final output = _FakeVideoController();
      final errors = <Object>[];
      final states = <DivineVideoPlayerState>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: player),
        videoControllerFactory: (_) => output,
        videoControllerReady: (_) => output.ready.future,
      );
      await backend.initialize(onStateChanged: states.add, onError: errors.add);
      addTearDown(backend.dispose);
      await backend.setClips([
        const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 2)),
      ]);
      output.ready.completeError(StateError('Renderer failed'));
      await pumpEventQueue();
      await backend.play();

      expect(player.pauseCalls, 1);
      expect(player.playCalls, 0);
      expect(states.last.status, PlaybackStatus.error);
      expect(errors.single.toString(), contains('Renderer failed'));
    });

    test('recovers source errors when the native playlist advances', () async {
      final player = _FakePlatformPlayer();
      final states = <DivineVideoPlayerState>[];
      final errors = <Object>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: player),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (_) => Completer<void>().future,
      );
      await backend.initialize(onStateChanged: states.add, onError: errors.add);
      addTearDown(backend.dispose);
      await backend.setClips([
        const VideoClip(uri: 'file:///missing.mp4', end: Duration(seconds: 2)),
        const VideoClip(uri: 'file:///valid.mp4', end: Duration(seconds: 3)),
      ]);
      player.emitPlaybackError('First item could not open');
      await pumpEventQueue();
      expect(states.last.status, PlaybackStatus.error);
      player.emitState(player.state.copyWith(position: 1.seconds));
      await pumpEventQueue();
      expect(states.last.status, PlaybackStatus.error);

      player.emitPlaylistIndex(1);
      player.emitState(
        player.state.copyWith(position: Duration.zero, buffering: true),
      );
      await pumpEventQueue();
      player.emitPlaybackError('Delayed diagnostic from first item');
      await pumpEventQueue();
      expect(states.last.status, PlaybackStatus.error);
      player.emitState(
        player.state.copyWith(
          playing: true,
          buffering: false,
          position: 1.seconds,
        ),
      );
      await pumpEventQueue();

      expect(states.last.status, PlaybackStatus.playing);
      expect(states.last.currentClipIndex, 1);
      expect(states.last.position, 3.seconds);
      expect(states.last.errorMessage, isNull);
      expect(errors, [
        'First item could not open',
        'Delayed diagnostic from first item',
      ]);
    });

    test('quiesces renderer failure and blocks queued play', () async {
      final player = _FakePlatformPlayer();
      final output = _FakeVideoController();
      final states = <DivineVideoPlayerState>[];
      final errors = <Object>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: player),
        videoControllerFactory: (_) => output,
        videoControllerReady: (_) => output.ready.future,
      );
      await backend.initialize(onStateChanged: states.add, onError: errors.add);
      addTearDown(backend.dispose);
      await backend.setClips([
        const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 2)),
        const VideoClip(uri: 'file:///two.mp4', end: Duration(seconds: 3)),
      ]);
      await backend.play();
      expect(player.state.playing, isTrue);
      final firstFrame = backend.firstFrameRendered;
      final gate = Completer<void>();
      player.volumeReady = gate.future;
      final volume = backend.setVolume(0.5);
      final queuedPlay = backend.play();
      output.ready.completeError(StateError('Renderer failed'));
      await pumpEventQueue();
      gate.complete();
      await Future.wait<void>([volume, queuedPlay]);
      await pumpEventQueue();

      expect(player.state.playing, isFalse);
      expect(player.playCalls, 1);
      expect(player.pauseCalls, 1);
      expect(await firstFrame, isFalse);
      player.emitPlaylistIndex(1);
      await pumpEventQueue();
      await backend.play();
      expect(player.state.playing, isFalse);
      expect(player.playCalls, 1);
      expect(states.last.status, PlaybackStatus.error);
      expect(errors.single.toString(), contains('Renderer failed'));
    });

    test('does not quiesce a replacement after the old output fails', () async {
      final players = <_FakePlatformPlayer>[];
      final outputs = <_FakeVideoController>[];
      final states = <DivineVideoPlayerState>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () {
          final player = _FakePlatformPlayer();
          players.add(player);
          return Player(platformPlayer: player);
        },
        videoControllerFactory: (_) {
          final output = _FakeVideoController();
          outputs.add(output);
          return output;
        },
        videoControllerReady: (output) =>
            (output as _FakeVideoController).ready.future,
      );
      await backend.initialize(onStateChanged: states.add, onError: (_) {});
      addTearDown(backend.dispose);
      await backend.setClips([
        const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 2)),
      ]);
      await backend.play();
      final gate = Completer<void>();
      players.first.volumeReady = gate.future;
      final volume = backend.setVolume(0.5);
      final replacing = backend.setClips([
        const VideoClip(uri: 'file:///two.mp4', end: Duration(seconds: 3)),
      ]);
      await pumpEventQueue();
      final playing = backend.play();
      outputs.first.ready.completeError(StateError('Retiring output failed'));
      await pumpEventQueue();
      gate.complete();
      await Future.wait<void>([volume, replacing, playing]);

      expect(players, hasLength(2));
      expect(players.last.pauseCalls, 0);
      expect(players.last.state.playing, isTrue);
      expect(states.last.status, PlaybackStatus.playing);
    });

    test('reports renderer failure after a source error', () async {
      final player = _FakePlatformPlayer();
      final output = _FakeVideoController();
      final errors = <Object>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: player),
        videoControllerFactory: (_) => output,
        videoControllerReady: (_) => output.ready.future,
      );
      await backend.initialize(onStateChanged: (_) {}, onError: errors.add);
      addTearDown(backend.dispose);
      await backend.setClips([
        const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 2)),
      ]);
      player.emitPlaybackError('Source failed');
      await pumpEventQueue();
      output.ready.completeError(StateError('Renderer failed'));
      await pumpEventQueue();

      expect(errors.map((error) => '$error'), [
        'Source failed',
        'Bad state: Renderer failed',
      ]);
    });

    test(
      'keeps a validated replacement when a newer request rejects '
      'during retirement',
      () async {
        final players = <_FakePlatformPlayer>[];
        final outputs = <_FakeVideoController>[];
        final states = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () {
            final player = _FakePlatformPlayer();
            players.add(player);
            return Player(platformPlayer: player);
          },
          videoControllerFactory: (_) {
            final output = _FakeVideoController();
            outputs.add(output);
            return output;
          },
          videoControllerReady: (output) =>
              (output as _FakeVideoController).ready.future,
          durationProbe: (_) =>
              Future<Duration>.error(StateError('Replacement unreadable')),
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        addTearDown(backend.dispose);
        await backend.setClips([
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 2)),
        ]);
        outputs.single.ready.complete();
        await backend.play();
        final gate = Completer<void>();
        players.first.disposalGate = gate;
        final replacing = backend.setClips([
          const VideoClip(uri: 'file:///second.mp4', end: Duration(seconds: 3)),
        ]);
        await players.first.disposalStarted.future;
        final retiringState = states.last;
        await expectLater(
          backend.setClips([const VideoClip(uri: 'file:///missing.mp4')]),
          throwsStateError,
        );
        gate.complete();
        await replacing;

        expect(
          players.last.lastOpenedPlaylist?.medias.single.uri,
          endsWith('/second.mp4'),
        );
        expect(states.last.duration, const Duration(seconds: 3));
        expect(states.last.status, PlaybackStatus.ready);
        expect(errors, isEmpty);
        expect(retiringState.status, PlaybackStatus.buffering);
        expect(retiringState.clipCount, 0);
        expect(retiringState.duration, Duration.zero);
        outputs.last.ready.complete();
        await pumpEventQueue();
        expect(states.last.isFirstFrameRendered, isTrue);
      },
    );

    test(
      'does not acquire another native player after disposal starts '
      'during retirement',
      () async {
        final players = <_FakePlatformPlayer>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () {
            final player = _FakePlatformPlayer();
            players.add(player);
            return Player(platformPlayer: player);
          },
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (output) =>
              (output as _FakeVideoController).ready.future,
        );
        await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
        await backend.setClips([
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 2)),
        ]);
        final gate = Completer<void>();
        players.first.disposalGate = gate;
        final replacing = backend.setClips([
          const VideoClip(uri: 'file:///second.mp4', end: Duration(seconds: 3)),
        ]);
        await players.first.disposalStarted.future;
        final closing = backend.dispose();
        gate.complete();
        await replacing;
        await closing;

        expect(players, hasLength(1));
        expect(players.single.disposeCalls, 1);
      },
    );

    test(
      'retains a current-source failure if replacement validation also fails',
      () async {
        final player = _FakePlatformPlayer();
        final output = _FakeVideoController();
        final probe = Completer<Duration>();
        final probing = Completer<void>();
        final states = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: player),
          videoControllerFactory: (_) => output,
          videoControllerReady: (_) => output.ready.future,
          durationProbe: (_) {
            probing.complete();
            return probe.future;
          },
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        addTearDown(backend.dispose);
        await backend.setClips([
          const VideoClip(
            uri: 'file:///current.mp4',
            end: Duration(seconds: 4),
          ),
        ]);
        output.ready.complete();
        await backend.play();
        final replacement = backend.setClips([
          const VideoClip(uri: 'file:///replacement.mp4'),
        ]);
        final rejected = expectLater(replacement, throwsStateError);
        await probing.future;
        player.emitPlaybackError('Current source became unreadable');
        await pumpEventQueue();
        expect(
          errors.single.toString(),
          contains('Current source became unreadable'),
        );
        probe.completeError(StateError('Replacement unavailable'));
        await rejected;

        expect(states.last.status, PlaybackStatus.error);
        expect(
          errors.single.toString(),
          contains('Current source became unreadable'),
        );
      },
    );

    test(
      'restores an active source after replacement validation fails',
      () async {
        final player = _FakePlatformPlayer();
        final output = _FakeVideoController();
        final states = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        var created = false;
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () {
            if (created) {
              return Player(
                platformPlayer: _FakePlatformPlayer(
                  probeError: 'Missing replacement',
                ),
              );
            }
            created = true;
            return Player(platformPlayer: player);
          },
          videoControllerFactory: (_) => output,
          videoControllerReady: (_) => output.ready.future,
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        addTearDown(backend.dispose);
        await backend.setClips([
          const VideoClip(
            uri: 'file:///current.mp4',
            end: Duration(seconds: 4),
          ),
        ]);
        output.ready.complete();
        await backend.play();
        await pumpEventQueue();
        expect(states.last.isFirstFrameRendered, isTrue);
        await expectLater(
          backend.setClips([const VideoClip(uri: 'file:///missing.mp4')]),
          throwsStateError,
        );

        expect(states.last.isFirstFrameRendered, isTrue);
        expect(states.last.status, PlaybackStatus.playing);
        player.emitPlaybackError('Current source read failure');
        await pumpEventQueue();
        expect(
          errors.single.toString(),
          contains('Current source read failure'),
        );
        expect(states.last.status, PlaybackStatus.error);
      },
    );

    test(
      'recreates a failed initial output after stop and renders its retry',
      () async {
        final outputs = <_FakeVideoController>[];
        final states = <DivineVideoPlayerState>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) {
            final output = _FakeVideoController();
            outputs.add(output);
            return output;
          },
          videoControllerReady: (output) =>
              (output as _FakeVideoController).ready.future,
        );
        await backend.initialize(onStateChanged: states.add, onError: (_) {});
        addTearDown(backend.dispose);
        outputs.single.ready.completeError(StateError('Initial output failed'));
        await pumpEventQueue();
        expect(states.last.status, PlaybackStatus.error);
        await backend.stop();
        await backend.setClips([
          const VideoClip(uri: 'file:///retry.mp4', end: Duration(seconds: 4)),
        ]);

        expect(outputs, hasLength(2));
        outputs.last.ready.complete();
        await pumpEventQueue();
        expect(states.last.isFirstFrameRendered, isTrue);
        expect(states.last.status, PlaybackStatus.ready);
      },
    );

    test(
      'keeps video progress when the audio output device is unavailable',
      () async {
        final player = _FakePlatformPlayer();
        final states = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: player),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        addTearDown(backend.dispose);
        await backend.setClips([
          const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 4)),
        ]);
        player.emitPlaybackError(
          'Could not open/initialize audio device -> no sound.',
        );
        player.emitState(
          player.state.copyWith(
            playing: true,
            position: 2.seconds,
            width: 128,
            height: 240,
          ),
        );
        await pumpEventQueue();

        expect(states.last.status, PlaybackStatus.playing);
        expect(states.last.position, 2.seconds);
        expect(errors, isEmpty);
      },
    );

    test(
      'does not fail a newer source when a cancelled probe fails late',
      () async {
        final probe = Completer<Duration>();
        final probing = Completer<void>();
        final states = <DivineVideoPlayerState>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          durationProbe: (_) {
            probing.complete();
            return probe.future;
          },
        );
        await backend.initialize(onStateChanged: states.add, onError: (_) {});
        addTearDown(backend.dispose);
        final oldLoad = backend.setClips([
          const VideoClip(uri: 'file:///old.mp4'),
        ]);
        await probing.future;
        await backend.setClips([
          const VideoClip(uri: 'file:///new.mp4', end: Duration(seconds: 4)),
        ]);
        probe.completeError(StateError('Retired duration lookup failed'));

        await oldLoad;

        expect(states.last.status, PlaybackStatus.ready);
        expect(states.last.errorMessage, isNull);
      },
    );

    test(
      'keeps an acknowledged mute before the SDK observes its volume',
      () async {
        final players = <_FakePlatformPlayer>[];
        final states = <DivineVideoPlayerState>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () {
            final player = _FakePlatformPlayer()..deferVolumeObservation = true;
            players.add(player);
            return Player(platformPlayer: player);
          },
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
        );
        await backend.initialize(onStateChanged: states.add, onError: (_) {});
        addTearDown(backend.dispose);
        await backend.setClips([
          const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 4)),
        ]);
        await backend.setVolume(0);
        expect(players.first.state.volume, 100);
        expect(players.first.lastVolume, 0);

        await backend.setClips([
          const VideoClip(uri: 'file:///two.mp4', end: Duration(seconds: 4)),
        ]);

        expect(players.last.lastVolume, 0);
        expect(states.last.volume, 0);
        await backend.stop();
        expect(states.last.volume, 0);
        await backend.setClips([
          const VideoClip(uri: 'file:///three.mp4', end: Duration(seconds: 4)),
        ]);
        expect(players.last.lastVolume, 0);
        expect(states.last.volume, 0);
      },
    );

    test(
      'does not let current-source errors mask replacement output errors',
      () async {
        final players = <_FakePlatformPlayer>[];
        final outputs = <_FakeVideoController>[];
        final states = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        final probe = Completer<Duration>();
        final probing = Completer<void>();
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () {
            final player = _FakePlatformPlayer();
            players.add(player);
            return Player(platformPlayer: player);
          },
          videoControllerFactory: (_) {
            final output = _FakeVideoController();
            outputs.add(output);
            return output;
          },
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          durationProbe: (_) {
            probing.complete();
            return probe.future;
          },
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        addTearDown(backend.dispose);
        await backend.setClips([
          const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 4)),
        ]);
        final replacement = backend.setClips([
          const VideoClip(uri: 'file:///two.mp4'),
        ]);
        await probing.future;
        players.first.emitPlaybackError('Active source decoder failure');
        await pumpEventQueue();
        expect(errors, ['Active source decoder failure']);
        probe.complete(4.seconds);
        await replacement;
        expect(states.last.errorMessage, isNull);
        final outputError = StateError('Replacement renderer failed');
        outputs.last.ready.completeError(outputError);
        await pumpEventQueue();

        expect(states.last.status, PlaybackStatus.error);
        expect(
          states.last.errorMessage,
          contains('Replacement renderer failed'),
        );
        expect(errors, ['Active source decoder failure', same(outputError)]);
      },
    );

    test('an older stop cannot unload a newer source', () async {
      final players = <_FakePlatformPlayer>[];
      final states = <DivineVideoPlayerState>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () {
          final player = _FakePlatformPlayer();
          players.add(player);
          return Player(platformPlayer: player);
        },
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
      );
      await backend.initialize(onStateChanged: states.add, onError: (_) {});
      final oldLoad = backend.setClips([
        const VideoClip(uri: 'file:///old.mp4'),
      ]);
      await pumpEventQueue();
      final probe = players[1];
      final gate = Completer<void>();
      probe.disposalGate = gate;
      final stopping = backend.stop();
      await probe.disposalStarted.future;
      final newLoad = backend.setClips([
        const VideoClip(uri: 'file:///new.mp4', end: Duration(seconds: 4)),
      ]);
      await pumpEventQueue();

      gate.complete();
      await Future.wait([oldLoad, stopping, newLoad]);

      expect(states.last.clipCount, 1);
      expect(
        players.first.lastOpenedPlaylist?.medias.single.uri,
        endsWith('/new.mp4'),
      );
      await backend.dispose();
    });

    test('disposal waits for a probe already being retired by stop', () async {
      final players = <_FakePlatformPlayer>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () {
          final player = _FakePlatformPlayer();
          players.add(player);
          return Player(platformPlayer: player);
        },
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
      );
      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
      final loading = backend.setClips([
        const VideoClip(uri: 'file:///old.mp4'),
      ]);
      await pumpEventQueue();
      final probe = players[1];
      final gate = Completer<void>();
      probe.disposalGate = gate;
      final stopping = backend.stop();
      await probe.disposalStarted.future;
      var disposed = false;
      final closing = backend.dispose().then<void>((_) => disposed = true);
      await pumpEventQueue();
      try {
        expect(disposed, isFalse);
      } finally {
        gate.complete();
        await Future.wait([loading, stopping, closing]);
      }
      expect(probe.disposeCalls, 1);
    });

    test('reports native source errors before the probe timeout', () async {
      final players = <_FakePlatformPlayer>[
        _FakePlatformPlayer(),
        _FakePlatformPlayer(probeError: 'Synthetic decoder failure'),
      ];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: players.removeAt(0)),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
      );
      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
      addTearDown(backend.dispose);

      await expectLater(
        backend
            .setClips([const VideoClip(uri: 'file:///bad.mp4')])
            .timeout(1.seconds),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Synthetic decoder failure'),
          ),
        ),
      );
    });

    testWidgets(
      'schedules native initialization when replacing on an idle binding',
      (tester) async {
        late final MediaKitLinuxVideoPlayerBackend backend;
        await tester.runAsync(() async {
          backend = MediaKitLinuxVideoPlayerBackend(
            mediaKitInitializer: _noop,
            playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
            videoControllerFactory: (player) {
              final output = _FakeVideoController();
              (player.platform! as _FakePlatformPlayer).volumeReady =
                  output.ready.future;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => output.ready.complete(),
              );
              return output;
            },
            videoControllerReady: (controller) =>
                (controller as _FakeVideoController).ready.future,
          );
        });
        await tester.runAsync(
          () => backend.initialize(onStateChanged: (_) {}, onError: (_) {}),
        );
        await tester.pump();
        await tester.runAsync(() async {
          await backend.setClips([
            const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 4)),
          ]);
          await backend.stop();
        });
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        late Future<void> replacing;
        var replaced = false;
        await tester.runAsync(() async {
          replacing = backend
              .setClips([
                const VideoClip(
                  uri: 'file:///two.mp4',
                  end: Duration(seconds: 4),
                ),
              ])
              .then<void>((_) => replaced = true);
          await pumpEventQueue();
        });
        try {
          expect(replaced, isFalse);
          expect(tester.binding.hasScheduledFrame, isTrue);
        } finally {
          tester.binding.scheduleFrame();
          await tester.pump();
          await tester.runAsync(() => replacing);
          await tester.runAsync(backend.dispose);
        }
        expect(replaced, isTrue);
      },
    );

    test(
      'does not probe another clip after disposal during resolution',
      () async {
        final first = Completer<Duration>();
        final entered = Completer<void>();
        final probed = <String>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          durationProbe: (uri) {
            probed.add(uri);
            if (!entered.isCompleted) entered.complete();
            return probed.length == 1 ? first.future : Future.value(4.seconds);
          },
        );
        await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
        final loading = backend.setClips([
          const VideoClip(uri: 'file:///one.mp4'),
          const VideoClip(uri: 'file:///two.mp4'),
        ]);
        await entered.future;

        await backend.dispose();
        first.complete(3.seconds);
        await loading;

        expect(probed, ['file:///one.mp4']);
      },
    );

    test('releases an active native duration probe on disposal', () async {
      final players = <_FakePlatformPlayer>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () {
          final player = _FakePlatformPlayer();
          players.add(player);
          return Player(platformPlayer: player);
        },
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
      );
      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
      final loading = backend.setClips([
        const VideoClip(uri: 'file:///one.mp4'),
      ]);
      await pumpEventQueue();
      final probe = players[1];
      expect(probe.lastOpenedMedia?.uri, endsWith('/one.mp4'));

      await backend.dispose();
      try {
        expect(probe.disposeCalls, 1);
      } finally {
        if (probe.disposeCalls == 0) {
          probe.emitState(const PlayerState(duration: Duration(seconds: 4)));
        }
        await loading;
      }
      expect(probe.disposeCalls, 1);
    });

    test('uses a duration delivered before native open completes', () async {
      final mainPlayer = _FakePlatformPlayer();
      final probe = _FakePlatformPlayer(
        probeDuration: 6.seconds,
        durationDuringOpen: true,
      );
      var creations = 0;
      final states = <DivineVideoPlayerState>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () =>
            Player(platformPlayer: creations++ == 0 ? mainPlayer : probe),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
      );
      await backend.initialize(onStateChanged: states.add, onError: (_) {});
      addTearDown(backend.dispose);

      await backend.setClips([const VideoClip(uri: 'file:///one.mp4')]);

      expect(states.last.duration, 6.seconds);
      expect(probe.disposeCalls, 1);
    });

    test(
      'releases a retired player once when replacement creation fails',
      () async {
        final player = _FakePlatformPlayer();
        var creations = 0;
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () {
            if (creations++ > 0) throw StateError('Synthetic creation failure');
            return Player(platformPlayer: player);
          },
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );
        await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
        await backend.setClips([
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 4)),
        ]);
        await expectLater(
          backend.setClips([
            const VideoClip(
              uri: 'file:///second.mp4',
              end: Duration(seconds: 6),
            ),
          ]),
          throwsStateError,
        );

        await backend.dispose();

        expect(player.disposeCalls, 1);
      },
    );

    test(
      'ignores retired frame signals and resets readiness for each source',
      () async {
        final outputs = <_FakeVideoController>[];
        final states = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) {
            final output = _FakeVideoController();
            outputs.add(output);
            return output;
          },
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        await backend.setClips([
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 4)),
        ]);
        await backend.setClips([
          const VideoClip(uri: 'file:///second.mp4', end: Duration(seconds: 6)),
        ]);
        outputs.first.ready.complete();
        await pumpEventQueue();
        expect(states.last.isFirstFrameRendered, isFalse);
        outputs[1].ready.complete();
        await pumpEventQueue();
        expect(states.last.isFirstFrameRendered, isTrue);

        await backend.setClips([
          const VideoClip(uri: 'file:///third.mp4', end: Duration(seconds: 8)),
        ]);
        expect(states.last.isFirstFrameRendered, isFalse);
        await backend.dispose();
        outputs.last.ready.completeError(StateError('Retired output'));
        await pumpEventQueue();
        expect(errors, isEmpty);
      },
    );

    test(
      'reports renderer failure and retries with a fresh native player',
      () async {
        final outputs = <_FakeVideoController>[];
        final errors = <Object>[];
        final states = <DivineVideoPlayerState>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) {
            final output = _FakeVideoController();
            outputs.add(output);
            return output;
          },
          videoControllerReady: (controller) => outputs.length < 3
              ? Future<void>.error(StateError('Synthetic output failure'))
              : (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        await pumpEventQueue();
        expect(errors, hasLength(1));
        await backend.setClips([
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 4)),
        ]);
        expect(errors, hasLength(2));
        expect(states.last.status, PlaybackStatus.error);

        await backend.setVolume(0.3);
        await pumpEventQueue();
        expect(states.last.status, PlaybackStatus.error);
        expect(states.last.errorMessage, contains('Synthetic output failure'));

        await backend.setClips([
          const VideoClip(uri: 'file:///retry.mp4', end: Duration(seconds: 6)),
        ]);
        outputs.last.ready.complete();
        await pumpEventQueue();
        expect(states.last.isFirstFrameRendered, isTrue);
        expect(states.last.errorMessage, isNull);
        await backend.dispose();
      },
    );

    test(
      'keeps queued controls usable after a failed volume command',
      () async {
        final player = _FakePlatformPlayer();
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: player),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );
        await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
        player.volumeError = StateError('Synthetic volume failure');
        await expectLater(backend.setVolume(0.2), throwsStateError);
        player.volumeError = null;
        await backend.setVolume(0.3);

        expect(player.lastVolume, 30);
        await backend.dispose();
      },
    );

    test(
      'reports asynchronous authored-speed failures through the error port',
      () async {
        final player = _FakePlatformPlayer();
        final errors = <Object>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: player),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );
        await backend.initialize(onStateChanged: (_) {}, onError: errors.add);
        await backend.setClips([
          const VideoClip(
            uri: 'file:///fast.mp4',
            end: Duration(seconds: 6),
            playbackSpeed: 2,
          ),
          const VideoClip(
            uri: 'file:///next-fast.mp4',
            end: Duration(seconds: 6),
            playbackSpeed: 2,
          ),
        ]);
        await pumpEventQueue();
        final error = StateError('Synthetic rate failure');
        player
          ..rateError = error
          ..emitPlaylistIndex(1);
        await pumpEventQueue();

        expect(errors, [error]);
        await backend.dispose();
      },
    );

    test('a newer source wins while the previous player is retiring', () async {
      final players = <_FakePlatformPlayer>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () {
          final player = _FakePlatformPlayer();
          players.add(player);
          return Player(platformPlayer: player);
        },
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
      );
      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
      await backend.setClips([
        const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 4)),
      ]);
      final gate = Completer<void>();
      players.single.disposalGate = gate;
      final superseded = backend.setClips([
        const VideoClip(uri: 'file:///second.mp4', end: Duration(seconds: 6)),
      ]);
      await players.first.disposalStarted.future;
      final latest = backend.setClips([
        const VideoClip(uri: 'file:///latest.mp4', end: Duration(seconds: 8)),
      ]);
      gate.complete();
      await superseded;
      await latest;

      expect(
        players.last.lastOpenedPlaylist!.medias.single.uri,
        endsWith('/latest.mp4'),
      );
      expect(players.first.disposeCalls, 1);
      await backend.dispose();
    });

    test('reports native playback errors from the SDK error stream', () async {
      final player = _FakePlatformPlayer();
      final errors = <Object>[];
      final emitted = <DivineVideoPlayerState>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: player),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
      );
      await backend.initialize(
        onStateChanged: emitted.add,
        onError: errors.add,
      );

      await backend.setClips([
        const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 4)),
      ]);
      player.emitPlaybackError('Synthetic decoder failure');
      await pumpEventQueue();

      expect(errors, ['Synthetic decoder failure']);
      expect(emitted.last.status, PlaybackStatus.error);
      await backend.setVolume(0.4);
      await pumpEventQueue();
      expect(emitted.last.status, PlaybackStatus.error);
      expect(emitted.last.errorMessage, contains('Synthetic decoder failure'));
      expect(errors, ['Synthetic decoder failure']);
      await backend.dispose();
    });

    test(
      'applies a volume change to the replacement player during retirement',
      () async {
        final players = <_FakePlatformPlayer>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () {
            final player = _FakePlatformPlayer();
            players.add(player);
            return Player(platformPlayer: player);
          },
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );
        addTearDown(backend.dispose);
        await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
        await backend.setClips([
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 4)),
        ]);
        await backend.setVolume(0.25);
        final gate = Completer<void>();
        players.single.disposalGate = gate;
        final replacing = backend.setClips([
          const VideoClip(uri: 'file:///second.mp4', end: Duration(seconds: 6)),
        ]);
        await players.first.disposalStarted.future;

        final changingVolume = backend.setVolume(0.2);
        gate.complete();
        await replacing;
        await changingVolume;

        expect(players.last.lastVolume, 20);
      },
    );

    test(
      'renews first-frame readiness after replacing a stopped source',
      () async {
        final players = <_FakePlatformPlayer>[];
        final outputs = <_FakeVideoController>[];
        final emitted = <DivineVideoPlayerState>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () {
            final player = _FakePlatformPlayer();
            players.add(player);
            return Player(platformPlayer: player);
          },
          videoControllerFactory: (_) {
            final output = _FakeVideoController();
            outputs.add(output);
            return output;
          },
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );
        addTearDown(backend.dispose);
        await backend.initialize(onStateChanged: emitted.add, onError: (_) {});
        await backend.setClips([
          const VideoClip(uri: 'file:///first.mp4', end: Duration(seconds: 4)),
        ]);
        outputs.single.ready.complete();
        await pumpEventQueue();
        expect(emitted.last.isFirstFrameRendered, isTrue);
        await backend.setVolume(0.25);
        await backend.setLooping(looping: true);
        await backend.stop();

        await backend.setClips([
          const VideoClip(uri: 'file:///second.mp4', end: Duration(seconds: 6)),
        ]);

        expect(outputs, hasLength(2));
        expect(players.first.disposeCalls, 1);
        expect(players.last.lastVolume, 25);
        expect(players.last.lastPlaylistMode, PlaylistMode.loop);
        expect(emitted.last.isFirstFrameRendered, isFalse);
        outputs.last.ready.complete();
        await pumpEventQueue();
        expect(emitted.last.isFirstFrameRendered, isTrue);
        await backend.dispose();
        expect(players.last.disposeCalls, 1);
      },
    );

    test(
      'keeps timeline coherent while an untrimmed duration is pending',
      () async {
        final player = _FakePlatformPlayer();
        final duration = Completer<Duration>();
        final emitted = <DivineVideoPlayerState>[];
        final asynchronousErrors = <Object>[];
        late List<DivineVideoPlayerState> duringProbe;
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: player),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
          durationProbe: (_) => duration.future,
        );

        await runZonedGuarded(
          () async {
            await backend.initialize(
              onStateChanged: emitted.add,
              onError: asynchronousErrors.add,
            );
            final loading = backend.setClips([
              const VideoClip.network('https://example.com/ordinary-video.mp4'),
            ]);
            await player.setVolume(42);
            await pumpEventQueue();
            duringProbe = List.of(emitted);
            duration.complete(6.seconds);
            await loading;
            await backend.dispose();
          },
          (error, _) => asynchronousErrors.add(error),
        );

        expect(asynchronousErrors, isEmpty);
        expect(duringProbe.last.volume, 0.42);
        expect(duringProbe.last.clipCount, 0);
        expect(emitted.last.clipCount, 1);
        expect(emitted.last.duration, 6.seconds);
      },
    );

    test('only invokes the media kit initializer once per process', () async {
      var calls = 0;

      Future<void> initializeBackend() async {
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: () => calls++,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );
        await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
      }

      await initializeBackend();
      await initializeBackend();

      expect(calls, 1);
    });

    test('buildView and playback methods require initialization', () {
      final backend = MediaKitLinuxVideoPlayerBackend();

      expect(backend.buildView, throwsStateError);
      expect(backend.play, throwsStateError);
      expect(backend.pause, throwsStateError);
      expect(backend.stop, throwsStateError);
      expect(() => backend.seekTo(Duration.zero), throwsStateError);
      expect(() => backend.setVolume(1), throwsStateError);
      expect(() => backend.setPlaybackSpeed(1), throwsStateError);
      expect(() => backend.setLooping(looping: true), throwsStateError);
      expect(() => backend.jumpToClip(0), throwsStateError);
    });

    testWidgets('initialize wires first-frame callback and buildView', (
      tester,
    ) async {
      final fakeVideoController = _FakeVideoController();
      final emittedStates = <DivineVideoPlayerState>[];
      late final MediaKitLinuxVideoPlayerBackend backend;
      await tester.runAsync(() async {
        backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) => fakeVideoController,
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const Text('Linux view'),
        );
        await backend.initialize(
          onStateChanged: emittedStates.add,
          onError: (_) {},
        );
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: backend.buildView(),
        ),
      );
      expect(find.text('Linux view'), findsOneWidget);

      fakeVideoController.ready.complete();
      await tester.pump();

      expect(emittedStates, isEmpty, reason: 'no media has been loaded');
      await tester.runAsync(
        () => backend.setClips([
          const VideoClip(uri: 'file:///one.mp4', end: Duration(seconds: 2)),
        ]),
      );
      expect(emittedStates.last.isFirstFrameRendered, isTrue);
      await tester.runAsync(backend.dispose);
    });

    test(
      'setClips uses the default duration probe and supports seeks',
      () async {
        final mainPlayer = _FakePlatformPlayer();
        final probePlayer = _FakePlatformPlayer(probeDuration: 9.seconds);
        final players = <_FakePlatformPlayer>[mainPlayer, probePlayer];
        final emittedStates = <DivineVideoPlayerState>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: players.removeAt(0)),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );

        await backend.initialize(
          onStateChanged: emittedStates.add,
          onError: (_) {},
        );

        await backend.setClips([
          VideoClip(uri: 'file:///clip-1.mp4', end: 5.seconds),
          VideoClip(uri: 'file:///clip-2.mp4', start: 2.seconds),
        ], startPosition: 6.seconds);

        expect(mainPlayer.lastOpenedPlaylist?.medias, hasLength(2));
        expect(mainPlayer.lastJumpIndex, 1);
        expect(mainPlayer.lastSeekPosition, 3.seconds);
        expect(emittedStates.first.status, PlaybackStatus.buffering);
        expect(emittedStates.last.duration, 12.seconds);
        expect(probePlayer.lastOpenedMedia?.uri, endsWith('clip-2.mp4'));
      },
    );

    test('rejects clips with end before start', () async {
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
      );

      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});

      await expectLater(
        () => backend.setClips([
          const VideoClip(
            uri: 'file:///clip.mp4',
            start: Duration(seconds: 4),
            end: Duration(seconds: 2),
          ),
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects clips whose start exceeds source duration', () async {
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
        durationProbe: (_) async => 3.seconds,
      );

      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});

      await expectLater(
        () => backend.setClips([
          const VideoClip(
            uri: 'file:///clip.mp4',
            start: Duration(seconds: 4),
          ),
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('times out when the default duration probe never resolves', () async {
      final mainPlayer = _FakePlatformPlayer();
      final probePlayer = _FakePlatformPlayer();
      final players = <_FakePlatformPlayer>[mainPlayer, probePlayer];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: players.removeAt(0)),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
      );

      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});

      Object? error;
      final async = FakeAsync()
        ..run((async) {
          unawaited(
            backend
                .setClips([const VideoClip(uri: 'file:///clip.mp4')])
                .catchError((Object caughtError) => error = caughtError),
          );

          async
            ..elapse(const Duration(seconds: 11))
            ..flushMicrotasks();
        });

      await pumpEventQueue();
      async.flushMicrotasks();

      expect(error, isA<TimeoutException>());
      expect(probePlayer.lastOpenedMedia?.uri, endsWith('clip.mp4'));
      expect(probePlayer.disposeCalls, 1);
      await backend.dispose();
    });

    test(
      'playback controls and state refresh update the emitted state',
      () async {
        final fakePlayer = _FakePlatformPlayer();
        final emittedStates = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: fakePlayer),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
          durationProbe: (_) async => 7.seconds,
        );

        await backend.initialize(
          onStateChanged: emittedStates.add,
          onError: errors.add,
        );
        await backend.setClips([
          VideoClip(uri: 'file:///clip-1.mp4', end: 4.seconds),
          const VideoClip(uri: 'file:///clip-2.mp4'),
        ]);

        fakePlayer.emitState(
          fakePlayer.state.copyWith(
            position: 2.seconds,
            buffer: 3.seconds,
            width: 1920,
            height: 1080,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        await backend.play();
        await backend.pause();
        fakePlayer.emitState(
          fakePlayer.state.copyWith(buffering: false, playing: false),
        );
        await Future<void>.delayed(Duration.zero);
        await backend.setVolume(0.25);
        await backend.setPlaybackSpeed(1.5);
        await backend.setLooping(looping: true);
        await backend.jumpToClip(1);
        await backend.jumpToClip(5);
        await backend.seekTo(5.seconds);

        fakePlayer
          ..emitPlaylistIndex(1)
          ..emitState(
            fakePlayer.state.copyWith(
              playing: true,
              position: 5.seconds,
              buffer: 6.seconds,
              volume: 25,
              rate: 1.5,
              width: 1280,
              height: 720,
            ),
          );
        await Future<void>.delayed(Duration.zero);

        fakePlayer.emitState(
          fakePlayer.state.copyWith(buffering: true, playing: false),
        );
        await Future<void>.delayed(Duration.zero);

        await backend.setLooping(looping: false);
        fakePlayer.emitState(
          fakePlayer.state.copyWith(
            buffering: false,
            completed: true,
            playing: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        fakePlayer.emitPositionError('position stream failed');
        await Future<void>.delayed(Duration.zero);

        expect(fakePlayer.playCalls, 1);
        expect(fakePlayer.pauseCalls, 1);
        expect(fakePlayer.lastVolume, 25);
        expect(fakePlayer.lastRate, 1.5);
        expect(fakePlayer.lastPlaylistMode, PlaylistMode.none);
        expect(fakePlayer.lastJumpIndex, 1);
        expect(fakePlayer.lastSeekPosition, 1.seconds);
        expect(
          emittedStates.any((state) => state.status == PlaybackStatus.playing),
          isTrue,
        );
        expect(
          emittedStates.any(
            (state) => state.status == PlaybackStatus.buffering,
          ),
          isTrue,
        );
        expect(
          emittedStates.any((state) => state.status == PlaybackStatus.ready),
          isTrue,
        );
        expect(
          emittedStates.any(
            (state) => state.status == PlaybackStatus.completed,
          ),
          isTrue,
        );
        expect(emittedStates.last.status, PlaybackStatus.error);
        expect(errors, contains('position stream failed'));
      },
    );

    test('audio track methods warn once and do not throw on Linux', () async {
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
      );

      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});

      await backend.setAudioTracks(const [
        AudioTrack(uri: 'file:///overlay.mp3'),
      ]);
      await backend.setAudioTracks(const []);
      await backend.removeAllAudioTracks();
      await backend.setAudioTrackVolume(0, 0.5);
    });

    test('dispose cancels listeners before player teardown', () async {
      final fakePlayer = _FakePlatformPlayer(emitErrorOnDispose: true);
      final emittedStates = <DivineVideoPlayerState>[];
      final errors = <Object>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: fakePlayer),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
        durationProbe: (_) async => 4.seconds,
      );

      await backend.initialize(
        onStateChanged: emittedStates.add,
        onError: errors.add,
      );
      await backend.setClips([const VideoClip(uri: 'file:///clip.mp4')]);
      final emittedBeforeDispose = emittedStates.length;

      await backend.dispose();
      await backend.dispose();

      expect(fakePlayer.disposeCalls, 1);
      expect(emittedStates, hasLength(emittedBeforeDispose));
      expect(errors, isEmpty);
      expect(backend.play, throwsStateError);
    });

    test(
      'dispose ignores first-frame callbacks that complete afterward',
      () async {
        final fakeVideoController = _FakeVideoController();
        final emittedStates = <DivineVideoPlayerState>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: _FakePlatformPlayer()),
          videoControllerFactory: (_) => fakeVideoController,
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
        );

        await backend.initialize(
          onStateChanged: emittedStates.add,
          onError: (_) {},
        );
        await backend.dispose();

        fakeVideoController.ready.complete();
        await Future<void>.delayed(Duration.zero);

        expect(emittedStates, isEmpty);
      },
    );

    test('stop resets state and dispose is idempotent', () async {
      final fakePlayer = _FakePlatformPlayer();
      final emittedStates = <DivineVideoPlayerState>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: fakePlayer),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
        durationProbe: (_) async => 4.seconds,
      );

      await backend.initialize(
        onStateChanged: emittedStates.add,
        onError: (_) {},
      );
      await backend.setClips([const VideoClip(uri: 'file:///clip.mp4')]);

      await backend.stop();

      expect(emittedStates.last, const DivineVideoPlayerState());
      expect(fakePlayer.stopCalls, 1);

      await backend.dispose();
      await backend.dispose();

      expect(fakePlayer.disposeCalls, 1);
      expect(backend.play, throwsStateError);
    });
  });

  group('playback speed', () {
    Future<MediaKitLinuxVideoPlayerBackend> buildBackend(
      _FakePlatformPlayer fakePlayer,
    ) async {
      final backend = MediaKitLinuxVideoPlayerBackend(
        mediaKitInitializer: _noop,
        playerFactory: () => Player(platformPlayer: fakePlayer),
        videoControllerFactory: (_) => _FakeVideoController(),
        videoControllerReady: (controller) =>
            (controller as _FakeVideoController).ready.future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
        durationProbe: (_) async => 10.seconds,
      );
      await backend.initialize(onStateChanged: (_) {}, onError: (_) {});
      return backend;
    }

    test(
      'playlist-index change re-applies per-clip speed when authored speeds '
      'exist',
      () async {
        final fakePlayer = _FakePlatformPlayer();
        final backend = await buildBackend(fakePlayer);

        await backend.setClips([
          VideoClip(
            uri: 'file:///clip-1.mp4',
            end: 4.seconds,
            playbackSpeed: 0.5,
          ),
          VideoClip(
            uri: 'file:///clip-2.mp4',
            end: 6.seconds,
            playbackSpeed: 2,
          ),
        ]);

        // Simulate mpv advancing to the second clip.
        fakePlayer.emitPlaylistIndex(1);
        await Future<void>.delayed(Duration.zero);

        expect(fakePlayer.lastRate, 2.0);
      },
    );

    test(
      'playlist-index change does NOT call setRate when all clips are 1.0x',
      () async {
        final fakePlayer = _FakePlatformPlayer();
        final backend = await buildBackend(fakePlayer);

        await backend.setClips([
          VideoClip(uri: 'file:///clip-1.mp4', end: 4.seconds),
          VideoClip(uri: 'file:///clip-2.mp4', end: 6.seconds),
        ]);

        // setClips applies the first clip's speed exactly once. The count is
        // the observable, not lastRate: a second setRate(1.0) leaves lastRate
        // at 1.0, so the value alone could never fail (#8617).
        expect(fakePlayer.setRateCalls, 1);
        expect(fakePlayer.lastRate, 1.0);

        fakePlayer.emitPlaylistIndex(1);
        await Future<void>.delayed(Duration.zero);

        expect(fakePlayer.setRateCalls, 1);
      },
    );

    test(
      'setClips converts slow-clip source duration to playback duration',
      () async {
        final emittedStates = <DivineVideoPlayerState>[];
        final fakePlayer = _FakePlatformPlayer();
        final backend = MediaKitLinuxVideoPlayerBackend(
          mediaKitInitializer: _noop,
          playerFactory: () => Player(platformPlayer: fakePlayer),
          videoControllerFactory: (_) => _FakeVideoController(),
          videoControllerReady: (controller) =>
              (controller as _FakeVideoController).ready.future,
          videoViewBuilder: (_) => const SizedBox.shrink(),
          durationProbe: (_) async => 10.seconds,
        );
        await backend.initialize(
          onStateChanged: emittedStates.add,
          onError: (_) {},
        );

        // 4-second clip at 0.5x speed → 8 s wall-clock duration.
        await backend.setClips([
          VideoClip(
            uri: 'file:///clip-slow.mp4',
            end: 4.seconds,
            playbackSpeed: 0.5,
          ),
        ]);

        expect(emittedStates.last.duration, 8.seconds);
      },
    );

    test('seekTo with slow clip uses playback-to-source conversion', () async {
      final fakePlayer = _FakePlatformPlayer();
      final backend = await buildBackend(fakePlayer);

      // 10-second clip at 0.5x → 20 s playback.
      await backend.setClips([
        const VideoClip(uri: 'file:///clip-slow.mp4', playbackSpeed: 0.5),
      ]);

      // Seek to playback second 4 → source second 2.
      await backend.seekTo(4.seconds);

      expect(fakePlayer.lastSeekPosition, 2.seconds);
    });
  });

  group('registerWith', () {
    test(
      'linux plugin registration is a no-op',
      () => expect(DivineVideoPlayerLinuxPlugin.registerWith, returnsNormally),
    );
  });
}

Future<void> _withDesktopController(
  LinuxVideoPlayerBackend backend,
  Future<void> Function(DivineVideoPlayerController) action,
) async {
  final originalForce = DivineVideoPlayerController.debugForceLinuxBackend;
  final originalFactory = DivineVideoPlayerController.linuxBackendFactory;
  DivineVideoPlayerController.debugForceLinuxBackend = true;
  DivineVideoPlayerController.linuxBackendFactory = () => backend;
  final controller = DivineVideoPlayerController();
  try {
    await controller.initialize();
    await action(controller);
  } finally {
    await controller.dispose();
    DivineVideoPlayerController.linuxBackendFactory = originalFactory;
    DivineVideoPlayerController.debugForceLinuxBackend = originalForce;
  }
}

class _FakeVideoController {
  final ready = Completer<void>();
}

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer({
    this.probeDuration,
    this.emitErrorOnDispose = false,
    this.durationDuringOpen = false,
    this.probeError,
  }) : super(configuration: const PlayerConfiguration());

  final Duration? probeDuration;
  final bool emitErrorOnDispose;
  final bool durationDuringOpen;
  final String? probeError;

  Playlist? lastOpenedPlaylist;
  Media? lastOpenedMedia;
  PlaylistMode? lastPlaylistMode;
  Duration? lastSeekPosition;
  double? lastVolume;
  double? lastRate;
  int? lastJumpIndex;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  int setRateCalls = 0;
  StateError? volumeError;
  StateError? pauseError;
  bool deferVolumeObservation = false;
  Future<void>? volumeReady;
  Timer? _durationTimer;
  StateError? rateError;
  Completer<void>? disposalGate;
  final disposalStarted = Completer<void>();

  @override
  Future<void> dispose() async {
    _durationTimer?.cancel();
    disposeCalls++;
    if (!disposalStarted.isCompleted) disposalStarted.complete();
    await disposalGate?.future;
    if (emitErrorOnDispose) {
      positionController.addError('dispose error');
    }
    await super.dispose();
  }

  @override
  Future<void> jump(int index) async {
    lastJumpIndex = index;
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (playable is Playlist) {
      lastOpenedPlaylist = playable;
      state = state.copyWith(
        playlist: playable,
        completed: false,
        playing: play,
      );
      playlistController.add(playable);
      return;
    }

    if (playable is Media) {
      lastOpenedMedia = playable;
      if (probeError case final error?) {
        errorController.add(error);
        return;
      }
      if (probeDuration != null) {
        if (durationDuringOpen) {
          state = state.copyWith(duration: probeDuration);
          durationController.add(probeDuration!);
          await pumpEventQueue();
          return;
        }
        _durationTimer = Timer(Duration.zero, () {
          state = state.copyWith(duration: probeDuration);
          durationController.add(probeDuration!);
        });
      }
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    if (pauseError case final error?) throw error;
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> play() async {
    playCalls++;
    state = state.copyWith(playing: true);
    playingController.add(true);
  }

  void emitPlaylistIndex(int index) {
    final playlist = (lastOpenedPlaylist ?? const Playlist([])).copyWith(
      index: index,
    );
    state = state.copyWith(playlist: playlist);
    playlistController.add(playlist);
  }

  void emitState(PlayerState nextState) {
    state = nextState;
    positionController.add(nextState.position);
    durationController.add(nextState.duration);
    bufferController.add(nextState.buffer);
    bufferingController.add(nextState.buffering);
    completedController.add(nextState.completed);
    playingController.add(nextState.playing);
    volumeController.add(nextState.volume);
    rateController.add(nextState.rate);
    widthController.add(nextState.width);
    heightController.add(nextState.height);
  }

  void emitPositionError(String error) {
    positionController.addError(error);
  }

  void emitPlaybackError(String error) {
    errorController.add(error);
  }

  @override
  Future<void> seek(Duration duration) async {
    lastSeekPosition = duration;
    state = state.copyWith(position: duration);
    positionController.add(duration);
  }

  @override
  Future<void> setPlaylistMode(PlaylistMode playlistMode) async {
    lastPlaylistMode = playlistMode;
    state = state.copyWith(playlistMode: playlistMode);
    playlistModeController.add(playlistMode);
  }

  @override
  Future<void> setRate(double rate) async {
    if (rateError case final error?) throw error;
    setRateCalls++;
    lastRate = rate;
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    await volumeReady;
    if (volumeError case final error?) throw error;
    lastVolume = volume;
    if (deferVolumeObservation) return;
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    state = const PlayerState().copyWith(
      volume: state.volume,
      rate: state.rate,
      playlistMode: state.playlistMode,
    );
    positionController.add(Duration.zero);
  }
}

extension on int {
  Duration get seconds => Duration(seconds: this);
}

void _noop() {}
