// ABOUTME: Button for selecting the marker/highlighter tool.
// ABOUTME: Displays a marker pen icon with semi-transparent colored tip.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_button.dart';

/// Button for selecting the marker/highlighter tool.
///
/// Displays a marker pen icon with colored tip (semi-transparent).
class DrawToolMarker extends StatelessWidget {
  /// Creates a marker tool button.
  const DrawToolMarker({
    required this.isSelected,
    required this.color,
    required this.onTap,
    super.key,
  });

  /// Whether this tool is currently selected.
  final bool isSelected;

  /// The color to display on the marker tip.
  final Color color;

  /// Callback invoked when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VideoEditorDrawItemButton(
      onTap: onTap,
      isSelected: isSelected,
      semanticLabel: context.l10n.videoEditorDrawToolMarkerSemanticLabel,
      painter: _MarkerPainter(color: color),
    );
  }
}

/// Custom painter that draws a marker pen icon.
///
/// The marker has a diagonal parallelogram tip, a funnel section, and body.
class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({required this.color});

  /// The color to use for the marker tip.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    const gap = 2.0;
    const radius = Radius.circular(2);

    // Dimensions
    const tipWidth = 14.0;
    const tipHeightLeft = 7.0;
    const tipHeightRight = 14.0;

    const funnelTopWidth = 14.0;
    const funnelBottomWidth = 24.0;
    const funnelHeight = 20.0;

    const funnelRectHeight = 8.0; // Rectangular part at top
    const bodyWidth = 24.0;

    // Pre-computed half-widths to avoid repeated division
    const halfTipWidth = tipWidth / 2;
    const halfFunnelTopWidth = funnelTopWidth / 2;
    const halfFunnelBottomWidth = funnelBottomWidth / 2;
    const halfBodyWidth = bodyWidth / 2;

    const tipBottom = tipHeightRight;
    const funnelTop = tipBottom + gap;
    const funnelRectBottom = funnelTop + funnelRectHeight;
    const funnelBottom = funnelTop + funnelHeight;
    const bodyTop = funnelBottom + gap;

    // Part 1: Tip (colored) - diagonal parallelogram
    // (left 7 high, right 14 high)
    final tipPaint = Paint()
      ..color = color.withAlpha(220)
      ..style = .fill;

    final tipPath = Path()
      // Bottom left corner
      ..moveTo(centerX - halfTipWidth + 2, tipBottom)
      ..quadraticBezierTo(
        centerX - halfTipWidth,
        tipBottom,
        centerX - halfTipWidth,
        tipBottom - 2,
      )
      // Left side (7 high)
      ..lineTo(centerX - halfTipWidth, tipBottom - tipHeightLeft + 2)
      ..quadraticBezierTo(
        centerX - halfTipWidth,
        tipBottom - tipHeightLeft,
        centerX - halfTipWidth + 2,
        tipBottom - tipHeightLeft,
      )
      // Diagonal top edge to right
      ..lineTo(centerX + halfTipWidth - 2, 0)
      ..quadraticBezierTo(centerX + halfTipWidth, 0, centerX + halfTipWidth, 2)
      // Right side (14 high)
      ..lineTo(centerX + halfTipWidth, tipBottom - 2)
      ..quadraticBezierTo(
        centerX + halfTipWidth,
        tipBottom,
        centerX + halfTipWidth - 2,
        tipBottom,
      )
      ..close();
    canvas.drawPath(tipPath, tipPaint);

    // Part 2: Funnel/cone (white) - with kink (rect top + diagonal bottom)
    // Combined with body since both are white
    final whitePaint = Paint()
      ..color = VineTheme.whiteText
      ..style = .fill;

    final funnelPath = Path()
      // Start top-left, rounded corner
      ..moveTo(centerX - halfFunnelTopWidth + 2, funnelTop)
      ..quadraticBezierTo(
        centerX - halfFunnelTopWidth,
        funnelTop,
        centerX - halfFunnelTopWidth,
        funnelTop + 2,
      )
      // Left side - straight down for rectangular part
      ..lineTo(centerX - halfFunnelTopWidth, funnelRectBottom)
      // Diagonal to bottom-left corner
      ..lineTo(centerX - halfFunnelBottomWidth, funnelBottom - 2)
      ..quadraticBezierTo(
        centerX - halfFunnelBottomWidth,
        funnelBottom,
        centerX - halfFunnelBottomWidth + 2,
        funnelBottom,
      )
      // Bottom edge
      ..lineTo(centerX + halfFunnelBottomWidth - 2, funnelBottom)
      ..quadraticBezierTo(
        centerX + halfFunnelBottomWidth,
        funnelBottom,
        centerX + halfFunnelBottomWidth,
        funnelBottom - 2,
      )
      // Diagonal to top-right rectangular part
      ..lineTo(centerX + halfFunnelTopWidth, funnelRectBottom)
      // Right side - straight up for rectangular part
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
  bool shouldRepaint(covariant _MarkerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
