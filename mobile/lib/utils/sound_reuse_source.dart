// ABOUTME: Checks whether a pending sound approval still describes the video.

import 'package:models/models.dart';

/// Allows unrelated metadata edits, but not changes to the media or consent
/// on which the creator based the pending approval.
bool soundReuseSourceUnchanged(
  VideoEvent approved,
  VideoEvent current,
  String audioEventId,
) =>
    approved.addressableId == current.addressableId &&
    approved.videoUrl == current.videoUrl &&
    approved.sha256 == current.sha256 &&
    !current.isVerifiedArchive &&
    current.audioReuseConsent != AudioReuseConsent.invalid &&
    (approved.audioReuseConsent == current.audioReuseConsent ||
        (current.allowAudioReuse && current.audioEventId == audioEventId)) &&
    (current.audioEventId == audioEventId ||
        current.audioEventId == null && approved.audioEventId == null);
