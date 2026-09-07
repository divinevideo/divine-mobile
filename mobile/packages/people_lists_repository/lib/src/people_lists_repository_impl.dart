// ABOUTME: NostrClient-backed implementation of PeopleListsRepository.
// ABOUTME: Treats publishEvent non-null return as submitted, never confirmed.

import 'dart:async';

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/src/local_people_lists_cache.dart';
import 'package:people_lists_repository/src/nip51_people_list_codec.dart';
import 'package:people_lists_repository/src/people_list_publish_result.dart';
import 'package:people_lists_repository/src/people_list_search_result.dart';
import 'package:people_lists_repository/src/people_lists_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Logger name for repository-level diagnostics.
const String _logName = 'people_lists_repository.impl';

/// Filter callback for owner-authored people-list search results.
///
/// Returns `true` when content from [ownerPubkey] should be hidden.
typedef BlockedPeopleListOwnerFilter = bool Function(String ownerPubkey);

/// Concrete [PeopleListsRepository] backed by a [NostrClient] and a
/// [LocalPeopleListsCache].
///
/// Submission semantics: a non-null return from [NostrClient.publishEvent]
/// means the event was signed and submitted to at least one relay socket. The
/// repository does not wait for a relay `OK`. On a null return or thrown
/// error, the operation is reported as [PeopleListPublishStatus.failed] and
/// no optimistic cache write is performed.
///
/// Constructor injection only — the repository never resolves dependencies
/// implicitly. All mutable state lives in the injected cache; the repository
/// itself is effectively stateless.
class PeopleListsRepositoryImpl implements PeopleListsRepository {
  /// Creates a repository bound to [nostrClient] and [cache].
  PeopleListsRepositoryImpl({
    required NostrClient nostrClient,
    required LocalPeopleListsCache cache,
    BlockedPeopleListOwnerFilter? blockFilter,
  }) : _nostrClient = nostrClient,
       _cache = cache,
       _blockFilter = blockFilter;

  final NostrClient _nostrClient;
  final LocalPeopleListsCache _cache;
  final BlockedPeopleListOwnerFilter? _blockFilter;

  @override
  Stream<List<UserList>> watchLists({required String ownerPubkey}) {
    return _cache.watchLists(ownerPubkey: ownerPubkey);
  }

  @override
  Future<List<UserList>> readLists({required String ownerPubkey}) {
    return _cache.readLists(ownerPubkey: ownerPubkey);
  }

  /// How long an authoritative read waits for every relay to settle.
  ///
  /// Deliberately shorter than the 5s default: an expiry reports `timedOut`,
  /// which refuses the mutation, so erring short errs toward not publishing
  /// over a list we could not read.
  static const _reconcileTimeout = Duration(seconds: 3);

  @override
  Future<void> syncOwner({required String ownerPubkey}) async {
    await _reconcileOwner(ownerPubkey);
  }

  /// Refresh the cached lists for [ownerPubkey] and report whether the answer
  /// was conclusive.
  ///
  /// Returns `false` when no relay settled the query — a timeout, or a fan-out
  /// no relay took. That is not the same as "this owner has no lists", and the
  /// difference decides whether it is safe to publish a replacement: these are
  /// addressable events, so a full replacement built on a stale cache drops
  /// every member only the relay's copy holds (#8273).
  ///
  /// [NostrClient.queryEvents] cannot express this — it drops `timedOut` and
  /// `noRelays` — which is why the detailed form is used, with
  /// `requireAllRelaysSettled` so a relay abandoned by the settle window
  /// arrives as a timeout rather than as an empty answer.
  ///
  /// [addPubkey] and [removePubkey] report an inconclusive answer as
  /// [PeopleListPublishResult.failed] rather than publishing over it — the
  /// bloc rolls its optimistic update back on that, and unlike a block or a
  /// follow there is no local-only meaning to preserve here: the list *is*
  /// the published artifact.
  Future<bool> _reconcileOwner(String ownerPubkey) async {
    final filter = Filter(
      kinds: const [Nip51PeopleListCodec.kind],
      authors: [ownerPubkey],
    );

    final result = await _nostrClient.queryEventsDetailed(
      [filter],
      requireAllRelaysSettled: true,
      timeout: _reconcileTimeout,
    );
    final conclusive = !result.timedOut && !result.noRelays;
    final events = result.events;
    if (events.isEmpty) return conclusive;

    // Index existing lists by id so we can skip stale relay echoes whose
    // createdAt is older than the locally-stored updatedAt. The cache alone
    // cannot make this decision because it compares against tombstones, not
    // against the current list's updatedAt.
    final existing = await _cache.readLists(ownerPubkey: ownerPubkey);
    final existingById = <String, UserList>{
      for (final list in existing) list.id: list,
    };

    final newestByListId = <String, ({Event event, UserList list})>{};
    for (final event in events) {
      final list = Nip51PeopleListCodec.decode(event);
      if (list == null) continue;
      final candidate = (event: event, list: list);
      final selected = newestByListId[list.id];
      if (selected == null || _isNewerRevision(candidate, selected)) {
        newestByListId[list.id] = candidate;
      }
    }

    final receivedAt = DateTime.now().toUtc();
    for (final candidate in newestByListId.values) {
      final event = candidate.event;
      final list = candidate.list;
      final current = existingById[list.id];
      // list.updatedAt is derived from the relay event's created_at by
      // Nip51PeopleListCodec, so comparing it against the cached list's
      // updatedAt correctly detects stale relay echoes. If the codec ever
      // stops sourcing updatedAt from created_at, revisit this guard.
      if (current != null && current.updatedAt.isAfter(list.updatedAt)) {
        continue;
      }
      if (current != null &&
          current.updatedAt == list.updatedAt &&
          current.nostrEventId != null &&
          current.nostrEventId != list.nostrEventId &&
          current.nostrEventId!.compareTo(list.nostrEventId ?? '') < 0) {
        continue;
      }
      await _cache.putList(
        ownerPubkey: ownerPubkey,
        list: list,
        receivedAt: receivedAt,
        sourceTags: event.tags,
        sourceContent: event.content,
      );
    }
    return conclusive;
  }

  @override
  Future<PeopleListPublishResult> createList({
    required String ownerPubkey,
    required String name,
    String? description,
    String? imageUrl,
    Iterable<String> initialPubkeys = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final list = UserList(
      id: _generateListId(now),
      name: name,
      description: description,
      imageUrl: imageUrl,
      pubkeys: List<String>.unmodifiable(initialPubkeys),
      createdAt: now,
      updatedAt: now,
    );
    return _publishListReplacement(ownerPubkey: ownerPubkey, list: list);
  }

  @override
  Future<PeopleListPublishResult> addPubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) async {
    // A replacement built on a stale cache drops members only the relay has.
    if (!await _reconcileOwner(ownerPubkey)) {
      return const PeopleListPublishResult.failed();
    }
    final record = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (record == null) {
      return const PeopleListPublishResult.failed();
    }
    final existing = record.list;
    if (existing.pubkeys.contains(pubkey)) {
      return const PeopleListPublishResult.noop();
    }
    if (!record.hasPublishSource) {
      return const PeopleListPublishResult.failed();
    }
    final updated = existing.copyWith(
      pubkeys: [...existing.pubkeys, pubkey],
      updatedAt: DateTime.now().toUtc(),
    );
    return _publishListReplacement(
      ownerPubkey: ownerPubkey,
      list: updated,
      sourceTags: record.sourceTags,
      sourceContent: record.sourceContent,
    );
  }

  @override
  Future<PeopleListPublishResult> removePubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) async {
    // A replacement built on a stale cache drops members only the relay has.
    if (!await _reconcileOwner(ownerPubkey)) {
      return const PeopleListPublishResult.failed();
    }
    final record = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (record == null) {
      return const PeopleListPublishResult.failed();
    }
    final existing = record.list;
    if (!existing.pubkeys.contains(pubkey)) {
      return const PeopleListPublishResult.noop();
    }
    if (!record.hasPublishSource) {
      return const PeopleListPublishResult.failed();
    }
    final updated = existing.copyWith(
      pubkeys: existing.pubkeys.where((p) => p != pubkey).toList(),
      updatedAt: DateTime.now().toUtc(),
    );
    return _publishListReplacement(
      ownerPubkey: ownerPubkey,
      list: updated,
      sourceTags: record.sourceTags,
      sourceContent: record.sourceContent,
    );
  }

  @override
  Future<PeopleListPublishResult> deleteList({
    required String ownerPubkey,
    required String listId,
  }) async {
    final addressableId = '${Nip51PeopleListCodec.kind}:$ownerPubkey:$listId';
    final tags = <List<String>>[
      ['a', addressableId],
      ['k', '${Nip51PeopleListCodec.kind}'],
    ];
    final event = Event(
      ownerPubkey,
      EventKind.eventDeletion,
      tags,
      'Deleted people list $listId',
    );

    try {
      final sent = await _nostrClient.publishEvent(event);
      if (sent is! PublishSuccess) {
        return const PeopleListPublishResult.failed();
      }
      await _cache.markDeleted(
        ownerPubkey: ownerPubkey,
        listId: listId,
        deletedAt: DateTime.now().toUtc(),
      );
      return PeopleListPublishResult.submitted(eventId: sent.event.id);
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to publish people-list deletion for list $listId',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      return PeopleListPublishResult.failed(error: error);
    }
  }

  @override
  Stream<List<PeopleListSearchResult>> searchPublicLists(
    String query, {
    int limit = 50,
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final lowerQuery = trimmed.toLowerCase();

    final List<Event> events;
    try {
      events = await _nostrClient.queryEvents([
        Filter(kinds: const [Nip51PeopleListCodec.kind], limit: limit),
      ]);
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to query public people lists for "$trimmed"',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    final seen = <String, PeopleListSearchResult>{};
    for (final event in events) {
      final blockFilter = _blockFilter;
      if (blockFilter != null && blockFilter(event.pubkey)) continue;

      final list = Nip51PeopleListCodec.decode(event);
      if (list == null) continue;
      if (list.pubkeys.isEmpty) continue;

      final nameMatches = list.name.toLowerCase().contains(lowerQuery);
      final descriptionMatches =
          list.description?.toLowerCase().contains(lowerQuery) ?? false;
      if (!nameMatches && !descriptionMatches) continue;

      final result = PeopleListSearchResult(
        ownerPubkey: event.pubkey,
        list: list,
      );
      final existing = seen[result.addressableId];
      if (existing != null && existing.list.updatedAt.isAfter(list.updatedAt)) {
        continue;
      }
      seen[result.addressableId] = result;
    }

    if (seen.isNotEmpty) {
      yield List.unmodifiable(seen.values.toList());
    }
  }

  Future<PeopleListPublishResult> _publishListReplacement({
    required String ownerPubkey,
    required UserList list,
    List<List<String>>? sourceTags,
    String? sourceContent,
  }) async {
    final payload = Nip51PeopleListCodec.encode(
      list,
      sourceTags: sourceTags,
      sourceContent: sourceContent,
    );
    final event = Event(
      ownerPubkey,
      payload.kind,
      payload.tags,
      payload.content,
    );

    try {
      final sent = await _nostrClient.publishEvent(event);
      if (sent is! PublishSuccess) {
        return const PeopleListPublishResult.failed();
      }
      final persisted = list.copyWith(nostrEventId: sent.event.id);
      await _cache.putList(
        ownerPubkey: ownerPubkey,
        list: persisted,
        receivedAt: DateTime.now().toUtc(),
        sourceTags: payload.tags,
        sourceContent: payload.content,
      );
      return PeopleListPublishResult.submitted(eventId: sent.event.id);
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to publish people-list replacement for list ${list.id}',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      return PeopleListPublishResult.failed(error: error);
    }
  }

  Future<CachedPeopleListRecord?> _findList({
    required String ownerPubkey,
    required String listId,
  }) => _cache.readRecord(ownerPubkey: ownerPubkey, listId: listId);

  static bool _isNewerRevision(
    ({Event event, UserList list}) candidate,
    ({Event event, UserList list}) selected,
  ) {
    final createdAtComparison = candidate.event.createdAt.compareTo(
      selected.event.createdAt,
    );
    if (createdAtComparison != 0) return createdAtComparison > 0;
    return candidate.event.id.compareTo(selected.event.id) < 0;
  }

  /// Generates a NIP-33 `d`-tag list identifier from [instant].
  ///
  /// NIP-33 parameterised replaceable events are identified by
  /// `kind:pubkey:d-tag`; callers pick any string. We combine the instant's
  /// microsecond epoch with a short entropy tail derived from a fresh
  /// `Object` identity hash so two `createList` calls that land in the same
  /// microsecond still produce distinct ids and do not clobber each other
  /// via NIP-33 replacement.
  String _generateListId(DateTime instant) {
    final entropy = Object().hashCode.toRadixString(36);
    return 'list-${instant.microsecondsSinceEpoch}-$entropy';
  }
}
