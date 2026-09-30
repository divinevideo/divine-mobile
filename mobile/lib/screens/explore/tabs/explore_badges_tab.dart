// ABOUTME: Explore's curated badge definitions, linked to their holder pages.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/badges/explore_badges_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/badges/awarded_badge_card.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:unified_logger/unified_logger.dart';

/// Discover badge definitions from curated issuers.
class ExploreBadgesTab extends ConsumerWidget {
  /// Creates the Explore Badges tab.
  const ExploreBadgesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(badgeRepositoryProvider);
    return BlocProvider(
      key: ValueKey(repository),
      create: (_) {
        final cubit = ExploreBadgesCubit(repository: repository);
        runDetached(
          cubit.load(),
          'load explore badges',
          logName: 'ExploreBadgesTab',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: const ExploreBadgesView(),
    );
  }
}

/// The curated badge list, driven by [ExploreBadgesCubit].
class ExploreBadgesView extends StatelessWidget {
  /// Creates the view.
  @visibleForTesting
  const ExploreBadgesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExploreBadgesCubit>().state;
    final cubit = context.read<ExploreBadgesCubit>();
    return switch (state.status) {
      ExploreBadgesStatus.initial || ExploreBadgesStatus.loading =>
        const Center(child: BrandedLoadingIndicator(size: 60)),
      ExploreBadgesStatus.failure => Center(
        child: DivineButton(
          onPressed: cubit.load,
          label: context.l10n.badgesLoadError,
        ),
      ),
      ExploreBadgesStatus.loaded => RefreshIndicator(
        color: VineTheme.onPrimary,
        backgroundColor: VineTheme.vineGreen,
        onRefresh: cubit.refresh,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.definitions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _ExploreBadgeRow(definition: state.definitions[index]),
        ),
      ),
    };
  }
}

class _ExploreBadgeRow extends StatelessWidget {
  const _ExploreBadgeRow({required this.definition});

  final Nip58BadgeDefinition definition;

  @override
  Widget build(BuildContext context) {
    final coordinate = BadgeCoordinate.parse(definition.coordinate)!;
    return BadgePanel(
      onTap: () => context.push<void>(BadgeDetailScreen.pathFor(coordinate)),
      child: Row(
        spacing: 12,
        children: [
          BadgeMedallion(imageUrl: definition.imageUrl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.name ?? definition.dTag,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
                if (definition.description case final description?)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
