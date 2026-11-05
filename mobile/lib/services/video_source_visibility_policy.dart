// ABOUTME: Shared predicate for the viewer's two video-source preferences.
// ABOUTME: Hosting and provenance are independent axes; neither implies the other.

import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';

/// Decides whether the viewer's source preferences hide a video.
///
/// Lives outside `VideoEventService` so the feed policy and the repository
/// content filter share one definition. They previously each spelled the
/// hosting rule out separately, which is how they came to disagree with the
/// "Not Divine" badge about the same video.
class VideoSourceVisibilityPolicy {
  const VideoSourceVisibilityPolicy._();

  /// Whether [video] is hidden by the viewer's source preferences.
  ///
  /// The two axes answer different questions and are deliberately not
  /// collapsed into one rule:
  ///
  /// * [divineHostedOnly] — hosting. Whether we serve the media and can
  ///   therefore moderate or take it down.
  /// * [verifiedOnly] — provenance. Whether the media carries a capture
  ///   chain (C2PA / ProofMode) tracing it back to a camera.
  ///
  /// A creator can publish verified media on their own host, and unverified
  /// media can sit on ours, so satisfying one axis says nothing about the
  /// other.
  ///
  /// Archive Vines funnelcake verifies are exempt from [verifiedOnly]: they
  /// predate content credentials by a decade, and without the exemption the
  /// preference would hide ~97% of the catalogue. A `platform=vine` tag alone
  /// does not count, because any publisher can write it.
  static bool isHiddenBySourcePreferences(
    VideoEvent video, {
    required bool divineHostedOnly,
    required bool verifiedOnly,
  }) {
    if (divineHostedOnly && !video.isFromDivineServer) return true;
    if (verifiedOnly && !video.hasProofMode && !video.isVerifiedArchive) {
      return true;
    }
    return false;
  }
}
