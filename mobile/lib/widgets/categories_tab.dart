// ABOUTME: Categories discovery tab for the Explore screen.
// ABOUTME: Renders the redesigned pinned-first category list and navigates to category detail.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_category_name.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/widgets/categories/category_glyph.dart';
import 'package:openvine/widgets/categories/category_visuals.dart';

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
              context.push(
                CategoryGalleryScreen.locationFor(category.name),
                extra: category,
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: categories.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryTile(
          category: category,
          visuals: CategoryVisuals.forCategory(category, index),
          onTap: () => onCategoryTap(category),
          index: index,
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
    return Semantics(
      button: true,
      label: localizedName,
      identifier: SemanticIds.categoryTile(index),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            height: 96,
            decoration: BoxDecoration(
              color: visuals.backgroundColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
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
                          style: VineTheme.headlineSmallFont(
                            color: visuals.foregroundColor,
                          ),
                        ),
                        Text(
                          context.l10n.categoryVideoCount(
                            category.videoCount,
                            _formatCount(category.videoCount),
                          ),
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
