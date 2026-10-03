// ABOUTME: Explore "Lists" tab — the discovery gallery: video lists and
// ABOUTME: people lists in two independent columns. My Lists lives on the
// ABOUTME: profile's Lists tab, not here.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:openvine/features/lists_discovery/lists_discovery_screenshot_fixtures.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:people_lists_repository/people_lists_repository.dart'
    show PeopleListSearchResult;
import 'package:unified_logger/unified_logger.dart';

/// The Lists tab shown inside `ExploreScreen`: the discovery gallery.
///
/// Page half of the Page/View split: bridges the Riverpod-provided service
/// and repositories into the [ListsDiscoveryCubit], re-keyed on their
/// identities so an auth flip rebuilds the cubit against the fresh
/// dependencies.
class ExploreListsTab extends ConsumerStatefulWidget {
  /// Creates the Lists tab.
  const ExploreListsTab({super.key});

  @override
  ConsumerState<ExploreListsTab> createState() => _ExploreListsTabState();
}

class _ExploreListsTabState extends ConsumerState<ExploreListsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // The state creates its service before awaiting initialization. Watching
    // the state re-keys discovery when a new service becomes available.
    ref.watch(curatedListsStateProvider);
    final service = ref.watch(curatedListsStateProvider.notifier).service;
    final curatedRepository = ref.watch(curatedListRepositoryProvider);
    final peopleRepository = ref.watch(peopleListsRepositoryProvider);
    ref.watch(currentAuthStateProvider);
    final viewerPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;

    if (service == null) {
      return const _LoadingGallery();
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
          seed: ScreenshotMode.enabled
              ? ListsDiscoveryState(
                  videoStatus: ListsDiscoveryColumnStatus.success,
                  peopleStatus: ListsDiscoveryColumnStatus.success,
                  videoLists: screenshotDiscoverListsFixtures(),
                )
              : null,
        );
        // Screenshot mode: deterministic fixtures instead of live relay
        // discovery, same pattern as the classics row in app_bootstrap.
        if (!ScreenshotMode.enabled) {
          runDetached(
            cubit.load(),
            'load list discovery',
            logName: 'ExploreListsTab',
            category: LogCategory.ui,
          );
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
              // is capped at kListsDiscoveryColumnCap per column, so building
              // the cards eagerly stays bounded.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Expanded(
                    child: _VideoListsColumn(
                      status: state.videoStatus,
                      lists: state.videoLists,
                      thumbnailsPending: state.videoThumbnailsPending,
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
  const _VideoListsColumn({
    required this.status,
    required this.lists,
    required this.thumbnailsPending,
  });

  final ListsDiscoveryColumnStatus status;
  final List<CuratedList> lists;
  final bool thumbnailsPending;

  @override
  Widget build(BuildContext context) {
    return _DiscoveryColumn(
      status: status,
      placeholder: const DivineListThumbnailSkeleton.videos(),
      isColumnEmpty: lists.isEmpty,
      children: [
        for (final (index, list) in lists.indexed)
          Semantics(
            // The stream re-sorts on every emit, so cards can change slots;
            // the key keeps each card's image state with its list.
            key: ValueKey(list.authorScopedId),
            identifier: SemanticIds.listCard(index),
            container: true,
            child: DivineListThumbnail.videos(
              curatedList: list,
              thumbnailsPending: thumbnailsPending,
              onTap: () {
                final author = list.pubkey;
                if (author == null) return;
                Log.info(
                  'Opening discovered video list: ${list.id}',
                  category: LogCategory.ui,
                );
                runDetached(
                  context.push<void>(
                    CuratedListByAuthorScreen.pathFor(
                      pubkey: author,
                      listId: list.id,
                    ),
                  ),
                  'open discovered list',
                  logName: 'VideoListsColumn',
                  category: LogCategory.ui,
                );
              },
            ),
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
      placeholder: const DivineListThumbnailSkeleton.people(),
      isColumnEmpty: lists.isEmpty,
      children: [
        for (final result in lists)
          DivineListThumbnail.people(
            key: ValueKey(result.addressableId),
            userList: result.list,
            onTap: () {
              Log.info(
                'Opening discovered people list: ${result.list.id}',
                category: LogCategory.ui,
              );
              runDetached(
                context.push<void>(
                  RoutePaths.peopleListForId(
                    result.list.id,
                    ownerPubkey: result.ownerPubkey,
                  ),
                ),
                'open discovered people list',
                logName: 'PeopleListsColumn',
                category: LogCategory.ui,
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
    required this.placeholder,
    required this.children,
  });

  final ListsDiscoveryColumnStatus status;
  final bool isColumnEmpty;

  /// The card silhouette this column shows while its lists load.
  final DivineListThumbnailSkeleton placeholder;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (isColumnEmpty) {
      return switch (status) {
        ListsDiscoveryColumnStatus.initial ||
        ListsDiscoveryColumnStatus.loading => _LoadingColumn(card: placeholder),
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

/// Placeholder cards per loading column: enough to fill a phone's height,
/// so the column reads as "cards are coming" rather than as empty space.
const _loadingCardCount = 4;

/// A column of card silhouettes, shimmering, announced once as loading.
///
/// Stands in for a column whose lists have not arrived yet, in the same
/// slot and with the same card geometry, so nothing shifts when they do.
class _LoadingColumn extends StatelessWidget {
  const _LoadingColumn({required this.card});

  final DivineListThumbnailSkeleton card;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.listsDiscoveryLoadingLabel,
      child: ListSkeletonizer(child: _SkeletonCards(card: card)),
    );
  }
}

/// Both columns as silhouettes under one shimmer when no curated-list
/// service is available to create the cubit.
class _LoadingGallery extends StatelessWidget {
  const _LoadingGallery();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.surfaceContainerHigh,
      child: Semantics(
        label: context.l10n.listsDiscoveryLoadingLabel,
        child: const ListSkeletonizer(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                Expanded(
                  child: _SkeletonCards(
                    card: DivineListThumbnailSkeleton.videos(),
                  ),
                ),
                Expanded(
                  child: _SkeletonCards(
                    card: DivineListThumbnailSkeleton.people(),
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

class _SkeletonCards extends StatelessWidget {
  const _SkeletonCards({required this.card});

  final DivineListThumbnailSkeleton card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: List.filled(_loadingCardCount, card),
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
