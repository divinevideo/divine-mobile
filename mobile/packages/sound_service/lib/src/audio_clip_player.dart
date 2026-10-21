// ABOUTME: Wrapper around just_audio for clipped audio playback.
// ABOUTME: Encapsulates AudioPlayer, ClippingAudioSource, and player state
// ABOUTME: so consumers never depend on just_audio types directly.

import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:sound_service/src/audio_source_config.dart';
import 'package:unified_logger/unified_logger.dart';

abstract class _RemoteAudioLoaderConfig {
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration readTimeout = Duration(seconds: 30);
  static const int maxBytes = 50 * 1024 * 1024;
}

/// Downloads a remote audio URL to a local file, optionally reusing a cache.
typedef RemoteAudioFileLoader =
    Future<File> Function(Uri uri, File? cachedFile, Uri? cachedUri);

/// A player that plays a clipped portion of an audio source.
///
/// Wraps `just_audio`'s [AudioPlayer] and [ClippingAudioSource] behind a
/// focused API so that consumers do not depend on `just_audio` types
/// directly. If the underlying audio library is replaced, only this class
/// needs to change.
class AudioClipPlayer {
  /// Creates an [AudioClipPlayer].
  ///
  /// An optional [audioPlayer] can be injected for testing within the
  /// `sound_service` package.
  // coverage:ignore-start
  AudioClipPlayer({
    AudioPlayer? audioPlayer,
    RemoteAudioFileLoader? remoteAudioFileLoader,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer(),
       _remoteAudioFileLoader =
           remoteAudioFileLoader ?? _defaultRemoteAudioFileLoader;
  // coverage:ignore-end

  final AudioPlayer _audioPlayer;
  final RemoteAudioFileLoader _remoteAudioFileLoader;
  File? _cachedRemoteFile;
  Uri? _cachedRemoteUri;

  /// playing (i.e. reaches the end without being stopped manually).
  ///
  /// Consumers can use this to implement looping or transition logic
  /// without needing to know about `just_audio`'s [PlayerState] or
  /// [ProcessingState].
  Stream<void> get completionStream => _audioPlayer.playerStateStream
      .where((s) => s.processingState == ProcessingState.completed)
      .map((_) {});

  /// Whether audio is currently playing.
  bool get isPlaying => _audioPlayer.playing;

  /// Sets a clipped audio source from an [AudioSourceConfig].
  ///
  /// The config's [AudioSourceConfig.start] and [AudioSourceConfig.end]
  /// define the clip boundaries within the full track.
  Future<void> setClip(AudioSourceConfig config) async {
    final UriAudioSource child;
    if (config.isAsset) {
      await _clearCachedRemoteFile();
      child = AudioSource.asset(config.uri);
    } else if (config.isFile) {
      await _clearCachedRemoteFile();
      child = AudioSource.file(config.uri);
    } else {
      final cachedFile = await _remoteAudioFileLoader(
        Uri.parse(config.uri),
        _cachedRemoteFile,
        _cachedRemoteUri,
      );
      _cachedRemoteFile = cachedFile;
      _cachedRemoteUri = Uri.parse(config.uri);
      child = AudioSource.file(cachedFile.path);
    }

    final source = ClippingAudioSource(
      child: child,
      start: config.start,
      end: config.end,
    );

    await _audioPlayer.setAudioSource(source);
  }

  /// Starts or resumes playback.
  Future<void> play() async {
    await _audioPlayer.play();
  }

  /// Pauses playback, keeping the current position.
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Stops playback and resets to the beginning.
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Seeks to the given [position] within the current clip.
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Sets the playback volume, clamped to `0.0..1.0`.
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Plays the clip [speed] times as fast at unchanged pitch: `2` plays it
  /// in half the time. Positions passed to [seek] stay positions in the clip.
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
  }

  /// Releases all resources held by the underlying player.
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } on Exception catch (e) {
      Log.warning(
        'Error disposing AudioClipPlayer: $e',
        name: 'AudioClipPlayer',
        category: LogCategory.video,
      );
    }
    await _clearCachedRemoteFile();
  }

  Future<void> _clearCachedRemoteFile() async {
    final file = _cachedRemoteFile;
    _cachedRemoteFile = null;
    _cachedRemoteUri = null;
    if (file == null) return;

    try {
      if (file.existsSync()) {
        file.deleteSync();
        final parent = file.parent;
        // Non-recursive on purpose: a custom RemoteAudioFileLoader may place
        // the cached file in a directory that is shared with unrelated files;
        // deleteSync() throws (and we swallow) if the parent isn't empty.
        if (parent.existsSync()) {
          parent.deleteSync();
        }
      }
    } on Exception catch (e) {
      Log.warning(
        'Failed to delete cached remote audio file: $e',
        name: 'AudioClipPlayer',
        category: LogCategory.video,
      );
    }
  }

  static Future<File> _defaultRemoteAudioFileLoader(
    Uri uri,
    File? cachedFile,
    Uri? cachedUri,
  ) async {
    // Defense-in-depth for issue #4395: callers that miscategorize a
    // local file path as a network source would otherwise reach
    // HttpClient.getUrl with a schemeless / file:// URI and crash with
    // "No host specified in URI". Reject anything that is not http(s)
    // up front with an actionable error. Note: platform-specific schemes
    // such as Android content:// and web blob: are also rejected here.
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError.value(
        uri,
        'uri',
        'Remote audio loader requires an http(s) URI; got scheme '
            '"${uri.scheme}". Use AudioSourceConfig.file for local paths.',
      );
    }

    if (cachedFile != null && cachedUri == uri && cachedFile.existsSync()) {
      return cachedFile;
    }

    if (cachedFile != null && cachedFile.existsSync()) {
      cachedFile.deleteSync();
      final parent = cachedFile.parent;
      if (parent.existsSync()) {
        parent.deleteSync(recursive: true);
      }
    }

    final client = HttpClient()
      ..connectionTimeout = _RemoteAudioLoaderConfig.connectionTimeout;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        _RemoteAudioLoaderConfig.readTimeout,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Failed to download remote audio (${response.statusCode})',
          uri: uri,
        );
      }

      final tempDir = await Directory.systemTemp.createTemp('sound_clip_');
      final path = tempDir.uri.resolve(_safeFilenameForUri(uri)).toFilePath();
      final file = File(path);
      final sink = file.openWrite();
      var written = 0;
      try {
        await for (final chunk in response.timeout(
          _RemoteAudioLoaderConfig.readTimeout,
        )) {
          written += chunk.length;
          if (written > _RemoteAudioLoaderConfig.maxBytes) {
            throw HttpException(
              'Remote audio exceeds ${_RemoteAudioLoaderConfig.maxBytes} '
              'byte limit',
              uri: uri,
            );
          }
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      return file;
    } finally {
      client.close(force: true);
    }
  }

  static String _safeFilenameForUri(Uri uri) {
    final lastSegment = uri.pathSegments.isEmpty
        ? 'audio_clip'
        : uri.pathSegments.last;
    final sanitized = lastSegment.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'audio_clip' : sanitized;
  }
}
