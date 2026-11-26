// ABOUTME: Service for audio playback during recording with headphone detection
// ABOUTME: Manages audio session configuration and exposes playback streams

// No non-experimental alternative exists. Tracked upstream:
// https://github.com/ryanheise/audio_session/issues
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_service/src/audio_session_service.dart';
import 'package:sound_service/src/audio_session_wrapper.dart';
import 'package:sound_service/src/audio_source_config.dart';
import 'package:sound_service/src/remote_audio_cache.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for managing audio playback during lip sync recording mode.
///
/// This service handles:
/// - Playing selected audio tracks during recording
/// - Detecting headphone connection state
/// - Managing audio session configuration for recording scenarios
class AudioPlaybackService {
  /// Creates an AudioPlaybackService with an optional custom AudioPlayer.
  ///
  /// The [audioPlayer] parameter allows for dependency injection in tests.
  /// The [audioSessionWrapper] parameter allows for mocking audio session.
  /// With [downloadRemoteAudio], an http(s) sound plays from a file the
  /// [remoteAudioCache] downloaded and keeps. It is off on the web, which has
  /// no file system for the cache and whose browser plays the URL itself.
  // coverage:ignore-start
  AudioPlaybackService({
    AudioPlayer? audioPlayer,
    AudioSessionWrapper? audioSessionWrapper,
    RemoteAudioCache? remoteAudioCache,
    bool downloadRemoteAudio = !kIsWeb,
    bool handleAudioSessionActivation = true,
  }) : _audioPlayer =
           audioPlayer ??
           AudioPlayer(
             handleAudioSessionActivation: handleAudioSessionActivation,
           ),
       _audioSessionWrapper =
           audioSessionWrapper ?? DefaultAudioSessionWrapper(),
       _remoteAudioCache = downloadRemoteAudio
           ? remoteAudioCache ?? RemoteAudioCache()
           : null {
    _audioSessionService = AudioSessionService(
      audioSessionWrapper: _audioSessionWrapper,
    );
    unawaited(_initializeHeadphoneDetection());
  }
  // coverage:ignore-end

  final AudioPlayer _audioPlayer;
  final AudioSessionWrapper _audioSessionWrapper;
  final RemoteAudioCache? _remoteAudioCache;
  late final AudioSessionService _audioSessionService;

  /// BehaviorSubject for headphone connection state.
  /// Starts with false (no headphones) until actual state is determined.
  final BehaviorSubject<bool> _headphonesConnectedSubject =
      BehaviorSubject<bool>.seeded(false);

  StreamSubscription<dynamic>? _deviceChangeSubscription;
  bool _isDisposed = false;

  /// Completer that gates operations while audio is loading.
  /// When non-null, a load operation is in progress. [seek] and [play]
  /// will await this completer before forwarding to the player.
  Completer<void>? _loadCompleter;

  /// Counts load requests, so a load whose download finishes after a later
  /// load started gives way instead of replacing the later one's audio.
  int _loadGeneration = 0;

  /// The last successfully loaded audio source identifier.
  /// Used to reload the source when a "Loading interrupted" error occurs.
  ({_SourceType type, Object value})? _lastSource;

  /// Monotonic counter to discard stale `getDevices` results.
  /// Incremented before every device query; only the response whose
  /// captured epoch still equals [_deviceCheckEpoch] may update the subject.
  int _deviceCheckEpoch = 0;

  /// Stream of playback position updates.
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Stream of duration updates (null if not loaded).
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  /// Stream of playing state updates.
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  /// Current duration of loaded audio (null if not loaded).
  Duration? get duration => _audioPlayer.duration;

  /// Whether audio is currently playing.
  bool get isPlaying => _audioPlayer.playing;

  /// Where playback is in the loaded audio.
  Duration get position => _audioPlayer.position;

  /// Stream of headphone connection state changes.
  Stream<bool> get headphonesConnectedStream =>
      _headphonesConnectedSubject.stream;

  /// Current headphone connection state.
  bool get areHeadphonesConnected => _headphonesConnectedSubject.value;

  /// Initializes headphone detection using audio_session.
  Future<void> _initializeHeadphoneDetection() async {
    if (_isDisposed) return;

    try {
      // Check initial headphone state
      final devices = await _audioSessionWrapper.getDevices();
      final hasHeadphones = _checkForHeadphones(devices);
      if (_isDisposed) return;
      _headphonesConnectedSubject.add(hasHeadphones);

      // Listen for device changes
      _deviceChangeSubscription = _audioSessionWrapper.devicesChangedEventStream
          .listen(
            (event) {
              if (_isDisposed) return;

              // Bump epoch so any in-flight getDevices() call becomes stale.
              final epoch = ++_deviceCheckEpoch;

              unawaited(
                _audioSessionWrapper.getDevices().then((allDevices) {
                  // Discard if a newer event arrived while we were waiting.
                  if (_isDisposed || epoch != _deviceCheckEpoch) return;
                  final hasHeadphones = _checkForHeadphones(allDevices);
                  _headphonesConnectedSubject.add(hasHeadphones);
                }),
              );
            },
            onError: (Object error) {
              Log.warning(
                'Error in device change stream: $error',
                name: 'AudioPlaybackService',
                category: LogCategory.video,
              );
            },
          );

      Log.debug(
        'Headphone detection initialized. Connected: $hasHeadphones',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
    } on Exception catch (e) {
      Log.warning(
        'Failed to initialize headphone detection: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      // Default to false if detection fails
      if (!_isDisposed) {
        _headphonesConnectedSubject.add(false);
      }
    }
  }

  /// Checks if any of the given devices are headphones or external audio.
  bool _checkForHeadphones(Set<audio_session.AudioDevice> devices) {
    for (final device in devices) {
      // Check for wired headphones
      if (device.type == audio_session.AudioDeviceType.wiredHeadphones ||
          device.type == audio_session.AudioDeviceType.wiredHeadset) {
        return true;
      }

      // Check for Bluetooth audio devices
      if (device.type == audio_session.AudioDeviceType.bluetoothA2dp ||
          device.type == audio_session.AudioDeviceType.bluetoothSco) {
        return true;
      }

      // iOS-specific: Check for Bluetooth HFP
      // coverage:ignore-start
      if (!kIsWeb &&
          Platform.isIOS &&
          device.type == audio_session.AudioDeviceType.bluetoothLe) {
        return true;
      }
      // coverage:ignore-end
    }
    return false;
  }

  /// Loads audio from a URL or asset path.
  ///
  /// Supports:
  /// - HTTP/HTTPS URLs for remote audio, downloaded before playback and kept,
  ///   so loading the same sound again needs no network
  /// - `asset://` URLs for bundled sounds (e.g., "asset://assets/sounds/bruh.mp3")
  ///
  /// With [streamUnlessCached], a remote sound that is not downloaded yet
  /// plays from its URL as it arrives instead, so a preview of a long song
  /// starts without waiting for the whole file. Nothing is kept then. A
  /// server the player cannot stream from is downloaded from as before.
  ///
  /// Returns the duration of the loaded audio, or `null` when the service
  /// was disposed while the audio loaded.
  ///
  /// Throws:
  ///
  /// * [RemoteAudioDownloadException] if a remote sound cannot be downloaded.
  /// * [PlayerInterruptedException] if a later load started before this
  ///   one's download finished.
  /// * Whatever the player throws for audio it cannot open.
  Future<Duration?> loadAudio(
    String url, {
    bool streamUnlessCached = false,
  }) async {
    if (_isDisposed) return null;
    final generation = ++_loadGeneration;
    final completer = _loadCompleter = Completer<void>();
    try {
      Duration? loadedDuration;

      // Check if this is a bundled asset URL
      if (url.startsWith('asset://')) {
        final assetPath = url.substring('asset://'.length);
        loadedDuration = await _audioPlayer.setAsset(assetPath);
        Log.debug(
          'Loaded audio from asset: $assetPath',
          name: 'AudioPlaybackService',
          category: LogCategory.video,
        );
      } else {
        final streamUri = streamUnlessCached ? _uncachedRemoteUri(url) : null;
        var loaded = false;
        if (streamUri != null) {
          try {
            loadedDuration = await _audioPlayer.setAudioSource(
              AudioSource.uri(streamUri),
            );
            loaded = true;
          } on PlayerException catch (e) {
            // A server that ignores byte ranges, which AVFoundation needs to
            // stream, still serves the whole file for the download.
            Log.info(
              'Could not stream $url, downloading it instead: $e',
              name: 'AudioPlaybackService',
              category: LogCategory.video,
            );
            if (generation != _loadGeneration) {
              throw PlayerInterruptedException('Loading interrupted');
            }
          }
        }
        if (!loaded) {
          final source = await _uriSource(url, generation);
          if (source == null) return null;
          loadedDuration = await _audioPlayer.setAudioSource(source);
        }
        Log.debug('Loaded audio from URL: $url', name: 'AudioPlaybackService');
      }

      _lastSource = (type: _SourceType.url, value: url);
      return loadedDuration;
    } catch (e) {
      Log.warning(
        'Failed to load audio from $url: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      rethrow;
    } finally {
      _finishLoad(completer);
    }
  }

  /// Loads audio from a local file path.
  ///
  /// Returns the duration of the loaded audio.
  Future<Duration?> loadAudioFromFile(String filePath) async {
    if (_isDisposed) return null;
    ++_loadGeneration;
    final completer = _loadCompleter = Completer<void>();
    try {
      final loadedDuration = await _audioPlayer.setFilePath(filePath);
      Log.debug(
        'Loaded audio from file: $filePath',
        name: 'AudioPlaybackService',
      );
      _lastSource = (type: _SourceType.file, value: filePath);
      return loadedDuration;
    } catch (e) {
      Log.warning(
        'Failed to load audio from file $filePath: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      rethrow;
    } finally {
      _finishLoad(completer);
    }
  }

  /// Sets an audio source from a library-agnostic [AudioSourceConfig].
  ///
  /// Converts the config into the appropriate player-specific source type.
  /// If [AudioSourceConfig.isClipped], wraps the source in a
  /// [ClippingAudioSource]. An http(s) source is downloaded first, as in
  /// [loadAudio], and throws the same errors.
  ///
  /// Returns the duration of the loaded audio, or `null` when the service
  /// was disposed while the audio loaded.
  Future<Duration?> setAudioSource(AudioSourceConfig config) async {
    if (_isDisposed) return null;
    final generation = ++_loadGeneration;
    final completer = _loadCompleter = Completer<void>();
    try {
      final UriAudioSource child;
      if (config.isAsset) {
        child = AudioSource.asset(config.uri);
      } else if (config.isFile) {
        child = AudioSource.file(config.uri);
      } else {
        final remote = await _uriSource(config.uri, generation);
        if (remote == null) return null;
        child = remote;
      }
      final source = config.isClipped
          ? ClippingAudioSource(
              child: child,
              start: config.start,
              end: config.end,
            )
          : child;

      final loadedDuration = await _audioPlayer.setAudioSource(source);
      Log.debug(
        'Set audio source: ${source.runtimeType}',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      _lastSource = (type: _SourceType.audioSource, value: config);
      return loadedDuration;
    } catch (e) {
      Log.warning(
        'Failed to set audio source: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      rethrow;
    } finally {
      _finishLoad(completer);
    }
  }

  /// [url] as a URI when it is an http(s) sound that is not downloaded yet,
  /// or `null` when it is local, already kept, or always played by URL (the
  /// web, which has no cache).
  Uri? _uncachedRemoteUri(String url) {
    final cache = _remoteAudioCache;
    final uri = Uri.parse(url);
    if (cache == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return cache.cachedFileFor(uri) == null ? uri : null;
  }

  /// The player source for a network [uri].
  ///
  /// An http(s) sound is downloaded to a local file first, unless the
  /// service plays remote sounds by URL (the web). just_audio's
  /// `LockCachingAudioSource` downloaded inside the player instead, where a
  /// server error escaped as an unhandled error no caller could catch.
  ///
  /// Returns `null` when the service was disposed during the download.
  /// Throws [PlayerInterruptedException] when a load started after the one
  /// numbered [generation] while the sound downloaded, so the later load
  /// keeps the player, as it would if the player itself had been loading.
  Future<UriAudioSource?> _uriSource(String uri, int generation) async {
    final parsedUri = Uri.parse(uri);
    final cache = _remoteAudioCache;
    if (cache == null ||
        (parsedUri.scheme != 'http' && parsedUri.scheme != 'https')) {
      return AudioSource.uri(parsedUri);
    }

    final file = await cache.fileFor(parsedUri);
    if (_isDisposed) return null;
    if (generation != _loadGeneration) {
      throw PlayerInterruptedException('Loading interrupted');
    }
    return AudioSource.file(file.path);
  }

  /// Releases whatever waits on the load that [completer] belongs to.
  ///
  /// Overlapping loads each complete their own completer, so a [play] or
  /// [seek] waiting on an earlier load is not left waiting forever after a
  /// later load replaced [_loadCompleter].
  void _finishLoad(Completer<void> completer) {
    completer.complete();
    if (identical(_loadCompleter, completer)) _loadCompleter = null;
  }

  /// Starts audio playback.
  ///
  /// If audio is currently loading, waits for the load to complete first.
  /// On transient "Loading interrupted" errors, reloads the source and
  /// retries once.
  Future<void> play() async {
    if (_isDisposed) return;
    await _loadCompleter?.future;
    if (_isDisposed) return;
    try {
      await _audioPlayer.play();
      Log.debug('Started audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      if (_isLoadingInterrupted(e)) {
        Log.debug(
          'Play interrupted, reloading source and retrying',
          name: 'AudioPlaybackService',
        );
        if (await _reloadLastSource()) {
          if (_isDisposed) return;
          await _audioPlayer.play();
          return;
        }
      }
      Log.warning(
        'Failed to start playback: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Pauses audio playback.
  Future<void> pause() async {
    if (_isDisposed) return;
    try {
      await _audioPlayer.pause();
      Log.debug('Paused audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      Log.warning(
        'Failed to pause playback: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Stops audio playback and resets position to the beginning.
  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _audioPlayer.stop();
      Log.debug('Stopped audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      Log.warning(
        'Failed to stop playback: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Seeks to a specific position in the audio.
  ///
  /// If audio is currently loading, waits for the load to complete first.
  /// On transient "Loading interrupted" errors, reloads the source and
  /// retries once.
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    await _loadCompleter?.future;
    if (_isDisposed) return;
    try {
      await _audioPlayer.seek(position);
      Log.debug(
        'Seeked to position: ${position.inSeconds}s',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
    } catch (e) {
      if (_isLoadingInterrupted(e)) {
        Log.debug(
          'Seek interrupted, reloading source and retrying',
          name: 'AudioPlaybackService',
          category: LogCategory.video,
        );
        if (await _reloadLastSource()) {
          if (_isDisposed) return;
          await _audioPlayer.seek(position);
          return;
        }
      }
      rethrow;
    }
  }

  /// Sets the playback volume.
  ///
  /// [volume] should be between 0.0 (muted) and 1.0 (full volume).
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
      Log.debug(
        'Set volume to: ${(volume * 100).toInt()}%',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to set volume: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Sets whether playback pauses and goes back to the beginning when the
  /// audio ends, ready to play again. Applies to every source loaded after
  /// it too.
  ///
  /// Without it, just_audio stays at the end and still counts as playing, so
  /// a play button would keep showing pause.
  ///
  /// The end is the player reporting completion, not the position reaching
  /// the duration: just_audio counts the position up from the moment play is
  /// requested, before the platform has played anything, so it reaches the
  /// duration before the audio has ended and would cut a short sound off.
  void setRewindsAtEnd({required bool rewinds}) {
    if (_isDisposed) return;
    unawaited(_endSubscription?.cancel());
    _endSubscription = rewinds
        ? _audioPlayer.processingStateStream
              .where((state) => state == ProcessingState.completed)
              .listen((_) => unawaited(_rewind()))
        : null;
  }

  StreamSubscription<ProcessingState>? _endSubscription;

  Future<void> _rewind() async {
    // A load started since the end was reported owns the player now.
    if (_isDisposed ||
        _audioPlayer.processingState != ProcessingState.completed) {
      return;
    }
    try {
      await _audioPlayer.pause();
      await _audioPlayer.seek(Duration.zero);
    } on Exception catch (e) {
      Log.warning(
        'Failed to rewind the audio at its end: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
    }
  }

  /// Configures the audio session for recording mode.
  ///
  /// This sets up the audio session to:
  /// - Allow audio playback during recording via A2DP to Bluetooth headphones
  /// - Use built-in microphone for recording (NOT Bluetooth mic)
  /// - Route to speaker when no headphones connected
  ///
  /// IMPORTANT: Only uses allowBluetoothA2dp, NOT allowBluetooth.
  /// allowBluetooth enables HFP (phone call mode) which causes
  /// "call started/ended" sounds on Bluetooth headsets.
  Future<void> configureForRecording() async {
    if (_isDisposed) return;
    await _audioSessionService.configureForRecording();
  }

  /// Configures the audio session for mixed playback.
  ///
  /// This allows audio to play simultaneously with other audio sources
  /// (e.g., video player). Use this in the video editor to prevent
  /// the audio from pausing the video.
  Future<void> configureForMixedPlayback() async {
    if (_isDisposed) return;
    await _audioSessionService.configureForMixedPlayback();
  }

  /// Resets the audio session to default configuration.
  ///
  /// Call this when exiting recording mode.
  Future<void> resetAudioSession() async {
    if (_isDisposed) return;
    await _audioSessionService.resetAudioSession();
  }

  /// Disposes of all resources used by this service.
  ///
  /// Must be called when the service is no longer needed.
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    await _endSubscription?.cancel();
    await _deviceChangeSubscription?.cancel();
    await _headphonesConnectedSubject.close();
    await _audioPlayer.dispose();

    Log.debug('AudioPlaybackService disposed', name: 'AudioPlaybackService');
  }

  /// Returns `true` if the error is a transient "Loading interrupted" error
  /// from just_audio that can be recovered by reloading the source.
  bool _isLoadingInterrupted(Object error) =>
      error.toString().contains('Loading interrupted');

  /// Reloads the last audio source that was successfully set.
  ///
  /// Returns `true` if the reload succeeded, `false` otherwise.
  Future<bool> _reloadLastSource() async {
    final source = _lastSource;
    if (source == null || _isDisposed) return false;

    try {
      switch (source.type) {
        case _SourceType.url:
          await loadAudio(source.value as String);
        case _SourceType.file:
          await loadAudioFromFile(source.value as String);
        case _SourceType.audioSource:
          await setAudioSource(source.value as AudioSourceConfig);
      }
      Log.debug(
        'Reloaded audio source after interruption',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      return true;
    } on Exception catch (e) {
      Log.warning(
        'Failed to reload audio source: $e',
        name: 'AudioPlaybackService',
        category: LogCategory.video,
      );
      return false;
    }
  }
}

/// The type of audio source last loaded into the player.
enum _SourceType { url, file, audioSource }
