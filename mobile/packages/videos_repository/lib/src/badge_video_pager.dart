// ABOUTME: Merges paged video streams from badge-holder author chunks.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

/// Fetches holder videos across any number of authors without dropping groups
/// after Funnelcake's 200-author request limit.
class BadgeVideoPager {
  /// Creates a pager for a snapshot of [authors].
  BadgeVideoPager({
    required FunnelcakeApiClient client,
    required List<String> authors,
    required List<VideoEvent> Function(List<VideoStats>) transform,
    int? before,
  }) : _client = client,
       _transform = transform,
       _before =
           before ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 1,
       _chunks = [
         for (var i = 0; i < authors.length; i += 200)
           _AuthorChunk(authors.skip(i).take(200).toList(growable: false)),
       ];

  final FunnelcakeApiClient _client;
  final List<VideoEvent> Function(List<VideoStats>) _transform;
  final int _before;
  final List<_AuthorChunk> _chunks;
  final Set<String> _seen = {};

  /// Whether a chunk still has buffered or unread videos.
  bool get hasMore =>
      _chunks.any((chunk) => chunk.buffer.isNotEmpty || !chunk.exhausted);

  /// Returns the next [limit] public, visible videos in recency order.
  Future<List<VideoEvent>> loadMore({int limit = 25}) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final result = <VideoEvent>[];
    while (result.length < limit) {
      // A 200-author read is memory-heavy server-side. Walk chunks one at a
      // time so one viewer cannot multiply that cost by the holder count.
      for (final chunk in _chunks) {
        await _ensureCandidate(chunk);
      }
      _AuthorChunk? newestChunk;
      for (final chunk in _chunks) {
        if (chunk.buffer.isEmpty) continue;
        final candidate = chunk.buffer.first;
        final current = newestChunk?.buffer.first;
        if (current == null ||
            candidate.createdAt > current.createdAt ||
            (candidate.createdAt == current.createdAt &&
                candidate.id.compareTo(current.id) > 0)) {
          newestChunk = chunk;
        }
      }
      if (newestChunk == null) break;
      final video = newestChunk.buffer.removeAt(0);
      if (_seen.add(video.feedDedupKey)) result.add(video);
    }
    return result;
  }

  Future<void> _ensureCandidate(_AuthorChunk chunk) async {
    while (chunk.buffer.isEmpty && !chunk.exhausted) {
      final response = await _client.getVideosByAuthors(
        authors: chunk.authors,
        limit: 100,
        offset: chunk.offset,
        before: _before,
      );
      chunk.offset += response.serverItemCount;
      chunk.buffer.addAll(_transform(response.videos));
      if (response.hasMore != true || response.serverItemCount == 0) {
        chunk.exhausted = true;
      }
    }
  }
}

class _AuthorChunk {
  _AuthorChunk(this.authors);

  final List<String> authors;
  final List<VideoEvent> buffer = [];
  int offset = 0;
  bool exhausted = false;
}
