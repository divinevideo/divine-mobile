// ABOUTME: Fallback placeholder widget displayed when camera is unavailable
// ABOUTME: Plain dark surface while initializing, icon + message on error

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Fallback preview widget for when camera is not available.
///
/// While the camera is still initializing (no [errorMessage]) this is a
/// plain dark surface — flashing an icon for the split second before the
/// preview arrives looks broken. The icon and message only appear when
/// initialization actually failed.
class VideoRecorderCameraPlaceholder extends StatelessWidget {
  /// Creates a camera placeholder widget.
  const VideoRecorderCameraPlaceholder({super.key, this.errorMessage});

  /// Optional error message to display when camera initialization fails.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF141414),
      child: errorMessage == null
          ? null
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 56,
                    color: context.vineColors.onSurfaceVariant,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
