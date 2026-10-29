// ABOUTME: Bottom bar of the video effects editor: category tabs over a grid
// ABOUTME: of preview tiles, one titled section per category, synced to scroll.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoEffect, VideoEffectPreview, VideoEffectType;
import 'package:unified_logger/unified_logger.dart';

/// Bottom bar of the effects editor: a row of category tabs over a grid of
/// the effects, one titled section per category.
///
/// Scrolling the grid slides the tab highlight along and a tab scrolls the
/// grid to its section, as in the font picker. Opened on an effect of the
/// timeline, the grid starts at that effect's section.
///
/// The bar reaches down under the system navigation bar, so the grid scrolls
/// on behind it; the editor must not pad the bar for it.
///
/// Each tile shows its effect on the first clip's thumbnail, at full strength
/// and at the start of the effect, where the glitch always bursts.
class VideoEditorEffectsBottomBar extends ConsumerWidget {
  const VideoEditorEffectsBottomBar({super.key});

  /// The height the editor reserves for the bar above the system navigation
  /// bar: the tabs over three rows of effects, growing with the text size.
  static double heightOf(BuildContext context) =>
      _PickerMetrics(_textScalerOf(context), context.vineColors).barExtent;

  /// The text size the bar lays out at, capped so large text cannot crowd out
  /// the preview.
  static TextScaler _textScalerOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailPath = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull?.thumbnailPath),
    );
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: _textScalerOf(context)),
      child: _EffectsPicker(thumbnailPath: thumbnailPath),
    );
  }
}

/// The effects of each category, in picker order.
final Map<EditorEffectCategory, List<EditorEffectType>> _sections = {
  for (final category in EditorEffectCategory.values) category: category.types,
};

const double _gridPadding = 16;
const double _gridBottomPadding = 8;
const double _rowSpacing = 12;
const double _columnSpacing = 8;
const double _minTileWidth = 64;
const double _tabsTopPadding = 8;

/// How far the tabs' shadow reaches down over the grid.
const double _shadowExtent = 16;

/// The TabBar's default; each tab is padded by it below its label.
const double _tabIndicatorWeight = 2;

/// Around a section title; the first sits close under the tabs, every other
/// one leaves a gap to the section above.
const EdgeInsets _firstHeaderPadding = EdgeInsets.fromLTRB(16, 5, 16, 8);
const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(16, 43, 16, 8);

/// The width and height of an effect's preview.
const double _previewSize = 52;

class _EffectsPicker extends StatefulWidget {
  const _EffectsPicker({required this.thumbnailPath});

  final String? thumbnailPath;

  @override
  State<_EffectsPicker> createState() => _EffectsPickerState();
}

class _EffectsPickerState extends State<_EffectsPicker>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  final _gridController = ScrollController();

  /// The category of the effect the editor opened on, if any.
  late final EditorEffectCategory? _editedCategory = context
      .read<VideoEditorEffectsCubit>()
      .state
      .selectedType
      ?.category;

  /// Whether scrolling moves the tab highlight. A tab tap stops it until the
  /// user scrolls again, because the grid passes other sections on its way
  /// and a jump to one of the last sections is clamped at the end of the grid.
  bool _followScroll = true;

  /// Whether the grid has scrolled under the tabs, which then cast a shadow
  /// on it.
  bool _scrolledUnder = false;

  /// Set by [build], from the text size and width it lays out at, and read
  /// by the scroll handlers in between.
  late _PickerMetrics _metrics;
  late _GridLayout _layout;

  @override
  int get tabCount => EditorEffectCategory.values.length;

  @override
  int get initialTabIndex => _editedCategory?.index ?? 0;

  @override
  void initState() {
    super.initState();
    _gridController.addListener(_onScroll);
    if (_editedCategory case final category?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollGridTo(category, animate: false);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final atEnd = position.pixels >= position.maxScrollExtent - 1;
    final category = atEnd
        ? EditorEffectCategory.values.last
        : _layout.categoryAt(position.pixels);
    if (tabController.index != category.index) {
      tabController.animateTo(category.index);
    }
  }

  void _scrollGridTo(EditorEffectCategory category, {required bool animate}) {
    _followScroll = false;
    if (!_gridController.hasClients) return;
    final target = min(
      _layout.offsetOf(category),
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
      'scroll the effects grid to a category',
      logName: 'VideoEditorEffectsBottomBar',
      category: LogCategory.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType,
    );
    _metrics = _PickerMetrics(
      MediaQuery.textScalerOf(context),
      context.vineColors,
    );
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    _layout = _GridLayout(_metrics, width: MediaQuery.sizeOf(context).width);
    return SizedBox(
      height: _metrics.barExtent + bottomInset,
      child: Stack(
        children: [
          Positioned.fill(
            top: _metrics.tabsExtent,
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
                  for (final MapEntry(key: category, value: types)
                      in _sections.entries) ...[
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: _metrics.headerExtentOf(category),
                        child: _SectionHeader(category: category),
                      ),
                    ),
                    SliverPadding(
                      padding: const .symmetric(horizontal: _gridPadding),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _layout.columns,
                          mainAxisExtent: _metrics.rowExtent,
                          mainAxisSpacing: _rowSpacing,
                          crossAxisSpacing: _columnSpacing,
                        ),
                        itemCount: types.length,
                        itemBuilder: (context, index) => _RevealWhenSelected(
                          isSelected: types[index] == selectedType,
                          child: _EffectItem(
                            type: types[index],
                            isSelected: types[index] == selectedType,
                            thumbnailPath: widget.thumbnailPath,
                          ),
                        ),
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
          // The tabs' shadow on the effects scrolled under them. A gradient
          // rather than a box shadow: a soft drop shadow is lost on the dark
          // surface.
          Positioned(
            top: _metrics.tabsExtent,
            left: 0,
            right: 0,
            height: _shadowExtent,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _scrolledUnder ? 1 : 0,
                duration: const Duration(
                  milliseconds: 150,
                ).autoReduceMotion(context),
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
            height: _metrics.tabsExtent,
            child: ColoredBox(
              color: context.vineColors.surfaceContainerHigh,
              child: Align(
                alignment: .bottomCenter,
                child: _CategoryTabs(
                  controller: tabController,
                  tabHeight: _metrics.tabHeight,
                  onTap: (index) => _scrollGridTo(
                    EditorEffectCategory.values[index],
                    animate: true,
                  ),
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
  /// are drawn in, coloured as they are.
  factory _PickerMetrics(TextScaler textScaler, VineThemeColors colors) {
    double lineOf(TextStyle style) =>
        textScaler.scale(style.fontSize!) * (style.height ?? 1.2);

    // A tab pads its label line by 6 above and below, as a tiny DivineButton
    // does.
    final tabHeight =
        lineOf(VineTheme.titleSmallFont(color: colors.accentBrand)) + 12;
    final titleLine = lineOf(
      VineTheme.labelSmallFont(color: colors.onSurfaceMuted),
    );
    return _PickerMetrics._(
      tabHeight: tabHeight,
      firstHeaderExtent: titleLine + _firstHeaderPadding.vertical,
      headerExtent: titleLine + _headerPadding.vertical,
      // A tile is its preview, a gap of 4 and one line of its name.
      rowExtent:
          _previewSize +
          4 +
          lineOf(VineTheme.bodySmallFont(color: colors.onSurface)),
    );
  }

  const _PickerMetrics._({
    required this.tabHeight,
    required this.firstHeaderExtent,
    required this.headerExtent,
    required this.rowExtent,
  });

  final double tabHeight;
  final double firstHeaderExtent;
  final double headerExtent;
  final double rowExtent;

  double get tabsExtent => _tabsTopPadding + tabHeight + _tabIndicatorWeight;

  double headerExtentOf(EditorEffectCategory category) =>
      category == EditorEffectCategory.values.first
      ? firstHeaderExtent
      : headerExtent;

  /// The first section's title over three rows of tiles.
  double get gridViewportExtent =>
      firstHeaderExtent + 3 * rowExtent + 2 * _rowSpacing + _gridBottomPadding;

  double get barExtent => tabsExtent + gridViewportExtent;
}

/// How the sections lay out across [width]: as many columns as fit, and the
/// scroll offset that shows each section's title at the top.
class _GridLayout {
  factory _GridLayout(_PickerMetrics metrics, {required double width}) {
    final usable = width - 2 * _gridPadding;
    final columns = max(
      1,
      ((usable + _columnSpacing) / (_minTileWidth + _columnSpacing)).floor(),
    );
    // A title is shown at the top where the first one sits, just under the
    // tabs, not where the gap above it starts.
    final gapAboveTitle = _headerPadding.top - _firstHeaderPadding.top;
    final titleOffsets = <EditorEffectCategory, double>{};
    var offset = 0.0;
    for (final MapEntry(key: category, value: types) in _sections.entries) {
      titleOffsets[category] = category == EditorEffectCategory.values.first
          ? 0
          : offset + gapAboveTitle;
      final rows = (types.length / columns).ceil();
      offset +=
          metrics.headerExtentOf(category) +
          rows * metrics.rowExtent +
          (rows - 1) * _rowSpacing;
    }
    return _GridLayout._(columns, titleOffsets);
  }

  const _GridLayout._(this.columns, this._titleOffsets);

  final int columns;
  final Map<EditorEffectCategory, double> _titleOffsets;

  /// Where a tab scrolls the grid to: its section's title at the top.
  double offsetOf(EditorEffectCategory category) => _titleOffsets[category]!;

  /// The section whose title has scrolled to the top of the grid at
  /// [offset].
  EditorEffectCategory categoryAt(double offset) {
    var category = EditorEffectCategory.values.first;
    for (final MapEntry(key: candidate, value: start)
        in _titleOffsets.entries) {
      if (start <= offset + 1) category = candidate;
    }
    return category;
  }
}

/// The category tabs. One highlight slides from tab to tab, and the tab row
/// scrolls the highlighted tab into view.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.controller,
    required this.tabHeight,
    required this.onTap,
  });

  final TabController controller;
  final double tabHeight;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
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
        // The highlight covers the label, not the padding the tab keeps
        // below it.
        indicatorPadding: const .only(bottom: _tabIndicatorWeight),
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
        tabs: [
          for (final category in EditorEffectCategory.values)
            Tab(height: tabHeight, text: _categoryLabel(context, category)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.category});

  final EditorEffectCategory category;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: category == EditorEffectCategory.values.first
              ? _firstHeaderPadding
              : _headerPadding,
          child: Text(
            _categoryLabel(context, category),
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

/// Scrolls [child] fully into view when it becomes selected, so a tile picked
/// at the edge of the grid shows whole.
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
      final duration = const Duration(
        milliseconds: 200,
      ).autoReduceMotion(context);
      // Each scrolls only when its edge is cut off, so at most one moves.
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ]) {
        runDetached(
          Scrollable.ensureVisible(
            context,
            duration: duration,
            alignmentPolicy: policy,
          ),
          'reveal the selected effect',
          logName: 'VideoEditorEffectsBottomBar',
          category: LogCategory.video,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _EffectItem extends StatelessWidget {
  const _EffectItem({
    required this.type,
    required this.isSelected,
    required this.thumbnailPath,
  });

  /// A playhead that never moves, so each tile shows a still.
  static final ValueListenable<Duration> _still = ValueNotifier(Duration.zero);

  final EditorEffectType type;
  final bool isSelected;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final label = videoEffectLabel(context, type);
    final path = thumbnailPath;
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => context.read<VideoEditorEffectsCubit>().selectType(type),
        child: Column(
          mainAxisAlignment: .end,
          spacing: 4,
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
              child: ClipRRect(
                borderRadius: .circular(18),
                child: path == null || path.isEmpty
                    ? const SizedBox.expand()
                    : type == EditorEffectType.echo
                    ? _EchoThumbnail(path: path)
                    : switch (shaderTileOf(type)) {
                        final tile? => _ShaderThumbnail(
                          path: path,
                          tile: tile,
                        ),
                        null => VideoEffectPreview(
                          effects: [
                            if (type.builtIn case final builtIn?)
                              VideoEffect(type: builtIn),
                          ],
                          position: _still,
                          child: _Thumbnail(path: path),
                        ),
                      },
              ),
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: double.infinity,
      height: double.infinity,
      fit: .cover,
      excludeFromSemantics: true,
    );
  }
}

/// The echo tile: a still has no motion to trail, so the thumbnail is shown
/// with fading copies of itself shifted to the left instead.
class _EchoThumbnail extends StatelessWidget {
  const _EchoThumbnail({required this.path});

  final String path;

  /// Shift, as a share of the preview's width, and opacity of each copy,
  /// oldest first.
  static const List<(double, double)> _copies = [
    (-12 / 52, 0.22),
    (-8 / 52, 0.35),
    (-4 / 52, 0.5),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        _Thumbnail(path: path),
        for (final (dx, opacity) in _copies)
          FractionalTranslation(
            translation: Offset(dx, 0),
            child: Opacity(
              opacity: opacity,
              child: _Thumbnail(path: path),
            ),
          ),
      ],
    );
  }
}

/// How the tile of an effect Divine draws itself shows it: the thumbnail
/// through [asset], the same shader the native effect runs, with [values] for
/// the uniforms after the texture size.
typedef ShaderTile = ({String asset, List<double> values});

/// Seconds into the particles at which their tiles show them.
const _particlesTileSeconds = 3.0;

/// The tile of [type], or `null` for an effect whose tile is drawn otherwise.
///
/// Each shows the effect at full strength. The fisheye's value is the
/// `CIBumpDistortion` scale `FisheyeVideoEffect` uses at intensity 1; the
/// drops show the default settings at a moment where two of them flow into
/// each other; the particles' last value is the style the native
/// `ParticlesVideoEffect` draws.
@visibleForTesting
ShaderTile? shaderTileOf(EditorEffectType? type) => switch (type?.customId) {
  fisheyeVideoEffectId => (asset: 'shaders/fisheye.frag', values: const [0.8]),
  dropsVideoEffectId => (asset: 'shaders/drops.frag', values: _dropsTileValues),
  lightLeakVideoEffectId => (
    asset: 'shaders/light_leak.frag',
    values: const [1.0, 0.0],
  ),
  snowVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 0.0],
  ),
  confettiVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 1.0],
  ),
  heartsVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 2.0],
  ),
  sparklesVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 3.0],
  ),
  tiltShiftVideoEffectId => (
    asset: 'shaders/tilt_shift.frag',
    values: const [1.0],
  ),
  zoomBlurVideoEffectId => (
    asset: 'shaders/zoom_blur.frag',
    values: const [1.0],
  ),
  comicVideoEffectId => (asset: 'shaders/comic.frag', values: const [1.0]),
  _ => null,
};

/// The drops' tile values: the intensity, the scale, the frost, the fringes
/// and each drop, seven seconds in.
final List<double> _dropsTileValues = () {
  const settings = DropsEffectSettings();
  return List<double>.unmodifiable([
    1.0,
    dropsScale(settings),
    settings.frost,
    settings.fringes,
    for (final drop in dropsLayout(settings, seconds: 7)) ...[
      drop.x,
      drop.y,
      drop.radius,
    ],
  ]);
}();

/// The tile of an effect Divine draws itself: the thumbnail through the
/// [tile]'s shader.
///
/// Shows the plain thumbnail where the backend has no shader image filter
/// (Skia), as the chroma-key preview does.
class _ShaderThumbnail extends StatefulWidget {
  const _ShaderThumbnail({required this.path, required this.tile});

  final String path;
  final ShaderTile tile;

  @override
  State<_ShaderThumbnail> createState() => _ShaderThumbnailState();
}

class _ShaderThumbnailState extends State<_ShaderThumbnail> {
  /// Each shader is read once, whichever tiles show it.
  static final _programs = <String, Future<ui.FragmentProgram>>{};

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ShaderThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.asset != widget.tile.asset) {
      _shader?.dispose();
      _shader = null;
      _load();
    } else if (!listEquals(oldWidget.tile.values, widget.tile.values)) {
      final shader = _shader;
      if (shader != null) _configure(shader);
    }
  }

  void _load() {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    final asset = widget.tile.asset;
    runDetached(
      (_programs[asset] ??= ui.FragmentProgram.fromAsset(asset)).then((
        program,
      ) {
        if (!mounted || widget.tile.asset != asset) return;
        setState(() => _shader = _configure(program.fragmentShader()));
      }),
      'load the effect tile shader',
      logName: 'VideoEditorEffectsBottomBar',
      category: LogCategory.video,
    );
  }

  /// Uniforms 0 and 1 are the bound texture's size, which the engine sets.
  ui.FragmentShader _configure(ui.FragmentShader shader) {
    var index = 2;
    for (final value in widget.tile.values) {
      shader.setFloat(index++, value);
    }
    return shader;
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final thumbnail = _Thumbnail(path: widget.path);
    if (shader == null) return thumbnail;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.shader(shader),
      child: thumbnail,
    );
  }
}

/// The localized name of [type], or of "no effect" for `null`.
String videoEffectLabel(BuildContext context, EditorEffectType? type) {
  if (type == null) return context.l10n.videoEditorEffectNone;
  if (type.builtIn case final builtIn?) {
    return builtInVideoEffectLabel(context, builtIn);
  }
  // The others Divine renders itself.
  return switch (type.customId) {
    fisheyeVideoEffectId => context.l10n.videoEditorEffectFisheye,
    dropsVideoEffectId => context.l10n.videoEditorEffectDrops,
    lightLeakVideoEffectId => context.l10n.videoEditorEffectLightLeak,
    snowVideoEffectId => context.l10n.videoEditorEffectSnow,
    confettiVideoEffectId => context.l10n.videoEditorEffectConfetti,
    heartsVideoEffectId => context.l10n.videoEditorEffectHearts,
    sparklesVideoEffectId => context.l10n.videoEditorEffectSparkles,
    tiltShiftVideoEffectId => context.l10n.videoEditorEffectTiltShift,
    zoomBlurVideoEffectId => context.l10n.videoEditorEffectZoomBlur,
    comicVideoEffectId => context.l10n.videoEditorEffectComic,
    _ => context.l10n.videoEditorEffectEcho,
  };
}

/// The localized name of [category].
String _categoryLabel(
  BuildContext context,
  EditorEffectCategory category,
) => switch (category) {
  EditorEffectCategory.retro => context.l10n.videoEditorEffectCategoryRetro,
  EditorEffectCategory.glitch => context.l10n.videoEditorEffectCategoryGlitch,
  EditorEffectCategory.distort => context.l10n.videoEditorEffectCategoryDistort,
  EditorEffectCategory.light => context.l10n.videoEditorEffectCategoryLight,
  EditorEffectCategory.motion => context.l10n.videoEditorEffectCategoryMotion,
  EditorEffectCategory.particles =>
    context.l10n.videoEditorEffectCategoryParticles,
};

/// The localized name of the built-in effect [type].
String builtInVideoEffectLabel(
  BuildContext context,
  VideoEffectType type,
) => switch (type) {
  VideoEffectType.glitch => context.l10n.videoEditorEffectGlitch,
  VideoEffectType.rgbSplit => context.l10n.videoEditorEffectRgbSplit,
  VideoEffectType.vhs => context.l10n.videoEditorEffectVhs,
  VideoEffectType.tvStatic => context.l10n.videoEditorEffectTvStatic,
  VideoEffectType.oldFilm => context.l10n.videoEditorEffectOldFilm,
  VideoEffectType.pixelate => context.l10n.videoEditorEffectPixelate,
  VideoEffectType.pixelPulse => context.l10n.videoEditorEffectPixelPulse,
  VideoEffectType.strobe => context.l10n.videoEditorEffectStrobe,
  VideoEffectType.negativeFlash => context.l10n.videoEditorEffectNegativeFlash,
  VideoEffectType.vignette => context.l10n.videoEditorEffectVignette,
  VideoEffectType.blockGlitch => context.l10n.videoEditorEffectBlockGlitch,
  VideoEffectType.filmGrain => context.l10n.videoEditorEffectFilmGrain,
  VideoEffectType.signalInterference =>
    context.l10n.videoEditorEffectSignalInterference,
  VideoEffectType.crt => context.l10n.videoEditorEffectCrt,
  VideoEffectType.shake => context.l10n.videoEditorEffectShake,
  VideoEffectType.zoomPulse => context.l10n.videoEditorEffectZoomPulse,
  VideoEffectType.mirror => context.l10n.videoEditorEffectMirror,
  VideoEffectType.kaleidoscope => context.l10n.videoEditorEffectKaleidoscope,
  VideoEffectType.splitScreen => context.l10n.videoEditorEffectSplitScreen,
  VideoEffectType.wave => context.l10n.videoEditorEffectWave,
  VideoEffectType.glow => context.l10n.videoEditorEffectGlow,
};
