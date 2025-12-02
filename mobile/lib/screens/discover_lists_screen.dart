// ABOUTME: Screen for discovering and subscribing to public curated lists from Nostr relays
// ABOUTME: Shows public kind 30005 video lists with subscribe/unsubscribe functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/list_card.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';

class DiscoverListsScreen extends ConsumerStatefulWidget {
  const DiscoverListsScreen({super.key});

  @override
  ConsumerState<DiscoverListsScreen> createState() =>
      _DiscoverListsScreenState();
}

class _DiscoverListsScreenState extends ConsumerState<DiscoverListsScreen> {
  List<CuratedList>? _discoveredLists;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPublicLists();
  }

  Future<void> _loadPublicLists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = await ref.read(curatedListServiceProvider.future);
      final lists = await service.fetchPublicListsFromRelays(limit: 50);

      // Filter out empty lists and sort by video count (popularity)
      final nonEmptyLists =
          lists.where((list) => list.videoEventIds.isNotEmpty).toList()..sort(
            (a, b) => b.videoEventIds.length.compareTo(a.videoEventIds.length),
          );

      if (mounted) {
        setState(() {
          _discoveredLists = nonEmptyLists;
          _isLoading = false;
        });
        Log.info(
          'Discovered ${nonEmptyLists.length} non-empty public lists (filtered from ${lists.length} total)',
          category: LogCategory.ui,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load lists: $e';
          _isLoading = false;
        });
        Log.error(
          'Failed to discover public lists: $e',
          category: LogCategory.ui,
        );
      }
    }
  }

  Future<void> _toggleSubscription(CuratedList list) async {
    try {
      final service = await ref.read(curatedListServiceProvider.future);
      final isSubscribed = service.isSubscribedToList(list.id);

      if (isSubscribed) {
        await service.unsubscribeFromList(list.id);
        Log.info(
          'Unsubscribed from list: ${list.name}',
          category: LogCategory.ui,
        );
      } else {
        await service.subscribeToList(list.id, list);
        Log.info('Subscribed to list: ${list.name}', category: LogCategory.ui);
      }

      // Trigger rebuild to update button state
      setState(() {});

      // Invalidate providers so Lists tab updates
      ref.invalidate(curatedListsProvider);
    } catch (e) {
      Log.error('Failed to toggle subscription: $e', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription: $e'),
            backgroundColor: VineTheme.likeRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.cardBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Discover Lists',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: VineTheme.vineGreen),
            const SizedBox(height: 16),
            Text(
              'Discovering public lists...',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load lists',
              style: TextStyle(
                color: VineTheme.likeRed,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPublicLists,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_discoveredLists == null || _discoveredLists!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'No public lists found',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new lists',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: VineTheme.vineGreen,
      onRefresh: _loadPublicLists,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _discoveredLists!.length,
        itemBuilder: (context, index) {
          final list = _discoveredLists![index];
          return _buildListCard(list);
        },
      ),
    );
  }

  Widget _buildListCard(CuratedList list) {
    final serviceAsync = ref.watch(curatedListServiceProvider);

    return serviceAsync.when(
      data: (service) {
        final isSubscribed = service.isSubscribedToList(list.id);

        return Card(
          color: VineTheme.cardBackground,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () {
              Log.info(
                'Tapped discovered list: ${list.name}',
                category: LogCategory.ui,
              );
              // Stop any playing videos before navigating
              disposeAllVideoControllers(ref);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CuratedListFeedScreen(
                    listId: list.id,
                    listName: list.name,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.video_library,
                        color: VineTheme.vineGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list.name,
                              style: const TextStyle(
                                color: VineTheme.whiteText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (list.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                list.description!,
                                style: TextStyle(
                                  color: VineTheme.secondaryText,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Subscribe/Subscribed button
                      ElevatedButton.icon(
                        onPressed: () => _toggleSubscription(list),
                        icon: Icon(
                          isSubscribed ? Icons.check : Icons.add,
                          size: 18,
                        ),
                        label: Text(
                          isSubscribed ? 'Subscribed' : 'Subscribe',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSubscribed
                              ? VineTheme.cardBackground
                              : VineTheme.vineGreen,
                          foregroundColor: isSubscribed
                              ? VineTheme.vineGreen
                              : VineTheme.backgroundColor,
                          side: isSubscribed
                              ? BorderSide(color: VineTheme.vineGreen, width: 1)
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${list.videoEventIds.length} ${list.videoEventIds.length == 1 ? 'video' : 'videos'}',
                        style: TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      if (list.tags.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            list.tags.take(3).map((t) => '#$t').join(' '),
                            style: TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => CuratedListCard(curatedList: list, onTap: () {}),
      error: (_, __) => CuratedListCard(curatedList: list, onTap: () {}),
    );
  }
}
