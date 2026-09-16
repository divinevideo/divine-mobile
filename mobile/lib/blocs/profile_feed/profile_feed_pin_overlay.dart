// ABOUTME: Pure derivation of the profile grid's pinned-first video sequence.
// ABOUTME: Applied to every ProfileFeedCubit emit so no path drops the pins.

import 'package:models/models.dart';

/// Moves the videos named by [pinnedCoordinates] to the front of [base],
/// in stored pin order, followed by the rest of [base] in its own order.
///
/// A pinned coordinate resolves from [base] first, then from [resolved]
/// (videos fetched separately because they fall outside the loaded feed
/// window). One that resolves from neither is skipped: a stale reference must
/// not leave an empty cell. Matching is by exact addressable coordinate, so a
/// metadata republish keeps its pin and a legacy video without a `d` tag is
/// never pinned.
List<VideoEvent> overlayPinnedVideos({
  required List<VideoEvent> base,
  required List<String> pinnedCoordinates,
  required Map<String, VideoEvent> resolved,
}) {
  if (pinnedCoordinates.isEmpty) return base;

  final byCoordinate = <String, VideoEvent>{};
  for (final video in base) {
    final coordinate = video.addressableId;
    if (coordinate != null) byCoordinate.putIfAbsent(coordinate, () => video);
  }

  final pinned = <VideoEvent>[];
  final pinnedSet = <String>{};
  for (final coordinate in pinnedCoordinates) {
    final video = byCoordinate[coordinate] ?? resolved[coordinate];
    if (video != null && pinnedSet.add(coordinate)) pinned.add(video);
  }
  if (pinned.isEmpty) return base;

  return [
    ...pinned,
    ...base.where((video) => !pinnedSet.contains(video.addressableId)),
  ];
}
