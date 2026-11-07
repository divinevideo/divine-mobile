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
  final likeTargetKind = VideoInteractionsBloc.likeTargetKindFor(
    addressableId: video.addressableId,
    eventKind: video.eventKind,
  );
  return ValueKey((
    likesRepository,
    commentsRepository,
    repostsRepository,
    video.stableId,
    video.addressableId,
    // The bloc captures this kind for the like's k tag (#6980). A regular
    // kind stays out: its k is optional (NIP-25), and rebuilding when a copy
    // learns it would drop an in-flight like or repost.
    likeTargetKind == NIP71VideoKinds.shortVideo ||
            likeTargetKind == NIP71VideoKinds.normalVideo
        ? null
        : likeTargetKind,
    includeVideoReplies,
  ));
}
