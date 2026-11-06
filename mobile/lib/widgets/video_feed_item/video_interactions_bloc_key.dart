import 'package:flutter/widgets.dart';
import 'package:models/models.dart';

/// Key for the per-video interaction bloc host.
ValueKey<Object> videoInteractionsBlocKey({
  required Object likesRepository,
  required Object commentsRepository,
  required Object repostsRepository,
  required VideoEvent video,
  bool includeVideoReplies = false,
}) {
  return ValueKey((
    likesRepository,
    commentsRepository,
    repostsRepository,
    video.stableId,
    video.addressableId,
    // The bloc reads the kind only for a video with no coordinate (#6980).
    video.addressableId == null ? video.eventKind : null,
    includeVideoReplies,
  ));
}
