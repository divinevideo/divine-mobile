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

  group(MediaKitLinuxVideoPlayerBackend, () {
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

    test('initialize wires first-frame callback and buildView', () async {
      final fakeVideoController = _FakeVideoController();
      final emittedStates = <DivineVideoPlayerState>[];
      final backend = MediaKitLinuxVideoPlayerBackend(
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

      expect(backend.buildView(), isA<Text>());

      fakeVideoController.ready.complete();
      await Future<void>.delayed(Duration.zero);

      expect(emittedStates.last.isFirstFrameRendered, isTrue);
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
      fakeAsync((async) {
        unawaited(
          backend
              .setClips([const VideoClip(uri: 'file:///clip.mp4')])
              .catchError((Object caughtError) => error = caughtError),
        );

        async
          ..elapse(const Duration(seconds: 11))
          ..flushMicrotasks();
      });

      expect(error, isA<TimeoutException>());
      expect(probePlayer.lastOpenedMedia?.uri, endsWith('clip.mp4'));
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

class _FakeVideoController {
  final ready = Completer<void>();
}

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer({this.probeDuration, this.emitErrorOnDispose = false})
    : super(configuration: const PlayerConfiguration());

  final Duration? probeDuration;
  final bool emitErrorOnDispose;

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

  @override
  Future<void> dispose() async {
    disposeCalls++;
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
      if (probeDuration != null) {
        state = state.copyWith(duration: probeDuration);
        unawaited(
          Future<void>.delayed(
            Duration.zero,
            () => durationController.add(probeDuration!),
          ),
        );
      }
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
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
    setRateCalls++;
    lastRate = rate;
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    state = const PlayerState();
    positionController.add(Duration.zero);
  }
}

extension on int {
  Duration get seconds => Duration(seconds: this);
}

void _noop() {}
