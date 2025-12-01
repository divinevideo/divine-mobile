// ABOUTME: Riverpod stream provider for managing Nostr video event subscriptions
// ABOUTME: Handles real-time video feed updates for discovery mode

import 'dart:async';

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/state/seen_videos_state.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_events_providers.g.dart';

/// Provider for NostrService instance (Video Events specific)
@riverpod
INostrService videoEventsNostrService(Ref ref) {
  throw UnimplementedError(
    'VideoEventsNostrService must be overridden in ProviderScope',
  );
}

/// Provider for SubscriptionManager instance (Video Events specific)
@riverpod
SubscriptionManager videoEventsSubscriptionManager(Ref ref) {
  throw UnimplementedError(
    'VideoEventsSubscriptionManager must be overridden in ProviderScope',
  );
}

/// Stream provider for video events from Nostr
@Riverpod(keepAlive: true) // Keep alive to prevent state loss on tab switches
class VideoEvents extends _$VideoEvents {
  StreamController<List<VideoEvent>>? _controller;
  Timer? _debounceTimer;
  List<VideoEvent>? _pendingEvents;
  List<VideoEvent>? _lastEmittedEvents;
  bool get _canEmit => _controller != null && !(_controller!.isClosed);

  // Buffer for new videos that arrive while user is browsing
  final List<VideoEvent> _bufferedEvents = [];
  bool _bufferingEnabled = false;

  /// Enable buffering mode - new videos go to buffer instead of auto-inserting
  void enableBuffering() {
    _bufferingEnabled = true;
    Log.info(
      'VideoEvents: Buffering enabled - new videos will be buffered',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
  }

  /// Disable buffering mode - resume auto-inserting new videos
  void disableBuffering() {
    _bufferingEnabled = false;
    Log.info(
      'VideoEvents: Buffering disabled - new videos will auto-insert',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
  }

  /// Get count of buffered videos
  int get bufferedCount => _bufferedEvents.length;

  /// Load all buffered videos into main feed
  void loadBufferedVideos() {
    if (_bufferedEvents.isEmpty) return;

    final service = ref.read(videoEventServiceProvider);
    final currentVideos = List<VideoEvent>.from(service.discoveryVideos);

    // Insert buffered videos at the beginning
    currentVideos.insertAll(0, _bufferedEvents);

    Log.info(
      'VideoEvents: Loading ${_bufferedEvents.length} buffered videos',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    _bufferedEvents.clear();

    // Emit updated list
    if (_canEmit) {
      _controller!.add(currentVideos);
      _lastEmittedEvents = currentVideos;
    }

    // Notify listeners that buffer was cleared
    ref.read(bufferedVideoCountProvider.notifier).state = 0;
  }

  @override
  Stream<List<VideoEvent>> build() {
    // Create stream controller first
    _controller = StreamController<List<VideoEvent>>.broadcast();

    // Get services and gate states
    final videoEventService = ref.watch(videoEventServiceProvider);
    final isAppReady = ref.watch(appReadyProvider);
    final isTabActive = ref.watch(isDiscoveryTabActiveProvider);
    final seenVideosState = ref.watch(seenVideosProvider);

    Log.error(
      '🔥🔥🔥 VideoEvents: Provider REBUILDING (appReady: $isAppReady, tabActive: $isTabActive, cached: ${videoEventService.discoveryVideos.length}) 🔥🔥🔥',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Extra debug logging to understand state
    Log.error(
      '  🔍 appReadyProvider state: $isAppReady',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.error(
      '  🔍 isDiscoveryTabActiveProvider state: $isTabActive',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.error(
      '  🔍 discoveryVideos cached: ${videoEventService.discoveryVideos.length}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.error(
      '  🔍 VideoEventService instance: ${videoEventService.hashCode}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Register cleanup handler ONCE at the top
    ref.onDispose(() {
      Log.error(
        '🔥🔥🔥 VideoEvents: DISPOSING provider 🔥🔥🔥',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      Log.error(
        '  🔍 Cached videos before dispose: ${videoEventService.discoveryVideos.length}',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      _debounceTimer?.cancel();
      videoEventService.removeListener(_onVideoEventServiceChange);
      _controller?.close();
      _controller = null;
    });

    // Setup listeners to react to gate changes
    _setupGateListeners(videoEventService, seenVideosState);

    // ALWAYS start subscription to load videos (database-first + Nostr)
    // This works even when gates are false - it will load from database
    // and skip Nostr subscription until gates flip true
    _startSubscription(videoEventService, seenVideosState);

    return _controller!.stream;
  }

  /// Setup listeners on gate providers to start/stop subscription
  void _setupGateListeners(
    VideoEventService service,
    SeenVideosState seenState,
  ) {
    Log.debug(
      '🎧 VideoEvents: Setting up gate listeners...',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Listen to app ready state changes
    ref.listen<bool>(appReadyProvider, (prev, next) {
      Log.debug(
        '🎧 VideoEvents: appReady listener fired! prev=$prev, next=$next',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      final tabActive = ref.read(isDiscoveryTabActiveProvider);
      if (next && tabActive) {
        Log.debug(
          'VideoEvents: App ready gate flipped true - starting subscription',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
        _startSubscription(service, seenState);
      }
      if (!next) {
        Log.debug(
          'VideoEvents: App ready gate flipped false - cleaning up',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
        _stopSubscription(service);
      }
    });

    // Listen to tab active state changes
    ref.listen<bool>(isDiscoveryTabActiveProvider, (prev, next) {
      Log.debug(
        '🎧 VideoEvents: tabActive listener fired! prev=$prev, next=$next',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      final appReady = ref.read(appReadyProvider);
      if (next && appReady) {
        Log.debug(
          'VideoEvents: Tab active gate flipped true - starting subscription',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
        _startSubscription(service, seenState);
      }
      if (!next) {
        Log.debug(
          'VideoEvents: Tab active gate flipped false - cleaning up',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
        _stopSubscription(service);
      }
    });

    Log.debug(
      '🎧 VideoEvents: Gate listeners installed!',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
  }

  /// Start subscription and emit initial events
  void _startSubscription(
    VideoEventService service,
    SeenVideosState seenState,
  ) {
    // Use service's isSubscribed() to check actual subscription state
    // This prevents the bug where we skip retrying after a failed initial subscription
    final isAlreadySubscribed = service.isSubscribed(
      SubscriptionType.discovery,
    );
    Log.error(
      '🔥🔥🔥 VideoEvents: _startSubscription called (serviceSubscribed: $isAlreadySubscribed) 🔥🔥🔥',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.error(
      '  🔍 VideoEventService.discoveryVideos.length: ${service.discoveryVideos.length}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Always ensure listener is attached - remove first for idempotency
    // This prevents duplicate listeners and ensures clean state
    service.removeListener(_onVideoEventServiceChange);
    service.addListener(_onVideoEventServiceChange);
    Log.error(
      '  🔍 Listener attached to service ${service.hashCode}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Subscribe to discovery videos if not already subscribed in the service
    // We check the service's state directly to avoid the race condition where
    // subscription fails (NostrService not ready) but we incorrectly mark as subscribed
    if (!isAlreadySubscribed) {
      Log.error(
        '  🔍 Starting NEW discovery subscription with NIP-50 search (sort:hot)',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      // Use NIP-50 search for trending/popular discovery (otherstuff-relay)
      service.subscribeToDiscovery(
        limit: 100,
        nip50Sort: NIP50SortMode.hot, // Recent events with high engagement
      );
      // NOTE: We don't set a local _isSubscribed flag here because we rely on
      // service.isSubscribed() which accurately tracks actual subscription state
    } else {
      Log.error(
        '  🔍 Already subscribed in service - skipping subscription call',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
    }

    // Always emit current events if available (no reordering - preserve insertion order)
    // Create defensive copy to prevent service mutations from affecting emitted state
    final currentEvents = List<VideoEvent>.from(service.discoveryVideos);

    Log.error(
      '  🔍 About to emit ${currentEvents.length} current events (canEmit: $_canEmit)',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.error(
      '  🔍 _lastEmittedEvents is null: ${_lastEmittedEvents == null}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.error(
      '  🔍 Lists equal: ${_listEquals(currentEvents, _lastEmittedEvents)}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    Future.microtask(() {
      Log.error(
        '  🔍 Inside Future.microtask - canEmit: $_canEmit',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      if (_canEmit && !_listEquals(currentEvents, _lastEmittedEvents)) {
        _controller!.add(currentEvents);
        // Store reference (not copy) to enable identical() checks downstream
        _lastEmittedEvents = currentEvents;
        Log.error(
          '  ✅ EMITTED ${currentEvents.length} events to stream!',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
      } else {
        Log.error(
          '  ❌ SKIPPED emission - canEmit: $_canEmit, listsEqual: ${_listEquals(currentEvents, _lastEmittedEvents)}',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
      }
    });
  }

  /// Stop subscription and remove listeners
  void _stopSubscription(VideoEventService service) {
    Log.info(
      'VideoEvents: Stopping discovery subscription',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Always remove listener (idempotent - safe to call even if not attached)
    service.removeListener(_onVideoEventServiceChange);
    // Don't unsubscribe from service - keep videos cached
    // The service tracks its own subscription state via isSubscribed()
  }

  /// Listener callback for service changes
  void _onVideoEventServiceChange() {
    final service = ref.read(videoEventServiceProvider);
    final newEvents = service.discoveryVideos; // Use direct reference (no copy)

    // Only process if the list has actually changed
    if (_listEquals(newEvents, _lastEmittedEvents)) {
      return; // No change, skip emission
    }

    // If buffering is enabled, find new videos and add to buffer
    if (_bufferingEnabled) {
      final lastEmittedIds = _lastEmittedEvents?.map((e) => e.id).toSet() ?? {};
      final newVideoEvents = newEvents
          .where((e) => !lastEmittedIds.contains(e.id))
          .toList();

      if (newVideoEvents.isNotEmpty) {
        _bufferedEvents.addAll(newVideoEvents);
        Log.info(
          '📦 VideoEvents: Buffered ${newVideoEvents.length} new videos (total buffered: ${_bufferedEvents.length})',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );

        // Update buffered count provider
        ref.read(bufferedVideoCountProvider.notifier).state =
            _bufferedEvents.length;
      }
      return; // Don't emit updates while buffering
    }

    // Store pending events for debounced emission (no reordering - preserve order)
    // Filter for platform support (WebM not supported on iOS/macOS)
    // Create defensive copy ONLY when contents changed
    _pendingEvents = newEvents
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();

    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Create a new debounce timer to batch updates
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingEvents != null && _canEmit) {
        // Double-check the list has changed before emitting
        if (!_listEquals(_pendingEvents, _lastEmittedEvents)) {
          Log.debug(
            '📺 VideoEvents: Batched update - ${_pendingEvents!.length} discovery videos',
            name: 'VideoEventsProvider',
            category: LogCategory.video,
          );
          _controller!.add(_pendingEvents!);
          // Store reference (not copy) to enable identical() checks downstream
          _lastEmittedEvents = _pendingEvents;
        }
        _pendingEvents = null;
      }
    });
  }

  /// Check if two video lists are equal (same videos in same order)
  bool _listEquals(List<VideoEvent>? a, List<VideoEvent>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Start discovery subscription when Explore tab is visible
  void startDiscoverySubscription() {
    final isExploreActive = ref.read(isExploreTabActiveProvider);
    if (!isExploreActive) {
      Log.debug(
        'VideoEvents: Ignoring discovery start; Explore inactive',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      return;
    }
    final videoEventService = ref.read(videoEventServiceProvider);
    // Avoid noisy re-requests if already subscribed
    if (videoEventService.isSubscribed(SubscriptionType.discovery)) {
      Log.debug(
        'VideoEvents: Discovery already active; skipping start',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      'VideoEvents: Starting discovery subscription on demand with NIP-50 search (sort:hot)',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Subscribe to discovery videos using NIP-50 search for trending/popular
    // NostrService now handles deduplication automatically
    videoEventService.subscribeToDiscovery(
      limit: 100,
      nip50Sort: NIP50SortMode.hot, // Recent events with high engagement
    );
  }

  /// Load more historical events
  Future<void> loadMoreEvents() async {
    final videoEventService = ref.read(videoEventServiceProvider);

    // Delegate to VideoEventService with proper subscription type for discovery
    await videoEventService.loadMoreEvents(
      SubscriptionType.discovery,
      limit: 50,
    );

    // The periodic timer will automatically pick up the new events
    // and emit them through the stream
  }

  /// Clear all events and refresh
  Future<void> refresh() async {
    final videoEventService = ref.read(videoEventServiceProvider);
    await videoEventService.refreshVideoFeed();
    // The stream will automatically emit the refreshed events
  }
}

/// Provider to check if video events are loading
@riverpod
bool videoEventsLoading(Ref ref) => ref.watch(videoEventsProvider).isLoading;

/// Provider to get video event count
@riverpod
int videoEventCount(Ref ref) {
  final asyncState = ref.watch(videoEventsProvider);
  return asyncState.hasValue ? (asyncState.value?.length ?? 0) : 0;
}

/// State provider for buffered video count
@riverpod
class BufferedVideoCount extends _$BufferedVideoCount {
  @override
  int build() => 0;
}
