// ABOUTME: Relay-boundary collaborator for NIP-51 curated lists (kind 30005)
// ABOUTME: Public-list reads, event codec, NIP-44 sealing, and deletion requests
//
// Everything CuratedListService does at the relay edge that does not touch its
// local list state lives here, so the service keeps the cache and this keeps
// the protocol. Extracted from curated_list_service.dart under the service
// god-file ratchet (#6932); the eventual home is curated_list_repository per
// epic #4338.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

enum UnsealItemTagsStatus { notSealed, unsealed, failed }

// Keeps the read alive past nostr_sdk's 8s subscription silence probe and 10s
// teardown repair floor so a repaired relay can still answer this request.

final class UnsealedItemTags {
  const UnsealedItemTags._(this.status, [this.tags]);

  const UnsealedItemTags.notSealed() : this._(UnsealItemTagsStatus.notSealed);

  const UnsealedItemTags.unsealed(List<List<String>> tags)
    : this._(UnsealItemTagsStatus.unsealed, tags);

  const UnsealedItemTags.failed() : this._(UnsealItemTagsStatus.failed);

  final UnsealItemTagsStatus status;
  final List<List<String>>? tags;
}

/// The relay side of curated lists: reads public lists, seals and unseals
/// private items, and publishes deletion requests.
///
/// Holds no list state. [CuratedListService] owns the local cache and calls
/// through here for anything that talks to a relay.
class CuratedListRelayGateway {
  CuratedListRelayGateway({
    required NostrClient nostrService,
    required AuthService authService,
  }) : _nostrService = nostrService,
       _authService = authService;

  final NostrClient _nostrService;
  final AuthService _authService;

  String? currentAuthenticatedPubkey() {
    if (!_authService.isAuthenticated) {
      return null;
    }

    final currentPubkey = _authService.currentPublicKeyHex;
    if (currentPubkey == null || currentPubkey.isEmpty) {
      return null;
    }

    return currentPubkey;
  }

  /// NIP-44 encrypts [list]'s item tags to their owner.
  ///
  /// Encrypting to our own pubkey is what makes a list readable on our other
  /// devices and opaque to everyone else, including the relay storing it.
  /// Returns `null` when there is nobody to encrypt to or the signer refuses,
  /// which callers must treat as "do not publish": a private list published
  /// without this would expose exactly what it is meant to hide.
  Future<String?> sealItemTags(CuratedList list) async {
    final ownerPubkey = currentAuthenticatedPubkey();
    if (ownerPubkey == null || ownerPubkey.isEmpty) {
      Log.warning(
        'Cannot seal private list ${list.id} - no authenticated pubkey',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
      return null;
    }

    final plaintext = _privateItemPlaintext(list);
    if (!privateItemPayloadFits(list)) {
      Log.error(
        'Cannot seal private list ${list.id} - item payload exceeds the '
        'NIP-44 plaintext limit',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
      return null;
    }

    final signer = _nostrService.signer;
    final signerPubkey = await signer.getPublicKey();
    if (signerPubkey == null || signerPubkey != ownerPubkey) {
      Log.error(
        'Cannot seal private list ${list.id} - signer does not match the '
        'authenticated account',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
      return null;
    }

    final sealed = await signer.nip44Encrypt(signerPubkey, plaintext);
    if (sealed == null) {
      Log.error(
        'NIP-44 encryption failed for private list ${list.id}',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
    }
    return sealed;
  }

  String _privateItemPlaintext(CuratedList list) {
    return jsonEncode(CuratedListConverter.toItemTags(list));
  }

  bool privateItemPayloadFits(CuratedList list) =>
      CuratedListConverter.privateItemPayloadFits(list);

  /// Stream public curated lists from Nostr relays for discovery.
  ///
  /// Yields lists immediately as they arrive, completes on EOSE, and times out
  /// after [timeout] so a silent subscription can trigger relay repair before
  /// the caller gives up.
  /// Deduplicates per author and d-tag (keeps the newest version): every
  /// account owns a `my_vine_list`, so the d-tag alone would collapse them.
  /// Use [until] to paginate backwards (set to oldest createdAt from previous batch)
  /// Use [limit] to control how many events to request (default:
  /// [kPublicListsRelayWindow], the window search reads too)
  /// Use [excludeIds] to skip lists already known (for pagination), keyed by
  /// [CuratedList.authorScopedId]
  Stream<List<CuratedList>> streamPublicListsFromRelays({
    DateTime? until,
    int limit = kPublicListsRelayWindow,
    Set<String>? excludeIds,
    Duration timeout = kPublicCuratedListsRelayReadTimeout,
  }) {
    Log.info(
      '📋 Streaming public curated lists from relays (limit: $limit)${until != null ? ' (until: $until)' : ''}'
      '${excludeIds != null ? ' (excluding ${excludeIds.length} known)' : ''}...',
      name: 'CuratedListRelayGateway',
      category: LogCategory.system,
    );

    // Track lists per author and d-tag for deduplication (keep newest)
    final listsByAuthorScopedId = <String, CuratedList>{};
    final skipIds = excludeIds ?? <String>{};
    var totalEventsReceived = 0;
    var listsWithVideos = 0;
    var rejectedCount = 0;

    // Build filter - use until for pagination (convert DateTime to Unix timestamp)
    // Include limit to ensure relays return a reasonable number of events
    final filter = Filter(
      kinds: [30005], // NIP-51 curated lists
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      limit: limit,
    );

    Log.info(
      '📋 Filter: ${filter.toJson()}',
      name: 'CuratedListRelayGateway',
      category: LogCategory.system,
    );

    late final StreamController<List<CuratedList>> controller;
    // The subscription is cancelled by finish(), which is wired to timeout,
    // EOSE, source close/error, and caller cancellation.
    // ignore: cancel_subscriptions
    StreamSubscription<Event>? relaySubscription;
    Timer? timeoutTimer;
    var finished = false;

    Future<void> finish({Object? error}) async {
      if (finished) return;
      finished = true;
      timeoutTimer?.cancel();
      timeoutTimer = null;

      if (error != null && !controller.isClosed) {
        controller.addError(error);
      }

      final subscription = relaySubscription;
      relaySubscription = null;
      await subscription?.cancel();

      if (controller.isClosed) return;
      await controller.close();
    }

    void finishFromCallback({Object? error}) {
      unawaited(finish(error: error));
    }

    void handleEvent(Event event) {
      totalEventsReceived++;
      // Log progress every 100 events (reduced spam)
      if (totalEventsReceived % 100 == 0) {
        Log.info(
          '📋 Progress: $totalEventsReceived events, $listsWithVideos with videos, '
          '$rejectedCount empty',
          name: 'CuratedListRelayGateway',
          category: LogCategory.system,
        );
      }
      final curatedList = _eventToCuratedList(event);

      // Track rejected lists for summary (don't log each one)
      if (curatedList == null || curatedList.videoEventIds.isEmpty) {
        rejectedCount++;
      }

      if (curatedList != null && curatedList.videoEventIds.isNotEmpty) {
        listsWithVideos++;
        final key = curatedList.authorScopedId;

        // Skip lists we already know about (for pagination)
        if (skipIds.contains(key)) {
          return;
        }

        final existing = listsByAuthorScopedId[key];

        // Keep newest version
        if (existing == null ||
            curatedList.updatedAt.isAfter(existing.updatedAt)) {
          listsByAuthorScopedId[key] = curatedList;

          // Yield current accumulated list sorted by video count
          final sortedLists = listsByAuthorScopedId.values.toList()
            ..sort(
              (a, b) =>
                  b.videoEventIds.length.compareTo(a.videoEventIds.length),
            );
          controller.add(sortedLists);
        }
      }
    }

    controller = StreamController<List<CuratedList>>(
      onListen: () {
        timeoutTimer = Timer(timeout, () {
          final message =
              'Public curated lists relay read timed out after '
              '${timeout.inSeconds}s';
          Log.warning(
            '📋 $message: received $totalEventsReceived events, '
            '$listsWithVideos had videos, ${listsByAuthorScopedId.length} unique lists',
            name: 'CuratedListRelayGateway',
            category: LogCategory.system,
          );
          finishFromCallback(error: TimeoutException(message, timeout));
        });

        try {
          final subscription = _nostrService.subscribe(
            [filter],
            closeOnEose: true,
            onEose: () {
              Log.info(
                '📋 EOSE received for public curated lists: '
                '$totalEventsReceived events, $listsWithVideos had videos, '
                '${listsByAuthorScopedId.length} unique lists',
                name: 'CuratedListRelayGateway',
                category: LogCategory.system,
              );
              finishFromCallback();
            },
          );

          relaySubscription = subscription.listen(
            handleEvent,
            onError: (Object error, StackTrace stackTrace) {
              Log.error(
                '📋 Public curated lists relay stream failed: $error',
                name: 'CuratedListRelayGateway',
                category: LogCategory.system,
              );
              if (!controller.isClosed) {
                controller.addError(error, stackTrace);
              }
              finishFromCallback();
            },
            onDone: () {
              Log.info(
                '📋 Public curated lists relay stream closed: '
                '$totalEventsReceived events, $listsWithVideos had videos, '
                '${listsByAuthorScopedId.length} unique lists',
                name: 'CuratedListRelayGateway',
                category: LogCategory.system,
              );
              finishFromCallback();
            },
          );
        } catch (error, stackTrace) {
          finished = true;
          timeoutTimer?.cancel();
          timeoutTimer = null;
          Log.error(
            '📋 Public curated lists relay subscription setup failed: $error',
            name: 'CuratedListRelayGateway',
            category: LogCategory.system,
          );
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
          unawaited(controller.close());
        }
      },
      onCancel: () {
        if (!finished) {
          Log.info(
            '📋 Public curated lists relay read cancelled: '
            '$totalEventsReceived events, $listsWithVideos had videos, '
            '${listsByAuthorScopedId.length} unique lists',
            name: 'CuratedListRelayGateway',
            category: LogCategory.system,
          );
        }
        return finish();
      },
    );

    return controller.stream;
  }

  /// Fetches a single public curated list (kind 30005) by author + d-tag.
  ///
  /// Queries local cache + relays via [NostrClient.queryEvents]. Returns
  /// `null` when no matching list event is found. No result limit is set,
  /// so a stale cached version and a newer relay version can both arrive —
  /// the winner follows NIP-01 replaceable/addressable ordering (newer
  /// `created_at`, lowest event id on a tie; see [_replacesList]). Author +
  /// d-tag are re-checked on each result because queryEvents merges cache
  /// hits, whose filter support can be looser than a relay's.
  Future<CuratedList?> fetchPublicList({
    required String authorPubkey,
    required String listId,
  }) async {
    final events = await _nostrService.queryEvents([
      Filter(
        kinds: [30005], // NIP-51 curated lists
        authors: [authorPubkey],
        d: [listId],
      ),
    ]);

    CuratedList? winner;
    for (final event in events) {
      final list = _eventToCuratedList(event);
      if (list == null || list.id != listId || list.pubkey != authorPubkey) {
        continue;
      }
      if (winner == null || _replacesList(list, winner)) {
        winner = list;
      }
    }
    return winner;
  }

  /// NIP-01 replaceable/addressable ordering: a newer `created_at` wins; on an
  /// equal timestamp the lowest event id (first in lexical order) is retained.
  bool _replacesList(CuratedList candidate, CuratedList current) {
    if (candidate.updatedAt.isAfter(current.updatedAt)) return true;
    if (candidate.updatedAt.isBefore(current.updatedAt)) return false;
    return (candidate.nostrEventId ?? '').compareTo(
          current.nostrEventId ?? '',
        ) <
        0;
  }

  /// Fetch public lists from any user that contain a specific video
  /// Uses Nostr #e filter to find kind 30005 events referencing the video
  /// Returns list of CuratedList objects (progressive loading via stream version)
  Future<List<CuratedList>> fetchPublicListsContainingVideo(
    String videoEventId,
  ) async {
    Log.info(
      '📋 Fetching public lists containing video: $videoEventId',
      name: 'CuratedListRelayGateway',
      category: LogCategory.system,
    );

    StreamSubscription<Event>? relaySubscription;
    Timer? timeoutTimer;
    try {
      final completer = Completer<void>();
      final receivedEvents = <Event>[];

      // Build filter for lists containing this video
      final filter = Filter(
        kinds: [30005], // NIP-51 curated lists
        e: [videoEventId], // Lists that reference this video event
        limit: 50,
      );

      // Subscribe to matching events
      final subscription = _nostrService.subscribe(
        [filter],
        closeOnEose: true,
      );

      // Set a timeout for the subscription
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        Log.debug(
          'Public lists containing video fetch timeout, processing received events',
          name: 'CuratedListRelayGateway',
          category: LogCategory.system,
        );
        if (!completer.isCompleted) {
          final subscription = relaySubscription;
          relaySubscription = null;
          unawaited(subscription?.cancel());
          completer.complete();
        }
      });

      relaySubscription = subscription.listen(
        (event) {
          receivedEvents.add(event);
          Log.debug(
            'Received public list containing video: ${event.id}',
            name: 'CuratedListRelayGateway',
            category: LogCategory.system,
          );
        },
        onDone: () {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          Log.error(
            'Error fetching public lists containing video: $error',
            name: 'CuratedListRelayGateway',
            category: LogCategory.system,
          );
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future;

      // Process received events into CuratedList objects
      final publicLists = <CuratedList>[];

      if (receivedEvents.isNotEmpty) {
        // Group events by 'd' tag to handle replaceable events (keep newest)
        final eventsByDTag = <String, Event>{};

        for (final event in receivedEvents) {
          final dTag = CuratedListConverter.extractDTag(event);
          if (dTag != null) {
            final existingEvent = eventsByDTag[dTag];
            if (existingEvent == null ||
                event.createdAt > existingEvent.createdAt) {
              eventsByDTag[dTag] = event;
            }
          }
        }

        Log.debug(
          'Processing ${eventsByDTag.length} unique public lists containing video',
          name: 'CuratedListRelayGateway',
          category: LogCategory.system,
        );

        for (final event in eventsByDTag.values) {
          final curatedList = _eventToCuratedList(event);
          if (curatedList != null) {
            publicLists.add(curatedList);
          }
        }
      }

      Log.info(
        '✅ Found ${publicLists.length} public lists containing video',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );

      return publicLists;
    } catch (e) {
      Log.error(
        'Failed to fetch public lists containing video: $e',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
      return [];
    } finally {
      timeoutTimer?.cancel();
      await relaySubscription?.cancel();
    }
  }

  /// Stream public lists containing a specific video for progressive loading
  /// Emits CuratedList objects as they arrive from relays
  Stream<CuratedList> streamPublicListsContainingVideo(String videoEventId) {
    Log.info(
      '📋 Streaming public lists containing video: $videoEventId',
      name: 'CuratedListRelayGateway',
      category: LogCategory.system,
    );

    // Build filter for lists containing this video
    final filter = Filter(
      kinds: [30005], // NIP-51 curated lists
      e: [videoEventId], // Lists that reference this video event
      limit: 50,
    );

    // Track seen d-tags to handle replaceable events
    final seenDTags = <String, Event>{};

    // Subscribe and transform events to CuratedList objects
    return _nostrService
        .subscribe([filter], closeOnEose: true)
        .map((event) {
          final dTag = CuratedListConverter.extractDTag(event);
          if (dTag == null) return null;

          // Check if we've seen a newer version of this list
          final existing = seenDTags[dTag];
          if (existing != null && existing.createdAt >= event.createdAt) {
            return null; // Skip older version
          }
          seenDTags[dTag] = event;

          return _eventToCuratedList(event);
        })
        .where((list) => list != null)
        .cast<CuratedList>();
  }

  /// Convert a Nostr event to a CuratedList object
  /// Returns null if event is invalid or cannot be parsed
  CuratedList? _eventToCuratedList(Event event) {
    final curatedList = CuratedListConverter.fromEvent(event);
    if (curatedList == null) {
      Log.warning(
        'Failed to parse list event: ${event.id}',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
      return null;
    }

    if (curatedList.videoEventIds.isNotEmpty) {
      Log.debug(
        '📋 Found list "${curatedList.id}" with '
        '${curatedList.videoEventIds.length} videos',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
    }

    return curatedList;
  }

  /// Recovers the item tags a private list sealed into [event]'s content.
  ///
  /// A failed unseal is distinct from a public list: merging a sealed event as
  /// public would drop the private items locally and publish them in plain tags
  /// on the next edit.
  Future<UnsealedItemTags> unsealItemTags(Event event) async {
    if (event.content.isEmpty || _hasPublicItemTags(event.tags)) {
      return const UnsealedItemTags.notSealed();
    }
    if (!CuratedListConverter.isEncryptedItemPayload(event.content)) {
      return const UnsealedItemTags.notSealed();
    }

    final ownerPubkey = currentAuthenticatedPubkey();
    // Only our own lists are encrypted to us. Asking the signer about
    // everyone else's costs a round trip per list to be told no.
    if (ownerPubkey == null || event.pubkey != ownerPubkey) {
      return const UnsealedItemTags.failed();
    }

    try {
      final signer = _nostrService.signer;
      if (await signer.getPublicKey() != ownerPubkey) {
        return const UnsealedItemTags.failed();
      }
      final plaintext = CuratedListConverter.isNip44Payload(event.content)
          ? await signer.nip44Decrypt(ownerPubkey, event.content)
          : await signer.decrypt(ownerPubkey, event.content);
      if (plaintext == null) return const UnsealedItemTags.failed();

      final decoded = jsonDecode(plaintext);
      if (decoded is! List) return const UnsealedItemTags.failed();
      return UnsealedItemTags.unsealed([
        for (final dynamic tag in decoded)
          if (tag is List) tag.map((dynamic value) => '$value').toList(),
      ]);
    } on Object catch (e) {
      Log.debug(
        'Content of list event ${event.id} is not sealed item tags: $e',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
      return const UnsealedItemTags.failed();
    }
  }

  bool _hasPublicItemTags(List<List<String>> tags) {
    return tags.any(
      (tag) => tag.isNotEmpty && (tag.first == 'e' || tag.first == 'a'),
    );
  }

  /// Asks relays to drop the plaintext list event a privacy flip replaced.
  ///
  /// The sealed replacement already overwrote the coordinate on every relay
  /// that accepted it; this reaches the relays that did not, so the worst
  /// case of a partial flip is a relay serving nothing rather than a relay
  /// still serving the items in plain `e` tags.
  ///
  /// Deliberately an `e` tag on [plaintextEventId] and never an `a` tag on the
  /// coordinate: NIP-09 has relays honour a coordinate deletion for every
  /// version up to the request's `created_at`, which would take the sealed
  /// replacement down with the original.
  ///
  /// Best effort by contract. NIP-09 is a request relays SHOULD honour, and
  /// anything that already read the public copy keeps it, so the caller must
  /// not gate the flip on the result — the flip is already committed by the
  /// time this runs.
  Future<void> redactPlaintextListEvent(String plaintextEventId) async {
    final event = await _authService.createAndSignEvent(
      kind: EventKind.eventDeletion,
      content: '',
      tags: [
        ['e', plaintextEventId],
        ['k', '30005'],
      ],
    );
    if (event == null) {
      Log.warning(
        'Could not sign redaction for public list event $plaintextEventId',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
      return;
    }

    final result = await _nostrService.publishEvent(event);
    final failureReason = result.failureReason;
    if (failureReason != null) {
      Log.warning(
        'Failed to redact public list event $plaintextEventId: '
        '$failureReason',
        name: 'CuratedListRelayGateway',
        category: LogCategory.system,
      );
    }
  }

  Future<bool> publishListDeletion(String listId) async {
    final currentPubkey = currentAuthenticatedPubkey();
    if (currentPubkey == null || currentPubkey.isEmpty) {
      return false;
    }

    final event = await _authService.createAndSignEvent(
      kind: EventKind.eventDeletion,
      content: 'Deleted curated list $listId',
      tags: [
        ['a', '30005:$currentPubkey:$listId'],
        ['k', '30005'],
      ],
    );
    if (event == null) return false;

    // Confirmed, for the same reason as the confirmed publish path: both
    // callers drop or flip local state when this returns false, and a queued
    // deletion that lands after the rollback would delete the list the user
    // still has.
    final outcome = await _nostrService.publishEventAwaitOk(event);
    if (outcome.acceptedByAny) return true;

    Log.warning(
      'Failed to publish curated list deletion: ${outcome.summary}',
      name: 'CuratedListRelayGateway',
      category: LogCategory.system,
    );
    return false;
  }
}
