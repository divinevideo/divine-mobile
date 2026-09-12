import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import '../client_utils/keys.dart';
import '../event.dart';
import '../event_kind.dart';
import '../filter.dart';
import '../nip19/nip19.dart';
import '../nip19/pubkey_for_logs.dart';
import '../relay/client_connected.dart';
import '../relay/relay.dart';
import '../relay/relay_base.dart';
import '../relay/relay_isolate.dart';
import '../relay/relay_mode.dart';
import '../relay/relay_status.dart';
import '../signer/local_nostr_signer.dart';
import '../signer/nostr_signer.dart';
import '../utils/string_util.dart';
import 'nostr_remote_request.dart';
import 'nostr_remote_response.dart';
import 'nostr_remote_signer_info.dart';

/// Exception thrown when bunker requires user authentication via URL
class BunkerAuthRequiredException implements Exception {
  final String authUrl;
  final String requestId;

  BunkerAuthRequiredException(this.authUrl, this.requestId);

  @override
  String toString() => 'BunkerAuthRequiredException: $authUrl';
}

class NostrRemoteSigner extends NostrSigner {
  int relayMode;

  NostrRemoteSignerInfo info;

  late LocalNostrSigner localNostrSigner;

  NostrRemoteSigner(this.relayMode, this.info) {
    if (!keyIsValid(info.remoteSignerPubkey)) {
      throw ArgumentError.value(
        info.remoteSignerPubkey,
        'info.remoteSignerPubkey',
        'A valid remote signer pubkey is required',
      );
    }
  }

  List<Relay> relays = [];

  Map<String, Completer<String?>> callbacks = {};

  /// Stores pending request events that need to be resent after reconnection.
  /// Key is the request ID, value is the signed EVENT message (as JSON array).
  final Map<String, List<dynamic>> _pendingRequestEvents = {};

  /// Callback for when an auth URL is received and needs to be opened
  void Function(String authUrl)? onAuthUrlReceived;

  /// Tracks request IDs for which we've already opened an auth URL
  /// This prevents opening the same auth URL multiple times on reconnection
  final Set<String> _openedAuthUrls = {};

  /// Stores the original `since` timestamp for the subscription filter.
  /// This is set when we first connect and reused for reconnections to ensure
  /// we don't miss events that were created while we were disconnected.
  int? _subscriptionSinceTimestamp;

  /// Tracks retry count per relay address for exponential backoff
  final Map<String, int> _relayRetryCount = {};

  /// Maximum number of reconnection attempts before giving up
  static const int _maxRetries = 5;

  /// Flag to track if this signer has been closed
  /// When true, all reconnection attempts should be stopped
  bool _isClosed = false;

  /// Flag to track if reconnection is paused (e.g., when app is backgrounded)
  /// When true, reconnection attempts are skipped but not permanently stopped
  bool _isPaused = false;

  /// Tracks which relays have received EOSE (stable connection confirmed)
  /// Only reset retry count for relays that have proven stable
  final Set<String> _stableRelays = {};

  Future<String?> connect({bool sendConnectRequest = true}) async {
    log(
      '[NIP46] connect: STARTING - _subscriptionSinceTimestamp=$_subscriptionSinceTimestamp, relays.length=${relays.length}, callbacks=${callbacks.keys.toList()}',
    );

    if (StringUtil.isBlank(info.nsec)) {
      log('[NIP46] connect: nsec is blank, returning null');
      return null;
    }

    localNostrSigner = LocalNostrSigner(Nip19.decode(info.nsec!));
    log('[NIP46] connect: created localNostrSigner');

    // Connect to all relays in parallel for speed
    final futures = info.relays.map((addr) async {
      try {
        return await _connectToRelay(addr);
      } catch (e) {
        log('[NIP46] connect: failed to connect to $addr: $e');
        return null;
      }
    });
    final results = await Future.wait(futures.toList());
    // `close()` can land inside that dial. Adopting a relay after it has run
    // would put a live socket on a list nothing will ever walk again, so shut
    // down what finished connecting instead (#7962).
    if (_isClosed) {
      for (final relay in results) {
        if (relay != null) _shutDownRelay(relay);
      }
      return null;
    }
    for (final relay in results) {
      if (relay != null) relays.add(relay);
    }

    if (sendConnectRequest) {
      log(
        '[NIP46] connect: relays status after delay: ${relays.map((r) => "${r.relayStatus.addr}=${r.relayStatus.connected}").join(", ")}',
      );

      var request = NostrRemoteRequest("connect", [
        info.remoteSignerPubkey,
        info.optionalSecret ?? "",
        "sign_event,get_relays,get_public_key,nip04_encrypt,nip04_decrypt,nip44_encrypt,nip44_decrypt",
      ]);
      log(
        '[NIP46] connect: sending connect request id=${request.id} to remoteSignerPubkey=${pubkeyForLogs(info.remoteSignerPubkey)}',
      );
      var result = await sendAndWaitForResult(request, timeout: 120);
      log('[NIP46] connect: result=$result');
      return result;
    }
    return null;
  }

  Future<String?> pullPubkey() async {
    var request = NostrRemoteRequest("get_public_key", []);
    var pubkey = await sendAndWaitForResult(request, timeout: 120);
    // Never bind the session to a malformed pubkey: get_public_key must
    // return a 32-byte hex key, and everything downstream trusts this value
    // as the account identity (#7344).
    if (pubkey == null || !keyIsValid(pubkey)) {
      log('[NIP46] pullPubkey: dropping non-hex get_public_key result');
      return null;
    }
    final normalizedPubkey = pubkey.toLowerCase();
    info.userPubkey = normalizedPubkey;
    return normalizedPubkey;
  }

  Future<void> onMessage(Relay relay, List<dynamic> json) async {
    final messageType = json[0];
    if (messageType == 'EVENT') {
      try {
        relay.relayStatus.noteReceive();

        final subscriptionId = json[1];
        final event = Event.fromJson(json[2]);
        log(
          '[NIP46] onMessage: received event subscriptionId=$subscriptionId, kind=${event.kind} from ${pubkeyForLogs(event.pubkey)}, createdAt=${event.createdAt}',
        );
        if (event.kind == EventKind.nostrRemoteSigning) {
          // NIP-46 responses must be authored by the paired remote signer.
          // Compare against the signer key, not the user's account key: those
          // keys legitimately differ for some bunkers.
          final expectedSigner = info.remoteSignerPubkey;
          if (event.pubkey.toLowerCase() != expectedSigner.toLowerCase()) {
            log(
              '[NIP46] onMessage: dropping kind-24133 event from an '
              'unexpected author: expected=${pubkeyForLogs(expectedSigner)} '
              'got=${pubkeyForLogs(event.pubkey)}',
            );
            return;
          }
          // isValid is id-integrity (sha256); isSigned is the Schnorr
          // verification. Both are required — an attacker clears isValid
          // trivially by recomputing the id over their own forged event.
          if (!event.isValid || !event.isSigned) {
            log(
              '[NIP46] onMessage: dropping kind-24133 event from '
              '${pubkeyForLogs(event.pubkey)} that failed id/signature '
              'validation',
            );
            return;
          }
          var response = await NostrRemoteResponse.decrypt(
            event.content,
            localNostrSigner,
            event.pubkey,
          );
          if (response != null) {
            if (response.result == 'auth_url' && !response.isAuthChallenge) {
              log(
                '[NIP46] onMessage: ignoring malformed auth challenge for '
                'id=${response.id}',
              );
              return;
            }
            // An auth challenge answers a request the client already sent, so
            // its id must be one we are waiting on. Correlating here (and not
            // logging the URL) closes the last of the unsolicited-challenge
            // surface after the author check above (#7339).
            if (response.isAuthChallenge) {
              if (!callbacks.containsKey(response.id)) {
                log(
                  '[NIP46] onMessage: ignoring auth challenge for unknown '
                  'request id=${response.id}',
                );
                return;
              }
              log(
                '[NIP46] onMessage: auth challenge received for '
                'id=${response.id}',
              );
              // Only open the auth URL once per request ID. This prevents
              // re-opening the browser on reconnection when historical events
              // are replayed from the relay.
              if (_openedAuthUrls.contains(response.id)) {
                log(
                  '[NIP46] onMessage: auth URL already opened for id=${response.id}, ignoring',
                );
                return;
              }
              _openedAuthUrls.add(response.id);

              // Don't remove the callback - we need to wait for the actual response
              // after user approves in the browser
              if (onAuthUrlReceived != null) {
                onAuthUrlReceived!(response.error!);
              }
              return; // Keep waiting for the real response
            }

            var completer = callbacks.remove(response.id);
            // Also remove from pending requests since we got a response
            _pendingRequestEvents.remove(response.id);
            if (completer != null) {
              // Check if bunker returned an error response
              if (response.error != null && response.error!.isNotEmpty) {
                log(
                  '[NIP46] onMessage: bunker returned error for id=${response.id}: ${response.error}',
                );
                completer.completeError(
                  Exception('Bunker error: ${response.error}'),
                );
              } else {
                completer.complete(response.result);
              }
            }
          } else {
            log('[NIP46] onMessage: failed to decrypt response');
          }
        }
      } catch (err, stackTrace) {
        log('[NIP46] onMessage error: $err\n$stackTrace');
        // Re-throw to ensure the error is not silently swallowed
        // This allows the caller to handle the error appropriately
        rethrow;
      }
    } else if (messageType == 'EOSE') {
      final addr = relay.relayStatus.addr;
      log(
        '[NIP46] onMessage: EOSE received from $addr - connection confirmed stable',
      );
      // Mark this relay as stable (has successfully received data)
      _stableRelays.add(addr);
      // Now it's safe to reset retry count since connection is proven stable
      _relayRetryCount[addr] = 0;
    } else if (messageType == "NOTICE") {
      log('[NIP46] onMessage: NOTICE: ${json.length > 1 ? json[1] : ""}');
    } else if (messageType == "AUTH") {
      log('[NIP46] onMessage: AUTH challenge received');
    } else if (messageType == "OK") {
      log(
        '[NIP46] onMessage: OK received: ${json.length > 1 ? json.sublist(1).join(", ") : ""}',
      );
    }
  }

  Future<Relay> _connectToRelay(String relayAddr) async {
    RelayStatus relayStatus = RelayStatus(relayAddr);
    Relay? relay;
    if (relayMode == RelayMode.baseMode) {
      relay = RelayBase(relayAddr, relayStatus);
    } else {
      relay = RelayIsolate(relayAddr, relayStatus);
    }
    relay.onMessage = onMessage;
    await addPenddingQueryMsg(relay);
    relay.relayStatusCallback = () {
      if (_isClosed) {
        log(
          '[NIP46] relayStatusCallback: signer is closed, ignoring disconnect',
        );
        return;
      }
      if (_isPaused) {
        log(
          '[NIP46] relayStatusCallback: signer is paused, ignoring disconnect',
        );
        return;
      }
      if (relayStatus.connected == ClientConnected.disconnect) {
        // Mark relay as no longer stable when it disconnects
        _stableRelays.remove(relayStatus.addr);
        log(
          '[NIP46] relayStatusCallback: relay ${relayStatus.addr} disconnected, attempting reconnect...',
        );
        // Attempt to reconnect automatically when disconnected
        // This is important for auth flows where app goes to background
        _reconnectRelay(relay!);
      }
    };

    await relay.connect();

    return relay;
  }

  /// Whether a reconnect that has already suspended must drop its connect.
  ///
  /// Re-checked after every await in [_reconnectRelay]: [close] landing inside
  /// one of those waits takes the relay off [relays], so a connect resuming
  /// afterwards opens a socket and arms a heartbeat that no owner is left to
  /// close (#7962).
  bool get _reconnectAbandoned => _isClosed || _isPaused;

  /// Attempts to reconnect a relay after disconnection
  /// Uses exponential backoff to avoid hammering the relay
  Future<void> _reconnectRelay(Relay relay) async {
    // Don't attempt reconnection if the signer has been closed
    if (_isClosed) {
      log('[NIP46] _reconnectRelay: signer is closed, skipping reconnect');
      return;
    }

    // Don't attempt reconnection if paused (e.g., app backgrounded)
    if (_isPaused) {
      log('[NIP46] _reconnectRelay: signer is paused, skipping reconnect');
      return;
    }

    final addr = relay.relayStatus.addr;

    // Check retry count and enforce limit
    final retryCount = _relayRetryCount[addr] ?? 0;
    if (retryCount >= _maxRetries) {
      log(
        '[NIP46] _reconnectRelay: max retries ($_maxRetries) reached for $addr, giving up',
      );
      return;
    }

    // Avoid multiple simultaneous reconnection attempts
    if (relay.relayStatus.connected == ClientConnected.connecting) {
      log('[NIP46] _reconnectRelay: already reconnecting to $addr');
      return;
    }

    // Check if still disconnected (might have reconnected via another path)
    // Only skip if this relay is confirmed stable (has received EOSE)
    if (relay.relayStatus.connected == ClientConnected.connected &&
        _stableRelays.contains(addr)) {
      log('[NIP46] _reconnectRelay: $addr already reconnected and stable');
      return;
    }

    // Increment retry count
    _relayRetryCount[addr] = retryCount + 1;

    // Apply exponential backoff: 100ms, 200ms, 400ms, 800ms, 1600ms
    final backoffMs = 100 * (1 << retryCount);
    log(
      '[NIP46] _reconnectRelay: attempt ${retryCount + 1}/$_maxRetries for $addr, waiting ${backoffMs}ms...',
    );
    await Future<void>.delayed(Duration(milliseconds: backoffMs));

    if (_reconnectAbandoned) {
      log('[NIP46] _reconnectRelay: abandoned during backoff for $addr');
      return;
    }

    try {
      // Add subscription query to pending messages before reconnecting
      if (relay.pendingMessages.isEmpty) {
        await addPenddingQueryMsg(relay);
        if (_reconnectAbandoned) {
          log(
            '[NIP46] _reconnectRelay: abandoned while queueing REQ for $addr',
          );
          return;
        }
      }

      await relay.connect();

      // Check if actually connected after connect() returns
      if (relay.relayStatus.connected == ClientConnected.connected) {
        log(
          '[NIP46] _reconnectRelay: $addr reconnected, waiting for EOSE to confirm stability',
        );
        // Don't reset retry count here - wait for EOSE to confirm stable connection
        // This prevents infinite reconnect loops when connection appears successful
        // but fails asynchronously

        // Resend any pending request events that were waiting for responses
        if (_pendingRequestEvents.isNotEmpty) {
          log(
            '[NIP46] _reconnectRelay: resending ${_pendingRequestEvents.length} pending requests',
          );
          for (var entry in _pendingRequestEvents.entries) {
            log('[NIP46] _reconnectRelay: resending request id=${entry.key}');
            relay.send(entry.value);
          }
        }
      } else {
        log(
          '[NIP46] _reconnectRelay: $addr connect() completed but not connected',
        );
      }
    } catch (e) {
      log('[NIP46] _reconnectRelay: failed to reconnect $addr: $e');
    }
  }

  Future<void> addPenddingQueryMsg(Relay relay) async {
    // add a query event
    log(
      '[NIP46] addPenddingQueryMsg: generating REQ for ${relay.relayStatus.addr}',
    );
    var queryMsg = await genQueryMsg();
    if (queryMsg != null) {
      relay.pendingMessages.add(queryMsg);
      log(
        '[NIP46] addPenddingQueryMsg: added REQ to ${relay.relayStatus.addr}, pendingMessages count=${relay.pendingMessages.length}',
      );
      log('[NIP46] addPenddingQueryMsg: REQ message=$queryMsg');
    } else {
      log('[NIP46] addPenddingQueryMsg: genQueryMsg returned null');
    }
  }

  Future<List?> genQueryMsg() async {
    var pubkey = await localNostrSigner.getPublicKey();
    if (pubkey == null) {
      log('[NIP46] genQueryMsg: pubkey is null');
      return null;
    }

    // Use the stored timestamp if available (for reconnections),
    // otherwise create a new one (for initial connection)
    final isFirstCall = _subscriptionSinceTimestamp == null;
    final sinceTimestamp =
        _subscriptionSinceTimestamp ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Store the timestamp for future reconnections
    _subscriptionSinceTimestamp ??= sinceTimestamp;

    // Use a slightly earlier timestamp to account for clock skew between
    // our device and the bunker server (subtract 30 seconds)
    final adjustedSinceTimestamp = sinceTimestamp - 30;

    // The receive-side author check remains the backstop for a relay that
    // ignores this filter.
    var filter = Filter(
      since: adjustedSinceTimestamp,
      p: [pubkey],
      kinds: [EventKind.nostrRemoteSigning],
      authors: [info.remoteSignerPubkey],
    );

    final filterJson = filter.toJson();
    log(
      '[NIP46] genQueryMsg: using adjusted since=$adjustedSinceTimestamp (original=$sinceTimestamp)',
    );
    final subscriptionId = StringUtil.rndNameStr(12);
    List<dynamic> queryMsg = ["REQ", subscriptionId];
    queryMsg.add(filterJson);

    log(
      '[NIP46] genQueryMsg: created subscription $subscriptionId [isFirstCall=$isFirstCall]',
    );
    log('[NIP46] genQueryMsg: filter=$filterJson');
    return queryMsg;
  }

  Future<String?> sendAndWaitForResult(
    NostrRemoteRequest request, {
    int timeout = 60,
  }) async {
    // Check and reconnect any disconnected relays before sending.
    // Iterate a snapshot: `close()` clears `relays`, and landing inside the
    // connect below would otherwise throw ConcurrentModificationError.
    for (final relay in List<Relay>.of(relays)) {
      if (_isClosed) {
        log('[NIP46] sendAndWaitForResult: signer closed, abandoning request');
        return null;
      }
      final status = relay.relayStatus.connected;
      log(
        '[NIP46] sendAndWaitForResult: checking relay ${relay.relayStatus.addr}, status=$status',
      );
      // Only reconnect if truly disconnected, not if connecting or already connected
      if (status == ClientConnected.disconnect) {
        log(
          '[NIP46] sendAndWaitForResult: relay ${relay.relayStatus.addr} disconnected, reconnecting...',
        );
        try {
          await relay.connect();
          // Re-add the subscription query after reconnecting
          await addPenddingQueryMsg(relay);
          log(
            '[NIP46] sendAndWaitForResult: relay ${relay.relayStatus.addr} reconnected',
          );
        } catch (e) {
          log('[NIP46] sendAndWaitForResult: failed to reconnect relay: $e');
        }
      }
    }

    if (_isClosed) {
      log('[NIP46] sendAndWaitForResult: signer closed, abandoning request');
      return null;
    }

    var senderPubkey = await localNostrSigner.getPublicKey();
    log(
      '[NIP46] sendAndWaitForResult: method=${request.method}, senderPubkey=${pubkeyForLogs(senderPubkey)}',
    );
    var content = await request.encrypt(
      localNostrSigner,
      info.remoteSignerPubkey,
    );
    log(
      '[NIP46] sendAndWaitForResult: encrypted content length=${content?.length ?? 0}',
    );
    if (StringUtil.isNotBlank(senderPubkey) && content != null) {
      Event? event = Event(senderPubkey!, EventKind.nostrRemoteSigning, [
        getRemoteSignerPubkeyTags(),
      ], content);
      event = await localNostrSigner.signEvent(event);
      if (event != null) {
        var json = ["EVENT", event.toJson()];
        log(
          '[NIP46] sendAndWaitForResult: sending event id=${event.id} to ${relays.length} relays',
        );

        if (_isClosed) {
          log(
            '[NIP46] sendAndWaitForResult: signer closed while signing, '
            'abandoning request',
          );
          return null;
        }

        // set completer to callbacks
        var completer = Completer<String?>();
        callbacks[request.id] = completer;

        // Store the request event for potential resend after reconnection
        _pendingRequestEvents[request.id] = json;

        for (var relay in relays) {
          log(
            '[NIP46] sendAndWaitForResult: sending to ${relay.relayStatus.addr}, connected=${relay.relayStatus.connected}',
          );
          relay.send(json);
        }

        log(
          '[NIP46] sendAndWaitForResult: waiting for response with timeout=${timeout}s',
        );
        try {
          return await completer.future.timeout(
            Duration(seconds: timeout),
            onTimeout: () {
              log('[NIP46] sendAndWaitForResult: TIMEOUT waiting for response');
              // Clean up callback and pending request on timeout
              callbacks.remove(request.id);
              _pendingRequestEvents.remove(request.id);
              throw TimeoutException(
                'Bunker request timed out after ${timeout}s',
                Duration(seconds: timeout),
              );
            },
          );
        } on TimeoutException {
          rethrow;
        }
      } else {
        log('[NIP46] sendAndWaitForResult: failed to sign event');
      }
    } else {
      log('[NIP46] sendAndWaitForResult: senderPubkey or content is null');
    }
    return null;
  }

  @override
  Future<String?> decrypt(pubkey, ciphertext) async {
    var request = NostrRemoteRequest("nip04_decrypt", [pubkey, ciphertext]);
    return await sendAndWaitForResult(request);
  }

  @override
  Future<String?> encrypt(pubkey, plaintext) async {
    var request = NostrRemoteRequest("nip04_encrypt", [pubkey, plaintext]);
    return await sendAndWaitForResult(request);
  }

  @override
  Future<String?> getPublicKey() async {
    return info.userPubkey;
  }

  @override
  Future<Map?> getRelays() async {
    var request = NostrRemoteRequest("get_relays", []);
    var result = await sendAndWaitForResult(request);
    if (StringUtil.isNotBlank(result)) {
      return jsonDecode(result!);
    }
    return null;
  }

  @override
  Future<String?> nip44Decrypt(pubkey, ciphertext) async {
    var request = NostrRemoteRequest("nip44_decrypt", [pubkey, ciphertext]);
    return await sendAndWaitForResult(request);
  }

  @override
  Future<String?> nip44Encrypt(pubkey, plaintext) async {
    var request = NostrRemoteRequest("nip44_encrypt", [pubkey, plaintext]);
    return await sendAndWaitForResult(request);
  }

  @override
  Future<Event?> signEvent(Event event) async {
    var eventJsonMap = event.toJson();
    eventJsonMap.remove("id");
    eventJsonMap.remove("pubkey");
    eventJsonMap.remove("sig");
    var eventJsonText = jsonEncode(eventJsonMap);
    // print("eventJsonText");
    // print(eventJsonText);
    var request = NostrRemoteRequest("sign_event", [eventJsonText]);
    var result = await sendAndWaitForResult(request);
    if (StringUtil.isNotBlank(result)) {
      // print("signEventResult");
      // print(result);
      var eventMap = jsonDecode(result!);
      return Event.fromJson(eventMap);
    }

    return null;
  }

  List<String>? _remotePubkeyTags;

  List<String> getRemoteSignerPubkeyTags() {
    _remotePubkeyTags ??= ["p", info.remoteSignerPubkey];
    return _remotePubkeyTags!;
  }

  /// Pause reconnection attempts (e.g., when app goes to background)
  /// This prevents wasted reconnection attempts when network is unavailable
  void pause() {
    if (_isPaused) return;
    log('[NIP46] pause: pausing reconnection attempts');
    _isPaused = true;
  }

  /// Resume reconnection attempts (e.g., when app returns to foreground)
  /// Also resets retry counts to give fresh attempts after resume
  void resume() {
    if (!_isPaused) return;
    log('[NIP46] resume: resuming reconnection attempts');
    _isPaused = false;
    // Reset retry counts to give fresh attempts after resume
    _relayRetryCount.clear();

    // Attempt to reconnect any disconnected relays
    for (final relay in relays) {
      if (relay.relayStatus.connected == ClientConnected.disconnect) {
        log('[NIP46] resume: reconnecting ${relay.relayStatus.addr}');
        _reconnectRelay(relay);
      }
    }
  }

  /// Whether the signer is currently paused
  bool get isPaused => _isPaused;

  /// Takes a relay down for good.
  ///
  /// [Relay.disconnect] alone leaves the relay connectable: it closes the
  /// socket but keeps the connection manager, so a reconnect resuming later
  /// reuses it and opens a fresh socket plus heartbeat. [Relay.dispose] is
  /// what sets the disposed flag that makes the relay refuse that connect
  /// (#7962, guard added in #7367).
  void _shutDownRelay(Relay relay) {
    try {
      relay.disconnect();
      relay.dispose();
    } catch (e) {
      log('[NIP46] error shutting down relay ${relay.relayStatus.addr}: $e');
    }
  }

  @override
  void close() {
    log('[NIP46] close: closing signer and disconnecting all relays');
    _isClosed = true;

    // Disconnect all relays to stop reconnection attempts
    for (final relay in relays) {
      _shutDownRelay(relay);
    }
    relays.clear();

    // Clear all pending callbacks
    for (final completer in callbacks.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Signer closed'));
      }
    }
    callbacks.clear();
    _pendingRequestEvents.clear();
    _relayRetryCount.clear();
    _stableRelays.clear();
  }
}
