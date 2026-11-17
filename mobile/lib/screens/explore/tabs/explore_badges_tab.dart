// ABOUTME: Public badge communities in an artwork-led discovery gallery.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/badges/explore_badges_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/routes/auth_routes.dart';
import 'package:openvine/router/routes/settings_routes.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/widgets/badges/badge_community_card.dart';
import 'package:unified_logger/unified_logger.dart';

/// Discover community-issued badges without requiring an account.
class ExploreBadgesTab extends ConsumerWidget {
  const ExploreBadgesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(badgeRepositoryProvider);
    final policyVersion = ref.watch(blocklistVersionProvider);
    ref.watch(currentAuthStateProvider);
    final viewer = ref.watch(authServiceProvider).currentPublicKeyHex;
    return BlocProvider(
      key: ValueKey((repository, policyVersion, viewer)),
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

/// Responsive gallery driven by [ExploreBadgesCubit].
class ExploreBadgesView extends StatelessWidget {
  @visibleForTesting
  const ExploreBadgesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExploreBadgesCubit>().state;
    final cubit = context.read<ExploreBadgesCubit>();
    return BlocListener<ExploreBadgesCubit, ExploreBadgesState>(
      listenWhen: (previous, current) =>
          current.refreshFailures > previous.refreshFailures,
      listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.badgesLoadError,
          error: true,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20
              ? 1
              : 2;
          final loading =
              state.status == ExploreBadgesStatus.initial ||
              state.status == ExploreBadgesStatus.loading;
          final definitions = state.visibleDefinitions;
          final rowCount = loading ? 3 : (definitions.length / columns).ceil();
          return RefreshIndicator(
            color: VineTheme.onPrimary,
            backgroundColor: VineTheme.vineGreen,
            onRefresh: cubit.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _BadgeDiscoveryHeader()),
                if (state.status == ExploreBadgesStatus.failure)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        spacing: 16,
                        children: [
                          Text(
                            context.l10n.badgesLoadError,
                            style: VineTheme.bodyMediumFont(
                              color: context.vineColors.onSurface,
                            ),
                          ),
                          DivineButton(
                            onPressed: cubit.load,
                            label: context.l10n.commonRetry,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!loading && definitions.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.l10n.badgeDiscoveryEmpty,
                        textAlign: TextAlign.center,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: rowCount,
                      separatorBuilder: (_, _) => const SizedBox(height: 20),
                      itemBuilder: (context, row) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 16,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Expanded(
                              child: loading
                                  ? const _BadgeCardSkeleton()
                                  : row * columns + column < definitions.length
                                  ? Builder(
                                      builder: (context) {
                                        final definition =
                                            definitions[row * columns + column];
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (context.mounted) {
                                                cubit.loadPreview(
                                                  definition.coordinate,
                                                );
                                              }
                                            });
                                        return BadgeCommunityCard(
                                          key: ValueKey(definition.coordinate),
                                          definition: definition,
                                          memberPubkeys:
                                              state.previews[definition
                                                  .coordinate] ??
                                              const [],
                                          onTap: () => context.push<void>(
                                            BadgeDetailScreen.pathFor(
                                              BadgeCoordinate.parse(
                                                definition.coordinate,
                                              )!,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: state.hasMore
                        ? DivineButton(
                            onPressed: cubit.showMore,
                            label: context.l10n.profileShowMore,
                            type: DivineButtonType.secondary,
                          )
                        : const SizedBox(height: 8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BadgeDiscoveryHeader extends ConsumerWidget {
  const _BadgeDiscoveryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          context.l10n.badgeDiscoveryTitle,
          style: VineTheme.headlineSmallFont(
            color: context.vineColors.onSurface,
          ),
        ),
        Text(
          context.l10n.badgeDiscoveryBody,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
        DivineButton(
          label: 'badges.divine.video',
          semanticLabel: '${context.l10n.profileLearnMore} badges.divine.video',
          type: DivineButtonType.link,
          maxLines: 2,
          trailingIcon: DivineIconName.arrowUpRight,
          onPressed: () =>
              openExternalLink(context, 'https://badges.divine.video'),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DivineButton(
              label: context.l10n.badgesCreateAction,
              leadingIcon: DivineIconName.plus,
              maxLines: 2,
              onPressed: () async {
                if (!ref.read(authServiceProvider).isAuthenticated) {
                  await const LoginOptionsRouteData().push<void>(context);
                  return;
                }
                await const BadgeCreateRouteData().push<void>(context);
              },
            ),
            DivineButton(
              label: context.l10n.badgeDiscoveryMyBadges,
              type: DivineButtonType.secondary,
              maxLines: 2,
              onPressed: () async {
                if (!ref.read(authServiceProvider).isAuthenticated) {
                  await const LoginOptionsRouteData().push<void>(context);
                  return;
                }
                await const BadgesRouteData().push<void>(context);
              },
            ),
          ],
        ),
      ],
    ),
  );
}

class _BadgeCardSkeleton extends StatelessWidget {
  const _BadgeCardSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.commonLoading,
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        AspectRatio(
          aspectRatio: 177 / 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        FractionallySizedBox(
          widthFactor: .8,
          child: ColoredBox(
            color: context.vineColors.surfaceContainerHigh,
            child: const SizedBox(height: 20),
          ),
        ),
        FractionallySizedBox(
          widthFactor: .6,
          child: ColoredBox(
            color: context.vineColors.surfaceContainerHigh,
            child: const SizedBox(height: 14),
          ),
        ),
      ],
    ),
  );
}
