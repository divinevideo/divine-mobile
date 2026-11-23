import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:divine_video_player/src/audio_track.dart' as divine;
import 'package:divine_video_player/src/desktop/desktop_video_configuration.dart';
import 'package:divine_video_player/src/desktop/desktop_video_frame_ready.dart';
import 'package:divine_video_player/src/video_clip.dart';
import 'package:divine_video_player/src/video_player_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;
import 'package:unified_logger/unified_logger.dart';

/// Creates a Linux video backend implementation.
typedef LinuxVideoPlayerBackendFactory = LinuxVideoPlayerBackend Function();

/// Linux-specific playback backend used by the public controller.
abstract interface class LinuxVideoPlayerBackend {
  /// Initializes the backend and starts emitting state changes.
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  });

  /// Loads one or more clips into the backend player.
  Future<void> setClips(List<VideoClip> clips, {Duration? startPosition});

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback and unloads media.
  Future<void> stop();

  /// Seeks to a position on the global timeline.
  Future<void> seekTo(Duration position);

  /// Sets the player volume.
  Future<void> setVolume(double volume);

  /// Sets the playback speed multiplier.
  Future<void> setPlaybackSpeed(double speed);

  /// Enables or disables looping.
  Future<void> setLooping({required bool looping});

  /// Jumps to a clip index within the current timeline.
  Future<void> jumpToClip(int index);

  /// Replaces the active overlay audio tracks.
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks);

  /// Removes all overlay audio tracks.
  Future<void> removeAllAudioTracks();

  /// Sets the volume of a single overlay audio track.
  Future<void> setAudioTrackVolume(int index, double volume);

  /// Builds the platform-specific render widget.
  Widget buildView();

  /// Disposes the backend and releases native resources.
  Future<void> dispose();
}

/// Linux backend powered by `media_kit` and mpv.
class MediaKitLinuxVideoPlayerBackend implements LinuxVideoPlayerBackend {
  /// Creates a Linux backend instance.
  MediaKitLinuxVideoPlayerBackend({
    void Function()? mediaKitInitializer,
    Player Function()? playerFactory,
    Object Function(Player player)? videoControllerFactory,
    Future<void> Function(Object controller)? videoControllerReady,
    Widget Function(Object controller)? videoViewBuilder,
    Future<Duration> Function(String uri)? durationProbe,
  }) : _mediaKitInitializer = mediaKitInitializer ?? MediaKit.ensureInitialized,
       _playerFactory = playerFactory ?? Player.new,
       _videoControllerFactory =
           videoControllerFactory ?? _defaultVideoControllerFactory,
       _videoControllerReady =
           videoControllerReady ?? _defaultVideoControllerReady,
       _videoViewBuilder = videoViewBuilder ?? _defaultVideoViewBuilder,
       _durationProbe = durationProbe;

  // media_kit native initialization is process-global, so this latch must
  // survive hot restart. Tests reset it explicitly via the visible hook.
  static bool _mediaKitInitialized = false;

  final void Function() _mediaKitInitializer;
  final Player Function() _playerFactory;
  final Object Function(Player player) _videoControllerFactory;
  final Future<void> Function(Object controller) _videoControllerReady;
  final Widget Function(Object controller) _videoViewBuilder;
  final Future<Duration> Function(String uri)? _durationProbe;

  /// Resets the one-time media_kit initialization latch for tests.
  @visibleForTesting
  static void resetInitializationForTesting() {
    _mediaKitInitialized = false;
  }

  late Player _player;
  late Object _videoController;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _clips = <VideoClip>[];
  final _clipSpeeds = <double>[];
  final _clipDurations = <Duration>[];
  final _clipOffsets = <Duration>[];
  final _durationProbes = <_DurationProbe>{};

  void Function(DivineVideoPlayerState state)? _onStateChanged;
  void Function(Object error)? _onError;

  DivineVideoPlayerState _state = const DivineVideoPlayerState();
  bool _initialized = false;
  bool _disposed = false;
  bool _isLooping = false;
  // A successful property acknowledgement can precede mpv's state observation.
  // Preserve app volume requests across output replacement, including mute.
  double? _requestedVolume;
  double get _volume => _requestedVolume ?? _player.state.volume / 100;
  bool _hasLoadedMedia = false;
  bool _playerHasOpenedMedia = false;
  bool _ownsPlayer = false;
  bool _changingPlayer = false;
  bool _outputReady = false;
  bool _outputFailed = false;
  Object? _terminalError;
  int _loadGeneration = 0;
  // Only validated requests can supersede a native commit already in progress.
  int _acceptedLoadGeneration = 0;
  int? _activeLoadGeneration = 0;
  int? _reportedErrorGeneration;
  int _playerGeneration = 0;
  Future<void> _mutations = Future<void>.value();
  bool _didLogUnsupportedAudioTrackWarning = false;
  int _currentClipIndex = 0;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    _ensureMediaKitInitialized();
    _onStateChanged = onStateChanged;
    _onError = onError;
    _createPlayer();
    _initialized = true;
  }

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {
    _ensureReady();
    final generation = ++_loadGeneration;
    final nextClips = List<VideoClip>.of(clips);
    final nextSpeeds = nextClips.map((clip) => clip.playbackSpeed).toList();

    // _resolveClipDurations returns source-time durations.  Divide by the
    // per-clip speed so _clipDurations (and therefore _clipOffsets and
    // _totalDuration) are in wall-clock (playback) time, consistent with
    // the global timeline coordinate space.
    await _cancelDurationProbes();
    if (_disposed || generation != _loadGeneration) return;
    final List<Duration> sourceDurations;
    try {
      sourceDurations = await _resolveClipDurations(nextClips, generation);
    } on Object catch (error) {
      if (!_disposed &&
          generation == _loadGeneration &&
          !_hasLoadedMedia &&
          !_changingPlayer) {
        // Rejection must not replace a playable source or cancel a previously
        // validated native commit. Its caller still receives the rejection.
        _handleError(error);
      }
      rethrow;
    }
    if (_disposed || generation != _loadGeneration) return;
    final nextDurations = <Duration>[];
    final nextOffsets = <Duration>[];
    var offset = Duration.zero;
    for (var i = 0; i < sourceDurations.length; i++) {
      final duration = _sourceToPlayback(
        sourceDurations[i],
        speed: nextSpeeds[i],
      );
      nextDurations.add(duration);
      nextOffsets.add(offset);
      offset += duration;
    }
    _acceptedLoadGeneration = generation;
    await _enqueue(() async {
      if (generation != _acceptedLoadGeneration) return;
      if (_playerHasOpenedMedia || _outputFailed || _terminalError != null) {
        _changingPlayer = true;
        final volume = _volume;
        _activeLoadGeneration = null;
        _hasLoadedMedia = false;
        _clearTimeline();
        _emitState(
          const DivineVideoPlayerState().copyWith(
            status: PlaybackStatus.buffering,
            volume: volume,
          ),
        );
        await _retirePlayer();
        if (_disposed) {
          _changingPlayer = false;
          return;
        }
        _createPlayer();
        await _player.setVolume(volume * 100);
      }
      if (_disposed || generation != _acceptedLoadGeneration) {
        _changingPlayer = false;
        return;
      }
      // Player streams can emit during the duration probe. Publish one coherent
      // timeline only after all source durations and offsets are available.
      _clips
        ..clear()
        ..addAll(nextClips);
      _clipSpeeds
        ..clear()
        ..addAll(nextSpeeds);
      _clipDurations
        ..clear()
        ..addAll(nextDurations);
      _clipOffsets
        ..clear()
        ..addAll(nextOffsets);

      final playlist = Playlist([
        for (final clip in nextClips)
          Media(clip.uri, start: clip.start, end: clip.end),
      ]);

      _hasLoadedMedia = true;
      _playerHasOpenedMedia = true;
      _activeLoadGeneration = generation;
      _currentClipIndex = 0;
      _changingPlayer = false;
      _emitState(
        _state.copyWith(
          status: PlaybackStatus.buffering,
          clipCount: nextClips.length,
          currentClipIndex: 0,
          duration: _totalDuration,
          position: Duration.zero,
          bufferedPosition: Duration.zero,
          isFirstFrameRendered: false,
          clearError: true,
        ),
      );

      await _player.open(playlist, play: false);
      if (_disposed || generation != _acceptedLoadGeneration) return;
      await _player.setPlaylistMode(
        _isLooping ? PlaylistMode.loop : PlaylistMode.none,
      );
      // Apply first-clip speed immediately so playback starts at the correct
      // rate.
      await _player.setRate(_clipSpeeds.firstOrNull ?? 1.0);

      final seekPosition = startPosition ?? Duration.zero;
      if (seekPosition > Duration.zero) {
        await _seekTo(seekPosition);
      } else {
        _refreshState();
      }
      _reportOutputReady();
    });
  }

  @override
  Future<void> play() async {
    _ensureReady();
    await _enqueue(() async {
      await _player.play();
      _refreshState();
    });
  }

  @override
  Future<void> pause() async {
    _ensureReady();
    await _enqueue(() async {
      await _player.pause();
      _refreshState();
    });
  }

  @override
  Future<void> stop() async {
    _ensureReady();
    _acceptedLoadGeneration = ++_loadGeneration;
    _activeLoadGeneration = null;
    final cancellingProbes = _cancelDurationProbes();
    await _enqueue(() async {
      await cancellingProbes;
      await _player.stop();
      _terminalError = null;
      _hasLoadedMedia = false;
      _clearTimeline();
      _emitState(const DivineVideoPlayerState().copyWith(volume: _volume));
    });
  }

  @override
  Future<void> seekTo(Duration position) async {
    _ensureReady();
    await _enqueue(() => _seekTo(position));
  }

  Future<void> _seekTo(Duration position) async {
    if (_clips.isEmpty) return;

    final clamped = _clampGlobalPosition(position);
    final targetIndex = _clipIndexForPosition(clamped);
    final clipOffset = _clipOffsets[targetIndex];
    final clip = _clips[targetIndex];
    // _clipOffsets are in playback time; subtract to get a playback-time
    // local offset, then multiply by speed to recover the source-time
    // position that mpv expects.
    final localOffset = clamped - clipOffset;
    final speed = _clipSpeeds.elementAtOrNull(targetIndex) ?? 1.0;
    final sourcePosition =
        clip.start + _playbackToSource(localOffset, speed: speed);

    if (_currentClipIndex != targetIndex) {
      await _player.jump(targetIndex);
    }
    await _player.seek(sourcePosition);
    _refreshState();
  }

  @override
  Future<void> setVolume(double volume) async {
    _ensureReady();
    await _enqueue(() async {
      await _player.setVolume(volume * 100);
      _requestedVolume = volume;
      _emitState(_state.copyWith(volume: volume));
    });
  }

  /// Sets the runtime player rate.
  ///
  /// This only changes the mpv player rate. It deliberately does **not**
  /// mutate the cached per-clip authored speeds (`_clipSpeeds`) used for the
  /// playback-time <-> source-time mapping, so duration math, seek offsets,
  /// and the global timeline coordinate space remain consistent with what
  /// was supplied via [setClips].
  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _ensureReady();
    await _enqueue(() async {
      await _player.setRate(speed);
      _emitState(_state.copyWith(playbackSpeed: speed));
    });
  }

  @override
  Future<void> setLooping({required bool looping}) async {
    _ensureReady();
    _isLooping = looping;
    await _enqueue(() async {
      await _player.setPlaylistMode(
        looping ? PlaylistMode.loop : PlaylistMode.none,
      );
      _emitState(_state.copyWith(isLooping: looping));
    });
  }

  @override
  Future<void> jumpToClip(int index) async {
    _ensureReady();
    await _enqueue(() async {
      if (index < 0 || index >= _clips.length) return;
      await _player.jump(index);
      await _player.seek(_clips[index].start);
      _refreshState();
    });
  }

  @override
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks) async {
    if (tracks.isEmpty) return;
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Future<void> removeAllAudioTracks() async {
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async {
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Widget buildView() {
    _ensureReady();
    return KeyedSubtree(
      key: ObjectKey(_videoController),
      child: _videoViewBuilder(_videoController),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _acceptedLoadGeneration = ++_loadGeneration;
    await _cancelDurationProbes();
    await _mutations;
    await _retirePlayer();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _mutations.then((_) async {
      if (_disposed) return;
      await action();
    });
    _mutations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        // The caller owns the failure; later player operations still run.
      },
    );
    return operation;
  }

  void _createPlayer() {
    _player = _playerFactory();
    _ownsPlayer = true;
    _videoController = _videoControllerFactory(_player);
    // media_kit initializes the native output in a post-frame callback, but
    // does not request that frame. Native commands can await that callback.
    WidgetsBinding.instance.ensureVisualUpdate();
    _playerHasOpenedMedia = false;
    _outputReady = false;
    _outputFailed = false;
    _terminalError = null;
    _reportedErrorGeneration = null;
    final generation = ++_playerGeneration;
    _listenToPlayer();
    unawaited(
      _videoControllerReady(_videoController).then<void>(
        (_) {
          if (_disposed || generation != _playerGeneration) return;
          _outputReady = true;
          _reportOutputReady();
        },
        onError: (Object error) {
          if (_disposed || generation != _playerGeneration) return;
          _outputFailed = true;
          _terminalError = error;
          _reportOutputReady();
        },
      ),
    );
  }

  void _reportOutputReady() {
    if (_disposed || _changingPlayer || _activeLoadGeneration == null) {
      return;
    }
    if (_terminalError case final error?) {
      if (_reportedErrorGeneration != _activeLoadGeneration) {
        _reportedErrorGeneration = _activeLoadGeneration;
        _handleError(error);
      }
    } else if (_outputReady && !_state.isFirstFrameRendered) {
      _emitState(_state.copyWith(isFirstFrameRendered: true));
    }
  }

  Future<void> _retirePlayer() async {
    if (!_ownsPlayer) return;
    _ownsPlayer = false;
    _playerGeneration++;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
  }

  void _listenToPlayer() {
    final player = _player;
    final generation = _playerGeneration;
    bool isCurrent() => !_disposed && generation == _playerGeneration;
    void refresh(Object? _) {
      if (isCurrent()) _refreshState();
    }

    void report(Object error) {
      if (isCurrent() && _activeLoadGeneration != null) {
        if (_isAudioOutputUnavailable(error)) {
          Log.warning(
            'Desktop audio output is unavailable; video playback continues.',
            name: 'divine_video_player',
            category: LogCategory.video,
          );
          return;
        }
        _handleError(error);
      }
    }

    _subscriptions.addAll([
      player.stream.playing.listen(refresh, onError: report),
      player.stream.position.listen(refresh, onError: report),
      player.stream.duration.listen(refresh, onError: report),
      player.stream.buffer.listen(refresh, onError: report),
      player.stream.buffering.listen(refresh, onError: report),
      player.stream.playlist.listen((playlist) async {
        if (!isCurrent() || _changingPlayer) return;
        try {
          _currentClipIndex = playlist.index.clamp(
            0,
            math.max(_clips.length - 1, 0),
          );
          // Only re-apply per-clip rate on transitions when any clip was
          // authored with a non-default speed. Otherwise leave the player rate
          // alone so an explicit [setPlaybackSpeed] override persists across
          // implicit playlist events.
          final hasAuthoredSpeed = _clipSpeeds.any((s) => s != 1.0);
          if (hasAuthoredSpeed) {
            final clipSpeed =
                _clipSpeeds.elementAtOrNull(_currentClipIndex) ?? 1.0;
            await player.setRate(clipSpeed);
          }
          refresh(null);
        } on Object catch (error) {
          report(error);
        }
      }, onError: report),
      player.stream.completed.listen(refresh, onError: report),
      player.stream.volume.listen(refresh, onError: report),
      player.stream.rate.listen(refresh, onError: report),
      player.stream.width.listen(refresh, onError: report),
      player.stream.height.listen(refresh, onError: report),
      player.stream.error.listen(report, onError: report),
    ]);
  }

  Future<List<Duration>> _resolveClipDurations(
    List<VideoClip> clips,
    int generation,
  ) async {
    final durations = <Duration>[];
    for (final clip in clips) {
      if (_disposed || generation != _loadGeneration) return [];
      if (clip.end != null) {
        if (clip.end! < clip.start) {
          throw ArgumentError.value(
            clip.end,
            'clip.end',
            'must be greater than or equal to clip.start',
          );
        }
        durations.add(clip.end! - clip.start);
        continue;
      }

      final Duration sourceDuration;
      try {
        sourceDuration = await (_durationProbe ?? _probeDuration)(clip.uri);
      } on Object {
        // A retired lookup does not own the current source's error state.
        if (_disposed || generation != _loadGeneration) return [];
        rethrow;
      }
      if (_disposed || generation != _loadGeneration) return [];
      if (clip.start > sourceDuration) {
        throw ArgumentError.value(
          clip.start,
          'clip.start',
          'must be less than or equal to the source duration',
        );
      }
      durations.add(sourceDuration - clip.start);
    }
    return durations;
  }

  Future<Duration> _probeDuration(String uri) async {
    final probe = _DurationProbe(_playerFactory());
    _durationProbes.add(probe);
    try {
      return await probe.run(uri);
    } finally {
      await probe.close();
      _durationProbes.remove(probe);
    }
  }

  Future<void> _cancelDurationProbes() async {
    final probes = _durationProbes.toList();
    await Future.wait(probes.map((probe) => probe.close(cancel: true)));
    _durationProbes.removeAll(probes);
  }

  // coverage:ignore-start
  // Default seams that bind to real media_kit native objects. They cannot
  // run in a headless unit test (no native media_kit backend), which is why
  // they are injectable — tests substitute fakes via the constructor.
  //
  // Environment escape hatch: setting `DIVINE_LINUX_NO_VIDEO_OUTPUT=1` skips
  // VideoController construction entirely. mpv's GL render-context setup
  // segfaults natively on virtual GPUs (QEMU virtio-gpu, some headless CI
  // runners) the moment it touches Flutter's EGL config — a native crash that
  // cannot be caught from Dart. With the flag set, audio still plays via the
  // mpv `Player`, and `buildView()` returns an empty placeholder so the
  // thumbnail behind it stays visible.
  static const _disableVideoOutputEnvVar = 'DIVINE_LINUX_NO_VIDEO_OUTPUT';

  static bool get _videoOutputDisabled {
    final value = Platform.environment[_disableVideoOutputEnvVar];
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  static Object _defaultVideoControllerFactory(Player player) {
    if (_videoOutputDisabled) {
      Log.warning(
        'DIVINE_LINUX_NO_VIDEO_OUTPUT is set — skipping VideoController. '
        'Audio will play but video frames will not render.',
        name: 'divine_video_player',
        category: LogCategory.video,
      );
      return const _DisabledVideoController();
    }
    // Keep Linux's virtual-GPU workaround without forcing Windows onto its
    // size-limited software output.
    return media_kit.VideoController(
      player,
      configuration: desktopVideoConfiguration(defaultTargetPlatform),
    );
  }

  static Future<void> _defaultVideoControllerReady(Object controller) {
    if (controller is _DisabledVideoController) {
      // Audio-only diagnostic output never produces a visual frame.
      return Completer<void>().future;
    }
    final video = controller as media_kit.VideoController;
    final disposed = Completer<void>();
    video.player.platform?.release.add(() async {
      disposed.complete();
    });
    return waitForDesktopVideoFrame(
      firstFrame: video.waitUntilFirstFrameRendered,
      rect: video.rect,
      disposed: disposed.future,
    );
  }

  static Widget _defaultVideoViewBuilder(Object controller) {
    if (controller is _DisabledVideoController) {
      return const SizedBox.expand();
    }
    return media_kit.Video(
      controller: controller as media_kit.VideoController,
      controls: null,
    );
  }
  // coverage:ignore-end

  /// Converts a source-time [Duration] to wall-clock (playback) time by
  /// dividing by [speed].  Returns [source] unchanged when [speed] is 1.0.
  Duration _sourceToPlayback(Duration source, {required double speed}) {
    if (speed == 1.0) return source;
    return Duration(
      microseconds: (source.inMicroseconds / speed).round(),
    );
  }

  /// Converts a playback-time [Duration] to source time by multiplying by
  /// [speed].  Returns [playback] unchanged when [speed] is 1.0.
  Duration _playbackToSource(Duration playback, {required double speed}) {
    if (speed == 1.0) return playback;
    return Duration(
      microseconds: (playback.inMicroseconds * speed).round(),
    );
  }

  Duration get _totalDuration =>
      _clipDurations.fold(Duration.zero, (a, b) => a + b);

  Duration _clampGlobalPosition(Duration position) {
    if (_clipDurations.isEmpty) return Duration.zero;
    if (position <= Duration.zero) return Duration.zero;
    if (position >= _totalDuration) return _totalDuration;
    return position;
  }

  int _clipIndexForPosition(Duration position) {
    for (var i = 0; i < _clipOffsets.length; i++) {
      final start = _clipOffsets[i];
      final end = start + _clipDurations[i];
      if (position < end || i == _clipOffsets.length - 1) {
        return i;
      }
    }
    return 0;
  }

  void _refreshState() {
    if (!_initialized || _disposed || _changingPlayer) return;
    if (_terminalError != null) {
      _reportOutputReady();
      return;
    }

    final playerState = _player.state;
    final hasClips = _clips.isNotEmpty;
    final currentIndex = hasClips
        ? _currentClipIndex.clamp(0, _clips.length - 1)
        : 0;
    final currentClip = hasClips ? _clips[currentIndex] : null;
    final currentOffset = hasClips ? _clipOffsets[currentIndex] : Duration.zero;
    final currentDuration = hasClips
        ? _clipDurations[currentIndex]
        : Duration.zero;
    // _clipDurations are in playback time.  mpv reports positions in source
    // time, so recover the source duration for clamping, then divide by
    // speed to convert the local offset back to playback time before adding
    // to the playback-time currentOffset.
    final speed = hasClips
        ? (_clipSpeeds.elementAtOrNull(currentIndex) ?? 1.0)
        : 1.0;
    final sourceDuration = _playbackToSource(currentDuration, speed: speed);

    final localPosition = currentClip == null
        ? Duration.zero
        : _sourceToPlayback(
            _clampDuration(
              playerState.position - currentClip.start,
              max: sourceDuration,
            ),
            speed: speed,
          );
    final localBuffer = currentClip == null
        ? Duration.zero
        : _sourceToPlayback(
            _clampDuration(
              playerState.buffer - currentClip.start,
              max: sourceDuration,
            ),
            speed: speed,
          );

    final status = switch ((
      hasClips,
      playerState.completed,
      playerState.buffering,
      playerState.playing,
    )) {
      (false, _, _, _) => PlaybackStatus.idle,
      (_, true, _, _) when !_isLooping => PlaybackStatus.completed,
      (_, _, true, _) => PlaybackStatus.buffering,
      (_, _, _, true) => PlaybackStatus.playing,
      _ when _hasLoadedMedia => PlaybackStatus.ready,
      _ => PlaybackStatus.idle,
    };

    _emitState(
      _state.copyWith(
        status: status,
        position: currentOffset + localPosition,
        duration: _totalDuration,
        bufferedPosition: currentOffset + localBuffer,
        currentClipIndex: currentIndex,
        clipCount: _clips.length,
        isLooping: _isLooping,
        volume: _volume,
        playbackSpeed: playerState.rate,
        videoWidth: playerState.width ?? 0,
        videoHeight: playerState.height ?? 0,
        clearError: status != PlaybackStatus.error,
      ),
    );
  }

  Duration _clampDuration(Duration value, {required Duration max}) {
    if (value <= Duration.zero) return Duration.zero;
    if (value >= max) return max;
    return value;
  }

  void _clearTimeline() {
    _clips.clear();
    _clipSpeeds.clear();
    _clipDurations.clear();
    _clipOffsets.clear();
    _currentClipIndex = 0;
  }

  void _emitState(DivineVideoPlayerState newState) {
    if (_disposed) return;
    _state = newState;
    _onStateChanged?.call(newState);
  }

  void _handleError(Object error) {
    if (_disposed) return;
    _terminalError = error;
    _reportedErrorGeneration = _activeLoadGeneration;
    _emitState(
      _state.copyWith(status: PlaybackStatus.error, errorMessage: '$error'),
    );
    _onError?.call(error);
  }

  void _logUnsupportedAudioTrackOperation() {
    if (_didLogUnsupportedAudioTrackWarning) return;
    _didLogUnsupportedAudioTrackWarning = true;
    Log.warning(
      'Overlay audio tracks are not supported on the Linux backend yet.',
      name: 'divine_video_player',
      category: LogCategory.video,
    );
  }

  void _ensureMediaKitInitialized() {
    if (_mediaKitInitialized) return;
    _mediaKitInitializer();
    _mediaKitInitialized = true;
  }

  void _ensureReady() {
    if (!_initialized) {
      throw StateError('Linux backend is not initialized.');
    }
    if (_disposed) {
      throw StateError('Linux backend has been disposed.');
    }
  }
}

/// Sentinel marker used in place of a real `VideoController` when video
/// output is disabled via `DIVINE_LINUX_NO_VIDEO_OUTPUT`. Lets the rest of
/// the backend stay non-nullable while skipping native GL setup.
class _DisabledVideoController {
  const _DisabledVideoController();
}

// mpv continues decoding video after this specific cplayer diagnostic. Keep
// genuine decoder/source failures terminal instead of clearing every SDK error.
bool _isAudioOutputUnavailable(Object error) =>
    error is String &&
    error.trim() == 'Could not open/initialize audio device -> no sound.';

/// Owns a temporary player and cancels unfinished duration reads.
class _DurationProbe {
  _DurationProbe(this.player);

  final Player player;
  final _duration = Completer<Duration>();
  final _cancelled = Completer<void>();
  StreamSubscription<Duration>? _subscription;
  StreamSubscription<String>? _errors;
  Timer? _timeout;
  Future<void>? _closing;

  Future<Duration> run(String uri) async {
    void receive(Duration value) {
      if (value > Duration.zero && !_duration.isCompleted) {
        _duration.complete(value);
      }
    }

    void fail(Object error, StackTrace stackTrace) {
      if (!_duration.isCompleted) _duration.completeError(error, stackTrace);
    }

    _subscription = player.stream.duration.listen(receive, onError: fail);
    _errors = player.stream.error.listen(
      (message) {
        if (!_isAudioOutputUnavailable(message)) {
          fail(StateError(message), StackTrace.current);
        }
      },
      onError: fail,
    );
    _timeout = Timer(const Duration(seconds: 10), () {
      fail(
        TimeoutException('Could not probe duration for $uri'),
        StackTrace.current,
      );
    });
    final opening = Future<void>.sync(
      () => player.open(Media(uri), play: false),
    ).then<void>((_) => receive(player.state.duration));
    await Future.wait<void>([
      Future.any<void>([opening, _cancelled.future]),
      _duration.future.then<void>((_) {}),
    ], eagerError: true);
    return _duration.future;
  }

  Future<void> close({bool cancel = false}) {
    if (cancel && !_cancelled.isCompleted) {
      _cancelled.complete();
      if (!_duration.isCompleted) _duration.complete(Duration.zero);
    }
    return _closing ??= () async {
      _timeout?.cancel();
      await _subscription?.cancel();
      await _errors?.cancel();
      await player.dispose();
    }();
  }
}
