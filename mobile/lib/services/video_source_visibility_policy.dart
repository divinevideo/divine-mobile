// ABOUTME: Shared predicate for the viewer's two video-source preferences.
// ABOUTME: Hosting and provenance are independent axes; neither implies the other.

import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/effective_content_labels.dart';

/// Decides whether the viewer's source preferences hide a video.
///
/// Lives outside `VideoEventService` so the feed policy and the repository
/// content filter share one definition. They previously each spelled the
/// hosting rule out separately, which is how they came to disagree with the
/// "Not Divine" badge about the same video.
class VideoSourceVisibilityPolicy {
  const VideoSourceVisibilityPolicy._();

  /// Whether hosting preferences hide [video] from this viewer.
  ///
  /// Creators keep access to their own uploads regardless of media host.
  /// Ownership does not exempt them from provenance or moderation rules.
  static bool isHiddenByHostingPreference(
    VideoEvent video, {
    required bool divineHostedOnly,
    required String? viewerPubkey,
  }) =>
      divineHostedOnly &&
      !video.isFromDivineServer &&
      !(viewerPubkey != null &&
          viewerPubkey.isNotEmpty &&
          contentOwnerMatches(video.pubkey, viewerPubkey));

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
  /// Archive Vines are exempt from [verifiedOnly]: they predate content
  /// credentials by a decade, and without the exemption the preference would
  /// hide ~97% of the catalogue. Funnelcake's verification decides which
  /// videos those are ([VideoEvent.countsAsArchiveVine]); a `platform=vine`
  /// tag stands in only while funnelcake cannot check its archive.
  static bool isHiddenBySourcePreferences(
    VideoEvent video, {
    required bool divineHostedOnly,
    required bool verifiedOnly,
    required String? viewerPubkey,
  }) {
    if (isHiddenByHostingPreference(
      video,
      divineHostedOnly: divineHostedOnly,
      viewerPubkey: viewerPubkey,
    )) {
      return true;
    }
    if (verifiedOnly && !video.hasProofMode && !video.countsAsArchiveVine) {
      return true;
    }
    return false;
  }
}
