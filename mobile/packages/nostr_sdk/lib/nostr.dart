import 'dart:async';
import 'dart:developer';

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
import 'src/relay/paged_read_cursor.dart';
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
  /// [RelayDiagnosticSite.queryCompletion] line: from the pool for a read it
  /// saw, and from here under [RelayDiagnostic.clientScope] for one whose
  /// deadline had already passed, which never reaches the pool.
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
  /// Each page is a read that every relay taking its REQ must settle. For
  /// each relay that sent it an event, the relay pool reports the oldest
  /// `created_at` among what it sent and whether the relay may have stopped
  /// at its result-size limit, counting events the block list hid. A relay
  /// that sent a frame the pool rejected, one that is not an event or not
  /// validly signed, may have: that frame took a slot of its limit. A relay
  /// sends its newest events first, so it has sent everything it holds after
  /// that oldest event. Cache relays do not count, and events already
  /// collected are dropped by event id.
  ///
  /// * A relay that sent the previous page an event, and did not take this
  ///   page's REQ, stops the walk incomplete: the walk was following that
  ///   relay, and has asked it nothing below the cursor.
  /// * A relay that takes a page's REQ after missing the first page's stops
  ///   the walk incomplete: every page it did take asked only for events at
  ///   or below that page's cursor, so its newer events were never read.
  /// * A relay whose oldest event is in the cursor's second, and that may be
  ///   capped, stops the walk incomplete: it may hold more events in that
  ///   second than any `until` can reach.
  /// * A relay that may be capped on a page it sent no matching event to
  ///   stops the walk incomplete: it named no `created_at` for the cursor to
  ///   follow, so no later page's `until` is known to be below what it
  ///   withheld. A relay that answered a page entirely outside the filter,
  ///   entirely with frames the pool rejected, or with a NIP-67 `more` hint
  ///   and no events is such a relay.
  /// * Otherwise the next page starts at the latest of the relays' oldest
  ///   `created_at`, inclusive, so a second a page split is asked for again.
  ///   An uncapped relay whose oldest event is in the cursor's second counts
  ///   one second below it, so the walk never moves past what it may still
  ///   hold below that second.
  /// * A page on which no relay sent an event ends the walk, complete unless
  ///   a relay may be capped. So does a page whose next `until` would fall
  ///   below [filter]'s `since`, and that page is never asked for: nothing
  ///   below `since` can match, and a relay may refuse a filter that says so.
  ///
  /// The walk also ends complete on a settled page confirmed exhaustive by
  /// NIP-67 `finish`, unless a relay it was following missed that page, and
  /// stops incomplete, keeping what it collected, on the first page that
  /// does not settle. Whenever a page stops the walk incomplete, its
  /// [QueryEnd] is [PagedQueryResult.stoppedBy]. The walk also stops
  /// incomplete after [maxPages] pages, or once [deadline] has passed. Each
  /// page gets [pageTimeout], cut short by [deadline].
  ///
  /// Four cases can still lose events while the walk reports complete:
  ///
  /// * A relay that stops short of [pageSize] without saying so, and holds
  ///   more events in one second than its cap, can lose the rest of that
  ///   second, since nothing marks its page capped. A NIP-11 `max_limit` or a
  ///   NIP-67 `more` hint from the relay removes that ambiguity. A relay that
  ///   sends a page nothing at all is that case at its limit: silence reads
  ///   as holding nothing, and a `max_limit` has no count to measure against,
  ///   so only a `more` hint can mark it capped.
  /// * The walk takes a relay's page to be its newest matching events, as
  ///   NIP-01 assumes of a `limit`. A relay that answers with others, as a
  ///   NIP-50 search ranked by relevance may, can have events skipped.
  /// * A frame the pool cannot tie to any read, one that names no
  ///   subscription or does not decode, does not mark its relay capped.
  /// * Like [readEvents], the walk answers for the relays that take part in
  ///   it: a relay that takes no page's REQ at all is never read, and no page
  ///   names it, so nothing tells the walk it was missed.
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
    final since = filter['since'] as int?;
    var previousRelays = const <QueryRelaySummary>[];
    var firstSentTo = const <String>[];
    var pages = 0;

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
      final read = await _read(
        [
          {...filter, 'limit': pageSize, if (until != null) 'until': until},
        ],
        id: null,
        tempRelays: tempRelays,
        relayTypes: relayTypes,
        sendAfterAuth: false,
        deadline: pageDeadline,
        requireAllRelaysSettled: true,
      );
      final page = read.result;
      collected.addAll([
        for (final event in page.events)
          if (seenIds.add(event.id)) event,
      ]);
      // Unknown only when the deadline ended the page, which never settles.
      final sentTo = read.sentTo ?? const <String>[];
      if (pages == 1) firstSentTo = sentTo;
      switch (nextPagedReadStep(
        cursor: until,
        since: since,
        relays: read.relays,
        previousRelays: previousRelays,
        sentTo: sentTo,
        firstSentTo: firstSentTo,
        settled: page.isComplete,
        confirmedExhaustive: page.confirmedExhaustive,
        possiblyCapped: page.possiblyCapped,
        cappedWithoutEvents: read.cappedWithoutEvents,
      )) {
        case ReadPageAt(until: final next):
          until = next;
          previousRelays = read.relays;
        case EndPagedRead(isComplete: true):
          return walked(isComplete: true);
        case EndPagedRead():
          return walked(isComplete: false, stoppedBy: page.endedBy);
      }
    }
    return walked(isComplete: false);
  }

  /// Set [requireAllRelaysSettled] when an incomplete answer must be reported
  /// as `timedOut` rather than as a result — see [RelayPool.query].
  ///
  /// `events` holds whatever had arrived when the read stopped, even when
  /// `timedOut` is `true` — a deadline no longer empties the answer, it only
  /// marks it incomplete.
  ///
  /// `noRelaysParticipated` reports that no relay took the REQ at all, which
  /// an empty `events` on its own cannot distinguish from every relay holding
  /// nothing. It stays `false` when the fan-out itself ran out of time, since
  /// that leaves participation genuinely unknown.
  ///
  /// It runs the same read as [readEvents] and maps how that read ended onto
  /// the two flags. Use [readEvents] directly for the full [QueryResult], or
  /// [readAllEvents] to walk every event a filter matches across many pages
  /// instead of one capped read.
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
          (requireAllRelaysSettled && !read.result.isComplete),
      noRelaysParticipated: noRelaysParticipated,
    );
  }

  /// Reads events matching [filters] and returns them as a plain list.
  ///
  /// A read that stops before it finishes — [timeout] elapsing, a relay
  /// closing the subscription, or a socket dropping — still returns whatever
  /// events had already arrived rather than an empty list; the returned list
  /// alone does not say whether the read finished. Use [readEvents] for the
  /// full [QueryResult], or [queryEventsDetailed] for a lighter
  /// timed-out/no-relays summary. Use [readAllEvents] to walk every event a
  /// filter matches across many pages instead of one capped read.
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

  /// Runs one read for [readEvents], its wrappers and [readAllEvents]. It
  /// says whether the caller's deadline is what ended it, what each relay
  /// sent, as the pool counted it, which relays may have been capped without
  /// sending anything, and which relays took the REQ: null when the deadline
  /// ended the read, which may be before the fan-out finished.
  Future<
    ({
      QueryResult result,
      bool endedAtDeadline,
      List<QueryRelaySummary> relays,
      List<String> cappedWithoutEvents,
      List<String>? sentTo,
    })
  >
  _read(
    List<Map<String, dynamic>> filters, {
    required String? id,
    required List<String>? tempRelays,
    required List<int> relayTypes,
    required bool sendAfterAuth,
    required DateTime deadline,
    required bool requireAllRelaysSettled,
  }) async {
    // [RelayPool.query] rejects an empty filter list, and the deadline branch
    // below returns before it is ever called. Validate here so a read is
    // rejected the same way whichever path it takes.
    if (filters.isEmpty) {
      throw ArgumentError('No filters given', 'filters');
    }

    // A deadline that has already passed ends the read before it starts. The
    // client's query pool can hand a slot over with the caller's budget fully
    // spent by the wait; a REQ written then was unsubscribed a few
    // milliseconds later, and the pool read those milliseconds of silence as
    // every relay having swallowed the request (#7301). Nothing is asked of
    // the relays, so the outcome is the deadline's with no relay in it — the
    // same answer the timer below would have given.
    final subscriptionId = id ?? StringUtil.rndNameStr(16);
    final now = DateTime.now();
    if (!deadline.isAfter(now)) {
      // The pool files a completion line for every read it sees; this one
      // it never will, so the line is filed here — under [clientScope],
      // which exists so a layer above the pool cannot spend the pool's
      // rate-limit budget on reads no relay was asked about.
      emitRelayDiagnostic(
        _pool.diagnosticsSink,
        RelayDiagnostic(
          site: RelayDiagnosticSite.queryCompletion,
          level: RelayDiagnosticLevel.warning,
          relayUrl: RelayDiagnostic.clientScope,
          message:
              'Query $subscriptionId ended deadline before any REQ was '
              'written: the deadline had already passed by '
              '${now.difference(deadline).inMilliseconds}ms',
        ),
      );
      // Growable, like every other exit: the normal path hands back
      // [EventMemBox.all], which callers are free to sort or append to.
      return (
        result: QueryResult(events: <Event>[], endedBy: QueryEnd.deadline),
        endedAtDeadline: true,
        relays: <QueryRelaySummary>[],
        cappedWithoutEvents: <String>[],
        sentTo: null,
      );
    }

    final eventBox = EventMemBox(sortAfterAdd: false);
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
      final fanout = _pool.query(
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
      );
      // Not awaited: the deadline must be able to end the read while the
      // fan-out is still writing the REQ to a slow relay.
      unawaited(
        fanout.then<void>(
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
        relays: outcome.relays,
        cappedWithoutEvents: outcome.cappedWithoutEvents,
        // The pool completes a read only once its fan-out has finished, so
        // this does not wait on a relay.
        sentTo: endedAtDeadline ? null : (await fanout).sentTo,
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
