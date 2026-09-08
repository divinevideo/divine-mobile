// ABOUTME: Stateful coordinator for the client-initiated nostrconnect:// flow —
// ABOUTME: owns the NIP-46 connect session, the single-flight wait future, and
// ABOUTME: the deep-link callback-handoff timers. Extracted from AuthService
// ABOUTME: (#4741, repository tier). The facade keeps all auth-session state and
// ABOUTME: applies a successful connection through the injected ports.

import 'dart:async';

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/auth_result.dart';
import 'package:unified_logger/unified_logger.dart';

/// Builds a [NostrConnectSession] for a set of [relays]. Injectable so tests
/// can supply a fake session that completes `waitForConnection` without opening
/// real relay sockets (closes the deferred nostrconnect happy-path gap #5713).
typedef NostrConnectSessionFactory = NostrConnectSession Function(
  List<String> relays,
);

/// Applies a successful nostrconnect connection on the facade: builds the
/// bunker signer from [result], persists its info, and sets up the user
/// session. Returns the [AuthResult] to surface to the caller.
typedef NostrConnectApply = Future<AuthResult> Function(
  NostrConnectResult result,
);

/// Reports an error to Crashlytics — mirrors `AuthService._reportAuthError`.
typedef NostrConnectErrorReporter = void Function(
  Object error,
  StackTrace stack, {
  required String reason,
  required String logMessage,
});

/// Coordinates the client-initiated `nostrconnect://` connection flow.
///
/// Extracted from `AuthService` (#4741, repository tier). Like
/// [OAuthSessionCoordinator] this collaborator is STATEFUL: it owns the connect
/// [NostrConnectSession], the single-flight wait future, and the two
/// deep-link callback-handoff [Timer]s. The facade keeps the *auth* session
/// state (`_bunkerSigner`, `_currentIdentity`, auth-state, `_lastError`) and
/// applies a successful connection through [_onConnected]/[_onConnectFailed],
/// so behavior is preserved exactly.
class NostrConnectCoordinator {
  NostrConnectCoordinator({
    required NostrConnectApply onConnected,
    required void Function(Object error) onConnectFailed,
    required void Function() onWaitStarted,
    required void Function() onWaitFailed,
    required NostrConnectErrorReporter reportError,
    NostrConnectSessionFactory? sessionFactory,
  }) : _onConnected = onConnected,
       _onConnectFailed = onConnectFailed,
       _onWaitStarted = onWaitStarted,
       _onWaitFailed = onWaitFailed,
       _reportError = reportError,
       _sessionFactory = sessionFactory ?? _defaultSessionFactory;

  final NostrConnectApply _onConnected;
  final void Function(Object error) _onConnectFailed;
  final void Function() _onWaitStarted;
  final void Function() _onWaitFailed;
  final NostrConnectErrorReporter _reportError;
  final NostrConnectSessionFactory _sessionFactory;

  NostrConnectSession? _session;
  Future<AuthResult>? _waitFuture;
  Timer? _callbackHandoffTimer;
  Timer? _callbackHandoffCancelTimer;
  bool _isCallbackHandoffActive = false;

  static NostrConnectSession _defaultSessionFactory(List<String> relays) =>
      NostrConnectSession(
        relays: relays,
        appName: 'Divine',
        appUrl: 'https://divine.video',
        appIcon: 'https://divine.video/icon.png',
        callback: 'divine://nostrconnect',
      );

  /// The active nostrconnect:// URL, or null if no session is active.
  String? get connectUrl => _session?.connectUrl;

  /// The current nostrconnect session state, or null if no session is active.
  NostrConnectState? get state => _session?.state;

  /// Stream of nostrconnect session state changes, or null if no session.
  Stream<NostrConnectState>? get stateStream => _session?.stateStream;

  /// True while Android/iOS custom-scheme routing is handing control back
  /// from a NIP-46 signer app to Divine.
  bool get isCallbackHandoffActive => _isCallbackHandoffActive;

  /// Starts a new nostrconnect:// session (generates the keypair + URL and
  /// connects to [customRelays] or the default NIP-46 relays). Cancels any
  /// existing session first.
  Future<NostrConnectSession> initiate({List<String>? customRelays}) async {
    Log.info(
      'Initiating nostrconnect:// session...',
      name: 'NostrConnectCoordinator',
      category: LogCategory.auth,
    );

    // Cancel any existing session
    cancel();

    // Default relays for nostrconnect:// connections.
    // Use NIP-46 compatible relays (relay.divine.video rejects Kind 24133).
    // These are public Nostr infrastructure relays — same URLs regardless of
    // app environment (dev/staging/prod).
    final relays =
        customRelays ??
        [
          'wss://relay.nsec.app',
          'wss://relay.damus.io',
          'wss://nos.lol',
          'wss://relay.primal.net',
        ];

    // Create the session
    _session = _sessionFactory(relays);

    // Start the session (generates keypair and URL, connects to relays)
    await _session!.start();

    Log.info(
      'NostrConnect session started, URL: ${_session!.connectUrl}',
      name: 'NostrConnectCoordinator',
      category: LogCategory.auth,
    );

    return _session!;
  }

  /// Wait for the bunker to respond to a nostrconnect:// URL.
  ///
  /// Must be called after [initiate].
  ///
  /// Returns [AuthResult.success] if the bunker connects and we can
  /// authenticate, or [AuthResult.failure] on timeout/error. Concurrent callers
  /// share the single in-flight wait.
  Future<AuthResult> waitForResponse({
    Duration timeout = const Duration(minutes: 2),
  }) {
    if (_session == null) {
      return Future.value(
        AuthResult.failure(
          'No active nostrconnect session. Call initiateNostrConnect first.',
        ),
      );
    }

    final activeWait = _waitFuture;
    if (activeWait != null) return activeWait;

    final waitFuture = _waitForResponse(timeout: timeout);
    _waitFuture = waitFuture;
    waitFuture.whenComplete(() {
      if (identical(_waitFuture, waitFuture)) {
        _waitFuture = null;
      }
    });
    return waitFuture;
  }

  Future<AuthResult> _waitForResponse({required Duration timeout}) async {
    Log.info(
      'Waiting for nostrconnect response (timeout: ${timeout.inSeconds}s)...',
      name: 'NostrConnectCoordinator',
      category: LogCategory.auth,
    );

    _onWaitStarted();

    try {
      // Keep a local reference in case session is cancelled during await
      final session = _session!;

      // Wait for the bunker to connect
      final result = await session.waitForConnection(timeout: timeout);

      // Check if session was cancelled while we were waiting
      if (_session == null) {
        _onWaitFailed();
        return AuthResult.nostrConnectFailure(
          NostrConnectFailureReason.cancelled,
        );
      }

      if (result == null) {
        // Timeout, cancellation, or a terminal session error.
        final state = session.state;
        _onWaitFailed();
        final reason = switch (state) {
          NostrConnectState.cancelled => NostrConnectFailureReason.cancelled,
          NostrConnectState.timeout => NostrConnectFailureReason.timedOut,
          NostrConnectState.error =>
            session.failureReason ??
                NostrConnectFailureReason.postConnectFailed,
          _ => NostrConnectFailureReason.postConnectFailed,
        };
        // `noExpectedSecret` is a programmer-invariant violation that "should
        // never happen": the response handler was reached with no secret to
        // validate against. Surface it to Crashlytics so a real break is
        // visible instead of reading as a routine "link expired" to the user.
        if (reason == NostrConnectFailureReason.noExpectedSecret) {
          _reportError(
            StateError(
              'nostrconnect response handling reached with no expected secret',
            ),
            StackTrace.current,
            reason: 'NostrConnect.noExpectedSecret',
            logMessage: 'nostrconnect invariant violated: no expected secret to validate',
          );
        }
        return AuthResult.nostrConnectFailure(reason);
      }

      // Success! Apply the connection on the facade (build signer + session).
      Log.info(
        'NostrConnect succeeded! Bunker pubkey: ${pubkeyForLogs(result.remoteSignerPubkey)}',
        name: 'NostrConnectCoordinator',
        category: LogCategory.auth,
      );

      final authResult = await _onConnected(result);

      // Clean up session (signer is now managing connections)
      _session?.dispose();
      _session = null;

      return authResult;
    } catch (e) {
      Log.error(
        'NostrConnect failed: $e',
        name: 'NostrConnectCoordinator',
        category: LogCategory.auth,
      );
      _onConnectFailed(e);

      return AuthResult.nostrConnectFailure(
        NostrConnectFailureReason.postConnectFailed,
      );
    }
  }

  /// Cancel an active nostrconnect:// session.
  ///
  /// Safe to call even if no session is active.
  void cancel() {
    _waitFuture = null;
    _isCallbackHandoffActive = false;
    _callbackHandoffTimer?.cancel();
    _callbackHandoffTimer = null;
    _callbackHandoffCancelTimer?.cancel();
    _callbackHandoffCancelTimer = null;

    if (_session != null) {
      Log.info(
        'Cancelling nostrconnect session',
        name: 'NostrConnectCoordinator',
        category: LogCategory.auth,
      );
      _session!.cancel();
      _session!.dispose();
      _session = null;
    }
  }

  /// Preserve the active session for the replacement NostrConnect screen.
  ///
  /// If no replacement screen claims the handoff quickly, cancel the session so
  /// backing out during the callback route handoff cannot orphan relay sockets.
  void preserveForCallbackHandoff() {
    if (!_isCallbackHandoffActive ||
        _session?.state != NostrConnectState.listening) {
      return;
    }

    _callbackHandoffCancelTimer?.cancel();
    _callbackHandoffCancelTimer = Timer(const Duration(seconds: 5), () {
      _callbackHandoffCancelTimer = null;
      if (_isCallbackHandoffActive &&
          _session?.state == NostrConnectState.listening) {
        Log.info(
          'NostrConnect callback handoff was not resumed - cancelling',
          name: 'NostrConnectCoordinator',
          category: LogCategory.auth,
        );
        cancel();
      }
    });
  }

  /// Marks the callback handoff as claimed by a mounted NostrConnect screen.
  ///
  /// The short handoff flag is left to expire on its own so an old route that
  /// disposes after the replacement screen mounts still preserves the session.
  void claimCallbackHandoff() {
    _callbackHandoffCancelTimer?.cancel();
    _callbackHandoffCancelTimer = null;
  }

  /// Called when a divine:// signer callback deep link is received.
  ///
  /// Ensures the nostrconnect session relay connections are alive so we
  /// don't miss the bunker's response event after being brought back
  /// from background.
  void onSignerCallbackReceived({String? relayUrl}) {
    if (_session?.state != NostrConnectState.listening) {
      return;
    }

    _isCallbackHandoffActive = true;
    _callbackHandoffTimer?.cancel();
    _callbackHandoffTimer = Timer(const Duration(seconds: 5), () {
      _isCallbackHandoffActive = false;
    });

    if (relayUrl != null) {
      Log.info(
        'Signer callback supplied relay $relayUrl - connecting',
        name: 'NostrConnectCoordinator',
        category: LogCategory.auth,
      );
      unawaited(_session!.addRelay(relayUrl));
    }
    Log.info(
      'Signer callback received - ensuring nostrconnect relays are connected',
      name: 'NostrConnectCoordinator',
      category: LogCategory.auth,
    );
    unawaited(_session!.ensureConnected());
  }

  /// Reconnect nostrconnect:// session relays that may have dropped while the
  /// app was backgrounded (e.g. the user switched to a signer app to approve
  /// the connection). No-op unless a session is actively listening.
  void reconnectListeningRelays() {
    if (_session != null && _session!.state == NostrConnectState.listening) {
      Log.info(
        '📱 App resumed - reconnecting nostrconnect session relays',
        name: 'NostrConnectCoordinator',
        category: LogCategory.auth,
      );
      _session!.ensureConnected();
    }
  }

  /// Cancels the callback-handoff timers on service teardown.
  ///
  /// Mirrors the facade's prior `dispose()` behavior exactly: it cancels the
  /// two handoff timers and deliberately leaves any live session untouched
  /// (the pre-existing behavior — see #4741 PR-R4).
  void dispose() {
    _callbackHandoffTimer?.cancel();
    _callbackHandoffTimer = null;
    _callbackHandoffCancelTimer?.cancel();
    _callbackHandoffCancelTimer = null;
  }
}
