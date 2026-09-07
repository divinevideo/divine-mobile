// ABOUTME: Screen for discovering and subscribing to public curated lists from Nostr relays
// ABOUTME: Shows public kind 30005 video lists with subscribe/unsubscribe functionality

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:unified_logger/unified_logger.dart';

class DiscoverListsScreen extends ConsumerStatefulWidget {
  const DiscoverListsScreen({super.key});

  static const String path = RoutePaths.discoverLists;

  static const String routeName = 'discover-lists';

  @override
  ConsumerState<DiscoverListsScreen> createState() =>
      _DiscoverListsScreenState();
}

class _DiscoverListsScreenState extends ConsumerState<DiscoverListsScreen>
    with ScrollPaginationMixin {
  bool _isLoadingMore = false;
  bool _hasReachedEnd = false;
  String? _errorMessage;
  StreamSubscription<List<CuratedList>>? _subscription;
  final _scrollController = ScrollController();

  // Debounce timer for batching rapid stream updates
  Timer? _updateDebounceTimer;
  List<CuratedList>? _pendingLists;

  /// Track if we're in refresh mode (need to merge lists, not replace)
  bool _isRefreshing = false;

  /// Track auto-pagination attempts to avoid infinite loops
  int _autoPaginationAttempts = 0;
  static const int _maxAutoPaginationAttempts = 5;
  static const int _minListsBeforeAutoPaginate = 10;
  static const Duration _paginationRelayReadTimeout = Duration(seconds: 3);

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() => !_hasReachedEnd && !_isLoadingMore;

  @override
  FutureOr<void> onLoadMore() => _loadMoreLists();

  @override
  void initState() {
    super.initState();
    initPagination();

    // Check if we already have cached lists from provider
    // Only stream if cache is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cachedState = ref.read(discoveredListsProvider);
      if (cachedState.lists.isEmpty) {
        _streamPublicLists();
      }
    });
  }

  @override
  void dispose() {
    _updateDebounceTimer?.cancel();
    _subscription?.cancel();
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _streamPublicLists({bool isRefresh = false}) async {
    final provider = ref.read(discoveredListsProvider.notifier);
    final currentState = ref.read(discoveredListsProvider);

    // Preserve existing lists during refresh
    final hadExistingLists = currentState.lists.isNotEmpty;

    setState(() {
      _errorMessage = null;
      _isRefreshing = isRefresh;
      _autoPaginationAttempts = 0;
      _hasReachedEnd = false;
    });

    // Clear lists only if not refreshing
    if (!isRefresh) {
      provider.clear();
    }

    // Set loading state in provider after any clear() call.
    provider.setLoading(!hadExistingLists);

    try {
      final service = ref.read(curatedListsStateProvider.notifier).service;

      if (service == null) {
        provider.setLoading(false);
        setState(() {
          _isRefreshing = false;
          _errorMessage = context.l10n.discoverListsServiceUnavailable;
        });
        return;
      }

      // Stream results - UI updates with debouncing to handle rapid events
      await _subscription?.cancel();
      var hasReceivedStreamUpdate = false;
      _subscription = service.streamPublicListsFromRelays().listen(
        (lists) {
          hasReceivedStreamUpdate = true;
          if (mounted) {
            // Track oldest timestamp for pagination
            for (final list in lists) {
              provider.updateOldestTimestamp(list.createdAt);
            }

            // Store pending lists and debounce UI updates
            _pendingLists = lists;

            // Log progress for debugging
            Log.debug(
              '📋 UI received ${lists.length} lists from stream',
              category: LogCategory.ui,
            );

            // Cancel any pending update and schedule a new one
            _updateDebounceTimer?.cancel();
            _updateDebounceTimer = Timer(const Duration(milliseconds: 100), () {
              if (mounted && _pendingLists != null) {
                final newLists = _pendingLists!;

                // During refresh, merge new lists with existing
                if (_isRefreshing) {
                  provider.addLists(newLists);
                  Log.info(
                    '📋 Refresh: merging ${newLists.length} lists',
                    category: LogCategory.ui,
                  );
                } else {
                  provider.setLists(newLists);
                }

                provider.setLoading(false);
                setState(() {
                  _isRefreshing = false;
                });

                ref
                    .read(screenAnalyticsServiceProvider)
                    .markDataLoaded(
                      'discover_lists',
                      dataMetrics: {
                        'list_count': ref
                            .read(discoveredListsProvider)
                            .lists
                            .length,
                      },
                    );

                // Auto-paginate if we have few results
                final providerState = ref.read(discoveredListsProvider);
                if (providerState.lists.length < _minListsBeforeAutoPaginate &&
                    providerState.oldestTimestamp != null &&
                    _autoPaginationAttempts < _maxAutoPaginationAttempts &&
                    !_isLoadingMore) {
                  _autoPaginationAttempts++;
                  Log.info(
                    'Auto-paginating to find more lists (attempt '
                    '$_autoPaginationAttempts/$_maxAutoPaginationAttempts, '
                    'currently have ${providerState.lists.length} lists)',
                    category: LogCategory.ui,
                  );
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && !_isLoadingMore) {
                      _loadMoreLists();
                    }
                  });
                }
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            provider.setLoading(false);
            setState(() {
              _isRefreshing = false;
              final hasRenderedLists = ref
                  .read(discoveredListsProvider)
                  .lists
                  .isNotEmpty;
              if (!hasRenderedLists || error is! TimeoutException) {
                if (error is! TimeoutException) {
                  Log.error(
                    'Public list stream failed: $error',
                    category: LogCategory.ui,
                  );
                }
                _errorMessage = error is TimeoutException
                    ? context.l10n.discoverListsRelayTimeout
                    : context.l10n.discoverListsFailedToLoad;
              }
            });
          }
        },
        onDone: () {
          if (mounted && !hasReceivedStreamUpdate) {
            provider.setLoading(false);
            setState(() {
              _isRefreshing = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ref.read(discoveredListsProvider.notifier).setLoading(false);
        setState(() {
          _isRefreshing = false;
          _errorMessage = context.l10n.discoverListsFailedToLoad;
        });
        Log.error(
          'Failed to discover public lists: $e',
          category: LogCategory.ui,
        );
      }
    }
  }

  Future<void> _loadMoreLists() async {
    final providerState = ref.read(discoveredListsProvider);
    if (_isLoadingMore ||
        _hasReachedEnd ||
        providerState.oldestTimestamp == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    var foundNewLists = false;
    var timedOut = false;

    try {
      final service = ref.read(curatedListsStateProvider.notifier).service;

      if (service == null) return;

      final provider = ref.read(discoveredListsProvider.notifier);
      final currentLists = ref.read(discoveredListsProvider).lists;
      final existingIds = currentLists.map((l) => l.id).toSet();
      final initialCount = existingIds.length;

      Log.info(
        '📋 Loading more lists, excluding $initialCount known IDs',
        category: LogCategory.ui,
      );

      final stream = service.streamPublicListsFromRelays(
        until: providerState.oldestTimestamp,
        excludeIds: existingIds,
        timeout: _paginationRelayReadTimeout,
      );

      await for (final lists in stream) {
        if (!mounted) break;

        // Add new lists that we don't already have
        final newLists = lists
            .where((l) => !existingIds.contains(l.id))
            .toList();

        if (newLists.isNotEmpty) {
          foundNewLists = true;
          for (final list in newLists) {
            existingIds.add(list.id);
            // Update oldest timestamp in provider
            provider.updateOldestTimestamp(list.createdAt);
          }

          // Add to provider (handles deduplication and sorting)
          provider.addLists(newLists);
        }
      }

      final finalState = ref.read(discoveredListsProvider);
      Log.info(
        'Pagination done: ${finalState.lists.length} total lists',
        category: LogCategory.ui,
      );
    } on TimeoutException catch (error) {
      timedOut = true;
      Log.warning('Pagination timeout: $error', category: LogCategory.ui);
    } catch (error) {
      Log.error('Pagination error: $error', category: LogCategory.ui);
    } finally {
      if (mounted) {
        if (!foundNewLists && !timedOut) {
          _hasReachedEnd = true;
        }

        setState(() {
          _isLoadingMore = false;
        });

        // Continue auto-paginating if we still have few results
        final finalState = ref.read(discoveredListsProvider);
        if (!_hasReachedEnd &&
            !timedOut &&
            finalState.lists.length < _minListsBeforeAutoPaginate &&
            finalState.oldestTimestamp != null &&
            _autoPaginationAttempts < _maxAutoPaginationAttempts) {
          _autoPaginationAttempts++;
          Log.info(
            'Continuing auto-pagination (attempt '
            '$_autoPaginationAttempts/$_maxAutoPaginationAttempts, '
            'have ${finalState.lists.length} lists)',
            category: LogCategory.ui,
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isLoadingMore) {
              _loadMoreLists();
            }
          });
        }
      }
    }
  }

  Future<void> _toggleSubscription(CuratedList list) async {
    try {
      final service = ref.read(curatedListsStateProvider.notifier).service;
      final isSubscribed = service?.isSubscribedToList(list.id) ?? false;

      if (isSubscribed) {
        await service?.unsubscribeFromList(list.id);
        Log.info(
          'Unsubscribed from list: ${list.name}',
          category: LogCategory.ui,
        );
      } else {
        await service?.subscribeToList(list.id, list);
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
            content: Text(
              context.l10n.discoverListsFailedToUpdateSubscription,
            ),
            backgroundColor: VineTheme.likeRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.discoverListsTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Watch the provider for reactive updates
    final providerState = ref.watch(discoveredListsProvider);
    final discoveredLists = providerState.lists;
    final isLoading = providerState.isLoading;

    if (isLoading && discoveredLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DivineCircularProgressIndicator(color: VineTheme.vineGreen),
            const SizedBox(height: 16),
            Text(
              context.l10n.discoverListsLoading,
              style: TextStyle(
                color: context.vineColors.secondaryText,
                fontSize: 14,
              ),
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
            const DivineIcon(
              icon: DivineIconName.warningCircle,
              size: 64,
              color: VineTheme.likeRed,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.discoverListsFailedToLoad,
              style: const TextStyle(
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
                style: TextStyle(
                  color: context.vineColors.secondaryText,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _streamPublicLists,
              icon: const DivineIcon(
                icon: DivineIconName.arrowClockwise,
                color: VineTheme.onPrimary,
              ),
              label: Text(context.l10n.commonRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: context.vineColors.background,
              ),
            ),
          ],
        ),
      );
    }

    if (discoveredLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DivineIcon(
              icon: DivineIconName.search,
              size: 64,
              color: context.vineColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.discoverListsEmptyTitle,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.discoverListsEmptySubtitle,
              style: TextStyle(
                color: context.vineColors.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () => _streamPublicLists(isRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        // +1 for loading indicator at bottom
        itemCount: discoveredLists.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at bottom
          if (index == discoveredLists.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: DivineCircularProgressIndicator(
                  color: VineTheme.vineGreen,
                ),
              ),
            );
          }
          final list = discoveredLists[index];
          return Semantics(
            identifier: SemanticIds.listCard(index),
            child: _buildListCard(list),
          );
        },
      ),
    );
  }

  Widget _buildListCard(CuratedList list) {
    // Check subscription status - don't block rendering on service state
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final isSubscribed =
        serviceAsync.whenOrNull(
          data: (_) => service?.isSubscribedToList(list.id),
        ) ??
        false;

    return Card(
      color: context.vineColors.card,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Log.info(
            'Tapped discovered list: ${list.name}',
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
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
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
                          style: TextStyle(
                            color: context.vineColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (list.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            list.description!,
                            style: TextStyle(
                              color: context.vineColors.secondaryText,
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
                  // Subscribe/Subscribed button (icon-only)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => _toggleSubscription(list),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSubscribed
                            ? context.vineColors.card
                            : VineTheme.vineGreen,
                        foregroundColor: isSubscribed
                            ? VineTheme.vineGreen
                            : context.vineColors.background,
                        side: isSubscribed
                            ? const BorderSide(color: VineTheme.vineGreen)
                            : null,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: DivineIcon(
                        icon: isSubscribed
                            ? DivineIconName.check
                            : DivineIconName.plus,
                        size: 20,
                        color: isSubscribed
                            ? VineTheme.vineGreen
                            : context.vineColors.background,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Creator info
                  if (list.pubkey != null) ...[
                    Text(
                      context.l10n.discoverListsByAuthorPrefix,
                      style: TextStyle(
                        color: context.vineColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      flex: 0,
                      child: UserName.fromPubKey(
                        list.pubkey!,
                        style: const TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        color: context.vineColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    context.l10n.listVideoCount(list.videoEventIds.length),
                    style: TextStyle(
                      color: context.vineColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  if (list.tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        color: context.vineColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        list.tags.take(3).map((t) => '#$t').join(' '),
                        style: const TextStyle(
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
  }
}
