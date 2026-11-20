// ABOUTME: The second camera's small window in the viewfinder during
// ABOUTME: dual-camera capture: tap swaps, long press reshapes, pinch resizes

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_camera/divine_camera.dart'
    show SecondaryCameraPreviewWidget;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/layer_animation_storage.dart'
    show ExportLayerMapping;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';

/// Shows the second camera in a small window over the viewfinder while
/// dual-camera capture is on.
///
/// Tapping it swaps which camera fills the viewfinder, a long press switches
/// it between portrait and square; dragging moves it, and pinching it resizes
/// and turns it. A pinch starts with a finger on the window, and the second
/// finger may land anywhere on the viewfinder, so a window shrunk small still
/// grows back. Where the window is, its shape, how large and how turned, is
/// where the editor places the second camera's picture-in-picture layer.
class VideoRecorderDualCameraWindow extends StatefulWidget {
  /// Creates the second camera's window.
  const VideoRecorderDualCameraWindow({super.key});

  /// How close to upright, or to a quarter turn, a pinch has to turn the
  /// window for it to settle there, in radians (about 4°).
  @visibleForTesting
  static const double rotationSnap = 0.07;

  /// How long the window takes to settle into a new size it did not get from
  /// a finger, such as switching between portrait and square.
  @visibleForTesting
  static const Duration resizeDuration = Duration(milliseconds: 220);

  @override
  State<VideoRecorderDualCameraWindow> createState() =>
      _VideoRecorderDualCameraWindowState();
}

/// Where the window is: its center as fractions of the kept picture, its size
/// as a multiple of the default, and its turn in radians clockwise.
typedef _Placement = ({Offset center, double scale, double rotation});

/// The viewfinder's geometry for one layout: the kept picture, the part of it
/// the viewfinder shows, and the window's size at scale 1.
typedef _Layout = ({Rect kept, Rect visible, Size unscaledSize});

class _VideoRecorderDualCameraWindowState
    extends State<VideoRecorderDualCameraWindow> {
  /// Pinches and drags the window. Fed by hand rather than by a
  /// [GestureDetector], so a pinch's second finger can land beside the window.
  late final ScaleGestureRecognizer _scale = ScaleGestureRecognizer(
    debugOwner: this,
  )..onUpdate = _onScaleUpdate;

  /// Where the fingers on the window are, and once one is, those on the
  /// viewfinder around it, in global coordinates.
  final Map<int, Offset> _pointers = {};

  /// The window while a drag or pinch moves it. Reported to the recorder when
  /// the last finger lifts.
  _Placement? _live;

  /// Where the window was, and the fingers' midpoint, when a finger last
  /// touched down or lifted. The recognizer measures its scale and turn from
  /// that moment too, so the window follows the fingers from where they
  /// touched it, not from where the pinch was recognized.
  _Placement? _gestureStart;
  Offset _gestureFocalStart = Offset.zero;

  /// Whether the pinch has the window settled upright or at a quarter turn.
  bool _isRotationSnapped = false;

  /// Whether a second finger touched down since the first one did. Such a
  /// touch is a pinch, even one too small to be recognized, and never a tap.
  bool _isMultiTouch = false;

  /// Switches the shape once one still finger has rested for a long press.
  ///
  /// A timer rather than a long-press recognizer: in the gesture arena that
  /// recognizer wins the first finger after half a second and takes it from
  /// the pinch, so two fingers that rested before spreading did nothing.
  Timer? _longPressTimer;

  /// Where the first finger touched down, to tell a still finger from a drag.
  Offset _longPressOrigin = Offset.zero;

  /// Whether this touch already switched the shape, so lifting the finger
  /// does not swap the cameras as well.
  bool _didLongPress = false;

  /// The geometry of the latest layout, for the gesture callbacks.
  _Layout? _layout;

  /// Whether a check of the recorder's window placement is queued for after
  /// this frame; see [_keepPlacementShown].
  bool _isPlacementCheckQueued = false;

  @override
  void deactivate() {
    // The camera stack re-keys its children after a camera switch, which
    // takes the window away under a finger. Put it down where the finger
    // left it; the finger's later events reach a window that is gone.
    _putDown();
    super.deactivate();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        center: b.state.dualCameraPipCenter,
        scale: b.state.dualCameraPipScale,
        rotation: b.state.dualCameraPipRotation,
        shape: b.state.dualCameraPipAspectRatio,
        textureId: b.state.secondaryPreviewTextureId,
        canSwap: b.state.canSwitchCamera && !b.state.hasRecordingInFlight,
        sensorAspectRatio: b.state.cameraSensorAspectRatio,
        keptAspectRatio: b.state.aspectRatio.value,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Offset.zero & constraints.biggest;
        final kept = keptPicture(
          box: box.size,
          sensorAspectRatio: state.sensorAspectRatio,
          keptAspectRatio: state.keptAspectRatio,
        );
        final width = kept.width * SecondaryCameraTake.pipWidthFraction;
        final layout = (
          kept: kept,
          visible: kept.intersect(box),
          unscaledSize: Size(width, width / state.shape.value),
        );
        _layout = layout;
        final placement = _fit(
          _live ??
              (
                center: state.center,
                scale: state.scale,
                rotation: state.rotation,
              ),
          layout,
        );
        if (_live == null) _keepPlacementShown(layout);

        return Stack(
          children: [
            // While a finger is on the window, a finger anywhere else on the
            // viewfinder joins the pinch instead of zooming the camera. Asked
            // when each finger lands rather than at the last build, so a
            // second finger in the same frame joins too; and always in the
            // tree, since inserting it would rebuild the window under the
            // finger and drop its tap.
            Positioned.fill(
              child: _CatchesPointersWhile(
                isActive: () => _pointers.isNotEmpty,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerGone,
                  onPointerCancel: _onPointerGone,
                ),
              ),
            ),
            // A size the recorder changes, a long press switching the shape
            // or a window made to fit, eases in; a finger moves it directly.
            AnimatedPositioned.fromRect(
              duration: _live != null || MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : VideoRecorderDualCameraWindow.resizeDuration,
              curve: Curves.easeOutCubic,
              rect: Rect.fromCenter(
                center: _centerPoint(placement.center, kept),
                width: layout.unscaledSize.width * placement.scale,
                height: layout.unscaledSize.height * placement.scale,
              ),
              child: Transform.rotate(
                angle: placement.rotation,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerGone,
                  onPointerCancel: _onPointerGone,
                  child: Semantics(
                    identifier: SemanticIds.cameraDualCameraWindow,
                    button: true,
                    enabled: state.canSwap,
                    label: context.l10n.videoRecorderDualCameraSwapLabel,
                    // Screen-reader actions carry no fingers, so the touch
                    // flags below do not apply to them.
                    onTap: state.canSwap ? _swapCameras : null,
                    onLongPress: _switchShape,
                    onLongPressHint:
                        context.l10n.videoRecorderDualCameraShapeHint,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: state.canSwap
                          ? () {
                              if (_isMultiTouch || _didLongPress) return;
                              _swapCameras();
                            }
                          : null,
                      child: _WindowFrame(textureId: state.textureId),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _scale.addPointer(event);
    // The first finger starts a fresh touch; any later one makes it a pinch.
    _isMultiTouch = _pointers.isNotEmpty;
    if (_isMultiTouch) {
      _cancelLongPress();
    } else {
      _didLongPress = false;
      _longPressOrigin = event.position;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(kLongPressTimeout, _onLongPress);
    }
    _pointers[event.pointer] = event.position;
    _restartGesture();
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if ((event.position - _longPressOrigin).distance > kTouchSlop) {
      _cancelLongPress();
    }
  }

  void _onPointerGone(PointerEvent event) {
    // A finger that was down when the camera stack rebuilt lifts here after
    // this window is gone; see [deactivate].
    if (!mounted) return;
    _cancelLongPress();
    _pointers.remove(event.pointer);
    // The last finger leaving puts the window down. The recognizer's own end
    // cannot tell: a finger lifted mid-pinch ends its gesture too, and the
    // last one then lifts with no end of its own.
    if (_pointers.isEmpty) {
      _putDown();
    } else {
      _restartGesture();
    }
    setState(() {});
  }

  /// Measures the gesture from here on, as the recognizer does whenever a
  /// finger touches down or lifts.
  void _restartGesture() {
    if (_pointers.isEmpty) return;
    final bloc = context.read<VideoRecorderBloc>();
    final start =
        _live ??
        (
          center: bloc.state.dualCameraPipCenter,
          scale: bloc.state.dualCameraPipScale,
          rotation: bloc.state.dualCameraPipRotation,
        );
    // A window already upright does not tick as a fresh drag starts.
    if (_live == null) {
      _isRotationSnapped = _quarterTurnNear(start.rotation) != null;
    }
    _gestureStart = start;
    final sum = _pointers.values.reduce((a, b) => a + b);
    _gestureFocalStart = _toLocal(sum / _pointers.length.toDouble());
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final start = _gestureStart;
    final layout = _layout;
    if (start == null || layout == null) return;

    final focalDelta = _toLocal(details.focalPoint) - _gestureFocalStart;
    final center =
        _centerPoint(start.center, layout.kept) +
        focalDelta -
        layout.kept.topLeft;
    setState(() {
      _live = _fit(
        (
          center: Offset(
            center.dx / layout.kept.width,
            center.dy / layout.kept.height,
          ),
          scale: start.scale * details.scale,
          rotation: _snapRotation(start.rotation + details.rotation),
        ),
        layout,
      );
    });
  }

  void _onLongPress() {
    _longPressTimer = null;
    if (!mounted || _isMultiTouch || _live != null) return;
    _didLongPress = true;
    _switchShape();
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _swapCameras() => context.read<VideoRecorderBloc>().add(
    const VideoRecorderCameraSwitched(),
  );

  /// Switches the window between portrait and square.
  void _switchShape() {
    unawaited(HapticFeedback.mediumImpact());
    context.read<VideoRecorderBloc>().add(
      const VideoRecorderDualCameraPipShapeToggled(),
    );
  }

  /// Reports where the gesture left the window to the recorder.
  void _putDown() {
    final placement = _live;
    _gestureStart = null;
    _live = null;
    if (placement == null) return;
    context.read<VideoRecorderBloc>().add(
      VideoRecorderDualCameraPipChanged(
        center: placement.center,
        scale: placement.scale,
        rotation: placement.rotation,
      ),
    );
  }

  /// [rotation] settled upright or at the nearest quarter turn when it is
  /// within [VideoRecorderDualCameraWindow.rotationSnap] of it, with a tick
  /// as it settles.
  double _snapRotation(double rotation) {
    final snapped = _quarterTurnNear(rotation);
    if (snapped != null && !_isRotationSnapped) {
      unawaited(HapticFeedback.selectionClick());
    }
    _isRotationSnapped = snapped != null;
    return snapped ?? rotation;
  }

  /// The upright or quarter-turn angle within
  /// [VideoRecorderDualCameraWindow.rotationSnap] of [rotation], if any.
  static double? _quarterTurnNear(double rotation) {
    const quarter = math.pi / 2;
    final nearest = (rotation / quarter).roundToDouble() * quarter;
    return (rotation - nearest).abs() <
            VideoRecorderDualCameraWindow.rotationSnap
        ? nearest
        : null;
  }

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : global;
  }

  /// Moves the recorder's window placement to where this viewfinder shows
  /// it, when it cannot show the stored one whole: a placement kept from the
  /// other aspect ratio, or the default on a viewfinder that cuts more of the
  /// frame off. The take then lands where the window was seen.
  ///
  /// Checked after the frame, against the recorder's state then: a gesture
  /// that just ended has landed there by then, and must not be undone.
  void _keepPlacementShown(_Layout layout) {
    if (_isPlacementCheckQueued) return;
    _isPlacementCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isPlacementCheckQueued = false;
      if (!mounted || _live != null) return;
      final bloc = context.read<VideoRecorderBloc>();
      final stored = (
        center: bloc.state.dualCameraPipCenter,
        scale: bloc.state.dualCameraPipScale,
        rotation: bloc.state.dualCameraPipRotation,
      );
      final shown = _fit(stored, layout);
      if ((shown.center - stored.center).distance > 0.001 ||
          (shown.scale - stored.scale).abs() > 0.001) {
        bloc.add(
          VideoRecorderDualCameraPipChanged(
            center: shown.center,
            scale: shown.scale,
            rotation: shown.rotation,
          ),
        );
      }
    });
  }

  /// [placement] limited to what the viewfinder shows whole: no larger than
  /// fits the visible part of the kept picture as turned, and moved inside
  /// it.
  static _Placement _fit(_Placement placement, _Layout layout) {
    final scale = SecondaryCameraTake.fittingPipScale(
      scale: placement.scale,
      unscaledSize: layout.unscaledSize,
      rotation: placement.rotation,
      area: layout.visible.size,
    );
    final bounds = SecondaryCameraTake.turnedPipBounds(
      layout.unscaledSize * scale,
      placement.rotation,
    );
    final visible = layout.visible;
    final point = _centerPoint(placement.center, layout.kept);
    final x = bounds.width >= visible.width
        ? visible.center.dx
        : point.dx.clamp(
            visible.left + bounds.width / 2,
            visible.right - bounds.width / 2,
          );
    final y = bounds.height >= visible.height
        ? visible.center.dy
        : point.dy.clamp(
            visible.top + bounds.height / 2,
            visible.bottom - bounds.height / 2,
          );
    return (
      center: Offset(
        (x - layout.kept.left) / layout.kept.width,
        (y - layout.kept.top) / layout.kept.height,
      ),
      scale: scale,
      rotation: placement.rotation,
    );
  }

  /// [center] (fractions of [kept]) as a point in the viewfinder.
  static Offset _centerPoint(Offset center, Rect kept) => Offset(
    kept.left + center.dx * kept.width,
    kept.top + center.dy * kept.height,
  );
}

/// Where the picture a take keeps sits in a viewfinder [box].
///
/// The preview covers the box with the camera frame of [sensorAspectRatio]
/// (width / height), so the frame can reach past the box; the take keeps the
/// middle of that frame at [keptAspectRatio]. The window is measured against
/// this rect, which is how the editor and the library picture measure it.
/// A camera that has not reported its frame yet counts as filling the box.
@visibleForTesting
Rect keptPicture({
  required Size box,
  required double sensorAspectRatio,
  required double keptAspectRatio,
}) {
  final Rect frame;
  if (sensorAspectRatio <= 0 || box.isEmpty) {
    frame = Offset.zero & box;
  } else {
    final cover = box.aspectRatio > sensorAspectRatio
        ? Size(box.width, box.width / sensorAspectRatio)
        : Size(box.height * sensorAspectRatio, box.height);
    frame = Rect.fromCenter(
      center: box.center(Offset.zero),
      width: cover.width,
      height: cover.height,
    );
  }
  return ExportLayerMapping.keptRect(
    frame.size,
    keptAspectRatio,
  ).shift(frame.topLeft);
}

/// Lets [child] take pointers only while [isActive] says so, asked at the
/// moment a pointer lands rather than when the widget last built.
class _CatchesPointersWhile extends SingleChildRenderObjectWidget {
  const _CatchesPointersWhile({required this.isActive, super.child});

  final bool Function() isActive;

  @override
  _RenderCatchesPointersWhile createRenderObject(BuildContext context) =>
      _RenderCatchesPointersWhile(isActive);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCatchesPointersWhile renderObject,
  ) => renderObject.isActive = isActive;
}

class _RenderCatchesPointersWhile extends RenderProxyBox {
  _RenderCatchesPointersWhile(this.isActive);

  bool Function() isActive;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      isActive() && super.hitTest(result, position: position);
}

class _WindowFrame extends StatelessWidget {
  const _WindowFrame({required this.textureId});

  final int? textureId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
        // The editor masks the layer with the same rounding, so the window
        // shows the take as it will look.
        borderRadius: BorderRadius.circular(
          constraints.biggest.shortestSide /
              2 *
              SecondaryCameraTake.pipCornerRadius,
        ),
        // Keyed on the texture: a swap hands the window the other camera's
        // texture.
        child: SecondaryCameraPreviewWidget(key: ValueKey(textureId)),
      ),
    );
  }
}
