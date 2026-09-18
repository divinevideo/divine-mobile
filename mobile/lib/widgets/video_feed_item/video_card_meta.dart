// ABOUTME: Resolves what a video card's secondary meta line shows.
// ABOUTME: A public count appears only when it is large enough to attract.

import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// Smallest public count that reads as a recommendation rather than a warning.
///
/// A number below this tells a viewer not to bother — which is worse than
/// silence on content the feed just paid to surface. Above it, the number is
/// doing useful work: a classic Vine with millions of loops is famous, and
/// saying so is the point.
///
/// Applies to archival Vine counts as well as diVine's own: a small number
/// discourages a viewer whatever its provenance. Measured against 1000
/// unique classic Vines, this hides roughly 64% of the archive (p50 is 298
/// loops) and keeps the famous ones.
///
/// This threshold is a product call, not a technical one. It is the single
/// value to change if the bar turns out to sit in the wrong place.
const int publicLoopCountFloor = 1000;

/// The count a video card's secondary line should render.
///
/// The post date is deliberately not part of the card. The line exists to show
/// social proof, and a date only reads as evidence the surface is quiet; the
/// metadata sheet still carries the full date for anyone who opens it.
@immutable
class VideoCardMeta {
  const VideoCardMeta({this.loopCount});

  /// Loop count to display, or null when the count stays hidden.
  final int? loopCount;

  /// Whether there is nothing to render, so the caller omits the line.
  bool get isEmpty => loopCount == null;
}

/// Resolves the meta line for [video].
///
/// Creators always see their own number, however small: it is their
/// performance data rather than a public signal, and correcting a creator's
/// underestimate of their audience is what keeps them posting.
VideoCardMeta resolveVideoCardMeta({
  required VideoEvent? video,
  required bool isOwnVideo,
}) {
  if (video == null) return const VideoCardMeta();

  final loopCount = _resolveLoopCount(video: video, isOwnVideo: isOwnVideo);

  return VideoCardMeta(loopCount: loopCount);
}

int? _resolveLoopCount({required VideoEvent video, required bool isOwnVideo}) {
  if (isOwnVideo) {
    return video.hasLoopMetadata ? video.totalLoops : null;
  }

  final publicCount = _publicCount(video);
  return publicCount >= publicLoopCountFloor ? publicCount : null;
}

/// The count a stranger would be shown, before the floor is applied.
///
/// Classic Vines report their archival figure alone. Folding live diVine
/// views into it would misreport how popular the Vine actually was, and our
/// current view volume is too small to change the number meaningfully anyway.
int _publicCount(VideoEvent video) =>
    video.isOriginalVine ? video.originalLoops ?? 0 : video.totalLoops;
