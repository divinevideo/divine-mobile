// ABOUTME: Maps VideoMetadataUpdateError codes to localized strings.
// ABOUTME: The service stores the code; the UI layer localizes for display.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_metadata_update_error.dart';

/// Maps a [VideoMetadataUpdateError] to a localized, user-facing message.
///
/// Follows the project's l10n rule: results carry codes, never English copy.
/// The switch has no `default`, so a new enum arm is a compile error here
/// rather than a silent fallthrough to the generic message.
extension VideoMetadataUpdateErrorL10n on AppLocalizations {
  String videoMetadataUpdateErrorMessage(VideoMetadataUpdateError reason) {
    switch (reason) {
      case VideoMetadataUpdateError.notAuthenticated:
        return videoUpdateErrorNotAuthenticated;
      case VideoMetadataUpdateError.noPlayableVideoUrl:
        return videoUpdateErrorNoPlayableVideo;
      case VideoMetadataUpdateError.couldNotSign:
        return videoUpdateErrorCouldNotSign;
      case VideoMetadataUpdateError.publishRejected:
        return videoUpdateErrorPublishRejected;
      case VideoMetadataUpdateError.concurrentEditsOverLimit:
        return videoUpdateErrorConcurrentEditsOverLimit;
      case VideoMetadataUpdateError.generic:
        return videoUpdateErrorGeneric;
    }
  }
}
