// ABOUTME: Readies the remote sounds a list shows before they are played,
// ABOUTME: so a tap on one starts it without waiting for the network

import 'dart:async';

import 'package:sound_service/src/remote_audio_cache.dart';

/// Readies the remote sounds a list shows, so a tap plays one at once.
///
/// A small sound, an effect of a few kilobytes, is downloaded into the
/// [RemoteAudioCache] and plays from the phone. A larger one, a song a
/// preview streams, only has its first byte requested, which gets the CDN
/// edge in front of the server ready to serve it.
///
/// Sounds are readied a few at a time, the one asked for last first: in a
/// list that is the row built last. Once more than [maxWaiting] wait, the
/// oldest, usually rows already scrolled past, are dropped.
class RemoteAudioPrefetcher {
  /// Creates a [RemoteAudioPrefetcher] that downloads into [cache].
  RemoteAudioPrefetcher({
    required RemoteAudioCache cache,
    this.downloadUpTo = 512 * 1024,
    this.maxRunning = 3,
    this.maxWaiting = 12,
  }) : _cache = cache;

  final RemoteAudioCache _cache;

  /// The largest sound, in bytes, that is downloaded whole. A larger one,
  /// or one of unknown size, is only warmed on the CDN.
  final int downloadUpTo;

  /// How many sounds are readied at the same time.
  final int maxRunning;

  /// How many sounds wait their turn; asking for more drops the oldest.
  final int maxWaiting;

  final _waiting = <({Uri uri, int? sizeBytes})>[];

  /// The sounds waiting, running or readied, so each is readied once.
  final _asked = <Uri>{};
  int _running = 0;
  bool _closed = false;

  /// Readies the sound at [uri], whose file is [sizeBytes] long when known.
  ///
  /// Does nothing for a sound that is not http(s) with a host, was asked
  /// for before, or is in the cache already.
  void prefetch(Uri uri, {int? sizeBytes}) {
    if (_closed || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    if (uri.host.isEmpty) return;
    if (_cache.cachedFileFor(uri) != null || !_asked.add(uri)) return;
    _waiting.add((uri: uri, sizeBytes: sizeBytes));
    if (_waiting.length > maxWaiting) _asked.remove(_waiting.removeAt(0).uri);
    _startNext();
  }

  void _startNext() {
    while (!_closed && _running < maxRunning && _waiting.isNotEmpty) {
      final next = _waiting.removeLast();
      _running++;
      unawaited(
        _ready(next.uri, next.sizeBytes).whenComplete(() {
          _running--;
          _startNext();
        }),
      );
    }
  }

  Future<void> _ready(Uri uri, int? sizeBytes) async {
    if (sizeBytes == null || sizeBytes > downloadUpTo) return _cache.warm(uri);
    try {
      await _cache.fileFor(uri);
    } on RemoteAudioDownloadException {
      // Nothing is kept for a failed download; playing the sound tries
      // again and reports the failure there.
    }
  }

  /// Stops readying sounds. Downloads already running finish into the
  /// cache.
  void dispose() {
    _closed = true;
    _waiting.clear();
  }
}
