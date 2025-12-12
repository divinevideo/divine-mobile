// ABOUTME: Abstract base class providing shared event broadcasting patterns for social event services
// ABOUTME: Handles event creation, signing, broadcasting, and caching with consistent error handling

import 'package:nostr_sdk/event.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';

/// Base class for services that broadcast and manage social events (reactions, reposts, etc)
/// Provides shared patterns for event lifecycle: create → sign → broadcast → cache
abstract class SocialEventServiceBase {
  /// Nostr service for broadcasting events to relays
  NostrClient get nostrService;

  /// Auth service for creating and signing events
  AuthService get authService;

  /// Optional cache for storing user's own events locally
  PersonalEventCacheService? get personalEventCache;

  /// Broadcasts event and caches it locally
  ///
  /// Throws Exception if broadcast fails
  Future<String> broadcastAndCacheEvent(Event event) async {
    // Cache immediately before broadcasting (optimistic update)
    personalEventCache?.cacheUserEvent(event);

    // Broadcast to relays
    final result = await nostrService.broadcast(event);

    if (!result.isSuccessful) {
      final errors = result.errors.values.join(', ');
      throw Exception('Failed to broadcast event: $errors');
    }

    return event.id;
  }

  /// Creates, signs, broadcasts, and caches an event in one atomic operation
  ///
  /// Throws Exception if creation, signing, or broadcast fails
  Future<String> createSignBroadcastAndCache({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async {
    final event = await authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
    );

    if (event == null) {
      throw Exception('Failed to create and sign event');
    }

    return await broadcastAndCacheEvent(event);
  }

  /// Publishes a deletion event (Kind 5) for the target event
  ///
  /// Throws Exception if deletion event creation or broadcast fails
  Future<void> publishDeletionEvent(String targetEventId) async {
    await createSignBroadcastAndCache(
      kind: 5,
      content: 'Deleted',
      tags: [
        ['e', targetEventId],
      ],
    );
  }
}
