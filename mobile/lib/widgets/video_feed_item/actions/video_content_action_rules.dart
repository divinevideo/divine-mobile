// ABOUTME: Decides whether a video offers Add to clips to a viewer.
// ABOUTME: Shared by the share sheet and the video info sheet.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';

/// Whether the viewer may add [video] to their clips.
///
/// Classic Vines, the viewer's own videos and videos whose creator allows
/// reuse qualify. Never offered on web, where clip import is unavailable.
bool canAddVideoToClips({
  required VideoEvent video,
  required bool isOwnContent,
  bool isWeb = kIsWeb,
}) {
  return (video.isOriginalVine || isOwnContent || video.allowVideoReuse) &&
      !isWeb;
}
