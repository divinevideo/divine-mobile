// ABOUTME: Puts the videos a curated list resolved back into the list's own
// ABOUTME: order, whatever order the cache and relays returned them in.

import 'package:models/models.dart';

/// Where each video a curated list names sits in the list's own order.
///
/// A list's videos resolve from the cache first and then from relays as they
/// arrive, so without this the grid and the player follow that timing instead
/// of the list. A reference is matched the way the list's videos are looked
/// up: an event id by id, and a `kind:pubkey:d-tag` coordinate by author and
/// d-tag.
class ListVideoOrder {
  /// The order of [references], a list's event ids and coordinates.
  ListVideoOrder(List<String> references) {
    for (final (position, reference) in references.indexed) {
      final key = _referenceKey(reference);
      if (key != null) _positions.putIfAbsent(key, () => position);
    }
  }

  final Map<String, int> _positions = {};

  /// The position of the first reference that names [video], or null when
  /// none does.
  int? positionOf(VideoEvent video) {
    int? first;
    for (final key in _videoKeys(video)) {
      final position = _positions[key];
      if (position != null && (first == null || position < first)) {
        first = position;
      }
    }
    return first;
  }

  /// The position of the first reference that names the same video as
  /// [reference], which is where [positionOf] places that video.
  int? positionOfReference(String reference) {
    final key = _referenceKey(reference);
    return key == null ? null : _positions[key];
  }

  /// [videos] in the list's order. A video no reference names keeps its
  /// arrival order after the rest, so nothing resolved is dropped.
  List<VideoEvent> sort(Iterable<VideoEvent> videos) {
    final placed =
        [
          for (final (arrival, video) in videos.indexed)
            (position: positionOf(video), arrival: arrival, video: video),
        ]..sort((a, b) {
          final (pa, pb) = (a.position, b.position);
          if (pa == pb) return a.arrival.compareTo(b.arrival);
          if (pa == null) return 1;
          if (pb == null) return -1;
          return pa.compareTo(pb);
        });
    return [for (final entry in placed) entry.video];
  }

  static String? _referenceKey(String reference) {
    if (!reference.contains(':')) return _idKey(reference);
    final parts = reference.split(':');
    if (parts.length < 3) return null;
    final pubkey = parts[1];
    final dTag = parts.sublist(2).join(':');
    if (pubkey.isEmpty || dTag.isEmpty) return null;
    return _addressKey(pubkey, dTag);
  }

  /// The keys [video] can be named by. The d-tag candidates are the ones the
  /// cache lookup accepts, so a video the cache matched is placed too.
  static Iterable<String> _videoKeys(VideoEvent video) => {
    _idKey(video.id),
    for (final dTag in [
      video.addressableDTag,
      video.rawTags['d'] ?? video.vineId ?? video.id,
    ])
      if (dTag != null && dTag.isNotEmpty) _addressKey(video.pubkey, dTag),
  };

  static String _idKey(String id) => 'id:${id.toLowerCase()}';

  static String _addressKey(String pubkey, String dTag) =>
      'address:${pubkey.toLowerCase()}:$dTag';
}
