import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'count_response.dart';
import 'event.dart';
import 'event_kind.dart';
import 'event_mem_box.dart';
import 'nip02/contact_list.dart';
import 'relay/event_filter.dart';
import 'relay/publish_outcome.dart';
import 'relay/query_outcome.dart';
import 'relay/query_result.dart';
import 'relay/relay.dart';
import 'relay/relay_diagnostics.dart';
import 'relay/relay_pool.dart';
import 'relay/relay_type.dart';
import 'relay/signature_verification_policy.dart';
import 'relay/web_socket_connection_manager.dart';
import 'signer/nostr_signer.dart';
import 'utils/string_util.dart';

class Nostr {
  late RelayPool _pool;

  NostrSigner nostrSigner;

  /// Cached public key from the signer - single source of truth
  String _cachedPublicKey = '';

  Function(String, String)? onNotice;

  Relay Function(String) tempRelayGener;

  Nostr(
    this.nostrSigner,
    List<EventFilter> eventFilters,
    this.tempRelayGener, {
    this.onNotice,
    WebSocketChannelFactory? channelFactory,
    RelayDiagnosticsSink? diagnosticsSink,
    SignatureVerificationPolicy signatureVerificationPolicy =
        SignatureVerificationPolicy.all,
  }) {
    // Public key starts empty - call refreshPublicKey() after construction
    // to populate from the signer (single source of truth).
    _pool = RelayPool(
      this,
      eventFilters,
      tempRelayGener,
      onNotice: onNotice,
      diagnosticsSink: diagnosticsSink,
      signatureVerificationPolicy: signatureVerificationPolicy,
    );
  }

  /// Public key of the client.
  ///
  /// Returns the cached public key. The signer is the source of truth;
  /// use [refreshPublicKey] to update the cache from the signer.
  String get publicKey => _cachedPublicKey;

  /// Refresh the cached public key from the signer.
  ///
  /// This is useful when the signer's key may have changed.
  Future<void> refreshPublicKey() async {
    final key = await nostrSigner.getPublicKey();
    _cachedPublicKey = key ?? '';
  }

  /// Returns the cached public key, refreshing from the signer if empty.
  ///
  /// Throws [StateError] if the signer has no public key available
  /// (e.g. not yet configured or session expired).
  Future<String> ensurePublicKey() async {
    if (_cachedPublicKey.isEmpty) {
      await refreshPublicKey();
    }
    if (_cachedPublicKey.isEmpty) {
      throw StateError(
        'No public key available — signer may not be configured',
      );
    }
    return _cachedPublicKey;
  }

  RelayPool get relayPool => _pool;

  Future<Event?> sendLike(
    String id, {
    String? pubkey,
    String? content,
    String? addressableId,
    int? targetKind,
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    content ??= "+";

    final tags = <List<String>>[
      ["e", id],
    ];

    if (addressableId != null && addressableId.isNotEmpty) {
      tags.add(["a", addressableId]);
    }
    if (pubkey != null && pubkey.isNotEmpty) {
      tags.add(["p", pubkey]);
    }
    if (targetKind != null) {
      tags.add(["k", targetKind.toString()]);
    }

    final pk = await ensurePublicKey();
    Event event = Event(pk, EventKind.reaction, tags, content);
    return await sendEvent(
      event,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  Future<Event?> deleteEvent(
    String eventId, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final pk = await ensurePublicKey();
    Event event = Event(pk, EventKind.eventDeletion, [
      ["e", eventId],
    ], "delete");
    return await sendEvent(
      event,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  Future<Event?> deleteEvents(
    List<String> eventIds, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    List<List<String>> tags = [];
    for (var eventId in eventIds) {
      tags.add(["e", eventId]);
    }

    final pk = await ensurePublicKey();
    Event event = Event(pk, EventKind.eventDeletion, tags, "delete");
    return await sendEvent(
      event,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  Future<Event?> sendRepost(
    String id, {
    String? relayAddr,
    String content = "",
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    List<String> tag = ["e", id];
    if (StringUtil.isNotBlank(relayAddr)) {
      tag.add(relayAddr!);
    }
    final pk = await ensurePublicKey();
    Event event = Event(pk, EventKind.repost, [tag], content);
    return await sendEvent(
      event,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  Future<Event?> sendContactList(
    ContactList contacts,
    String content, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final tags = contacts.toJson();
    final pk = await ensurePublicKey();
    final event = Event(pk, EventKind.contactList, tags, content);
    return await sendEvent(
      event,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  Future<Event?> sendEvent(
    Event event, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    // Only sign if the event is not already signed
    if (StringUtil.isBlank(event.sig)) {
      await signEvent(event);
      if (StringUtil.isBlank(event.sig)) {
        return null;
      }
    }

    var result = await _pool.send(
      ["EVENT", event.toJson()],
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (result) {
      return event;
    }
    return null;
  }

  /// Sends an event and awaits `OK` confirmations from the targeted relays.
  ///
  /// Signs the event if needed, dispatches to relays, and returns a
  /// [PublishOutcome] describing per-relay acceptance, rejection and silence.
  ///
  /// The future completes once every relay the fan-out reached has answered,
  /// or a short settle window after the first answer, or at [timeout] —
  /// whichever comes first. It does **not** complete on the first acceptance,
  /// so an accepted publish that another relay refused reports both.
  ///
  /// Note that [timeout] bounds only the publish: signing happens first and
  /// its latency is additive.
  ///
  /// Returns `null` if signing failed.
  Future<PublishOutcome?> sendEventAwaitOk(
    Event event, {
    List<String>? tempRelays,
    List<String>? targetRelays,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (StringUtil.isBlank(event.sig)) {
      await signEvent(event);
      if (StringUtil.isBlank(event.sig)) {
        return null;
      }
    }

    return _pool.sendEventAwaitOk(
      ["EVENT", event.toJson()],
      eventId: event.id,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
      timeout: timeout,
    );
  }

  void checkEventSign(Event event) {
    if (StringUtil.isBlank(event.sig)) {
      throw StateError("Event is not signed");
    }
  }

  Future<void> signEvent(Event event) async {
    var ne = await nostrSigner.signEvent(event);
    if (ne != null) {
      event.id = ne.id;
      event.sig = ne.sig;
    }
  }

  Future<Event?> broadcase(
    Event event, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final result = await _pool.send(
      ["EVENT", event.toJson()],
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (result) {
      return event;
    }
    return null;
  }

  /// Marks the relay pool as closing so nothing opens another socket while
  /// the owner works its way through the rest of its teardown.
  ///
  /// [close] is the real teardown; this only has to run first, before the
  /// owner's first await. See [RelayPool.beginClose].
  void beginClose() {
    _pool.beginClose();
  }

  void close() {
    // Idempotent, and already done by an owner that called [beginClose] first;
    // repeated here so a direct [close] closes the same window.
    _pool.beginClose();
    _pool.removeAll();
    nostrSigner.close();
  }

  void addInitQuery(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
  }) {
    _pool.addInitQuery(filters, onEvent, id: id, onComplete: onComplete);
  }

  bool tempRelayHasSubscription(String relayAddr) {
    return _pool.tempRelayHasSubscription(relayAddr);
  }

  String subscribe(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth =
        false, // if relay not connected, it will send after auth
    void Function()? onEose,
    void Function(String reason)? onClosed,
  }) {
    return _pool.subscribe(
      filters,
      onEvent,
      id: id,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      onEose: onEose,
      onClosed: onClosed,
    );
  }

  void unsubscribe(String id) {
    _pool.unsubscribe(id);
  }

  /// Reads the events [filters] match, and reports how the read ended.
  ///
  /// The read ends at [deadline] — [timeout] from now when [deadline] is
  /// null — unless the relay pool completes it first, and either way it
  /// returns the events that had arrived. [QueryResult.endedBy] says how it
  /// ended.
  ///
  /// Set [requireAllRelaysSettled] when an incomplete answer must not
  /// complete the read — see [RelayPool.query]. Such a read then runs to its
  /// deadline rather than completing on the relays that answered first.
  ///
  /// A read that ends any other way than a complete, uncapped answer gets one
  /// [RelayDiagnosticSite.queryCompletion] line, from the pool.
  ///
  /// Throws [ArgumentError] when [filters] is empty.
  Future<QueryResult> readEvents(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    Duration timeout = const Duration(seconds: 5),
    DateTime? deadline,
    bool requireAllRelaysSettled = false,
  }) async {
    final read = await _read(
      filters,
      id: id,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      deadline: deadline ?? DateTime.now().add(timeout),
      requireAllRelaysSettled: requireAllRelaysSettled,
    );
    return read.result;
  }

  /// Reads every event [filter] matches, a page of [pageSize] at a time,
  /// walking back through the relays' history with an `until` cursor.
  ///
  /// Each page is a [readEvents] that every relay taking its REQ must settle.
  /// Where the next page starts depends on which relays filled this one, by
  /// sending `min(pageSize, max_limit)` events with `max_limit` from their
  /// NIP-11 document when known, since only a relay that filled its page may
  /// hold more:
  ///
  /// * When a relay filled the page, the cursor moves to the newest of those
  ///   relays' oldest `created_at`, inclusive. Every relay has then sent all
  ///   it holds above the cursor, and the events asked for again are dropped
  ///   by event id. When that is the cursor's own second, a relay filled the
  ///   page inside one second, which no `until` can page within: the cursor
  ///   steps one second back and the walk ends incomplete, since that second
  ///   may hold more.
  /// * When no relay filled the page, one more page asks for anything older
  ///   than every event returned. A relay may send fewer events than it
  ///   holds, so the walk is complete only once such a page comes back empty.
  ///
  /// An event counts for every relay that sent it; cached events do not move
  /// the cursor.
  ///
  /// The walk also ends complete on a settled page confirmed exhaustive by
  /// NIP-67 `finish`. It stops incomplete, keeping what it collected, on the
  /// first page that does not settle — whose [QueryEnd] is
  /// [PagedQueryResult.stoppedBy] — after [maxPages] pages, or once
  /// [deadline] has passed. Each page gets [pageTimeout], cut short by
  /// [deadline].
  ///
  /// [filter]'s own `limit` gives way to [pageSize], and its own `until`, if
  /// any, starts the walk.
  ///
  /// Throws [ArgumentError] when [pageSize] or [maxPages] is below 1.
  Future<PagedQueryResult> readAllEvents(
    Map<String, dynamic> filter, {
    int pageSize = 500,
    int maxPages = 50,
    Duration pageTimeout = const Duration(seconds: 10),
    DateTime? deadline,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
  }) async {
    if (pageSize < 1) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be at least 1');
    }
    if (maxPages < 1) {
      throw ArgumentError.value(maxPages, 'maxPages', 'must be at least 1');
    }
    final collected = <Event>[];
    final seenIds = <String>{};
    var until = filter['until'] as int?;
    var pages = 0;
    var skippedPartOfASecond = false;

    PagedQueryResult walked({required bool isComplete, QueryEnd? stoppedBy}) =>
        PagedQueryResult(
          events: collected,
          isComplete: isComplete,
          pages: pages,
          stoppedBy: stoppedBy,
        );

    while (pages < maxPages) {
      final now = DateTime.now();
      if (deadline != null && !now.isBefore(deadline)) break;
      var pageDeadline = now.add(pageTimeout);
      if (deadline != null && deadline.isBefore(pageDeadline)) {
        pageDeadline = deadline;
      }

      pages++;
      final page = await readEvents(
        [
          {...filter, 'limit': pageSize, if (until != null) 'until': until},
        ],
        tempRelays: tempRelays,
        relayTypes: relayTypes,
        deadline: pageDeadline,
        requireAllRelaysSettled: true,
      );
      final newEvents = [
        for (final event in page.events)
          if (seenIds.add(event.id)) event,
      ];
      collected.addAll(newEvents);

      if (!page.isComplete) {
        return walked(isComplete: false, stoppedBy: page.endedBy);
      }
      if (page.confirmedExhaustive) {
        return walked(isComplete: !skippedPartOfASecond);
      }
      final cursor = until;
      final reach = _pageReach(page.events, pageSize);
      final frontier = reach.fullFrontier;
      if (frontier != null && (cursor == null || frontier < cursor)) {
        until = frontier;
      } else if (frontier != null && cursor != null) {
        // A relay filled the page inside the cursor's own second, which no
        // `until` can page within.
        skippedPartOfASecond = true;
        until = cursor - 1;
      } else {
        final oldest = reach.oldestContribution;
        if (oldest == null) return walked(isComplete: !skippedPartOfASecond);
        until = oldest - 1;
      }
    }
    return walked(isComplete: false);
  }

  /// How far back each relay reached on one page of [readAllEvents], judged
  /// by the relays each event came from.
  ///
  /// `fullFrontier` is the latest of the oldest `created_at`s sent by the
  /// relays that filled the page, or null when none did. `oldestContribution`
  /// is the oldest `created_at` any relay sent, or null when none sent one.
  /// Cached events carry the relays they first came from rather than this
  /// page's, so they are left out.
  ({int? fullFrontier, int? oldestContribution}) _pageReach(
    List<Event> events,
    int pageSize,
  ) {
    final reach = <String, ({int count, int oldest})>{};
    for (final event in events) {
      if (event.cacheEvent) continue;
      for (final url in event.sources) {
        final seen = reach[url];
        reach[url] = seen == null
            ? (count: 1, oldest: event.createdAt)
            : (
                count: seen.count + 1,
                oldest: math.min(seen.oldest, event.createdAt),
              );
      }
    }
    int? fullFrontier;
    int? oldestContribution;
    for (final MapEntry(key: url, value: (:count, :oldest)) in reach.entries) {
      if (oldestContribution == null || oldest < oldestContribution) {
        oldestContribution = oldest;
      }
      final maxLimit = (getRelay(url) ?? getTempRelay(url))?.info?.maxLimit;
      final fillsAt = maxLimit == null
          ? pageSize
          : math.min(pageSize, maxLimit);
      if (count >= fillsAt && (fullFrontier == null || oldest > fullFrontier)) {
        fullFrontier = oldest;
      }
    }
    return (fullFrontier: fullFrontier, oldestContribution: oldestContribution);
  }

  /// Set [requireAllRelaysSettled] when an incomplete answer must be reported
  /// as `timedOut` rather than as a result — see [RelayPool.query].
  ///
  /// `noRelaysParticipated` reports that no relay took the REQ at all, which
  /// an empty `events` on its own cannot distinguish from every relay holding
  /// nothing. It stays `false` when the fan-out itself ran out of time, since
  /// that leaves participation genuinely unknown.
  ///
  /// It runs the same read as [readEvents] and maps how that read ended onto
  /// the two flags.
  Future<({List<Event> events, bool timedOut, bool noRelaysParticipated})>
  queryEventsDetailed(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    Duration timeout = const Duration(seconds: 5),
    bool requireAllRelaysSettled = false,
  }) async {
    final read = await _read(
      filters,
      id: id,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      deadline: DateTime.now().add(timeout),
      requireAllRelaysSettled: requireAllRelaysSettled,
    );
    final noRelaysParticipated = read.result.endedBy == QueryEnd.noRelay;
    return (
      events: read.result.events,
      // A deadline that ends the read is a timeout. That is every
      // [QueryEnd.deadline], and one [QueryEnd.noRelay] as well: noRelay
      // outranks the deadline, so a read no relay took still reads noRelay
      // when the pool waits out its deadline on a relay that saved the REQ
      // but failed to write it.
      //
      // A full-settlement caller is about to replace what it read, so a
      // fan-out no relay took stays as inconclusive as a relay that never
      // answered. A default read is content with what the reachable relays
      // hold and keeps its prompt empty answer.
      timedOut:
          read.endedAtDeadline ||
          (requireAllRelaysSettled && noRelaysParticipated),
      noRelaysParticipated: noRelaysParticipated,
    );
  }

  Future<List<Event>> queryEvents(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final result = await readEvents(
      filters,
      id: id,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      timeout: timeout,
    );
    return result.events;
  }

  /// Runs one read for [readEvents] and its wrappers, and says whether the
  /// caller's deadline is what ended it.
  Future<({QueryResult result, bool endedAtDeadline})> _read(
    List<Map<String, dynamic>> filters, {
    required String? id,
    required List<String>? tempRelays,
    required List<int> relayTypes,
    required bool sendAfterAuth,
    required DateTime deadline,
    required bool requireAllRelaysSettled,
  }) async {
    final eventBox = EventMemBox(sortAfterAdd: false);
    final subscriptionId = id ?? StringUtil.rndNameStr(16);
    final ended = Completer<QueryOutcome>();
    var endedAtDeadline = false;

    void endAtDeadline() {
      // The pool hands its outcome over synchronously as it completes the
      // read, so an [ended] already completed means the pool finished first.
      if (ended.isCompleted) return;
      endedAtDeadline = true;
      // Judged before unsubscribing, which forgets how each relay stood. A
      // null means something other than a completion dropped the pool's
      // record of the read, such as an unsubscribe of its id; the deadline is
      // still what ended it.
      final outcome = _pool.reportQueryDeadline(subscriptionId);
      unsubscribe(subscriptionId);
      ended.complete(outcome ?? const QueryOutcome(endedBy: QueryEnd.deadline));
    }

    // A deadline already past fires at once: a Timer treats it as zero.
    final deadlineTimer = Timer(
      deadline.difference(DateTime.now()),
      endAtDeadline,
    );
    try {
      // Not awaited: the deadline must be able to end the read while the
      // fan-out is still writing the REQ to a slow relay.
      unawaited(
        _pool
            .query(
              filters,
              (event) {
                eventBox.add(event);
              },
              id: subscriptionId,
              tempRelays: tempRelays,
              relayTypes: relayTypes,
              sendAfterAuth: sendAfterAuth,
              requireAllRelaysSettled: requireAllRelaysSettled,
              onOutcome: (outcome) {
                if (!ended.isCompleted) ended.complete(outcome);
              },
            )
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace stackTrace) {
                // An error after the read ended has no caller left to hear it.
                if (!ended.isCompleted) ended.completeError(error, stackTrace);
              },
            ),
      );
      final outcome = await ended.future;
      return (
        result: QueryResult(
          events: eventBox.all(),
          endedBy: outcome.endedBy,
          possiblyCapped: outcome.possiblyCapped,
          confirmedExhaustive: outcome.confirmedExhaustive,
        ),
        endedAtDeadline: endedAtDeadline,
      );
    } finally {
      deadlineTimer.cancel();
    }
  }

  /// Sends a COUNT request (NIP-45) to relays and returns the count.
  ///
  /// Unlike [queryEvents], this returns a single count rather than
  /// a list of events. Useful for follower counts, reaction counts, etc.
  ///
  /// Throws [CountNotSentException] when no relay accepted the COUNT, and
  /// [CountNotSupportedException] when relays accepted it but none answered.
  /// See [RelayPool.count].
  Future<CountResponse> countEvents(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return _pool.count(
      filters,
      id: id,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      timeout: timeout,
    );
  }

  /// See [RelayPool.query] for what `sentTo` means and when it is empty.
  Future<({String id, List<String> sentTo})> query(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool requireAllRelaysSettled = false,
  }) async {
    return await _pool.query(
      filters,
      onEvent,
      id: id,
      onComplete: onComplete,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      requireAllRelaysSettled: requireAllRelaysSettled,
    );
  }

  String queryByFilters(
    Map<String, List<Map<String, dynamic>>> filtersMap,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
  }) {
    return _pool.queryByFilters(
      filtersMap,
      onEvent,
      id: id,
      onComplete: onComplete,
    );
  }

  Future<bool> addRelay(
    Relay relay, {
    bool autoSubscribe = false,
    bool init = false,
    int relayType = RelayType.normal,
  }) async {
    return await _pool.add(
      relay,
      autoSubscribe: autoSubscribe,
      init: init,
      relayType: relayType,
    );
  }

  void removeRelay(String url, {int relayType = RelayType.normal}) {
    _pool.remove(url, relayType: relayType);
  }

  List<Relay> activeRelays() {
    return _pool.activeRelays();
  }

  Relay? getRelay(String url) {
    return _pool.getRelay(url);
  }

  Relay? getTempRelay(String url) {
    return _pool.getTempRelay(url);
  }

  void reconnect() {
    log("nostr reconnect");
    _pool.reconnect();
  }

  List<String> getExtralReadableRelays(
    List<String> extralRelays,
    int maxRelayNum,
  ) {
    return _pool.getExtralReadableRelays(extralRelays, maxRelayNum);
  }

  void removeTempRelay(String addr) {
    _pool.removeTempRelay(addr);
  }

  bool readable() {
    return _pool.readable();
  }

  bool writable() {
    return _pool.writable();
  }

  /// Configure a relay to always require authentication
  void setRelayAlwaysAuth(String relayUrl, bool alwaysAuth) {
    _pool.setRelayAlwaysAuth(relayUrl, alwaysAuth);
  }

  /// Configure multiple relays with authentication requirements
  void configureRelayAuth(Map<String, bool> relayAuthConfig) {
    _pool.configureRelayAuth(relayAuthConfig);
  }

  /// Get current authentication configuration for all relays
  Map<String, bool> getRelayAuthConfig() {
    return _pool.getRelayAuthConfig();
  }
}
