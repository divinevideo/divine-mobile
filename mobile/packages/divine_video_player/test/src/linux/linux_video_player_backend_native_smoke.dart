// ABOUTME: Native libmpv regression entrypoint, run explicitly by Desktop CI.
// ABOUTME: Uses synthetic media and null output with the native libmpv runtime.

import 'dart:async';
import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide AudioTrack;
import 'package:media_kit_video/media_kit_video.dart' as video;

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
      'a stop during native retirement cannot inherit a later frame',
      () async {
        MediaKit.ensureInitialized();
        final players = <Player>[];
        final outputs = <Completer<void>>[];
        final errors = <Object>[];
        final backend = MediaKitLinuxVideoPlayerBackend(
          playerFactory: () {
            final player = _headlessPlayer();
            players.add(player);
            return player;
          },
          videoControllerFactory: (_) {
            final output = Completer<void>();
            outputs.add(output);
            return output;
          },
          videoControllerReady: (output) => (output as Completer<void>).future,
        );
        await backend.initialize(onStateChanged: (_) {}, onError: errors.add);
        addTearDown(backend.dispose);
        final clip = VideoClip(
          uri: File(
            'test/fixtures/desktop_silent_portrait.mp4',
          ).absolute.uri.toString(),
          end: const Duration(seconds: 1),
        );
        await backend.setClips([clip]);
        final retiring = Completer<void>();
        final gate = Completer<void>();
        players.first.platform!.release.add(() async {
          retiring.complete();
          await gate.future;
        });
        final replacing = backend.setClips([clip]);
        try {
          await retiring.future.timeout(const Duration(seconds: 5));
          final stopping = backend.stop();
          gate.complete();
          await Future.wait<void>([replacing, stopping]);
          final stopped = backend.firstFrameRendered;
          await backend.setClips([clip]);
          outputs.last.complete();

          expect(await backend.firstFrameRendered, isTrue);
          expect(await stopped, isFalse);
          expect(errors, isEmpty);
        } finally {
          if (!gate.isCompleted) gate.complete();
          await replacing;
        }
      },
    );

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
            final player = _headlessPlayer();
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
        final player = _headlessPlayer();
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
            return _headlessPlayer();
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
          if (mainPlayerCreated) return _headlessPlayer();
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
      final player = _headlessPlayer(
        audioOutput: 'divine_missing_audio_driver',
      );
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

    test('reflects native recovery onto a valid subsequent clip', () async {
      MediaKit.ensureInitialized();
      final player = _headlessPlayer();
      final states = <DivineVideoPlayerState>[];
      final errors = <Object>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
        playerFactory: () => player,
        videoControllerFactory: (_) => Object(),
        videoControllerReady: (_) => Completer<void>().future,
      );
      await backend.initialize(onStateChanged: states.add, onError: errors.add);
      addTearDown(backend.dispose);
      final progressing = player.stream.position.firstWhere(
        (position) =>
            position > Duration.zero && player.state.playlist.index == 1,
      );
      await backend.setClips([
        VideoClip(
          uri: File(
            'test/fixtures/absent-playlist.mp4',
          ).absolute.uri.toString(),
          end: const Duration(seconds: 1),
        ),
        VideoClip(
          uri: File(
            'test/fixtures/desktop_audio_portrait.mp4',
          ).absolute.uri.toString(),
          end: const Duration(seconds: 1),
        ),
      ]);
      await backend.play();
      await progressing.timeout(const Duration(seconds: 5));
      await pumpEventQueue();

      expect(errors, isNotEmpty, reason: 'the first clip genuinely failed');
      expect(player.state.playlist.index, 1);
      expect(player.state.playing, isTrue);
      expect(states.last.currentClipIndex, 1);
      expect(states.last.status, PlaybackStatus.playing);
      expect(states.last.errorMessage, isNull);
    });

    testWidgets('blocks playback after attached renderer creation fails', (
      tester,
    ) async {
      const channel = MethodChannel('com.alexmercerind/media_kit_video');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'VideoOutputManager.Create') {
          throw PlatformException(code: 'synthetic_output_create_failed');
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final originalPlatform = debugDefaultTargetPlatformOverride;
      final originalFactory = DivineVideoPlayerController.linuxBackendFactory;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      late Player player;
      late DivineVideoPlayerController controller;
      late Future<void> opened;
      late Future<DivineVideoPlayerState> failed;
      final created = StreamController<Player>.broadcast();
      addTearDown(created.close);
      try {
        await tester.runAsync(() async {
          MediaKit.ensureInitialized();
          DivineVideoPlayerController.linuxBackendFactory = () =>
              MediaKitLinuxVideoPlayerBackend(
                playerFactory: () => player = _headlessPlayer(),
                videoControllerFactory: (player) {
                  final output = video.VideoController(
                    player,
                    configuration: const video.VideoControllerConfiguration(
                      vo: 'null',
                      hwdec: 'no',
                    ),
                  );
                  created.add(player);
                  return output;
                },
              );
          controller = DivineVideoPlayerController();
          await controller.initialize();
          final loading = controller.stateStream.firstWhere(
            (state) => state.status == PlaybackStatus.buffering,
          );
          failed = controller.stateStream.firstWhere(
            (state) => state.status == PlaybackStatus.error,
          );
          opened = controller.setSource(
            VideoClip(
              uri: File(
                'test/fixtures/desktop_audio_portrait.mp4',
              ).absolute.uri.toString(),
              end: const Duration(seconds: 1),
            ),
          );
          await loading.timeout(const Duration(seconds: 3));
          expect(
            (player.platform! as NativePlayer).isVideoControllerAttached,
            isTrue,
          );
        });
        await tester.pump();
        await tester.runAsync(() async {
          await opened.timeout(const Duration(seconds: 5));
          final error = await failed.timeout(const Duration(seconds: 3));
          expect(
            error.errorMessage,
            contains('synthetic_output_create_failed'),
          );
          await controller.play();

          final native = player.platform! as NativePlayer;
          expect(native.videoControllerCompleter.isCompleted, isTrue);
          expect(await native.getProperty('pause'), 'yes');
          expect(player.state.playing, isFalse);
          expect(await controller.firstFrameRendered, isFalse);
          expect(controller.state.status, PlaybackStatus.error);
          expect(calls, contains('VideoOutputManager.Create'));
        });

        await tester.runAsync(() async {
          await controller.stop();
          final replacement = created.stream.first;
          failed = controller.stateStream.firstWhere(
            (state) => state.status == PlaybackStatus.error,
          );
          opened = controller.setSource(
            VideoClip(
              uri: File(
                'test/fixtures/desktop_silent_portrait.mp4',
              ).absolute.uri.toString(),
              end: const Duration(seconds: 1),
            ),
          );
          await replacement.timeout(const Duration(seconds: 5));
        });
        await tester.pump();
        await tester.runAsync(() async {
          await opened.timeout(const Duration(seconds: 5));
          final error = await failed.timeout(const Duration(seconds: 3));
          expect(
            error.errorMessage,
            contains('synthetic_output_create_failed'),
          );
          await controller.play();

          expect(player.state.playing, isFalse);
          expect(
            await controller.firstFrameRendered.timeout(
              const Duration(seconds: 2),
            ),
            isFalse,
          );
          expect(
            calls.where((call) => call == 'VideoOutputManager.Create'),
            hasLength(2),
          );
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(controller.dispose);
        DivineVideoPlayerController.linuxBackendFactory = originalFactory;
        debugDefaultTargetPlatformOverride = originalPlatform;
      }
    });
  });
}

Player _headlessPlayer({String audioOutput = 'null'}) {
  final player = Player();
  final native = player.platform! as NativePlayer;
  // Configure before mpv selects tracks. Setting these after open races with
  // automatic audio/video selection and can leave an already idle playlist.
  native.onLoadHooks.add(() async {
    await native.setProperty('vo', 'null', waitForInitialization: false);
    await native.setProperty('ao', audioOutput, waitForInitialization: false);
    await native.setProperty('vid', 'auto', waitForInitialization: false);
  });
  return player;
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
