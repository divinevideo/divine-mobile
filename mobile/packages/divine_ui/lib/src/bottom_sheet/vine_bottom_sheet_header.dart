// ABOUTME: Header component for VineBottomSheet
// ABOUTME: Displays title with optional trailing actions (badges, buttons)

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Header component for [VineBottomSheet].
///
/// Combines drag handle and title section as per Figma design.
/// Uses Bricolage Grotesque bold font at 24px for title.
///
/// The title is centered on the full header width, never between the
/// leading/trailing slots, so it does not move when a slot changes width — a
/// sort chip relabelled New → Top, or two icon buttons whose variants happen
/// to differ by a couple of pixels. Both sides are kept clear by capping the
/// title at `width - 2 * widestSlot - 2 * gap` instead of reserving layout
/// space opposite the filled slot, so a wide slot costs the title its own
/// width once rather than twice and the row cannot overflow.
///
/// If a slot grows so wide that keeping the same width clear on the empty
/// side would leave the title no room at all — a text-driven slot at
/// accessibility text scales on a narrow screen — the title falls back to the
/// space between the slots. Centering is geometrically impossible at that
/// point; the alternative is a title squeezed to zero width.
class VineBottomSheetHeader extends StatelessWidget {
  /// Creates a [VineBottomSheetHeader] with the given title and optional
  /// leading and trailing widgets.
  const VineBottomSheetHeader({
    this.title,
    this.leading,
    this.trailing,
    this.showDivider = true,
    this.showDragHandle = true,
    this.padding,
    this.leadingAction,
    this.trailingAction,
    super.key,
  });

  /// Optional title widget displayed in the center
  final Widget? title;

  /// Optional leading widget on the left (e.g., close button)
  final Widget? leading;

  /// Optional trailing widget on the right (e.g., badge, button)
  final Widget? trailing;

  /// Whether to show the divider below the header.
  ///
  /// Defaults to true.
  final bool showDivider;

  /// Whether to show the drag handle at the top of the header.
  ///
  /// Defaults to true.
  final bool showDragHandle;

  /// Optional padding override for the inner content area.
  ///
  /// Defaults to `EdgeInsetsDirectional.only(start: 24, end: 24, top: 8)`.
  final EdgeInsetsGeometry? padding;

  /// Optional icon button displayed on the left side of the header.
  final DivineIconButton? leadingAction;

  /// Optional icon button displayed on the right side of the header.
  final DivineIconButton? trailingAction;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title is! SizedBox;
    final leadingSlot = leadingAction ?? leading;
    final trailingSlot = trailingAction ?? trailing;
    final hasHeaderRow =
        hasTitle || leadingSlot != null || trailingSlot != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding:
              padding ??
              (const EdgeInsetsDirectional.only(start: 16, end: 16, top: 8)),
          child: Column(
            spacing: 20,
            children: [
              // Drag handle
              if (showDragHandle)
                Container(
                  width: 64,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.vineColors.disabled,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

              Padding(
                padding: .only(bottom: hasHeaderRow ? 14 : 0),
                child: _HeaderRow(
                  leading: leadingSlot,
                  trailing: trailingSlot,
                  title: hasTitle
                      ? DefaultTextStyle(
                          style: VineTheme.titleMediumFont(
                            color: context.vineColors.onSurface,
                          ),
                          textAlign: .center,
                          child: title!,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),

        // Divider separating header from content
        if (showDivider)
          Divider(
            height: 2,
            thickness: 2,
            color: context.vineColors.surfaceContainer,
          ),
      ],
    );
  }
}

enum _HeaderSlot { leading, title, trailing }

/// Lays out the header's leading slot at the start, the trailing slot at the
/// end, and the title centered on the full width.
///
/// A [Row] cannot do this. Centering there means balancing the filled slot
/// with an equally wide box on the empty side, which charges the title twice
/// for one slot and overflows once the two copies plus the gaps exceed the
/// row. Positioning the title independently of the slots costs nothing and
/// stays exact when the slots differ in width.
class _HeaderRow
    extends SlottedMultiChildRenderObjectWidget<_HeaderSlot, RenderBox> {
  const _HeaderRow({this.leading, this.title, this.trailing});

  final Widget? leading;
  final Widget? title;
  final Widget? trailing;

  @override
  Iterable<_HeaderSlot> get slots => _HeaderSlot.values;

  @override
  Widget? childForSlot(_HeaderSlot slot) => switch (slot) {
    _HeaderSlot.leading => leading,
    _HeaderSlot.title => title,
    _HeaderSlot.trailing => trailing,
  };

  @override
  _RenderHeaderRow createRenderObject(BuildContext context) =>
      _RenderHeaderRow(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderHeaderRow renderObject) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _RenderHeaderRow extends RenderBox
    with SlottedContainerRenderObjectMixin<_HeaderSlot, RenderBox> {
  _RenderHeaderRow({required TextDirection textDirection})
    : _textDirection = textDirection;

  /// Minimum gap between the title and either slot.
  static const _gap = 12.0;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _leading => childForSlot(_HeaderSlot.leading);
  RenderBox? get _title => childForSlot(_HeaderSlot.title);
  RenderBox? get _trailing => childForSlot(_HeaderSlot.trailing);

  // Reading order, which is also paint and semantics traversal order.
  @override
  Iterable<RenderBox> get children => <RenderBox>[
    ?_leading,
    ?_title,
    ?_trailing,
  ];

  /// Width each side keeps clear of the title, so the centered title clears
  /// the wider slot on both sides.
  double _sideInset(double leadingWidth, double trailingWidth) {
    final widest = math.max(leadingWidth, trailingWidth);
    return widest == 0 ? 0 : widest + _gap;
  }

  Size _computeLayout(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    bool positionChildren = false,
  }) {
    final leading = _leading;
    final title = _title;
    final trailing = _trailing;
    final slotConstraints = BoxConstraints.loose(
      Size(constraints.maxWidth, double.infinity),
    );

    final leadingSize = leading == null
        ? Size.zero
        : layoutChild(leading, slotConstraints);
    final trailingSize = trailing == null
        ? Size.zero
        : layoutChild(trailing, slotConstraints);

    final inset = _sideInset(leadingSize.width, trailingSize.width);
    // Unbounded width only happens through misuse (a header in an
    // unconstrained Row); there is always room to center in that case.
    final centeredBudget = constraints.hasBoundedWidth
        ? constraints.maxWidth - inset * 2
        : double.infinity;
    // One slot can be wide enough that keeping the same width clear on the
    // empty side leaves the title nothing. Centering is then impossible
    // rather than merely tight, so the title takes the space between the
    // slots instead of collapsing to zero.
    final canCenter = centeredBudget > 0;
    final leadStart = leadingSize.width + (leading == null ? 0 : _gap);
    final titleSize = title == null
        ? Size.zero
        : layoutChild(
            title,
            BoxConstraints(
              maxWidth: canCenter
                  ? centeredBudget
                  : math.max<double>(
                      0,
                      constraints.maxWidth -
                          leadStart -
                          trailingSize.width -
                          (trailing == null ? 0 : _gap),
                    ),
            ),
          );

    final size = constraints.constrain(
      Size(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : titleSize.width + inset * 2,
        math.max(
          titleSize.height,
          math.max(leadingSize.height, trailingSize.height),
        ),
      ),
    );

    if (positionChildren) {
      final isRtl = textDirection == TextDirection.rtl;
      if (leading != null) {
        _positionChild(
          leading,
          isRtl ? size.width - leadingSize.width : 0,
          size.height - leadingSize.height,
        );
      }
      if (trailing != null) {
        _positionChild(
          trailing,
          isRtl ? 0 : size.width - trailingSize.width,
          size.height - trailingSize.height,
        );
      }
      if (title != null) {
        final titleX = canCenter
            ? (size.width - titleSize.width) / 2
            : (isRtl ? size.width - leadStart - titleSize.width : leadStart);
        _positionChild(title, titleX, size.height - titleSize.height);
      }
    }

    return size;
  }

  /// Positions [child] at [x], vertically centered in the remaining [freeY].
  void _positionChild(RenderBox child, double x, double freeY) {
    (child.parentData! as BoxParentData).offset = Offset(x, freeY / 2);
  }

  @override
  void performLayout() {
    size = _computeLayout(
      constraints,
      ChildLayoutHelper.layoutChild,
      positionChildren: true,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeLayout(constraints, ChildLayoutHelper.dryLayoutChild);

  double _intrinsicInset(double height) => _sideInset(
    _leading?.getMaxIntrinsicWidth(height) ?? 0,
    _trailing?.getMaxIntrinsicWidth(height) ?? 0,
  );

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicInset(height) * 2 + (_title?.getMinIntrinsicWidth(height) ?? 0);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicInset(height) * 2 + (_title?.getMaxIntrinsicWidth(height) ?? 0);

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) intrinsic,
  ) {
    final titleWidth = width.isFinite
        ? math.max<double>(0, width - _intrinsicInset(double.infinity) * 2)
        : width;
    var height = _title == null ? 0.0 : intrinsic(_title!, titleWidth);
    for (final slot in <RenderBox?>[_leading, _trailing]) {
      if (slot != null) {
        height = math.max(height, intrinsic(slot, double.infinity));
      }
    }
    return height;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMaxIntrinsicHeight(width),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        (child.parentData! as BoxParentData).offset + offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Front to back, so the topmost child wins a shared pixel.
    for (final child in children.toList().reversed) {
      final childOffset = (child.parentData! as BoxParentData).offset;
      final isHit = result.addWithPaintOffset(
        offset: childOffset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }
}
