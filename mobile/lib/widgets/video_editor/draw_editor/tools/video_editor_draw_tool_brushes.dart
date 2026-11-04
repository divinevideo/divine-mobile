// ABOUTME: Buttons for the draw editor's own brushes: neon, rainbow and
// ABOUTME: calligraphy, each a pen icon in the look of the stroke it draws.

import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/editor_draw_brushes.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_pencil.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_button.dart';

/// Button for selecting the neon brush.
///
/// Displays a pencil whose tip glows in the selected color.
class DrawToolNeon extends StatelessWidget {
  /// Creates a neon brush button.
  const DrawToolNeon({
    required this.isSelected,
    required this.color,
    required this.onTap,
    super.key,
  });

  /// Whether this tool is currently selected.
  final bool isSelected;

  /// The color the tip glows in.
  final Color color;

  /// Callback invoked when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VideoEditorDrawItemButton(
      onTap: onTap,
      isSelected: isSelected,
      semanticLabel: context.l10n.videoEditorDrawToolNeonSemanticLabel,
      painter: _NeonPencilPainter(color: color),
    );
  }
}

class _NeonPencilPainter extends CustomPainter {
  const _NeonPencilPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = pencilIconTipPath(size);
    canvas
      ..drawPath(
        tip,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(.normal, 5),
      )
      ..drawPath(
        tip,
        Paint()
          ..color = Color.lerp(
            color,
            VineTheme.whiteText,
            NeonBrushPathBuilder.coreLightening,
          )!,
      )
      ..drawPath(
        pencilIconBodyPath(size),
        Paint()..color = VineTheme.whiteText,
      );
  }

  @override
  bool shouldRepaint(covariant _NeonPencilPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Button for selecting the rainbow brush.
///
/// Displays a pencil striped in the rainbow's colors from its tip down.
class DrawToolRainbow extends StatelessWidget {
  /// Creates a rainbow brush button.
  const DrawToolRainbow({
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
      semanticLabel: context.l10n.videoEditorDrawToolRainbowSemanticLabel,
      painter: const _RainbowPencilPainter(),
    );
  }
}

class _RainbowPencilPainter extends CustomPainter {
  const _RainbowPencilPainter();

  /// How far down the pencil the rainbow runs before it turns white.
  static const double _rainbowHeight = 52;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      ...RainbowBrushPathBuilder.colors,
      VineTheme.whiteText,
    ];
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(0, _rainbowHeight),
        colors,
        [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)],
      );
    canvas
      ..drawPath(pencilIconTipPath(size), paint)
      ..drawPath(pencilIconBodyPath(size), paint);
  }

  @override
  bool shouldRepaint(covariant _RainbowPencilPainter oldDelegate) => false;
}

/// Button for selecting the calligraphy brush.
///
/// Displays a fountain pen with a nib in the selected color.
class DrawToolCalligraphy extends StatelessWidget {
  /// Creates a calligraphy brush button.
  const DrawToolCalligraphy({
    required this.isSelected,
    required this.color,
    required this.onTap,
    super.key,
  });

  /// Whether this tool is currently selected.
  final bool isSelected;

  /// The color of the nib.
  final Color color;

  /// Callback invoked when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VideoEditorDrawItemButton(
      onTap: onTap,
      isSelected: isSelected,
      semanticLabel: context.l10n.videoEditorDrawToolCalligraphySemanticLabel,
      painter: _FountainPenPainter(color: color),
    );
  }
}

class _FountainPenPainter extends CustomPainter {
  const _FountainPenPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    const nibHalfWidth = 11.0;
    const shoulderY = 20.0;
    const nibBottom = 30.0;
    const bodyTop = nibBottom + 2;
    const bodyWidth = 26.0;

    final nib = Path()
      ..moveTo(centerX, 0)
      ..quadraticBezierTo(
        centerX - 3,
        shoulderY * 0.45,
        centerX - nibHalfWidth,
        shoulderY,
      )
      ..lineTo(centerX - nibHalfWidth, nibBottom)
      ..lineTo(centerX + nibHalfWidth, nibBottom)
      ..lineTo(centerX + nibHalfWidth, shoulderY)
      ..quadraticBezierTo(centerX + 3, shoulderY * 0.45, centerX, 0)
      ..close();
    final slitColor = Color.lerp(color, VineTheme.backgroundColor, 0.6)!;

    canvas
      ..drawPath(nib, Paint()..color = color)
      ..drawLine(
        Offset(centerX, 4),
        Offset(centerX, shoulderY - 2),
        Paint()
          ..color = slitColor
          ..strokeWidth = 1.5
          ..strokeCap = .round,
      )
      ..drawCircle(Offset(centerX, shoulderY), 2.2, Paint()..color = slitColor)
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centerX - bodyWidth / 2,
            bodyTop,
            bodyWidth,
            size.height - bodyTop,
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = VineTheme.whiteText,
      );
  }

  @override
  bool shouldRepaint(covariant _FountainPenPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
