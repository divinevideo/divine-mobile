// ABOUTME: Lets the color mask preview be tapped to choose the color to
// ABOUTME: remove, reading a small patch of footage under the finger.

import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_snapshot.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reads the footage under a tap on [child] and hands it to [onPatchPicked].
///
/// A patch rather than one pixel: the key's color and how far it reaches are
/// both measured from it, the way auto-detect measures the frame border.
///
/// [child] has to be the footage itself, below the key's filter: the point is
/// to pick the screen color, which the keyed picture no longer shows. Taps
/// that land while a read is still running are dropped rather than queued, so
/// a quick double tap cannot apply two colors out of order.
///
/// A tap is read from raw pointer events rather than a gesture recognizer, so
/// it reaches the read even when [child] has gestures of its own: the camera
/// preview always registers a tap for focus, and the inner of two tap
/// recognizers wins the gesture arena. Only one finger lifted where it went
/// down counts, so a pinch or a drag never picks.
class ChromaKeyTapToPick extends StatefulWidget {
  const ChromaKeyTapToPick({
    required this.child,
    required this.onPatchPicked,
    @visibleForTesting this.capture = captureEyedropperSnapshot,
    super.key,
  });

  final Widget child;

  /// Receives the straight RGBA pixels of the patch under the tap.
  final ValueChanged<Uint8List> onPatchPicked;

  /// Captures [child] for the read. Tests replace it to supply known pixels.
  final EyedropperCapture capture;

  /// Image pixels per logical pixel of the capture.
  ///
  /// One is plenty: the read averages a few pixels around the tap, and a
  /// coarser capture spreads that average over more of a noisy video frame
  /// while costing a fraction of a full-resolution one.
  static const double capturePixelRatio = 1;

  /// Image pixels read on each side of the tapped one: a patch about as wide
  /// as a fingertip at [capturePixelRatio].
  static const int patchRadius = 6;

  @override
  State<ChromaKeyTapToPick> createState() => _ChromaKeyTapToPickState();
}

class _ChromaKeyTapToPickState extends State<ChromaKeyTapToPick> {
  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'ChromaKeyTapToPick');
  bool _isReading = false;

  /// The pointers currently down on [ChromaKeyTapToPick.child].
  final _pointersDown = <int>{};

  /// Where the single finger of a possible tap went down, or `null` once the
  /// touch stopped being one: a second finger, or movement past [kTouchSlop].
  Offset? _tapStart;

  void _onPointerDown(PointerDownEvent event) {
    _pointersDown.add(event.pointer);
    _tapStart = _pointersDown.length == 1 ? event.localPosition : null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _tapStart;
    if (start != null && (event.localPosition - start).distance > kTouchSlop) {
      _tapStart = null;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final isTap = _pointersDown.length == 1 && _tapStart != null;
    _pointersDown.remove(event.pointer);
    if (_pointersDown.isEmpty) _tapStart = null;
    if (!isTap) return;
    // A frame that cannot be read leaves the key as it was; the swatch under
    // Fine-tune still sets it by hand.
    runDetached(
      _pick(event.localPosition),
      'read the color mask preview',
      logName: 'ChromaKeyTapToPick',
      category: LogCategory.video,
    );
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointersDown.remove(event.pointer);
    _tapStart = null;
  }

  Future<void> _pick(Offset position) async {
    if (_isReading) return;
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;

    _isReading = true;
    try {
      final snapshot = await widget.capture(
        boundary,
        pixelRatio: ChromaKeyTapToPick.capturePixelRatio,
      );
      if (snapshot == null) {
        Log.warning(
          'Color mask tap-to-pick could not capture the preview',
          name: 'ChromaKeyTapToPick',
          category: LogCategory.video,
        );
        return;
      }
      final Uint8List patch;
      try {
        patch = snapshot.patchAround(
          position,
          radius: ChromaKeyTapToPick.patchRadius,
        );
      } finally {
        snapshot.dispose();
      }
      if (mounted) widget.onPatchPicked(patch);
    } finally {
      _isReading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: RepaintBoundary(key: _boundaryKey, child: widget.child),
    );
  }
}
