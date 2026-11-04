// ABOUTME: Screen-reader name of a library clip, shared by grid and preview
// ABOUTME: Says the length, or the still count for a stop-motion clip

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/video_editor_utils.dart';

/// How a screen reader names a library clip.
extension VideoClipSemanticLabel on DivineVideoClip {
  /// The clip's length, or for a stop-motion clip how many stills it holds.
  ///
  /// A stop-motion clip's playback length is a tiny, misleading value, which
  /// is why the grid hides its duration badge. Announcing that same number
  /// would leak to screen readers exactly what the UI withholds.
  String semanticLabel(AppLocalizations l10n) => isStopMotion
      ? l10n.videoClipStopMotionSemanticLabel(
          l10n.videoEditorStopMotionFramesCount(stopMotionFrames?.length ?? 0),
        )
      : l10n.videoClipSemanticLabel(duration.toFormattedSeconds());
}
