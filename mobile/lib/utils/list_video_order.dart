// ABOUTME: Puts the videos a curated list resolved back into the list's own
// ABOUTME: order, whatever order the cache and relays returned them in.

import 'package:models/models.dart';
import 'package:nostr_sdk/aid.dart';

/// Where each video a curated list names sits in the list's own order.
///
/// A list's videos resolve from the cache first and then from relays as they
/// arrive, so without this the grid and the player follow that timing instead
/// of the list. A reference is matched the way the list's videos are looked
/// up: an event id by id, and a `kind:pubkey:d-tag` coordinate by kind,
/// author and d-tag.
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
  int? positionOf(VideoEvent video) => _earlierPosition(
    _positions[_idKey(video.id)],
    _positions[addressOf(video)?.toAString()],
  );

  /// The index in [videos] of the video named by [reference], even if the
  /// list also names the video earlier by its other identifier.
  static int indexOfReference(String reference, List<VideoEvent> videos) {
    final key = _referenceKey(reference);
    if (key == null) return -1;
    return videos.indexWhere(
      (video) =>
          _idKey(video.id) == key || addressOf(video)?.toAString() == key,
    );
  }

  /// [videos] in the list's order. A video no reference names keeps its
  /// arrival order after the rest, so nothing resolved is dropped.
  /// [legacyMatches] gives cached fallbacks the positions they resolved.
  List<VideoEvent> sort(
    Iterable<VideoEvent> videos, {
    Map<AId, VideoEvent> legacyMatches = const {},
  }) {
    final legacyPositions = {
      for (final MapEntry(key: address, value: video) in legacyMatches.entries)
        video.id: _positions[address.toAString()],
    };
    final placed =
        [
          for (final (arrival, video) in videos.indexed)
            (
              position: _earlierPosition(
                positionOf(video),
                legacyPositions[video.id],
              ),
              arrival: arrival,
              video: video,
            ),
        ]..sort((a, b) {
          final (pa, pb) = (a.position, b.position);
          if (pa == pb) return a.arrival.compareTo(b.arrival);
          if (pa == null) return 1;
          if (pb == null) return -1;
          return pa.compareTo(pb);
        });
    return [for (final entry in placed) entry.video];
  }

  static int? _earlierPosition(int? first, int? second) {
    if (first == null) return second;
    return second == null || first < second ? first : second;
  }

  static String? _referenceKey(String reference) {
    if (!reference.contains(':')) return _idKey(reference);
    return parseAddress(reference)?.toAString();
  }

  /// Parses an addressable video reference, preserving the full d-tag.
  static AId? parseAddress(String reference) {
    final address = AId.fromString(reference);
    if (address == null ||
        !NIP71VideoKinds.isAddressableVideoKind(address.kind) ||
        address.pubkey.isEmpty ||
        address.dTag.isEmpty) {
      return null;
    }
    return AId(
      kind: address.kind,
      pubkey: address.pubkey.toLowerCase(),
      dTag: address.dTag,
    );
  }

  /// The address of a video, including cached videos stored before the kind
  /// and addressable d-tag were persisted separately.
  static AId? addressOf(VideoEvent video) {
    final kind = video.eventKind ?? NIP71VideoKinds.addressableShortVideo;
    final dTag =
        video.addressableDTag ?? video.rawTags['d'] ?? video.vineId ?? video.id;
    if (!NIP71VideoKinds.isAddressableVideoKind(kind) || dTag.isEmpty) {
      return null;
    }
    return AId(kind: kind, pubkey: video.pubkey.toLowerCase(), dTag: dTag);
  }

  static String _idKey(String id) => id.toLowerCase();
}
