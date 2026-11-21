import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:infinite_video_feed/src/utils/canonical_divine_url.dart';
import 'package:models/models.dart';

/// The canonical policy endpoint denied playback.
class BunnyPlaybackDenied implements Exception {
  /// Constructs a policy denial without carrying request or user data.
  const BunnyPlaybackDenied();

  @override
  String toString() => 'HTTP 404 playback denied';
}

/// Selects verified public equivalents without changing signed event URLs.
/// The caller owns the HTTP client. Viewer credentials are never sent.
class BunnyPlaybackSelector {
  /// Creates a bounded selector. Successful choices expire after 30 seconds.
  BunnyPlaybackSelector({
    required http.Client client,
    DateTime Function()? now,
    Duration timeout = const Duration(seconds: 1),
  }) : _client = client,
       _now = now ?? DateTime.now,
       _timeout = timeout;

  final http.Client _client;
  final DateTime Function() _now;
  final Duration _timeout;
  final _cache = <String, ({DateTime expires, Set<String> paths})>{};
  final _pending = <String, Future<Set<String>>>{};

  /// Returns only server-approved, same-parent top-level media paths.
  /// Service/configuration failures preserve canonical playback; denials throw.
  Future<Set<String>> select(VideoEvent video) async {
    final path = bunnyProgressivePath(video.videoUrl);
    if (path == null) return const {};
    final parent = path.substring(1, 65);
    final cached = _cache[parent];
    if (cached != null && _now().isBefore(cached.expires)) return cached.paths;
    final pending = _pending[parent];
    if (pending != null) return pending;
    if (_pending.length >= 8) return const {};
    final request = _fetch(parent);
    _pending[parent] = request;
    try {
      final paths = await request;
      if (_cache.length >= 256) _cache.remove(_cache.keys.first);
      _cache[parent] = (
        expires: _now().add(const Duration(seconds: 30)),
        paths: paths,
      );
      return paths;
    } finally {
      unawaited(_pending.remove(parent));
    }
  }

  Future<Set<String>> _fetch(String parent) async {
    final abort = Completer<void>();
    Future<Set<String>> fetch() async {
      final request = http.AbortableRequest(
        'GET',
        Uri.https('media.divine.video', '/api/bunny-playback/$parent'),
        abortTrigger: abort.future,
      )..followRedirects = false;
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
        if (const {401, 403, 404}.contains(response.statusCode)) {
          throw const BunnyPlaybackDenied();
        }
        return const {};
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 8192) return const {};
        bytes.addAll(chunk);
      }
      final body = jsonDecode(utf8.decode(bytes));
      if (body is! Map<String, dynamic> ||
          body['version'] != 1 ||
          body['host'] != bunnyPlaybackHost ||
          body['paths'] is! List) {
        return const {};
      }
      final paths = body['paths'] as List<dynamic>;
      if (paths.length > 4) return const {};
      final allowed = {
        '/$parent',
        '/$parent/720p.mp4',
        '/$parent/480p.mp4',
        '/$parent/hls/master.m3u8',
      };
      if (paths.any((path) => path is! String || !allowed.contains(path))) {
        return const {};
      }
      return Set<String>.unmodifiable(paths.cast<String>());
    }

    try {
      return await fetch().timeout(_timeout);
    } on BunnyPlaybackDenied {
      rethrow;
    } on Object {
      return const {};
    } finally {
      abort.complete();
    }
  }
}
