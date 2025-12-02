// ABOUTME: Universal mixin for loading all published events from embedded relay
// ABOUTME: Provides cached access to user's own published events for all list services

import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr;

// Import Event from nostr_sdk
typedef Event = nostr.Event;

/// Mixin that provides universal access to user's published events from embedded relay
///
/// This mixin fetches ALL events published by the current user from the embedded relay
/// with a single query, then caches them for use by multiple list services (bookmarks,
/// mutes, curated lists, etc.). This is much more efficient than each service making
/// separate queries for specific event kinds.
mixin NostrListServiceMixin {
  // Static cache shared across all services using this mixin
  static List<Event>? _cachedMyEvents;
  static String? _cachedForPubkey;
  static DateTime? _lastCacheTime;

  // Services must provide these dependencies
  INostrService get nostrService;
  AuthService get authService;

  /// Get all events published by the current user from embedded relay
  ///
  /// This method fetches ALL events we've ever published with a single query:
  /// Filter(authors: [ourPubkey])
  ///
  /// Results are cached per pubkey to avoid redundant queries when multiple
  /// services initialize. Cache is invalidated after 5 minutes or when pubkey changes.
  Future<List<Event>> getMyPublishedEvents() async {
    try {
      final ourPubkey = authService.currentPublicKeyHex;
      if (ourPubkey == null) {
        Log.warning(
          'Cannot load published events - user not authenticated',
          name: 'NostrListServiceMixin',
          category: LogCategory.system,
        );
        return [];
      }

      final now = DateTime.now();
      final cacheExpiry = Duration(minutes: 5);

      // Check if we have valid cached data
      if (_cachedMyEvents != null &&
          _cachedForPubkey == ourPubkey &&
          _lastCacheTime != null &&
          now.difference(_lastCacheTime!) < cacheExpiry) {
        Log.debug(
          'Using cached published events: ${_cachedMyEvents!.length} events',
          name: 'NostrListServiceMixin',
          category: LogCategory.system,
        );
        return _cachedMyEvents!;
      }

      Log.info(
        'Fetching all published events from embedded relay for pubkey: ${ourPubkey}...',
        name: 'NostrListServiceMixin',
        category: LogCategory.system,
      );

      // Query embedded relay for ALL our published events
      final filter = nostr.Filter(authors: [ourPubkey]);
      final events = await nostrService.getEvents(filters: [filter]);

      // Cache the results
      _cachedMyEvents = events;
      _cachedForPubkey = ourPubkey;
      _lastCacheTime = now;

      Log.info(
        'Loaded ${events.length} published events from embedded relay',
        name: 'NostrListServiceMixin',
        category: LogCategory.system,
      );

      return events;
    } catch (e) {
      Log.error(
        'Failed to load published events from embedded relay: $e',
        name: 'NostrListServiceMixin',
        category: LogCategory.system,
      );
      return [];
    }
  }

  /// Filter published events by kind
  ///
  /// Helper method to filter the universal event list for specific kinds.
  /// This is more efficient than making separate queries per kind.
  List<Event> filterMyEventsByKind(List<Event> events, List<int> kinds) {
    return events.where((event) => kinds.contains(event.kind)).toList();
  }

  /// Filter published events by kind and d-tag (for parameterized replaceable events)
  ///
  /// For kinds 30000-39999, filters by both kind and d-tag value.
  /// Returns the most recent event for each unique (kind, d-tag) combination.
  Map<String, Event> filterMyParameterizedEvents(
    List<Event> events,
    List<int> kinds,
  ) {
    final Map<String, Event> latestEvents = {};

    for (final event in events) {
      if (!kinds.contains(event.kind)) continue;

      // Find d-tag
      String? dTag;
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'd' && tag.length > 1) {
          dTag = tag[1];
          break;
        }
      }

      // Skip events without d-tag for parameterized replaceable events
      if (dTag == null) continue;

      final key = '${event.kind}:$dTag';
      final existing = latestEvents[key];

      // Keep the most recent event for this (kind, d-tag) combination
      if (existing == null || event.createdAt > existing.createdAt) {
        latestEvents[key] = event;
      }
    }

    return latestEvents;
  }

  /// Clear the event cache
  ///
  /// Call this when user logs out or switches accounts
  static void clearEventCache() {
    _cachedMyEvents = null;
    _cachedForPubkey = null;
    _lastCacheTime = null;
    Log.debug(
      'Cleared published events cache',
      name: 'NostrListServiceMixin',
      category: LogCategory.system,
    );
  }
}
