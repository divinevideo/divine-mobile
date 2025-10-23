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
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_events_providers.g.dart';

/// Provider for NostrService instance (Video Events specific)
@riverpod
INostrService videoEventsNostrService(Ref ref) {
  throw UnimplementedError(
      'VideoEventsNostrService must be overridden in ProviderScope');
}

/// Provider for SubscriptionManager instance (Video Events specific)
@riverpod
SubscriptionManager videoEventsSubscriptionManager(Ref ref) {
  throw UnimplementedError(
      'VideoEventsSubscriptionManager must be overridden in ProviderScope');
}

/// Stream provider for video events from Nostr
@Riverpod(keepAlive: false)
class VideoEvents extends _$VideoEvents {
  StreamController<List<VideoEvent>>? _controller;
  Timer? _debounceTimer;
  List<VideoEvent>? _pendingEvents;
  bool _isSubscribed = false;
  bool get _canEmit => _controller != null && !(_controller!.isClosed);

  @override
  Stream<List<VideoEvent>> build() {
    // Create stream controller first
    _controller = StreamController<List<VideoEvent>>.broadcast();

    // Get services and gate states
    final videoEventService = ref.watch(videoEventServiceProvider);
    final isAppReady = ref.watch(appReadyProvider);
    final isTabActive = ref.watch(isDiscoveryTabActiveProvider);
    final seenVideosState = ref.watch(seenVideosProvider);

    Log.info(
      'VideoEvents: Provider built (appReady: $isAppReady, tabActive: $isTabActive, cached: ${videoEventService.discoveryVideos.length})',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Register cleanup handler ONCE at the top
    ref.onDispose(() {
      Log.debug('VideoEvents: Disposing provider, cleaning up resources',
          name: 'VideoEventsProvider', category: LogCategory.video);
      _debounceTimer?.cancel();
      videoEventService.removeListener(_onVideoEventServiceChange);
      _controller?.close();
      _controller = null;
    });

    // Setup listeners to react to gate changes
    _setupGateListeners(videoEventService, seenVideosState);

    // Start subscription if ready, otherwise emit empty
    if (isAppReady && isTabActive) {
      _startSubscription(videoEventService, seenVideosState);
    } else {
      Log.info(
        'VideoEvents: Not ready - returning empty (will retry when gates flip)',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      Future.microtask(() {
        if (_canEmit) {
          _controller!.add(<VideoEvent>[]);
        }
      });
    }

    return _controller!.stream;
  }

  /// Setup listeners on gate providers to start/stop subscription
  void _setupGateListeners(VideoEventService service, SeenVideosState seenState) {
    Log.debug('🎧 VideoEvents: Setting up gate listeners...',
        name: 'VideoEventsProvider', category: LogCategory.video);

    // Listen to app ready state changes
    ref.listen<bool>(appReadyProvider, (prev, next) {
      Log.debug('🎧 VideoEvents: appReady listener fired! prev=$prev, next=$next',
          name: 'VideoEventsProvider', category: LogCategory.video);
      final tabActive = ref.read(isDiscoveryTabActiveProvider);
      if (next && tabActive) {
        Log.debug('VideoEvents: App ready gate flipped true - starting subscription',
            name: 'VideoEventsProvider', category: LogCategory.video);
        _startSubscription(service, seenState);
      }
      if (!next) {
        Log.debug('VideoEvents: App ready gate flipped false - cleaning up',
            name: 'VideoEventsProvider', category: LogCategory.video);
        _stopSubscription(service);
      }
    });

    // Listen to tab active state changes
    ref.listen<bool>(isDiscoveryTabActiveProvider, (prev, next) {
      Log.debug('🎧 VideoEvents: tabActive listener fired! prev=$prev, next=$next',
          name: 'VideoEventsProvider', category: LogCategory.video);
      final appReady = ref.read(appReadyProvider);
      if (next && appReady) {
        Log.debug('VideoEvents: Tab active gate flipped true - starting subscription',
            name: 'VideoEventsProvider', category: LogCategory.video);
        _startSubscription(service, seenState);
      }
      if (!next) {
        Log.debug('VideoEvents: Tab active gate flipped false - cleaning up',
            name: 'VideoEventsProvider', category: LogCategory.video);
        _stopSubscription(service);
      }
    });

    Log.debug('🎧 VideoEvents: Gate listeners installed!',
        name: 'VideoEventsProvider', category: LogCategory.video);
  }

  /// Start subscription and emit initial events
  void _startSubscription(VideoEventService service, SeenVideosState seenState) {
    Log.debug('VideoEvents: _startSubscription called (subscribed: $_isSubscribed)',
        name: 'VideoEventsProvider', category: LogCategory.video);

    // Always ensure listener is attached - remove first for idempotency
    // This prevents duplicate listeners and ensures clean state
    service.removeListener(_onVideoEventServiceChange);
    service.addListener(_onVideoEventServiceChange);
    Log.info('VideoEvents: Listener attached to service ${service.hashCode}, hasListeners=${service.hasListeners}',
        name: 'VideoEventsProvider', category: LogCategory.video);

    // Subscribe to discovery videos if not already subscribed
    if (!_isSubscribed) {
      Log.info('VideoEvents: Starting discovery subscription',
          name: 'VideoEventsProvider', category: LogCategory.video);
      service.subscribeToDiscovery(limit: 100);
      _isSubscribed = true;
    }

    // Always emit current events if available
    final currentEvents = List<VideoEvent>.from(service.discoveryVideos);
    final reordered = _reorderBySeen(currentEvents, seenState);

    Log.debug('VideoEvents: Emitting ${reordered.length} current events',
        name: 'VideoEventsProvider', category: LogCategory.video);

    Future.microtask(() {
      if (_canEmit) {
        _controller!.add(reordered);
        Log.info(
          'VideoEvents: ✅ Emitted ${reordered.length} events to stream',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
      }
    });
  }

  /// Stop subscription and remove listeners
  void _stopSubscription(VideoEventService service) {
    Log.info('VideoEvents: Stopping discovery subscription',
        name: 'VideoEventsProvider', category: LogCategory.video);

    // Always remove listener (idempotent - safe to call even if not attached)
    service.removeListener(_onVideoEventServiceChange);
    _isSubscribed = false;
    // Don't unsubscribe from service - keep videos cached
  }

  /// Listener callback for service changes
  void _onVideoEventServiceChange() {
    final service = ref.read(videoEventServiceProvider);
    final seenState = ref.read(seenVideosProvider);
    final newEvents = List<VideoEvent>.from(service.discoveryVideos);
    final reordered = _reorderBySeen(newEvents, seenState);

    Log.debug(
      '🔔 VideoEvents: Listener fired! Service has ${newEvents.length} discovery videos',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Store pending events for debounced emission
    _pendingEvents = reordered;

    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Create a new debounce timer to batch updates
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingEvents != null && _canEmit) {
        Log.debug(
          '📺 VideoEvents: Batched update - ${_pendingEvents!.length} discovery videos',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
        _controller!.add(_pendingEvents!);
        _pendingEvents = null;
      }
    });
  }

  /// Reorder events to show unseen first
  List<VideoEvent> _reorderBySeen(List<VideoEvent> events, SeenVideosState seenState) {
    final unseen = <VideoEvent>[];
    final seen = <VideoEvent>[];

    for (final video in events) {
      if (seenState.seenVideoIds.contains(video.id)) {
        seen.add(video);
      } else {
        unseen.add(video);
      }
    }

    return [...unseen, ...seen];
  }


  /// Start discovery subscription when Explore tab is visible
  void startDiscoverySubscription() {
    final isExploreActive = ref.read(isExploreTabActiveProvider);
    if (!isExploreActive) {
      Log.debug('VideoEvents: Ignoring discovery start; Explore inactive',
          name: 'VideoEventsProvider', category: LogCategory.video);
      return;
    }
    final videoEventService = ref.read(videoEventServiceProvider);
    // Avoid noisy re-requests if already subscribed
    if (videoEventService.isSubscribed(SubscriptionType.discovery)) {
      Log.debug('VideoEvents: Discovery already active; skipping start',
          name: 'VideoEventsProvider', category: LogCategory.video);
      return;
    }

    Log.info(
      'VideoEvents: Starting discovery subscription on demand',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Subscribe to discovery videos using dedicated subscription type
    // NostrService now handles deduplication automatically
    videoEventService.subscribeToDiscovery(limit: 100);
  }

  /// Load more historical events
  Future<void> loadMoreEvents() async {
    final videoEventService = ref.read(videoEventServiceProvider);

    // Delegate to VideoEventService with proper subscription type for discovery
    await videoEventService.loadMoreEvents(SubscriptionType.discovery,
        limit: 50);

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
