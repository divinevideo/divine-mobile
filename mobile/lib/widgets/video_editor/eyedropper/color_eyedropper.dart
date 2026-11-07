// ABOUTME: Full-area overlay that freezes what a repaint boundary shows and
// ABOUTME: picks the color under the finger, with a magnifying loupe.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_snapshot.dart';
import 'package:unified_logger/unified_logger.dart';

/// Picks a color off what the [RepaintBoundary] keyed by [sourceKey] shows.
///
/// On open it captures the boundary once and shows that frame still, in the
/// boundary's place, so the colors under the finger cannot change while the
/// video keeps playing — and so the pick reads the boundary's own pixels, not
/// whatever is drawn over them. Touching and dragging shows a loupe above the
/// finger; lifting it picks the color under the finger.
///
/// Lay this over at least the boundary: everything it covers outside the
/// boundary is dimmed, and a touch there picks from the boundary's nearest
/// edge. The overlay takes every touch, so nothing below it reacts while a
/// color is being picked. Back navigation is left to the host, which knows
/// what else a back gesture would close.
class ColorEyedropper extends StatefulWidget {
  /// Creates an eyedropper over the boundary keyed by [sourceKey].
  const ColorEyedropper({
    required this.sourceKey,
    required this.onColorPicked,
    required this.onCancel,
    this.sourceBorderRadius = BorderRadius.zero,
    this.capture = captureEyedropperSnapshot,
    super.key,
  });

  /// The key of the [RepaintBoundary] whose pixels are picked from.
  ///
  /// The first render object below the key must be that boundary, so a
  /// [KeyedSubtree] directly around it works as well as the boundary's own
  /// key.
  final GlobalKey sourceKey;

  /// Called with the opaque color under the finger when it is lifted.
  final ValueChanged<Color> onColorPicked;

  /// Called when the user closes the eyedropper without picking, and when
  /// the boundary cannot be captured.
  final VoidCallback onCancel;

  /// The rounding the boundary is shown with, so the still frame drawn in
  /// its place has the same corners.
  final BorderRadius sourceBorderRadius;

  /// Captures the boundary. Tests replace it, through
  /// [EyedropperSourceRegion.capture] too, to supply known pixels.
  final EyedropperCapture capture;

  @override
  State<ColorEyedropper> createState() => _ColorEyedropperState();
}

class _ColorEyedropperState extends State<ColorEyedropper> {
  EyedropperSnapshot? _snapshot;

  /// Where the boundary sits in this overlay.
  Rect? _sourceRect;

  /// The pointer picking a color; others are ignored until it lifts.
  int? _pointer;

  /// Where that pointer is, in this overlay.
  Offset? _touch;

  static const _logName = 'ColorEyedropper';

  @override
  void initState() {
    super.initState();
    // After the first frame, once this overlay has a size to map the
    // boundary into.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => runDetached(
        _capture(),
        'capture eyedropper source',
        logName: _logName,
        category: LogCategory.video,
      ),
    );
  }

  Future<void> _capture() async {
    if (!mounted) return;
    final boundary = widget.sourceKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      _giveUp('the source is not a RepaintBoundary');
      return;
    }
    final EyedropperSnapshot? snapshot;
    try {
      snapshot = await widget.capture(
        boundary,
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (error, stackTrace) {
      Log.error(
        'Eyedropper could not capture its source',
        name: _logName,
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      if (mounted) _giveUp('the capture failed');
      return;
    }
    if (!mounted) {
      snapshot?.dispose();
      return;
    }
    final overlay = context.findRenderObject();
    if (snapshot == null || overlay is! RenderBox || !boundary.attached) {
      snapshot?.dispose();
      _giveUp('there was nothing to capture');
      return;
    }
    setState(() {
      _snapshot = snapshot;
      _sourceRect = MatrixUtils.transformRect(
        boundary.getTransformTo(overlay),
        Offset.zero & boundary.size,
      );
    });
  }

  void _giveUp(String reason) {
    Log.warning(
      'Eyedropper closed because $reason',
      name: _logName,
      category: LogCategory.video,
    );
    widget.onCancel();
  }

  @override
  void dispose() {
    _snapshot?.dispose();
    super.dispose();
  }

  /// [position] in this overlay, moved into the boundary's area.
  Offset _clampToSource(Offset position, Rect source) => Offset(
    position.dx.clamp(source.left, source.right),
    position.dy.clamp(source.top, source.bottom),
  );

  /// [position] in this overlay, in logical pixels of the boundary.
  Offset _toSource(Offset position, Rect source, EyedropperSnapshot snapshot) {
    final clamped = _clampToSource(position, source);
    return Offset(
      (clamped.dx - source.left) * snapshot.size.width / source.width,
      (clamped.dy - source.top) * snapshot.size.height / source.height,
    );
  }

  Color? _colorAt(Offset position) {
    final snapshot = _snapshot;
    final source = _sourceRect;
    if (snapshot == null || source == null || source.isEmpty) return null;
    return snapshot.colorAt(_toSource(position, source, snapshot));
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    setState(() {
      _pointer = event.pointer;
      _touch = event.localPosition;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    setState(() => _touch = event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final color = _colorAt(event.localPosition);
    setState(() {
      _pointer = null;
      _touch = null;
    });
    if (color != null) widget.onColorPicked(color);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    setState(() {
      _pointer = null;
      _touch = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final source = _sourceRect;
    final touch = _touch;

    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Repaints only when the capture lands, not on every move.
              RepaintBoundary(
                child: CustomPaint(
                  painter: _StillSourcePainter(
                    snapshot: snapshot,
                    source: source,
                    borderRadius: widget.sourceBorderRadius,
                  ),
                ),
              ),
              if (snapshot != null && source != null && touch != null)
                CustomPaint(
                  painter: _LoupePainter(
                    snapshot: snapshot,
                    sourcePosition: _toSource(touch, source, snapshot),
                    anchor: _clampToSource(touch, source),
                    pixelsPerLogical: snapshot.image.width / source.width,
                    color: _colorAt(touch),
                  ),
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: _TopBar(onCancel: widget.onCancel),
        ),
      ],
    );
  }
}

/// The close button and the instruction, where the host's toolbar sits.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      // Same inset as the editor's toolbars, so the close button lands where
      // their close button was.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          spacing: 12,
          children: [
            DivineIconButton(
              icon: DivineIconName.x,
              size: DivineIconButtonSize.small,
              type: DivineIconButtonType.ghostOverMedia,
              semanticLabel:
                  context.l10n.videoEditorEyedropperCancelSemanticLabel,
              onPressed: onCancel,
            ),
            Expanded(
              // As tall as the pill: an unbounded Center would stretch the row
              // over the whole overlay and drop the bar to its middle.
              child: Center(
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: VineTheme.scrim65,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      context.l10n.videoEditorEyedropperHint,
                      textAlign: TextAlign.center,
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.whiteText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Balances the close button, so the instruction stays centered.
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

/// Paints the captured frame in the boundary's place and dims everything
/// around it.
class _StillSourcePainter extends CustomPainter {
  const _StillSourcePainter({
    required this.snapshot,
    required this.source,
    required this.borderRadius,
  });

  final EyedropperSnapshot? snapshot;
  final Rect? source;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final snapshot = this.snapshot;
    final source = this.source;
    if (snapshot == null || source == null) return;

    final frame = borderRadius.toRRect(source);
    canvas
      ..drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRRect(frame),
        Paint()..color = VineTheme.scrim65,
      )
      ..save()
      ..clipRRect(frame)
      ..drawImageRect(
        snapshot.image,
        Offset.zero &
            Size(
              snapshot.image.width.toDouble(),
              snapshot.image.height.toDouble(),
            ),
        source,
        Paint()..filterQuality = FilterQuality.low,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_StillSourcePainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.source != source ||
      oldDelegate.borderRadius != borderRadius;
}

/// The magnifier over the finger: the pixels around the touched point blown
/// up, the sampled block outlined in the middle, and a ring in the color that
/// lifting the finger would pick.
class _LoupePainter extends CustomPainter {
  const _LoupePainter({
    required this.snapshot,
    required this.sourcePosition,
    required this.anchor,
    required this.pixelsPerLogical,
    required this.color,
  });

  /// Diameter of the magnified area.
  static const double _diameter = 112;

  /// How wide the ring showing the picked color is.
  static const double _ringWidth = 8;

  /// How far above the finger the loupe sits, from the finger to the loupe's
  /// lower edge, so the finger never covers it.
  static const double _gap = 32;

  /// Keeps the loupe this far inside the overlay's edges.
  static const double _margin = 8;

  /// How much of the boundary the loupe shows across, in logical pixels.
  static const double _span = 16;

  final EyedropperSnapshot snapshot;

  /// The touched point, in logical pixels of the captured boundary.
  final Offset sourcePosition;

  /// The touched point in the overlay, which the loupe is placed against.
  final Offset anchor;

  /// Image pixels per logical pixel of the overlay.
  final double pixelsPerLogical;

  /// The color lifting the finger would pick; `null` over nothing painted.
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = _diameter / 2;
    const outer = radius + _ringWidth;
    final center = _center(size, outer);
    final lens = Rect.fromCircle(center: center, radius: radius);

    canvas
      ..drawCircle(
        center,
        outer + 1,
        Paint()
          ..color = VineTheme.scrim50
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
      )
      ..save()
      ..clipPath(Path()..addOval(lens))
      ..drawRect(lens, Paint()..color = VineTheme.backgroundCamera);

    // The touched image pixel sits in the middle of the lens.
    final pixel = snapshot.pixelAt(sourcePosition);
    final across = math.max(1, (_span * pixelsPerLogical).round());
    final scale = _diameter / across;
    final shown = Rect.fromCenter(
      center: Offset(pixel.x + 0.5, pixel.y + 0.5),
      width: across.toDouble(),
      height: across.toDouble(),
    );
    final visible = shown.intersect(
      Offset.zero &
          Size(
            snapshot.image.width.toDouble(),
            snapshot.image.height.toDouble(),
          ),
    );
    if (!visible.isEmpty) {
      canvas.drawImageRect(
        snapshot.image,
        visible,
        Rect.fromLTWH(
          lens.left + (visible.left - shown.left) * scale,
          lens.top + (visible.top - shown.top) * scale,
          visible.width * scale,
          visible.height * scale,
        ),
        // Hard pixel edges: the point of the lens is to see single pixels.
        Paint()..filterQuality = FilterQuality.none,
      );
    }

    // The block that is averaged into the pick.
    const sampled = EyedropperSnapshot.sampleRadius * 2 + 1;
    final block = Rect.fromCenter(
      center: center,
      width: sampled * scale,
      height: sampled * scale,
    );
    canvas
      ..drawRect(
        block.inflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = VineTheme.backgroundCamera,
      )
      ..drawRect(
        block,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = VineTheme.whiteText,
      )
      ..restore();

    final ring = color;
    if (ring != null) {
      canvas.drawCircle(
        center,
        radius + _ringWidth / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringWidth
          ..color = ring,
      );
    }
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = VineTheme.whiteText;
    canvas
      ..drawCircle(center, radius, border)
      ..drawCircle(center, outer, border);
  }

  /// Above the finger, kept inside [size]; below it when there is no room
  /// above.
  Offset _center(Size size, double outer) {
    final reach = outer + _margin;
    final x = size.width <= reach * 2
        ? size.width / 2
        : anchor.dx.clamp(reach, size.width - reach);
    var y = anchor.dy - _gap - outer;
    if (y < reach) y = anchor.dy + _gap + outer;
    if (size.height > reach * 2) y = y.clamp(reach, size.height - reach);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(_LoupePainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.sourcePosition != sourcePosition ||
      oldDelegate.anchor != anchor ||
      oldDelegate.pixelsPerLogical != pixelsPerLogical ||
      oldDelegate.color != color;
}
