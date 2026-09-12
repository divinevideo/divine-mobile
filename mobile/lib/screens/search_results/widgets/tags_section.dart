import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/search_tag_chip.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Maximum number of hashtag chips shown in the Tags preview.
const _maxTagsPreview = 6;

/// Always-visible Tags section with a "Tags" header.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class TagsSection extends StatelessWidget {
  const TagsSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results instead of a limited preview.
  final bool showAll;

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (HashtagSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (HashtagSearchBloc bloc) => bloc.state.results,
    );

    // In the All tab, hide entire section when results are empty and loaded.
    if (!showAll && status == .success && results.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(
              title: context.l10n.searchTagsSectionHeader,
              onTap: onSeeAll,
              semanticIdentifier: SemanticIds.searchSectionHeader('tags'),
            ),
          ),
        _TagsContent(showAll: showAll),
        if (showAll) const _TagsPaginationTrigger(),
      ],
    );
  }
}

class _TagsPaginationTrigger extends StatelessWidget {
  const _TagsPaginationTrigger();

  @override
  Widget build(BuildContext context) {
    final hasMore = context.select((HashtagSearchBloc b) => b.state.hasMore);
    final isLoadingMore = context.select(
      (HashtagSearchBloc b) => b.state.isLoadingMore,
    );
    return SliverPaginationTrigger(
      onLoadMore: () =>
          context.read<HashtagSearchBloc>().add(const HashtagSearchLoadMore()),
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
    );
  }
}

class _TagsContent extends StatelessWidget {
  const _TagsContent({this.showAll = false});

  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (HashtagSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (HashtagSearchBloc bloc) => bloc.state.results,
    );
    final query = context.select((HashtagSearchBloc bloc) => bloc.state.query);

    if ((status == .initial || status == .loading) && results.isEmpty) {
      return const _TagsSkeletonLoader();
    }

    if (status == .failure) {
      return SearchSectionErrorState(
        onRetry: () => context.read<HashtagSearchBloc>().add(
          HashtagSearchQueryChanged(query),
        ),
      );
    }

    if (results.isEmpty) {
      if (showAll) return SearchSectionEmptyState(query: query);
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final tags = showAll ? results : results.take(_maxTagsPreview).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              SearchTagChip(
                tag: tag,
                onTap: () => context.push(HashtagScreenRouter.pathForTag(tag)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder widths for tag chip skeletons, varying to look organic.
const _tagSkeletonWidths = [80.0, 64.0, 96.0, 72.0, 88.0, 60.0];

class _TagsSkeletonLoader extends StatelessWidget {
  const _TagsSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Semantics(
        identifier: 'tags_loading_indicator',
        label: context.l10n.searchTagsLoadingLabel,
        child: Skeletonizer(
          effect: vineSkeletonEffectOf(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _maxTagsPreview; i++)
                  _TagChipSkeletonItem(width: _tagSkeletonWidths[i]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChipSkeletonItem extends StatelessWidget {
  const _TagChipSkeletonItem({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Skeleton.leaf(
      child: Container(
        width: width,
        height: 36,
        decoration: BoxDecoration(
          color: context.vineColors.skeleton,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
