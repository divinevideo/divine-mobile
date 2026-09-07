// ABOUTME: Defines viewer-independent reuse terms for original video audio.
// ABOUTME: Applies Divine's classic Vine reuse policy.
// ABOUTME: Preserves explicit creator terms and the owner exception.

import 'package:models/src/video_event.dart';

/// Viewer-independent reuse terms for a video's own original sound.
///
/// A `null` result means the marker is genuinely absent and a viewer-aware
/// policy may still grant the video's creator access to their own sound.
/// For an authoritatively verified classic Vine, the server may instead apply
/// Divine's legacy compatibility presumption. That is a product-policy grant,
/// not affirmative creator consent.
bool? originalSoundReuseTerms(VideoEvent video) {
  return switch (video.audioReuseConsent) {
    AudioReuseConsent.granted => true,
    AudioReuseConsent.declined || AudioReuseConsent.invalid => false,
    AudioReuseConsent.unspecified =>
      video.isVerifiedArchive && video.archiveAudioReuseEnabled ? true : null,
  };
}
