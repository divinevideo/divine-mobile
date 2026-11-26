import 'package:models/models.dart';

/// Returns the first index whose video identity matches the supplied event id
/// or stable id. Event id wins when both identities are supplied.
int indexOfVideoIdentity(
  List<VideoEvent> videos, {
  String? videoId,
  String? stableId,
  String? pubkey,
}) {
  final exactIndex = videoId == null
      ? -1
      : videos.indexWhere((video) => video.id == videoId);
  if (exactIndex >= 0 || stableId == null) return exactIndex;

  return videos.indexWhere(
    (video) =>
        video.stableId == stableId &&
        (pubkey == null || video.pubkey == pubkey),
  );
}

/// Returns the first index whose identity matches [target].
int indexOfMatchingVideo(List<VideoEvent> videos, VideoEvent target) {
  final exactIndex = indexOfVideoIdentity(videos, videoId: target.id);
  if (exactIndex >= 0) return exactIndex;

  // An edit changes the event id but keeps the full coordinate. The same
  // author and d-tag can also describe a different kind of video.
  final address = target.addressableId;
  if (address != null) {
    final addressIndex = videos.indexWhere(
      (video) => video.addressableId == address,
    );
    if (addressIndex >= 0) return addressIndex;
  }

  // Old feed rows may only carry a stable id.
  return videos.indexWhere((video) {
    if (video.pubkey != target.pubkey || video.stableId != target.stableId) {
      return false;
    }
    return address == null ||
        video.addressableId == null ||
        target.eventKind == null ||
        video.eventKind == null;
  });
}
