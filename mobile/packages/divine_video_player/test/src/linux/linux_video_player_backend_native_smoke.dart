// ABOUTME: Native libmpv regression entrypoint, run explicitly by Desktop CI.
// ABOUTME: Uses synthetic media and null output with the native libmpv runtime.

import 'dart:async';
import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide AudioTrack;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final library = Platform.environment['DIVINE_NATIVE_LIBMPV'];
    if (library != null) MediaKit.ensureInitialized(libmpv: library);
  });
  setUp(MediaKitLinuxVideoPlayerBackend.resetInitializationForTesting);
  tearDown(MediaKitLinuxVideoPlayerBackend.resetInitializationForTesting);

  group('native desktop media', () {
    test(
      'retains a validated source when newer validation rejects '
      'during retirement',
      () async {
        MediaKit.ensureInitialized();
        final players = <Player>[];
        final states = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          playerFactory: () {
            final player = Player();
            players.add(player);
            return player;
          },
          videoControllerFactory: (_) => Object(),
          videoControllerReady: (_) => Completer<void>().future,
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        addTearDown(backend.dispose);
        final firstNative = players.first.platform! as NativePlayer;
        await firstNative.setProperty('vo', 'null');
        await firstNative.setProperty('vid', 'auto');
        await firstNative.setProperty('ao', 'null');
        final first = File(
          'test/fixtures/desktop_silent_portrait.mp4',
        ).absolute;
        final second = File(
          'test/fixtures/desktop_audio_portrait.mp4',
        ).absolute;
        final missing = File('test/fixtures/absent-overlap.mp4').absolute;
        await backend.setClips([
          VideoClip(uri: first.uri.toString(), end: const Duration(seconds: 1)),
        ]);
        await backend.setLooping(looping: true);
        final firstProgress = players.first.stream.position.firstWhere(
          (position) => position > Duration.zero,
        );
        await backend.play();
        await firstProgress.timeout(const Duration(seconds: 5));
        final retiring = Completer<void>();
        final gate = Completer<void>();
        firstNative.release.add(() async {
          retiring.complete();
          await gate.future;
        });
        final replacing = backend.setClips([
          VideoClip(
            uri: second.uri.toString(),
            end: const Duration(milliseconds: 900),
          ),
        ]);
        await retiring.future.timeout(const Duration(seconds: 5));
        try {
          // NativePlayer uses a static command lock. Start validation while
          // retirement is held, then release it so both players can proceed.
          final rejected = expectLater(
            backend.setClips([VideoClip(uri: missing.uri.toString())]),
            throwsStateError,
          );
          gate.complete();
          await Future.wait<void>([replacing, rejected]);
        } finally {
          if (!gate.isCompleted) gate.complete();
          await replacing;
        }

        final native = players.last.platform! as NativePlayer;
        expect(await native.getProperty('playlist-count'), '1');
        expect(
          players.last.state.playlist.medias.single.uri,
          Media(second.uri.toString()).uri,
        );
        expect(states.last.clipCount, 1);
        expect(states.last.duration, const Duration(milliseconds: 900));
        await native.setProperty('vo', 'null');
        await native.setProperty('ao', 'null');
        await native.setProperty('vid', 'auto');
        final progressing = players.last.stream.position.firstWhere(
          (position) => position > Duration.zero,
        );
        await backend.play();
        await progressing.timeout(const Duration(seconds: 5));
        expect(states.last.status, PlaybackStatus.playing);
        expect(errors, isEmpty);
      },
    );

    test(
      'preserves a rendered source after replacement validation fails',
      () async {
        MediaKit.ensureInitialized();
        final player = Player();
        final native = player.platform! as NativePlayer;
        await native.setProperty('vo', 'null');
        await native.setProperty('vid', 'auto');
        await native.setProperty('ao', 'null');
        final source = File(
          'test/fixtures/desktop_silent_portrait.mp4',
        ).absolute;
        final missing = File('test/fixtures/absent-replacement.mp4').absolute;
        var first = true;
        final states = <DivineVideoPlayerState>[];
        final errors = <Object>[];
        final rendered = Completer<void>();
        final backend = MediaKitLinuxVideoPlayerBackend(
          playerFactory: () {
            if (first) {
              first = false;
              return player;
            }
            return Player();
          },
          videoControllerFactory: (_) => Object(),
          videoControllerReady: (_) => rendered.future,
        );
        await backend.initialize(
          onStateChanged: states.add,
          onError: errors.add,
        );
        addTearDown(backend.dispose);
        await backend.setClips([
          VideoClip(
            uri: source.uri.toString(),
            end: const Duration(seconds: 1),
          ),
        ]);
        await backend.setLooping(looping: true);
        rendered.complete();
        await backend.play();
        await pumpEventQueue();
        expect(states.last.isFirstFrameRendered, isTrue);

        await expectLater(
          backend.setClips([VideoClip(uri: missing.uri.toString())]),
          throwsStateError,
        );
        await player.stream.position
            .firstWhere((position) => position > Duration.zero)
            .timeout(const Duration(seconds: 4));

        expect(player.state.playing, isTrue);
        expect(states.last.status, PlaybackStatus.playing);
        expect(states.last.isFirstFrameRendered, isTrue);
        expect(errors, isEmpty);
      },
    );

    testWidgets('keeps the thumbnail when video output is disabled', (
      tester,
    ) async {
      expect(Platform.environment['DIVINE_LINUX_NO_VIDEO_OUTPUT'], '1');
      final original = debugDefaultTargetPlatformOverride;
      final originalFactory = DivineVideoPlayerController.linuxBackendFactory;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      DivineVideoPlayerController.linuxBackendFactory = () =>
          MediaKitLinuxVideoPlayerBackend(
            mediaKitInitializer: () {},
            playerFactory: () => Player(platformPlayer: _PlaybackHarness()),
          );
      try {
        late final DivineVideoPlayerController controller;
        await tester.runAsync(() async {
          controller = DivineVideoPlayerController();
          await controller.initialize();
          await controller.setClips([
            const VideoClip(
              uri: 'file:///audio-only-output.mp4',
              end: Duration(seconds: 4),
            ),
          ]);
        });
        try {
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: DivineVideoPlayer(
                  controller: controller,
                  placeholder: const Text('Video thumbnail'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Video thumbnail'), findsOneWidget);
          expect(controller.state.isFirstFrameRendered, isFalse);
        } finally {
          await tester.runAsync(controller.dispose);
        }
      } finally {
        debugDefaultTargetPlatformOverride = original;
        DivineVideoPlayerController.linuxBackendFactory = originalFactory;
      }
    });

    test('resolves a video-only MP4 without an explicit clip end', () async {
      final source = File('test/fixtures/desktop_silent_portrait.mp4').absolute;
      expect(source.existsSync(), isTrue);
      var mainPlayerCreated = false;
      final states = <DivineVideoPlayerState>[];
      final errors = <Object>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        playerFactory: () {
          if (mainPlayerCreated) return Player();
          mainPlayerCreated = true;
          return Player(platformPlayer: _PlaybackHarness());
        },
        videoControllerFactory: (_) => Object(),
        videoControllerReady: (_) => Completer<void>().future,
        videoViewBuilder: (_) => const SizedBox.shrink(),
      );
      await backend.initialize(onStateChanged: states.add, onError: errors.add);
      addTearDown(backend.dispose);

      await backend.setClips([VideoClip(uri: source.uri.toString())]);

      expect(states.last.duration, const Duration(seconds: 1));
      expect(errors, isEmpty);
    });

    test('continues native video after an unavailable audio output', () async {
      MediaKit.ensureInitialized();
      final source = File('test/fixtures/desktop_audio_portrait.mp4').absolute;
      expect(source.existsSync(), isTrue);
      final player = Player();
      final native = player.platform! as NativePlayer;
      await native.setProperty('vo', 'null');
      await native.setProperty('vid', 'auto');
      await native.setProperty('ao', 'divine_missing_audio_driver');
      final states = <DivineVideoPlayerState>[];
      final errors = <Object>[];
      final diagnostics = <String>[];
      final diagnosticSubscription = player.stream.error.listen(
        diagnostics.add,
      );
      addTearDown(diagnosticSubscription.cancel);
      final backend = MediaKitLinuxVideoPlayerBackend(
        playerFactory: () => player,
        videoControllerFactory: (_) => Object(),
        videoControllerReady: (_) => Future<void>.value(),
        videoViewBuilder: (_) => const SizedBox.shrink(),
      );
      await backend.initialize(onStateChanged: states.add, onError: errors.add);
      addTearDown(backend.dispose);
      final completed = player.stream.completed.firstWhere((value) => value);
      await backend.setClips([
        VideoClip(uri: source.uri.toString(), end: const Duration(seconds: 1)),
      ]);
      await backend.play();
      await completed.timeout(const Duration(seconds: 10));

      expect(
        diagnostics,
        contains('Could not open/initialize audio device -> no sound.'),
      );
      expect(
        states.last.status,
        PlaybackStatus.completed,
        reason: errors.join('\n'),
      );
      expect(errors, isEmpty);
    });
  });
}

class _PlaybackHarness extends PlatformPlayer {
  _PlaybackHarness() : super(configuration: const PlayerConfiguration());

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    state = state.copyWith(playlist: playable as Playlist, playing: play);
  }

  @override
  Future<void> setPlaylistMode(PlaylistMode playlistMode) async {}

  @override
  Future<void> setRate(double rate) async {
    state = state.copyWith(rate: rate);
  }
}
