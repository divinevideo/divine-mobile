// ABOUTME: Universal trim handle wrapper for timeline strips.
// ABOUTME: Adds draggable left/right handles around a child widget.
// ABOUTME: Reusable for clip, layer, and audio strip trimming.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';

/// Callback reporting the horizontal drag delta in pixels.
typedef TrimDragCallback = void Function(double dx);

/// A reusable trim-handle overlay for timeline strips.
///
/// Wraps [child] with left and right drag handles that report pixel
/// deltas. The parent converts deltas to domain values (time, etc.)
/// and manages clamping / state updates.
///
/// Designed for reuse across clip, layer, and audio strips — colours,
/// sizes, and border radius are all configurable.
class TimelineTrimHandles extends StatefulWidget {
  const TimelineTrimHandles({
    required this.child,
    required this.height,
    this.width,
    this.onLeftDragUpdate,
    this.onRightDragUpdate,
    this.onDragStart,
    this.onDragEnd,
    this.onDragPositionUpdate,
    this.handleColor = VineTheme.accentYellow,
    this.markerColor = TimelineConstants.trimHandleMarkerColor,
    this.handleWidth = TimelineConstants.trimHandleWidth,
    this.markerWidth = TimelineConstants.trimHandleMarkerWidth,
    this.markerHeight = TimelineConstants.trimHandleMarkerHeight,
    this.borderWidth = TimelineConstants.trimBorderWidth,
    this.borderRadius = TimelineConstants.thumbnailRadius,
    this.hitAreaExtra = TimelineConstants.trimHitAreaExtra,
    super.key,
  });

  /// Content displayed between the two handles.
  final Widget child;

  /// Total height of the trim container (including border).
  final double height;

  /// Content width of the strip (excluding the handles). When provided,
  /// the inward part of each grab zone is clamped so the left and right
  /// hit areas never overlap on narrow strips.
  final double? width;

  /// Called with the horizontal pixel delta when the left handle moves.
  final TrimDragCallback? onLeftDragUpdate;

  /// Called with the horizontal pixel delta when the right handle moves.
  final TrimDragCallback? onRightDragUpdate;

  /// Called when a drag gesture starts on either handle.
  final VoidCallback? onDragStart;

  /// Called when a drag gesture ends on either handle.
  final VoidCallback? onDragEnd;

  /// Called on every drag update with the current global finger position.
  /// Use this to implement auto-scroll during trimming.
  final ValueChanged<Offset>? onDragPositionUpdate;

  /// Background colour of the handles and border.
  final Color handleColor;

  /// Colour of the vertical marker line inside each handle.
  final Color markerColor;

  /// Width of each handle in logical pixels.
  final double handleWidth;

  /// Width of the marker line inside each handle.
  final double markerWidth;

  /// Height of the marker line inside each handle.
  final double markerHeight;

  /// Width of the border wrapping the content.
  final double borderWidth;

  /// Border radius of the outer container.
  final double borderRadius;

  /// Extra invisible hit area on the outer edge of each handle
  /// to make small handles easier to grab.
  final double hitAreaExtra;

  @override
  State<TimelineTrimHandles> createState() => _TimelineTrimHandlesState();
}

class _TimelineTrimHandlesState extends State<TimelineTrimHandles> {
  void _onDragStart(DragStartDetails details) {
    widget.onDragStart?.call();
  }

  void _onLeftDragUpdate(DragUpdateDetails details) {
    widget.onLeftDragUpdate?.call(details.delta.dx);
    widget.onDragPositionUpdate?.call(details.globalPosition);
  }

  void _onRightDragUpdate(DragUpdateDetails details) {
    widget.onRightDragUpdate?.call(details.delta.dx);
    widget.onDragPositionUpdate?.call(details.globalPosition);
  }

  void _onDragEnd(DragEndDetails _) {
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final handleW = widget.handleWidth - widget.borderWidth;
    final innerRadius = (widget.borderRadius - widget.borderWidth).clamp(
      0.0,
      double.infinity,
    );

    // The grab zone reaches symmetrically around each handle edge:
    // [outwardHit] points away from the content, [inwardHit] into it.
    final defaultInward = widget.hitAreaExtra / 2 + widget.borderWidth;
    var outwardHit = handleW + widget.hitAreaExtra / 2;
    var inwardHit = defaultInward;
    // On narrow strips, clamp the inward reach so the left and right hit
    // areas never overlap — but keep the total grab width constant by
    // shifting the lost inward part outwards instead of shrinking it.
    final width = widget.width;
    if (width != null) {
      final clampedInward = inwardHit.clamp(0.0, width / 2);
      outwardHit += inwardHit - clampedInward;
      inwardHit = clampedInward;
    }
    final hitWidth = outwardHit + inwardHit;

    return _ExpandedHitSizedBox(
      expandLeft: outwardHit,
      expandRight: outwardHit,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Content fills the widget area with border overlay.
          Positioned.fill(
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: widget.handleColor,
                    width: widget.borderWidth,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerRadius),
                child: widget.child,
              ),
            ),
          ),
          // Left handle visual — positioned outside the left edge.
          Positioned(
            left: -handleW,
            top: 0,
            width: handleW,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.handleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.borderRadius),
                  bottomLeft: Radius.circular(widget.borderRadius),
                ),
              ),
              child: _HandleVisual(
                color: widget.handleColor,
                markerColor: widget.markerColor,
                markerWidth: widget.markerWidth,
                markerHeight: widget.markerHeight,
              ),
            ),
          ),
          // Right handle visual — positioned outside the right edge.
          Positioned(
            right: -handleW,
            top: 0,
            width: handleW,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.handleColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(widget.borderRadius),
                  bottomRight: Radius.circular(widget.borderRadius),
                ),
              ),
              child: _HandleVisual(
                color: widget.handleColor,
                markerColor: widget.markerColor,
                markerWidth: widget.markerWidth,
                markerHeight: widget.markerHeight,
              ),
            ),
          ),
          // Left hit area — symmetric grab zone around the handle edge:
          // reaches [outwardHit] outwards and [inwardHit] inwards.
          Positioned(
            left: -outwardHit,
            top: 0,
            width: hitWidth,
            height: widget.height,
            child: Semantics(
              label: context.l10n.videoEditorTimelineTrimStartSemanticLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onLeftDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
              ),
            ),
          ),
          // Right hit area — symmetric grab zone around the handle edge:
          // reaches [outwardHit] outwards and [inwardHit] inwards.
          Positioned(
            right: -outwardHit,
            top: 0,
            width: hitWidth,
            height: widget.height,
            child: Semantics(
              label: context.l10n.videoEditorTimelineTrimEndSemanticLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onRightDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual handle bar with a centred marker line.
class _HandleVisual extends StatelessWidget {
  const _HandleVisual({
    required this.color,
    required this.markerColor,
    required this.markerWidth,
    required this.markerHeight,
  });

  final Color color;
  final Color markerColor;
  final double markerWidth;
  final double markerHeight;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: markerWidth,
        height: markerHeight,
        decoration: BoxDecoration(
          color: markerColor,
          borderRadius: BorderRadius.circular(markerWidth),
        ),
      ),
    );
  }
}

/// A [SizedBox]-like widget that accepts hit-tests beyond its layout bounds.
///
/// Used so that trim handles positioned outside the content area via
/// [Stack] + [Clip.none] remain interactive.
class _ExpandedHitSizedBox extends SingleChildRenderObjectWidget {
  const _ExpandedHitSizedBox({
    required super.child,
    required this.height,
    this.expandLeft = 0,
    this.expandRight = 0,
  });

  final double height;
  final double expandLeft;
  final double expandRight;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderExpandedHitSizedBox(
      expandLeft: expandLeft,
      expandRight: expandRight,
      additionalConstraints: BoxConstraints.tightFor(height: height),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderExpandedHitSizedBox renderObject,
  ) {
    renderObject
      ..expandLeft = expandLeft
      ..expandRight = expandRight
      ..additionalConstraints = BoxConstraints.tightFor(height: height);
  }
}

class _RenderExpandedHitSizedBox extends RenderConstrainedBox {
  _RenderExpandedHitSizedBox({
    required double expandLeft,
    required double expandRight,
    required super.additionalConstraints,
  }) : _expandLeft = expandLeft,
       _expandRight = expandRight;

  double _expandLeft;
  double get expandLeft => _expandLeft;
  set expandLeft(double value) {
    if (_expandLeft == value) return;
    _expandLeft = value;
  }

  double _expandRight;
  double get expandRight => _expandRight;
  set expandRight(double value) {
    if (_expandRight == value) return;
    _expandRight = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final inBounds =
        position.dx >= -_expandLeft &&
        position.dx < size.width + _expandRight &&
        position.dy >= 0 &&
        position.dy < size.height;
    if (inBounds) {
      final childHit =
          child?.hitTestChildren(result, position: position) ?? false;
      if (childHit || hitTestSelf(position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return false;
  }
}
