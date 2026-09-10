// ABOUTME: Button for selecting the pencil drawing tool.
// ABOUTME: Displays a pencil icon with colored tip.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_button.dart';

/// Button for selecting the pencil drawing tool.
///
/// Displays a pencil icon with colored tip.
class DrawToolPencil extends StatelessWidget {
  /// Creates a pencil tool button.
  const DrawToolPencil({
    required this.isSelected,
    required this.color,
    required this.onTap,
    super.key,
  });

  /// Whether this tool is currently selected.
  final bool isSelected;

  /// The color to display on the pencil tip.
  final Color color;

  /// Callback invoked when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VideoEditorDrawItemButton(
      onTap: onTap,
      isSelected: isSelected,
      semanticLabel: context.l10n.videoEditorDrawToolPencilSemanticLabel,
      painter: _PencilPainter(color: color),
    );
  }
}

/// Custom painter that draws a pencil icon.
///
/// The pencil has a triangular tip, a funnel section, and rectangular body.
class _PencilPainter extends CustomPainter {
  const _PencilPainter({required this.color});

  /// The color to use for the pencil tip.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    const gap = 2.0;
    const radius = Radius.circular(2);

    // Dimensions
    const tipWidth = 9.0;
    const tipHeight = 12.0;
    const funnelTopWidth = 11.0;
    const funnelBottomWidth = 24.0;
    const funnelHeight = 23.0;
    const bodyWidth = 24.0;

    // Pre-computed half-widths to avoid repeated division
    const halfTipWidth = tipWidth / 2;
    const halfFunnelTopWidth = funnelTopWidth / 2;
    const halfFunnelBottomWidth = funnelBottomWidth / 2;
    const halfBodyWidth = bodyWidth / 2;

    const tipBottom = tipHeight;
    const funnelTop = tipBottom + gap;
    const funnelBottom = funnelTop + funnelHeight;
    const bodyTop = funnelBottom + gap;

    // Part 1: Tip (colored) - rounded triangle
    final tipPaint = Paint()
      ..color = color
      ..style = .fill;

    final tipPath = Path()
      ..moveTo(centerX - halfTipWidth + 1, tipBottom) // Bottom left
      ..quadraticBezierTo(
        centerX - halfTipWidth,
        tipBottom - 1,
        centerX - halfTipWidth + 0.5,
        tipBottom - 2,
      )
      ..lineTo(centerX - 1, 2) // Line to near top
      ..quadraticBezierTo(
        centerX,
        0, // Rounded tip
        centerX + 1,
        2,
      )
      ..lineTo(centerX + halfTipWidth - 0.5, tipBottom - 2)
      ..quadraticBezierTo(
        centerX + halfTipWidth,
        tipBottom - 1,
        centerX + halfTipWidth - 1,
        tipBottom,
      )
      ..close();
    canvas.drawPath(tipPath, tipPaint);

    // Part 2: Funnel/cone (white) - rounded trapezoid
    // Combined with body since both are white
    final whitePaint = Paint()
      ..color = VineTheme.whiteText
      ..style = .fill;

    final funnelPath = Path()
      ..moveTo(centerX - halfFunnelTopWidth + 2, funnelTop)
      ..quadraticBezierTo(
        centerX - halfFunnelTopWidth,
        funnelTop,
        centerX - halfFunnelTopWidth,
        funnelTop + 2,
      )
      ..lineTo(centerX - halfFunnelBottomWidth, funnelBottom - 2)
      ..quadraticBezierTo(
        centerX - halfFunnelBottomWidth,
        funnelBottom,
        centerX - halfFunnelBottomWidth + 2,
        funnelBottom,
      )
      ..lineTo(centerX + halfFunnelBottomWidth - 2, funnelBottom)
      ..quadraticBezierTo(
        centerX + halfFunnelBottomWidth,
        funnelBottom,
        centerX + halfFunnelBottomWidth,
        funnelBottom - 2,
      )
      ..lineTo(centerX + halfFunnelTopWidth, funnelTop + 2)
      ..quadraticBezierTo(
        centerX + halfFunnelTopWidth,
        funnelTop,
        centerX + halfFunnelTopWidth - 2,
        funnelTop,
      )
      ..close()
      // Part 3: Body - rounded rectangle (only top corners)
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centerX - halfBodyWidth,
            bodyTop,
            bodyWidth,
            size.height - bodyTop,
          ),
          topLeft: radius,
          topRight: radius,
        ),
      );
    canvas.drawPath(funnelPath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant _PencilPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
