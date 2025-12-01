// ABOUTME: Comprehensive cache for ALL of the current user's own Nostr events
// ABOUTME: Stores every event the user creates/publishes for instant access and offline availability

import 'package:hive_ce/hive.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for aggressively caching ALL of the current user's own events
/// This ensures the user's own data is always instantly available
class PersonalEventCacheService {
  static const String _boxName = 'personal_events';
  static const String _metadataBoxName = 'personal_events_metadata';

  Box<Map<String, dynamic>>? _eventsBox;
  Box<Map<String, dynamic>>? _metadataBox;
  bool _isInitialized = false;
  String? _currentUserPubkey;

  /// Check if the cache service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the personal event cache
  Future<void> initialize(String userPubkey) async {
    if (_isInitialized && _currentUserPubkey == userPubkey) return;

    try {
      _currentUserPubkey = userPubkey;

      // Try to open the events box
      _eventsBox = await Hive.openBox<Map<String, dynamic>>(_boxName);

      // Open the metadata box for indexing
      _metadataBox = await Hive.openBox<Map<String, dynamic>>(_metadataBoxName);

      _isInitialized = true;

      Log.info(
        'PersonalEventCacheService initialized for $userPubkey with ${_eventsBox!.length} cached events',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );

      // Log cache statistics by kind
      _logCacheStatistics();
    } catch (e) {
      Log.error(
        'Failed to initialize PersonalEventCacheService: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );

      // Try to recover by deleting corrupted boxes
      try {
        Log.warning(
          'Attempting to recover from corrupted cache by deleting boxes',
          name: 'PersonalEventCache',
          category: LogCategory.storage,
        );

        await Hive.deleteBoxFromDisk(_boxName);
        await Hive.deleteBoxFromDisk(_metadataBoxName);

        // Retry opening after deletion
        _eventsBox = await Hive.openBox<Map<String, dynamic>>(_boxName);
        _metadataBox = await Hive.openBox<Map<String, dynamic>>(
          _metadataBoxName,
        );

        _isInitialized = true;

        Log.info(
          'Successfully recovered PersonalEventCacheService after corruption',
          name: 'PersonalEventCache',
          category: LogCategory.storage,
        );
      } catch (recoveryError) {
        Log.error(
          'Failed to recover from corrupted cache: $recoveryError',
          name: 'PersonalEventCache',
          category: LogCategory.storage,
        );
        rethrow;
      }
    }
  }

  /// Cache a user's own event (any kind)
  void cacheUserEvent(Event event) {
    if (!_isInitialized || _eventsBox == null || _metadataBox == null) {
      Log.warning(
        'PersonalEventCache not initialized, cannot cache event',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
      return;
    }

    // Only cache events from the current user
    if (event.pubkey != _currentUserPubkey) {
      return;
    }

    try {
      // Store the full event data
      final eventData = {
        'id': event.id,
        'pubkey': event.pubkey,
        'created_at': event.createdAt,
        'kind': event.kind,
        'tags': event.tags.map((tag) => tag.toList()).toList(),
        'content': event.content,
        'sig': event.sig,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

      _eventsBox!.put(event.id, eventData);

      // Update metadata for quick queries
      final kindKey = 'kind_${event.kind}';
      final kindEvents = _metadataBox!.get(
        kindKey,
        defaultValue: <String, dynamic>{},
      )!;
      kindEvents[event.id] = {
        'created_at': event.createdAt,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };
      _metadataBox!.put(kindKey, kindEvents);

      Log.debug(
        '💾 Cached personal event: ${event.id} (kind ${event.kind})',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Failed to cache personal event ${event.id}: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
    }
  }

  /// Get all cached events of a specific kind
  List<Event> getEventsByKind(int kind) {
    if (!_isInitialized || _eventsBox == null || _metadataBox == null) {
      return [];
    }

    try {
      final kindKey = 'kind_$kind';
      final kindEvents = _metadataBox!.get(
        kindKey,
        defaultValue: <String, dynamic>{},
      )!;

      final events = <Event>[];
      for (final eventId in kindEvents.keys) {
        final eventData = _eventsBox!.get(eventId);
        if (eventData != null) {
          final event = _eventDataToEvent(eventData);
          if (event != null) {
            events.add(event);
          }
        }
      }

      // Sort by creation time (newest first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      Log.debug(
        '📋 Retrieved ${events.length} cached events of kind $kind',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );

      return events;
    } catch (e) {
      Log.error(
        'Failed to get events by kind $kind: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
      return [];
    }
  }

  /// Get all cached events
  List<Event> getAllEvents() {
    if (!_isInitialized || _eventsBox == null) {
      return [];
    }

    try {
      final events = <Event>[];
      for (final eventData in _eventsBox!.values) {
        final event = _eventDataToEvent(eventData);
        if (event != null) {
          events.add(event);
        }
      }

      // Sort by creation time (newest first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      Log.debug(
        '📋 Retrieved ${events.length} total cached personal events',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );

      return events;
    } catch (e) {
      Log.error(
        'Failed to get all personal events: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
      return [];
    }
  }

  /// Get a specific cached event by ID
  Event? getEventById(String eventId) {
    if (!_isInitialized || _eventsBox == null) {
      return null;
    }

    try {
      final eventData = _eventsBox!.get(eventId);
      if (eventData != null) {
        return _eventDataToEvent(eventData);
      }
    } catch (e) {
      Log.error(
        'Failed to get event by ID $eventId: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
    }

    return null;
  }

  /// Check if an event is cached
  bool hasEvent(String eventId) {
    if (!_isInitialized || _eventsBox == null) {
      return false;
    }
    return _eventsBox!.containsKey(eventId);
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    if (!_isInitialized || _eventsBox == null || _metadataBox == null) {
      return {'error': 'not_initialized'};
    }

    final stats = <String, dynamic>{
      'total_events': _eventsBox!.length,
      'by_kind': <String, int>{},
      'user_pubkey': _currentUserPubkey,
    };

    // Count events by kind
    for (final kindKey in _metadataBox!.keys) {
      if (kindKey.startsWith('kind_')) {
        final kind = kindKey.substring(5);
        final kindEvents = _metadataBox!.get(
          kindKey,
          defaultValue: <String, dynamic>{},
        )!;
        stats['by_kind'][kind] = kindEvents.length;
      }
    }

    return stats;
  }

  /// Log cache statistics for debugging
  void _logCacheStatistics() {
    final stats = getCacheStats();
    Log.info(
      '📊 Personal Event Cache Statistics:',
      name: 'PersonalEventCache',
      category: LogCategory.storage,
    );
    Log.info(
      '  - Total events: ${stats['total_events']}',
      name: 'PersonalEventCache',
      category: LogCategory.storage,
    );
    Log.info(
      '  - User: ${stats['user_pubkey']}',
      name: 'PersonalEventCache',
      category: LogCategory.storage,
    );

    final byKind = stats['by_kind'] as Map<String, int>;
    if (byKind.isNotEmpty) {
      Log.info(
        '  - By kind:',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
      for (final entry in byKind.entries) {
        final kindName = _getKindName(int.tryParse(entry.key) ?? 0);
        Log.info(
          '    Kind ${entry.key} ($kindName): ${entry.value}',
          name: 'PersonalEventCache',
          category: LogCategory.storage,
        );
      }
    }
  }

  /// Convert stored event data back to Event object
  Event? _eventDataToEvent(Map<String, dynamic> eventData) {
    try {
      final event = Event(
        eventData['pubkey'] as String,
        eventData['kind'] as int,
        (eventData['tags'] as List<dynamic>)
            .map(
              (tag) => (tag as List<dynamic>)
                  .map((item) => item.toString())
                  .toList(),
            )
            .toList(),
        eventData['content'] as String,
        createdAt: eventData['created_at'] as int,
      );

      // Manually set the id and signature since these are not constructor parameters
      event.id = eventData['id'] as String;
      event.sig = eventData['sig'] as String;

      return event;
    } catch (e) {
      Log.error(
        'Failed to convert event data to Event: $e',
        name: 'PersonalEventCache',
        category: LogCategory.storage,
      );
      return null;
    }
  }

  /// Get human-readable name for event kind
  String _getKindName(int kind) {
    switch (kind) {
      case 0:
        return 'Profile';
      case 1:
        return 'Text Note';
      case 3:
        return 'Contact List';
      case 6:
        return 'Repost';
      case 7:
        return 'Reaction/Like';
      case 22:
        return 'Video';
      case 30000:
        return 'Follow Set';
      case 5:
        return 'Deletion';
      default:
        return 'Unknown';
    }
  }

  /// Clear all cached events (for testing or cleanup)
  Future<void> clearCache() async {
    if (!_isInitialized || _eventsBox == null || _metadataBox == null) {
      return;
    }

    try {
      await _eventsBox!.clear();
      await _metadataBox!.clear();

      Log.info(
        '🧹 Cleared all personal event cache',
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

  /// Dispose of the cache service
  void dispose() {
    _eventsBox?.close();
    _metadataBox?.close();
    _isInitialized = false;
    _currentUserPubkey = null;

    Log.debug(
      '📱 PersonalEventCacheService disposed',
      name: 'PersonalEventCache',
      category: LogCategory.storage,
    );
  }
}
