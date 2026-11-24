// ABOUTME: Reason codes for a failed video metadata re-publish.
// ABOUTME: The service returns a code; the UI layer localizes it for display.

/// Why `VideoMetadataUpdateService.updateVideo` could not re-publish.
///
/// The arms differ in what the user can do about them, which is the reason
/// this is a code rather than a single generic message: signing in again,
/// retrying now, retrying later, reopening the video to trim it, and "this
/// video cannot be edited at all" are five different next steps.
enum VideoMetadataUpdateError {
  /// No signed-in identity, so the replacement event cannot be authored.
  notAuthenticated,

  /// The original event carries no HTTP video URL to carry forward, so a
  /// lossless replacement is impossible. Retrying cannot help.
  noPlayableVideoUrl,

  /// The signer refused or returned nothing.
  couldNotSign,

  /// The event was signed but no relay accepted it.
  publishRejected,

  /// This edit and a newer one from another device together go over the
  /// collaborator or hashtag limit. Saving the same edit again fails the same
  /// way; reopening the video loads the other device's changes to trim.
  concurrentEditsOverLimit,

  /// Anything else. Kept last so a new arm is a compile error in the
  /// localization switch rather than a silent fallthrough.
  generic,
}
