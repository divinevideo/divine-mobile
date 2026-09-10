import 'dart:async';
import 'dart:developer';

import 'count_response.dart';
import 'event.dart';
import 'event_kind.dart';
import 'event_mem_box.dart';
import 'nip02/contact_list.dart';
import 'relay/event_filter.dart';
import 'relay/publish_outcome.dart';
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

  /// Set [requireAllRelaysSettled] when an incomplete answer must be reported
  /// as `timedOut` rather than as a result — see [RelayPool.query].
  ///
  /// `noRelaysParticipated` reports that no relay took the REQ at all, which
  /// an empty `events` on its own cannot distinguish from every relay holding
  /// nothing. It stays `false` when the fan-out itself ran out of time, since
  /// that leaves participation genuinely unknown.
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
    final eventBox = EventMemBox(sortAfterAdd: false);
    final completer = Completer<void>();
    final subscriptionId = id ?? StringUtil.rndNameStr(16);
    final deadline = DateTime.now().add(timeout);
    var timedOut = false;
    var noRelaysParticipated = false;

    Duration remainingTimeout() {
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative || remaining == Duration.zero) {
        return Duration.zero;
      }
      return remaining;
    }

    try {
      final fanout = await query(
        filters,
        id: subscriptionId,
        tempRelays: tempRelays,
        relayTypes: relayTypes,
        sendAfterAuth: sendAfterAuth,
        requireAllRelaysSettled: requireAllRelaysSettled,
        (event) {
          eventBox.add(event);
        },
        onComplete: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ).timeout(remainingTimeout());
      noRelaysParticipated = fanout.sentTo.isEmpty;
      await completer.future.timeout(remainingTimeout());
    } on TimeoutException {
      timedOut = true;
      unsubscribe(subscriptionId);
    }

    return (
      events: eventBox.all(),
      // A full-settlement caller is about to replace what it read, so a
      // fan-out no relay took stays as inconclusive as a relay that never
      // answered. A default read is content with what the reachable relays
      // hold and keeps its prompt empty answer.
      timedOut: timedOut || (requireAllRelaysSettled && noRelaysParticipated),
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
    final result = await queryEventsDetailed(
      filters,
      id: id,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      timeout: timeout,
    );
    return result.events;
  }

  /// Sends a COUNT request (NIP-45) to relays and returns the count.
  ///
  /// Unlike [queryEvents], this returns a single count rather than
  /// a list of events. Useful for follower counts, reaction counts, etc.
  ///
  /// Throws [CountNotSupportedException] if no relay supports NIP-45.
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
