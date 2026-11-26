// ABOUTME: Readable content widths for box layouts and full-width scroll views.

import 'dart:math' as math;

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

  /// Applies the cap even with the large-screen layouts off. Use this to
  /// preserve caps that predate the layouts. Otherwise the child is returned
  /// directly when the layouts are off.
  final bool capWithoutLargeLayout;

  /// Positions the child within the space available to the column.
  final AlignmentGeometry alignment;

  /// Scales the child's height to size the column. Use 1 to wrap the child's
  /// height in a bounded parent, such as a bottom action bar.
  final double? heightFactor;

  /// Applies the width cap using the space offered by the parent.
  @override
  Widget build(BuildContext context) {
    if (!capWithoutLargeLayout && !context.adaptiveLayout.enabled) {
      return child;
    }

    return Align(
      alignment: alignment,
      heightFactor: heightFactor,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width.maxWidth),
        child: child,
      ),
    );
  }
}

/// Centers a sliver in a vertical scroll view by adding horizontal padding.
///
/// The padding comes from the sliver's own cross-axis extent, including when
/// side navigation takes up part of the window. The viewport stays full width,
/// so its scrollbar can stay at the edge and wheel and trackpad scrolling work
/// over the empty margins.
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

  /// Applies the cap even with the large-screen layouts off. Use this to
  /// preserve caps that predate the layouts.
  final bool capWithoutLargeLayout;

  /// Pads the content within the viewport when the cap is active.
  @override
  Widget build(BuildContext context) {
    final cap = capWithoutLargeLayout || context.adaptiveLayout.enabled;
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
