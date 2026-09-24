// ABOUTME: Message action enum shared by DM long-press menu implementations.
// ABOUTME: Keeps action handling independent from the concrete overlay UI.

/// Actions available from the message long-press sheet.
enum MessageAction {
  /// Copy the message text to clipboard.
  copy,

  /// Copy the divine.video video URL embedded in the message.
  copyVideoUrl,

  /// Save the shared video to the device gallery.
  saveVideo,

  /// Play a received encrypted video DM.
  playVideo,

  /// Delete the message for everyone (NIP-09 kind 5).
  delete,

  /// Report the message.
  report,
}
