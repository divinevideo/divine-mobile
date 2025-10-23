// ABOUTME: Routes incoming Nostr events to appropriate database tables
// ABOUTME: All events go to NostrEvents table, kind-specific processing extracts to denormalized tables

import 'package:nostr_sdk/event.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Routes incoming Nostr events to appropriate database tables
///
/// All events go to NostrEvents table (single source of truth)
/// Kind-specific processing extracts data to denormalized tables
class EventRouter {
  EventRouter(this._db);

  final AppDatabase _db;

  /// Access to database for cache-first queries
  AppDatabase get db => _db;

  /// Handle incoming event from relay
  ///
  /// Step 1: Insert ALL events to nostr_events table
  /// Step 2: Route to specialized tables based on kind
  Future<void> handleEvent(Event event) async {
    // Step 1: Insert ALL events to nostr_events table
    await _insertToEventsTable(event);

    // Step 2: Route to specialized tables based on kind
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

    Log.verbose(
      'Routed event ${event.id} (kind ${event.kind}) to database',
      name: 'EventRouter',
      category: LogCategory.system,
    );
  }

  /// Insert event to nostr_events table
  ///
  /// Uses INSERT OR REPLACE for upsert behavior
  Future<void> _insertToEventsTable(Event event) async {
    await _db.nostrEventsDao.upsertEvent(event);
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
