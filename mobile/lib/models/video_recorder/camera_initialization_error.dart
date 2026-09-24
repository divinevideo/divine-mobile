// ABOUTME: Stable, localizable classification of camera initialization failures.
// ABOUTME: State carries the reason; the UI maps it to context.l10n.

/// Why the camera could not be initialized.
///
/// `CameraService.initializationError` and `VideoRecorderBlocState` carry
/// one of these instead of a message. Before #3591 they carried
/// `'Camera initialization failed: $e'`, which rendered the platform
/// exception's `toString()` full-screen in the camera placeholder — untranslated,
/// and on Android including the native stack trace that `PlatformException`
/// interpolates from its `details` field.
///
/// The UI maps a reason to copy through `CameraInitializationErrorL10n`.
enum CameraInitializationError {
  /// The platform refused or failed to bring the camera up. Covers every
  /// hardware, permission-adjacent and plugin failure — the distinction
  /// between them is diagnostic, reaches the BLoC through `addError`, and is not
  /// something the user can act on differently.
  failed,

  /// This platform has no camera support at all, so there is nothing to retry.
  unsupportedPlatform,
}
