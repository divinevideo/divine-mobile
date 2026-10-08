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
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:openvine/features/lists_discovery/lists_discovery_screenshot_fixtures.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:people_lists_repository/people_lists_repository.dart'
    show PeopleListSearchResult;
import 'package:unified_logger/unified_logger.dart';

/// Shared content-policy filter injected into the discovery cubit.
final listsDiscoveryBlockFilterProvider = Provider<bool Function(String)>(
  createBlockedAuthorFilter,
);

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
    final curatedState = ref.watch(curatedListsStateProvider);
    final service = ref.watch(curatedListsStateProvider.notifier).service;
    final curatedRepository = ref.watch(curatedListRepositoryProvider);
    final thumbnailPolicy = ref.watch(curatedListThumbnailFilterProvider);
    final peopleRepository = ref.watch(peopleListsRepositoryProvider);
    final peopleListsEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    final blocklistVersion = ref.watch(blocklistVersionProvider);
    final blockFilter = ref.watch(listsDiscoveryBlockFilterProvider);
    ref.watch(currentAuthStateProvider);
    final viewerPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;

    if (service == null && !curatedState.hasError) {
      return _LoadingGallery(
        peopleListsEnabled: peopleListsEnabled,
        showCreationActions: true,
      );
    }

    return BlocProvider(
      key: ValueKey((
        service,
        curatedRepository,
        thumbnailPolicy,
        peopleRepository,
        viewerPubkey,
        peopleListsEnabled,
        blocklistVersion,
        curatedState.hasError,
      )),
      create: (_) {
        final cubit = ListsDiscoveryCubit(
          curatedListService: service,
          curatedListRepository: curatedRepository,
          peopleListsRepository: peopleRepository,
          viewerPubkey: viewerPubkey,
          peopleListsEnabled: peopleListsEnabled,
          videoInitializationFailed: curatedState.hasError,
          blockFilter: blockFilter,
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
      child: ExploreListsView(
        showCreationActions: true,
        onRetryVideoInitialization: () =>
            ref.invalidate(curatedListsStateProvider),
      ),
    );
  }
}

/// View half: renders the two-column discovery gallery from cubit state.
class ExploreListsView extends StatelessWidget {
  /// Creates the view. Requires a [ListsDiscoveryCubit] above it.
  @visibleForTesting
  const ExploreListsView({
    this.onRetryVideoInitialization,
    this.showCreationActions = false,
    super.key,
  });

  /// Existing Main creation flows remain available above discovery.
  final bool showCreationActions;

  /// Rebuilds the saved-list service from acknowledged storage after recovery.
  final VoidCallback? onRetryVideoInitialization;

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
            if (state.isEmpty && !showCreationActions) {
              return _FullBleedMessage(text: context.l10n.listsDiscoveryEmpty);
            }
            return SingleChildScrollView(
              key: const Key('lists-tab-content'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              // Two independent columns under one scroll: when one runs out
              // its space stays empty while the other keeps going. Discovery
              // is capped at kListsDiscoveryColumnCap per column, so building
              // the cards eagerly stays bounded.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showCreationActions) const _ExploreCreationHeader(),
                  if (state.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        context.l10n.listsDiscoveryEmpty,
                        textAlign: TextAlign.center,
                        style: VineTheme.bodyLargeFont(
                          color: context.vineColors.onSurfaceMuted,
                        ),
                      ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [
                        Expanded(
                          child: _VideoListsColumn(
                            status: state.videoStatus,
                            initializationFailed:
                                state.videoInitializationFailed,
                            onRetryInitialization: onRetryVideoInitialization,
                            lists: state.videoLists,
                            thumbnailsPending: state.videoThumbnailsPending,
                          ),
                        ),
                        if (state.peopleListsEnabled)
                          Expanded(
                            child: _PeopleListsColumn(
                              status: state.peopleStatus,
                              lists: state.peopleLists,
                            ),
                          ),
                      ],
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
    required this.initializationFailed,
    this.onRetryInitialization,
  });

  final ListsDiscoveryColumnStatus status;
  final List<CuratedList> lists;
  final bool thumbnailsPending;
  final bool initializationFailed;
  final VoidCallback? onRetryInitialization;

  @override
  Widget build(BuildContext context) {
    if (initializationFailed) {
      return _VideoInitializationFailure(onRetry: onRetryInitialization);
    }
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
                    extra: CuratedListRouteExtra(
                      listName: list.name,
                      videoIds: list.videoEventIds,
                      authorPubkey: list.pubkey,
                      list: list,
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

class _VideoInitializationFailure extends StatelessWidget {
  const _VideoInitializationFailure({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          context.l10n.listErrorLoading,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        DivineButton(
          type: DivineButtonType.secondary,
          size: DivineButtonSize.small,
          label: context.l10n.searchTryAgain,
          onPressed: onRetry,
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
  const _LoadingGallery({
    required this.peopleListsEnabled,
    this.showCreationActions = false,
  });

  final bool peopleListsEnabled;

  final bool showCreationActions;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.surfaceContainerHigh,
      child: SingleChildScrollView(
        key: const Key('lists-tab-content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showCreationActions) const _ExploreCreationHeader(),
            Semantics(
              label: context.l10n.listsDiscoveryLoadingLabel,
              child: ListSkeletonizer(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: [
                    const Expanded(
                      child: _SkeletonCards(
                        card: DivineListThumbnailSkeleton.videos(),
                      ),
                    ),
                    if (peopleListsEnabled)
                      const Expanded(
                        child: _SkeletonCards(
                          card: DivineListThumbnailSkeleton.people(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Existing Main creation flows remain independent of discovery readiness.
class _ExploreCreationHeader extends ConsumerWidget {
  const _ExploreCreationHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (peopleEnabled) ...[
          DivineButton(
            leadingIcon: .plus,
            label: context.l10n.listNewPeopleList,
            onPressed: () => context.push(CreatePeopleListPage.path),
          ),
          const SizedBox(height: 16),
        ],
        DivineButton(
          leadingIcon: .plus,
          label: context.l10n.listNewVideoList,
          onPressed: () => runDetached(
            showListInfoSheet(context),
            'open list creation sheet',
            logName: 'ExploreListsTab',
            category: LogCategory.ui,
          ),
        ),
        const SizedBox(height: 16),
      ],
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
