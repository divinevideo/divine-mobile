// ABOUTME: Routes incoming Nostr events to appropriate database tables
// ABOUTME: All events go to NostrEvents table, kind-specific processing extracts to denormalized tables

import 'dart:async';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Routes incoming Nostr events to appropriate database tables
///
/// All events go to NostrEvents table (single source of truth)
/// Kind-specific processing extracts data to denormalized tables
/// Uses batching to avoid database lock contention
class EventRouter {
  EventRouter(this._db);

  final AppDatabase _db;
  final List<Event> _eventQueue = [];
  Timer? _batchTimer;
  bool _isProcessingBatch = false;

  /// Access to database for cache-first queries
  AppDatabase get db => _db;

  /// Handle incoming event from relay
  ///
  /// Queues event for batch processing to avoid database locks
  Future<void> handleEvent(Event event) async {
    // Add to batch queue
    _eventQueue.add(event);

    // Schedule batch processing if not already scheduled
    _batchTimer ??= Timer(const Duration(milliseconds: 50), _processBatch);

    // If queue is large, process immediately
    if (_eventQueue.length >= 50 && !_isProcessingBatch) {
      _batchTimer?.cancel();
      _batchTimer = null;
      await _processBatch();
    }
  }

  /// Process queued events in a single batch
  Future<void> _processBatch() async {
    if (_isProcessingBatch || _eventQueue.isEmpty) return;

    _isProcessingBatch = true;
    _batchTimer = null;

    try {
      final batch = List<Event>.from(_eventQueue);
      _eventQueue.clear();

      Log.debug(
        'Processing batch of ${batch.length} events',
        name: 'EventRouter',
        category: LogCategory.system,
      );

      // Batch insert to nostr_events table
      await _db.nostrEventsDao.upsertEventsBatch(batch);

      // Process kind-specific routing for each event
      for (final event in batch) {
        await _routeEvent(event);
      }

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
    } finally {
      _isProcessingBatch = false;
    }
  }

  /// Route event to specialized tables based on kind
  Future<void> _routeEvent(Event event) async {
    switch (event.kind) {
      case 0: // Profile metadata
        await _handleProfileEvent(event);
        break;

      case 3: // Contacts
        // TODO: Future implementation
        break;

      case 7: // Reactions
        // TODO: Future implementation
        break;

      case 6: // Reposts
      case 34236: // Videos
        // Already in events table, queryable via DAO
        break;

      default:
        // Still in events table, just not processed further
        break;
    }
  }

  /// Handle kind 0 (profile) event
  ///
  /// Extracts profile data and stores in UserProfiles table
  /// Handles malformed JSON gracefully (UserProfile.fromNostrEvent has fallback)
  Future<void> _handleProfileEvent(Event event) async {
    try {
      final profile = UserProfile.fromNostrEvent(event);
      await _db.userProfilesDao.upsertProfile(profile);

      Log.verbose(
        'Extracted profile for ${profile.pubkey} from event ${event.id}',
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
      // Don't rethrow - we already stored the raw event
    }
  }
}
