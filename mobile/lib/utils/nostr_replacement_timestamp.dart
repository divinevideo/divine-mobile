// ABOUTME: Computes monotonic created_at values for replaceable Nostr events.
// ABOUTME: Keeps kind 34236 edits relay-replaceable while preserving published_at.

import 'package:models/models.dart';
import 'package:nostr_sdk/utils/nostr_timestamp.dart';

/// Returns the next `created_at` to use when replacing [previousEvent].
///
/// NIP-01 replacement is based on the raw event `created_at`, not NIP-71's
/// stable `published_at` tag. [VideoEvent.createdAt] intentionally prefers
/// `published_at` for app display/feed ordering, so replacement publishes must
/// use [VideoEvent.nostrCreatedAt] instead.
int nextReplacementCreatedAt(VideoEvent previousEvent) =>
    nextReplacementCreatedAtAfter(previousEvent.nostrCreatedAt);

/// Returns the next `created_at` to use when replacing a raw event stamped
/// [previousCreatedAt].
int nextReplacementCreatedAtAfter(int previousCreatedAt) {
  final now = NostrTimestamp.now();
  final nextAfterPrevious = previousCreatedAt + 1;
  return now > nextAfterPrevious ? now : nextAfterPrevious;
}
