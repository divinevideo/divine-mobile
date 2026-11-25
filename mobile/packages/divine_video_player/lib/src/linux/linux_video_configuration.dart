import 'package:media_kit_video/media_kit_video.dart' as media_kit;

/// Selects the media_kit video output for the Linux backend.
media_kit.VideoControllerConfiguration linuxVideoConfiguration() =>
    const media_kit.VideoControllerConfiguration(
      // Avoid unsupported decoder probes on Linux virtual GPUs while
      // retaining mpv's allowlisted hardware acceleration.
      hwdec: 'auto-safe',
      enableHardwareAcceleration: false,
    );
