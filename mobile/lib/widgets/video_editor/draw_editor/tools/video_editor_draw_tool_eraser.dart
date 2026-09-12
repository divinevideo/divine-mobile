// ABOUTME: Button for selecting the eraser tool.
// ABOUTME: Displays a pink-tipped eraser icon.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_button.dart';

/// Button for selecting the eraser tool.
///
/// Displays a pink-tipped eraser icon.
class DrawToolEraser extends StatelessWidget {
  /// Creates an eraser tool button.
  const DrawToolEraser({
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// Whether this tool is currently selected.
  final bool isSelected;

  /// Callback invoked when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VideoEditorDrawItemButton(
      onTap: onTap,
      isSelected: isSelected,
      semanticLabel: context.l10n.videoEditorDrawToolEraserSemanticLabel,
      painter: const _EraserPainter(),
    );
  }
}

/// Custom painter that draws an eraser icon with pink top and white body.
class _EraserPainter extends CustomPainter {
  const _EraserPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    const gap = 2.0;
    const radius = Radius.circular(2);
    const bigRadius = Radius.circular(8);

    // Dimensions
    const topWidth = 30.0;
    const topHeight = 16.0;
    const bodyWidth = 32.0;

    const topBottom = topHeight;
    const bodyTop = topBottom + gap;

    // Part 1: Top (pink) - rectangle with strongly rounded top-left corner
    final topPaint = Paint()
      ..color = const Color(0xFFFFDEEA)
      ..style = PaintingStyle.fill;

    final topRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(centerX - topWidth / 2, 0, topWidth, topHeight),
      topLeft: bigRadius,
      topRight: radius,
      bottomLeft: radius,
      bottomRight: radius,
    );
    canvas.drawRRect(topRect, topPaint);

    // Part 2: Body (white) - rounded rectangle (only top corners)
    final bodyPaint = Paint()
      ..color = VineTheme.whiteText
      ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        centerX - bodyWidth / 2,
        bodyTop,
        bodyWidth,
        size.height - bodyTop,
      ),
      topLeft: radius,
      topRight: radius,
    );
    canvas.drawRRect(bodyRect, bodyPaint);
  }

  @override
  bool shouldRepaint(covariant _EraserPainter oldDelegate) {
    return false;
  }
}
