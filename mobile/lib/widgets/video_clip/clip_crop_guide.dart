// ABOUTME: Shows the crop a clip is about to be cut to while it is picked —
// ABOUTME: over library thumbnails and the camera preview alike

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';

/// The crop a clip picked under this widget will be cut to, for every preview
/// below it to show.
///
/// Picking a clip for a split-screen cell is the use: the cell keeps only a
/// slice of the frame, and seeing which slice while choosing is the difference
/// between picking the right clip and finding out afterwards. The library and
/// the recorder each take the crop as a parameter and provide it here, since
/// the previews that draw it — library thumbnails, the camera viewfinder — sit
/// several layers deep in screens that know nothing about layouts.
class ClipCropGuide extends InheritedWidget {
  const ClipCropGuide({
    required this.aspectRatio,
    required super.child,
    super.key,
  });

  /// Width / height of the crop.
  final double aspectRatio;

  /// The nearest guide above [context], or `null` when nothing is cropped.
  static ClipCropGuide? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ClipCropGuide>();

  @override
  bool updateShouldNotify(ClipCropGuide oldWidget) =>
      aspectRatio != oldWidget.aspectRatio;
}

/// Dims everything outside the crop of [aspectRatio] that a centred cut of
/// footage shaped [contentAspectRatio] keeps.
///
/// The footage is assumed to cover this widget's box, centred — how a
/// thumbnail and the viewfinder both lay it out — so the crop can reach past
/// the box on one side; only the part inside it is drawn.
class ClipCropGuideOverlay extends StatelessWidget {
  const ClipCropGuideOverlay({
    required this.aspectRatio,
    required this.contentAspectRatio,
    super.key,
  });

  final double aspectRatio;
  final double contentAspectRatio;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _CropGuidePainter(
            aspectRatio: aspectRatio,
            contentAspectRatio: contentAspectRatio,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// The crop [ClipCropGuideOverlay] draws, in the coordinates of a box of
/// [size].
Rect clipCropGuideRect({
  required Size size,
  required double aspectRatio,
  required double contentAspectRatio,
}) {
  final content = size.aspectRatio > contentAspectRatio
      ? Size(size.width, size.width / contentAspectRatio)
      : Size(size.height * contentAspectRatio, size.height);
  final origin = Offset(
    (size.width - content.width) / 2,
    (size.height - content.height) / 2,
  );
  final crop = splitScreenCropRect(
    sourceAspectRatio: contentAspectRatio,
    cellAspectRatio: aspectRatio,
  );
  return Rect.fromLTWH(
    origin.dx + crop.left * content.width,
    origin.dy + crop.top * content.height,
    crop.width * content.width,
    crop.height * content.height,
  ).intersect(Offset.zero & size);
}

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter({
    required this.aspectRatio,
    required this.contentAspectRatio,
  });

  final double aspectRatio;
  final double contentAspectRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || aspectRatio <= 0 || contentAspectRatio <= 0) return;
    final crop = clipCropGuideRect(
      size: size,
      aspectRatio: aspectRatio,
      contentAspectRatio: contentAspectRatio,
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(crop);
    // Fixed media chrome: the guide always sits over footage, so it keeps the
    // same scrim and line in both appearances.
    canvas
      ..drawPath(outside, Paint()..color = VineTheme.scrim50)
      ..drawRect(
        crop.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = VineTheme.whiteText,
      );
  }

  @override
  bool shouldRepaint(_CropGuidePainter oldDelegate) =>
      oldDelegate.aspectRatio != aspectRatio ||
      oldDelegate.contentAspectRatio != contentAspectRatio;
}
