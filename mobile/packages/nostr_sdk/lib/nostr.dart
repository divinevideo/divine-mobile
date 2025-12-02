import 'dart:async';

import 'event.dart';
import 'event_kind.dart';
import 'event_mem_box.dart';
import 'nip02/contact_list.dart';
import 'relay/event_filter.dart';
import 'relay/relay.dart';
import 'relay/relay_pool.dart';
import 'relay/relay_type.dart';
import 'signer/nostr_signer.dart';
import 'signer/pubkey_only_nostr_signer.dart';
import 'utils/string_util.dart';

class Nostr {
  late RelayPool _pool;

  NostrSigner nostrSigner;

  final String _publicKey;

  Function(String, String)? onNotice;

  Relay Function(String) tempRelayGener;

  Nostr(this.nostrSigner, this._publicKey, List<EventFilter> eventFilters,
      this.tempRelayGener,
      {this.onNotice}) {
    _pool = RelayPool(this, eventFilters, tempRelayGener, onNotice: onNotice);
  }

  String get publicKey => _publicKey;

  RelayPool get relayPool => _pool;

  Future<Event?> sendLike(String id,
      {String? pubkey,
      String? content,
      List<String>? tempRelays,
      List<String>? targetRelays}) async {
    content ??= "+";

    Event event = Event(
        _publicKey,
        EventKind.REACTION,
        [
          ["e", id]
        ],
        content);
    return await sendEvent(event,
        tempRelays: tempRelays, targetRelays: targetRelays);
  }

  Future<Event?> deleteEvent(String eventId,
      {List<String>? tempRelays, List<String>? targetRelays}) async {
    Event event = Event(
        _publicKey,
        EventKind.EVENT_DELETION,
        [
          ["e", eventId]
        ],
        "delete");
    return await sendEvent(event,
        tempRelays: tempRelays, targetRelays: targetRelays);
  }

  Future<Event?> deleteEvents(List<String> eventIds,
      {List<String>? tempRelays, List<String>? targetRelays}) async {
    List<List<dynamic>> tags = [];
    for (var eventId in eventIds) {
      tags.add(["e", eventId]);
    }

    Event event = Event(_publicKey, EventKind.EVENT_DELETION, tags, "delete");
    return await sendEvent(event,
        tempRelays: tempRelays, targetRelays: targetRelays);
  }

  Future<Event?> sendRepost(String id,
      {String? relayAddr,
      String content = "",
      List<String>? tempRelays,
      List<String>? targetRelays}) async {
    List<dynamic> tag = ["e", id];
    if (StringUtil.isNotBlank(relayAddr)) {
      tag.add(relayAddr);
    }
    Event event = Event(_publicKey, EventKind.REPOST, [tag], content);
    return await sendEvent(event,
        tempRelays: tempRelays, targetRelays: targetRelays);
  }

  Future<Event?> sendContactList(ContactList contacts, String content,
      {List<String>? tempRelays, List<String>? targetRelays}) async {
    final tags = contacts.toJson();
    final event = Event(_publicKey, EventKind.CONTACT_LIST, tags, content);
    return await sendEvent(event,
        tempRelays: tempRelays, targetRelays: targetRelays);
  }

  Future<Event?> sendEvent(Event event,
      {List<String>? tempRelays, List<String>? targetRelays}) async {
    // Only sign if the event is not already signed
    if (StringUtil.isBlank(event.sig)) {
      await signEvent(event);
      if (StringUtil.isBlank(event.sig)) {
        return null;
      }
    }

    var result = _pool.send(
      ["EVENT", event.toJson()],
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (result) {
      return event;
    }
    return null;
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

  Event? broadcase(Event event,
      {List<String>? tempRelays, List<String>? targetRelays}) {
    var result = _pool.send(
      ["EVENT", event.toJson()],
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (result) {
      return event;
    }
    return null;
  }

  void close() {
    _pool.removeAll();
    nostrSigner.close();
  }

  void addInitQuery(List<Map<String, dynamic>> filters, Function(Event) onEvent,
      {String? id, Function? onComplete}) {
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
    List<int> relayTypes = RelayType.ALL,
    bool sendAfterAuth =
        false, // if relay not connected, it will send after auth
  }) {
    return _pool.subscribe(
      filters,
      onEvent,
      id: id,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
    );
  }

  void unsubscribe(String id) {
    _pool.unsubscribe(id);
  }

  Future<List<Event>> queryEvents(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.ALL,
    bool sendAfterAuth = false,
  }) async {
    var eventBox = EventMemBox(sortAfterAdd: false);
    var completer = Completer();

    query(
      filters,
      id: id,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      (event) {
        eventBox.add(event);
      },
      onComplete: () {
        completer.complete();
      },
    );

    await completer.future;
    return eventBox.all();
  }

  String query(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.ALL,
    bool sendAfterAuth = false,
  }) {
    return _pool.query(
      filters,
      onEvent,
      id: id,
      onComplete: onComplete,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
    );
  }

  String queryByFilters(Map<String, List<Map<String, dynamic>>> filtersMap,
      Function(Event) onEvent,
      {String? id, Function? onComplete}) {
    return _pool.queryByFilters(filtersMap, onEvent,
        id: id, onComplete: onComplete);
  }

  Future<bool> addRelay(
    Relay relay, {
    bool autoSubscribe = false,
    bool init = false,
    int relayType = RelayType.NORMAL,
  }) async {
    return await _pool.add(relay,
        autoSubscribe: autoSubscribe, init: init, relayType: relayType);
  }

  void removeRelay(String url, {int relayType = RelayType.NORMAL}) {
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
    print("nostr reconnect");
    _pool.reconnect();
  }

  List<String> getExtralReadableRelays(
      List<String> extralRelays, int maxRelayNum) {
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

  bool isReadOnly() {
    return nostrSigner is PubkeyOnlyNostrSigner;
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
