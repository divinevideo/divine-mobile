// ABOUTME: Defines viewer-independent reuse terms for original video audio.
// ABOUTME: Preserves classic Vine compatibility while honoring creator terms.

import 'package:models/src/video_event.dart';

/// Viewer-independent reuse terms for a video's own original sound.
///
/// A `null` result means the marker is genuinely absent and a viewer-aware
/// policy may still grant the video's creator access to their own sound.
bool? originalSoundReuseTerms(VideoEvent video) {
  return switch (video.audioReuseConsent) {
    AudioReuseConsent.granted => true,
    AudioReuseConsent.declined || AudioReuseConsent.invalid => false,
    // TODO(NotThatKindOfDrLiz): Replace this compatibility signal with
    // verified archive provenance after #8466 ships.
    AudioReuseConsent.unspecified => video.isOriginalVine ? true : null,
  };
}
