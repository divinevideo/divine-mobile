// ABOUTME: Routes incoming Nostr events to appropriate database tables
// ABOUTME: All events go to NostrEvents table, kind-specific processing extracts to denormalized tables

import 'dart:async';
import 'dart:collection';

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

const eventRouterBatchFlushThreshold = 50;

enum EventIngestionPriority { visible, normal, background }

class EventRouterConfig {
  const EventRouterConfig({
    this.flushDelay = const Duration(milliseconds: 50),
    this.maxBatchSize = eventRouterBatchFlushThreshold,
    this.autoStart = true,
    this.maxQueueDepth,
  });

  final Duration flushDelay;
  final int maxBatchSize;
  final bool autoStart;

  /// Hard cap on the total number of queued events across all priorities.
  ///
  /// When null (the default) the queues are unbounded — every existing caller
  /// is unaffected. When set, [EventRouter.handleEvent] drops the oldest
  /// low-priority events (background, then normal, then visible only if it
  /// alone exceeds the cap) once the total exceeds this depth.
  final int? maxQueueDepth;
}

typedef EventRouterYield = Future<void> Function();

Future<void> _defaultYieldToEventLoop() => Future<void>.delayed(Duration.zero);

/// Routes incoming Nostr events to appropriate database tables.
///
/// UI surfaces update from in-memory feed state before this persistence path
/// completes. This router must therefore be best-effort and cooperative:
/// bounded batches, priority queues, and event-loop yields keep background
/// ingestion from starving Flutter frames.
class EventRouter {
  EventRouter(
    this._db, {
    EventRouterConfig config = const EventRouterConfig(),
    EventRouterYield yieldToEventLoop = _defaultYieldToEventLoop,
  }) : _config = config,
       _yieldToEventLoop = yieldToEventLoop;

  final AppDatabase _db;
  final EventRouterConfig _config;
  final EventRouterYield _yieldToEventLoop;
  final Queue<Event> _visibleQueue = Queue<Event>();
  final Queue<Event> _normalQueue = Queue<Event>();
  final Queue<Event> _backgroundQueue = Queue<Event>();
  Timer? _batchTimer;
  bool _isProcessingBatch = false;
  bool _disposed = false;

  /// Access to database for cache-first queries.
  AppDatabase get db => _db;

  void handleEvent(
    Event event, {
    EventIngestionPriority priority = EventIngestionPriority.normal,
  }) {
    // After dispose the database may be closing; a late relay callback must
    // not re-arm a drain that would run SQLite against a closed connection.
    if (_disposed) return;
    _queueFor(priority).add(event);
    _enforceQueueBound();
    if (_config.autoStart) {
      _scheduleProcessing(immediate: _queuedLength >= _config.maxBatchSize);
    }
  }

  /// Drops the oldest low-priority events until the total queued count is back
  /// within [EventRouterConfig.maxQueueDepth]. No-op when the cap is null.
  ///
  /// Background is shed first, then normal; visible is only dropped when it
  /// alone exceeds the cap, so the on-screen feed keeps persisting.
  void _enforceQueueBound() {
    final maxQueueDepth = _config.maxQueueDepth;
    if (maxQueueDepth == null) return;

    var dropped = 0;
    while (_queuedLength > maxQueueDepth) {
      final Queue<Event> queue;
      if (_backgroundQueue.isNotEmpty) {
        queue = _backgroundQueue;
      } else if (_normalQueue.isNotEmpty) {
        queue = _normalQueue;
      } else {
        queue = _visibleQueue;
      }
      queue.removeFirst();
      dropped++;
    }

    if (dropped > 0) {
      _droppedEventCount += dropped;
      Log.warning(
        'Dropped $dropped events to bound ingestion queue at $maxQueueDepth',
        name: 'EventRouter',
        category: LogCategory.system,
      );
    }
  }

  Queue<Event> _queueFor(EventIngestionPriority priority) {
    switch (priority) {
      case EventIngestionPriority.visible:
        return _visibleQueue;
      case EventIngestionPriority.normal:
        return _normalQueue;
      case EventIngestionPriority.background:
        return _backgroundQueue;
    }
  }

  int get _queuedLength =>
      _visibleQueue.length + _normalQueue.length + _backgroundQueue.length;

  /// Total number of events currently queued across all priorities.
  ///
  /// Exposed as an always-on gauge for memory instrumentation; a growing
  /// value points at ingestion outrunning persistence.
  int get queuedLength => _queuedLength;

  int _droppedEventCount = 0;

  /// Number of events dropped by [shedLowPriority] over this router's
  /// lifetime.
  int get droppedEventCount => _droppedEventCount;

  /// Drops every queued event whose id is in [eventIds], across all
  /// priorities. Returns the number of events removed.
  ///
  /// Callers use this when an event has just been tombstoned: a write queued
  /// before the tombstone existed would otherwise flush *after* the row was
  /// deleted and put it straight back. Only pending writes are affected —
  /// rows already flushed must be deleted through the DAO.
  int dropQueuedEvents(Set<String> eventIds) {
    if (_disposed || eventIds.isEmpty) return 0;

    var dropped = 0;
    for (final queue in [_visibleQueue, _normalQueue, _backgroundQueue]) {
      final survivors = queue
          .where((event) => !eventIds.contains(event.id))
          .toList();
      dropped += queue.length - survivors.length;
      queue
        ..clear()
        ..addAll(survivors);
    }
    return dropped;
  }

  /// Drops all queued background- and normal-priority events, preserving the
  /// visible queue so the on-screen feed still persists.
  ///
  /// Called under memory pressure to shed ingestion backlog. Returns the
  /// number of events dropped.
  int shedLowPriority() {
    // Mirror [handleEvent]'s guard: after dispose the queues are cleared and
    // the database may be closing, so there is nothing to shed.
    if (_disposed) return 0;
    final dropped = _backgroundQueue.length + _normalQueue.length;
    _backgroundQueue.clear();
    _normalQueue.clear();
    _droppedEventCount += dropped;
    if (dropped > 0) {
      Log.info(
        'Shed $dropped low-priority events under memory pressure',
        name: 'EventRouter',
        category: LogCategory.system,
      );
    }
    return dropped;
  }

  void _scheduleProcessing({bool immediate = false}) {
    if (_disposed || _isProcessingBatch) return;
    if (immediate || _config.flushDelay == Duration.zero) {
      _batchTimer?.cancel();
      _batchTimer = null;
      unawaited(_processNextBatch());
      return;
    }

    _batchTimer ??= Timer(_config.flushDelay, () {
      _batchTimer = null;
      unawaited(_processNextBatch());
    });
  }

  List<Event> _takeNextBatch() {
    final batch = <Event>[];
    while (batch.length < _config.maxBatchSize && _queuedLength > 0) {
      final queue = _visibleQueue.isNotEmpty
          ? _visibleQueue
          : _normalQueue.isNotEmpty
          ? _normalQueue
          : _backgroundQueue;
      batch.add(queue.removeFirst());
    }
    return batch;
  }

  Future<void> _processNextBatch({bool continueProcessing = true}) async {
    if (_disposed || _isProcessingBatch || _queuedLength == 0) return;

    _isProcessingBatch = true;
    try {
      final batch = _takeNextBatch();
      await _persistBatch(batch);
    } finally {
      _isProcessingBatch = false;
    }

    if (continueProcessing && _queuedLength > 0) {
      await _yieldToEventLoop();
      _scheduleProcessing(immediate: true);
    }
  }

  Future<void> _persistBatch(List<Event> batch) async {
    if (batch.isEmpty) return;

    try {
      Log.debug(
        'Processing batch of ${batch.length} events',
        name: 'EventRouter',
        category: LogCategory.system,
      );

      await _persistRawEvents(batch);

      final routeBatch = _coalesceReplaceableRouting(batch);
      await _db.transaction(() async {
        for (final event in routeBatch) {
          await _routeEvent(event);
        }
      });

      Log.verbose(
        'Completed batch of ${batch.length} events',
        name: 'EventRouter',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to process event batch: $e',
        name: 'EventRouter',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Persists raw events, splitting by replaceable semantics.
  ///
  /// Addressable / parameterized-replaceable events (e.g. kind 34236 videos)
  /// go through [upsertEventsBatch] so superseded coordinates are deleted —
  /// the cache-first feed reads these raw with a SQL `LIMIT`, so stale rows
  /// would otherwise consume slots and shrink the unique-result count. Every
  /// other kind keeps all raw rows by id via [cacheEventsBatch]; its current
  /// value (if any) lives in a denormalized table (e.g. kind 0 → UserProfiles).
  Future<void> _persistRawEvents(List<Event> batch) async {
    final addressable = <Event>[];
    final raw = <Event>[];
    for (final event in batch) {
      if (EventKind.isParameterizedReplaceable(event.kind)) {
        addressable.add(event);
      } else {
        raw.add(event);
      }
    }

    if (raw.isNotEmpty) {
      await _db.nostrEventsDao.cacheEventsBatch(raw);
    }
    if (addressable.isNotEmpty) {
      await _db.nostrEventsDao.upsertEventsBatch(addressable);
    }
  }

  List<Event> _coalesceReplaceableRouting(List<Event> batch) {
    final routeBatch = <Event>[];
    final latestProfileByPubkey = <String, Event>{};

    for (final event in batch) {
      if (event.kind == 0) {
        final existing = latestProfileByPubkey[event.pubkey];
        if (existing == null || event.createdAt >= existing.createdAt) {
          latestProfileByPubkey[event.pubkey] = event;
        }
      } else {
        routeBatch.add(event);
      }
    }

    routeBatch.addAll(latestProfileByPubkey.values);
    return routeBatch;
  }

  /// Extracts denormalized rows for kinds that have a dedicated table.
  ///
  /// Only kind 0 (profiles) is denormalized, into UserProfiles. The other
  /// routed kinds — 3 (contacts, NIP-02), 6 (repost, NIP-18), 7 (reactions,
  /// NIP-25), and 34236 (video, NIP-71) — are intentionally raw-cached only
  /// via [_persistRawEvents] and NOT denormalized here.
  ///
  /// No feed-aggregate table exists for them; their surfaced data comes from
  /// other paths: like/reaction counts from the relay (NIP-45) and
  /// LikesRepository, the user's own likes from PersonalReactions, follower
  /// counts from the backend (ProfileStats), and VideoMetrics parsed from the
  /// video event's own tags during raw caching. The cases stay listed
  /// explicitly so this "unsupported by design" choice is visible rather than
  /// an implicit default.
  Future<void> _routeEvent(Event event) async {
    switch (event.kind) {
      case 0:
        await _handleProfileEvent(event);
      case 3:
        break;
      case 7:
        break;
      case 6:
      case NIP71VideoKinds.addressableShortVideo:
        break;
      default:
        break;
    }
  }

  /// Denormalizes a kind 0 into `user_profiles`.
  ///
  /// This is a direct DAO write — it does not pass through `ProfileRepository`.
  /// The NIP-62 vanish guard therefore lives in `UserProfilesDao.upsertProfile`
  /// rather than here, so a relay still serving a deleted account's kind 0
  /// cannot re-create its row.
  Future<void> _handleProfileEvent(Event event) async {
    try {
      final profile = UserProfile.fromNostrEvent(event);
      await _db.userProfilesDao.upsertProfile(profile);

      Log.verbose(
        'Extracted profile for ${pubkeyForLogs(profile.pubkey)} from event ${event.id}',
        name: 'EventRouter',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to parse profile event ${event.id}: $e',
        name: 'EventRouter',
        category: LogCategory.system,
        stackTrace: stackTrace,
      );
    }
  }

  void dispose() {
    _disposed = true;
    _batchTimer?.cancel();
    _batchTimer = null;
    _visibleQueue.clear();
    _normalQueue.clear();
    _backgroundQueue.clear();
  }

  @visibleForTesting
  Future<void> drainOneBatchForTesting() =>
      _processNextBatch(continueProcessing: false);

  @visibleForTesting
  Future<void> drainForTesting() async {
    while (_queuedLength > 0 || _isProcessingBatch) {
      if (_isProcessingBatch) {
        await _yieldToEventLoop();
      } else {
        await _processNextBatch(continueProcessing: false);
        if (_queuedLength > 0) {
          await _yieldToEventLoop();
        }
      }
    }
  }
}
