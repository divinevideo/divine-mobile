// ABOUTME: Riverpod provider for managing user-specific video fetching and grid display
// ABOUTME: Fetches video events by author with pagination and caching

import 'dart:async';

import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/constants/nip71_migration.dart';

part 'profile_videos_provider.g.dart';

/// State for profile videos provider
class ProfileVideosState {
  const ProfileVideosState({
    required this.videos,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.error,
    required this.lastTimestamp,
  });

  final List<VideoEvent> videos;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int? lastTimestamp;

  ProfileVideosState copyWith({
    List<VideoEvent>? videos,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? lastTimestamp,
  }) => ProfileVideosState(
    videos: videos ?? this.videos,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: error,
    lastTimestamp: lastTimestamp ?? this.lastTimestamp,
  );

  static const initial = ProfileVideosState(
    videos: [],
    isLoading: false,
    isLoadingMore: false,
    hasMore: true,
    error: null,
    lastTimestamp: null,
  );

  bool get hasVideos => videos.isNotEmpty;
  bool get hasError => error != null;
  int get videoCount => videos.length;
}

// Cache for different users' videos
final Map<String, List<VideoEvent>> _profileVideosCache = {};
final Map<String, DateTime> _profileVideosCacheTimestamps = {};
final Map<String, bool> _profileVideosHasMoreCache = {};
const Duration _profileVideosCacheExpiry = Duration(minutes: 10);

// Pagination settings
const int _profileVideosPageSize = 200;

/// Get cached videos if available and not expired
List<VideoEvent>? _getCachedProfileVideos(String pubkey) {
  final videos = _profileVideosCache[pubkey];
  final timestamp = _profileVideosCacheTimestamps[pubkey];

  if (videos != null && timestamp != null) {
    final age = DateTime.now().difference(timestamp);
    if (age < _profileVideosCacheExpiry) {
      Log.debug(
        '📱 Using cached videos for ${pubkey} (age: ${age.inMinutes}min)',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
      return videos;
    } else {
      Log.debug(
        '⏰ Video cache expired for ${pubkey} (age: ${age.inMinutes}min)',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
      _clearProfileVideosCache(pubkey);
    }
  }

  return null;
}

/// Cache videos for a user
void _cacheProfileVideos(String pubkey, List<VideoEvent> videos, bool hasMore) {
  _profileVideosCache[pubkey] = videos;
  _profileVideosCacheTimestamps[pubkey] = DateTime.now();
  _profileVideosHasMoreCache[pubkey] = hasMore;
  Log.debug(
    '📱 Cached ${videos.length} videos for ${pubkey}',
    name: 'ProfileVideosProvider',
    category: LogCategory.ui,
  );
}

/// Clear cache for a specific user
void _clearProfileVideosCache(String pubkey) {
  _profileVideosCache.remove(pubkey);
  _profileVideosCacheTimestamps.remove(pubkey);
  _profileVideosHasMoreCache.remove(pubkey);
}

/// Clear all cached videos
void clearAllProfileVideosCache() {
  _profileVideosCache.clear();
  _profileVideosCacheTimestamps.clear();
  _profileVideosHasMoreCache.clear();
  Log.debug(
    '📱 Cleared all profile videos cache',
    name: 'ProfileVideosProvider',
    category: LogCategory.ui,
  );
}

/// Notifier for managing profile videos state
/// keepAlive: false allows disposal when profile not visible - prevents ghost video playback
@Riverpod(keepAlive: false)
class ProfileVideosNotifier extends _$ProfileVideosNotifier {
  String? _currentPubkey;
  Completer<void>? _loadingCompleter;

  @override
  ProfileVideosState build() {
    return ProfileVideosState.initial;
  }

  /// Load videos for a specific user with real-time streaming
  Future<void> loadVideosForUser(String pubkey) async {
    Log.debug(
      '🔍 loadVideosForUser called for ${pubkey} | _currentPubkey=${_currentPubkey} | hasVideos=${state.hasVideos} | hasError=${state.hasError} | videos.length=${state.videos.length}',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );

    // Prevent concurrent loads for the same user
    // This is the ONLY early return - allows reload when returning to profile after publishing
    if (_loadingCompleter != null && _currentPubkey == pubkey) {
      Log.debug(
        '⏭️ Early return: already loading for ${pubkey}',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
      return _loadingCompleter!.future;
    }

    _loadingCompleter = Completer<void>();
    _currentPubkey = pubkey;

    // Check cache first
    final cached = _getCachedProfileVideos(pubkey);
    Log.debug(
      '💾 Cache check for ${pubkey}: ${cached?.length ?? 0} videos',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );

    if (cached != null) {
      Log.debug(
        '✅ Using cache: returning ${cached.length} videos for ${pubkey}',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
      // Defer state modification to avoid modifying provider during build
      await Future.microtask(() {
        state = state.copyWith(
          videos: cached,
          isLoading: false,
          hasMore: _profileVideosHasMoreCache[pubkey] ?? true,
          error: null,
        );
      });
      _loadingCompleter!.complete();
      _loadingCompleter = null;
      return;
    }

    Log.debug(
      '🌐 No cache found, starting streaming load for ${pubkey}',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );

    // Defer state modification to avoid modifying provider during build
    await Future.microtask(() {
      state = state.copyWith(
        isLoading: true,
        videos: [],
        error: null,
        hasMore: true,
        lastTimestamp: null,
      );
    });

    try {
      // Use streaming approach for real-time video updates
      await _loadVideosStreaming(pubkey);
      _loadingCompleter!.complete();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      _loadingCompleter!.completeError(e);
    } finally {
      _loadingCompleter = null;
    }
  }

  /// Stream videos with real-time UI updates as they arrive
  Future<void> _loadVideosStreaming(String pubkey) async {
    final nostrService = ref.read(nostrServiceProvider);
    final videoEventService = ref.read(videoEventServiceProvider);

    // First, get any cached videos for immediate display
    final cachedVideos = videoEventService.getVideosByAuthor(pubkey);
    if (cachedVideos.isNotEmpty) {
      Log.info(
        '📱 Found ${cachedVideos.length} cached videos for ${pubkey} in VideoEventService',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );

      // Filter for platform support (WebM not supported on iOS/macOS)
      // and sort cached videos
      final sortedCached = cachedVideos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList();
      sortedCached.sort(VideoEvent.compareByLoopsThenTime);

      state = state.copyWith(
        videos: sortedCached,
        isLoading:
            false, // Mark as not loading since we're showing cached content
        lastTimestamp: sortedCached.isNotEmpty
            ? sortedCached.last.createdAt
            : null,
      );

      Log.info(
        '✅ Displaying ${cachedVideos.length} cached videos immediately for ${pubkey}',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
      // Continue to relay query to supplement with any missing/new videos
    }

    final filter = Filter(
      authors: [pubkey],
      kinds: [
        ...NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video events
        NIP71VideoKinds.repost, // Include reposts (kind 6)
      ],
      limit: _profileVideosPageSize,
    );

    Log.info(
      '📱 Starting streaming query for videos: authors=[$pubkey], kinds=${[...NIP71VideoKinds.getAllVideoKinds(), NIP71VideoKinds.repost]}, limit=$_profileVideosPageSize',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );

    final completer = Completer<void>();
    // Start with cached videos
    final receivedVideos = <VideoEvent>[...cachedVideos];
    final seenIds = <String>{...cachedVideos.map((v) => v.id)};

    final subscription = nostrService.subscribeToEvents(
      filters: [filter],
      onEose: () {
        Log.info(
          '📱 Streaming EOSE: received ${receivedVideos.length} events for ${pubkey}',
          name: 'ProfileVideosProvider',
          category: LogCategory.ui,
        );
        if (!completer.isCompleted) {
          _finalizeStreamingLoad(pubkey, receivedVideos);
          completer.complete();
        }
      },
    );

    subscription.listen(
      (event) {
        // Process events immediately and update UI progressively
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          // Only add if we haven't seen this video before
          if (!seenIds.contains(videoEvent.id)) {
            receivedVideos.add(videoEvent);
            seenIds.add(videoEvent.id);

            Log.debug(
              '📱 Streaming: received new video event ${videoEvent.id} for ${pubkey}',
              name: 'ProfileVideosProvider',
              category: LogCategory.ui,
            );

            // Update UI state immediately with new video
            _updateUIWithStreamingVideo(videoEvent, receivedVideos);
          } else {
            Log.debug(
              '📱 Streaming: skipping duplicate video event ${videoEvent.id}',
              name: 'ProfileVideosProvider',
              category: LogCategory.ui,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to parse streaming video event: $e',
            name: 'ProfileVideosProvider',
            category: LogCategory.ui,
          );
        }
      },
      onError: (error) {
        Log.error(
          'Error streaming profile videos: $error',
          name: 'ProfileVideosProvider',
          category: LogCategory.ui,
        );
        if (!completer.isCompleted) {
          _finalizeStreamingLoad(pubkey, receivedVideos);
          completer.complete();
        }
      },
      onDone: () {
        Log.info(
          '📱 Streaming query completed: received ${receivedVideos.length} events for ${pubkey}',
          name: 'ProfileVideosProvider',
          category: LogCategory.ui,
        );

        if (!completer.isCompleted) {
          _finalizeStreamingLoad(pubkey, receivedVideos);
          completer.complete();
        }
      },
    );

    // Wait for EOSE/onDone with a 30-second safety timeout
    // Old 3-second timeout was too short and caused empty loads
    // 30 seconds allows relay time to respond while preventing infinite hangs
    try {
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          Log.warning(
            '⏱️ Streaming load timed out after 30s for ${pubkey} with ${receivedVideos.length} videos',
            name: 'ProfileVideosProvider',
            category: LogCategory.ui,
          );
          if (!completer.isCompleted) {
            _finalizeStreamingLoad(pubkey, receivedVideos);
            completer.complete();
          }
        },
      );
    } catch (e) {
      Log.error(
        'Error during streaming load: $e',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
      if (!completer.isCompleted) {
        _finalizeStreamingLoad(pubkey, receivedVideos);
        completer.complete();
      }
    }
  }

  /// Update UI state immediately when each video arrives during streaming
  void _updateUIWithStreamingVideo(
    VideoEvent newVideo,
    List<VideoEvent> allReceived,
  ) {
    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      return;
    }

    // Add the new video to current state, maintaining sort order
    final currentVideos = List<VideoEvent>.from(state.videos);
    currentVideos.add(newVideo);

    // Sort using loops-first policy
    currentVideos.sort(VideoEvent.compareByLoopsThenTime);

    // Update state with progressive loading
    state = state.copyWith(
      videos: currentVideos,
      lastTimestamp: currentVideos.isNotEmpty
          ? currentVideos.last.createdAt
          : null,
    );

    Log.debug(
      '📱 Streaming UI update: now showing ${currentVideos.length} videos',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );
  }

  /// Finalize the streaming load and update cache
  void _finalizeStreamingLoad(String pubkey, List<VideoEvent> allVideos) {
    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      Log.debug(
        '📱 Streaming finalized skipped - provider disposed for ${pubkey}',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
      return;
    }

    // Filter for platform support (WebM not supported on iOS/macOS)
    // and sort using loops-first policy
    final supportedVideos = allVideos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();
    supportedVideos.sort(VideoEvent.compareByLoopsThenTime);

    // Update final state
    state = state.copyWith(
      videos: supportedVideos,
      isLoading: false,
      hasMore: allVideos.length >= _profileVideosPageSize,
      lastTimestamp: allVideos.isNotEmpty ? allVideos.last.createdAt : null,
    );

    // Cache the results
    _cacheProfileVideos(
      pubkey,
      supportedVideos,
      supportedVideos.length >= _profileVideosPageSize,
    );

    Log.info(
      '📱 Streaming finalized: loaded ${supportedVideos.length} videos for ${pubkey} (filtered from ${allVideos.length})',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );
  }

  /// Load more videos (pagination) with streaming updates
  Future<void> loadMoreVideos() async {
    if (_currentPubkey == null ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.lastTimestamp == null) {
      return;
    }

    // Defer state modification to avoid modifying provider during build
    await Future.microtask(() {
      state = state.copyWith(isLoadingMore: true, error: null);
    });

    try {
      await _loadMoreVideosStreaming();
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
      Log.error(
        'Error loading more videos: $e',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
    }
  }

  /// Stream additional videos with real-time UI updates as they arrive
  Future<void> _loadMoreVideosStreaming() async {
    final nostrService = ref.read(nostrServiceProvider);

    final filter = Filter(
      authors: [_currentPubkey!],
      kinds: [
        ...NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video events
        NIP71VideoKinds.repost, // Include reposts (kind 6)
      ],
      until: state.lastTimestamp! - 1, // Load older videos
      limit: _profileVideosPageSize,
    );

    Log.info(
      '📱 Starting streaming load more query for ${_currentPubkey!}: until=${state.lastTimestamp! - 1}, limit=$_profileVideosPageSize',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );

    final completer = Completer<void>();
    final newVideos = <VideoEvent>[];

    final subscription = nostrService.subscribeToEvents(
      filters: [filter],
      onEose: () {
        Log.info(
          '📱 Load more EOSE: received ${newVideos.length} additional events for ${_currentPubkey!}',
          name: 'ProfileVideosProvider',
          category: LogCategory.ui,
        );
        if (!completer.isCompleted) {
          _finalizeLoadMoreStreaming(newVideos);
          completer.complete();
        }
      },
    );

    subscription.listen(
      (event) {
        // Process events immediately and update UI progressively
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          newVideos.add(videoEvent);

          Log.debug(
            '📱 Load more streaming: received video event ${videoEvent.id} for ${_currentPubkey!}',
            name: 'ProfileVideosProvider',
            category: LogCategory.ui,
          );

          // Update UI state immediately with new video
          _updateUIWithAdditionalVideo(videoEvent);
        } catch (e) {
          Log.warning(
            'Failed to parse additional streaming video event: $e',
            name: 'ProfileVideosProvider',
            category: LogCategory.ui,
          );
        }
      },
      onError: (error) {
        Log.error(
          'Error streaming additional videos: $error',
          name: 'ProfileVideosProvider',
          category: LogCategory.ui,
        );
        if (!completer.isCompleted) {
          _finalizeLoadMoreStreaming(newVideos);
          completer.complete();
        }
      },
      onDone: () {
        Log.info(
          '📱 Load more streaming completed: received ${newVideos.length} additional events for ${_currentPubkey!}',
          name: 'ProfileVideosProvider',
          category: LogCategory.ui,
        );

        if (!completer.isCompleted) {
          _finalizeLoadMoreStreaming(newVideos);
          completer.complete();
        }
      },
    );

    // Wait for EOSE/onDone with a 30-second safety timeout
    try {
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          Log.warning(
            '⏱️ Load more timed out after 30s for ${_currentPubkey!} with ${newVideos.length} new videos',
            name: 'ProfileVideosProvider',
            category: LogCategory.ui,
          );
          if (!completer.isCompleted) {
            _finalizeLoadMoreStreaming(newVideos);
            completer.complete();
          }
        },
      );
    } catch (e) {
      Log.error(
        'Error during load more: $e',
        name: 'ProfileVideosProvider',
        category: LogCategory.ui,
      );
      if (!completer.isCompleted) {
        _finalizeLoadMoreStreaming(newVideos);
        completer.complete();
      }
    }
  }

  /// Update UI state immediately when each additional video arrives during load more streaming
  void _updateUIWithAdditionalVideo(VideoEvent newVideo) {
    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      return;
    }

    // Add the new video to current state
    final currentVideos = List<VideoEvent>.from(state.videos);
    currentVideos.add(newVideo);

    // Sort using loops-first policy
    currentVideos.sort(VideoEvent.compareByLoopsThenTime);

    // Update state with progressive loading
    state = state.copyWith(
      videos: currentVideos,
      lastTimestamp: currentVideos.isNotEmpty
          ? currentVideos.last.createdAt
          : null,
    );

    Log.debug(
      '📱 Load more streaming UI update: now showing ${currentVideos.length} videos',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );
  }

  /// Finalize the load more streaming and update cache
  void _finalizeLoadMoreStreaming(List<VideoEvent> newVideos) {
    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      return;
    }

    final hasMore = newVideos.length >= _profileVideosPageSize;

    // Update final state
    state = state.copyWith(isLoadingMore: false, hasMore: hasMore);

    // Update cache with current videos
    _cacheProfileVideos(_currentPubkey!, state.videos, hasMore);

    Log.info(
      '📱 Load more streaming finalized: added ${newVideos.length} videos (total: ${state.videos.length})',
      name: 'ProfileVideosProvider',
      category: LogCategory.ui,
    );
  }

  /// Refresh videos by clearing cache and reloading
  Future<void> refreshVideos(String pubkey) async {
    _clearProfileVideosCache(pubkey);
    // Reset state to force reload
    state = state.copyWith(
      videos: [],
      isLoading: false,
      hasMore: true,
      error: null,
    );
    await loadVideosForUser(pubkey);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Add a new video to the current list (for optimistic updates)
  void addVideo(VideoEvent video) {
    if (_currentPubkey != null && video.pubkey == _currentPubkey) {
      final updatedVideos = [video, ...state.videos];
      state = state.copyWith(videos: updatedVideos);

      // Update cache
      _cacheProfileVideos(_currentPubkey!, updatedVideos, state.hasMore);
    }
  }

  /// Remove a video from the current list
  void removeVideo(String videoId) {
    final updatedVideos = state.videos.where((v) => v.id != videoId).toList();
    state = state.copyWith(videos: updatedVideos);

    // Update cache if we have a current pubkey
    if (_currentPubkey != null) {
      _cacheProfileVideos(_currentPubkey!, updatedVideos, state.hasMore);
    }
  }
}
