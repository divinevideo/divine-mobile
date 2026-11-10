// ABOUTME: Auto-detect and the green/blue presets of the chroma-key panel,
// ABOUTME: reflowed onto more rows so no language or text size cuts a label.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/whole_word_button_text_scale.dart';

/// Auto-detect plus the two screen presets.
///
/// All three share one row while they fit at their natural widths, Auto-detect
/// stretching over what the presets leave. Once they do not — a long
/// translation, a large text size, a narrow phone — Auto-detect takes a
/// full-width row of its own and the presets halve the row below, and when
/// even they do not fit side by side each gets a row. Squeezed into one row,
/// Polish and Vietnamese Auto-detect were cut to a few letters at the normal
/// text size and overflowed from the middle sizes up (#10796).
///
/// Only Auto-detect waits for a wanted measurement. The presets stay live,
/// like the swatch and the sliders below them: someone who shot on blue should
/// not have to sit out the green measurement the panel started on its own. A
/// preset tapped while one runs writes it off instead — see
/// `ChromaKeyEditorState.isDetecting`.
class ChromaKeyDetectRow extends StatelessWidget {
  const ChromaKeyDetectRow({
    required this.isDetecting,
    required this.onDetect,
    required this.onGreenPreset,
    required this.onBluePreset,
    super.key,
  });

  /// Lines a label may wrap onto once it has a row of its own. Two is the
  /// most any locale needs at the largest text size; the third is slack.
  static const int _maxLabelLines = 3;

  /// Whether a measurement is running, which holds Auto-detect.
  final bool isDetecting;

  /// Measures the screen and adopts its colour and amount.
  final VoidCallback onDetect;

  /// Adopts the green-screen preset.
  final VoidCallback onGreenPreset;

  /// Adopts the blue-screen preset.
  final VoidCallback onBluePreset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) => _DetectRowLayout(
        children: [
          WholeWordButtonTextScale(
            label: l10n.videoEditorChromaKeyAutoDetect,
            width: constraints.maxWidth,
            hasLeadingIcon: true,
            child: DivineButton(
              label: l10n.videoEditorChromaKeyAutoDetect,
              leadingIcon: .sparkle,
              size: .small,
              // It is always drawn stretched, so its natural width has to be
              // measured with the stretched padding too, or the row would
              // give up on one line 16px before it had to.
              expanded: true,
              maxLines: _maxLabelLines,
              isLoading: isDetecting,
              onPressed: isDetecting ? null : onDetect,
            ),
          ),
          WholeWordButtonTextScale(
            label: l10n.videoEditorChromaKeyPresetGreen,
            width: constraints.maxWidth,
            child: DivineButton(
              label: l10n.videoEditorChromaKeyPresetGreen,
              type: .secondary,
              size: .small,
              maxLines: _maxLabelLines,
              onPressed: onGreenPreset,
            ),
          ),
          WholeWordButtonTextScale(
            label: l10n.videoEditorChromaKeyPresetBlue,
            width: constraints.maxWidth,
            child: DivineButton(
              label: l10n.videoEditorChromaKeyPresetBlue,
              type: .secondary,
              size: .small,
              maxLines: _maxLabelLines,
              onPressed: onBluePreset,
            ),
          ),
        ],
      ),
    );
  }
}

/// How [_RenderDetectRow] places Auto-detect and the two presets.
enum _Arrangement {
  /// All three side by side.
  singleRow,

  /// Auto-detect on a full-width row, the presets halving the row below.
  presetsBelow,

  /// Each button on a full-width row of its own.
  stacked,
}

/// Lays out exactly three buttons — Auto-detect, Green, Blue — as described
/// on [ChromaKeyDetectRow].
///
/// A render object because the choice turns on the buttons' natural widths,
/// which a widget cannot read, and `OverflowBar` cannot stretch Auto-detect
/// over what the presets leave.
class _DetectRowLayout extends MultiChildRenderObjectWidget {
  const _DetectRowLayout({required super.children})
    : assert(children.length == 3, 'Auto-detect, Green and Blue');

  @override
  _RenderDetectRow createRenderObject(BuildContext context) {
    return _RenderDetectRow(textDirection: Directionality.of(context));
  }

  @override
  void updateRenderObject(BuildContext context, _RenderDetectRow renderObject) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _DetectRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDetectRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DetectRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DetectRowParentData> {
  _RenderDetectRow({required TextDirection textDirection})
    : _textDirection = textDirection;

  /// Gap between buttons, across a row and between rows.
  static const double _spacing = 8;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DetectRowParentData) {
      child.parentData = _DetectRowParentData();
    }
  }

  static _Arrangement _arrangementFor(
    double maxWidth,
    List<double> naturalWidths,
  ) {
    final [autoDetect, green, blue] = naturalWidths;
    if (autoDetect + green + blue + _spacing * 2 <= maxWidth) {
      return _Arrangement.singleRow;
    }
    // A preset measures with the wider padding it hugs its label with, but a
    // half-row button draws with the narrower stretched one, so this test is
    // a little stricter than it has to be — never looser.
    final half = (maxWidth - _spacing) / 2;
    if (green <= half && blue <= half) return _Arrangement.presetsBelow;
    return _Arrangement.stacked;
  }

  /// Sizes and, unless [dry], positions the children.
  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final children = getChildrenAsList();
    final naturalWidths = [
      for (final child in children) child.getMaxIntrinsicWidth(double.infinity),
    ];
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : naturalWidths.fold(_spacing * 2, (sum, width) => sum + width);

    Size place(RenderBox child, BoxConstraints childConstraints) {
      if (dry) return child.getDryLayout(childConstraints);
      child.layout(childConstraints, parentUsesSize: true);
      return child.size;
    }

    BoxConstraints tight(double width) =>
        BoxConstraints.tightFor(width: math.max(0, width));

    // Left-to-right, mirrored for right-to-left once the width is known.
    final rects = <Rect>[];
    final double height;
    final [autoDetect, green, blue] = children;
    switch (_arrangementFor(maxWidth, naturalWidths)) {
      case _Arrangement.singleRow:
        final greenSize = place(green, BoxConstraints(maxWidth: maxWidth));
        final blueSize = place(blue, BoxConstraints(maxWidth: maxWidth));
        final autoSize = place(
          autoDetect,
          tight(maxWidth - greenSize.width - blueSize.width - _spacing * 2),
        );
        final sizes = [autoSize, greenSize, blueSize];
        height = sizes.map((size) => size.height).reduce(math.max);
        var x = 0.0;
        for (final size in sizes) {
          rects.add(Offset(x, (height - size.height) / 2) & size);
          x += size.width + _spacing;
        }
      case _Arrangement.presetsBelow:
        final autoSize = place(autoDetect, tight(maxWidth));
        final half = (maxWidth - _spacing) / 2;
        final greenSize = place(green, tight(half));
        final blueSize = place(blue, tight(half));
        final top = autoSize.height + _spacing;
        final rowHeight = math.max(greenSize.height, blueSize.height);
        rects.addAll([
          Offset.zero & autoSize,
          Offset(0, top + (rowHeight - greenSize.height) / 2) & greenSize,
          Offset(half + _spacing, top + (rowHeight - blueSize.height) / 2) &
              blueSize,
        ]);
        height = top + rowHeight;
      case _Arrangement.stacked:
        var y = 0.0;
        for (final child in children) {
          final size = place(child, tight(maxWidth));
          rects.add(Offset(0, y) & size);
          y += size.height + _spacing;
        }
        height = y - _spacing;
    }

    final size = constraints.constrain(Size(maxWidth, height));
    if (!dry) {
      for (final (index, child) in children.indexed) {
        final rect = rects[index];
        (child.parentData! as _DetectRowParentData).offset =
            switch (textDirection) {
              TextDirection.ltr => rect.topLeft,
              TextDirection.rtl => Offset(size.width - rect.right, rect.top),
            };
      }
    }
    return size;
  }

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  /// Narrowest when stacked, widest when all three share a row.
  @override
  double computeMinIntrinsicWidth(double height) => getChildrenAsList()
      .map((child) => child.getMinIntrinsicWidth(double.infinity))
      .fold(0, math.max);

  @override
  double computeMaxIntrinsicWidth(double height) => getChildrenAsList()
      .map((child) => child.getMaxIntrinsicWidth(double.infinity))
      .fold(_spacing * 2, (sum, width) => sum + width);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
