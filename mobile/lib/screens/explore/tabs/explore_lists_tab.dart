// ABOUTME: Explore "Lists" tab — the discovery gallery: video lists and
// ABOUTME: people lists in two independent columns. My Lists lives on the
// ABOUTME: profile's Lists tab, not here.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:openvine/features/lists_discovery/lists_discovery_screenshot_fixtures.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/list_search_card.dart';
import 'package:openvine/widgets/people_list_card.dart';
import 'package:people_lists_repository/people_lists_repository.dart'
    show PeopleListSearchResult;
import 'package:unified_logger/unified_logger.dart';

/// The Lists tab shown inside `ExploreScreen`: the discovery gallery.
///
/// Page half of the Page/View split: bridges the Riverpod-provided service
/// and repositories into the [ListsDiscoveryCubit], re-keyed on their
/// identities so an auth flip rebuilds the cubit against the fresh
/// dependencies.
class ExploreListsTab extends ConsumerWidget {
  /// Creates the Lists tab.
  const ExploreListsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Readiness gate: the service is null until the curated-lists state
    // finishes its cold-start load.
    ref.watch(curatedListsStateProvider);
    final service = ref.watch(curatedListsStateProvider.notifier).service;
    final curatedRepository = ref.watch(curatedListRepositoryProvider);
    final peopleRepository = ref.watch(peopleListsRepositoryProvider);
    ref.watch(currentAuthStateProvider);
    final viewerPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;

    if (service == null) {
      return const Center(child: BrandedLoadingIndicator(size: 60));
    }

    return BlocProvider(
      key: ValueKey((
        service,
        curatedRepository,
        peopleRepository,
        viewerPubkey,
      )),
      create: (_) {
        final cubit = ListsDiscoveryCubit(
          curatedListService: service,
          curatedListRepository: curatedRepository,
          peopleListsRepository: peopleRepository,
          viewerPubkey: viewerPubkey,
        );
        // Screenshot mode: deterministic fixtures instead of live relay
        // discovery, same pattern as the classics row in app_bootstrap.
        if (ScreenshotMode.enabled) {
          cubit.seedForScreenshots(
            videoLists: screenshotDiscoverListsFixtures(),
          );
        } else {
          cubit.load();
        }
        return cubit;
      },
      child: const ExploreListsView(),
    );
  }
}

/// View half: renders the two-column discovery gallery from cubit state.
class ExploreListsView extends StatelessWidget {
  /// Creates the view. Requires a [ListsDiscoveryCubit] above it.
  @visibleForTesting
  const ExploreListsView({super.key});

  @override
  Widget build(BuildContext context) {
    // The gallery ground is the design's darker container, same as the list
    // detail's grid panel.
    return ColoredBox(
      color: context.vineColors.surfaceContainerHigh,
      child: RefreshIndicator(
        color: VineTheme.onPrimary,
        backgroundColor: VineTheme.vineGreen,
        onRefresh: () => context.read<ListsDiscoveryCubit>().load(),
        child: BlocBuilder<ListsDiscoveryCubit, ListsDiscoveryState>(
          builder: (context, state) {
            if (state.isEmpty) {
              return _FullBleedMessage(
                text: context.l10n.listsDiscoveryEmpty,
              );
            }
            return SingleChildScrollView(
              key: const Key('lists-tab-content'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              // Two independent columns under one scroll: when one runs out
              // its space stays empty while the other keeps going. Discovery
              // is capped at kListsDiscoveryLimit per column, so building
              // the cards eagerly stays bounded.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Expanded(
                    child: _VideoListsColumn(
                      status: state.videoStatus,
                      lists: state.videoLists,
                    ),
                  ),
                  Expanded(
                    child: _PeopleListsColumn(
                      status: state.peopleStatus,
                      lists: state.peopleLists,
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

/// Left column: discovered kind-30005 video lists.
class _VideoListsColumn extends StatelessWidget {
  const _VideoListsColumn({required this.status, required this.lists});

  final ListsDiscoveryColumnStatus status;
  final List<CuratedList> lists;

  @override
  Widget build(BuildContext context) {
    return _DiscoveryColumn(
      status: status,
      isColumnEmpty: lists.isEmpty,
      children: [
        for (final list in lists)
          CuratedListSearchCard(
            curatedList: list,
            onTap: () {
              Log.info(
                'Opening discovered video list: ${list.id}',
                category: LogCategory.ui,
              );
              context.push(
                CuratedListFeedScreen.pathForId(list.id),
                extra: CuratedListRouteExtra(
                  listName: list.name,
                  videoIds: list.videoEventIds,
                  authorPubkey: list.pubkey,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Right column: discovered kind-30000 people lists.
class _PeopleListsColumn extends StatelessWidget {
  const _PeopleListsColumn({required this.status, required this.lists});

  final ListsDiscoveryColumnStatus status;
  final List<PeopleListSearchResult> lists;

  @override
  Widget build(BuildContext context) {
    return _DiscoveryColumn(
      status: status,
      isColumnEmpty: lists.isEmpty,
      children: [
        for (final result in lists)
          PeopleListCard(
            userList: result.list,
            onTap: () {
              Log.info(
                'Opening discovered people list: ${result.list.id}',
                category: LogCategory.ui,
              );
              context.push(
                RoutePaths.peopleListForId(
                  result.list.id,
                  ownerPubkey: result.ownerPubkey,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// One discovery column: cards stacked with the design's row spacing, a
/// small loader while its source loads, and a quiet error line when its
/// source failed. A successfully-empty column renders nothing — the other
/// column keeps the tab alive.
class _DiscoveryColumn extends StatelessWidget {
  const _DiscoveryColumn({
    required this.status,
    required this.isColumnEmpty,
    required this.children,
  });

  final ListsDiscoveryColumnStatus status;
  final bool isColumnEmpty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (isColumnEmpty) {
      return switch (status) {
        ListsDiscoveryColumnStatus.initial ||
        ListsDiscoveryColumnStatus.loading => const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: BrandedLoadingIndicator(size: 40)),
        ),
        ListsDiscoveryColumnStatus.failure => Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            context.l10n.exploreErrorLoadingLists,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        ListsDiscoveryColumnStatus.success => const SizedBox.shrink(),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: children,
    );
  }
}

/// Full-height centered message that still supports pull-to-refresh.
class _FullBleedMessage extends StatelessWidget {
  const _FullBleedMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                text,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
