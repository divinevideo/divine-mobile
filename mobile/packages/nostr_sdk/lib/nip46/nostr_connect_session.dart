// ABOUTME: State machine for managing client-initiated NIP-46 nostrconnect://
// ABOUTME: connections. Handles keypair generation, relay listening, and
// ABOUTME: bunker response validation.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../event.dart';
import '../event_kind.dart';
import '../filter.dart';
import '../nip19/nip19.dart';
import '../relay/client_connected.dart';
import '../relay/relay.dart';
import '../relay/relay_base.dart';
import '../relay/relay_mode.dart';
import '../relay/relay_status.dart';
import '../signer/local_nostr_signer.dart';
import '../utils/relay_addr_util.dart';
import '../utils/relay_url_policy.dart';
import '../utils/string_util.dart';
import 'nostr_remote_response.dart';
import 'nostr_remote_signer_info.dart';

const _relayConnectTimeout = Duration(seconds: 8);
const _relayFailedConnectCleanupTimeout = Duration(seconds: 1);

/// State of a nostrconnect:// session.
enum NostrConnectState {
  /// Session not started.
  idle,

  /// Generating keypair and URL.
  generating,

  /// Listening on relays for bunker response.
  listening,

  /// Bunker responded and connection successful.
  connected,

  /// Connection timed out waiting for bunker.
  timeout,

  /// Session was cancelled by user.
  cancelled,

  /// An error occurred.
  error,
}

/// Why a `nostrconnect://` session terminated in failure.
///
/// The UI layer maps this to a localized string; this package never carries
/// user-facing English. Mirrors the `InviteActivationFailureReason` pattern.
enum NostrConnectFailureReason {
  /// Programmer error: the response handler was reached with no expected
  /// secret to validate against. Should never happen in practice.
  noExpectedSecret,

  /// The wait window elapsed without a valid response.
  timedOut,

  /// The user cancelled mid-flow.
  cancelled,

  /// The session failed to start (relay-connect failure, etc.).
  startFailed,

  /// The secret matched but post-connect setup failed (e.g. fetching the
  /// user pubkey from the signer). Assigned by the auth layer, not the
  /// session itself.
  postConnectFailed,
}

/// Result of a successful nostrconnect:// connection.
class NostrConnectResult {
  const NostrConnectResult({
    required this.remoteSignerPubkey,
    required this.userPubkey,
    required this.info,
  });

  /// The bunker's pubkey (learned from response event).
  final String remoteSignerPubkey;

  /// The user's pubkey (if returned by bunker, may need get_public_key call).
  final String? userPubkey;

  /// The complete NostrRemoteSignerInfo for creating NostrRemoteSigner.
  final NostrRemoteSignerInfo info;
}

/// State machine for managing client-initiated NIP-46 nostrconnect:// connections.
///
/// Usage:
/// ```dart
/// final session = NostrConnectSession(
///   relays: ['wss://relay.divine.video', 'wss://relay.nsec.app'],
///   appName: 'OpenVine',
/// );
///
/// // Start the session - generates keypair and URL
/// await session.start();
///
/// // Display session.connectUrl as QR code
/// print(session.connectUrl);
///
/// // Wait for bunker to connect
/// final result = await session.waitForConnection(timeout: Duration(minutes: 2));
/// if (result != null) {
///   // Success! Create NostrRemoteSigner with result.info
/// }
/// ```
class NostrConnectSession {
  NostrConnectSession({
    required this.relays,
    this.appName,
    this.appUrl,
    this.appIcon,
    this.permissions,
    this.callback,
    this.relayMode = RelayMode.baseMode,
    this.logger = log,
  });

  /// Relays to use for the connection.
  final List<String> relays;

  /// App name for bunker's approval dialog.
  final String? appName;

  /// App URL for bunker's approval dialog.
  final String? appUrl;

  /// App icon URL for bunker's approval dialog.
  final String? appIcon;

  /// Requested permissions (defaults to standard video app permissions).
  final String? permissions;

  /// Callback URL scheme for signer app to redirect back after approval.
  final String? callback;

  /// Relay mode to use (base or isolate).
  final int relayMode;

  /// Sink for diagnostic log lines. Injectable so tests can assert that
  /// secret material never reaches the logs (default: `dart:developer` log).
  final void Function(String message) logger;

  /// Current session state.
  NostrConnectState _state = NostrConnectState.idle;
  NostrConnectState get state => _state;

  /// Stream of state changes.
  Stream<NostrConnectState> get stateStream => _stateController.stream;
  final _stateController = StreamController<NostrConnectState>.broadcast();

  /// The generated nostrconnect:// URL. Available after start().
  String? get connectUrl => _connectUrl;
  String? _connectUrl;

  /// The generated info. Available after start().
  NostrRemoteSignerInfo? get info => _info;
  NostrRemoteSignerInfo? _info;

  /// Why the session terminated in failure, if any. The UI maps this to a
  /// localized string; this package never carries user-facing English.
  NostrConnectFailureReason? get failureReason => _failureReason;
  NostrConnectFailureReason? _failureReason;

  // Internal state
  LocalNostrSigner? _localSigner;
  final List<Relay> _relays = [];

  /// How many relays a signer named in a callback rather than the session
  /// advertising them. Bounded by [RelayListCaps.nip46Callback].
  ///
  /// Counts slots, not entries in [_relays]: one is taken before the dial and
  /// released if the dial fails, so callbacks arriving inside one connect
  /// window cannot each observe a pre-dial count and overshoot the cap.
  int _signerSuppliedRelayCount = 0;

  /// Dedupe keys of callback relays currently being dialed.
  ///
  /// [_relays] only holds relays that finished connecting, so without this a
  /// second callback naming the same URL opens a second socket to it.
  final Set<String> _pendingSignerRelays = {};
  Completer<NostrConnectResult?>? _connectionCompleter;
  Timer? _timeoutTimer;
  bool _isClosed = false;

  /// Ids of relay events already processed. Up to 4 relays each deliver
  /// the same event, and the fixed `since` timestamp replays history on
  /// every reconnect — skip replays before paying for decryption.
  /// Bounded by the events received in one short-lived pairing session.
  final Set<String> _seenEventIds = {};

  /// Response ids of auth challenges already logged, so a signer that
  /// re-sends its challenge as a fresh event doesn't spam the log.
  /// Bounded by session lifetime.
  final Set<String> _seenAuthChallengeIds = {};

  /// The wait window passed to [waitForConnection], kept so the timer can
  /// be re-armed once when an auth challenge arrives.
  Duration? _waitTimeout;

  /// Whether the one allowed challenge-triggered timer restart happened.
  /// Capped at one per session so injected challenges cannot extend the
  /// wait indefinitely.
  bool _challengeTimerRestarted = false;

  /// The since timestamp used for subscriptions, captured once at session start
  /// so reconnections use the same timestamp.
  int? _subscriptionSinceTimestamp;

  /// Start the session - generates keypair and begins listening on relays.
  Future<void> start() async {
    if (_state != NostrConnectState.idle) {
      throw StateError('Session already started. Create a new session.');
    }

    _setState(NostrConnectState.generating);

    try {
      // Generate the nostrconnect:// URL with ephemeral keypair
      _info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: relays,
        appName: appName,
        appUrl: appUrl,
        appIcon: appIcon,
        permissions: permissions,
      );

      // Generate the URL
      _connectUrl = _info!.toNostrConnectUrl(
        permissions: permissions,
        callback: callback,
      );

      // Create local signer from the ephemeral keypair
      _localSigner = LocalNostrSigner(Nip19.decode(_info!.nsec!));

      logger('[NostrConnectSession] Generated URL: $_connectUrl');

      // Connect to relays and start listening
      await _connectToRelays();
      // A cancel landing inside that dial has already torn the session down;
      // announcing `listening` afterwards would undo its terminal state.
      if (_isClosed) return;

      _setState(NostrConnectState.listening);
      logger('[NostrConnectSession] Now listening for bunker response...');
    } catch (e) {
      logger('[NostrConnectSession] Failed to start session: $e');
      _failureReason = NostrConnectFailureReason.startFailed;
      _setState(NostrConnectState.error);
      rethrow;
    }
  }

  /// Wait for the bunker to connect and respond.
  ///
  /// Returns [NostrConnectResult] on success, null on timeout/cancel.
  Future<NostrConnectResult?> waitForConnection({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_state != NostrConnectState.listening) {
      throw StateError(
        'Session must be in listening state. Call start() first.',
      );
    }

    final activeWait = _connectionCompleter;
    if (activeWait != null && !activeWait.isCompleted) {
      return activeWait.future;
    }

    _connectionCompleter = Completer<NostrConnectResult?>();

    _waitTimeout = timeout;
    _armTimeoutTimer(timeout);

    return _connectionCompleter!.future;
  }

  void _armTimeoutTimer(Duration timeout) {
    _timeoutTimer = Timer(timeout, () {
      if (!(_connectionCompleter?.isCompleted ?? true)) {
        logger('[NostrConnectSession] Connection timed out');
        _setState(NostrConnectState.timeout);
        _connectionCompleter!.complete(null);
      }
    });
  }

  /// Cancel the session.
  void cancel() {
    if (_isClosed) return;

    logger('[NostrConnectSession] Session cancelled');
    _setState(NostrConnectState.cancelled);

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(null);
    }

    _cleanup();
  }

  /// Ensure all relay connections are alive. Reconnects any that dropped.
  ///
  /// Call this when the app returns from background to recover connections
  /// that Android may have killed.
  Future<void> ensureConnected() async {
    if (_isClosed || _state != NostrConnectState.listening) return;

    logger(
      '[NostrConnectSession] ensureConnected: checking ${_relays.length} '
      'relays + ${relays.length} configured',
    );

    // Reconnect any disconnected relays
    final disconnected = _relays
        .where((r) => r.relayStatus.connected != ClientConnected.connected)
        .toList();

    for (final relay in disconnected) {
      if (_isClosed) return;
      await _reconnectRelay(relay);
    }

    // A cleanup landing inside one of those reconnects has already emptied
    // `_relays`, which reads here as "all relays lost". Dialing from scratch
    // then opens sockets for a session that is over (#7962).
    if (_isClosed) return;

    // If all relays were lost, try to reconnect from scratch
    if (_relays.isEmpty) {
      logger(
        '[NostrConnectSession] All relays lost, reconnecting from scratch',
      );
      await _connectToRelays();
    }
  }

  /// Adds a signer-supplied relay to the active session.
  ///
  /// Some same-device signers return a callback relay after the user approves
  /// the connection. Connect to it in addition to the original nostrconnect://
  /// relays so the response event can arrive on the signer's chosen transport.
  ///
  /// At most [RelayListCaps.nip46Callback] of them are adopted per session:
  /// the callback is a deep link, so anything on the device can deliver one,
  /// and nothing else bounds how many arrive while a session is listening.
  /// Only relays that actually connected count — a failed dial leaves the
  /// budget for the signer's next attempt.
  ///
  /// Callers dispatch this without awaiting, so the cap is claimed before the
  /// dial rather than after it: reading the count, awaiting, then incrementing
  /// would let every call in one connect window see the same pre-dial count.
  Future<void> addRelay(String relayUrl) async {
    if (_isClosed || _state != NostrConnectState.listening) return;
    final key = _relayDedupeKey(relayUrl);
    if (relays.any((url) => _relayDedupeKey(url) == key) ||
        _relays.any(
          (relay) => _relayDedupeKey(relay.relayStatus.addr) == key,
        ) ||
        _pendingSignerRelays.contains(key)) {
      return;
    }
    if (_signerSuppliedRelayCount >= RelayListCaps.nip46Callback) {
      logger(
        '[NostrConnectSession] Ignoring callback relay $relayUrl - '
        'already holding ${RelayListCaps.nip46Callback}',
      );
      return;
    }

    _signerSuppliedRelayCount++;
    _pendingSignerRelays.add(key);
    try {
      final relay = await _connectToRelay(relayUrl);
      if (_isClosed) {
        _shutDownRelay(relay);
        _signerSuppliedRelayCount--;
        return;
      }
      _relays.add(relay);
      logger('[NostrConnectSession] Added callback relay $relayUrl');
    } catch (e) {
      _signerSuppliedRelayCount--;
      logger(
        '[NostrConnectSession] Failed to add callback relay $relayUrl: $e',
      );
    } finally {
      _pendingSignerRelays.remove(key);
    }
  }

  /// The identity callback relays are deduplicated under.
  ///
  /// [RelayAddrUtil.handle] collapses a bare address to a root path for every
  /// address this package dials, so `wss://h` and `wss://h/` are one relay to
  /// the pool. Matching that here keeps a respelling from costing a second
  /// slot of the cap. An unparseable address keys under itself.
  String _relayDedupeKey(String url) {
    final trimmed = url.trim();
    if (Uri.tryParse(trimmed) == null) return trimmed;
    return RelayAddrUtil.handle(trimmed);
  }

  /// Clean up resources.
  void dispose() {
    _cleanup();
    _stateController.close();
  }

  void _cleanup() {
    _isClosed = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    for (final relay in _relays) {
      _shutDownRelay(relay);
    }
    _relays.clear();
  }

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
      logger(
        '[NostrConnectSession] Error shutting down relay '
        '${relay.relayStatus.addr}: $e',
      );
    }
  }

  void _setState(NostrConnectState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  Future<void> _connectToRelays() async {
    // Connect to all relays in parallel for speed
    final futures = relays.map((url) async {
      try {
        return await _connectToRelay(url);
      } catch (e) {
        logger('[NostrConnectSession] Failed to connect to $url: $e');
        return null;
      }
    });
    final results = await Future.wait(futures.toList());
    // `cancel()` / `dispose()` can land inside that dial. Adopting a relay
    // after the cleanup has run would put a live socket on a list nothing
    // will ever walk again, so shut down what finished connecting (#7962).
    if (_isClosed) {
      for (final relay in results) {
        if (relay != null) _shutDownRelay(relay);
      }
      return;
    }
    for (final relay in results) {
      if (relay != null) _relays.add(relay);
    }
    if (_relays.isEmpty) {
      throw StateError('Failed to connect to any relay');
    }
  }

  Future<Relay> _connectToRelay(String relayAddr) async {
    final relayStatus = RelayStatus(relayAddr);
    final relay = RelayBase(relayAddr, relayStatus);

    relay.onMessage = _onMessage;
    relay.relayStatusCallback = () {
      if (_isClosed) return;
      if (relayStatus.connected == ClientConnected.disconnect) {
        logger('[NostrConnectSession] Relay $relayAddr disconnected');
      }
    };

    try {
      // Add subscription for listening to responses
      await _addSubscription(relay);

      final connected = await relay.connect().timeout(_relayConnectTimeout);
      if (!connected) {
        throw StateError('Relay connect returned false');
      }
      logger('[NostrConnectSession] Connected to $relayAddr');

      return relay;
    } catch (_) {
      relay.onMessage = null;
      try {
        await relay.disconnect().timeout(_relayFailedConnectCleanupTimeout);
      } catch (_) {
        // Best-effort cleanup; preserve and rethrow the connection failure.
      }
      rethrow;
    }
  }

  /// Reconnects one dropped relay.
  ///
  /// Checks [_isClosed] itself rather than trusting the caller's single
  /// pre-loop check: every attempt suspends, and a cleanup landing inside one
  /// of those waits takes the relay off [_relays] — a connect resuming
  /// afterwards opens a socket and arms a heartbeat that no owner is left to
  /// close (#7962).
  Future<void> _reconnectRelay(Relay relay) async {
    if (_isClosed) return;

    final addr = relay.relayStatus.addr;
    logger('[NostrConnectSession] Reconnecting to $addr');

    try {
      // Re-add the subscription filter so it is sent on connect
      await _addSubscription(relay);
      if (_isClosed) return;
      final connected = await relay.connect().timeout(_relayConnectTimeout);
      if (connected) {
        logger('[NostrConnectSession] Reconnected to $addr');
      } else {
        logger('[NostrConnectSession] Failed to reconnect to $addr');
      }
    } catch (e) {
      logger('[NostrConnectSession] Reconnection error for $addr: $e');
    }
  }

  Future<void> _addSubscription(Relay relay) async {
    final pubkey = await _localSigner!.getPublicKey();
    if (pubkey == null) {
      throw StateError('Failed to get client pubkey');
    }

    // Capture the since timestamp once at session start so reconnections
    // use the same value and don't miss events sent while disconnected.
    _subscriptionSinceTimestamp ??=
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 30;

    final filter = Filter(
      since: _subscriptionSinceTimestamp!,
      p: [pubkey],
      kinds: [EventKind.nostrRemoteSigning],
    );

    final subscriptionId = StringUtil.rndSecureNameStr(12);
    final queryMsg = ['REQ', subscriptionId, filter.toJson()];

    relay.pendingMessages.add(queryMsg);
    logger(
      '[NostrConnectSession] Added subscription $subscriptionId for pubkey $pubkey',
    );
  }

  Future<void> _onMessage(Relay relay, List<dynamic> json) async {
    final messageType = json[0];

    if (messageType == 'EVENT') {
      try {
        relay.relayStatus.noteReceive();
        final event = Event.fromJson(json[2]);

        logger(
          '[NostrConnectSession] Received event kind=${event.kind} '
          'from ${event.pubkey}',
        );

        if (event.kind == EventKind.nostrRemoteSigning) {
          await _handleResponse(event);
        }
      } catch (e, stack) {
        logger('[NostrConnectSession] Error handling event: $e\n$stack');
      }
    } else if (messageType == 'EOSE') {
      logger('[NostrConnectSession] EOSE from ${relay.relayStatus.addr}');
    } else if (messageType == 'NOTICE') {
      logger('[NostrConnectSession] NOTICE: ${json.length > 1 ? json[1] : ""}');
    }
  }

  Future<void> _handleResponse(Event event) async {
    // NIP-01 id integrity: an event id is the SHA-256 of its serialized
    // content, so a tampered relay copy cannot reuse the genuine
    // response's id without also reproducing its content. Verify before
    // touching the replay-dedup cache — otherwise an attacker on the
    // listening relays could reserve the real id with a junk copy that
    // fails decryption, so the genuine response arriving from another
    // relay is discarded as a "duplicate" and sign-in times out (#6151).
    if (!event.isValid || !event.isSigned) {
      logger(
        '[NostrConnectSession] Dropped event from ${event.pubkey}: '
        'failed event verification',
      );
      return;
    }
    if (!_seenEventIds.add(event.id)) {
      return;
    }

    // Decrypt the response
    final response = await NostrRemoteResponse.decrypt(
      event.content,
      _localSigner!,
      event.pubkey,
    );

    if (response == null) {
      logger('[NostrConnectSession] Failed to decrypt response');
      return;
    }

    logger(
      '[NostrConnectSession] Decrypted response: id=${response.id}, '
      'hasResult=${response.result.isNotEmpty}, '
      'hasError=${(response.error ?? '').isNotEmpty}',
    );

    // Validate the secret per NIP-46. Accept ONLY an exact match;
    // "ack"/"connect" belong to the bunker:// flow's connect method
    // and are not valid for nostrconnect://. Everything else — junk
    // responses, signer errors, auth_url challenges — is non-terminal:
    // the sender is unauthenticated pre-secret, so treating any of it
    // as terminal would let any pubkey on the listening relays DoS
    // pairing by racing a junk response in front of the legitimate
    // signer's reply (matches nostr-tools/NDK pairing behavior).
    final validation = validateConnectResponse(
      response: response,
      expectedSecret: _info?.optionalSecret,
    );

    switch (validation) {
      case NostrConnectResponseValidation.invalidSession:
        logger('[NostrConnectSession] No expected secret - cannot validate');
        _failureReason = NostrConnectFailureReason.noExpectedSecret;
        _setState(NostrConnectState.error);
        _timeoutTimer?.cancel();
        if (_connectionCompleter != null &&
            !_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(null);
        }
        return;

      case NostrConnectResponseValidation.authChallenge:
        // The challenge URL in response.error is deliberately not
        // surfaced, opened, or logged: the sender is unauthenticated
        // at pairing time, so the URL is attacker-suppliable (#3760).
        // The signer answers on the same request id once the user
        // authenticates out-of-band, so keep listening.
        if (_seenAuthChallengeIds.add(response.id)) {
          logger(
            '[NostrConnectSession] Auth challenge from ${event.pubkey}; '
            'keeping the session listening',
          );
        }
        // Grant extra runway exactly once per session, since out-of-band
        // approval can be slow. The single restart is deliberately
        // consumable by any sender: an unauthenticated challenge must
        // not be able to extend the wait forever.
        if (!_challengeTimerRestarted && (_timeoutTimer?.isActive ?? false)) {
          _challengeTimerRestarted = true;
          _timeoutTimer!.cancel();
          _armTimeoutTimer(_waitTimeout!);
          logger('[NostrConnectSession] Wait window restarted once');
        }
        return;

      case NostrConnectResponseValidation.ignore:
        // Drop silently and keep listening; the hard timeout in
        // waitForConnection terminates the wait if no valid response
        // ever arrives.
        logger(
          '[NostrConnectSession] Ignoring response from ${event.pubkey}: '
          'not a binding response',
        );
        return;

      case NostrConnectResponseValidation.match:
        if (_connectionCompleter != null && _connectionCompleter!.isCompleted) {
          // The wait already ended (timeout or cancel); binding now would
          // flip the UI to a connected state nobody is waiting on.
          logger(
            '[NostrConnectSession] Ignoring late secret match from '
            '${event.pubkey}: the wait already ended',
          );
          return;
        }
        // Fall through to the success path below.
        break;
    }

    // Success! Extract remote signer pubkey from the event
    final remoteSignerPubkey = event.pubkey;
    logger('[NostrConnectSession] Connected to bunker: $remoteSignerPubkey');

    // Update info with the remote signer pubkey
    _info = NostrRemoteSignerInfo(
      remoteSignerPubkey: remoteSignerPubkey,
      relays: _info!.relays,
      optionalSecret: _info!.optionalSecret,
      nsec: _info!.nsec,
      userPubkey: null, // Will be fetched via get_public_key
      isClientInitiated: true,
      clientPubkey: _info!.clientPubkey,
      appName: _info!.appName,
      appUrl: _info!.appUrl,
      appIcon: _info!.appIcon,
    );

    _timeoutTimer?.cancel();
    _setState(NostrConnectState.connected);

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(
        NostrConnectResult(
          remoteSignerPubkey: remoteSignerPubkey,
          userPubkey: null,
          info: _info!,
        ),
      );
    }

    // Clean up relays - NostrRemoteSigner will create its own connections
    _cleanup();
  }
}

/// Outcome of validating a `nostrconnect://` connect response per NIP-46.
@visibleForTesting
enum NostrConnectResponseValidation {
  /// `response.result` exactly matches the expected secret. Proceed to
  /// bind the session.
  match,

  /// `response.result` is the literal `auth_url` challenge marker
  /// (NIP-46 Auth Challenges): the signer wants the user to authenticate
  /// out-of-band and will answer later on the same request id, so keep
  /// listening. The challenge URL (carried in `response.error`) is
  /// deliberately not surfaced, opened, or logged — during
  /// nostrconnect:// pairing the sender is unauthenticated, so the URL
  /// is attacker-suppliable (#3760, #5683).
  authChallenge,

  /// Programmer error: the session is missing an expected secret.
  /// Surface a terminal error.
  invalidSession,

  /// Anything else: a non-matching `response.result`, or a signer error
  /// (`response.error` set) that is not an auth challenge. Drop silently
  /// per #3355/#5683 — the sender is unauthenticated pre-secret, so
  /// treating errors as terminal would let any pubkey on the listening
  /// relays DoS pairing by racing junk responses in front of the
  /// legitimate signer's reply. Matches nostr-tools/NDK pairing
  /// behavior; the cost is that a genuine signer-side deny waits out
  /// the timeout instead of failing fast.
  ignore,
}

/// Pure validation of a NIP-46 nostrconnect:// connect response against
/// the expected secret. Public-by-test so the security-critical decision
/// is exhaustively unit-testable.
@visibleForTesting
NostrConnectResponseValidation validateConnectResponse({
  required NostrRemoteResponse response,
  required String? expectedSecret,
}) {
  if (expectedSecret == null || expectedSecret.isEmpty) {
    return NostrConnectResponseValidation.invalidSession;
  }
  if (response.isAuthChallenge) {
    return NostrConnectResponseValidation.authChallenge;
  }
  final error = response.error;
  // Checked before the secret compare so a response carrying an error
  // can never bind the session, even if its result matches the secret.
  if (error != null && error.isNotEmpty) {
    return NostrConnectResponseValidation.ignore;
  }
  if (_constantTimeEqual(response.result, expectedSecret)) {
    return NostrConnectResponseValidation.match;
  }
  return NostrConnectResponseValidation.ignore;
}

bool _constantTimeEqual(String a, String b) {
  // This still leaks length, which is acceptable here because the
  // compared value is an ephemeral per-session secret. We only need
  // to avoid content-dependent early exit for equal-length strings.
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
