// ABOUTME: Decides whether a video's creator lets a viewer reuse it as a clip.
// ABOUTME: Read by VideoContentActionsBloc and by the sheets that offer Remix.

import 'package:models/models.dart';

/// Whether the viewer may remix [video], using it as a clip in their own post.
///
/// Videos are remixable unless the creator declined with
/// `allow_video_reuse=false`. Classic Vines and the viewer's own videos are
/// remixable whatever their tag says. Platform and creator-account checks are
/// the caller's concern.
bool canRemixVideo({required VideoEvent video, required bool isOwnContent}) {
  return video.isOriginalVine || isOwnContent || video.allowVideoReuse;
}
