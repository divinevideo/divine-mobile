// ABOUTME: Abstract relay class defining the Nostr relay interface.
// ABOUTME: Manages subscriptions, queries, and pending messages.

import 'dart:developer';

import '../subscription.dart';
import 'client_connected.dart';
import 'relay_info.dart';
import 'relay_info_util.dart';
import 'relay_status.dart';

enum WriteAccess { readOnly, writeOnly, readWrite, nothing }

abstract class Relay {
  final String url;

  RelayStatus relayStatus;

  RelayInfo? info;

  // to hold the message when the ws haven't connected and should be send after connected.
  List<List<dynamic>> pendingMessages = [];

  // to hold the message when the ws haven't authed and should be send after auth.
  List<List<dynamic>> pendingAuthedMessages = [];

  Function(Relay, List<dynamic>)? onMessage;

  // subscriptions
  final Map<String, Subscription> _subscriptions = {};

  // queries
  final Map<String, Subscription> _queries = {};

  Relay(this.url, this.relayStatus);

  /// The method to call connect function by framework.
  Future<bool> connect() async {
    try {
      relayStatus.authed = false;
      var result = await doConnect();
      if (result) {
        try {
          onConnected();
        } catch (e) {
          log("onConnected exception.");
          log('$e');
        }
      }
      return result;
    } catch (e) {
      log("connect fail");
      disconnect();
      return false;
    }
  }

  /// The method implement by different relays to do some real when it connecting.
  Future<bool> doConnect();

  /// The medhod called after relay connect success.
  Future onConnected() async {
    for (var message in pendingMessages) {
      // TODO To check result? and how to handle if send fail?
      var result = send(message);
      if (!result) {
        log("message send fail onConnected");
      }
    }

    pendingMessages.clear();
  }

  Future<void> getRelayInfo(String url) async {
    info ??= await RelayInfoUtil.get(url);
  }

  bool send(List<dynamic> message, {bool? forceSend});

  Future<void> disconnect();

  void onError(String errMsg, {bool reconnect = false}) {
    log("relay error $errMsg");
    relayStatus.onError();
    relayStatus.connected = ClientConnected.disconnect;
    if (relayStatusCallback != null) {
      relayStatusCallback!();
    }
    // Note: reconnection is now handled by WebSocketConnectionManager
  }

  List<Subscription> getSubscriptions() {
    return _subscriptions.values.toList();
  }

  void saveSubscription(Subscription subscription) {
    _subscriptions[subscription.id] = subscription;
  }

  bool checkAndCompleteSubscription(String id) {
    // all subscription should be close
    var sub = _subscriptions.remove(id);
    if (sub != null) {
      send(["CLOSE", id]);
      return true;
    }
    return false;
  }

  bool hasSubscription() {
    return _subscriptions.isNotEmpty;
  }

  void saveQuery(Subscription subscription) {
    _queries[subscription.id] = subscription;
  }

  bool checkAndCompleteQuery(String id) {
    // all subscription should be close
    var sub = _queries.remove(id);
    if (sub != null) {
      send(["CLOSE", id]);
      return true;
    }
    return false;
  }

  bool checkQuery(String id) {
    return _queries[id] != null;
  }

  Subscription? getRequestSubscription(String id) {
    return _queries[id];
  }

  Function? relayStatusCallback;

  void dispose() {}
}
