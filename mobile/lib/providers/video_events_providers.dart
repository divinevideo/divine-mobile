// ABOUTME: Riverpod stream provider for managing Nostr video event subscriptions
// ABOUTME: Handles real-time video feed updates for discovery mode

import 'dart:async';

import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_events_providers.g.dart';

/// Stream provider for video events from Nostr
@Riverpod(keepAlive: true) // Keep alive to prevent state loss on tab switches
class VideoEvents extends _$VideoEvents {
  // BehaviorSubject replays last value to late subscribers, fixing race condition
  // where PopularVideosTab subscribes AFTER initial emission
  BehaviorSubject<List<VideoEvent>>? _subject;
  Timer? _debounceTimer;
  List<VideoEvent>? _pendingEvents;

  /// The list [_subject] currently holds, or `null` when it holds none.
  ///
  /// Derived from the subject rather than mirrored in a field. `build()`
  /// installs a fresh [BehaviorSubject] on every rebuild while the notifier
  /// instance — and therefore any field on it — survives, so a mirrored copy
  /// outlives the subject it described. The equality guards below would then
  /// suppress the first emission into the replacement subject, which never
  /// receives a value and leaves the provider in `AsyncLoading` for good.
  /// A fresh subject reports `null` here, so that emission always lands.
  List<VideoEvent>? get _lastEmittedEvents => _subject?.valueOrNull;
  bool get _canEmit => _subject != null && !_subject!.isClosed;

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
      _subject!.add(currentVideos);
    }

    // Notify listeners that buffer was cleared
    ref.read(bufferedVideoCountProvider.notifier).state = 0;
  }

  @override
  Stream<List<VideoEvent>> build() {
    // BehaviorSubject replays last value to late subscribers (unlike broadcast streams)
    // This fixes the race condition where UI subscribes after initial data emission
    _subject = BehaviorSubject<List<VideoEvent>>();

    // Get services and gate states
    final videoEventService = ref.watch(videoEventServiceProvider);
    ref.watch(blocklistVersionProvider);
    ref.watch(divineHostFilterVersionProvider);
    ref.watch(contentFilterVersionProvider);
    final isAppReady = ref.watch(appReadyProvider);
    final isTabActive = ref.watch(isDiscoveryTabActiveProvider);

    Log.debug(
      'VideoEvents: rebuilding (appReady: $isAppReady, tabActive: $isTabActive, cached: ${videoEventService.discoveryVideos.length})',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Extra debug logging to understand state
    Log.debug(
      'VideoEvents: appReady=$isAppReady',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.debug(
      'VideoEvents: discoveryTabActive=$isTabActive',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.debug(
      'VideoEvents: cached discoveryVideos=${videoEventService.discoveryVideos.length}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.debug(
      'VideoEvents: service instance=${videoEventService.hashCode}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    final unregisterVideoUpdate = videoEventService.addVideoUpdateListener((
      updated,
    ) {
      _onVideoEventServiceChange();
    });

    // Register cleanup handler ONCE at the top
    ref.onDispose(() {
      Log.debug(
        'VideoEvents: disposing provider',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      Log.debug(
        'VideoEvents: cached videos before dispose=${videoEventService.discoveryVideos.length}',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      _debounceTimer?.cancel();
      videoEventService.removeListener(_onVideoEventServiceChange);
      unregisterVideoUpdate(); // Clean up video update callback
      _subject?.close();
      _subject = null;
    });

    // Setup listeners to react to gate changes
    _setupGateListeners(videoEventService);

    // ALWAYS start subscription to load videos (database-first + Nostr)
    // This works even when gates are false - it will load from database
    // and skip Nostr subscription until gates flip true
    _startSubscription(videoEventService);

    return _subject!.stream;
  }

  /// Setup listeners on gate providers to start/stop subscription
  void _setupGateListeners(VideoEventService service) {
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
        _startSubscription(service);
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
        _startSubscription(service);
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
  void _startSubscription(VideoEventService service) {
    // Use service's isSubscribed() to check actual subscription state
    // This prevents the bug where we skip retrying after a failed initial subscription
    final isAlreadySubscribed = service.isSubscribed(
      SubscriptionType.discovery,
    );
    Log.debug(
      'VideoEvents: starting subscription (serviceSubscribed: $isAlreadySubscribed)',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.debug(
      'VideoEvents: discoveryVideos=${service.discoveryVideos.length}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Always ensure listener is attached - remove first for idempotency
    // This prevents duplicate listeners and ensures clean state
    service.removeListener(_onVideoEventServiceChange);
    service.addListener(_onVideoEventServiceChange);
    Log.debug(
      'VideoEvents: listener attached to service ${service.hashCode}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    // Subscribe to discovery videos if not already subscribed in the service
    // We check the service's state directly to avoid the race condition where
    // subscription fails (NostrService not ready) but we incorrectly mark as subscribed
    if (!isAlreadySubscribed) {
      Log.debug(
        'VideoEvents: starting new discovery subscription (NIP-50 sort:hot)',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      // Use NIP-50 search for trending/popular discovery (otherstuff-relay)
      unawaited(
        service
            .subscribeToDiscovery(
              nip50Sort:
                  NIP50SortMode.hot, // Recent events with high engagement
            )
            .catchError((Object error, StackTrace stackTrace) {
              if (error is! RelayNotReadyException) {
                Error.throwWithStackTrace(error, stackTrace);
              }
              Log.warning(
                'VideoEvents: Discovery subscription deferred until relay connection is ready',
                name: 'VideoEventsProvider',
                category: LogCategory.video,
              );
            }),
      );
      // NOTE: We don't set a local _isSubscribed flag here because we rely on
      // service.isSubscribed() which accurately tracks actual subscription state
    } else {
      Log.debug(
        'VideoEvents: already subscribed in service, skipping subscribe call',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
    }

    // Always emit current events if available (no reordering - preserve insertion order)
    // Create defensive copy, applying the shared feed filters.
    final currentEvents = service.filterVideoList(service.discoveryVideos);

    Log.debug(
      'VideoEvents: about to emit ${currentEvents.length} events (canEmit: $_canEmit)',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.debug(
      'VideoEvents: subject holds no value: ${_lastEmittedEvents == null}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );
    Log.debug(
      'VideoEvents: lists equal: ${_listEquals(currentEvents, _lastEmittedEvents)}',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    Future.microtask(() {
      Log.debug(
        'VideoEvents: emitting on microtask (canEmit: $_canEmit)',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
      if (_canEmit && !_listEquals(currentEvents, _lastEmittedEvents)) {
        // The subject keeps the reference, not a copy, so identical() checks
        // downstream still hold.
        _subject!.add(currentEvents);
        Log.debug(
          'VideoEvents: emitted ${currentEvents.length} events',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
      } else {
        Log.debug(
          'VideoEvents: skipped emission (canEmit: $_canEmit, listsEqual: ${_listEquals(currentEvents, _lastEmittedEvents)})',
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
    // Filter for platform support and shared hidden-video policy.
    // Create defensive copy ONLY when contents changed
    _pendingEvents = service.filterVideoList(
      newEvents.where((v) => v.isSupportedOnCurrentPlatform).toList(),
    );

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
          _subject!.add(_pendingEvents!);
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
