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
