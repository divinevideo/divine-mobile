// ABOUTME: Coordinates push registration and teardown against Nostr readiness.
// ABOUTME: Keeps mutable push-session lifecycle state out of Riverpod wiring.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

typedef PushReadinessReader = NostrSessionReadiness Function();
typedef PushServiceReader = PushNotificationService? Function();
typedef CleanupClientFactory = NostrClient Function(NostrIdentity identity);
typedef CleanupClientFactoryReader = CleanupClientFactory Function();

const _pushRegistrationCleanupWaitTimeout = Duration(seconds: 4);

enum _PushRegistrationPhase { beforePushService, mayPublish }

final class _PushRegistrationOperation {
  _PushRegistrationOperation({
    required this.pubkey,
    required this.client,
    required this.pushService,
    required this.identity,
  });

  final String pubkey;
  final NostrClient client;
  final PushNotificationService pushService;
  final NostrIdentity identity;
  Future<void>? future;
  String? pendingToken;
  int generation = 0;
  Timer? retryTimer;
  Completer<void>? retryWaiter;
  int retryCount = 0;
  int uncertainRetryCount = 0;
  Event? deferredCleanupDeregistrationEvent;
  _PushRegistrationPhase phase = _PushRegistrationPhase.beforePushService;
  bool cleanupScheduled = false;

  void wakeRetry() {
    retryTimer?.cancel();
    retryTimer = null;
    final waiter = retryWaiter;
    retryWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void cancel() => wakeRetry();
}

class PushNotificationSessionCoordinator {
  PushNotificationSessionCoordinator({
    required AuthService authService,
    required FirebaseMessaging firebaseMessaging,
    required PushReadinessReader readReadiness,
    required PushServiceReader readPushService,
    required CleanupClientFactoryReader readCleanupClientFactory,
  }) : _authService = authService,
       _firebaseMessaging = firebaseMessaging,
       _readReadiness = readReadiness,
       _readPushService = readPushService,
       _readCleanupClientFactory = readCleanupClientFactory;

  final AuthService _authService;
  final FirebaseMessaging _firebaseMessaging;
  final PushReadinessReader _readReadiness;
  final PushServiceReader _readPushService;
  final CleanupClientFactoryReader _readCleanupClientFactory;

  final _activeRegistrations = <_PushRegistrationOperation>{};
  static const _registrationRetryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
  ];
  StreamSubscription<String>? _tokenRefreshSubscription;
  Future<NotificationSettings>? _permissionRequestFuture;
  String? _lastReadyPubkey;
  NostrClient? _lastReadyClient;
  PushNotificationService? _lastReadyPushService;
  NostrIdentity? _lastReadyIdentity;
  CleanupClientFactory? _lastReadyCleanupClientFactory;

  void dispose() {
    if (_tokenRefreshSubscription != null) {
      runDetached(
        _tokenRefreshSubscription!.cancel(),
        'cancel the push-token refresh subscription',
        logName: 'PushNotificationSessionCoordinator',
        category: LogCategory.system,
      );
    }
    _tokenRefreshSubscription = null;
    _invalidateActiveRegistrations();
  }

  void handleAuthStateChange() {
    final pubkey = _lastReadyPubkey;
    if (pubkey != null && _authService.currentIdentity?.pubkey != pubkey) {
      _lastReadyPubkey = null;
      _lastReadyClient = null;
      _lastReadyPushService = null;
      _lastReadyIdentity = null;
      _lastReadyCleanupClientFactory = null;
      _invalidateActiveRegistrations();
    }
  }

  void handleReadiness(NostrSessionReadiness readiness) {
    final readyPubkey = readiness.pubkey;
    if (!readiness.isReadyForActiveClient || readyPubkey == null) {
      _invalidateActiveRegistrations();
      if (readyPubkey == null ||
          _authService.currentIdentity?.pubkey != readyPubkey ||
          (_lastReadyPubkey != null && _lastReadyPubkey != readyPubkey)) {
        _lastReadyPubkey = null;
        _lastReadyClient = null;
        _lastReadyPushService = null;
        _lastReadyIdentity = null;
        _lastReadyCleanupClientFactory = null;
      }
      return;
    }

    if (_authService.currentIdentity?.pubkey != readyPubkey) {
      _lastReadyPubkey = null;
      _lastReadyClient = null;
      _lastReadyPushService = null;
      _lastReadyIdentity = null;
      _lastReadyCleanupClientFactory = null;
      _invalidateActiveRegistrations();
      return;
    }

    final pushService = _readPushService();
    if (pushService == null) return;
    final identity = _authService.currentIdentity;
    if (identity == null || identity.pubkey != readyPubkey) {
      _lastReadyPubkey = null;
      _lastReadyClient = null;
      _lastReadyPushService = null;
      _lastReadyIdentity = null;
      _lastReadyCleanupClientFactory = null;
      _invalidateActiveRegistrations();
      return;
    }

    if (_activeRegistrations.any(
      (operation) =>
          operation.pubkey != readyPubkey ||
          !identical(operation.client, readiness.client) ||
          !identical(operation.pushService, pushService),
    )) {
      _invalidateActiveRegistrations();
    }

    _lastReadyPubkey = readyPubkey;
    _lastReadyClient = readiness.client;
    _lastReadyPushService = pushService;
    _lastReadyIdentity = identity;
    _lastReadyCleanupClientFactory = _readCleanupClientFactory();
    _ensureTokenRefreshSubscription();
    _triggerRegistration(
      pubkey: readyPubkey,
      client: readiness.client!,
      pushService: pushService,
      identity: identity,
    );
  }

  void _triggerRegistration({
    required String pubkey,
    required NostrClient client,
    required PushNotificationService pushService,
    required NostrIdentity identity,
    String? token,
  }) {
    final existing = _activeRegistrations.where(
      (operation) =>
          operation.pubkey == pubkey &&
          identical(operation.client, client) &&
          identical(operation.pushService, pushService),
    );
    if (existing.isNotEmpty) {
      final operation = existing.single;
      if (token != null) {
        operation.generation += 1;
        operation.pendingToken = token;
        operation.uncertainRetryCount = 0;
        operation.wakeRetry();
      }
      return;
    }
    if (!_isSessionCurrent(pubkey, client, pushService)) return;

    final operation = _PushRegistrationOperation(
      pubkey: pubkey,
      client: client,
      pushService: pushService,
      identity: identity,
    )..pendingToken = token;
    _activeRegistrations.add(operation);
    final registrationFuture = _requestPermissionAndRegister(operation);
    operation.future = registrationFuture;
    unawaited(
      registrationFuture.whenComplete(() {
        _activeRegistrations.remove(operation);
      }),
    );
  }

  void _ensureTokenRefreshSubscription() {
    _tokenRefreshSubscription ??= _firebaseMessaging.onTokenRefresh.listen(
      _handleTokenRefresh,
    );
  }

  void _handleTokenRefresh(String token) {
    final pubkey = _lastReadyPubkey;
    final client = _lastReadyClient;
    final pushService = _lastReadyPushService;
    final identity = _lastReadyIdentity;
    if (pubkey == null || client == null || pushService == null) return;
    if (identity == null || _authService.currentIdentity?.pubkey != pubkey) {
      return;
    }
    if (!_isOutgoingSessionCurrent(pubkey, client, pushService)) return;

    Log.info(
      'FCM token refreshed — re-registering',
      name: 'PushNotificationSync',
      category: LogCategory.system,
    );
    _triggerRegistration(
      pubkey: pubkey,
      client: client,
      pushService: pushService,
      identity: identity,
      token: token,
    );
  }

  Future<void> deregisterLastReadyPubkey() =>
      _deregisterLastReadyPubkey(requireCurrentSession: true);

  /// Deregisters the captured outgoing session after an account swap commits.
  ///
  /// Unlike sign-out teardown, this runs after the target container commits.
  /// The swap host retains the outgoing provider container until this work
  /// settles, while the captured pubkey and identity keep cleanup scoped to the
  /// account being left.
  Future<void> deregisterLastReadyPubkeyAfterAccountSwitch() =>
      _deregisterLastReadyPubkey(requireCurrentSession: false);

  Future<void> _deregisterLastReadyPubkey({
    required bool requireCurrentSession,
  }) async {
    final pubkey = _lastReadyPubkey;
    final client = _lastReadyClient;
    final pushService = _lastReadyPushService;
    final identity = _lastReadyIdentity;
    final createCleanupClient = _lastReadyCleanupClientFactory;
    final operations = List<_PushRegistrationOperation>.of(
      _activeRegistrations,
    );
    _invalidateActiveRegistrations();
    if (pubkey == null ||
        client == null ||
        pushService == null ||
        createCleanupClient == null) {
      return;
    }
    pushService.deactivateRegistration();

    Event? deferredCleanupDeregistrationEvent;
    for (final operation in operations) {
      if (operation.phase == _PushRegistrationPhase.mayPublish) {
        deferredCleanupDeregistrationEvent ??=
            await _createDeferredCleanupDeregistrationEvent(
              operation,
              requireCurrentSession: requireCurrentSession,
            );
        operation.deferredCleanupDeregistrationEvent ??=
            deferredCleanupDeregistrationEvent;
      }
    }

    final operationsToWait = operations
        .where(
          (operation) =>
              operation.phase != _PushRegistrationPhase.beforePushService,
        )
        .toList();
    if (operationsToWait.isNotEmpty) {
      try {
        await Future.wait(
          operationsToWait.map(
            (operation) =>
                operation.future?.timeout(
                  _pushRegistrationCleanupWaitTimeout,
                ) ??
                Future<void>.value(),
          ),
        );
      } on TimeoutException catch (e) {
        Log.warning(
          'Timed out waiting for push registration before deregistration: $e',
          name: 'PushNotificationSync',
          category: LogCategory.system,
        );
        operationsToWait.forEach(_scheduleDeregisterAfterRegistration);
        return;
      }
    }

    if (requireCurrentSession &&
        !_isOutgoingSessionCurrent(pubkey, client, pushService)) {
      return;
    }

    if (identity == null) {
      await _deregisterCapturedPubkey(
        pubkey,
        client,
        pushService,
        null,
        null,
        requireCurrentSession: requireCurrentSession,
      );
      return;
    }

    final deregistrationEvent = deferredCleanupDeregistrationEvent;
    if (deregistrationEvent != null) {
      try {
        await _publishDeregistrationWithCleanupClient(
          deregistrationEvent,
          pushService,
          identity,
          createCleanupClient,
        );
      } catch (e) {
        Log.warning(
          'Push notification sync listener failed: $e',
          name: 'PushNotificationSync',
          category: LogCategory.system,
        );
      }
      return;
    }

    await _deregisterWithCleanupClient(
      pubkey,
      client,
      pushService,
      identity,
      createCleanupClient: createCleanupClient,
      requireCurrentSession: requireCurrentSession,
    );
  }

  void _invalidateActiveRegistrations() {
    for (final operation in _activeRegistrations) {
      operation.cancel();
    }
    _activeRegistrations.clear();
  }

  bool _isRegistrationCurrent(_PushRegistrationOperation operation) {
    if (!_activeRegistrations.contains(operation) ||
        _authService.currentIdentity?.pubkey != operation.pubkey) {
      return false;
    }

    final currentReadiness = _readReadiness();
    if (!currentReadiness.isReadyForActiveClient ||
        currentReadiness.pubkey != operation.pubkey ||
        !identical(currentReadiness.client, operation.client)) {
      return false;
    }

    return identical(_readPushService(), operation.pushService);
  }

  Future<void> _requestPermissionAndRegister(
    _PushRegistrationOperation operation,
  ) async {
    try {
      final current = await _firebaseMessaging.getNotificationSettings();
      if (!_isRegistrationCurrent(operation)) return;

      final settings = await _resolvePermissionSettings(current);

      if (!_isRegistrationCurrent(operation)) return;

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        Log.info(
          'Push notification permission denied by user',
          name: 'PushNotificationSync',
          category: LogCategory.system,
        );
        return;
      }

      if (!_isRegistrationCurrent(operation)) return;

      operation.phase = _PushRegistrationPhase.mayPublish;
      bool isCurrent() => _isRegistrationCurrent(operation);
      while (_isRegistrationCurrent(operation)) {
        final generation = operation.generation;
        final token = operation.pendingToken;
        operation.pendingToken = null;
        late final PushRegistrationResult result;
        try {
          result = token == null
              ? await operation.pushService.register(
                  operation.pubkey,
                  isCurrent: isCurrent,
                )
              : await operation.pushService.registerToken(
                  operation.pubkey,
                  token,
                  isCurrent: isCurrent,
                );
        } catch (e, stackTrace) {
          Log.warning(
            'Push notification registration failed: $e',
            name: 'PushNotificationSync',
            category: LogCategory.system,
            stackTrace: stackTrace,
          );
          return;
        }
        if (!_isRegistrationCurrent(operation)) return;
        if (result == PushRegistrationResult.published) {
          operation.retryCount = 0;
          operation.uncertainRetryCount = 0;
        }
        if (operation.generation != generation) continue;
        switch (result) {
          case PushRegistrationResult.published:
          case PushRegistrationResult.terminalFailure:
            return;
          case PushRegistrationResult.uncertainFailure:
            if (operation.uncertainRetryCount >= 1) return;
            operation.uncertainRetryCount += 1;
            await _waitForRegistrationRetry(operation);
          case PushRegistrationResult.retryableFailure:
            await _waitForRegistrationRetry(operation);
        }
      }
    } catch (e) {
      Log.warning(
        'Push notification registration failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _waitForRegistrationRetry(
    _PushRegistrationOperation operation,
  ) async {
    final retryIndex = operation.retryCount.clamp(
      0,
      _registrationRetryDelays.length - 1,
    );
    operation.retryCount += 1;
    final waiter = Completer<void>();
    operation.retryWaiter = waiter;
    operation.retryTimer = Timer(
      _registrationRetryDelays[retryIndex],
      operation.wakeRetry,
    );
    await waiter.future;
  }

  bool _isSessionCurrent(
    String pubkey,
    NostrClient client,
    PushNotificationService pushService,
  ) {
    if (_authService.currentIdentity?.pubkey != pubkey) return false;
    final readiness = _readReadiness();
    return readiness.isReadyForActiveClient &&
        readiness.pubkey == pubkey &&
        identical(readiness.client, client) &&
        identical(_readPushService(), pushService);
  }

  Future<NotificationSettings> _resolvePermissionSettings(
    NotificationSettings current,
  ) async {
    if (current.authorizationStatus != AuthorizationStatus.notDetermined) {
      return current;
    }

    // Screenshot capture runs must never surface the iOS permission
    // dialog — it deadlocks the XCUITest waits.
    if (ScreenshotMode.enabled) return current;

    final existingRequest = _permissionRequestFuture;
    if (existingRequest != null) return existingRequest;

    final request = _firebaseMessaging.requestPermission();
    _permissionRequestFuture = request;
    try {
      return await request;
    } finally {
      if (identical(_permissionRequestFuture, request)) {
        _permissionRequestFuture = null;
      }
    }
  }

  bool _isOutgoingSessionCurrent(
    String pubkey,
    NostrClient client,
    PushNotificationService pushService,
  ) {
    final currentReadiness = _readReadiness();
    if (currentReadiness.pubkey != null && currentReadiness.pubkey != pubkey) {
      return false;
    }

    if (currentReadiness.isReadyForActiveClient &&
        !identical(currentReadiness.client, client)) {
      return false;
    }

    return identical(pushService, _lastReadyPushService);
  }

  Future<void> _deregisterCapturedPubkey(
    String pubkey,
    NostrClient client,
    PushNotificationService pushService,
    NostrIdentity? signingIdentity,
    NostrClient? publishClient, {
    required bool requireCurrentSession,
  }) async {
    try {
      await pushService.deregister(
        pubkey,
        isCurrent: requireCurrentSession && publishClient == null
            ? () => _isOutgoingSessionCurrent(pubkey, client, pushService)
            : null,
        signingIdentity: signingIdentity,
        publishClient: publishClient,
      );
    } catch (e) {
      Log.warning(
        'Push notification sync listener failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _publishDeregistrationWithCleanupClient(
    Event deregistrationEvent,
    PushNotificationService pushService,
    NostrIdentity identity,
    CleanupClientFactory createCleanupClient,
  ) async {
    final cleanupClient = createCleanupClient(identity);
    try {
      await cleanupClient.initialize();
      await pushService.publishDeregistrationEvent(
        deregistrationEvent,
        publishClient: cleanupClient,
      );
    } finally {
      await cleanupClient.dispose();
    }
  }

  Future<void> _deregisterWithCleanupClient(
    String pubkey,
    NostrClient client,
    PushNotificationService pushService,
    NostrIdentity identity, {
    required CleanupClientFactory createCleanupClient,
    required bool requireCurrentSession,
  }) async {
    try {
      if (requireCurrentSession &&
          !_isOutgoingSessionCurrent(pubkey, client, pushService)) {
        return;
      }
      final deregistrationEvent = await pushService
          .createSignedDeregistrationEvent(pubkey, signingIdentity: identity);
      if (deregistrationEvent == null) return;

      await _publishDeregistrationWithCleanupClient(
        deregistrationEvent,
        pushService,
        identity,
        createCleanupClient,
      );
    } catch (e) {
      Log.warning(
        'Push notification sync listener failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
    }
  }

  Future<Event?> _createDeferredCleanupDeregistrationEvent(
    _PushRegistrationOperation operation, {
    required bool requireCurrentSession,
  }) async {
    try {
      if (requireCurrentSession &&
          !_isOutgoingSessionCurrent(
            operation.pubkey,
            operation.client,
            operation.pushService,
          )) {
        return null;
      }
      return await operation.pushService.createSignedDeregistrationEvent(
        operation.pubkey,
        signingIdentity: operation.identity,
      );
    } catch (e) {
      Log.warning(
        'Push notification sync listener failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
      return null;
    }
  }

  void _scheduleDeregisterAfterRegistration(
    _PushRegistrationOperation operation,
  ) {
    if (operation.cleanupScheduled) return;
    final registrationFuture = operation.future;
    final deregistrationEvent = operation.deferredCleanupDeregistrationEvent;
    final createCleanupClient = _lastReadyCleanupClientFactory;
    if (registrationFuture == null) return;
    if (deregistrationEvent == null) return;
    if (createCleanupClient == null) return;
    operation.cleanupScheduled = true;
    unawaited(
      (() async {
        try {
          await registrationFuture;
          await _publishDeregistrationWithCleanupClient(
            deregistrationEvent,
            operation.pushService,
            operation.identity,
            createCleanupClient,
          );
        } catch (e) {
          Log.warning(
            'Push notification deferred cleanup failed: $e',
            name: 'PushNotificationSync',
            category: LogCategory.system,
          );
        }
      })(),
    );
  }
}
