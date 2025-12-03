// ABOUTME: Pure helper functions for notification event processing
// ABOUTME: Extracted from NotificationServiceEnhanced to reduce duplication and improve testability

import 'package:nostr_sdk/event.dart';
import 'package:models/models.dart';

/// Extracts the video event ID from the first 'e' tag in a Nostr event
/// Returns null if no 'e' tag exists or if the tag has no value
String? extractVideoEventId(Event event) {
  for (final tag in event.tags) {
    if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
      return tag[1];
    }
  }
  return null;
}

/// Resolves the actor name from a user profile with fallback priority:
/// 1. name field
/// 2. displayName field
/// 3. nip05 username (part before @)
/// 4. "Unknown user" as final fallback
String resolveActorName(UserProfile? profile) {
  if (profile == null) {
    return 'Unknown user';
  }

  // Try name first
  if (profile.name != null) {
    return profile.name!;
  }

  // Try displayName second
  if (profile.displayName != null) {
    return profile.displayName!;
  }

  // Try nip05 username third
  if (profile.nip05 != null) {
    final nip05Parts = profile.nip05!.split('@');
    return nip05Parts.first;
  }

  // Final fallback
  return 'Unknown user';
}
