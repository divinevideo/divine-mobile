// ABOUTME: The shape mask editor over the live canvas: the shape is moved,
// ABOUTME: resized and turned by touch, its look set in a panel below.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_mask.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskShape;

/// Where the masked item sits on screen: the box its mask is measured in, and
/// the transform from that box to the screen.
typedef MaskTargetGeometry = ({Size size, Matrix4 transform});

/// What the mask editor closes with: the mask to keep, `null` for none.
typedef MaskEditorResult = ({LayerMask? mask});

/// How close, in screen pixels, a touch has to land to a resize handle to
/// grab it rather than move the whole shape.
const double _handleTouchRadius = 32;

/// The radius of a drawn resize handle.
const double _handleRadius = 7;

/// The height of the mask editor's panel, above the bottom safe area.
///
/// The editor keeps this much free below the canvas while the mask editor is
/// open, so the video sits above the panel instead of under it.
const double videoEditorMaskPanelHeight = 200;

/// The mask editor itself.
///
/// The editor shows through: the mask is drawn on the item as it changes,
/// through [onChanged], and its outline over it. One finger moves the shape,
/// two resize and turn it, and the handles on its sides stretch it. The
/// panel picks the shape, how soft its edge is, how round a rectangle's
/// corners are and whether it is inverted. The top bar cancels or confirms;
/// confirming pops a [MaskEditorResult].
@visibleForTesting
class VideoEditorMaskEditorView extends StatefulWidget {
  /// Creates a [VideoEditorMaskEditorView].
  const VideoEditorMaskEditorView({
    required this.initialMask,
    required this.resolveGeometry,
    required this.canvasChanges,
    required this.onChanged,
    super.key,
  });

  /// The mask the item has when the editor opens, or `null` for none.
  final LayerMask? initialMask;

  /// Reads where the item sits on screen right now, or `null` while it
  /// cannot be measured.
  final MaskTargetGeometry? Function() resolveGeometry;

  /// Fires whenever the canvas moves, resizes or zooms.
  final Listenable canvasChanges;

  /// Called with every change, so the item shows it.
  final ValueChanged<LayerMask?> onChanged;

  @override
  State<VideoEditorMaskEditorView> createState() =>
      _VideoEditorMaskEditorViewState();
}

enum _Drag { move, width, height }

class _VideoEditorMaskEditorViewState extends State<VideoEditorMaskEditorView> {
  late LayerMask? _mask = widget.initialMask;
  bool _refreshScheduled = false;

  _Drag? _drag;
  LayerMask? _dragStartMask;
  Offset _dragStartLocal = Offset.zero;
  int _dragPointers = 0;
  double _scaleBase = 1;
  double _rotationBase = 0;

  @override
  void initState() {
    super.initState();
    widget.canvasChanges.addListener(_scheduleRefresh);
    // The canvas is mid-resize when the editor opens: the timeline is still
    // collapsing, so the first measurable frame comes after this one.
    addPostFrameCallbackIfMounted(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.canvasChanges.removeListener(_scheduleRefresh);
    super.dispose();
  }

  /// Redraws after the frame the canvas changed in, as the slide point
  /// picker does: the notification arrives while the canvas lays itself out.
  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    addPostFrameCallbackIfMounted(() {
      _refreshScheduled = false;
      setState(() {});
    });
  }

  void _setMask(LayerMask? mask) {
    if (mask == _mask) return;
    setState(() => _mask = mask);
    widget.onChanged(mask);
  }

  void _selectShape(LayerMaskShape? shape) {
    if (shape == null) return _setMask(null);
    if (shape == _mask?.shape) return;
    final geometry = widget.resolveGeometry();
    _setMask(
      editorMaskForShape(
        shape,
        boxSize: geometry?.size ?? Size.zero,
        previous: _mask,
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    final mask = _mask;
    final geometry = widget.resolveGeometry();
    if (mask == null || geometry == null) return;
    final local = maskLocalPoint(geometry, details.focalPoint);
    if (local == null) return;

    var drag = _Drag.move;
    if (details.pointerCount == 1 && mask.shape != LayerMaskShape.linear) {
      final handles = maskHandles(mask, geometry.size);
      final touch = details.focalPoint;
      final toWidth =
          (maskScreenPoint(geometry, handles.width) - touch).distance;
      final toHeight =
          (maskScreenPoint(geometry, handles.height) - touch).distance;
      if (math.min(toWidth, toHeight) <= _handleTouchRadius) {
        drag = toWidth <= toHeight ? _Drag.width : _Drag.height;
      }
    }
    _drag = drag;
    _rebase(mask, local, details.pointerCount, scale: 1, rotation: 0);
  }

  /// Starts measuring the gesture again from [mask] at [local]: when it
  /// begins, and whenever a finger lands or lifts, which jumps the focal
  /// point and restarts the recognizer's scale and turn.
  void _rebase(
    LayerMask mask,
    Offset local,
    int pointers, {
    required double scale,
    required double rotation,
  }) {
    _dragStartMask = mask;
    _dragStartLocal = local;
    _dragPointers = pointers;
    _scaleBase = scale;
    _rotationBase = rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final start = _dragStartMask;
    final mask = _mask;
    final geometry = widget.resolveGeometry();
    if (start == null || mask == null || geometry == null) return;
    final local = maskLocalPoint(geometry, details.focalPoint);
    if (local == null) return;
    final box = geometry.size;
    if (box.isEmpty) return;

    if (details.pointerCount != _dragPointers) {
      _rebase(
        mask,
        local,
        details.pointerCount,
        scale: details.scale,
        rotation: details.rotation,
      );
      return;
    }

    switch (_drag) {
      case _Drag.width || _Drag.height:
        _setMask(
          maskResizedTowards(
            start,
            box,
            local,
            horizontal: _drag == _Drag.width,
          ),
        );
      case _Drag.move:
        var next = start;
        if (details.pointerCount >= 2) {
          if (next.shape != LayerMaskShape.linear && _scaleBase > 0) {
            next = scaleEditorMask(next, details.scale / _scaleBase);
          }
          next = next.copyWith(
            rotation: start.rotation + details.rotation - _rotationBase,
          );
        }
        // Kept on the item at the size and turn it now has.
        final moved = local - _dragStartLocal;
        _setMask(
          fitEditorMask(
            next.copyWith(
              center:
                  start.center +
                  Offset(moved.dx / box.width, moved.dy / box.height),
            ),
            box,
          ),
        );
      case null:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _drag = null;
    _dragStartMask = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final geometry = widget.resolveGeometry();
    final mask = _mask;

    return Scaffold(
      backgroundColor: VineTheme.transparent,
      body: Stack(
        fit: .expand,
        children: [
          Semantics(
            label: l10n.videoEditorShapeMaskHint,
            child: GestureDetector(
              behavior: .opaque,
              // Measured from where the finger lands, so the shape follows it
              // from the first pixel instead of jumping after the slop.
              dragStartBehavior: .down,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
            ),
          ),
          if (geometry != null && mask != null)
            IgnorePointer(
              child: CustomPaint(
                painter: MaskOutlinePainter(
                  mask: mask,
                  geometry: geometry,
                  lineColor: VineTheme.whiteText,
                  shadowColor: VineTheme.scrim50,
                  handleColor: context.vineColors.accentBrand,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          Align(
            alignment: .topCenter,
            child: _MaskEditorToolbar(
              onCancel: () => Navigator.of(context).pop(),
              onDone: () =>
                  Navigator.of(context).pop<MaskEditorResult>((mask: _mask)),
            ),
          ),
          Align(
            alignment: .bottomCenter,
            child: _MaskEditorPanel(
              mask: mask,
              onShapeSelected: _selectShape,
              onFeatherChanged: (feather) =>
                  _setMask(mask?.copyWith(feather: feather)),
              onCornerRadiusChanged: (corners) =>
                  _setMask(mask?.copyWith(cornerRadius: corners)),
              onInvertToggled: () =>
                  _setMask(mask?.copyWith(invert: !mask.invert)),
            ),
          ),
        ],
      ),
    );
  }
}

/// [global], a point on screen, in the coordinates of the masked item's box,
/// or `null` when the item is turned edge-on and the point has none.
@visibleForTesting
Offset? maskLocalPoint(MaskTargetGeometry geometry, Offset global) {
  final inverse = Matrix4.tryInvert(geometry.transform);
  if (inverse == null) return null;
  return MatrixUtils.transformPoint(inverse, global);
}

/// [local], a point in the masked item's box, on screen.
@visibleForTesting
Offset maskScreenPoint(MaskTargetGeometry geometry, Offset local) =>
    MatrixUtils.transformPoint(geometry.transform, local);

/// Where the handles that stretch [mask] sit in a box of [boxSize]: on the
/// middle of its right side and of its bottom side, turned with it.
@visibleForTesting
({Offset width, Offset height}) maskHandles(LayerMask mask, Size boxSize) {
  final pivot = Offset(
    mask.center.dx * boxSize.width,
    mask.center.dy * boxSize.height,
  );
  return (
    width:
        pivot +
        _turned(Offset(mask.size.width * boxSize.width / 2, 0), mask.rotation),
    height:
        pivot +
        _turned(
          Offset(0, mask.size.height * boxSize.height / 2),
          mask.rotation,
        ),
  );
}

/// [mask] with one side stretched so its handle reaches [local], a point in a
/// box of [boxSize]: its width when [horizontal], its height otherwise. The
/// shape stays centred, so it grows on both sides at once, and stops growing
/// where it touches an edge of the box.
@visibleForTesting
LayerMask maskResizedTowards(
  LayerMask mask,
  Size boxSize,
  Offset local, {
  required bool horizontal,
}) {
  final pivot = Offset(
    mask.center.dx * boxSize.width,
    mask.center.dy * boxSize.height,
  );
  final along = _turned(local - pivot, -mask.rotation);
  final size = horizontal
      ? Size(along.dx.abs() * 2 / boxSize.width, mask.size.height)
      : Size(mask.size.width, along.dy.abs() * 2 / boxSize.height);
  return resizeEditorMask(mask, size, boxSize: boxSize);
}

Offset _turned(Offset offset, double angle) {
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  return Offset(
    offset.dx * cos - offset.dy * sin,
    offset.dx * sin + offset.dy * cos,
  );
}

/// Draws [mask]'s outline over the item [geometry] places on screen, with the
/// handles that stretch it.
@visibleForTesting
class MaskOutlinePainter extends CustomPainter {
  /// Creates a [MaskOutlinePainter].
  const MaskOutlinePainter({
    required this.mask,
    required this.geometry,
    required this.lineColor,
    required this.shadowColor,
    required this.handleColor,
  });

  /// The mask being edited.
  final LayerMask mask;

  /// Where the masked item sits on screen.
  final MaskTargetGeometry geometry;

  /// The outline's color.
  final Color lineColor;

  /// A wider line under the outline, so it reads on light footage too.
  final Color shadowColor;

  /// The fill of the resize handles.
  final Color handleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = mask
        .outline(geometry.size)
        .transform(geometry.transform.storage);
    canvas
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = shadowColor,
      )
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = lineColor,
      );

    final center = maskScreenPoint(
      geometry,
      Offset(
        mask.center.dx * geometry.size.width,
        mask.center.dy * geometry.size.height,
      ),
    );
    canvas.drawCircle(center, 4, Paint()..color = lineColor);

    // A linear mask has no sides to stretch.
    if (mask.shape == LayerMaskShape.linear) return;
    final handles = maskHandles(mask, geometry.size);
    for (final handle in [handles.width, handles.height]) {
      final point = maskScreenPoint(geometry, handle);
      canvas
        ..drawCircle(point, _handleRadius + 2, Paint()..color = lineColor)
        ..drawCircle(point, _handleRadius, Paint()..color = handleColor);
    }
  }

  @override
  bool shouldRepaint(MaskOutlinePainter oldDelegate) =>
      oldDelegate.mask != mask ||
      oldDelegate.geometry.size != geometry.size ||
      oldDelegate.geometry.transform != geometry.transform ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.handleColor != handleColor;
}

/// Cancel on the left, confirm on the right.
///
/// Only the two buttons catch touches: everything else of the bar's width
/// belongs to the canvas, where the shape may be dragged under it.
class _MaskEditorToolbar extends StatelessWidget {
  const _MaskEditorToolbar({required this.onCancel, required this.onDone});

  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const .fromSTEB(16, 12, 16, 0),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            DivineIconButton(
              icon: .x,
              semanticLabel: l10n.commonCancel,
              size: .small,
              type: .ghostSecondary,
              onPressed: onCancel,
            ),
            DivineIconButton(
              icon: .check,
              semanticLabel: l10n.videoEditorDoneLabel,
              size: .small,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

/// The shapes, the invert toggle and the sliders for the edge and the
/// corners.
///
/// It fills the space the editor keeps free below the canvas while the mask
/// editor is open ([videoEditorMaskPanelHeight]), so the whole video stays
/// above it, where the shape can be seen and reached.
class _MaskEditorPanel extends StatelessWidget {
  const _MaskEditorPanel({
    required this.mask,
    required this.onShapeSelected,
    required this.onFeatherChanged,
    required this.onCornerRadiusChanged,
    required this.onInvertToggled,
  });

  final LayerMask? mask;
  final ValueChanged<LayerMaskShape?> onShapeSelected;
  final ValueChanged<double> onFeatherChanged;
  final ValueChanged<double> onCornerRadiusChanged;
  final VoidCallback onInvertToggled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mask = this.mask;
    final colors = context.vineColors;
    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: videoEditorMaskPanelHeight,
          // A large system font can outgrow the fixed height; it scrolls
          // then rather than overflow.
          child: SingleChildScrollView(
            padding: const .fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                SingleChildScrollView(
                  scrollDirection: .horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      _MaskOptionTile(
                        label: l10n.videoEditorShapeMaskNone,
                        selected: mask == null,
                        onTap: () => onShapeSelected(null),
                        child: DivineIcon(
                          icon: .prohibit,
                          color: colors.primaryText,
                        ),
                      ),
                      for (final shape in editorMaskShapes)
                        _MaskOptionTile(
                          label: switch (shape) {
                            .ellipse => l10n.videoEditorShapeMaskCircle,
                            .rectangle => l10n.videoEditorShapeMaskRectangle,
                            .heart => l10n.videoEditorShapeMaskHeart,
                            .linear => l10n.videoEditorShapeMaskLinear,
                            // TODO(#10396): Name these once the panel offers
                            // them; editorMaskShapes does not list them yet.
                            .star ||
                            .triangle ||
                            .diamond ||
                            .hexagon ||
                            .speechBubble => throw StateError(
                              '$shape is not an editor mask shape yet',
                            ),
                          },
                          selected: mask?.shape == shape,
                          onTap: () => onShapeSelected(shape),
                          child: _MaskShapeIcon(
                            mask: editorMaskForShape(
                              shape,
                              boxSize: const Size.square(1),
                            ),
                          ),
                        ),
                      _MaskOptionTile(
                        label: l10n.videoEditorShapeMaskInvert,
                        selected: mask?.invert ?? false,
                        onTap: mask == null ? null : onInvertToggled,
                        child: _MaskShapeIcon(
                          mask: editorMaskForShape(
                            mask?.shape ?? LayerMaskShape.ellipse,
                            boxSize: const Size.square(1),
                          ).copyWith(invert: true),
                        ),
                      ),
                    ],
                  ),
                ),
                if (mask != null)
                  _MaskSlider(
                    label: l10n.videoEditorShapeMaskSoftnessLabel,
                    minLabel: l10n.videoEditorShapeMaskSoftnessSharp,
                    maxLabel: l10n.videoEditorShapeMaskSoftnessSoft,
                    value: mask.feather.clamp(0.0, editorMaskMaxFeather),
                    max: editorMaskMaxFeather,
                    onChanged: onFeatherChanged,
                  ),
                if (mask?.shape == LayerMaskShape.rectangle)
                  _MaskSlider(
                    label: l10n.videoEditorShapeMaskCornersLabel,
                    minLabel: l10n.videoEditorShapeMaskCornersSquare,
                    maxLabel: l10n.videoEditorShapeMaskCornersRound,
                    value: mask!.cornerRadius,
                    onChanged: onCornerRadiusChanged,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A shape, or the invert toggle, to pick: a small picture and its name.
class _MaskOptionTile extends StatelessWidget {
  const _MaskOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;

  /// `null` disables the tile.
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final colors = context.vineColors;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      enabled: enabled,
      onTap: onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: onTap,
        behavior: .opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: SizedBox(
            width: 64,
            child: Column(
              spacing: 6,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? colors.accentPositive
                          : colors.outlineMuted,
                      width: 2,
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 52,
                    child: Center(
                      child: SizedBox.square(dimension: 26, child: child),
                    ),
                  ),
                ),
                // The tile announces the name itself.
                ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: VineTheme.bodySmallFont(
                      color: selected
                          ? colors.primaryText
                          : colors.onSurfaceMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small picture of [mask]: the shape where it shows the item, on a faint
/// square that marks the item.
class _MaskShapeIcon extends StatelessWidget {
  const _MaskShapeIcon({required this.mask});

  final LayerMask mask;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _MaskShapePainter(mask, color: context.vineColors.primaryText),
      ),
    );
  }
}

class _MaskShapePainter extends CustomPainter {
  const _MaskShapePainter(this.mask, {required this.color});

  final LayerMask mask;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    // The faint square lets an inverted shape read as a frame with the shape
    // cut out of it.
    canvas
      ..drawRect(bounds, Paint()..color = color.withValues(alpha: 0.25))
      ..saveLayer(bounds, Paint());
    // The mask paints white; the colour goes over what it painted.
    mask.paint(canvas, size);
    canvas
      ..drawRect(
        bounds,
        Paint()
          ..color = color
          ..blendMode = BlendMode.srcIn,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_MaskShapePainter oldDelegate) =>
      oldDelegate.mask != mask || oldDelegate.color != color;
}

/// A setting of the mask on a slider, named beside it. What its two ends
/// mean is announced with it.
class _MaskSlider extends StatelessWidget {
  const _MaskSlider({
    required this.label,
    required this.minLabel,
    required this.maxLabel,
    required this.value,
    required this.onChanged,
    this.max = 1,
  });

  final String label;
  final String minLabel;
  final String maxLabel;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        // The slider announces the name with its ends.
        ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 112),
            child: Text(
              label,
              maxLines: 1,
              overflow: .ellipsis,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
        ),
        Expanded(
          child: DivineSlider(
            value: value,
            max: max,
            semanticLabel: '$label: $minLabel – $maxLabel',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
