import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;

/// Selects the native video output for a supported desktop platform.
media_kit.VideoControllerConfiguration desktopVideoConfiguration(
  TargetPlatform platform,
) => media_kit.VideoControllerConfiguration(
  // Avoid unsupported decoder probes on Linux virtual GPUs while retaining
  // mpv's allowlisted hardware acceleration.
  hwdec: platform == TargetPlatform.linux ? 'auto-safe' : null,
  // Windows software output independently caps each axis at 1920x1080.
  // Its native hardware surface preserves portrait dimensions.
  enableHardwareAcceleration: platform == TargetPlatform.windows,
);
