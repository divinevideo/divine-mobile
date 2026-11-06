import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';

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
    // The bloc captures this kind for the like's k tag (#6980).
    VideoInteractionsBloc.likeTargetKindFor(
      addressableId: video.addressableId,
      eventKind: video.eventKind,
    ),
    includeVideoReplies,
  ));
}
