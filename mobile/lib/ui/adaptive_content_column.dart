// ABOUTME: Readable content widths for box layouts and full-width scroll views.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/ui/adaptive_layout.dart';

/// A maximum content width in logical pixels for an adaptive column.
@immutable
final class AdaptiveContentWidth {
  /// Keeps an existing maximum width that has no named equivalent.
  const AdaptiveContentWidth.custom(this.maxWidth)
    : assert(
        maxWidth > 0 && maxWidth < double.infinity,
        'The maximum content width must be positive and finite.',
      );

  /// 440 logical pixels for forms and other groups of input controls.
  static const form = AdaptiveContentWidth.custom(440);

  /// 600 logical pixels for lists of rows such as settings.
  static const list = AdaptiveContentWidth.custom(600);

  /// 720 logical pixels for longer text and conversations.
  static const reading = AdaptiveContentWidth.custom(720);

  /// The maximum width of the column in logical pixels.
  final double maxWidth;
}

/// Centers box content within its parent and caps its width.
///
/// The cap applies where [AdaptiveLayout.isLargeScreen]. In a narrower window
/// or with the large-screen layouts off, [child] lays out exactly as it would
/// without the column, so phones are unchanged. The column stays in the tree
/// either way, so resizing a window across [AdaptiveBreakpoints.large] keeps
/// [child]'s state.
///
/// For scrollable content, prefer [SliverAdaptiveContentColumn] inside the
/// viewport. A [ListView] wrapped in this widget has a narrow viewport on
/// desktop, so wheel and trackpad scrolling only work over the middle column
/// and the scrollbar follows the column edge.
class AdaptiveContentColumn extends StatelessWidget {
  /// Creates a column that is top aligned by default.
  const AdaptiveContentColumn({
    required this.width,
    required this.child,
    this.capWithoutLargeLayout = false,
    this.alignment = Alignment.topCenter,
    this.heightFactor,
    super.key,
  });

  /// Use [AdaptiveContentWidth.form] for forms, [AdaptiveContentWidth.list]
  /// for row lists and settings, and [AdaptiveContentWidth.reading] for
  /// longer text and conversations.
  final AdaptiveContentWidth width;

  /// Content to lay out within the column.
  final Widget child;

  /// Applies the cap in every window, even with the large-screen layouts off.
  /// Use this to preserve caps that predate the layouts.
  final bool capWithoutLargeLayout;

  /// Positions the child within the space available to the column.
  final AlignmentGeometry alignment;

  /// Scales the child's height to size the column. Use 1 to wrap the child's
  /// height in a bounded parent, such as a bottom action bar.
  final double? heightFactor;

  /// Applies the width cap using the space offered by the parent.
  @override
  Widget build(BuildContext context) => _ContentColumn(
    capped: capWithoutLargeLayout || context.adaptiveLayout.isLargeScreen,
    maxWidth: width.maxWidth,
    alignment: alignment,
    heightFactor: heightFactor,
    child: child,
  );
}

/// An [Align] around a [ConstrainedBox] while [capped], and nothing at all
/// otherwise: one render object for both, so switching keeps the child.
class _ContentColumn extends SingleChildRenderObjectWidget {
  const _ContentColumn({
    required this.capped,
    required this.maxWidth,
    required this.alignment,
    required this.heightFactor,
    required super.child,
  });

  final bool capped;
  final double maxWidth;
  final AlignmentGeometry alignment;
  final double? heightFactor;

  @override
  _RenderContentColumn createRenderObject(BuildContext context) =>
      _RenderContentColumn(
        capped: capped,
        maxWidth: maxWidth,
        alignment: alignment,
        heightFactor: heightFactor,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderContentColumn renderObject,
  ) {
    renderObject
      ..capped = capped
      ..maxWidth = maxWidth
      ..alignment = alignment
      ..heightFactor = heightFactor
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Lays its child out as [Align] and [ConstrainedBox] would while [capped],
/// and passes the incoming constraints straight through otherwise.
class _RenderContentColumn extends RenderPositionedBox {
  _RenderContentColumn({
    required bool capped,
    required double maxWidth,
    required super.alignment,
    required super.heightFactor,
    required super.textDirection,
  }) : _capped = capped,
       _maxWidth = maxWidth;

  bool get capped => _capped;
  bool _capped;
  set capped(bool value) {
    if (value == _capped) return;
    _capped = value;
    markNeedsLayout();
  }

  double get maxWidth => _maxWidth;
  double _maxWidth;
  set maxWidth(double value) {
    if (value == _maxWidth) return;
    _maxWidth = value;
    markNeedsLayout();
  }

  /// What the [ConstrainedBox] inside the [Align] gives the child.
  BoxConstraints _cappedChildConstraints(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: _maxWidth).enforce(constraints.loosen());

  /// The size the [Align] takes around a child [childSize] large.
  Size _cappedSize(BoxConstraints constraints, Size childSize) {
    final shrinkWrapWidth = constraints.maxWidth == double.infinity;
    final shrinkWrapHeight =
        heightFactor != null || constraints.maxHeight == double.infinity;
    return constraints.constrain(
      Size(
        shrinkWrapWidth ? childSize.width : double.infinity,
        shrinkWrapHeight
            ? childSize.height * (heightFactor ?? 1)
            : double.infinity,
      ),
    );
  }

  double _cappedWidth(double width) =>
      _capped ? math.min(width, _maxWidth) : width;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _cappedWidth(super.computeMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _cappedWidth(super.computeMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(_cappedWidth(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(_cappedWidth(width));

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (!_capped) {
      return child?.getDryLayout(constraints) ?? constraints.smallest;
    }
    final childSize =
        child?.getDryLayout(_cappedChildConstraints(constraints)) ?? Size.zero;
    return _cappedSize(constraints, childSize);
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    if (!_capped) return child.getDryBaseline(constraints, baseline);
    final childConstraints = _cappedChildConstraints(constraints);
    final childBaseline = child.getDryBaseline(childConstraints, baseline);
    if (childBaseline == null) return null;
    final childSize = child.getDryLayout(childConstraints);
    final offset = resolvedAlignment.alongOffset(
      (getDryLayout(constraints) - childSize) as Offset,
    );
    return childBaseline + offset.dy;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (!_capped) {
      if (child == null) {
        size = constraints.smallest;
        return;
      }
      child.layout(constraints, parentUsesSize: true);
      (child.parentData! as BoxParentData).offset = Offset.zero;
      size = constraints.constrain(child.size);
      return;
    }
    if (child == null) {
      size = _cappedSize(constraints, Size.zero);
      return;
    }
    child.layout(_cappedChildConstraints(constraints), parentUsesSize: true);
    size = _cappedSize(constraints, child.size);
    alignChild();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('capped', value: capped, ifTrue: 'capped'))
      ..add(DoubleProperty('maxWidth', maxWidth));
  }
}

/// Centers a sliver in a vertical scroll view by adding horizontal padding.
///
/// The padding comes from the sliver's own cross-axis extent, including when
/// side navigation takes up part of the window. The viewport stays full width,
/// so its scrollbar can stay at the edge and wheel and trackpad scrolling work
/// over the empty margins.
///
/// Like [AdaptiveContentColumn], it pads only where
/// [AdaptiveLayout.isLargeScreen], so phones are unchanged.
class SliverAdaptiveContentColumn extends StatelessWidget {
  /// Creates a width-capped column inside a vertical viewport.
  const SliverAdaptiveContentColumn({
    required this.width,
    required this.sliver,
    this.capWithoutLargeLayout = false,
    super.key,
  });

  /// Use [AdaptiveContentWidth.form] for forms, [AdaptiveContentWidth.list]
  /// for row lists and settings, and [AdaptiveContentWidth.reading] for
  /// longer text and conversations.
  final AdaptiveContentWidth width;

  /// The sliver to center, such as a [SliverList].
  final Widget sliver;

  /// Applies the cap in every window, even with the large-screen layouts off.
  /// Use this to preserve caps that predate the layouts.
  final bool capWithoutLargeLayout;

  /// Pads the content within the viewport when the cap is active.
  @override
  Widget build(BuildContext context) {
    final cap = capWithoutLargeLayout || context.adaptiveLayout.isLargeScreen;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final inset = cap && constraints.axis == Axis.vertical
            ? math.max(0.0, (constraints.crossAxisExtent - width.maxWidth) / 2)
            : 0.0;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          sliver: sliver,
        );
      },
    );
  }
}
