// ABOUTME: Defines viewer-independent reuse terms for original video audio.
// ABOUTME: Applies Divine's classic Vine reuse policy.
// ABOUTME: Preserves explicit creator terms and the owner exception.

import 'package:models/src/video_event.dart';

/// Viewer-independent reuse terms for a video's own original sound.
///
/// A `null` result means the marker is genuinely absent and a viewer-aware
/// policy may still grant the video's creator access to their own sound.
/// Verified classic Vine audio is reusable by default while rollout is enabled.
/// Its imported event marker is not a creator takedown; takedowns are enforced
/// separately through the action-time server policy.
bool? originalSoundReuseTerms(VideoEvent video) {
  if (video.isVerifiedArchive) {
    return video.archiveAudioReuseEnabled ? true : null;
  }
  return switch (video.audioReuseConsent) {
    AudioReuseConsent.granted => true,
    AudioReuseConsent.declined || AudioReuseConsent.invalid => false,
    AudioReuseConsent.unspecified => null,
  };
}
