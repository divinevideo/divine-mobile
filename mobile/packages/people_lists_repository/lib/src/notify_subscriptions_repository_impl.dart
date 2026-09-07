// ABOUTME: NostrClient-backed d=notify subscription list repository.
// ABOUTME: Serializes mutations so concurrent bell toggles cannot clobber.

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/src/nip51_people_list_codec.dart';
import 'package:people_lists_repository/src/notify_subscriptions_repository.dart';
import 'package:people_lists_repository/src/people_list_publish_result.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

const String _logName = 'people_lists_repository.notify';

/// Title tag written on the notify list.
///
/// Only shown if another client renders the list; Divine hides it from the
/// user-facing list UI via `Nip51PeopleListCodec.reservedDTags`.
const String _notifyListTitle = 'Notify';

/// Concrete [NotifySubscriptionsRepository] backed by a [NostrClient].
///
/// Submission semantics match `PeopleListsRepositoryImpl`: a
/// [PublishSuccess] means the event reached at least one relay socket, not
/// that any relay persisted it.
///
/// ### Mutation serialization
///
/// Every bell toggle is a read-modify-write on one NIP-33 replaceable event.
/// Two concurrent toggles would each read the same base set and the second
/// publish would drop the first's change. Mutations are therefore chained
/// per owner: each awaits the previous one's completion and reads the set
/// that mutation produced, so a rapid on/off/on sequence converges instead
/// of racing.
///
/// The chain is per owner rather than per creator on purpose — all bells live
/// in a *single* event, so serializing per creator would still race.
///
/// ### Unreadable lists are never a base for a publish
///
/// The event is replaceable, so a publish deletes every member it omits.
/// An unreachable relay pool therefore cannot be treated as an empty list:
/// reads that did not reach a relay produce no snapshot at all, mutations
/// against a missing snapshot fail without publishing, and
/// [watchSubscriptions] stays silent so the UI keeps its control disabled.
class NotifySubscriptionsRepositoryImpl
    implements NotifySubscriptionsRepository {
  /// Creates a repository bound to [nostrClient].
  NotifySubscriptionsRepositoryImpl({required NostrClient nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  final Map<String, _NotifyListSnapshot> _snapshots = {};
  final Map<String, BehaviorSubject<Set<String>>> _subjects = {};

  /// Tail of the per-owner mutation chain. Awaiting it serializes the next
  /// read-modify-write behind every mutation already queued.
  final Map<String, Future<void>> _mutationTails = {};

  /// In-flight relay reads, so concurrent mounts share one query instead of
  /// stampeding the pool with identical filters.
  final Map<String, Future<_NotifyListSnapshot?>> _inFlightReads = {};

  /// Removals whose publish failed, per owner.
  ///
  /// The bell is follow-gated, so a failed unfollow teardown would otherwise
  /// leave the creator in the public list with no UI left to remove them.
  /// Pending removals are folded into the next publish for that owner and
  /// drained by [reconcile].
  final Map<String, Set<String>> _pendingRemovals = {};

  bool _disposed = false;

  @override
  Future<Set<String>> readSubscriptions({required String ownerPubkey}) async {
    final snapshot = await _ensureSnapshot(ownerPubkey);
    if (snapshot == null) {
      throw NotifySubscriptionsUnavailableException(ownerPubkey);
    }
    return snapshot.creators;
  }

  @override
  Stream<Set<String>> watchSubscriptions({required String ownerPubkey}) {
    final subject = _subjectFor(ownerPubkey);
    // Seed asynchronously so a listener that subscribes before the first
    // relay read still receives the loaded set rather than only future
    // mutations. A failed read stores nothing, so the next mount retries.
    if (!_snapshots.containsKey(ownerPubkey)) {
      _ensureSnapshot(ownerPubkey).ignore();
    }
    return subject.stream;
  }

  @override
  Future<void> refresh({required String ownerPubkey}) async {
    final snapshot = await _readFromRelays(ownerPubkey);
    // A failed read must not clear a good snapshot: the empty set it would
    // cache is exactly the base a later publish would delete the list down
    // to.
    if (snapshot == null) return;
    _publishSnapshot(ownerPubkey, snapshot);
  }

  @override
  Future<PeopleListPublishResult> subscribe({
    required String ownerPubkey,
    required String creatorPubkey,
  }) {
    return _mutate(
      ownerPubkey: ownerPubkey,
      creatorPubkey: creatorPubkey,
      add: true,
    );
  }

  @override
  Future<PeopleListPublishResult> unsubscribe({
    required String ownerPubkey,
    required String creatorPubkey,
  }) {
    return _mutate(
      ownerPubkey: ownerPubkey,
      creatorPubkey: creatorPubkey,
      add: false,
    );
  }

  @override
  Future<PeopleListPublishResult> reconcile({required String ownerPubkey}) {
    if (_pendingRemovals[ownerPubkey]?.isNotEmpty != true) {
      return Future.value(const PeopleListPublishResult.noop());
    }
    return _mutate(ownerPubkey: ownerPubkey, add: false);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subject in _subjects.values) {
      await subject.close();
    }
    _subjects.clear();
    _snapshots.clear();
    _mutationTails.clear();
    _inFlightReads.clear();
    _pendingRemovals.clear();
  }

  /// Queues a mutation behind every mutation already pending for [ownerPubkey].
  ///
  /// A null [creatorPubkey] mutates nothing by itself and only republishes
  /// outstanding removals — see [reconcile].
  Future<PeopleListPublishResult> _mutate({
    required String ownerPubkey,
    required bool add,
    String? creatorPubkey,
  }) {
    final previous = _mutationTails[ownerPubkey] ?? Future<void>.value();
    final result = previous.then(
      (_) => _applyMutation(
        ownerPubkey: ownerPubkey,
        creatorPubkey: creatorPubkey,
        add: add,
      ),
    );
    // The tail must never carry an error, or every later mutation in the
    // chain would fail with the earlier one's error instead of running.
    _mutationTails[ownerPubkey] = result.then((_) {}, onError: (_, _) {});
    return result;
  }

  Future<PeopleListPublishResult> _applyMutation({
    required String ownerPubkey,
    required String? creatorPubkey,
    required bool add,
  }) async {
    if (_disposed) return const PeopleListPublishResult.failed();
    if (creatorPubkey != null &&
        (creatorPubkey.isEmpty || creatorPubkey == ownerPubkey)) {
      // Subscribing to your own posts is meaningless; the push service drops
      // self-references anyway, so never write one.
      return const PeopleListPublishResult.noop();
    }

    final snapshot = await _ensureSnapshot(ownerPubkey);
    if (snapshot == null) {
      // Publishing against a base set we could not read would delete every
      // subscription the read failed to load. Retain the removal so the next
      // successful read reapplies it.
      if (creatorPubkey != null && !add) {
        _recordPendingRemoval(ownerPubkey, creatorPubkey);
      }
      return PeopleListPublishResult.failed(
        error: NotifySubscriptionsUnavailableException(ownerPubkey),
      );
    }

    final desired = <String>{...snapshot.creators}
      ..removeAll(_pendingRemovals[ownerPubkey] ?? const <String>{});
    if (creatorPubkey != null) {
      if (add) {
        desired.add(creatorPubkey);
      } else {
        desired.remove(creatorPubkey);
      }
    }

    if (_sameMembers(desired, snapshot.creators)) {
      // The published list already matches what we want, so every pending
      // removal is satisfied without a write.
      _pendingRemovals.remove(ownerPubkey);
      return const PeopleListPublishResult.noop();
    }

    final result = await _publishReplacement(
      ownerPubkey: ownerPubkey,
      creators: desired,
      previousCreatedAt: snapshot.createdAt,
      sourceTags: snapshot.sourceTags,
      sourceContent: snapshot.sourceContent,
    );

    if (result.submitted) {
      // `desired` excluded every pending removal, so a submitted publish
      // clears all of them at once.
      _pendingRemovals.remove(ownerPubkey);
    } else if (creatorPubkey != null && !add) {
      _recordPendingRemoval(ownerPubkey, creatorPubkey);
    }
    return result;
  }

  /// Publishes the full list. A partial list would be a destructive write:
  /// the event is replaceable, so omitted members are removed.
  Future<PeopleListPublishResult> _publishReplacement({
    required String ownerPubkey,
    required Set<String> creators,
    required int previousCreatedAt,
    required List<List<String>>? sourceTags,
    required String? sourceContent,
  }) async {
    final payload = Nip51PeopleListCodec.encodeReserved(
      dTag: Nip51PeopleListCodec.notifyDTag,
      title: _notifyListTitle,
      pubkeys: creators,
      sourceTags: sourceTags,
      sourceContent: sourceContent,
    );

    // NIP-33 replacement resolves by created_at, and relay behaviour for a
    // tie is unspecified. Two toggles inside the same second would otherwise
    // be a coin flip over which survives, so step past the previous event.
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final createdAt = nowSeconds > previousCreatedAt
        ? nowSeconds
        : previousCreatedAt + 1;

    final event = Event(
      ownerPubkey,
      payload.kind,
      payload.tags,
      payload.content,
      createdAt: createdAt,
    );

    try {
      final sent = await _nostrClient.publishEvent(event);
      if (sent is! PublishSuccess) {
        Log.warning(
          'Notify list publish returned no event for owner '
          '${pubkeyForLogs(ownerPubkey)}',
          name: _logName,
          category: LogCategory.relay,
        );
        return const PeopleListPublishResult.failed();
      }
      _publishSnapshot(
        ownerPubkey,
        _NotifyListSnapshot(
          creators: creators,
          createdAt: createdAt,
          sourceTags: payload.tags,
          sourceContent: payload.content,
        ),
      );
      return PeopleListPublishResult.submitted(eventId: sent.event.id);
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to publish notify list for owner ${pubkeyForLogs(ownerPubkey)}',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      // Snapshot intentionally untouched so the caller can revert optimistic
      // UI and a retry re-reads the unchanged base set.
      return PeopleListPublishResult.failed(error: error);
    }
  }

  /// Returns the cached snapshot, reading from relays once when absent.
  ///
  /// Returns `null` when the list has never been read successfully. The
  /// failure is deliberately not cached, so the next call retries.
  Future<_NotifyListSnapshot?> _ensureSnapshot(String ownerPubkey) async {
    final cached = _snapshots[ownerPubkey];
    if (cached != null) return cached;

    final inFlight = _inFlightReads[ownerPubkey];
    if (inFlight != null) return inFlight;

    final read = _readFromRelays(ownerPubkey);
    _inFlightReads[ownerPubkey] = read;
    final _NotifyListSnapshot? loaded;
    try {
      loaded = await read;
    } finally {
      // The removed handle is the future awaited just above; `_readFromRelays`
      // never completes with an error, so there is nothing left to observe.
      _inFlightReads.remove(ownerPubkey)?.ignore();
    }
    if (loaded == null) return null;

    // A mutation may have published while the relay read was in flight; that
    // snapshot is newer than what the relay returned, so keep it.
    final current = _snapshots[ownerPubkey];
    if (current != null && current.createdAt >= loaded.createdAt) {
      return current;
    }
    _publishSnapshot(ownerPubkey, loaded);
    return loaded;
  }

  /// Reads the newest `d=notify` event for [ownerPubkey], or `null` when the
  /// list could not be read.
  ///
  /// Relays may return several replaceable generations; the highest
  /// `created_at` wins.
  ///
  /// A query that reached no relay or timed out cannot distinguish "this user
  /// has no subscriptions" from "we could not ask", and the difference is
  /// destructive: the caller would publish a replacement built on an empty
  /// base and delete the real list. Both cases therefore return `null`, as
  /// does a thrown read.
  Future<_NotifyListSnapshot?> _readFromRelays(String ownerPubkey) async {
    final filter = Filter(
      kinds: const [Nip51PeopleListCodec.kind],
      authors: [ownerPubkey],
      d: const [Nip51PeopleListCodec.notifyDTag],
    );

    try {
      final result = await _nostrClient.queryEventsDetailed([filter]);
      if (result.noRelays || result.timedOut) {
        Log.warning(
          'Notify list unreadable for owner ${pubkeyForLogs(ownerPubkey)} '
          '(noRelays: ${result.noRelays}, timedOut: ${result.timedOut})',
          name: _logName,
          category: LogCategory.relay,
        );
        return null;
      }

      Event? newestEvent;
      List<String>? newestMembers;
      for (final event in result.events) {
        final members = Nip51PeopleListCodec.decodeReservedMembers(
          event,
          dTag: Nip51PeopleListCodec.notifyDTag,
        );
        if (members == null) continue;
        if (newestEvent != null && !_isNewerRevision(event, newestEvent)) {
          continue;
        }
        newestEvent = event;
        newestMembers = members;
      }
      if (newestEvent == null) {
        return _NotifyListSnapshot(creators: const {}, createdAt: 0);
      }
      return _NotifyListSnapshot(
        creators: newestMembers!.toSet(),
        createdAt: newestEvent.createdAt,
        sourceTags: newestEvent.tags,
        sourceContent: newestEvent.content,
      );
    } on Object catch (error) {
      Log.warning(
        'Failed to read notify list for owner ${pubkeyForLogs(ownerPubkey)}: '
        '$error',
        name: _logName,
        category: LogCategory.relay,
      );
      return null;
    }
  }

  void _recordPendingRemoval(String ownerPubkey, String creatorPubkey) {
    (_pendingRemovals[ownerPubkey] ??= <String>{}).add(creatorPubkey);
  }

  void _publishSnapshot(String ownerPubkey, _NotifyListSnapshot snapshot) {
    if (_disposed) return;
    _snapshots[ownerPubkey] = snapshot;
    final subject = _subjects[ownerPubkey];
    if (subject != null && !subject.isClosed) {
      subject.add(snapshot.creators);
    }
  }

  BehaviorSubject<Set<String>> _subjectFor(String ownerPubkey) {
    return _subjects.putIfAbsent(ownerPubkey, () {
      final seed = _snapshots[ownerPubkey]?.creators;
      // Unseeded until something has actually been read or published: an
      // unverified empty set would let a listener enable a control whose
      // first tap replaces the real list with just that one member.
      return seed == null
          ? BehaviorSubject<Set<String>>()
          : BehaviorSubject<Set<String>>.seeded(seed);
    });
  }

  static bool _sameMembers(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _isNewerRevision(Event candidate, Event selected) {
    final createdAtComparison = candidate.createdAt.compareTo(
      selected.createdAt,
    );
    if (createdAtComparison != 0) return createdAtComparison > 0;
    // Match the user-facing people-list reconciliation rule so relay result
    // order cannot change which complete event becomes the next publish base.
    return candidate.id.compareTo(selected.id) < 0;
  }
}

/// Immutable view of the notify list and its complete replacement source.
///
/// The timestamp is kept so the next publish can step past it — see
/// `_publishReplacement`. Null source fields mean no relay event exists yet,
/// which is distinct from an existing event with no members or empty content.
class _NotifyListSnapshot {
  _NotifyListSnapshot({
    required Set<String> creators,
    required this.createdAt,
    List<List<String>>? sourceTags,
    this.sourceContent,
  }) : assert(
         (sourceTags == null) == (sourceContent == null),
         'sourceTags and sourceContent must both be present or both be absent',
       ),
       creators = Set<String>.unmodifiable(creators),
       sourceTags = sourceTags == null
           ? null
           : List<List<String>>.unmodifiable(
               sourceTags.map(List<String>.unmodifiable),
             );

  final Set<String> creators;
  final int createdAt;
  final List<List<String>>? sourceTags;
  final String? sourceContent;
}
