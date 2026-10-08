// ABOUTME: Reads a bounded snapshot of an account's NIP-51 video-list events.
// ABOUTME: Owns relay subscription cleanup; cache merging stays in the service.

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

/// Relay events paired with whether the subscription completed normally.
final class CuratedListRelaySnapshot {
  /// Captures a read without implying that partial events authorize writes.
  CuratedListRelaySnapshot({
    required List<Event> events,
    required this.completedNormally,
  }) : events = List.unmodifiable(events);

  /// The events received before completion, error, or the timeout.
  final List<Event> events;

  /// False on a timeout or stream error; callers must not backfill from it.
  final bool completedNormally;
}

/// Reads events without retaining list state or authorizing cache mutations.
///
/// The service captures the owner and rechecks its lease after this read.
/// Session retirement therefore cannot turn a completed read into permission
/// to merge another account's rows or publish a stale local cache.
final class CuratedListRelaySnapshotReader {
  /// Uses the same client connection as the owning service.
  const CuratedListRelaySnapshotReader({required NostrClient nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// Cancels the subscription on every exit and retains partial events.
  Future<CuratedListRelaySnapshot> read({
    required String ownerPubkey,
    required Duration timeout,
  }) async {
    StreamSubscription<Event>? relaySubscription;
    Timer? timeoutTimer;
    try {
      final completer = Completer<bool>();
      final receivedEvents = <Event>[];
      final filter = Filter(authors: [ownerPubkey], kinds: [30005]);
      Log.debug(
        '📋 Subscribing with filter: authors=[${pubkeyForLogs(ownerPubkey)}], kinds=[30005]',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      final subscription = _nostrClient.subscribe([filter]);
      timeoutTimer = Timer(timeout, () {
        Log.debug(
          'Relay sync timeout reached, processing received events',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        if (!completer.isCompleted) {
          final activeSubscription = relaySubscription;
          relaySubscription = null;
          unawaited(activeSubscription?.cancel());
          completer.complete(false);
        }
      });
      relaySubscription = subscription.listen(
        (event) {
          receivedEvents.add(event);
          Log.debug(
            'Received list event from relay: ${event.id}',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
        },
        onDone: () {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (Object error) {
          Log.error(
            'Error fetching lists from relay: $error',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
          timeoutTimer?.cancel();
          if (!completer.isCompleted) completer.complete(false);
        },
        cancelOnError: true,
      );
      final completedNormally = await completer.future;
      timeoutTimer.cancel();
      final activeSubscription = relaySubscription;
      relaySubscription = null;
      await activeSubscription?.cancel();
      Log.info(
        '📋 Received ${receivedEvents.length} raw list events from relays',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListRelaySnapshot(
        events: receivedEvents,
        completedNormally: completedNormally,
      );
    } finally {
      timeoutTimer?.cancel();
      await relaySubscription?.cancel();
    }
  }
}
