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
import 'package:openvine/providers/database_provider.dart';
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
        final cubit = ExploreBadgesCubit(
          repository: repository,
          hiddenIssuers:
              ref.read(vanishedProfilePubkeysProvider).value ?? const {},
        );
        runDetached(
          cubit.load(),
          'load explore badges',
          logName: 'ExploreBadgesTab',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: const _BadgeVisibilityGate(),
    );
  }
}

class _BadgeVisibilityGate extends ConsumerStatefulWidget {
  const _BadgeVisibilityGate();

  @override
  ConsumerState<_BadgeVisibilityGate> createState() =>
      _BadgeVisibilityGateState();
}

class _BadgeVisibilityGateState extends ConsumerState<_BadgeVisibilityGate> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<ExploreBadgesCubit>();
    ref.listenManual(vanishedProfilePubkeysProvider, (_, next) {
      if (next.error case final error?) {
        Log.warning(
          'Badge discovery could not load vanish markers',
          name: 'ExploreBadgesTab',
          category: LogCategory.ui,
          error: error,
          stackTrace: next.stackTrace,
        );
      }
      final vanished = next.value;
      if (vanished != null) cubit.updateHiddenIssuers(vanished);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final visibility = ref.watch(
      vanishedProfilePubkeysProvider.select(
        (snapshot) => (
          pending: snapshot.isLoading || !snapshot.hasValue,
          failed: snapshot.hasError,
        ),
      ),
    );
    // Public discovery may finish before Drift has read the local vanish
    // markers. Keep the snapshot offscreen so no card can request a preview.
    return ExploreBadgesView(
      isVisibilityPending: visibility.pending,
      onVisibilityRetry: visibility.failed
          ? () => ref.invalidate(vanishedProfilePubkeysProvider)
          : null,
    );
  }
}

/// Responsive gallery driven by [ExploreBadgesCubit].
class ExploreBadgesView extends StatelessWidget {
  @visibleForTesting
  const ExploreBadgesView({
    super.key,
    this.isVisibilityPending = false,
    this.onVisibilityRetry,
  });

  final bool isVisibilityPending;
  final VoidCallback? onVisibilityRetry;

  @override
  Widget build(BuildContext context) {
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
      child: BlocBuilder<ExploreBadgesCubit, ExploreBadgesState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.definitions != current.definitions ||
            previous.hiddenIssuers != current.hiddenIssuers ||
            previous.visibleCount != current.visibleCount ||
            previous.previewGeneration != current.previewGeneration ||
            (previous.isRefreshing && !current.isRefreshing),
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20
                ? 1
                : 2;
            final loading =
                isVisibilityPending ||
                state.status == ExploreBadgesStatus.initial ||
                state.status == ExploreBadgesStatus.loading;
            final definitions = state.visibleDefinitions;
            final rowCount = (definitions.length / columns).ceil();
            return RefreshIndicator(
              color: VineTheme.onPrimary,
              backgroundColor: VineTheme.vineGreen,
              onRefresh: cubit.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: _BadgeDiscoveryHeader()),
                  if (onVisibilityRetry != null ||
                      (!isVisibilityPending &&
                          state.status == ExploreBadgesStatus.failure))
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
                              onPressed: onVisibilityRetry ?? cubit.load,
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
                        child: Column(
                          spacing: 16,
                          children: [
                            Text(
                              context.l10n.badgeDiscoveryEmpty,
                              textAlign: TextAlign.center,
                              style: VineTheme.bodyMediumFont(
                                color: context.vineColors.onSurfaceVariant,
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
                  else if (loading)
                    SliverToBoxAdapter(
                      child: Semantics(
                        label: context.l10n.commonLoading,
                        container: true,
                        liveRegion: true,
                        excludeSemantics: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            spacing: 20,
                            children: List.generate(
                              3,
                              (_) => Row(
                                spacing: 16,
                                children: List.generate(
                                  columns,
                                  (_) => const Expanded(
                                    child: _BadgeCardSkeleton(),
                                  ),
                                ),
                              ),
                            ),
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
                        itemBuilder: (context, row) {
                          final first = row * columns;
                          final rowDefinitions = definitions
                              .skip(first)
                              .take(columns);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 16,
                            children: [
                              for (final definition in rowDefinitions)
                                Expanded(
                                  key: ValueKey(definition.coordinate),
                                  child: _BadgePreviewCard(
                                    definition: definition,
                                  ),
                                ),
                              for (
                                var i = rowDefinitions.length;
                                i < columns;
                                i++
                              )
                                const Expanded(child: SizedBox.shrink()),
                            ],
                          );
                        },
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child:
                          !loading && onVisibilityRetry == null && state.hasMore
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
      ),
    );
  }
}

class _BadgePreviewCard extends StatelessWidget {
  const _BadgePreviewCard({required this.definition});

  final Nip58BadgeDefinition definition;

  @override
  Widget build(BuildContext context) {
    final coordinate = definition.coordinate;
    final cubit = context.read<ExploreBadgesCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) cubit.loadPreview(coordinate);
    });
    return BlocSelector<ExploreBadgesCubit, ExploreBadgesState, List<String>>(
      selector: (state) => state.previews[coordinate] ?? const [],
      builder: (context, members) => BadgeCommunityCard(
        key: ValueKey(coordinate),
        definition: definition,
        memberPubkeys: members,
        onTap: () => context.push<void>(
          BadgeDetailScreen.pathFor(BadgeCoordinate.parse(coordinate)!),
        ),
      ),
    );
  }
}

const _badgeWebsite = 'badges.divine.video';

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
          label: _badgeWebsite,
          semanticLabel: context.l10n.badgeDiscoveryWebsiteLabel(_badgeWebsite),
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      AspectRatio(
        aspectRatio: badgeArtworkAspectRatio,
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
  );
}
