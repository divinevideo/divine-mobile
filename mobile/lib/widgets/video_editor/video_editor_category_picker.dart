// ABOUTME: Picker of the video editor's effects and filters: category tabs
// ABOUTME: over a grid of preview tiles, one titled section per category.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// A picker of items grouped into categories: a row of category tabs over a
/// grid of tiles, one titled section per category.
///
/// Scrolling the grid slides the tab highlight along and a tab scrolls the
/// grid to its section, as `VideoEditorFontList` does. Given an
/// [initialCategory], the grid starts at that category's section.
///
/// The picker reaches down under the system navigation bar, so the grid
/// scrolls on behind it; the editor must not pad it for the navigation bar.
class VideoEditorCategoryPicker<C extends Object, T> extends StatelessWidget {
  const VideoEditorCategoryPicker({
    required this.sections,
    required this.categoryLabel,
    required this.isSelected,
    required this.tileBuilder,
    this.initialCategory,
    super.key,
  });

  /// The height the editor reserves for the picker above the system
  /// navigation bar: the tabs over three rows of tiles, growing with the text
  /// size.
  static double heightOf(BuildContext context) =>
      _PickerMetrics(_textScalerOf(context), context.vineColors).barExtent;

  /// The text size the picker lays out at, capped so large text cannot crowd
  /// out the preview.
  static TextScaler _textScalerOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25);

  /// The items of each category, in picker order; one tab per key.
  final Map<C, List<T>> sections;

  /// The localized name of a category, on its tab and over its section.
  final String Function(BuildContext context, C category) categoryLabel;

  /// Whether an item is the picked one, which the grid reveals when it
  /// becomes so.
  final bool Function(T item) isSelected;

  /// The tile of an item, usually a [VideoEditorCategoryPickerTile].
  final Widget Function(BuildContext context, T item, bool isSelected)
  tileBuilder;

  /// The category the grid opens at. Only read when the picker is first
  /// built.
  final C? initialCategory;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: _textScalerOf(context)),
      child: _CategoryPicker<C, T>(picker: this),
    );
  }
}

const double _gridPadding = 16;
const double _gridBottomPadding = 8;
const double _rowSpacing = 12;
const double _columnSpacing = 8;
const double _minTileWidth = 64;

/// How far the tabs' shadow reaches down over the grid.
const double _shadowExtent = 16;

/// The TabBar's default; each tab is padded by it below its label.
const double _tabIndicatorWeight = 2;

/// Between a tile's preview and its name.
const double _previewLabelGap = 4;

/// Around a section title; the first sits close under the tabs, every other
/// one leaves a gap to the section above.
const EdgeInsets _firstHeaderPadding = EdgeInsets.fromLTRB(16, 5, 16, 8);
const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(16, 43, 16, 8);

/// The width and height of a tile's preview frame, border included.
const double _previewSize = 52;

class _CategoryPicker<C extends Object, T> extends StatefulWidget {
  const _CategoryPicker({required this.picker});

  final VideoEditorCategoryPicker<C, T> picker;

  @override
  State<_CategoryPicker<C, T>> createState() => _CategoryPickerState<C, T>();
}

class _CategoryPickerState<C extends Object, T>
    extends State<_CategoryPicker<C, T>>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  final _gridController = ScrollController();

  /// The tab of the category the grid opens at, if any. A category with no
  /// section opens the grid at its start.
  late final int? _initialIndex = switch (widget.picker.initialCategory) {
    final category? when widget.picker.sections.containsKey(category) =>
      _categories.indexOf(category),
    _ => null,
  };

  /// Whether scrolling moves the tab highlight. A jump to a section, from a
  /// tab tap or on opening at [VideoEditorCategoryPicker.initialCategory],
  /// stops it until the user scrolls again, because the grid passes other
  /// sections on its way and a jump to one of the last sections is clamped at
  /// the end of the grid.
  bool _followScroll = true;

  /// Whether the grid has scrolled under the tabs, which then cast a shadow
  /// on it.
  bool _scrolledUnder = false;

  /// Set by [build], from the text size and width it lays out at, and read
  /// by [_onScroll] and [_scrollGridTo] in between.
  late _GridLayout _layout;

  List<C> get _categories => widget.picker.sections.keys.toList();

  @override
  int get tabCount => widget.picker.sections.length;

  @override
  int get initialTabIndex => _initialIndex ?? 0;

  @override
  void initState() {
    super.initState();
    _gridController.addListener(_onScroll);
    if (_initialIndex case final index?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollGridTo(index, animate: false);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  void didUpdateWidget(_CategoryPicker<C, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTabController();
  }

  @override
  void dispose() {
    _gridController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_gridController.hasClients) return;
    final position = _gridController.position;
    final scrolledUnder = position.pixels > 0;
    if (scrolledUnder != _scrolledUnder) {
      setState(() => _scrolledUnder = scrolledUnder);
    }
    if (!_followScroll) return;
    final index = _layout.sectionAt(
      position.pixels,
      maxOffset: position.maxScrollExtent,
    );
    if (tabController.index != index) tabController.animateTo(index);
  }

  void _scrollGridTo(int index, {required bool animate}) {
    _followScroll = false;
    if (!_gridController.hasClients) return;
    final target = min(
      _layout.offsetOf(index),
      _gridController.position.maxScrollExtent,
    );
    if (!animate || context.reduceMotion) {
      _gridController.jumpTo(target);
      return;
    }
    runDetached(
      _gridController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      ),
      'scroll the picker grid to a category',
      logName: 'VideoEditorCategoryPicker',
      category: LogCategory.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    final picker = widget.picker;
    final metrics = _PickerMetrics(
      MediaQuery.textScalerOf(context),
      context.vineColors,
    );
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    _layout = _GridLayout(
      metrics,
      sectionLengths: [
        for (final items in picker.sections.values) items.length,
      ],
      width: MediaQuery.sizeOf(context).width,
    );
    final categories = _categories;
    return SizedBox(
      height: metrics.barExtent + bottomInset,
      child: Stack(
        children: [
          Positioned.fill(
            top: metrics.tabsExtent,
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction != ScrollDirection.idle) {
                  _followScroll = true;
                }
                return false;
              },
              child: CustomScrollView(
                controller: _gridController,
                slivers: [
                  for (final (index, category) in categories.indexed) ...[
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: metrics.headerExtentOf(index),
                        child: _SectionHeader(
                          label: picker.categoryLabel(context, category),
                          isFirst: index == 0,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const .symmetric(horizontal: _gridPadding),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _layout.columns,
                          mainAxisExtent: metrics.rowExtent,
                          mainAxisSpacing: _rowSpacing,
                          crossAxisSpacing: _columnSpacing,
                        ),
                        itemCount: picker.sections[category]!.length,
                        itemBuilder: (context, itemIndex) {
                          final item = picker.sections[category]![itemIndex];
                          final isSelected = picker.isSelected(item);
                          return _RevealWhenSelected(
                            isSelected: isSelected,
                            child: picker.tileBuilder(
                              context,
                              item,
                              isSelected,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  // The last row can scroll clear of the navigation bar.
                  SliverPadding(
                    padding: .only(bottom: _gridBottomPadding + bottomInset),
                  ),
                ],
              ),
            ),
          ),
          // The tabs' shadow on the tiles scrolled under them. A gradient
          // rather than a box shadow: a soft drop shadow is lost on the dark
          // surface.
          Positioned(
            top: metrics.tabsExtent,
            left: 0,
            right: 0,
            height: _shadowExtent,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _scrolledUnder ? 1 : 0,
                duration: const Duration(milliseconds: 150)
                    .autoReduceMotion(context),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: .topCenter,
                      end: .bottomCenter,
                      colors: [
                        VineTheme.scrim50,
                        VineTheme.scrim50.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: metrics.tabsExtent,
            child: ColoredBox(
              color: context.vineColors.surfaceContainerHigh,
              child: Align(
                alignment: .bottomCenter,
                child: _CategoryTabs(
                  controller: tabController,
                  labels: [
                    for (final category in categories)
                      picker.categoryLabel(context, category),
                  ],
                  tabHeight: metrics.tabHeight,
                  highlightHeight: metrics.highlightHeight,
                  onTap: (index) => _scrollGridTo(index, animate: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extents of the picker. They are fixed, so a tab can scroll to a section
/// the grid has not built yet, and grow with the text size.
class _PickerMetrics {
  /// Measured in the styles the tabs, the section titles and the tile names
  /// are drawn in; their colours only keep each style complete.
  factory _PickerMetrics(TextScaler textScaler, VineThemeColors colors) {
    double lineOf(TextStyle style) =>
        textScaler.scale(style.fontSize!) * (style.height ?? 1.2);

    // A tab's highlight pads its label line by 6 above and below, as a tiny
    // DivineButton does; the tab around it is a full tap target.
    final highlightHeight =
        lineOf(VineTheme.titleSmallFont(color: colors.accentBrand)) + 12;
    final titleLine = lineOf(
      VineTheme.labelSmallFont(color: colors.onSurfaceMuted),
    );
    return _PickerMetrics._(
      highlightHeight: highlightHeight,
      tabHeight: max(
        kMinInteractiveDimension - _tabIndicatorWeight,
        highlightHeight,
      ),
      firstHeaderExtent: titleLine + _firstHeaderPadding.vertical,
      headerExtent: titleLine + _headerPadding.vertical,
      // A tile is its preview over one line of its name.
      rowExtent:
          _previewSize +
          _previewLabelGap +
          lineOf(VineTheme.bodySmallFont(color: colors.onSurface)),
    );
  }

  const _PickerMetrics._({
    required this.highlightHeight,
    required this.tabHeight,
    required this.firstHeaderExtent,
    required this.headerExtent,
    required this.rowExtent,
  });

  final double highlightHeight;

  /// A tab without the padding [TabBar] keeps below it, which makes up the
  /// rest of its tap target.
  final double tabHeight;
  final double firstHeaderExtent;
  final double headerExtent;
  final double rowExtent;

  double get tabsExtent => tabHeight + _tabIndicatorWeight;

  /// The height of the title over the section at [index].
  double headerExtentOf(int index) =>
      index == 0 ? firstHeaderExtent : headerExtent;

  /// The first section's title over three rows of tiles.
  double get gridViewportExtent =>
      firstHeaderExtent + 3 * rowExtent + 2 * _rowSpacing + _gridBottomPadding;

  double get barExtent => tabsExtent + gridViewportExtent;
}

/// How the sections lay out across [width]: as many columns as fit, and the
/// scroll offset that shows each section's title at the top.
class _GridLayout {
  factory _GridLayout(
    _PickerMetrics metrics, {
    required List<int> sectionLengths,
    required double width,
  }) {
    final usable = width - 2 * _gridPadding;
    final columns = max(
      1,
      ((usable + _columnSpacing) / (_minTileWidth + _columnSpacing)).floor(),
    );
    // A title is shown at the top where the first one sits, just under the
    // tabs, not where the gap above it starts.
    final gapAboveTitle = _headerPadding.top - _firstHeaderPadding.top;
    final titleOffsets = <double>[];
    var offset = 0.0;
    for (final (index, length) in sectionLengths.indexed) {
      titleOffsets.add(index == 0 ? 0 : offset + gapAboveTitle);
      final rows = (length / columns).ceil();
      offset +=
          metrics.headerExtentOf(index) +
          rows * metrics.rowExtent +
          max(rows - 1, 0) * _rowSpacing;
    }
    return _GridLayout._(columns, titleOffsets);
  }

  const _GridLayout._(this.columns, this._titleOffsets);

  final int columns;

  /// By section index.
  final List<double> _titleOffsets;

  /// Where a tab scrolls the grid to: the title of the section at [index] at
  /// the top.
  double offsetOf(int index) => _titleOffsets[index];

  /// The index of the section whose title has scrolled to the top of the
  /// grid at [offset], in a grid that scrolls up to [maxOffset].
  ///
  /// The last sections can be too short for their titles to reach the top.
  /// They share the scroll left after the last title that does, in order, so
  /// every tab still gets its turn and the last one is highlighted at the
  /// end.
  int sectionAt(double offset, {required double maxOffset}) {
    final starts = List.of(_titleOffsets);
    final firstUnreachable = starts.indexWhere((start) => start > maxOffset);
    if (firstUnreachable > 0) {
      final from = starts[firstUnreachable - 1];
      final step = (maxOffset - from) / (starts.length - firstUnreachable);
      for (var i = firstUnreachable; i < starts.length; i++) {
        starts[i] = from + (i - firstUnreachable + 1) * step;
      }
    }
    var section = 0;
    for (final (index, start) in starts.indexed) {
      if (start <= offset + 1) section = index;
    }
    return section;
  }
}

/// The category tabs. One highlight slides from tab to tab, and the tab row
/// scrolls the highlighted tab into view.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.controller,
    required this.labels,
    required this.tabHeight,
    required this.highlightHeight,
    required this.onTap,
  });

  final TabController controller;
  final List<String> labels;
  final double tabHeight;
  final double highlightHeight;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final highlightInset = (tabHeight - highlightHeight) / 2;
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
          bottom: highlightInset + _tabIndicatorWeight,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.isFirst});

  final String label;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: isFirst ? _firstHeaderPadding : _headerPadding,
          child: Text(
            label,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            maxLines: 1,
            overflow: .ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Scrolls [child] fully into view when it becomes selected, clear of the
/// system navigation bar the grid scrolls on under, so a tile picked at the
/// edge of the grid shows whole.
///
/// Only on becoming selected: the grid builds lazily, so a picked tile is
/// built again whenever it scrolls back in, and must not pull the grid then.
class _RevealWhenSelected extends StatefulWidget {
  const _RevealWhenSelected({required this.isSelected, required this.child});

  final bool isSelected;
  final Widget child;

  @override
  State<_RevealWhenSelected> createState() => _RevealWhenSelectedState();
}

class _RevealWhenSelectedState extends State<_RevealWhenSelected> {
  @override
  void didUpdateWidget(_RevealWhenSelected oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tile = context.findRenderObject();
      if (tile is! RenderBox) return;
      final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
      // The grid scrolls only when an edge of this rect is cut off.
      tile.showOnScreen(
        rect:
            Offset.zero & Size(tile.size.width, tile.size.height + bottomInset),
        duration: const Duration(milliseconds: 200).autoReduceMotion(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A tile of a [VideoEditorCategoryPicker]: [preview] in a rounded, bordered
/// frame over the item's [label]; the border turns the positive accent while
/// [isSelected].
class VideoEditorCategoryPickerTile extends StatelessWidget {
  const VideoEditorCategoryPickerTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.preview,
    super.key,
  });

  /// The width and height of the frame [preview] is drawn in, border
  /// included.
  static const double previewSize = _previewSize;

  /// The item's name, shown under the frame and read by screen readers.
  final String label;

  /// Whether this is the picked item.
  final bool isSelected;

  /// Picks the item.
  final VoidCallback onTap;

  /// Fills the frame, inside its border.
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: .end,
          spacing: _previewLabelGap,
          children: [
            Container(
              width: _previewSize,
              height: _previewSize,
              decoration: BoxDecoration(
                color: context.vineColors.surfaceContainer,
                borderRadius: .circular(20),
                border: .all(
                  color: isSelected
                      ? context.vineColors.accentPositive
                      : context.vineColors.outlineMuted,
                  width: 2,
                ),
              ),
              child: ClipRRect(borderRadius: .circular(18), child: preview),
            ),
            // The tile's Semantics already carries the name.
            ExcludeSemantics(
              child: Text(
                label,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurface,
                ),
                maxLines: 1,
                textAlign: .center,
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
