// ABOUTME: The video editor's category tabs: one highlight that slides from
// ABOUTME: tab to tab with the page or grid they control.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A row of category tabs whose highlight slides from tab to tab, following
/// [controller] as the page or grid it drives moves. The row scrolls the
/// highlighted tab into view.
///
/// Shared by the effects and filter picker and the sound picker, so every
/// category row in the editor moves the same way.
class VideoEditorCategoryTabs extends StatelessWidget {
  const VideoEditorCategoryTabs({
    required this.controller,
    required this.labels,
    required this.onTap,
    this.tabHeight,
    this.highlightHeight,
    super.key,
  });

  /// The padding [TabBar] keeps below each tab, its indicator weight.
  static const double indicatorWeight = 2;

  /// The heights [VideoEditorCategoryTabs] lays out at for [textScaler]: a
  /// highlight that pads its label line by 6 above and below, as a tiny
  /// DivineButton does, inside a tab that stays a full tap target.
  static ({double tabHeight, double highlightHeight}) extentsOf(
    TextScaler textScaler,
    VineThemeColors colors,
  ) {
    final style = VineTheme.titleSmallFont(color: colors.accentBrand);
    final highlightHeight =
        textScaler.scale(style.fontSize!) * (style.height ?? 1.2) + 12;
    return (
      tabHeight: max(
        kMinInteractiveDimension - indicatorWeight,
        highlightHeight,
      ),
      highlightHeight: highlightHeight,
    );
  }

  final TabController controller;
  final List<String> labels;
  final ValueChanged<int> onTap;

  /// A tab without the padding [TabBar] keeps below it, which makes up the
  /// rest of its tap target. Defaults to [extentsOf].
  final double? tabHeight;

  /// Defaults to [extentsOf].
  final double? highlightHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final extents = extentsOf(MediaQuery.textScalerOf(context), colors);
    final tabHeight = this.tabHeight ?? extents.tabHeight;
    final highlightInset =
        (tabHeight - (highlightHeight ?? extents.highlightHeight)) / 2;
    return Material(
      type: MaterialType.transparency,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const .symmetric(horizontal: 12),
        labelPadding: const .symmetric(horizontal: 14),
        indicator: ShapeDecoration(
          color: colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: .circular(16),
            side: BorderSide(
              color: colors.isLight ? colors.outline : colors.outlineMuted,
            ),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        // The highlight hugs the label, not the whole tap target nor the
        // padding the tab keeps below it.
        indicatorPadding: .only(
          top: highlightInset,
          bottom: highlightInset + indicatorWeight,
        ),
        dividerHeight: 0,
        overlayColor: const WidgetStatePropertyAll(VineTheme.transparent),
        splashFactory: NoSplash.splashFactory,
        labelColor: colors.accentBrand,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: VineTheme.titleSmallFont(color: colors.accentBrand),
        unselectedLabelStyle: VineTheme.titleSmallFont(
          color: colors.onSurfaceVariant,
        ),
        onTap: onTap,
        tabs: [for (final label in labels) Tab(height: tabHeight, text: label)],
      ),
    );
  }
}
