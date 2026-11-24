import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;

/// Selects the native video output for a supported desktop platform.
media_kit.VideoControllerConfiguration desktopVideoConfiguration(
  TargetPlatform platform,
) => media_kit.VideoControllerConfiguration(
  // Windows software output independently caps each axis at 1920x1080.
  // Its native hardware surface preserves portrait dimensions.
  enableHardwareAcceleration: platform == TargetPlatform.windows,
);
