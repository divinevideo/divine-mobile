// ABOUTME: NostrClient-backed implementation of PeopleListsRepository.
// ABOUTME: Orders replacements and caches only after relay acceptance.

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/src/local_people_lists_cache.dart';
import 'package:people_lists_repository/src/nip51_people_list_codec.dart';
import 'package:people_lists_repository/src/people_list_publish_result.dart';
import 'package:people_lists_repository/src/people_list_search_result.dart';
import 'package:people_lists_repository/src/people_lists_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// A public list read could not establish whether the list exists.
class PublicPeopleListReadUnavailableException implements Exception {
  /// Creates a retryable failure for an unconfirmed relay read.
  const PublicPeopleListReadUnavailableException();
}

/// Logger name for repository-level diagnostics.
const String _logName = 'people_lists_repository.impl';

/// Read budget for public people-list discovery, search and coordinate reads.
const kPublicPeopleListsRelayReadTimeout = Duration(seconds: 12);

/// How many authors one bulk-profile call answers for.
const _bulkProfilesPageSize = 100;

/// Filter callback for owner-authored people-list search results.
///
/// Returns `true` when content from [ownerPubkey] should be hidden.
typedef BlockedPeopleListOwnerFilter = bool Function(String ownerPubkey);

/// Concrete [PeopleListsRepository] backed by a [NostrClient] and a
/// [LocalPeopleListsCache].
///
/// Writes wait for at least one relay to acknowledge acceptance. This is not
/// a durability guarantee: relays may commit after acknowledging.
/// Sync and all writes share an owner queue: reconciling one list reads all
/// of that owner's lists, so its cache merge must not overlap another write.
class PeopleListsRepositoryImpl implements PeopleListsRepository {
  /// Creates a repository bound to [nostrClient] and [cache].
  PeopleListsRepositoryImpl({
    required NostrClient nostrClient,
    required LocalPeopleListsCache cache,
    BlockedPeopleListOwnerFilter? blockFilter,
    FunnelcakeApiClient? funnelcakeApiClient,
    List<String> discoveryRelayUrls = const [],
  }) : _nostrClient = nostrClient,
       _cache = cache,
       _blockFilter = blockFilter,
       _funnelcakeApiClient = funnelcakeApiClient,
       _discoveryRelayUrls = discoveryRelayUrls;

  final NostrClient _nostrClient;
  final LocalPeopleListsCache _cache;
  final BlockedPeopleListOwnerFilter? _blockFilter;
  final Map<String, Future<void>> _ownerOperations = {};

  Future<T> _serializeOwner<T>(
    String ownerPubkey,
    Future<T> Function() operation,
  ) async {
    final previous = _ownerOperations[ownerPubkey];
    final completed = Completer<void>();
    _ownerOperations[ownerPubkey] = completed.future;
    try {
      if (previous != null) await previous;
      return await operation();
    } finally {
      completed.complete();
      if (identical(_ownerOperations[ownerPubkey], completed.future)) {
        unawaited(_ownerOperations.remove(ownerPubkey));
      }
    }
  }

  Future<PeopleListPublishResult> _serializeMutation(
    String ownerPubkey,
    Future<PeopleListPublishResult> Function() operation,
  ) => _serializeOwner(ownerPubkey, () async {
    try {
      return await operation();
    } on Object catch (error, stackTrace) {
      Log.error(
        'People-list change for ${pubkeyForLogs(ownerPubkey)} threw',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      return PeopleListPublishResult.failed(error: error);
    }
  });

  /// Reports a refusal to publish as a failed result, with the reason logged.
  ///
  /// Every refusal here is a path where the caller sees only a generic
  /// failure, so the reason has nowhere else to surface.
  PeopleListPublishResult _refuse(String listId, String reason) {
    Log.warning(
      'Not publishing a change to people list $listId: $reason',
      name: _logName,
      category: LogCategory.relay,
    );
    return const PeopleListPublishResult.failed();
  }

  /// Avoid walking an imported future timestamp arbitrarily far forward.
  /// This application bound is not a claim about any relay's clock tolerance;
  /// a relay can still reject a nearer revision and the write then fails.
  static const _maxRevisionLead = Duration(minutes: 1);

  static int _revisionTimestamp(UserList? previous) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final next = previous == null
        ? now
        : previous.updatedAt.millisecondsSinceEpoch ~/ 1000 + 1;
    if (next > now + _maxRevisionLead.inSeconds) {
      throw StateError('People-list revision is too far ahead of this clock');
    }
    return next > now ? next : now;
  }

  /// Answers which list authors have posted on Divine. `null` skips the
  /// check, which is how a build without Funnelcake still discovers lists.
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// Where public lists are discovered and searched. Empty reads the whole
  /// pool, which for every account includes the NIP-65 indexer relays, and
  /// those hold every client's follow sets: the newest kind-30000 events
  /// there are mostly lists nobody on Divine is in. The Divine relay alone
  /// holds what Divine's own clients publish. A list named by coordinate —
  /// a deep link, a followed list's refresh — is still read from the whole
  /// pool, since it cannot be noise.
  final List<String> _discoveryRelayUrls;

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
  Future<void> syncOwner({required String ownerPubkey}) =>
      _serializeOwner(ownerPubkey, () async {
        if (!await _reconcileOwner(ownerPubkey)) {
          throw const PublicPeopleListReadUnavailableException();
        }
      });

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
      // Read the record rather than the list: whether the cached row carries a
      // publish source decides whether a relay revision may replace it.
      final current = await _cache.readRecord(
        ownerPubkey: ownerPubkey,
        listId: list.id,
      );
      if (current != null && !_shouldReplaceCached(current, list)) {
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
  }) => _serializeMutation(ownerPubkey, () async {
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
  });

  @override
  Future<PeopleListPublishResult> updateList({
    required String ownerPubkey,
    required String listId,
    required String name,
    required String description,
  }) => _serializeMutation(ownerPubkey, () async {
    final title = name.trim();
    final summary = description.trim();
    if (title.isEmpty) return _refuse(listId, 'the title is empty');
    if (!await _reconcileOwner(ownerPubkey)) {
      return _refuse(listId, 'the owner read was inconclusive');
    }
    final record = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (record == null) return _refuse(listId, 'the list is not cached');
    if (!record.hasPublishSource) {
      return _refuse(
        listId,
        'the cached row predates source preservation, so no complete '
        'replacement can be built from it',
      );
    }
    final existing = record.list;
    if (existing.name == title && (existing.description ?? '') == summary) {
      return const PeopleListPublishResult.noop();
    }
    // Only metadata owned by this operation changes. The codec carries
    // through every other source tag, including member relay hints, and the
    // opaque encrypted content without trying to reinterpret either.
    final tags = <List<String>>[
      for (final tag in record.sourceTags!)
        if (tag.isEmpty || (tag.first != 'title' && tag.first != 'description'))
          List<String>.of(tag),
      ['title', title],
      if (summary.isNotEmpty) ['description', summary],
    ];
    return _publishListReplacement(
      ownerPubkey: ownerPubkey,
      list: existing,
      previous: existing,
      sourceTags: tags,
      sourceContent: record.sourceContent,
    );
  });

  @override
  Future<PeopleListPublishResult> addPubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) => _serializeMutation(
    ownerPubkey,
    () => _addPubkey(ownerPubkey: ownerPubkey, listId: listId, pubkey: pubkey),
  );

  Future<PeopleListPublishResult> _addPubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) async {
    // A replacement built on a stale cache drops members only the relay has.
    if (!await _reconcileOwner(ownerPubkey)) {
      return _refuse(listId, 'the owner read was inconclusive');
    }
    final record = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (record == null) return _refuse(listId, 'the list is not cached');
    final existing = record.list;
    if (existing.pubkeys.contains(pubkey)) {
      return const PeopleListPublishResult.noop();
    }
    if (!record.hasPublishSource) {
      Log.warning(
        'Cannot add a member of people list $listId: the cached row '
        'predates source preservation, so no complete replacement '
        'can be built from it',
        name: _logName,
        category: LogCategory.relay,
      );
      return const PeopleListPublishResult.failed();
    }
    final updated = existing.copyWith(
      pubkeys: [...existing.pubkeys, pubkey],
      updatedAt: DateTime.now().toUtc(),
    );
    return _publishListReplacement(
      ownerPubkey: ownerPubkey,
      list: updated,
      previous: existing,
      sourceTags: record.sourceTags,
      sourceContent: record.sourceContent,
    );
  }

  @override
  Future<PeopleListPublishResult> removePubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) => _serializeMutation(
    ownerPubkey,
    () =>
        _removePubkey(ownerPubkey: ownerPubkey, listId: listId, pubkey: pubkey),
  );

  Future<PeopleListPublishResult> _removePubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) async {
    // A replacement built on a stale cache drops members only the relay has.
    if (!await _reconcileOwner(ownerPubkey)) {
      return _refuse(listId, 'the owner read was inconclusive');
    }
    final record = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (record == null) return _refuse(listId, 'the list is not cached');
    final existing = record.list;
    if (!existing.pubkeys.contains(pubkey)) {
      return const PeopleListPublishResult.noop();
    }
    if (!record.hasPublishSource) {
      Log.warning(
        'Cannot remove a member of people list $listId: the cached row '
        'predates source preservation, so no complete replacement '
        'can be built from it',
        name: _logName,
        category: LogCategory.relay,
      );
      return const PeopleListPublishResult.failed();
    }
    final updated = existing.copyWith(
      pubkeys: existing.pubkeys.where((p) => p != pubkey).toList(),
      updatedAt: DateTime.now().toUtc(),
    );
    return _publishListReplacement(
      ownerPubkey: ownerPubkey,
      list: updated,
      previous: existing,
      sourceTags: record.sourceTags,
      sourceContent: record.sourceContent,
    );
  }

  @override
  Future<PeopleListPublishResult> deleteList({
    required String ownerPubkey,
    required String listId,
  }) => _serializeMutation(
    ownerPubkey,
    () => _deleteList(ownerPubkey: ownerPubkey, listId: listId),
  );

  Future<PeopleListPublishResult> _deleteList({
    required String ownerPubkey,
    required String listId,
  }) async {
    if (!await _reconcileOwner(ownerPubkey)) {
      return _refuse(listId, 'the owner read was inconclusive');
    }
    final record = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    final createdAt = _revisionTimestamp(record?.list);
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
      createdAt: createdAt,
    );

    try {
      final outcome = await _nostrClient.publishEventAwaitOk(event);
      if (!outcome.acceptedByAny) {
        return const PeopleListPublishResult.failed();
      }
      await _cache.markDeleted(
        ownerPubkey: ownerPubkey,
        listId: listId,
        deletedAt: DateTime.fromMillisecondsSinceEpoch(
          event.createdAt * 1000,
          isUtc: true,
        ),
      );
      return PeopleListPublishResult.submitted(eventId: event.id);
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
    String? viewerPubkey,
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) return;

    final lowerQuery = trimmed.toLowerCase();
    final results = await _queryPublicLists(
      limit: limit > 500 ? limit : 500,
      logContext: 'for "$trimmed"',
      discovery: true,
      keepAuthor: viewerPubkey,
      where: (list) =>
          list.name.toLowerCase().contains(lowerQuery) ||
          (list.description?.toLowerCase().contains(lowerQuery) ?? false),
    );

    // The candidate window is independent of the displayed result limit.
    // Keep main's deterministic revision/coordinate order before that cut.
    results.sort(_newestFirst);
    if (results.isNotEmpty) {
      yield List.unmodifiable(results.take(limit));
    }
  }

  @override
  Future<List<PeopleListSearchResult>> discoverPublicLists({
    int limit = 50,
    String? excludeAuthor,
  }) async {
    final results = await _queryPublicLists(
      limit: limit,
      logContext: 'for discovery',
      discovery: true,
      excludeAuthor: excludeAuthor,
    );
    results.sort((a, b) => b.list.updatedAt.compareTo(a.list.updatedAt));
    return List.unmodifiable(results);
  }

  static int _newestFirst(PeopleListSearchResult a, PeopleListSearchResult b) {
    final byRevision = b.list.updatedAt.compareTo(a.list.updatedAt);
    return byRevision != 0
        ? byRevision
        : a.addressableId.compareTo(b.addressableId);
  }

  @override
  Future<UserList?> fetchPublicList({
    required String ownerPubkey,
    required String listId,
  }) async {
    final results = await _queryPublicLists(
      limit: 10,
      logContext: 'for ${pubkeyForLogs(ownerPubkey)}/$listId',
      author: ownerPubkey,
      dTag: listId,
    );
    for (final result in results) {
      if (result.ownerPubkey == ownerPubkey && result.list.id == listId) {
        // Someone else's list: the members render, the owner affordances
        // (add people, delete) must not.
        return result.list.copyWith(isEditable: false);
      }
    }
    return null;
  }

  /// Shared relay query + decode + filter + coordinate-dedup pipeline behind
  /// [searchPublicLists], [discoverPublicLists], and [fetchPublicList].
  ///
  /// A [discovery] read is an open one — no author, no `d` tag — so it goes
  /// to the discovery relays alone, without the client's local cache, and
  /// its results pass the Divine author check ([_keepDivineAuthors]).
  Future<List<PeopleListSearchResult>> _queryPublicLists({
    required int limit,
    required String logContext,
    bool discovery = false,
    bool Function(UserList list)? where,
    String? excludeAuthor,
    String? keepAuthor,
    String? author,
    String? dTag,
  }) async {
    final scoped = discovery && _discoveryRelayUrls.isNotEmpty;
    final List<Event> events;
    try {
      final read = await _nostrClient.queryEventsDetailed(
        [
          Filter(
            kinds: const [Nip51PeopleListCodec.kind],
            limit: limit,
            authors: author == null ? null : [author],
            d: dTag == null ? null : [dTag],
          ),
        ],
        tempRelays: scoped ? _discoveryRelayUrls : null,
        relayTypes: scoped ? const [RelayType.temp] : RelayType.all,
        // Cached rows came from whichever relays answered earlier reads, so
        // they would bring the public relays' sets back in.
        useCache: !scoped,
        timeout: kPublicPeopleListsRelayReadTimeout,
        requireAllRelaysSettled: true,
      );
      if (read.events.isEmpty && (read.timedOut || read.noRelays)) {
        throw const PublicPeopleListReadUnavailableException();
      }
      events = read.events;
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to query public people lists $logContext',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    final seen = <String, PeopleListSearchResult>{};
    for (final event in events) {
      if (excludeAuthor != null && event.pubkey == excludeAuthor) continue;
      final blockFilter = _blockFilter;
      if (blockFilter != null && blockFilter(event.pubkey)) continue;

      final list = Nip51PeopleListCodec.decode(event);
      if (list == null) continue;

      final result = PeopleListSearchResult(
        ownerPubkey: event.pubkey,
        list: list,
      );
      final existing = seen[result.addressableId];
      if (existing != null && !_supersedes(list, existing.list)) {
        continue;
      }
      seen[result.addressableId] = result;
    }

    // Select the latest revision before filtering. An empty or renamed
    // replacement must not revive an older discoverable version.
    if (!discovery) return seen.values.toList();
    final results = seen.values.where((result) {
      final list = result.list;
      return list.pubkeys.isNotEmpty &&
          !Nip51PeopleListCodec.machineryDTags.contains(list.id) &&
          (where == null || where(list));
    }).toList();
    return _keepDivineAuthors(results, keepAuthor: keepAuthor);
  }

  /// Keeps the lists whose author has posted on Divine, and [keepAuthor]'s.
  ///
  /// Kind 30000 is every Nostr client's follow-set kind, so a list's members
  /// say nothing about Divine; its author having posted here does. Authors
  /// are asked about a page at a time. Without Funnelcake every list is
  /// kept, and so is every list when the check itself fails, with a warning:
  /// the unfiltered gallery is what shipped before this check, while an
  /// empty one would claim there are no lists when the relay just listed
  /// them.
  Future<List<PeopleListSearchResult>> _keepDivineAuthors(
    List<PeopleListSearchResult> lists, {
    String? keepAuthor,
  }) async {
    final api = _funnelcakeApiClient;
    if (api == null || !api.isAvailable || lists.isEmpty) return lists;
    final authors = {
      for (final list in lists)
        if (list.ownerPubkey != keepAuthor) list.ownerPubkey,
    }.toList();
    if (authors.isEmpty) return lists;

    final Set<String> posted;
    try {
      final pages = await Future.wait([
        for (
          var start = 0;
          start < authors.length;
          start += _bulkProfilesPageSize
        )
          api.getBulkProfiles(
            authors.skip(start).take(_bulkProfilesPageSize).toList(),
          ),
      ]);
      posted = {
        for (final page in pages)
          for (final MapEntry(key: pubkey, value: profile)
              in page.profiles.entries)
            if ((profile.stats?.videoCount ?? 0) > 0) pubkey.toLowerCase(),
      };
    } on Exception catch (error, stackTrace) {
      Log.warning(
        'Could not check which public people list authors have posted on '
        'Divine; keeping every list',
        name: _logName,
        category: LogCategory.api,
        error: error,
        stackTrace: stackTrace,
      );
      return lists;
    }

    return [
      for (final list in lists)
        if (list.ownerPubkey == keepAuthor ||
            posted.contains(list.ownerPubkey.toLowerCase()))
          list,
    ];
  }

  Future<PeopleListPublishResult> _publishListReplacement({
    required String ownerPubkey,
    required UserList list,
    UserList? previous,
    List<List<String>>? sourceTags,
    String? sourceContent,
  }) async {
    try {
      // encode throws ArgumentError on a malformed or mismatched source, so
      // it belongs inside the catch: callers only ever see the documented
      // failure result, never a raw programming-invariant throw.
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
        createdAt: _revisionTimestamp(previous),
      );
      final outcome = await _nostrClient.publishEventAwaitOk(event);
      if (!outcome.acceptedByAny) {
        return const PeopleListPublishResult.failed();
      }
      final persisted = Nip51PeopleListCodec.decode(event)!;
      // Cache what was published, not what was handed to the client: the
      // client rebinds event.tags while applying the NIP-89 client tag, so the
      // payload never sees it. Storing the payload would pair sourceTags with
      // a nostrEventId those tags cannot hash to.
      await _cache.putList(
        ownerPubkey: ownerPubkey,
        list: persisted,
        receivedAt: DateTime.now().toUtc(),
        sourceTags: event.tags,
        sourceContent: event.content,
      );
      return PeopleListPublishResult.submitted(eventId: event.id);
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

  /// Whether relay revision [incoming] should replace cached record [current].
  ///
  /// [UserList.updatedAt] is derived from the relay event's `created_at` by
  /// [Nip51PeopleListCodec], so comparing the two normally detects a stale
  /// relay echo. If the codec ever stops sourcing `updatedAt` from
  /// `created_at`, revisit this guard.
  ///
  /// A row written before this repository preserved publish sources is the
  /// exception. Its `updatedAt` is the millisecond `DateTime.now()` the
  /// publish stamped, so it always reads as newer than the second-resolution
  /// `created_at` of the very event it came from — and with no source tags it
  /// can never drive another membership edit. A matching `nostrEventId` proves
  /// the relay holds that same event, so adopting it loses nothing and is what
  /// keeps the list editable.
  static bool _shouldReplaceCached(
    CachedPeopleListRecord current,
    UserList incoming,
  ) {
    final cached = current.list;
    if (cached.updatedAt.isAfter(incoming.updatedAt)) {
      return !current.hasPublishSource &&
          cached.nostrEventId != null &&
          cached.nostrEventId == incoming.nostrEventId;
    }
    // NIP-01 breaks a created_at tie on the lowest event id. If either id is
    // absent, this guard does not apply and the incoming revision is adopted,
    // preserving the existing behavior for incomplete identifiers.
    final cachedId = cached.nostrEventId;
    final incomingId = incoming.nostrEventId;
    if (cached.updatedAt == incoming.updatedAt &&
        cachedId != null &&
        incomingId != null &&
        cachedId != incomingId &&
        cachedId.compareTo(incomingId) < 0) {
      return false;
    }
    return true;
  }

  /// Whether revision [candidate] supersedes [selected] under NIP-01
  /// replaceable-event ordering: the later `updatedAt` wins, and a tie is
  /// broken on the lowest event id. An absent id on either side leaves the tie
  /// unbroken, so the already-selected revision is kept.
  static bool _supersedes(UserList candidate, UserList selected) {
    if (candidate.updatedAt != selected.updatedAt) {
      return candidate.updatedAt.isAfter(selected.updatedAt);
    }
    final candidateId = candidate.nostrEventId;
    final selectedId = selected.nostrEventId;
    if (candidateId == null || selectedId == null) return false;
    return candidateId.compareTo(selectedId) < 0;
  }

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
