// ABOUTME: Reads and rewrites a creator's pinned profile videos (kind 10001).
// ABOUTME: Keeps NIP-51 tag handling and relay reconciliation out of UI/BLoC.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cache_sync/cache_sync.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

/// The identity that signs the pin list, narrowed from `AuthService` so the
/// repository can be exercised without the app's auth stack.
abstract interface class ProfilePinsSigner {
  /// The signed-in user's public key in hex, or `null` when signed out.
  String? get currentPublicKeyHex;

  /// Creates and signs an event, returning `null` when signing fails or the
  /// user is not authenticated.
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  });
}

/// Why a pin mutation did not complete.
enum ProfilePinFailure {
  /// There is no signed-in identity to publish as.
  notAuthenticated,

  /// No relay could be reached, so the current list could not be read.
  couldNotReachRelays,

  /// Relays were reachable but did not answer before the query deadline.
  timedOut,

  /// The relay already holds [ProfilePinsRepository.maxPins] pinned videos.
  limitReached,

  /// Signing failed or no relay accepted the replacement list.
  publishDidNotComplete,
}

/// Outcome of [ProfilePinsRepository.pin] / [ProfilePinsRepository.unpin].
///
/// [coordinates] is the reconciled pin list after the mutation, so callers
/// render what the relay accepted rather than what they expected.
class ProfilePinMutation {
  const ProfilePinMutation.succeeded(List<String> this.coordinates)
    : failure = null;

  const ProfilePinMutation.failed(ProfilePinFailure this.failure)
    : coordinates = null;

  /// The managed coordinates after the mutation; `null` on failure.
  final List<String>? coordinates;

  /// Why the mutation failed; `null` on success.
  final ProfilePinFailure? failure;

  bool get succeeded => failure == null;
}

/// Replacement tags for a pin list, or `null` when the list is already in
/// the requested state, or a [ProfilePinFailure] to refuse the write.
typedef _PinListRewrite = Object? Function(
  List<List<String>> tags,
  List<String> current,
  String owner,
);

/// A creator's pinned profile videos, stored on their NIP-51 kind-10001 list
/// as kind-34236 `a` coordinates (`34236:<pubkey>:<d>`).
///
/// This is Divine's convention (shared with Divine Web), not standard NIP-51,
/// which pins kind-1 notes by `e` tag. The repository therefore manages only
/// coordinates that name the owner's own kind-34236 videos and carries every
/// other tag, plus `content`, through a rewrite byte-for-byte.
///
/// A new pin is inserted at the front so the most recently pinned video shows
/// first; Web appends. Unpin removes every exact copy of the coordinate.
class ProfilePinsRepository {
  ProfilePinsRepository({
    required NostrClient nostrClient,
    required ProfilePinsSigner signer,
    DateTime Function() now = DateTime.now,
  }) : _nostrClient = nostrClient,
       _signer = signer,
       _now = now;

  final NostrClient _nostrClient;
  final ProfilePinsSigner _signer;
  final DateTime Function() _now;

  /// How many videos a creator may pin. Product decision for the first cut
  /// (two rows of the three-column grid); the stored list is never truncated
  /// to it.
  static const int maxPins = 6;

  /// How far past this device's clock a replacement may be stamped, so a
  /// publish can still supersede a base whose `created_at` is in our future.
  static const int maxPublishFutureSkew = 30;

  /// How long a cached pin list is served before it is treated as absent.
  static const Duration cacheTtl = Duration(days: 30);

  /// Mutations run one at a time so a second pin cannot read the list the
  /// first one is about to replace.
  Future<void> _queue = Future<void>.value();

  /// The replacement each owner last got accepted, kept as a read candidate:
  /// a relay acknowledges from a queue and can still answer the next read with
  /// the revision it replaced.
  final Map<String, Event> _lastAccepted = {};

  /// Cache key per owner, following `cache_sync`'s `${pubkey}:${operation}`
  /// convention so sign-out's `invalidatePrefix` clears the owner's entry.
  static String cacheKeyFor(String ownerPubkey) => '$ownerPubkey:profile_pins';

  /// The coordinates this repository manages on [event], in stored order,
  /// first occurrence wins: kind-34236 `a` tags whose author is the list
  /// owner and whose `d` value is non-empty.
  static List<String> managedCoordinates(Event event) {
    final seen = <String>{};
    final coordinates = <String>[];
    for (final tag in event.tags) {
      final coordinate = _managedCoordinate(tag, owner: event.pubkey);
      if (coordinate != null && seen.add(coordinate)) {
        coordinates.add(coordinate);
      }
    }
    return coordinates;
  }

  static String? _managedCoordinate(List<String> tag, {required String owner}) {
    if (tag.length < 2 || tag[0] != 'a') return null;
    return isEligibleCoordinate(tag[1], owner: owner) ? tag[1] : null;
  }

  /// Whether [coordinate] names a kind-34236 video authored by [owner] with a
  /// non-empty `d` value — the only shape this repository pins.
  static bool isEligibleCoordinate(String coordinate, {required String owner}) {
    final parsed = AId.fromString(coordinate);
    return parsed != null &&
        parsed.kind == EventKind.videoVertical &&
        parsed.pubkey == owner &&
        parsed.dTag.isNotEmpty;
  }

  /// The cached pin list for [ownerPubkey], or `null` when nothing is cached.
  ///
  /// Never touches the network; a cache failure reads as a miss so a cold
  /// profile open cannot be broken by it.
  Future<List<String>?> readCached(String ownerPubkey) async {
    try {
      return await CacheSync.read<List<String>>(
        key: cacheKeyFor(ownerPubkey),
        fromJson: _coordinatesFromJson,
      );
    } on Object catch (error) {
      Log.warning(
        'Failed to read cached profile pins - $error',
        name: 'ProfilePinsRepository',
        category: LogCategory.storage,
      );
      return null;
    }
  }

  /// Reads [ownerPubkey]'s pin list from the relays and caches it.
  ///
  /// Returns `null` when the read was inconclusive (no reachable relay, or a
  /// timeout with nothing to show), so the caller keeps whatever it already
  /// has instead of clearing the grid's pins on a flaky connection.
  ///
  /// Settled on every relay for the same reason [_readAuthoritative] is: this
  /// read replaces the cached list, and without the flag a relay that stays
  /// connected without ever sending a terminal frame is skipped past the
  /// settle window and still reported as `timedOut: false`. An unconfirmed
  /// empty answer would then overwrite a real list with `[]`.
  Future<List<String>?> fetch(String ownerPubkey) async {
    final result = await _nostrClient.queryEventsDetailed(
      [
        Filter(kinds: const [EventKind.pinList], authors: [ownerPubkey]),
      ],
      requireAllRelaysSettled: true,
    );
    final selected = _selectNewest(result.events, owner: ownerPubkey);
    if (selected == null && (result.noRelays || result.timedOut)) return null;

    final coordinates = selected == null
        ? const <String>[]
        : managedCoordinates(selected);
    await _writeCache(ownerPubkey, coordinates);
    return coordinates;
  }

  /// Pins [coordinate] to the front of the signed-in user's list.
  ///
  /// Idempotent: a coordinate the relay already holds is left in place and
  /// reported as success. Refuses to write past [maxPins], counting every
  /// stored owner-authored coordinate whether or not its video resolves; a
  /// slot held by a deleted video is freed by [releaseDeleted], never by a
  /// read.
  ///
  /// Throws [ArgumentError] when [coordinate] does not name one of the signer's
  /// own kind-34236 videos; callers gate the action on
  /// [isEligibleCoordinate] before offering it.
  Future<ProfilePinMutation> pin(String coordinate) => _serialized(
    () => _mutate(coordinate, (tags, current, _) {
      if (current.contains(coordinate)) return null;
      if (current.length >= maxPins) return ProfilePinFailure.limitReached;
      return [
        ['a', coordinate],
        ...tags,
      ];
    }),
  );

  /// Removes every stored copy of [coordinate] from the signed-in user's list
  /// without reordering the rest. Idempotent: an absent coordinate is success.
  ///
  /// Throws [ArgumentError] under the same conditions as [pin].
  Future<ProfilePinMutation> unpin(String coordinate) => _serialized(
    () => _mutate(coordinate, (tags, current, owner) {
      if (!current.contains(coordinate)) return null;
      return tags
          .where((tag) => _managedCoordinate(tag, owner: owner) != coordinate)
          .toList();
    }),
  );

  /// Frees the slots held by pinned videos the signed-in user has deleted.
  ///
  /// [unavailable] are coordinates from the user's own list that show no
  /// video: the caller could not resolve them, or resolved a version it
  /// already knows is deleted. That alone never drops a pin — a relay hiccup
  /// reads the same way — so a coordinate is released only when the relays
  /// hold a NIP-09 deletion request by the user naming it and no version of
  /// the video published after that request (NIP-09 covers the versions
  /// stamped at or before it; a later republish is live again). Coordinates
  /// the signer does not own are ignored without a relay round trip, so a
  /// viewer on another creator's profile never touches that creator's list.
  ///
  /// The released coordinates leave in one rewrite. Returns the reconciled
  /// list afterwards, or `null` when nothing was released: no candidate is
  /// known deleted, the deletion lookup was inconclusive, or the rewrite
  /// failed. The caller keeps its list either way and asks again on the next
  /// profile open, which is how a quiet unpin that never landed after an
  /// in-app delete is retried.
  Future<List<String>?> releaseDeleted(List<String> unavailable) async {
    final owner = _signer.currentPublicKeyHex;
    if (owner == null) return null;
    final candidates = {
      for (final coordinate in unavailable)
        if (isEligibleCoordinate(coordinate, owner: owner)) coordinate,
    };
    if (candidates.isEmpty) return null;

    final deleted = await _knownDeleted(owner, candidates);
    if (deleted.isEmpty) return null;

    var released = 0;
    final result = await _serialized(() async {
      // The lookup was a relay round trip ago; an account switch since then
      // must not sign this owner's list with the next account's key.
      if (_signer.currentPublicKeyHex != owner) {
        return const ProfilePinMutation.failed(
          ProfilePinFailure.notAuthenticated,
        );
      }
      return _rewrite(owner, (tags, current, _) {
        released = current.where(deleted.contains).length;
        if (released == 0) return null;
        return tags
            .where(
              (tag) => !deleted.contains(_managedCoordinate(tag, owner: owner)),
            )
            .toList();
      });
    });
    final coordinates = result.coordinates;
    if (coordinates != null && released > 0) {
      Log.info(
        'Released $released pinned video(s) the relays report deleted for '
        '${pubkeyForLogs(owner)}',
        name: 'ProfilePinsRepository',
        category: LogCategory.relay,
      );
    }
    return coordinates;
  }

  /// The [candidates] the relays report deleted: a kind-5 by [owner] names
  /// the coordinate and no kind-34236 version by [owner] under the same `d`
  /// is stamped later than the newest such request. Settled on every relay
  /// so a slow relay cannot hide the version that outlives the request; an
  /// inconclusive read reports nothing deleted.
  Future<Set<String>> _knownDeleted(
    String owner,
    Set<String> candidates,
  ) async {
    final result = await _nostrClient.queryEventsDetailed(
      [
        Filter(
          kinds: const [EventKind.eventDeletion],
          authors: [owner],
          a: candidates.toList(),
        ),
        Filter(
          kinds: const [EventKind.videoVertical],
          authors: [owner],
          d: [
            for (final coordinate in candidates)
              AId.fromString(coordinate)!.dTag,
          ],
        ),
      ],
      useCache: false,
      requireAllRelaysSettled: true,
    );
    if (result.noRelays || result.timedOut) {
      Log.info(
        'Pinned-video deletion lookup inconclusive (timedOut='
        '${result.timedOut}, noRelays=${result.noRelays}) - nothing released',
        name: 'ProfilePinsRepository',
        category: LogCategory.relay,
      );
      return const {};
    }

    final deletedAt = <String, int>{};
    final liveAt = <String, int>{};
    for (final event in result.events) {
      if (event.pubkey != owner) continue;
      if (event.kind == EventKind.eventDeletion) {
        for (final tag in event.tags) {
          if (tag.length < 2 || tag[0] != 'a') continue;
          if (!candidates.contains(tag[1])) continue;
          deletedAt.update(
            tag[1],
            (known) => max(known, event.createdAt),
            ifAbsent: () => event.createdAt,
          );
        }
      } else if (event.kind == EventKind.videoVertical) {
        final coordinate = '${event.kind}:${event.pubkey}:${event.dTagValue}';
        if (!candidates.contains(coordinate)) continue;
        liveAt.update(
          coordinate,
          (known) => max(known, event.createdAt),
          ifAbsent: () => event.createdAt,
        );
      }
    }
    return {
      for (final MapEntry(key: coordinate, value: requestedAt)
          in deletedAt.entries)
        if ((liveAt[coordinate] ?? requestedAt) <= requestedAt) coordinate,
    };
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  /// Rewrites the signed-in user's list around a single [coordinate] of
  /// their own; see [pin] for the failure and throw contract.
  Future<ProfilePinMutation> _mutate(
    String coordinate,
    _PinListRewrite rewrite,
  ) async {
    final owner = _signer.currentPublicKeyHex;
    if (owner == null) {
      return const ProfilePinMutation.failed(
        ProfilePinFailure.notAuthenticated,
      );
    }
    if (!isEligibleCoordinate(coordinate, owner: owner)) {
      throw ArgumentError.value(
        coordinate,
        'coordinate',
        'must name a kind-${EventKind.videoVertical} video by the signer',
      );
    }
    return _rewrite(owner, rewrite);
  }

  /// Reads [owner]'s authoritative list, asks [rewrite] for the replacement
  /// tags, and publishes the result.
  Future<ProfilePinMutation> _rewrite(
    String owner,
    _PinListRewrite rewrite,
  ) async {
    final read = await _readAuthoritative(owner);
    if (read.failure case final failure?) {
      return ProfilePinMutation.failed(failure);
    }
    final base = read.event;
    final current = base == null ? const <String>[] : managedCoordinates(base);

    final replacement = rewrite(base?.tags ?? const [], current, owner);
    if (replacement == null) return ProfilePinMutation.succeeded(current);
    if (replacement is ProfilePinFailure) {
      return ProfilePinMutation.failed(replacement);
    }

    final event = await _signer.createAndSignEvent(
      kind: EventKind.pinList,
      // NIP-51 reserves `content` for the encrypted private-item array, which
      // this client neither reads nor writes; it travels through verbatim.
      content: base?.content ?? '',
      tags: replacement as List<List<String>>,
      createdAt: _nextCreatedAt(base),
    );
    if (event == null) {
      return const ProfilePinMutation.failed(
        ProfilePinFailure.publishDidNotComplete,
      );
    }

    final outcome = await _nostrClient.publishEventAwaitOk(event);
    if (!outcome.acceptedByAny) {
      Log.warning(
        'Relay did not accept pinned videos ${event.id} (${outcome.summary}) '
        'for ${pubkeyForLogs(owner)}',
        name: 'ProfilePinsRepository',
        category: LogCategory.relay,
      );
      return const ProfilePinMutation.failed(
        ProfilePinFailure.publishDidNotComplete,
      );
    }

    _lastAccepted[owner] = event;
    final coordinates = managedCoordinates(event);
    await _writeCache(owner, coordinates);
    return ProfilePinMutation.succeeded(coordinates);
  }

  /// The relay's current list for [owner], settled on every relay so an empty
  /// answer is a real empty list rather than a slow relay — republishing over
  /// an unread list is how a replaceable event loses items.
  Future<({Event? event, ProfilePinFailure? failure})> _readAuthoritative(
    String owner,
  ) async {
    final result = await _nostrClient.queryEventsDetailed(
      [
        Filter(kinds: const [EventKind.pinList], authors: [owner]),
      ],
      useCache: false,
      requireAllRelaysSettled: true,
    );
    if (result.noRelays || result.timedOut) {
      Log.warning(
        'Pinned-video read inconclusive (timedOut=${result.timedOut}, '
        'noRelays=${result.noRelays}) - list left unchanged',
        name: 'ProfilePinsRepository',
        category: LogCategory.relay,
      );
      // Offline sets both flags, so noRelays is tested first.
      return (
        event: null,
        failure: result.noRelays
            ? ProfilePinFailure.couldNotReachRelays
            : ProfilePinFailure.timedOut,
      );
    }
    return (event: _selectNewest(result.events, owner: owner), failure: null);
  }

  /// The canonical replaceable-event winner among [events] and the owner's
  /// last locally accepted revision: newest `created_at`, lowest id on a tie.
  Event? _selectNewest(Iterable<Event> events, {required String owner}) {
    Event? winner;
    for (final candidate in events.followedBy([?_lastAccepted[owner]])) {
      if (candidate.kind != EventKind.pinList || candidate.pubkey != owner) {
        continue;
      }
      if (winner == null ||
          candidate.createdAt > winner.createdAt ||
          (candidate.createdAt == winner.createdAt &&
              candidate.id.compareTo(winner.id) < 0)) {
        winner = candidate;
      }
    }
    return winner;
  }

  /// A `created_at` that supersedes [base]: NIP-01 keeps the higher timestamp
  /// for a replaceable event, so two writes inside one second would otherwise
  /// tie and the relay could keep the old list.
  int _nextCreatedAt(Event? base) {
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final backdated =
        nowSeconds - NostrTimestamp.getDriftToleranceForKind(EventKind.pinList);
    if (base == null || backdated > base.createdAt) return backdated;

    final superseding = base.createdAt + 1;
    final ceiling = nowSeconds + maxPublishFutureSkew;
    if (superseding <= ceiling) return superseding;
    Log.warning(
      'Cannot stamp past pin list revision ${base.createdAt}; publishing at '
      '$ceiling, which the relay merge may discard',
      name: 'ProfilePinsRepository',
      category: LogCategory.relay,
    );
    return ceiling;
  }

  Future<void> _writeCache(String ownerPubkey, List<String> coordinates) async {
    try {
      await CacheSync.write<List<String>>(
        key: cacheKeyFor(ownerPubkey),
        value: coordinates,
        toJson: jsonEncode,
        ttl: cacheTtl,
      );
    } on Object catch (error) {
      Log.warning(
        'Failed to cache profile pins - $error',
        name: 'ProfilePinsRepository',
        category: LogCategory.storage,
      );
    }
  }

  /// Eager on purpose: `cast` returns a lazy view that only throws when an
  /// element is read, which is long after `CacheSync.read`'s guard has
  /// returned and left the corrupt entry on disk.
  static List<String> _coordinatesFromJson(String json) =>
      List<String>.from(jsonDecode(json) as List<dynamic>);
}
