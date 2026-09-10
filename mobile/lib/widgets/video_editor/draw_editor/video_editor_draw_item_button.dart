// ABOUTME: Reusable button widget for draw tool selection.
// ABOUTME: Displays a CustomPainter icon that animates vertically when selected.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// A reusable button widget for draw tool selection.
///
/// Displays a [CustomPainter] icon that animates vertically when selected.
class VideoEditorDrawItemButton extends StatelessWidget {
  /// Creates a draw tool button.
  const VideoEditorDrawItemButton({
    required this.onTap,
    required this.isSelected,
    required this.painter,
    required this.semanticLabel,
    super.key,
  });

  /// Callback invoked when the button is tapped.
  final VoidCallback onTap;

  /// Whether this tool is currently selected.
  final bool isSelected;

  /// The painter used to draw the tool icon.
  final CustomPainter painter;

  /// Accessibility label for screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    final height = 120.0 + bottomSafeArea;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: VideoEditorConstants.drawItemWidth,
          padding: const .only(top: 12),
          transform: .translationValues(0, isSelected ? 0 : 18, 0),
          child: CustomPaint(
            size: Size(VideoEditorConstants.drawItemWidth, height),
            painter: painter,
          ),
        ),
      ),
    );
  }
}
