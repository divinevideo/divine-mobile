// ABOUTME: Lays the recorder's mode stack and bottom bar out in a column as
// ABOUTME: wide as the preview it records on large screens and the desktop

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/ui/adaptive_layout.dart';

/// How long the camera preview, and the recorder's column with it, take to
/// follow a change of the recording's aspect ratio.
const Duration recorderAspectRatioTransition = Duration(milliseconds: 220);

/// The curve the camera preview and the recorder's column follow a change of
/// the recording's aspect ratio along.
const Curve recorderAspectRatioCurve = Curves.easeInOut;

/// Whether the recorder shows exactly the frame it records instead of filling
/// the window with a vertical preview: on the desktop, and with the
/// large-screen layouts in a large or a landscape window. A phone, and the
/// folded iPhone Duo, fill the window even where it is not exactly 9:16.
///
/// Reads [defaultTargetPlatform] rather than `dart:io`, so a widget test lays
/// the recorder out for the platform it emulates, not the machine it runs on.
bool recorderShowsRecordedFrame(BuildContext context) {
  if (_isDesktop) return true;
  final layout = context.adaptiveLayout;
  return layout.enabled &&
      (layout.isLargeScreen || layout.size.width > layout.size.height);
}

bool get _isDesktop =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };

/// Lays out the recorder: the selected mode's [content] above the
/// [bottomBar].
///
/// On a phone both span the window, as they always have. Where the recorder
/// shows the frame it records ([recorderShowsRecordedFrame]), both are laid
/// out in a column as wide as the largest preview of [aspectRatio] that fits,
/// centered in the window, so the controls each mode lays over or around its
/// preview, the mode wheel and the library button stay with the preview
/// instead of at the window's edges. A square recording gets the wider
/// column, so its preview grows to the window's height too.
class VideoRecorderFrame extends StatelessWidget {
  /// Creates the recorder's layout.
  const VideoRecorderFrame({
    required this.aspectRatio,
    required this.content,
    required this.bottomBar,
    super.key,
  });

  /// The width over the height of the recording: 9/16 or square. The column
  /// follows a change along with the preview.
  final double aspectRatio;

  /// The selected mode's stack, which keeps clear of the top inset itself.
  final Widget content;

  /// The bar below [content], which keeps clear of the bottom inset itself.
  final Widget bottomBar;

  @override
  Widget build(BuildContext context) {
    final framed = recorderShowsRecordedFrame(context);
    final padding = MediaQuery.paddingOf(context);
    // A framed column keeps clear of the side insets itself, so its children
    // do not inset again. The children are the same either way, so a window
    // that crosses into the frame keeps the camera preview.
    final children = [
      MediaQuery.removePadding(
        context: context,
        removeLeft: framed,
        removeRight: framed,
        child: content,
      ),
      MediaQuery.removePadding(
        context: context,
        removeLeft: framed,
        removeRight: framed,
        child: bottomBar,
      ),
    ];
    return TweenAnimationBuilder<double>(
      tween: Tween(end: aspectRatio),
      duration: recorderAspectRatioTransition.autoReduceMotion(context),
      curve: recorderAspectRatioCurve,
      builder: (context, value, _) => _RecorderFrameLayout(
        framed: framed,
        aspectRatio: value,
        topInset: padding.top,
        leftInset: framed ? padding.left : 0,
        rightInset: framed ? padding.right : 0,
        children: children,
      ),
    );
  }
}

/// Lays out exactly two children, the content above the bottom bar, as
/// described on [VideoRecorderFrame].
///
/// A render object because the frame's width turns on the bottom bar's
/// height, which a widget cannot read before the bar is laid out at that
/// width.
class _RecorderFrameLayout extends MultiChildRenderObjectWidget {
  const _RecorderFrameLayout({
    required this.framed,
    required this.aspectRatio,
    required this.topInset,
    required this.leftInset,
    required this.rightInset,
    required super.children,
  }) : assert(children.length == 2, 'Content and bottom bar');

  final bool framed;
  final double aspectRatio;
  final double topInset;
  final double leftInset;
  final double rightInset;

  @override
  _RenderRecorderFrame createRenderObject(BuildContext context) {
    return _RenderRecorderFrame(
      framed: framed,
      aspectRatio: aspectRatio,
      topInset: topInset,
      leftInset: leftInset,
      rightInset: rightInset,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRecorderFrame renderObject,
  ) {
    renderObject
      ..framed = framed
      ..aspectRatio = aspectRatio
      ..topInset = topInset
      ..leftInset = leftInset
      ..rightInset = rightInset;
  }
}

class _RecorderFrameParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderRecorderFrame extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RecorderFrameParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RecorderFrameParentData> {
  _RenderRecorderFrame({
    required bool framed,
    required double aspectRatio,
    required double topInset,
    required double leftInset,
    required double rightInset,
  }) : _framed = framed,
       _aspectRatio = aspectRatio,
       _topInset = topInset,
       _leftInset = leftInset,
       _rightInset = rightInset;

  /// Whether the column is as wide as the preview rather than the window.
  bool get framed => _framed;
  bool _framed;
  set framed(bool value) {
    if (_framed == value) return;
    _framed = value;
    markNeedsLayout();
  }

  /// The width over the height of the preview the column is as wide as.
  double get aspectRatio => _aspectRatio;
  double _aspectRatio;
  set aspectRatio(double value) {
    if (_aspectRatio == value) return;
    _aspectRatio = value;
    markNeedsLayout();
  }

  /// The inset above the content's preview, which the content keeps clear of.
  double get topInset => _topInset;
  double _topInset;
  set topInset(double value) {
    if (_topInset == value) return;
    _topInset = value;
    markNeedsLayout();
  }

  /// The window inset the column keeps clear of on the left.
  double get leftInset => _leftInset;
  double _leftInset;
  set leftInset(double value) {
    if (_leftInset == value) return;
    _leftInset = value;
    markNeedsLayout();
  }

  /// The window inset the column keeps clear of on the right.
  double get rightInset => _rightInset;
  double _rightInset;
  set rightInset(double value) {
    if (_rightInset == value) return;
    _rightInset = value;
    markNeedsLayout();
  }

  /// The bottom bar's height at the last layout.
  ///
  /// The bar is as tall at any width, so a layout lays it out once, at the
  /// width this height leaves the frame, and a second time only when its
  /// height changed since. Laying it out at two widths on every layout would
  /// resize the mode wheel back and forth while it animates.
  double _bottomBarHeight = 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RecorderFrameParentData) {
      child.parentData = _RecorderFrameParentData();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  /// The column's width when the bottom bar is [bottomBarHeight] tall: as
  /// wide as the preview of [aspectRatio] that fits above the bar when
  /// [framed], and never wider than the space between the side insets.
  double _columnWidth(double bottomBarHeight) {
    final available = math.max(0.0, size.width - leftInset - rightInset);
    if (!framed) return available;
    final previewHeight = math.max(
      0.0,
      size.height - topInset - bottomBarHeight,
    );
    return math.min(available, previewHeight * aspectRatio);
  }

  /// Lays the bar out [width] wide at its own height, which is unbounded as
  /// in a column: bounded, the bar's alignments would stretch it to the
  /// window's height.
  void _layoutBottomBar(RenderBox bottomBar, double width) {
    bottomBar.layout(
      BoxConstraints.tightFor(width: width),
      parentUsesSize: true,
    );
  }

  @override
  void performLayout() {
    final content = firstChild!;
    final bottomBar = lastChild!;

    var width = _columnWidth(_bottomBarHeight);
    _layoutBottomBar(bottomBar, width);
    if (bottomBar.size.height != _bottomBarHeight) {
      _bottomBarHeight = bottomBar.size.height;
      final settledWidth = _columnWidth(_bottomBarHeight);
      if (settledWidth != width) {
        width = settledWidth;
        _layoutBottomBar(bottomBar, width);
      }
    }

    final bottomBarHeight = bottomBar.size.height;
    content.layout(
      BoxConstraints.tightFor(
        width: width,
        height: math.max(0.0, size.height - bottomBarHeight),
      ),
    );

    final available = math.max(0.0, size.width - leftInset - rightInset);
    final left = leftInset + (available - width) / 2;
    (content.parentData! as _RecorderFrameParentData).offset = Offset(left, 0);
    (bottomBar.parentData! as _RecorderFrameParentData).offset = Offset(
      left,
      size.height - bottomBarHeight,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
