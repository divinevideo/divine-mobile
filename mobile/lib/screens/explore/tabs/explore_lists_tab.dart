// ABOUTME: Explore "Lists" tab — discover/create lists plus the user's own,
// ABOUTME: people, and subscribed curated lists.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/list_card.dart';
import 'package:openvine/widgets/owned_list_card.dart';
import 'package:unified_logger/unified_logger.dart';

/// The Lists tab shown inside [ExploreScreen].
class ExploreListsTab extends ConsumerWidget {
  /// Creates the Lists tab.
  const ExploreListsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load data but don't wait for everything - show UI progressively
    final allListsAsync = ref.watch(allListsProvider);

    // Always show the static UI elements immediately
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        // Invalidate both providers to refresh
        ref.invalidate(userListsProvider);
        ref.invalidate(curatedListsProvider);
      },
      child: ListView(
        key: const Key('lists-tab-content'),
        // Explicit padding: without it Flutter inserts MediaQuery.padding,
        // which adds a status-bar-sized gap above the first card.
        padding: EdgeInsets.zero,
        children: [
          // Discover Lists button - ALWAYS VISIBLE
          Padding(
            padding: const EdgeInsets.all(16),
            child: DivineButton(
              leadingIcon: .search,
              label: context.l10n.exploreDiscoverLists,
              onPressed: () {
                Log.info(
                  'Tapped Discover Lists button',
                  category: LogCategory.ui,
                );
                context.push(DiscoverListsScreen.path);
              },
            ),
          ),

          // Create New List button - ALWAYS VISIBLE
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DivineButton(
              leadingIcon: .plus,
              label: context.l10n.listCreateNewList,
              onPressed: () {
                Log.info(
                  'Tapped Create New List button',
                  category: LogCategory.ui,
                );
                showDialog<void>(
                  context: context,
                  builder: (_) => const CreateListDialog(),
                );
              },
            ),
          ),

          // Help text - ALWAYS VISIBLE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DivineInfoCard(
              title: context.l10n.exploreAboutLists,
              message: context.l10n.exploreAboutListsDescription,
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  _ListKindExplainer(
                    icon: DivineIconName.user,
                    title: context.l10n.explorePeopleLists,
                    description: context.l10n.explorePeopleListsDescription,
                  ),
                  _ListKindExplainer(
                    icon: DivineIconName.playlist,
                    title: context.l10n.exploreVideoLists,
                    description: context.l10n.exploreVideoListsDescription,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // MY LISTS and PEOPLE LISTS - Show immediately when data available
          allListsAsync.when(
            skipLoadingOnRefresh: true,
            data: (data) {
              final userLists = data.userLists;
              // Owned lists stay visible after publishing — filtering on a
              // null nostrEventId hid lists once they reached the relay.
              final service = ref
                  .read(curatedListsStateProvider.notifier)
                  .service;
              final myLists = service?.myLists ?? const <CuratedList>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // My Lists section
                  if (myLists.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          DivineIcon(
                            icon: DivineIconName.playlist,
                            color: context.vineColors.accentPositive,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.exploreMyLists,
                            style: TextStyle(
                              color: context.vineColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...myLists.map(
                      (curatedList) => OwnedListCard(
                        curatedList: curatedList,
                        onTap: () => Log.info(
                          'Tapped my curated list: ${curatedList.name}',
                          category: LogCategory.ui,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // People Lists section
                  if (userLists.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          DivineIcon(
                            icon: DivineIconName.user,
                            color: context.vineColors.accentPositive,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.explorePeopleLists,
                            style: TextStyle(
                              color: context.vineColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...userLists.map(
                      (userList) => UserListCard(
                        userList: userList,
                        onTap: () {
                          Log.info(
                            'Tapped user list: ${userList.name}',
                            category: LogCategory.ui,
                          );
                          context.push(
                            '/people-lists/'
                            '${Uri.encodeComponent(userList.id)}',
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: BrandedLoadingIndicator(size: 60)),
            ),
            error: (error, stack) {
              Log.error(
                'Failed to load lists: $error',
                name: 'ExploreListsTab',
                category: LogCategory.ui,
              );
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.exploreErrorLoadingLists,
                  style: VineTheme.bodyMediumFont(color: VineTheme.error),
                ),
              );
            },
          ),

          // SUBSCRIBED LISTS - Load separately with its own loading state
          const _SubscribedListsSection(),
        ],
      ),
    );
  }
}

/// Subscribed curated lists section with an independent loading state.
class _SubscribedListsSection extends ConsumerWidget {
  const _SubscribedListsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allListsAsync = ref.watch(allListsProvider);
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    // Wait for both to load subscribed lists
    if (!allListsAsync.hasValue || !serviceAsync.hasValue) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DivineIcon(
                  icon: DivineIconName.checks,
                  color: context.vineColors.accentPositive,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.exploreSubscribedLists,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(child: BrandedLoadingIndicator(size: 60)),
          ],
        ),
      );
    }

    final allCuratedLists = allListsAsync.value!.curatedLists;

    // Filter subscribed lists
    final subscribedLists = allCuratedLists.where((list) {
      return service?.isSubscribedToList(list.id) ?? false;
    }).toList();

    if (subscribedLists.isEmpty) {
      // Don't show section if no subscribed lists
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              DivineIcon(
                icon: DivineIconName.checks,
                color: context.vineColors.accentPositive,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.exploreSubscribedLists,
                style: TextStyle(
                  color: context.vineColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...subscribedLists.map(
          (curatedList) => CuratedListCard(
            curatedList: curatedList,
            onTap: () {
              Log.info(
                'Tapped subscribed list: ${curatedList.name}',
                category: LogCategory.ui,
              );
              context.push(
                CuratedListFeedScreen.pathForId(curatedList.id),
                extra: CuratedListRouteExtra(listName: curatedList.name),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One "what this kind of list is" row inside the tab's explanation card.
class _ListKindExplainer extends StatelessWidget {
  const _ListKindExplainer({
    required this.icon,
    required this.title,
    required this.description,
  });

  final DivineIconName icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        DivineIcon(
          icon: icon,
          color: context.vineColors.accentPositive,
          size: 18,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                title,
                style: VineTheme.labelLargeFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              Text(
                description,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
