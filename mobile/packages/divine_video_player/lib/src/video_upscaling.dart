/// How a texture player scales video frames up to the size it is shown at.
///
/// Flutter draws a video texture into its on-screen rectangle with bilinear
/// sampling, so a 720p rendition stretched across a 1080-wide screen goes
/// soft. With [lanczos] the native player does that upscale itself, before
/// Flutter sees the frame, with a Lanczos-3 filter at the exact pixel size
/// the texture is shown at, and Flutter's draw becomes a 1:1 copy.
///
/// Only Android acts on this today, and only for texture players; a device
/// with too little memory keeps [off] whatever is asked for.
enum VideoUpscaling {
  /// Flutter scales the frame when it draws the texture.
  off,

  /// The native player scales the frame with Lanczos-3 before Flutter
  /// draws it.
  lanczos;

  /// Stable wire value sent across the platform channel.
  String get wireValue => name;
}
