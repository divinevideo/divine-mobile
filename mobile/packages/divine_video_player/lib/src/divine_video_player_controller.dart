import 'dart:async';

import 'package:divine_video_player/src/audio_track.dart';
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:divine_video_player/src/video_buffer_profile.dart';
import 'package:divine_video_player/src/video_clip.dart';
import 'package:divine_video_player/src/video_player_state.dart';
import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:unified_logger/unified_logger.dart';

/// Default maximum size of the Android player's disk cache (500 MB).
///
/// The cache lives at `<cacheDir>/divine_video_cache`, see
/// [kNativeVideoCacheDirectoryName].
const int kDefaultCacheMaxSizeBytes = 500 * 1024 * 1024;

/// Directory under the platform cache directory that holds the Android
/// player's own disk cache (ExoPlayer's `SimpleCache`).
///
/// Nothing is written there on other platforms. The app's storage screen
/// counts and clears the directory by this name, so it is part of the
/// package's contract with `VideoCache.kt`.
const String kNativeVideoCacheDirectoryName = 'divine_video_cache';

/// Logger name for the Dart half of the player.
///
/// Native diagnostics arrive under their own `DivineVideoPlayer.*` names, so
/// this one marks the lines that come from a Dart-side call.
const _logName = 'DivineVideoPlayerController';

/// Controls a native multi-clip video player that treats multiple clips
/// as a single continuous timeline.
///
/// Usage:
/// ```dart
/// final controller = DivineVideoPlayerController();
/// await controller.initialize();
/// await controller.setSource(VideoClip(uri: '/path/to/video.mp4'));
/// await controller.play();
/// // ...
/// await controller.dispose();
/// ```
class DivineVideoPlayerController {
  /// Creates a controller. Call [initialize] before using playback methods.
  ///
  /// When [useTexture] is `true` the native side renders frames into a
  /// Flutter texture instead of a platform view. This allows Flutter
  /// widgets like `ColorFiltered` to affect the video pixels — required
  /// on iOS/macOS where `UiKitView`/`AppKitView` are composited as
  /// separate `CALayer`s that bypass Flutter's rendering pipeline.
  /// Defaults to `false` (platform view).
  ///
  /// When [useLegacySurface] is `true` AND [useTexture] is `true`, the
  /// Android side allocates a legacy `SurfaceTextureEntry` instead of
  /// the default `SurfaceProducer`. The legacy backend has no
  /// surface-recreate callback (so it can't transparently survive
  /// permission dialogs / OEM compositor events), but it has no shared
  /// `ImageReader` buffer pool either — which makes it immune to the
  /// 1-frame ghost frame that surfaces when many `SurfaceProducer`-backed
  /// players coexist and a sibling decoder is released (the feed flicker).
  /// Use it for screens that render many players at once. No effect on
  /// iOS/macOS. Defaults to `false`.
  ///
  /// [bufferProfile] caps how much media each native player buffers into
  /// memory. Defaults to [VideoBufferProfile.full] (platform defaults);
  /// short-form many-player surfaces like the feed should pass
  /// [VideoBufferProfile.feed] to bound per-player heap use. Only Android
  /// acts on it today. See [VideoBufferProfile].
  ///
  /// [exclusivePlayback] opts this controller into the app-wide rule that
  /// only one video plays at a time. Defaults to `true`, which is right for
  /// anything the user perceives as *a* video — a feed item, a preview, a
  /// full-screen player. Pass `false` only for a companion player that is
  /// part of another player's picture rather than a video of its own, such as
  /// the chroma-key backdrop composited behind a keyed clip. See
  /// [_pauseOtherLiveControllers].
  ///
  /// [debugLabel] names the surface that owns this player in diagnostic logs.
  /// Player IDs are wall-clock seeded and identical on both sides of the
  /// channel, so a `Player 665404` line in a bug report is only traceable
  /// back to a screen if that screen labelled itself here. The label is
  /// forwarded to the native player, so its lines carry it too.
  DivineVideoPlayerController({
    this.useTexture = false,
    this.useLegacySurface = false,
    this.bufferProfile = VideoBufferProfile.full,
    this.exclusivePlayback = true,
    this.debugLabel,
  }) {
    _ensureNativeLogHandler();
  }

  /// Guards one-time installation of the global-channel handler that
  /// receives native diagnostics (`onNativeLog`).
  static bool _nativeLogHandlerInstalled = false;

  /// Installs the handler that receives curated native diagnostics from the
  /// platform side and forwards them into the app's [UnifiedLogger], so video
  /// playback problems show up in bug reports. Idempotent.
  static void _ensureNativeLogHandler() {
    if (_nativeLogHandlerInstalled) return;
    _nativeLogHandlerInstalled = true;
    _globalChannel.setMethodCallHandler(_handleGlobalChannelCall);
  }

  static Future<dynamic> _handleGlobalChannelCall(MethodCall call) async {
    if (call.method == 'onNativeLog') {
      final args = call.arguments;
      if (args is Map) {
        _forwardNativeLog(args);
      }
    }
    return null;
  }

  /// Forwards a curated native diagnostic into the app's [UnifiedLogger].
  ///
  /// The native side only sends events worth surfacing for diagnosing
  /// playback problems (player lifecycle, clip-composition skips, asset /
  /// playback errors, audio-track setup) — see `DivineVideoPlayerLog` on each
  /// platform. Per-frame and verbose native logs stay on the device console.
  static void _forwardNativeLog(Map<dynamic, dynamic> args) {
    final message = args['message'] as String?;
    if (message == null || message.isEmpty) return;
    final level = args['level'] as String? ?? 'info';
    final name = args['name'] as String? ?? 'DivineVideoPlayerNative';
    switch (level) {
      case 'error':
        Log.error(message, name: name, category: LogCategory.video);
      case 'warning':
        Log.warning(message, name: name, category: LogCategory.video);
      case 'debug':
        Log.debug(message, name: name, category: LogCategory.video);
      case 'verbose':
        Log.verbose(message, name: name, category: LogCategory.video);
      case 'info':
      default:
        Log.info(message, name: name, category: LogCategory.video);
    }
  }

  /// Whether this player renders via a Flutter texture instead of a
  /// platform view. When `true` the widget should use the [Texture]
  /// widget with [textureId].
  final bool useTexture;

  /// Whether to use the legacy Android `SurfaceTextureEntry` backend
  /// instead of `SurfaceProducer`. See the constructor docs.
  final bool useLegacySurface;

  /// How aggressively the native player buffers media into memory.
  /// See the constructor docs and [VideoBufferProfile].
  final VideoBufferProfile bufferProfile;

  /// Whether this player takes part in the one-video-at-a-time rule.
  /// See the constructor docs and [_pauseOtherLiveControllers].
  final bool exclusivePlayback;

  /// Names the surface that owns this player in diagnostic logs.
  ///
  /// See the constructor docs. `null` when the owner did not label itself,
  /// which leaves both halves logging a bare `Player <id>`.
  final String? debugLabel;

  static const _globalChannel = MethodChannel('divine_video_player');

  /// Factory used to create the Linux backend implementation.
  @visibleForTesting
  static LinuxVideoPlayerBackendFactory linuxBackendFactory =
      MediaKitLinuxVideoPlayerBackend.new;

  /// Factory used to create the [WebVideoPlayerBackend] instance.
  ///
  /// The default factory ([createDefaultWebVideoPlayerBackend]) returns an
  /// `HtmlVideoElementBackend` on real web builds. On every other target it
  /// returns a stub that throws — the controller never reaches the factory
  /// when `kIsWeb` is `false`, so this is safe in production.
  ///
  /// **Test usage:** The default factory cannot be used in unit tests because
  /// `HtmlVideoElementBackend` requires a live `HTMLVideoElement` in the
  /// browser DOM — which does not exist in the Dart VM (`flutter test`).
  /// Replace this factory with a fake before calling [initialize], and
  /// combine it with [debugForceWebBackend] to actually activate the web
  /// code path:
  ///
  /// ```dart
  /// setUp(() {
  ///   DivineVideoPlayerController.debugForceWebBackend = true;
  ///   DivineVideoPlayerController.webBackendFactory =
  ///       () => FakeWebVideoPlayerBackend();
  /// });
  ///
  /// tearDown(() {
  ///   DivineVideoPlayerController.debugForceWebBackend = null;
  ///   DivineVideoPlayerController.webBackendFactory =
  ///       createDefaultWebVideoPlayerBackend;
  /// });
  /// ```
  ///
  /// Without both this override and [debugForceWebBackend], the entire web
  /// code path inside the controller is unreachable from unit tests.
  @visibleForTesting
  static WebVideoPlayerBackendFactory webBackendFactory =
      createDefaultWebVideoPlayerBackend;

  /// Test hook that forces Linux backend selection regardless of platform.
  @visibleForTesting
  static bool? debugForceLinuxBackend;

  /// Test hook that forces web backend selection regardless of platform.
  ///
  /// Normally the controller selects the web backend only when `kIsWeb` is
  /// `true`. Because `kIsWeb` is always `false` in the Dart VM (including
  /// all `flutter test` runs), the web code path is unreachable without this
  /// hook.
  ///
  /// Set to `true` before calling [initialize] to force the controller into
  /// the web code path. This **must** be combined with a [webBackendFactory]
  /// override that returns a fake — the default factory creates an
  /// `HtmlVideoElementBackend` that requires a real browser DOM and will
  /// throw in a headless test environment.
  ///
  /// Reset to `null` in `tearDown` to avoid leaking state across tests.
  @visibleForTesting
  static bool? debugForceWebBackend;

  /// Seeded from the current time so that IDs are unique across hot
  /// restarts. Without this, Dart's static reset would reuse id 0
  /// while the native side still holds a zombie player with that ID.
  ///
  /// The modulo keeps the value within int32 range because platform
  /// channels transmit integers as 32-bit on the native side.
  static int _nextId = DateTime.now().microsecondsSinceEpoch % 1000000;

  /// The next player ID that will be assigned by [initialize].
  ///
  /// Exposed so tests can set up mock channels before calling
  /// [initialize].
  @visibleForTesting
  static int get nextId => _nextId;

  /// Resets the player ID counter to 0.
  ///
  /// Call in test `setUp` to make IDs deterministic regardless of
  /// test ordering.
  @visibleForTesting
  static void resetIdCounterForTesting() {
    _nextId = 0;
    _liveControllers.clear();
  }

  static final Set<DivineVideoPlayerController> _liveControllers =
      <DivineVideoPlayerController>{};

  /// Number of controllers that have been initialized and not yet disposed.
  ///
  /// Exposed as an always-on gauge for memory instrumentation; each live
  /// controller holds a native player and its buffers.
  static int get liveControllerCount => _liveControllers.length;

  /// Disposes all native player instances that may still be alive.
  ///
  /// Call at app startup to clean up zombie players from a previous
  /// Dart VM (e.g. after hot restart). The native plugin keeps its
  /// process-level state across hot restarts, so old ExoPlayer /
  /// AVPlayer instances and their timers survive unless explicitly
  /// released.
  ///
  /// No-op on web and Linux where no native channel is registered.
  static Future<void> disposeAll() {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) {
      return Future.value();
    }
    return _globalChannel.invokeMethod<void>('disposeAll');
  }

  /// Configures the Android player's disk cache.
  ///
  /// Call once at app startup before creating any controllers. On Android
  /// this sets up ExoPlayer's disk-backed `SimpleCache`, which fills
  /// progressively while an HTTP(S) source streams and serves later reads
  /// of the same URL from disk. Local sources (`VideoClip.file`, or any
  /// non-HTTP URI) are played directly and never copied into it.
  ///
  /// A no-op everywhere else. AVFoundation loads media through its own
  /// stack and never reads `URLCache`, so there is nothing to configure on
  /// iOS or macOS; web and Linux have no native plugin.
  ///
  /// [maxSizeBytes] is the maximum cache size on disk. Defaults to
  /// [kDefaultCacheMaxSizeBytes] (500 MB). Least-recently-used entries
  /// are evicted automatically when the cache is full.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await DivineVideoPlayerController.configureCache();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> configureCache({
    int maxSizeBytes = kDefaultCacheMaxSizeBytes,
  }) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future.value();
    }
    return _globalChannel.invokeMethod<void>('configureCache', {
      'maxSizeBytes': maxSizeBytes,
    });
  }

  /// Pre-loads video metadata, and on Android the initial buffer of an
  /// HTTP(S) source into the disk cache, without creating a player instance.
  ///
  /// Call this for upcoming videos (e.g. the next item in a feed) so
  /// that playback starts instantly when the user reaches them.
  /// No controller needs to be alive — the work happens on the native
  /// side. On iOS and macOS this only makes a best-effort metadata request;
  /// nothing is retained by this plugin or written to disk there.
  ///
  /// ```dart
  /// await DivineVideoPlayerController.preload([
  ///   VideoClip.network('https://example.com/next.mp4'),
  /// ]);
  /// ```
  static Future<void> preload(List<VideoClip> clips) {
    return _globalChannel.invokeMethod<void>('preload', {
      'clips': clips.map((c) => c.toMap()).toList(),
    });
  }

  late final int _playerId;
  late final MethodChannel _methodChannel;
  late final EventChannel _eventChannel;
  LinuxVideoPlayerBackend? _linuxBackend;
  WebVideoPlayerBackend? _webBackend;

  final _stateController = StreamController<DivineVideoPlayerState>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;

  var _state = const DivineVideoPlayerState();
  var _initialized = false;
  var _disposed = false;
  var _isLinuxBackend = false;
  var _isWebBackend = false;
  var _firstFrameCompleter = Completer<bool>();

  /// The texture ID returned by the native side when [useTexture] is
  /// `true`. `null` when using platform views.
  int? _textureId;

  /// The texture ID for use with the [Texture] widget.
  ///
  /// Only non-null after [initialize] completes when [useTexture] is
  /// `true`.
  int? get textureId => _textureId;

  /// Whether this controller instance is backed by the Linux Dart backend.
  bool get usesLinuxBackend => _isLinuxBackend;

  /// Whether this controller instance is backed by the web HTML backend.
  bool get usesWebBackend => _isWebBackend;

  /// The current player state.
  DivineVideoPlayerState get state => _state;

  /// Stream of player state updates.
  ///
  /// Emits whenever position, status, or clip index changes.
  Stream<DivineVideoPlayerState> get stateStream => _stateController.stream;

  /// Completes when the first video frame has been rendered to the
  /// native surface.
  ///
  /// Resets each time [setClips] or [setSource] loads new media.
  /// Safe to await multiple times — a completed future stays completed
  /// until the next source change.
  Future<bool> get firstFrameRendered => _firstFrameCompleter.future;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// The platform view type identifier used to render this player's video.
  String get viewType => 'divine_video_player_view';

  /// The player ID passed to the native platform view as a creation parameter.
  int get playerId => _playerId;

  /// Creates the native player instance. Must be called before any
  /// other method.
  ///
  /// Throws [StateError] if called more than once.
  Future<void> initialize() async {
    if (_initialized) {
      throw StateError('Controller is already initialized.');
    }

    _playerId = _nextId++;
    _isWebBackend = debugForceWebBackend ?? kIsWeb;
    _isLinuxBackend =
        !_isWebBackend && (debugForceLinuxBackend ?? _usesLinuxBackend);
    if (_isWebBackend) {
      _webBackend = webBackendFactory();
      await _webBackend!.initialize(
        onStateChanged: _handleWebState,
        onError: _handleEventError,
      );
    } else if (_isLinuxBackend) {
      _linuxBackend = linuxBackendFactory();
      await _linuxBackend!.initialize(
        onStateChanged: _handleLinuxState,
        onError: _handleEventError,
      );
    } else {
      _methodChannel = MethodChannel('divine_video_player/player_$_playerId');
      _eventChannel = EventChannel(
        'divine_video_player/player_$_playerId/events',
      );

      final result = await _globalChannel.invokeMethod<Map<Object?, Object?>>(
        'create',
        {
          'id': _playerId,
          'useTexture': useTexture,
          'useLegacySurface': useLegacySurface,
          'bufferProfile': bufferProfile.wireValue,
          'debugLabel': debugLabel,
        },
      );
      if (useTexture && result != null) {
        _textureId = result['textureId'] as int?;
      }

      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: _handleEventError,
      );
    }

    _initialized = true;
    _liveControllers.add(this);
  }

  /// Sets a single video source.
  ///
  /// Convenience wrapper around [setClips] for the common single-video
  /// case. Replaces any previously loaded clips.
  Future<void> setSource(VideoClip clip) => setClips([clip]);

  /// Sets the list of clips to play as a continuous timeline.
  ///
  /// Replaces any previously loaded clips. The player must be
  /// [isInitialized] before calling this.
  ///
  /// Pass [startPosition] to begin playback at a specific point on the
  /// global timeline. ExoPlayer will start buffering at the matching
  /// clip and local offset directly — no extra seekTo needed.
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {
    _ensureInitialized();
    if (clips.isEmpty) {
      throw ArgumentError.value(clips, 'clips', 'must not be empty');
    }
    if (_firstFrameCompleter.isCompleted) {
      _firstFrameCompleter = Completer<bool>();
    }
    if (_isWebBackend) {
      await _webBackend!.setClips(clips, startPosition: startPosition);
      return;
    }
    if (_isLinuxBackend) {
      await _linuxBackend!.setClips(clips, startPosition: startPosition);
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>('setClips', {
        'clips': clips.map((c) => c.toMap()).toList(),
        if (startPosition != null && startPosition > Duration.zero)
          'startPositionMs': startPosition.inMilliseconds,
      });
    } on PlatformException catch (e) {
      // The native side cancels an in-flight setClips when a newer call
      // supersedes it. This is benign — the newer call will succeed.
      if (e.code != 'CANCELLED') rethrow;
    }
  }

  /// Starts or resumes playback.
  Future<void> play() async {
    _ensureInitialized();
    Log.debug(
      '$_logTarget: play() requested',
      name: _logName,
      category: LogCategory.video,
    );
    if (exclusivePlayback) await _pauseOtherLiveControllers();
    if (_isWebBackend) return _webBackend!.play();
    if (_isLinuxBackend) return _linuxBackend!.play();
    await _methodChannel.invokeMethod<void>('play');
  }

  /// Pauses playback.
  Future<void> pause() async {
    _ensureInitialized();
    Log.debug(
      '$_logTarget: pause() requested',
      name: _logName,
      category: LogCategory.video,
    );
    if (_isWebBackend) return _webBackend!.pause();
    if (_isLinuxBackend) return _linuxBackend!.pause();
    await _methodChannel.invokeMethod<void>('pause');
  }

  /// Stops playback and clears the current media.
  ///
  /// After calling this the player surface is blank (no stale frame)
  /// and position resets to zero.  The player remains alive and can
  /// be reused by calling [setSource] or [setClips] again.
  Future<void> stop() async {
    _ensureInitialized();
    Log.debug(
      '$_logTarget: stop() requested',
      name: _logName,
      category: LogCategory.video,
    );
    if (_isWebBackend) return _webBackend!.stop();
    if (_isLinuxBackend) return _linuxBackend!.stop();
    await _methodChannel.invokeMethod<void>('stop');
  }

  /// Seeks to [position] on the global timeline.
  Future<void> seekTo(Duration position) async {
    _ensureInitialized();
    if (_isWebBackend) return _webBackend!.seekTo(position);
    if (_isLinuxBackend) return _linuxBackend!.seekTo(position);
    await _methodChannel.invokeMethod<void>('seekTo', {
      'positionMs': position.inMilliseconds,
    });
  }

  /// Sets the volume (0.0 silent, 1.0 full).
  Future<void> setVolume(double volume) async {
    _ensureInitialized();
    final vol = volume.clamp(0.0, 1.0);
    if (_isWebBackend) return _webBackend!.setVolume(vol);
    if (_isLinuxBackend) return _linuxBackend!.setVolume(vol);
    _state = _state.copyWith(volume: vol);
    _stateController.add(_state);
    await _methodChannel.invokeMethod<void>('setVolume', {'volume': vol});
  }

  /// Sets the playback speed multiplier.
  Future<void> setPlaybackSpeed(double speed) async {
    _ensureInitialized();
    if (_isWebBackend) return _webBackend!.setPlaybackSpeed(speed);
    if (_isLinuxBackend) return _linuxBackend!.setPlaybackSpeed(speed);
    await _methodChannel.invokeMethod<void>('setPlaybackSpeed', {
      'speed': speed,
    });
  }

  /// Enables or disables looping.
  ///
  /// When enabled, playback restarts from the beginning after all
  /// clips finish.
  Future<void> setLooping({required bool looping}) async {
    _ensureInitialized();
    if (_isWebBackend) return _webBackend!.setLooping(looping: looping);
    if (_isLinuxBackend) return _linuxBackend!.setLooping(looping: looping);
    await _methodChannel.invokeMethod<void>('setLooping', {'looping': looping});
  }

  /// Jumps playback to the start of the clip at [index].
  Future<void> jumpToClip(int index) async {
    _ensureInitialized();
    if (_isWebBackend) return _webBackend!.jumpToClip(index);
    if (_isLinuxBackend) return _linuxBackend!.jumpToClip(index);
    await _methodChannel.invokeMethod<void>('jumpToClip', {'index': index});
  }

  /// Sets overlay audio tracks that play in sync with the video.
  ///
  /// Each track is mixed on top of the video's original audio with
  /// independent volume, video-timeline range, and track range.
  ///
  /// Replaces any previously set audio tracks.
  Future<void> setAudioTracks(List<AudioTrack> tracks) async {
    _ensureInitialized();
    if (_isWebBackend) return _webBackend!.setAudioTracks(tracks);
    if (_isLinuxBackend) return _linuxBackend!.setAudioTracks(tracks);
    await _methodChannel.invokeMethod<void>('setAudioTracks', {
      'tracks': tracks.map((t) => t.toMap()).toList(),
    });
  }

  /// Removes all overlay audio tracks.
  Future<void> removeAllAudioTracks() async {
    _ensureInitialized();
    if (_isWebBackend) return _webBackend!.removeAllAudioTracks();
    if (_isLinuxBackend) return _linuxBackend!.removeAllAudioTracks();
    await _methodChannel.invokeMethod<void>('removeAllAudioTracks');
  }

  /// Sets the volume of the overlay audio track at [index]
  /// (0.0 silent, 1.0 full).
  ///
  /// Has no effect if [index] is out of range.
  Future<void> setAudioTrackVolume(int index, double volume) async {
    _ensureInitialized();
    if (_isWebBackend) return _webBackend!.setAudioTrackVolume(index, volume);
    if (_isLinuxBackend) {
      return _linuxBackend!.setAudioTrackVolume(index, volume);
    }
    await _methodChannel.invokeMethod<void>('setAudioTrackVolume', {
      'index': index,
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  /// Releases all native resources. The controller cannot be reused
  /// after disposal.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _liveControllers.remove(this);

    // Cancel the event subscription before disposing the native player.
    // The native dispose tears down the EventChannel stream handler, so if
    // dispose races ahead of the cancel message the channel is already gone
    // and Flutter throws MissingPluginException on the cancel call.
    await _eventSubscription?.cancel();
    _eventSubscription = null;

    await Future.wait<void>([
      if (_initialized && _isWebBackend)
        _webBackend!.dispose()
      else if (_initialized && _isLinuxBackend)
        _linuxBackend!.dispose()
      else if (_initialized)
        _globalChannel.invokeMethod<void>('dispose', {'id': _playerId}),
      _stateController.close(),
    ]);
  }

  // -- internals --

  /// Enforces Divine's app-wide invariant that only one live
  /// [DivineVideoPlayerController] is playing at a time.
  ///
  /// Controllers with [exclusivePlayback] set to `false` sit outside the rule
  /// in both directions: they neither pause anyone when they start, nor get
  /// paused when someone else does. Otherwise a companion player and the clip
  /// it belongs to would stop each other — whichever started last would win.
  Future<void> _pauseOtherLiveControllers() async {
    final otherControllers = _liveControllers
        .where(
          (controller) =>
              !identical(controller, this) &&
              controller.exclusivePlayback &&
              controller._initialized &&
              !controller._disposed,
        )
        .toList(growable: false);
    if (otherControllers.isEmpty) return;

    // The only record that a player was stopped by *someone else* rather than
    // by its own screen. Without it a pause from this rule is indistinguishable
    // from the user pressing pause.
    Log.info(
      '$_logTarget: exclusive playback pausing ${otherControllers.length} '
      'sibling player(s): '
      '${otherControllers.map((c) => c._logTarget).join(', ')}',
      name: _logName,
      category: LogCategory.video,
    );

    await Future.wait<void>(
      otherControllers.map((controller) async {
        try {
          await controller.pause();
        } on Object catch (error) {
          Log.warning(
            '$_logTarget: failed to pause sibling player '
            '${controller._logTarget} before starting playback: $error',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }),
    );
  }

  /// Identifies this player in diagnostic logs.
  ///
  /// Reads [_playerId], so it is only safe after [initialize] has run.
  String get _logTarget => debugLabel == null
      ? 'Player $_playerId'
      : 'Player $_playerId ($debugLabel)';

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'Controller is not initialized. Call initialize() first.',
      );
    }
    if (_disposed) {
      throw StateError('Controller has been disposed.');
    }
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final map = event.cast<Object?, Object?>();
    _state = DivineVideoPlayerState.fromMap(map);

    if (_state.isFirstFrameRendered && !_firstFrameCompleter.isCompleted) {
      _firstFrameCompleter.complete(true);
    }
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _handleLinuxState(DivineVideoPlayerState state) {
    _state = state;
    if (_state.isFirstFrameRendered && !_firstFrameCompleter.isCompleted) {
      _firstFrameCompleter.complete(true);
    }
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _handleWebState(DivineVideoPlayerState state) {
    _state = state;
    if (_state.isFirstFrameRendered && !_firstFrameCompleter.isCompleted) {
      _firstFrameCompleter.complete(true);
    }
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _handleEventError(Object error) {
    _state = _state.copyWith(status: PlaybackStatus.error);
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  bool get _usesLinuxBackend =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Builds the Linux video surface for this controller instance.
  @internal
  Widget buildLinuxView() {
    if (!_isLinuxBackend || _linuxBackend == null) {
      throw StateError('Linux view is not available.');
    }
    return _linuxBackend!.buildView();
  }

  /// Builds the web video surface for this controller instance.
  @internal
  Widget buildWebView() {
    if (!_isWebBackend || _webBackend == null) {
      throw StateError('Web view is not available.');
    }
    return _webBackend!.buildView();
  }
}
