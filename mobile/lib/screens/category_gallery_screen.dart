// ABOUTME: Dedicated category gallery screen with visible sort controls.
// ABOUTME: Preserves category context and opens the pooled fullscreen feed.

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_category_name.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/categories/category_glyph.dart';
import 'package:openvine/widgets/categories/category_visuals.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:rxdart/rxdart.dart';

class CategoryGalleryScreen extends ConsumerStatefulWidget {
  const CategoryGalleryScreen({required this.category, super.key});

  static const routeName = 'category-gallery';
  static const path = '/categories/:categoryName';

  final VideoCategory category;

  @override
  ConsumerState<CategoryGalleryScreen> createState() =>
      _CategoryGalleryScreenState();
}

class _CategoryGalleryScreenState extends ConsumerState<CategoryGalleryScreen> {
  late final CategoriesBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = CategoriesBloc(
      categoriesRepository: ref.read(categoriesRepositoryProvider),
      contentBlocklistRepository: ref.read(contentBlocklistRepositoryProvider),
      currentUserPubkey: ref.read(authServiceProvider).currentPublicKeyHex,
    )..add(CategorySelected(widget.category));
  }

  @override
  void dispose() {
    runDetached(
      _bloc.close(),
      'close category gallery BLoC',
      logName: 'CategoryGalleryScreen',
      category: LogCategory.ui,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(blocklistVersionProvider, (previous, current) {
      if (previous != null && current > previous) {
        _bloc.add(const CategoriesBlocklistChanged());
      }
    });

    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<CategoriesBloc, CategoriesState>(
        builder: (context, state) {
          return CategoryGalleryView(
            category: widget.category,
            state: state,
            onBack: context.pop,
            onRetry: () {
              context.read<CategoriesBloc>().add(
                CategorySelected(widget.category),
              );
            },
            onSortChanged: (sort) {
              context.read<CategoriesBloc>().add(
                CategoryVideosSortChanged(sort),
              );
            },
            onRefresh: () async {
              context.read<CategoriesBloc>().add(
                CategorySelected(widget.category),
              );
            },
            onLoadMore: () async {
              context.read<CategoriesBloc>().add(
                const CategoryVideosLoadMore(),
              );
            },
            onVideoTap: (videos, index) {
              // The live first page can remove a cached tile. Do not open a
              // fullscreen session that its pending refresh could swap out.
              if (_bloc.state.isRefreshingVideos) return;
              runDetached(
                PooledFullscreenVideoFeedRouteData(
                  video: videos[index].id,
                  $extra: PooledFullscreenVideoFeedArgs(
                    source: CategoryViewSource(widget.category.name),
                    feedRepository: StreamFeedRepository(
                      videos: _bloc.stream
                          .map((state) => state.videos)
                          .startWith(videos),
                      hasMore: _bloc.stream
                          .map((state) => state.hasMoreVideos)
                          .startWith(state.hasMoreVideos),
                      onLoadMore: () async =>
                          _bloc.add(const CategoryVideosLoadMore()),
                    ),
                    initialIndex: index,
                    initialVideoId: videos[index].id,
                    contextTitle: localizedCategoryName(
                      context.l10n,
                      widget.category.name,
                    ),
                  ),
                ).push<void>(context),
                'open category video',
                logName: 'CategoryGalleryScreen',
                category: LogCategory.ui,
              );
            },
          );
        },
      ),
    );
  }
}

class CategoryGalleryView extends StatelessWidget {
  const CategoryGalleryView({
    required this.category,
    required this.state,
    required this.onBack,
    required this.onRetry,
    required this.onSortChanged,
    required this.onVideoTap,
    required this.onLoadMore,
    required this.onRefresh,
    this.galleryOverride,
    super.key,
  });

  final VideoCategory category;
  final CategoriesState state;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<String> onSortChanged;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget? galleryOverride;

  @override
  Widget build(BuildContext context) {
    final visuals = CategoryVisuals.forCategory(category, 0);

    // This screen is a root-navigator route, so nothing above it provides a
    // `Material`. Without one every `Text` inherits Flutter's yellow
    // double-underline fallback style from `MaterialApp`. It is nav-coloured
    // so the gallery's cut top corners blend into the header.
    return Material(
      color: context.vineColors.nav,
      child: Column(
        children: [
          _CategoryGalleryHeader(
            category: category,
            visuals: visuals,
            selectedSort: state.sortOrder,
            onBack: onBack,
            onSortChanged: onSortChanged,
          ),
          Expanded(
            // Outside the scroll view, so the corners stay put while the
            // videos scroll under them.
            child: ClipRRect(
              key: const Key('category-gallery-body-clip'),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_galleryTopRadius),
              ),
              child: Material(
                color: context.vineColors.surfaceContainerHigh,
                child: _CategoryGalleryBody(
                  state: state,
                  onRetry: onRetry,
                  onVideoTap: onVideoTap,
                  onLoadMore: onLoadMore,
                  onRefresh: onRefresh,
                  galleryOverride: galleryOverride,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGalleryBody extends StatelessWidget {
  const _CategoryGalleryBody({
    required this.state,
    required this.onRetry,
    required this.onVideoTap,
    required this.onLoadMore,
    required this.onRefresh,
    this.galleryOverride,
  });

  final CategoriesState state;
  final VoidCallback onRetry;
  final void Function(List<VideoEvent>, int) onVideoTap;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget? galleryOverride;

  @override
  Widget build(BuildContext context) {
    switch (state.videosStatus) {
      case CategoriesVideosStatus.initial:
      case CategoriesVideosStatus.loading:
        return const Center(child: DivineCircularProgressIndicator());
      case CategoriesVideosStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(
                context.l10n.categoryGalleryCouldNotLoadVideos,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              DivineButton(
                label: context.l10n.commonRetry,
                onPressed: onRetry,
              ),
            ],
          ),
        );
      case CategoriesVideosStatus.loaded:
        if (state.videos.isEmpty && galleryOverride == null) {
          return Center(
            child: Text(
              context.l10n.categoryGalleryNoVideosInCategory,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          );
        }

        return galleryOverride ??
            ComposableVideoGrid(
              videos: state.videos,
              onVideoTap: (videos, index, _) => onVideoTap(videos, index),
              useMasonryLayout: true,
              // Edge to edge: the gallery's rounded corners frame the grid.
              padding: const EdgeInsets.only(bottom: 12),
              onLoadMore: onLoadMore,
              onRefresh: onRefresh,
              isLoadingMore: state.isLoadingMore,
              hasMoreContent: state.hasMoreVideos,
            );
    }
  }
}

class _CategoryGalleryHeader extends StatelessWidget {
  const _CategoryGalleryHeader({
    required this.category,
    required this.visuals,
    required this.selectedSort,
    required this.onBack,
    required this.onSortChanged,
  });

  final VideoCategory category;
  final CategoryVisuals visuals;
  final String selectedSort;
  final VoidCallback onBack;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    // The mascot ends where the trailing button's visible edge begins, and
    // that button grows with the text scale through its icon.
    final mascotEndInset =
        _headerBarPadding +
        _headerActionMargin +
        _headerActionPadding * 2 +
        DivineIcon.scaleSize(context, _headerActionIconSize);

    return ColoredBox(
      color: context.vineColors.nav,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.only(top: 24),
        // A minimum, not a fixed height: at large text the actions and title
        // need more than the design's 72 px.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _headerBarHeight),
          // The mascot is painted first so the actions stay on top where the
          // two overlap, and it may rise above the bar into the status area.
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            clipBehavior: Clip.none,
            children: [
              PositionedDirectional(
                end: mascotEndInset,
                bottom: 0,
                child: _CategoryHeaderMascotSlot(
                  visuals: visuals,
                  emoji: category.emoji,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(_headerBarPadding),
                child: Row(
                  spacing: _headerBarGap,
                  children: [
                    _CategoryHeaderActionButton(
                      decorationKey: const Key('category-header-back-button'),
                      icon: DivineIconName.caretLeft,
                      semanticLabel: context.l10n.commonBack,
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: _titleStartPadding,
                          end: _titleEndPadding,
                        ),
                        child: Text(
                          localizedCategoryName(context.l10n, category.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VineTheme.titleMediumFont(
                            color: context.vineColors.onNav,
                          ),
                        ),
                      ),
                    ),
                    _CategoryHeaderActionButton(
                      decorationKey: const Key('category-header-filter-button'),
                      icon: DivineIconName.funnelSimple,
                      semanticLabel:
                          context.l10n.categoryGallerySortOptionsLabel,
                      onPressed: () async {
                        final selected = await _showCategorySortSheet(
                          context: context,
                          selectedValue: selectedSort,
                        );
                        if (selected != null && selected != selectedSort) {
                          onSortChanged(selected);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<VineBottomSheetSelectionOptionData> _categorySortOptions(
  AppLocalizations l10n,
) => [
  VineBottomSheetSelectionOptionData(
    label: l10n.categoryGallerySortHot,
    value: 'trending',
  ),
  VineBottomSheetSelectionOptionData(
    label: l10n.categoryGallerySortNew,
    value: 'timestamp',
  ),
  VineBottomSheetSelectionOptionData(
    label: l10n.categoryGallerySortClassic,
    value: 'classic',
  ),
  VineBottomSheetSelectionOptionData(
    label: l10n.categoryGallerySortForYou,
    value: 'forYou',
  ),
];

const _categoryHeaderActionFill = Color(0xFF3E0C1F);
const _categoryHeaderActionBorder = Color(0x40FFFFFF);
const _categoryActionShadows = <BoxShadow>[
  BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0.4, 0.4),
    blurRadius: 0.6,
  ),
  BoxShadow(color: Color(0x1A000000), offset: Offset(1, 1), blurRadius: 1),
];

// Header metrics from the Figma category page's top app bar, below the
// status area.
const _headerBarHeight = 72.0;
const _headerBarPadding = 12.0;
const _headerBarGap = 8.0;
const _titleStartPadding = 4.0;

// Each action is a 24 px icon (DivineIcon's default size) padded to a 40 px
// button inside a 4 px margin, Figma's 48 px slot. The icon, and so the
// button, grows with the text scale.
const _headerActionMargin = 4.0;
const _headerActionPadding = 8.0;
const _headerActionIconSize = 24.0;

// The mascot's slot rests on the bar's bottom edge and rises above it into
// the status area.
const _mascotSlotWidth = 149.0;
const _mascotSlotHeight = 90.0;

/// The mascot's box inside the slot, narrow enough that its 8° tilt stays
/// within the slot's width.
const _mascotWidth = 132.0;

/// Stops the title where the mascot starts. The mascot ends where the
/// trailing button begins, so the button's width cancels out.
const double _titleEndPadding =
    _mascotSlotWidth - _headerActionMargin - _headerBarGap;

/// The gallery's top corner radius: Figma's `radius 96` corner pieces are
/// 96 px across, so 48 per side.
const _galleryTopRadius = 48.0;

Future<String?> _showCategorySortSheet({
  required BuildContext context,
  required String selectedValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: VineTheme.transparent,
    barrierColor: VineTheme.scrim65,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _CategorySortSheet(selectedValue: selectedValue);
    },
  );
}

class _CategoryHeaderActionButton extends StatelessWidget {
  const _CategoryHeaderActionButton({
    required this.decorationKey,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  final Key decorationKey;
  final DivineIconName icon;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Pads the button out to Figma's 48 px slot; only the button is tappable.
    return Padding(
      padding: const EdgeInsets.all(_headerActionMargin),
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: Material(
          color: VineTheme.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              key: decorationKey,
              decoration: BoxDecoration(
                color: _categoryHeaderActionFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _categoryHeaderActionBorder,
                  width: 2,
                ),
                boxShadow: _categoryActionShadows,
              ),
              child: Padding(
                padding: const EdgeInsets.all(_headerActionPadding),
                child: DivineIcon(icon: icon, color: VineTheme.whiteText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeaderMascotSlot extends StatelessWidget {
  const _CategoryHeaderMascotSlot({required this.visuals, required this.emoji});

  final CategoryVisuals visuals;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final sticker = visuals.sticker;
    return SizedBox(
      key: const Key('category-header-mascot-slot'),
      width: _mascotSlotWidth,
      height: _mascotSlotHeight,
      // Clipped to the slot, as in Figma: the 8° tilt pushes the mascot's
      // corners a few px past it, and those corners are empty artwork.
      child: ClipRect(
        child: Center(
          child: Transform.rotate(
            angle: 8 * math.pi / 180,
            child: sticker != null
                ? _CategoryHeaderSticker(sticker: sticker.name)
                : CategoryGlyph(
                    assetPath: visuals.assetPath,
                    emoji: emoji,
                    height: _mascotSlotHeight,
                    width: _mascotWidth,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The category's sticker in the glyph's box, as tall as the glyph it
/// replaces. Decorative: the header already names the category.
class _CategoryHeaderSticker extends StatelessWidget {
  const _CategoryHeaderSticker({required this.sticker});

  final DivineStickerName sticker;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: _mascotWidth,
        height: _mascotSlotHeight,
        child: Center(
          child: DivineSticker(sticker: sticker, size: _mascotSlotHeight),
        ),
      ),
    );
  }
}

class _CategorySortSheet extends StatelessWidget {
  const _CategorySortSheet({required this.selectedValue});

  final String selectedValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('category-sort-sheet'),
      decoration: BoxDecoration(
        color: context.vineColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VineTheme.bottomSheetBorderRadius),
        ),
      ),
      // Inside the surface, so it paints behind the home indicator while the
      // options stay above it.
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 32,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.vineColors.outlineDisabled),
                ),
              ),
              child: Center(
                child: Container(
                  key: const Key('category-sort-sheet-handle'),
                  width: 64,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in _categorySortOptions(context.l10n))
                    _CategorySortSheetOption(
                      option: option,
                      isSelected: option.value == selectedValue,
                      onTap: () => Navigator.of(context).pop(option.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySortSheetOption extends StatelessWidget {
  const _CategorySortSheetOption({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final VineBottomSheetSelectionOptionData option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VineTheme.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          key: Key('category-sort-option-${option.value}'),
          decoration: BoxDecoration(
            color: isSelected
                ? context.vineColors.iconButton
                : context.vineColors.surface,
            border: Border(
              bottom: BorderSide(color: context.vineColors.outlineDisabled),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ),
                if (isSelected)
                  const DivineIcon(
                    icon: DivineIconName.check,
                    color: VineTheme.vineGreen,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
