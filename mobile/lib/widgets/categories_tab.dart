// ABOUTME: Categories discovery tab for the Explore screen.
// ABOUTME: Renders the redesigned pinned-first category list and navigates to category detail.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_category_name.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/search_routes.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/categories/category_glyph.dart';
import 'package:openvine/widgets/categories/category_visuals.dart';
import 'package:unified_logger/unified_logger.dart';

/// Category tile metrics from the Figma category list.
const _tileHeight = 96.0;
const _tileGap = 8.0;
const _listPadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
const _tileRadius = 24.0;
const _tileStartPadding = 24.0;
const _tileVerticalPadding = 16.0;

/// The square slot a sticker is centred on, and its inset from the tile's end.
const _stickerSlotSize = 64.0;
const _stickerSlotEndInset = 32.0;

/// Text stops short of the sticker slot by the same gap the slot keeps from
/// the tile's edge.
const double _textEndPadding = _stickerSlotEndInset * 2 + _stickerSlotSize;

class CategoriesTab extends ConsumerWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesRepository = ref.watch(categoriesRepositoryProvider);

    return BlocProvider(
      create: (_) =>
          CategoriesBloc(categoriesRepository: categoriesRepository)
            ..add(const CategoriesLoadRequested()),
      child: BlocBuilder<CategoriesBloc, CategoriesState>(
        builder: (context, state) {
          return CategoriesDiscoveryView(
            state: state,
            onRetry: () {
              context.read<CategoriesBloc>().add(
                const CategoriesLoadRequested(),
              );
            },
            onCategoryTap: (category) {
              runDetached(
                CategoryGalleryRouteData(
                  categoryName: category.name,
                  $extra: category,
                ).push<void>(context),
                'open category gallery',
                logName: 'CategoriesTab',
                category: LogCategory.ui,
              );
            },
          );
        },
      ),
    );
  }
}

class CategoriesDiscoveryView extends StatelessWidget {
  const CategoriesDiscoveryView({
    required this.state,
    required this.onCategoryTap,
    required this.onRetry,
    super.key,
  });

  final CategoriesState state;
  final ValueChanged<VideoCategory> onCategoryTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final body = switch (state.categoriesStatus) {
      CategoriesStatus.loading => const Center(
        child: DivineCircularProgressIndicator(),
      ),
      CategoriesStatus.error => Center(
        child: Column(
          spacing: 16,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.categoriesCouldNotLoadCategories,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
      CategoriesStatus.loaded => _CategoriesListBody(
        categories: state.categories,
        onCategoryTap: onCategoryTap,
      ),
      CategoriesStatus.initial => const SizedBox.shrink(),
    };

    return LoadingOverlay(
      isLoading: state.isRefreshing,
      padding: const .only(top: 4),
      child: body,
    );
  }
}

class _CategoriesListBody extends StatelessWidget {
  const _CategoriesListBody({
    required this.categories,
    required this.onCategoryTap,
  });

  final List<VideoCategory> categories;
  final ValueChanged<VideoCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          context.l10n.categoriesNoCategoriesAvailable,
          style: VineTheme.bodyLargeFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      );
    }

    Widget buildTile(BuildContext context, int index) {
      final category = categories[index];
      return _CategoryTile(
        category: category,
        visuals: CategoryVisuals.forCategory(category, index),
        onTap: () => onCategoryTap(category),
        index: index,
      );
    }

    final layout = context.adaptiveLayout;
    return LayoutBuilder(
      builder: (context, constraints) {
        // One full-width tile per row on a phone; with the large-screen
        // layouts a wider window lays the tiles out side by side, so they
        // keep about a phone tile's width.
        final columns = layout.gridColumns(
          compact: 1,
          width: constraints.maxWidth - _listPadding.horizontal,
        );
        if (columns == 1) {
          return ListView.separated(
            padding: _listPadding,
            itemCount: categories.length,
            separatorBuilder: (_, index) => const SizedBox(height: _tileGap),
            itemBuilder: buildTile,
          );
        }
        return GridView.builder(
          padding: _listPadding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: _tileHeight,
            mainAxisSpacing: _tileGap,
            crossAxisSpacing: _tileGap,
          ),
          itemCount: categories.length,
          itemBuilder: buildTile,
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.visuals,
    required this.onTap,
    required this.index,
  });

  final int index;
  final VideoCategory category;
  final CategoryVisuals visuals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizedName = localizedCategoryName(context.l10n, category.name);
    final sticker = visuals.sticker;
    final borderRadius = BorderRadius.circular(_tileRadius);

    return Semantics(
      button: true,
      label: localizedName,
      identifier: SemanticIds.categoryTile(index),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Ink(
            height: _tileHeight,
            decoration: BoxDecoration(
              color: visuals.backgroundColor,
              borderRadius: borderRadius,
            ),
            // Stickers are larger than the tile and bleed past it, so the
            // tile's rounded edge is what cuts them.
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _tileStartPadding,
                      end: _textEndPadding,
                      top: _tileVerticalPadding,
                      bottom: _tileVerticalPadding,
                    ),
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: fixedRowTextScaleLimit,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            localizedName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VineTheme.headlineSmallFont(
                              color: visuals.foregroundColor,
                            ),
                          ),
                          Text(
                            context.l10n.categoryVideoCount(
                              category.videoCount,
                              _formatCount(category.videoCount),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VineTheme.labelMediumFont(
                              color: visuals.foregroundColor.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (sticker != null)
                    _CategoryStickerSlot(sticker: sticker)
                  else
                    PositionedDirectional(
                      end: 18,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: CategoryGlyph(
                          assetPath: visuals.assetPath,
                          emoji: category.emoji,
                          height: 88,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Places a category's sticker where design put it: centred on the slot at the
/// tile's end, then moved, turned and allowed to overflow.
class _CategoryStickerSlot extends StatelessWidget {
  const _CategoryStickerSlot({required this.sticker});

  final CategorySticker sticker;

  @override
  Widget build(BuildContext context) {
    // The slot follows the reading direction, so the sideways nudge that
    // pushes a sticker toward the tile's edge has to follow it too.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final offset = isRtl
        ? Offset(-sticker.offset.dx, sticker.offset.dy)
        : sticker.offset;

    return PositionedDirectional(
      end: _stickerSlotEndInset,
      top: (_tileHeight - _stickerSlotSize) / 2,
      width: _stickerSlotSize,
      height: _stickerSlotSize,
      // Decorative: the tile already carries the category's label and tap.
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: OverflowBox(
            maxWidth: sticker.size,
            maxHeight: sticker.size,
            child: Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: sticker.rotationDegrees * math.pi / 180,
                child: DivineSticker(sticker: sticker.name, size: sticker.size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatCount(int count) {
  if (count >= 1000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
  }
  return count.toString();
}
