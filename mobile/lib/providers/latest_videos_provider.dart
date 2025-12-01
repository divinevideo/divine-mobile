// ABOUTME: Provider for fetching the latest videos from Nostr relays
// ABOUTME: Ensures NEW VINES tab shows truly recent content from the network

import 'dart:async';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'latest_videos_provider.g.dart';

/// Provider for the latest videos from the network
@Riverpod(keepAlive: false)
class LatestVideos extends _$LatestVideos {
  Timer? _refreshTimer;
  StreamSubscription? _subscription;
  final Set<String> _loadedVideoIds = {};
  int? _oldestTimestamp;
  bool _isLoadingMore = false;

  @override
  Future<List<VideoEvent>> build() async {
    final isExploreActive = ref.watch(isExploreTabActiveProvider);
    if (!isExploreActive) {
      // Not on Explore; do not start timers or subscriptions
      ref.onDispose(() {
        _refreshTimer?.cancel();
        _subscription?.cancel();
      });
      return [];
    }
    // Set up auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.hasValue && !_isLoadingMore) {
        _fetchLatestVideos(isRefresh: true);
      }
    });

    // Clean up on dispose
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _subscription?.cancel();
    });

    // Initial fetch
    return _fetchLatestVideos();
  }

  Future<List<VideoEvent>> _fetchLatestVideos({
    bool isRefresh = false,
    bool loadMore = false,
  }) async {
    try {
      if (_isLoadingMore && loadMore) {
        Log.info(
          '⏳ Already loading more videos, skipping request',
          name: 'LatestVideosProvider',
          category: LogCategory.system,
        );
        return state.value ?? [];
      }

      if (loadMore) {
        _isLoadingMore = true;
      }

      Log.info(
        '📡 Fetching ${loadMore
            ? "more"
            : isRefresh
            ? "refreshed"
            : "latest"} videos from relay...',
        name: 'LatestVideosProvider',
        category: LogCategory.system,
      );

      final nostrService = ref.read(nostrServiceProvider);
      final videoEventService = ref.read(videoEventServiceProvider);

      // Cancel existing subscription if any
      await _subscription?.cancel();

      // Create filter for latest videos
      Filter filter;

      if (loadMore && _oldestTimestamp != null) {
        // Load older videos
        filter = Filter(
          kinds: [NIP71VideoKinds.addressableShortVideo], // Kind 34236 only
          until:
              _oldestTimestamp! - 1, // Get videos older than the oldest we have
          limit: 200, // Get 200 more videos
        );

        Log.debug(
          '🔍 Loading more: kind=34236, until=${DateTime.fromMillisecondsSinceEpoch(_oldestTimestamp! * 1000).toIso8601String()}, limit=200',
          name: 'LatestVideosProvider',
          category: LogCategory.system,
        );
      } else {
        // Initial load or refresh - just get the latest videos, no time limit
        filter = Filter(
          kinds: [NIP71VideoKinds.addressableShortVideo], // Kind 34236 only
          limit: 500, // Get up to 500 latest videos
        );

        Log.debug(
          '🔍 Filter: kind=34236, limit=500 (no time restrictions)',
          name: 'LatestVideosProvider',
          category: LogCategory.system,
        );
      }

      // Subscribe to events
      final eventStream = nostrService.subscribeToEvents(filters: [filter]);

      final newVideos = <VideoEvent>[];

      var receivedCount = 0;
      var hasReceivedInitialBatch = false;
      final completer = Completer<void>();

      // Listen to the stream and process events immediately
      _subscription = eventStream.listen(
        (event) {
          try {
            if (event.kind == NIP71VideoKinds.addressableShortVideo &&
                !_loadedVideoIds.contains(event.id)) {
              _loadedVideoIds.add(event.id);
              final video = VideoEvent.fromNostrEvent(event);
              newVideos.add(video);
              receivedCount++;

              // Track oldest timestamp for pagination
              if (_oldestTimestamp == null ||
                  video.createdAt < _oldestTimestamp!) {
                _oldestTimestamp = video.createdAt;
              }

              // Also add to video service cache
              videoEventService.addVideoEvent(video);

              Log.verbose(
                '📹 Found video $receivedCount: ${video.title ?? video.id}',
                name: 'LatestVideosProvider',
                category: LogCategory.system,
              );

              // Update UI immediately with every video for progressive loading
              _updateStateWithVideos(newVideos, loadMore, isRefresh);

              // Log progress periodically
              if (receivedCount % 10 == 0 || receivedCount <= 5) {
                Log.info(
                  '📊 Progress: Received $receivedCount videos, UI updated',
                  name: 'LatestVideosProvider',
                  category: LogCategory.system,
                );
              }

              // Mark that we've received initial content - complete early for better UX
              if (!hasReceivedInitialBatch && receivedCount >= 5) {
                hasReceivedInitialBatch = true;
                Log.info(
                  '🚀 Got initial batch of $receivedCount videos, continuing to stream in background...',
                  name: 'LatestVideosProvider',
                  category: LogCategory.system,
                );

                // Complete the operation early so UI can show content immediately
                if (!completer.isCompleted) {
                  completer.complete();
                }
              }
            }
          } catch (e) {
            Log.error(
              'Failed to parse video event: $e',
              name: 'LatestVideosProvider',
              category: LogCategory.system,
            );
          }
        },
        onError: (error) {
          Log.error(
            'Stream error: $error',
            name: 'LatestVideosProvider',
            category: LogCategory.system,
          );
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () {
          Log.info(
            '✅ Stream completed. Total ${newVideos.length} videos received',
            name: 'LatestVideosProvider',
            category: LogCategory.system,
          );
          // Stream ended - just complete if not already done
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: false, // Keep listening even if there's an error
      );

      // Wait for initial batch or reasonable timeout, but don't block the UI
      final timeout = loadMore ? 3 : 5; // Shorter timeouts for better UX
      await Future.any([
        completer.future,
        Future.delayed(Duration(seconds: timeout)),
      ]);

      // Let the stream continue in the background to collect more videos
      // We don't cancel immediately anymore - let it continue streaming
      if (receivedCount > 0) {
        Log.info(
          '⚡ Early return with ${newVideos.length} videos for immediate UI update. Stream continues in background.',
          name: 'LatestVideosProvider',
          category: LogCategory.system,
        );
      } else {
        Log.info(
          '⏱️ Timeout reached with ${newVideos.length} videos after $timeout seconds',
          name: 'LatestVideosProvider',
          category: LogCategory.system,
        );
        // Cancel subscription if we got nothing after timeout
        await _subscription?.cancel();
        _subscription = null;
      }

      return state.value ?? [];
    } catch (e, stack) {
      Log.error(
        '❌ Failed to fetch latest videos: $e',
        name: 'LatestVideosProvider',
        category: LogCategory.system,
      );
      Log.error(
        'Stack: $stack',
        name: 'LatestVideosProvider',
        category: LogCategory.system,
      );

      // Return existing videos on error
      if (state.hasValue) {
        return state.value!;
      }
      return [];
    } finally {
      if (loadMore) {
        _isLoadingMore = false;
      }
    }
  }

  void _updateStateWithVideos(
    List<VideoEvent> newVideos,
    bool loadMore,
    bool isRefresh,
  ) {
    try {
      // Combine with existing videos if loading more
      List<VideoEvent> allVideos;
      if (loadMore && state.hasValue) {
        allVideos = [...state.value!, ...newVideos];
      } else if (isRefresh && state.hasValue) {
        // For refresh, prepend new videos to existing ones
        allVideos = [
          ...newVideos,
          ...state.value!.where((v) => !newVideos.any((nv) => nv.id == v.id)),
        ];
      } else {
        allVideos = newVideos;
      }

      // Sort by creation time (newest first)
      allVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Remove duplicates while preserving order
      final uniqueVideos = <String, VideoEvent>{};
      for (final video in allVideos) {
        uniqueVideos[video.id] = video;
      }
      allVideos = uniqueVideos.values.toList();

      Log.info(
        '✅ State update: ${allVideos.length} total videos (was ${state.value?.length ?? 0})',
        name: 'LatestVideosProvider',
        category: LogCategory.system,
      );

      state = AsyncData(allVideos);
    } catch (e) {
      Log.error(
        'Failed to update state: $e',
        name: 'LatestVideosProvider',
        category: LogCategory.system,
      );
    }
  }

  /// Manually refresh the latest videos
  Future<void> refresh() async {
    Log.info(
      '🔄 Manual refresh requested',
      name: 'LatestVideosProvider',
      category: LogCategory.system,
    );
    await _fetchLatestVideos();
  }

  /// Load more (older) videos for pagination
  Future<void> loadMore() async {
    if (_isLoadingMore) {
      Log.info(
        '⏳ Already loading more videos',
        name: 'LatestVideosProvider',
        category: LogCategory.system,
      );
      return;
    }

    if (!state.hasValue || state.value!.isEmpty) {
      Log.info(
        '⚠️ No videos to paginate from',
        name: 'LatestVideosProvider',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      '📥 Loading more videos...',
      name: 'LatestVideosProvider',
      category: LogCategory.system,
    );
    await _fetchLatestVideos(loadMore: true);
  }

  /// Check if more videos are being loaded
  bool get isLoadingMore => _isLoadingMore;
}
