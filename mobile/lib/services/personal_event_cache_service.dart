// ABOUTME: Cache for the current user's own Nostr events, backed by Drift.
// ABOUTME: Serves reads from a bounded in-memory mirror of personal_events.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

/// Caches the signed-in user's own events so they are instantly available.
///
/// Reads are synchronous — `sourceOriginalVideoTags` is a plain function and
/// `GetCachedEventsByKindCallback` is a synchronous typedef in the
/// `follow_repository` package — so the service keeps an in-memory mirror of
/// the owner's rows and writes through to [PersonalEventsDao].
///
/// The mirror is what the Hive implementation had too: `Hive.openBox` is
/// non-lazy, so the whole box was resident. The difference is that the mirror
/// is now **bounded**, because the DAO collapses replaceable kinds to one row
/// per `(pubkey, kind)` and trims the rest to a per-owner cap. Before #6986 a
/// 500-follow contact list was 42.5 KiB and every follow, unfollow, block,
/// unblock and automatic re-broadcast appended another one that was never
/// evicted.
class PersonalEventCacheService {
  PersonalEventCacheService({required PersonalEventsDao dao}) : _dao = dao;

  static const int _maxPendingEventWrites = 100;

  final PersonalEventsDao _dao;

  /// The owner's events, keyed by event id. Empty until [initialize].
  final Map<String, Event> _events = <String, Event>{};

  bool _isInitialized = false;
  bool _isDisposed = false;
  int _initializationToken = 0;
  String? _currentUserPubkey;
  final List<Event> _pendingEventWrites = <Event>[];

  /// Check if the cache service is initialized
  bool get isInitialized => _isInitialized;

  /// Reset the active user session without deleting the stored rows.
  ///
  /// Signing out hides the cache rather than clearing it, so signing back in
  /// restores it. Only [clearCache] and cache recovery delete anything.
  void resetCurrentUser() {
    _initializationToken++;
    _isInitialized = false;
    _currentUserPubkey = null;
    _events.clear();
    _pendingEventWrites.clear();
  }

  /// Initialize the personal event cache for [userPubkey].
  Future<void> initialize(String userPubkey) async {
    _isDisposed = false;
    final initializationToken = ++_initializationToken;

    if (_isInitialized && _currentUserPubkey == userPubkey) {
      await _flushPendingEventWrites();
      return;
    }

    try {
      _currentUserPubkey = userPubkey;

      final stored = await _dao.getAllForOwner(userPubkey);

      if (!_isCurrentInitialization(initializationToken, userPubkey)) {
        return;
      }

      _events
        ..clear()
        ..addEntries(stored.map((event) => MapEntry(event.id, event)));

      _isInitialized = true;

      await _flushPendingEventWrites();

      Log.info(
        'PersonalEventCacheService initialized for '
        '${pubkeyForLogs(userPubkey)} with ${_events.length} cached events',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize PersonalEventCacheService: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
      rethrow;
    }
  }

  /// Cache a user's own event (any kind).
  ///
  /// Fire-and-forget: the in-memory mirror is updated synchronously so a read
  /// immediately after this call sees the event, while the durable write runs
  /// in the background. A failed write is logged and never surfaces to the
  /// caller — publishing must not fail because a cache write did.
  void cacheUserEvent(Event event) {
    if (_isDisposed) {
      return;
    }

    if (!_isInitialized) {
      _queuePendingEventWrite(event);
      return;
    }

    unawaited(_cacheInitializedUserEvent(event));
  }

  bool _isCurrentInitialization(int token, String userPubkey) {
    return !_isDisposed &&
        token == _initializationToken &&
        _currentUserPubkey == userPubkey;
  }

  void _queuePendingEventWrite(Event event) {
    final currentUserPubkey = _currentUserPubkey;
    if (currentUserPubkey != null && event.pubkey != currentUserPubkey) {
      return;
    }

    _pendingEventWrites.removeWhere(
      (pendingEvent) => pendingEvent.id == event.id,
    );
    if (_pendingEventWrites.length >= _maxPendingEventWrites) {
      _pendingEventWrites.removeAt(0);
    }
    _pendingEventWrites.add(event);

    Log.warning(
      'PersonalEventCache not initialized, queued event for later caching',
      name: 'PersonalEventCache',
      category: LogCategory.storage,
    );
  }

  Future<void> _flushPendingEventWrites() async {
    if (_pendingEventWrites.isEmpty) {
      return;
    }

    final pendingEventWrites = List<Event>.from(_pendingEventWrites);
    _pendingEventWrites.clear();

    var cachedCount = 0;
    for (final event in pendingEventWrites) {
      if (await _cacheInitializedUserEvent(event)) {
        cachedCount++;
      }
    }

    if (cachedCount > 0) {
      Log.info(
        'Cached $cachedCount pending personal event(s) after initialization',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
    }
  }

  Future<bool> _cacheInitializedUserEvent(Event event) async {
    // Only cache events from the current user
    if (event.pubkey != _currentUserPubkey) {
      return false;
    }

    // Mirror the DAO's retention rule so a synchronous read taken before the
    // durable write completes agrees with what the database will hold.
    _applyRetentionToMirror(event);

    try {
      await _dao.upsertPersonalEvent(event);
      Log.debug(
        '💾 Cached personal event: ${event.id} (kind ${event.kind})',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
      return true;
    } catch (e) {
      Log.error(
        'Failed to cache personal event ${event.id}: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
      return false;
    }
  }

  void _applyRetentionToMirror(Event event) {
    if (PersonalEventRetention.forKind(event.kind) ==
        PersonalEventRetention.collapsing) {
      _events.removeWhere(
        (_, cached) => cached.kind == event.kind && cached.id != event.id,
      );
      _events[event.id] = event;
      return;
    }

    _events[event.id] = event;

    final durable =
        _events.values
            .where(
              (cached) =>
                  PersonalEventRetention.forKind(cached.kind) ==
                  PersonalEventRetention.durable,
            )
            .toList()
          ..sort((a, b) {
            final byCreatedAt = b.createdAt.compareTo(a.createdAt);
            return byCreatedAt != 0 ? byCreatedAt : b.id.compareTo(a.id);
          });

    for (final evicted in durable.skip(maxDurablePersonalEventsPerOwner)) {
      _events.remove(evicted.id);
    }
  }

  /// Get all cached events of a specific kind, newest first.
  List<Event> getEventsByKind(int kind) {
    if (!_isInitialized) {
      return [];
    }

    final events = _events.values.where((event) => event.kind == kind).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Log.debug(
      '📋 Retrieved ${events.length} cached events of kind $kind',
      name: 'PersonalEventCache',
      category: LogCategory.storage,
    );

    return events;
  }

  /// Get all cached events, newest first.
  List<Event> getAllEvents() {
    if (!_isInitialized) {
      return [];
    }

    return _events.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get a specific cached event by ID.
  Event? getEventById(String eventId) {
    if (!_isInitialized) {
      return null;
    }
    return _events[eventId];
  }

  /// Check if an event is cached.
  bool hasEvent(String eventId) {
    if (!_isInitialized) {
      return false;
    }
    return _events.containsKey(eventId);
  }

  /// Clear the current user's cached events.
  Future<void> clearCache() async {
    _pendingEventWrites.clear();

    final currentUserPubkey = _currentUserPubkey;
    if (!_isInitialized || currentUserPubkey == null) {
      return;
    }

    _events.clear();

    try {
      // Scoped to the owner: the table is shared across accounts on one
      // device, and the Hive implementation this replaced cleared every
      // account's rows here.
      await _dao.deleteAllForOwner(currentUserPubkey);

      Log.info(
        '🧹 Cleared personal event cache for ${pubkeyForLogs(currentUserPubkey)}',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Failed to clear personal event cache: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
    }
  }

  /// Dispose of the cache service.
  void dispose() {
    _isDisposed = true;
    _initializationToken++;
    _isInitialized = false;
    _currentUserPubkey = null;
    _events.clear();
    _pendingEventWrites.clear();

    Log.debug(
      '📱 PersonalEventCacheService disposed',
      name: 'PersonalEventCache',
      category: LogCategory.storage,
    );
  }
}
