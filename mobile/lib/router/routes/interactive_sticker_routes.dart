// ABOUTME: Full-screen routes of the interactive stickers: the private answer to
// ABOUTME: a question sticker, and the creator's list of their video replies.
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show NostrHexUtils, VideoStickerRegion;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/question_answer_target.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/screens/question_answer/question_answer_screen.dart';
import 'package:openvine/screens/video_replies/video_replies_screen.dart';

part 'interactive_sticker_routes.g.dart';

List<RouteBase> interactiveStickerRoutes() => $appRoutes;

/// The answer to the question sticker on a video by [pubkey]: the video by
/// its event id or d-tag, and what it asks. The whole question is in the
/// link, so the page needs nothing read first.
@TypedGoRoute<QuestionAnswerRouteData>(
  path: QuestionAnswerScreen.path,
  name: QuestionAnswerScreen.routeName,
)
class QuestionAnswerRouteData extends GoRouteData
    with $QuestionAnswerRouteData {
  const QuestionAnswerRouteData({
    required this.pubkey,
    @TypedQueryParameter(name: 'video') this.videoId,
    @TypedQueryParameter(name: 'd') this.dTag,
    @TypedQueryParameter(name: 'q') this.question,
  });

  final String pubkey;
  final String? videoId;
  final String? dTag;
  final String? question;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final target = QuestionAnswerTarget(
      creatorPubkey: pubkey.toLowerCase(),
      question: question ?? '',
      videoId: videoId?.toLowerCase(),
      videoDTag: dTag,
    );
    if (!target.isValid) {
      return RouteErrorScreen(message: context.l10n.routeInvalidQuestion);
    }
    return QuestionAnswerScreen(target: target);
  }
}

/// The video replies to the creator's video [videoId], published at
/// [address], where they pin and hide them.
@TypedGoRoute<VideoRepliesRouteData>(
  path: VideoRepliesScreen.path,
  name: VideoRepliesScreen.routeName,
)
class VideoRepliesRouteData extends GoRouteData with $VideoRepliesRouteData {
  const VideoRepliesRouteData({
    required this.videoId,
    @TypedQueryParameter(name: 'address') this.address,
  });

  final String videoId;
  final String? address;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final id = videoId.toLowerCase();
    final address = this.address ?? '';
    if (!NostrHexUtils.isValidEventId(id) ||
        !VideoStickerRegion.isVideoAddress(address)) {
      return RouteErrorScreen(message: context.l10n.routeInvalidVideoId);
    }
    return VideoRepliesScreen(videoId: id, videoAddress: address);
  }
}
