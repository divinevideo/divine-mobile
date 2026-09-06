// ABOUTME: Tests for pushNotificationSync provider error handling.
// ABOUTME: Verifies firebase permission races don't escape the async listener.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPushNotificationService extends Mock
    implements PushNotificationService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockNotificationRefreshCoordinator extends Mock
    implements NotificationRefreshCoordinator {}

class _FakeEvent extends Fake implements Event {
  @override
  String get id => 'fake-event-id';
}

class _MockEvent extends Mock implements Event {}

class _FakeNotificationPreferencesStore
    implements NotificationPreferencesStore {
  final publishedSchemaVersions = <String, int>{};

  @override
  Future<int?> loadPublishedSchemaVersion(String pubkey) async =>
      publishedSchemaVersions[pubkey];

  @override
  Future<void> savePublishedSchemaVersion(String pubkey, int version) async {
    publishedSchemaVersions[pubkey] = version;
  }

  NotificationPreferences? savedPreferences;
  final dirtyPreferencesByPubkey = <String, NotificationPreferences>{};
  final _clearWaitersByPubkey = <String, List<Completer<void>>>{};

  Future<void> waitForClear(String pubkey) {
    if (!dirtyPreferencesByPubkey.containsKey(pubkey)) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _clearWaitersByPubkey.putIfAbsent(pubkey, () => []).add(completer);
    return completer.future;
  }

  @override
  Future<NotificationPreferences> loadPreferences() async {
    return savedPreferences ?? const NotificationPreferences();
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    savedPreferences = preferences;
  }

  @override
  Future<void> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    dirtyPreferencesByPubkey[pubkey] = preferences;
  }

  @override
  Future<NotificationPreferences?> loadDirty(String pubkey) async {
    return dirtyPreferencesByPubkey[pubkey];
  }

  @override
  Future<void> clearDirty(String pubkey) async {
    dirtyPreferencesByPubkey.remove(pubkey);
    final waiters = _clearWaitersByPubkey.remove(pubkey) ?? const [];
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  @override
  Future<void> clearDirtyIfMatches(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    if (dirtyPreferencesByPubkey[pubkey] == preferences) {
      await clearDirty(pubkey);
    }
  }
}

class _ConfiguredEnvironmentConfig extends EnvironmentConfig {
  const _ConfiguredEnvironmentConfig({
    required super.environment,
    required this.configuredPushServicePubkey,
  });

  final String configuredPushServicePubkey;

  @override
  String get pushServicePubkey => configuredPushServicePubkey;
}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._initialReadiness);

  final NostrSessionReadiness _initialReadiness;

  @override
  NostrSessionReadiness build() => _initialReadiness;

  void setReadiness(NostrSessionReadiness readiness) {
    state = readiness;
  }
}

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
    );

NostrIdentity _identity(String pubkey) =>
    KeycastNostrIdentity(pubkey: pubkey, rpcSigner: _MockNostrSigner());

PublishOutcome _acceptedOutcome(Event event, String relayUrl) => PublishOutcome(
  eventId: event.id,
  acceptedBy: [relayUrl],
  rejectedBy: const {},
  noResponseFrom: const [],
);

void main() {
  late _MockFirebaseMessaging messaging;
  late _MockAuthService authService;
  late _MockPushNotificationService pushService;
  late _MockNostrClient nostrClient;
  late _MockNostrClient defaultCleanupClient;
  late _FakeNotificationPreferencesStore preferenceStore;
  late StreamController<AuthState> authStateController;
  late StreamController<String> defaultTokenRefreshController;
  BeforeSessionTeardownCallback? beforeSessionTeardownCallback;

  const pubkeyA =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const pubkeyB =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const pushServicePubkey =
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
  const pushEnvironment = _ConfiguredEnvironmentConfig(
    environment: AppEnvironment.staging,
    configuredPushServicePubkey: pushServicePubkey,
  );
  const stagingEnvironment = _ConfiguredEnvironmentConfig(
    environment: AppEnvironment.staging,
    configuredPushServicePubkey: pushServicePubkey,
  );

  setUpAll(() {
    registerFallbackValue(const NotificationPreferences());
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_identity(pubkeyA));
    registerFallbackValue(<String>[]);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    messaging = _MockFirebaseMessaging();
    authService = _MockAuthService();
    pushService = _MockPushNotificationService();
    nostrClient = _MockNostrClient();
    defaultCleanupClient = _MockNostrClient();
    preferenceStore = _FakeNotificationPreferencesStore();
    authStateController = StreamController<AuthState>.broadcast();
    defaultTokenRefreshController = StreamController<String>.broadcast();

    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);
    when(
      () => messaging.onTokenRefresh,
    ).thenAnswer((_) => defaultTokenRefreshController.stream);
    when(() => authService.authState).thenReturn(AuthState.unauthenticated);
    when(() => authService.currentIdentity).thenReturn(null);
    when(() => authService.currentPublicKeyHex).thenReturn(null);
    when(
      () => authService.registerBeforeSessionTeardownCallback(any()),
    ).thenAnswer((invocation) {
      beforeSessionTeardownCallback =
          invocation.positionalArguments.single
              as BeforeSessionTeardownCallback;
      return () => beforeSessionTeardownCallback = null;
    });

    when(
      () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
    ).thenAnswer((_) async => PushRegistrationResult.published);
    when(
      () => pushService.deregister(any(), isCurrent: any(named: 'isCurrent')),
    ).thenAnswer((_) async {});
    when(
      () => pushService.deregister(
        any(),
        isCurrent: any(named: 'isCurrent'),
        signingIdentity: any(named: 'signingIdentity'),
        publishClient: any(named: 'publishClient'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => pushService.deregister(
        any(),
        signingIdentity: any(named: 'signingIdentity'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => pushService.deregister(
        any(),
        signingIdentity: any(named: 'signingIdentity'),
        publishClient: any(named: 'publishClient'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => pushService.createSignedDeregistrationEvent(
        any(),
        signingIdentity: any(named: 'signingIdentity'),
      ),
    ).thenAnswer((_) async => _FakeEvent());
    when(
      () => pushService.publishDeregistrationEvent(
        any(),
        publishClient: any(named: 'publishClient'),
      ),
    ).thenAnswer((_) async {});
    when(() => nostrClient.hasKeys).thenReturn(true);
    when(() => nostrClient.publicKey).thenReturn(pubkeyA);
    when(() => defaultCleanupClient.initialize()).thenAnswer((_) async {});
    when(() => defaultCleanupClient.dispose()).thenAnswer((_) async {});
    when(
      () => defaultCleanupClient.publishEventAwaitOk(
        any(),
        targetRelays: any(named: 'targetRelays'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (invocation) async => _acceptedOutcome(
        invocation.positionalArguments.single as Event,
        pushEnvironment.relayUrl,
      ),
    );
  });

  tearDown(() async {
    await authStateController.close();
    await defaultTokenRefreshController.close();
  });

  ProviderContainer buildContainer({
    _TestNostrSession? nostrSession,
    List<dynamic> extraOverrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        firebaseMessagingProvider.overrideWithValue(messaging),
        authServiceProvider.overrideWithValue(authService),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        notificationPreferencesStoreProvider.overrideWithValue(preferenceStore),
        nostrSessionProvider.overrideWith(
          () =>
              nostrSession ??
              _TestNostrSession(const NostrSessionReadiness.signedOut()),
        ),
        if (extraOverrides.isEmpty)
          nostrClientFactoryProvider.overrideWithValue(
            ({dbClient, environmentConfig, signer, statisticsService}) =>
                defaultCleanupClient,
          ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> emitReady(_TestNostrSession nostrSession, String pubkey) async {
    when(() => authService.currentIdentity).thenReturn(_identity(pubkey));
    when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
    when(() => nostrClient.publicKey).thenReturn(pubkey);
    nostrSession.setReadiness(
      NostrSessionReadiness.nostrReady(pubkey: pubkey, client: nostrClient),
    );
    await pumpEventQueue(times: 1);
    await pumpEventQueue(times: 1);
  }

  void recordMockDeregistration(
    List<String> events, {
    String Function(NostrClient? publishClient)? suffixForPublishClient,
  }) {
    final pubkeysByEvent = <Event, String>{};
    when(
      () => pushService.createSignedDeregistrationEvent(
        any(),
        signingIdentity: any(named: 'signingIdentity'),
      ),
    ).thenAnswer((invocation) async {
      final event = _MockEvent();
      pubkeysByEvent[event] = invocation.positionalArguments.single as String;
      return event;
    });
    when(
      () => pushService.publishDeregistrationEvent(
        any(),
        publishClient: any(named: 'publishClient'),
      ),
    ).thenAnswer((invocation) async {
      final event = invocation.positionalArguments.single as Event;
      final publishClient =
          invocation.namedArguments[#publishClient] as NostrClient?;
      final suffix = suffixForPublishClient == null
          ? ''
          : ' ${suffixForPublishClient(publishClient)}';
      events.add('deregister ${pubkeysByEvent[event]}$suffix');
    });
  }

  group('pushNotificationSync', () {
    test(
      'foreground message schedules an authoritative Inbox refresh',
      () async {
        final messages = StreamController<RemoteMessage>.broadcast();
        final refreshCoordinator = _MockNotificationRefreshCoordinator();
        addTearDown(messages.close);
        when(
          () => pushService.handleForegroundMessage(any()),
        ).thenAnswer((_) async {});
        when(refreshCoordinator.schedulePushRefresh).thenReturn(null);
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        final container = buildContainer(
          extraOverrides: [
            firebaseOnMessageProvider.overrideWithValue(messages.stream),
            notificationRefreshCoordinatorProvider.overrideWithValue(
              refreshCoordinator,
            ),
          ],
        );

        container.read(pushNotificationSyncProvider);
        messages.add(
          const RemoteMessage(
            data: {'title': 'New like', 'body': 'Someone'},
          ),
        );
        await pumpEventQueue(times: 1);

        verify(
          () => pushService.handleForegroundMessage(const {
            'title': 'New like',
            'body': 'Someone',
          }),
        ).called(1);
        verify(refreshCoordinator.schedulePushRefresh).called(1);
      },
    );

    test(
      'does not publish stale registration when auth changes mid-flight',
      () async {
        const encryptedPayload = 'encrypted-token-payload';
        final tokenCompleter = Completer<String?>();
        final tokenRefreshController = StreamController<String>.broadcast();
        final signer = _MockNostrSigner();
        final event = _FakeEvent();
        addTearDown(tokenRefreshController.close);
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => messaging.getToken(),
        ).thenAnswer((_) => tokenCompleter.future);
        when(
          () => messaging.onTokenRefresh,
        ).thenAnswer((_) => tokenRefreshController.stream);
        when(() => nostrClient.signer).thenReturn(signer);
        when(
          () => signer.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => encryptedPayload);
        when(
          () => authService.createAndSignEvent(
            kind: PushNotificationService.pushRegistrationKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => event);
        when(
          () => nostrClient.publishEventAwaitOk(
            event,
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => _acceptedOutcome(event, pushEnvironment.relayUrl),
        );

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            notificationServiceProvider.overrideWithValue(
              _MockNotificationService(),
            ),
            currentEnvironmentProvider.overrideWith(
              (_) =>
                  const EnvironmentConfig(environment: AppEnvironment.staging),
            ),
            nostrSessionProvider.overrideWith(() => nostrSession),
          ],
        );
        addTearDown(container.dispose);
        container.read(pushNotificationSyncProvider);

        await emitReady(nostrSession, pubkeyA);
        await pumpEventQueue(times: 1);
        verify(() => messaging.getToken()).called(1);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyB));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);
        authStateController.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);

        tokenCompleter.complete('fcm-token-for-stale-session');
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        verifyNever(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
      },
    );

    test('registers only after Nostr session is ready', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

      final nostrSession = _TestNostrSession(
        const NostrSessionReadiness.signedOut(),
      );
      final container = buildContainer(nostrSession: nostrSession);
      container.read(pushNotificationSyncProvider);

      when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
      authStateController.add(AuthState.authenticated);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      verifyNever(
        () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
      );

      await emitReady(nostrSession, pubkeyA);

      verify(
        () => pushService.register(pubkeyA, isCurrent: any(named: 'isCurrent')),
      ).called(1);
    });

    test('retries a retryable registration failure', () {
      fakeAsync((async) {
        var registerCalls = 0;
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer(
          (_) async => ++registerCalls > 1
              ? PushRegistrationResult.published
              : PushRegistrationResult.retryableFailure,
        );

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();

        expect(registerCalls, 1);
        // Repeated readiness must not create a concurrent or immediate drain.
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();
        expect(registerCalls, 1);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(registerCalls, 2);
        container.dispose();
      });
    });

    test('does not retry a terminal registration failure', () {
      fakeAsync((async) {
        var registerCalls = 0;
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((_) async {
          registerCalls += 1;
          return PushRegistrationResult.terminalFailure;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();

        expect(registerCalls, 1);
        container.dispose();
      });
    });

    test('does not retry an unexpected registration exception', () {
      fakeAsync((async) {
        var registerCalls = 0;
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((_) async {
          registerCalls += 1;
          throw StateError('unexpected registration failure');
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();

        expect(registerCalls, 1);
        container.dispose();
      });
    });

    test('retries an uncertain publish once, then stops', () {
      fakeAsync((async) {
        var registerCalls = 0;
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((_) async {
          registerCalls += 1;
          return PushRegistrationResult.uncertainFailure;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();

        expect(registerCalls, 1);
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(registerCalls, 2);
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();
        expect(registerCalls, 2);
        container.dispose();
      });
    });

    test(
      'invalidation wakes a parked retry so teardown deregisters without '
      'waiting out the registration timeout',
      () {
        fakeAsync((async) {
          when(
            () => messaging.getNotificationSettings(),
          ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
          // Registration never succeeds, so the drain parks on the backoff
          // timer with no publish in flight.
          when(
            () =>
                pushService.register(any(), isCurrent: any(named: 'isCurrent')),
          ).thenAnswer((_) async => PushRegistrationResult.retryableFailure);

          final nostrSession = _TestNostrSession(
            const NostrSessionReadiness.signedOut(),
          );
          final container = buildContainer(nostrSession: nostrSession);
          container.read(pushNotificationSyncProvider);
          when(
            () => authService.currentIdentity,
          ).thenReturn(_identity(pubkeyA));
          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
          nostrSession.setReadiness(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          );
          async.flushMicrotasks();

          verify(
            () => pushService.register(
              pubkeyA,
              isCurrent: any(named: 'isCurrent'),
            ),
          ).called(1);

          unawaited(beforeSessionTeardownCallback!());
          async.flushMicrotasks();

          // Invalidation wakes the parked retry, so the registration future
          // completes now and cleanup publishes without elapsing the 4s
          // _pushRegistrationCleanupWaitTimeout. Without the wake this
          // deregistration only happens via the timeout fallback.
          verify(defaultCleanupClient.initialize).called(1);

          container.dispose();
        });
      },
    );

    test('publishes a refreshed token received during registration', () {
      fakeAsync((async) {
        final firstPublish = Completer<PushRegistrationResult>();
        var registerCalls = 0;
        var refreshedTokenCalls = 0;
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((_) {
          registerCalls += 1;
          return firstPublish.future;
        });
        when(
          () => pushService.registerToken(
            any(),
            any(),
            isCurrent: any(named: 'isCurrent'),
          ),
        ).thenAnswer((_) async {
          refreshedTokenCalls += 1;
          return PushRegistrationResult.published;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();
        expect(registerCalls, 1);

        defaultTokenRefreshController.add('refreshed-token');
        async.flushMicrotasks();
        firstPublish.complete(PushRegistrationResult.published);
        async.flushMicrotasks();

        expect(refreshedTokenCalls, 1);
        container.dispose();
      });
    });

    test('account change cancels the old registration retry drain', () {
      fakeAsync((async) {
        final registeredPubkeys = <String>[];
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          final pubkey = invocation.positionalArguments.single as String;
          registeredPubkeys.add(pubkey);
          return pubkey == pubkeyB
              ? PushRegistrationResult.published
              : PushRegistrationResult.retryableFailure;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyB));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);
        when(() => nostrClient.publicKey).thenReturn(pubkeyB);
        authStateController.add(AuthState.authenticated);
        async.flushMicrotasks();
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyB,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();

        expect(registeredPubkeys, [pubkeyA, pubkeyB]);
        container.dispose();
      });
    });

    test('ignores stale readiness for an old account', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

      final nostrSession = _TestNostrSession(
        const NostrSessionReadiness.signedOut(),
      );
      final container = buildContainer(nostrSession: nostrSession);
      container.read(pushNotificationSyncProvider);

      when(() => authService.currentIdentity).thenReturn(_identity(pubkeyB));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);
      nostrSession.setReadiness(
        NostrSessionReadiness.nostrReady(pubkey: pubkeyA, client: nostrClient),
      );
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      verifyNever(
        () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
      );

      await emitReady(nostrSession, pubkeyB);

      verify(
        () => pushService.register(pubkeyB, isCurrent: any(named: 'isCurrent')),
      ).called(1);
    });

    test(
      'clears teardown target when ready session no longer matches auth',
      () async {
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);

        await emitReady(nostrSession, pubkeyA);
        verify(
          () =>
              pushService.register(pubkeyA, isCurrent: any(named: 'isCurrent')),
        ).called(1);
        clearInteractions(pushService);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyB));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        await beforeSessionTeardownCallback!();

        verifyNever(
          () => pushService.createSignedDeregistrationEvent(
            any(),
            signingIdentity: any(named: 'signingIdentity'),
          ),
        );
      },
    );

    test('aborts deferred registration when ready session changes', () async {
      final settingsCompleter = Completer<NotificationSettings>();
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) => settingsCompleter.future);

      final nostrSession = _TestNostrSession(
        const NostrSessionReadiness.signedOut(),
      );
      final container = buildContainer(nostrSession: nostrSession);
      container.read(pushNotificationSyncProvider);

      when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
      nostrSession.setReadiness(
        NostrSessionReadiness.nostrReady(pubkey: pubkeyA, client: nostrClient),
      );
      await pumpEventQueue(times: 1);

      when(() => authService.currentIdentity).thenReturn(null);
      when(() => authService.currentPublicKeyHex).thenReturn(null);
      nostrSession.setReadiness(const NostrSessionReadiness.signedOut());

      settingsCompleter.complete(_settings(AuthorizationStatus.authorized));
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      verifyNever(
        () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
      );
    });

    test(
      'deregisters last ready pubkey when permission check blocks registration',
      () async {
        final settingsCompleter = Completer<NotificationSettings>();
        final events = <String>[];
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) => settingsCompleter.future);
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          events.add('register ${invocation.positionalArguments.single}');
          return PushRegistrationResult.published;
        });
        recordMockDeregistration(events);

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);

        await emitReady(nostrSession, pubkeyA);

        final teardownFuture = beforeSessionTeardownCallback!().timeout(
          const Duration(milliseconds: 100),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        await teardownFuture;
        when(() => authService.currentIdentity).thenReturn(null);
        when(() => authService.currentPublicKeyHex).thenReturn(null);
        expect(events, ['deregister $pubkeyA']);

        settingsCompleter.complete(_settings(AuthorizationStatus.authorized));
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(events, ['deregister $pubkeyA']);
        verifyNever(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        );
      },
    );

    test(
      'does not publish duplicate registration when queued preferences drain',
      () async {
        final settingsCompleter = Completer<NotificationSettings>();
        final publishCompleter = Completer<void>();
        var registerCalls = 0;
        const prefs = NotificationPreferences(commentsEnabled: false);
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) => settingsCompleter.future);
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          registerCalls += 1;
          final isCurrent =
              invocation.namedArguments[#isCurrent]
                  as FutureOr<bool> Function();
          if (await isCurrent()) {
            await publishCompleter.future;
          }
          return PushRegistrationResult.published;
        });
        when(
          () => pushService.updatePreferences(prefs),
        ).thenAnswer((_) async => true);

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        await container
            .read(notificationPreferencesServiceProvider)
            .updatePreferences(prefs);

        await emitReady(nostrSession, pubkeyA);
        await pumpEventQueue(times: 1);

        settingsCompleter.complete(_settings(AuthorizationStatus.authorized));
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        expect(registerCalls, equals(1));

        publishCompleter.complete();
        await pumpEventQueue(times: 1);
      },
    );

    test(
      'waits for in-flight registration that reached push service before deregistering',
      () async {
        final registerCompleter = Completer<void>();
        final events = <String>[];
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          events.add('register ${invocation.positionalArguments.single}');
          await registerCompleter.future;
          return PushRegistrationResult.published;
        });
        recordMockDeregistration(events);

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(nostrSession: nostrSession);
        container.read(pushNotificationSyncProvider);

        await emitReady(nostrSession, pubkeyA);
        await pumpEventQueue(times: 1);
        expect(events, ['register $pubkeyA']);

        final teardownFuture = beforeSessionTeardownCallback!();
        await pumpEventQueue(times: 1);

        expect(events, ['register $pubkeyA']);

        registerCompleter.complete();
        await teardownFuture;

        expect(events, ['register $pubkeyA', 'deregister $pubkeyA']);
      },
    );

    test('signs deferred cleanup before teardown returns', () {
      fakeAsync((async) {
        final registerCompleter = Completer<void>();
        final cleanupClient = _MockNostrClient();
        final events = <String>[];
        final pubkeysByEvent = <Event, String>{};
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          events.add('register ${invocation.positionalArguments.single}');
          await registerCompleter.future;
          return PushRegistrationResult.published;
        });
        when(
          () => pushService.createSignedDeregistrationEvent(
            any(),
            signingIdentity: any(named: 'signingIdentity'),
          ),
        ).thenAnswer((invocation) async {
          final event = _MockEvent();
          final pubkey = invocation.positionalArguments.single as String;
          pubkeysByEvent[event] = pubkey;
          events.add('sign $pubkey');
          return event;
        });
        when(
          () => pushService.publishDeregistrationEvent(
            any(),
            publishClient: any(named: 'publishClient'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.single as Event;
          final publishClient =
              invocation.namedArguments[#publishClient] as NostrClient?;
          events.add(
            'publish ${pubkeysByEvent[event]} cleanup ${identical(publishClient, cleanupClient)}',
          );
        });
        // ignore: unnecessary_lambdas
        when(() => cleanupClient.initialize()).thenAnswer((_) async {});
        // ignore: unnecessary_lambdas
        when(() => cleanupClient.dispose()).thenAnswer((_) async {});

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(
          nostrSession: nostrSession,
          extraOverrides: [
            nostrClientFactoryProvider.overrideWithValue(
              ({dbClient, environmentConfig, signer, statisticsService}) =>
                  cleanupClient,
            ),
          ],
        );
        container.read(pushNotificationSyncProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => nostrClient.publicKey).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();

        var teardownCompleted = false;
        unawaited(
          beforeSessionTeardownCallback!().then((_) {
            teardownCompleted = true;
          }),
        );
        async.flushMicrotasks();

        expect(teardownCompleted, isFalse);
        expect(events, ['register $pubkeyA', 'sign $pubkeyA']);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(teardownCompleted, isTrue);
        expect(events, ['register $pubkeyA', 'sign $pubkeyA']);

        when(() => authService.currentIdentity).thenReturn(null);
        when(() => authService.currentPublicKeyHex).thenReturn(null);
        registerCompleter.complete();
        async.flushMicrotasks();

        expect(events, [
          'register $pubkeyA',
          'sign $pubkeyA',
          'publish $pubkeyA cleanup true',
        ]);
      });
    });

    test(
      'retains deregistration cleanup when reached registration outlives teardown wait',
      () {
        fakeAsync((async) {
          final registerCompleter = Completer<void>();
          final cleanupClient = _MockNostrClient();
          final events = <String>[];
          when(
            () => messaging.getNotificationSettings(),
          ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
          when(
            () =>
                pushService.register(any(), isCurrent: any(named: 'isCurrent')),
          ).thenAnswer((invocation) async {
            events.add('register ${invocation.positionalArguments.single}');
            await registerCompleter.future;
            return PushRegistrationResult.published;
          });
          recordMockDeregistration(events);
          // ignore: unnecessary_lambdas
          when(() => cleanupClient.initialize()).thenAnswer((_) async {});
          // ignore: unnecessary_lambdas
          when(() => cleanupClient.dispose()).thenAnswer((_) async {});

          final nostrSession = _TestNostrSession(
            const NostrSessionReadiness.signedOut(),
          );
          final container = buildContainer(
            nostrSession: nostrSession,
            extraOverrides: [
              nostrClientFactoryProvider.overrideWithValue(
                ({dbClient, environmentConfig, signer, statisticsService}) =>
                    cleanupClient,
              ),
            ],
          );
          container.read(pushNotificationSyncProvider);

          when(
            () => authService.currentIdentity,
          ).thenReturn(_identity(pubkeyA));
          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
          when(() => nostrClient.publicKey).thenReturn(pubkeyA);
          nostrSession.setReadiness(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          );
          async.flushMicrotasks();

          expect(events, ['register $pubkeyA']);

          var teardownCompleted = false;
          unawaited(
            beforeSessionTeardownCallback!().then((_) {
              teardownCompleted = true;
            }),
          );
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(teardownCompleted, isTrue);
          expect(events, ['register $pubkeyA']);

          registerCompleter.complete();
          async.flushMicrotasks();

          expect(events, ['register $pubkeyA', 'deregister $pubkeyA']);
        });
      },
    );

    test('deferred cleanup can deregister after auth has been cleared', () {
      fakeAsync((async) {
        final registerCompleter = Completer<void>();
        final cleanupClient = _MockNostrClient();
        final events = <String>[];
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          events.add('register ${invocation.positionalArguments.single}');
          await registerCompleter.future;
          return PushRegistrationResult.published;
        });
        recordMockDeregistration(events);
        // ignore: unnecessary_lambdas
        when(() => cleanupClient.initialize()).thenAnswer((_) async {});
        // ignore: unnecessary_lambdas
        when(() => cleanupClient.dispose()).thenAnswer((_) async {});

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(
          nostrSession: nostrSession,
          extraOverrides: [
            nostrClientFactoryProvider.overrideWithValue(
              ({dbClient, environmentConfig, signer, statisticsService}) =>
                  cleanupClient,
            ),
          ],
        );
        container.read(pushNotificationSyncProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => nostrClient.publicKey).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();

        expect(events, ['register $pubkeyA']);

        var teardownCompleted = false;
        unawaited(
          beforeSessionTeardownCallback!().then((_) {
            teardownCompleted = true;
          }),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(teardownCompleted, isTrue);

        when(() => authService.currentIdentity).thenReturn(null);
        when(() => authService.currentPublicKeyHex).thenReturn(null);
        registerCompleter.complete();
        async.flushMicrotasks();

        expect(events, ['register $pubkeyA', 'deregister $pubkeyA']);
      });
    });

    test('deferred cleanup uses a retained publish client', () {
      fakeAsync((async) {
        final registerCompleter = Completer<void>();
        final cleanupClient = _MockNostrClient();
        final events = <String>[];
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          events.add('register ${invocation.positionalArguments.single}');
          await registerCompleter.future;
          return PushRegistrationResult.published;
        });
        // ignore: unnecessary_lambdas
        when(() => cleanupClient.initialize()).thenAnswer((_) async {});
        // ignore: unnecessary_lambdas
        when(() => cleanupClient.dispose()).thenAnswer((_) async {});
        recordMockDeregistration(
          events,
          suffixForPublishClient: (publishClient) =>
              'with cleanup client ${identical(publishClient, cleanupClient)}',
        );

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = buildContainer(
          nostrSession: nostrSession,
          extraOverrides: [
            nostrClientFactoryProvider.overrideWithValue(
              ({dbClient, environmentConfig, signer, statisticsService}) =>
                  cleanupClient,
            ),
          ],
        );
        container.read(pushNotificationSyncProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => nostrClient.publicKey).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        async.flushMicrotasks();

        expect(events, ['register $pubkeyA']);

        unawaited(beforeSessionTeardownCallback!());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        when(() => authService.currentIdentity).thenReturn(null);
        when(() => authService.currentPublicKeyHex).thenReturn(null);
        registerCompleter.complete();
        async.flushMicrotasks();

        expect(events, [
          'register $pubkeyA',
          'deregister $pubkeyA with cleanup client true',
        ]);
        // ignore: unnecessary_lambdas
        verify(() => cleanupClient.initialize()).called(1);
        // ignore: unnecessary_lambdas
        verify(() => cleanupClient.dispose()).called(1);
      });
    });

    test('skips requestPermission when status is already authorized', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

      final container = buildContainer();
      final nostrSession =
          container.read(nostrSessionProvider.notifier) as _TestNostrSession;
      container.read(pushNotificationSyncProvider);

      await emitReady(nostrSession, pubkeyA);

      verify(() => messaging.getNotificationSettings()).called(1);
      verifyNever(
        () => messaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(
            named: 'providesAppNotificationSettings',
          ),
        ),
      );
      verify(
        () => pushService.register(pubkeyA, isCurrent: any(named: 'isCurrent')),
      ).called(1);
    });

    test('requests permission when status is notDetermined', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.notDetermined));
      when(
        () => messaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(
            named: 'providesAppNotificationSettings',
          ),
        ),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

      final container = buildContainer();
      final nostrSession =
          container.read(nostrSessionProvider.notifier) as _TestNostrSession;
      container.read(pushNotificationSyncProvider);

      await emitReady(nostrSession, pubkeyA);

      verify(
        () => messaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(
            named: 'providesAppNotificationSettings',
          ),
        ),
      ).called(1);
      verify(
        () => pushService.register(pubkeyA, isCurrent: any(named: 'isCurrent')),
      ).called(1);
    });

    test(
      'catches PlatformException from firebase_messaging permission race',
      () async {
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.notDetermined));
        when(
          () => messaging.requestPermission(
            alert: any(named: 'alert'),
            announcement: any(named: 'announcement'),
            badge: any(named: 'badge'),
            carPlay: any(named: 'carPlay'),
            criticalAlert: any(named: 'criticalAlert'),
            provisional: any(named: 'provisional'),
            sound: any(named: 'sound'),
            providesAppNotificationSettings: any(
              named: 'providesAppNotificationSettings',
            ),
          ),
        ).thenThrow(
          PlatformException(
            code: 'firebase_messaging/unknown',
            message:
                'A request for permissions is already running, '
                'please wait for it to finish before doing another request.',
          ),
        );

        final container = buildContainer();
        container.read(pushNotificationSyncProvider);

        // Collect any unhandled async errors from the listener.
        final unhandled = <Object>[];
        await runZonedGuarded(() async {
          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
          when(
            () => authService.currentIdentity,
          ).thenReturn(_identity(pubkeyA));
          final nostrSession =
              container.read(nostrSessionProvider.notifier)
                  as _TestNostrSession;
          nostrSession.setReadiness(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          );
          await pumpEventQueue(times: 1);
          await pumpEventQueue(times: 1);
          await pumpEventQueue(times: 1);
        }, (error, stack) => unhandled.add(error));

        expect(
          unhandled,
          isEmpty,
          reason:
              'PlatformException from firebase_messaging must be caught '
              'inside the listener — otherwise it escapes to the enclosing '
              'zone and fails the surrounding integration test.',
        );
        // Permission failed, so pushService.register must not be invoked.
        verifyNever(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        );
      },
    );

    test('catches errors from pushService.register', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
      when(
        () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
      ).thenThrow(StateError('relay unreachable'));

      final container = buildContainer();
      container.read(pushNotificationSyncProvider);

      final unhandled = <Object>[];
      await runZonedGuarded(() async {
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        final nostrSession =
            container.read(nostrSessionProvider.notifier) as _TestNostrSession;
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
      }, (error, stack) => unhandled.add(error));

      expect(unhandled, isEmpty);
    });

    test(
      'catches errors from pushService.publishDeregistrationEvent',
      () async {
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.publishDeregistrationEvent(
            any(),
            publishClient: any(named: 'publishClient'),
          ),
        ).thenThrow(StateError('relay unreachable'));

        final container = buildContainer();
        container.read(pushNotificationSyncProvider);

        final unhandled = <Object>[];
        await runZonedGuarded(() async {
          // First emit readiness to set the last ready pubkey.
          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
          when(
            () => authService.currentIdentity,
          ).thenReturn(_identity(pubkeyA));
          final nostrSession =
              container.read(nostrSessionProvider.notifier)
                  as _TestNostrSession;
          nostrSession.setReadiness(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          );
          await pumpEventQueue(times: 1);
          await pumpEventQueue(times: 1);

          // Then start sign-out teardown — publishing deregistration throws.
          await beforeSessionTeardownCallback!();
          await pumpEventQueue(times: 1);
          await pumpEventQueue(times: 1);
        }, (error, stack) => unhandled.add(error));

        expect(unhandled, isEmpty);
      },
    );

    test('deregisters ready pubkey before session teardown', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

      final container = buildContainer();
      container.read(pushNotificationSyncProvider);

      final nostrSession =
          container.read(nostrSessionProvider.notifier) as _TestNostrSession;
      await emitReady(nostrSession, pubkeyA);

      expect(beforeSessionTeardownCallback, isNotNull);

      await beforeSessionTeardownCallback!();

      verify(
        () => pushService.createSignedDeregistrationEvent(
          pubkeyA,
          signingIdentity: any(named: 'signingIdentity'),
        ),
      ).called(1);
      verify(
        () => pushService.publishDeregistrationEvent(
          any(),
          publishClient: any(named: 'publishClient'),
        ),
      ).called(1);
    });

    test('does not deregister stale pubkey after readiness clears', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

      final container = buildContainer();
      container.read(pushNotificationSyncProvider);

      final nostrSession =
          container.read(nostrSessionProvider.notifier) as _TestNostrSession;
      await emitReady(nostrSession, pubkeyA);
      verify(
        () => pushService.register(pubkeyA, isCurrent: any(named: 'isCurrent')),
      ).called(1);
      clearInteractions(pushService);

      when(() => authService.currentIdentity).thenReturn(null);
      when(() => authService.currentPublicKeyHex).thenReturn(null);
      nostrSession.setReadiness(const NostrSessionReadiness.signedOut());
      await pumpEventQueue(times: 1);

      await beforeSessionTeardownCallback!();

      verifyNever(
        () => pushService.createSignedDeregistrationEvent(
          any(),
          signingIdentity: any(named: 'signingIdentity'),
        ),
      );
    });

    test(
      'deregisters ready pubkey after same-pubkey readiness downgrade',
      () async {
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

        final container = buildContainer();
        container.read(pushNotificationSyncProvider);

        final nostrSession =
            container.read(nostrSessionProvider.notifier) as _TestNostrSession;
        await emitReady(nostrSession, pubkeyA);
        clearInteractions(pushService);

        nostrSession.setReadiness(
          const NostrSessionReadiness.identityKnown(pubkey: pubkeyA),
        );
        await pumpEventQueue(times: 1);

        await beforeSessionTeardownCallback!();

        verify(
          () => pushService.createSignedDeregistrationEvent(
            pubkeyA,
            signingIdentity: any(named: 'signingIdentity'),
          ),
        ).called(1);
        verify(
          () => pushService.publishDeregistrationEvent(
            any(),
            publishClient: any(named: 'publishClient'),
          ),
        ).called(1);
      },
    );

    test(
      'real push service deregisters after same-pubkey readiness downgrade',
      () async {
        final tokenRefreshController = StreamController<String>.broadcast();
        addTearDown(tokenRefreshController.close);
        final signer = _MockNostrSigner();
        final identity = KeycastNostrIdentity(
          pubkey: pubkeyA,
          rpcSigner: signer,
        );
        final event = _MockEvent();
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.denied));
        when(
          () => messaging.onTokenRefresh,
        ).thenAnswer((_) => tokenRefreshController.stream);
        when(() => authService.currentIdentity).thenReturn(identity);
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => event.id).thenReturn('same-pubkey-deregistration-event-id');
        when(() => event.isSigned).thenReturn(true);
        when(() => event.isValid).thenReturn(true);
        when(() => signer.signEvent(any())).thenAnswer((_) async => event);
        when(
          () => signer.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => 'encrypted-dereg-token');
        when(() => messaging.getToken()).thenAnswer((_) async => 'fcm-token');
        when(
          () => defaultCleanupClient.publishEventAwaitOk(
            event,
            targetRelays: [pushEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        ).thenAnswer(
          (_) async => _acceptedOutcome(event, pushEnvironment.relayUrl),
        );

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            notificationServiceProvider.overrideWithValue(
              _MockNotificationService(),
            ),
            currentEnvironmentProvider.overrideWith((_) => pushEnvironment),
            nostrSessionProvider.overrideWith(() => nostrSession),
            nostrClientFactoryProvider.overrideWithValue(
              ({dbClient, environmentConfig, signer, statisticsService}) =>
                  defaultCleanupClient,
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(pushNotificationSyncProvider);

        when(() => nostrClient.publicKey).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        nostrSession.setReadiness(
          const NostrSessionReadiness.identityKnown(pubkey: pubkeyA),
        );
        await pumpEventQueue(times: 1);

        await beforeSessionTeardownCallback!();

        verify(() => signer.signEvent(any())).called(1);
        verify(
          () => defaultCleanupClient.publishEventAwaitOk(
            event,
            targetRelays: [pushEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        ).called(1);
      },
    );

    test(
      'real push service deregisters captured pubkey after auth identity clears',
      () async {
        final tokenRefreshController = StreamController<String>.broadcast();
        addTearDown(tokenRefreshController.close);
        final signer = _MockNostrSigner();
        final identity = KeycastNostrIdentity(
          pubkey: pubkeyA,
          rpcSigner: signer,
        );
        final event = _MockEvent();
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.denied));
        when(
          () => messaging.onTokenRefresh,
        ).thenAnswer((_) => tokenRefreshController.stream);
        when(() => authService.currentIdentity).thenReturn(identity);
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(
          () => event.id,
        ).thenReturn('captured-pubkey-deregistration-event-id');
        when(() => event.isSigned).thenReturn(true);
        when(() => event.isValid).thenReturn(true);
        when(() => signer.signEvent(any())).thenAnswer((_) async => event);
        when(
          () => signer.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => 'encrypted-dereg-token');
        when(() => messaging.getToken()).thenAnswer((_) async => 'fcm-token');
        when(
          () => defaultCleanupClient.publishEventAwaitOk(
            event,
            targetRelays: [pushEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        ).thenAnswer(
          (_) async => _acceptedOutcome(event, pushEnvironment.relayUrl),
        );

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            notificationServiceProvider.overrideWithValue(
              _MockNotificationService(),
            ),
            currentEnvironmentProvider.overrideWith((_) => pushEnvironment),
            nostrSessionProvider.overrideWith(() => nostrSession),
            nostrClientFactoryProvider.overrideWithValue(
              ({dbClient, environmentConfig, signer, statisticsService}) =>
                  defaultCleanupClient,
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(pushNotificationSyncProvider);

        when(() => nostrClient.publicKey).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        when(() => authService.currentIdentity).thenReturn(null);
        when(() => authService.currentPublicKeyHex).thenReturn(null);

        await beforeSessionTeardownCallback!();

        verify(() => signer.signEvent(any())).called(1);
        verify(
          () => defaultCleanupClient.publishEventAwaitOk(
            event,
            targetRelays: [pushEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        ).called(1);
      },
    );

    test(
      'account-switch cleanup retains provider dependencies after disposal',
      () async {
        final tokenRefreshController = StreamController<String>.broadcast();
        addTearDown(tokenRefreshController.close);
        final signer = _MockNostrSigner();
        final identity = KeycastNostrIdentity(
          pubkey: pubkeyA,
          rpcSigner: signer,
        );
        final cleanupClient = _MockNostrClient();
        final event = _MockEvent();
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.denied));
        when(
          () => messaging.onTokenRefresh,
        ).thenAnswer((_) => tokenRefreshController.stream);
        when(() => authService.currentIdentity).thenReturn(identity);
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(
          () => event.id,
        ).thenReturn('direct-cleanup-deregistration-event-id');
        when(() => event.isSigned).thenReturn(true);
        when(() => event.isValid).thenReturn(true);
        when(() => signer.signEvent(any())).thenAnswer((_) async => event);
        when(
          () => signer.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => 'encrypted-dereg-token');
        final tokenCompleter = Completer<String?>();
        when(
          () => messaging.getToken(),
        ).thenAnswer((_) => tokenCompleter.future);
        when(
          () => cleanupClient.publishEventAwaitOk(
            event,
            targetRelays: [stagingEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        ).thenAnswer(
          (_) async => _acceptedOutcome(event, stagingEnvironment.relayUrl),
        );
        final initializeCompleter = Completer<void>();
        when(
          cleanupClient.initialize,
        ).thenAnswer((_) => initializeCompleter.future);
        // ignore: unnecessary_lambdas
        when(() => cleanupClient.dispose()).thenAnswer((_) async {});

        var currentEnvironment = pushEnvironment;
        EnvironmentConfig? cleanupEnvironment;
        Object? cleanupStatisticsService;
        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            notificationServiceProvider.overrideWithValue(
              _MockNotificationService(),
            ),
            currentEnvironmentProvider.overrideWith((_) => currentEnvironment),
            nostrSessionProvider.overrideWith(() => nostrSession),
            nostrClientFactoryProvider.overrideWithValue(
              ({dbClient, environmentConfig, signer, statisticsService}) {
                cleanupEnvironment = environmentConfig;
                cleanupStatisticsService = statisticsService;
                return cleanupClient;
              },
            ),
          ],
        );
        final coordinator = container.read(pushNotificationSyncProvider)!;

        when(() => nostrClient.publicKey).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        currentEnvironment = stagingEnvironment;
        container.invalidate(currentEnvironmentProvider);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        final teardownFuture = coordinator
            .deregisterLastReadyPubkeyAfterAccountSwitch();
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        verify(() => messaging.getToken()).called(1);
        verifyNever(cleanupClient.initialize);
        verifyNever(
          () => cleanupClient.publishEventAwaitOk(
            event,
            targetRelays: [stagingEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        );

        container.dispose();
        tokenCompleter.complete('fcm-token');
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        verify(() => signer.signEvent(any())).called(1);
        verify(cleanupClient.initialize).called(1);
        expect(cleanupEnvironment, same(stagingEnvironment));
        expect(cleanupStatisticsService, isNull);

        initializeCompleter.complete();
        await teardownFuture;

        verify(
          () => cleanupClient.publishEventAwaitOk(
            event,
            targetRelays: [stagingEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        ).called(1);
        verify(cleanupClient.dispose).called(1);
        verifyNever(
          () => nostrClient.publishEventAwaitOk(
            event,
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
      },
    );

    test(
      'token refresh does not register once teardown cleanup has begun',
      () async {
        final tokenRefreshController = StreamController<String>.broadcast();
        addTearDown(tokenRefreshController.close);
        final signer = _MockNostrSigner();
        final identity = KeycastNostrIdentity(
          pubkey: pubkeyA,
          rpcSigner: signer,
        );
        final deregistrationEvent = _MockEvent();
        final registrationEvent = _MockEvent();
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.denied));
        when(
          () => messaging.onTokenRefresh,
        ).thenAnswer((_) => tokenRefreshController.stream);
        when(() => authService.currentIdentity).thenReturn(identity);
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => nostrClient.signer).thenReturn(signer);
        when(
          () => signer.nip44Encrypt(pushServicePubkey, any()),
        ).thenAnswer((_) async => 'encrypted-token');
        when(
          () => authService.createAndSignEvent(
            kind: PushNotificationService.pushRegistrationKind,
            content: 'encrypted-token',
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => registrationEvent);
        when(
          () => registrationEvent.id,
        ).thenReturn('teardown-registration-event-id');
        when(
          () => deregistrationEvent.id,
        ).thenReturn('teardown-deregistration-event-id');
        when(() => deregistrationEvent.isSigned).thenReturn(true);
        when(() => deregistrationEvent.isValid).thenReturn(true);
        when(
          () => signer.signEvent(any()),
        ).thenAnswer((_) async => deregistrationEvent);
        when(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => _acceptedOutcome(
            invocation.positionalArguments.single as Event,
            pushEnvironment.relayUrl,
          ),
        );

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            notificationServiceProvider.overrideWithValue(
              _MockNotificationService(),
            ),
            currentEnvironmentProvider.overrideWith((_) => pushEnvironment),
            nostrSessionProvider.overrideWith(() => nostrSession),
            nostrClientFactoryProvider.overrideWithValue(
              ({dbClient, environmentConfig, signer, statisticsService}) =>
                  defaultCleanupClient,
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(pushNotificationSyncProvider);

        when(() => nostrClient.publicKey).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        await beforeSessionTeardownCallback!();
        tokenRefreshController.add('refreshed-token-during-teardown');
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        verifyNever(
          () => authService.createAndSignEvent(
            kind: PushNotificationService.pushRegistrationKind,
            content: 'encrypted-token',
            tags: any(named: 'tags'),
          ),
        );
        verifyNever(
          () => nostrClient.publishEventAwaitOk(
            registrationEvent,
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
      },
    );

    test(
      'waits for in-flight token refresh registration before deregistering',
      () async {
        const encryptedPayload = 'encrypted-refreshed-token';
        final events = <String>[];
        final tokenRefreshController = StreamController<String>.broadcast();
        final registrationPublishCompleter = Completer<PublishOutcome>();
        addTearDown(tokenRefreshController.close);
        final signer = _MockNostrSigner();
        final identity = KeycastNostrIdentity(
          pubkey: pubkeyA,
          rpcSigner: signer,
        );
        final registrationEvent = _MockEvent();
        final deregistrationEvent = _MockEvent();
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        // getToken() is null at startup (initial register skips and waits for a
        // refresh); once the refresh arrives the device has a token, so
        // deregistration can encrypt it for the push service.
        String? sessionToken;
        when(() => messaging.getToken()).thenAnswer((_) async => sessionToken);
        when(
          () => messaging.onTokenRefresh,
        ).thenAnswer((_) => tokenRefreshController.stream);
        when(() => authService.currentIdentity).thenReturn(identity);
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => nostrClient.signer).thenReturn(signer);
        when(
          () => signer.nip44Encrypt(pushServicePubkey, any()),
        ).thenAnswer((_) async => encryptedPayload);
        when(
          () => authService.createAndSignEvent(
            kind: PushNotificationService.pushRegistrationKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => registrationEvent);
        when(
          () => registrationEvent.id,
        ).thenReturn('in-flight-registration-event-id');
        when(
          () => deregistrationEvent.id,
        ).thenReturn('in-flight-deregistration-event-id');
        when(() => deregistrationEvent.isSigned).thenReturn(true);
        when(() => deregistrationEvent.isValid).thenReturn(true);
        when(
          () => signer.signEvent(any()),
        ).thenAnswer((_) async => deregistrationEvent);
        when(
          () => nostrClient.publishEventAwaitOk(
            registrationEvent,
            targetRelays: [pushEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        ).thenAnswer((_) async {
          events.add('registration publish started');
          final result = await registrationPublishCompleter.future;
          events.add('registration publish completed');
          return result;
        });
        when(() => defaultCleanupClient.initialize()).thenAnswer((_) async {});
        when(() => defaultCleanupClient.dispose()).thenAnswer((_) async {});
        when(
          () => defaultCleanupClient.publishEventAwaitOk(
            deregistrationEvent,
            targetRelays: [pushEnvironment.relayUrl],
            timeout: const Duration(seconds: 5),
          ),
        ).thenAnswer((_) async {
          events.add('deregister');
          return _acceptedOutcome(
            deregistrationEvent,
            pushEnvironment.relayUrl,
          );
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            notificationServiceProvider.overrideWithValue(
              _MockNotificationService(),
            ),
            currentEnvironmentProvider.overrideWith((_) => pushEnvironment),
            nostrSessionProvider.overrideWith(() => nostrSession),
            nostrClientFactoryProvider.overrideWithValue(
              ({dbClient, environmentConfig, signer, statisticsService}) =>
                  defaultCleanupClient,
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(pushNotificationSyncProvider);

        when(() => nostrClient.publicKey).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        tokenRefreshController.add('refreshed-token-during-session');
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        expect(events, ['registration publish started']);

        // The refresh delivered a token, so getToken() now returns it and the
        // pending deregistration can encrypt it.
        sessionToken = 'refreshed-token-during-session';

        final teardownFuture = beforeSessionTeardownCallback!();
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        expect(events, ['registration publish started']);

        registrationPublishCompleter.complete(
          _acceptedOutcome(registrationEvent, pushEnvironment.relayUrl),
        );
        await teardownFuture;

        expect(events, [
          'registration publish started',
          'registration publish completed',
          'deregister',
        ]);
      },
    );

    test(
      'deregisters account A before teardown then registers account B',
      () async {
        final events = <String>[];
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          events.add('register ${invocation.positionalArguments.single}');
          return PushRegistrationResult.published;
        });
        recordMockDeregistration(events);

        final container = buildContainer();
        container.read(pushNotificationSyncProvider);
        final nostrSession =
            container.read(nostrSessionProvider.notifier) as _TestNostrSession;

        await emitReady(nostrSession, pubkeyA);
        await beforeSessionTeardownCallback!();
        events.add('teardown $pubkeyA');
        await emitReady(nostrSession, pubkeyB);

        expect(events, [
          'register $pubkeyA',
          'deregister $pubkeyA',
          'teardown $pubkeyA',
          'register $pubkeyB',
        ]);
      },
    );

    test(
      'does not subscribe token refresh before Nostr session is ready',
      () async {
        final tokenRefreshController = StreamController<String>.broadcast();
        addTearDown(tokenRefreshController.close);

        when(
          () => messaging.onTokenRefresh,
        ).thenAnswer((_) => tokenRefreshController.stream);
        when(() => messaging.getToken()).thenAnswer((_) async => 'token');

        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            notificationServiceProvider.overrideWithValue(
              _MockNotificationService(),
            ),
            currentEnvironmentProvider.overrideWithValue(
              const EnvironmentConfig(environment: AppEnvironment.staging),
            ),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(const NostrSessionReadiness.signedOut()),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(pushNotificationServiceProvider), isNull);

        tokenRefreshController.add('refreshed-token');
        await pumpEventQueue(times: 1);

        verifyNever(() => nostrClient.signer);
      },
    );

    test(
      'does not create push service when ready session does not match auth',
      () async {
        final tokenRefreshController = StreamController<String>.broadcast();
        addTearDown(tokenRefreshController.close);

        when(
          () => messaging.onTokenRefresh,
        ).thenAnswer((_) => tokenRefreshController.stream);
        when(() => messaging.getToken()).thenAnswer((_) async => 'token');
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyB));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);

        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            notificationServiceProvider.overrideWithValue(
              _MockNotificationService(),
            ),
            currentEnvironmentProvider.overrideWithValue(
              const EnvironmentConfig(environment: AppEnvironment.staging),
            ),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                NostrSessionReadiness.nostrReady(
                  pubkey: pubkeyA,
                  client: nostrClient,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(pushNotificationServiceProvider), isNull);
      },
    );

    test(
      'publishes queued preferences when matching session becomes ready',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        final published = Completer<NotificationPreferences>();
        when(() => pushService.updatePreferences(any())).thenAnswer((
          invocation,
        ) async {
          final preferences =
              invocation.positionalArguments.single as NotificationPreferences;
          if (!published.isCompleted) published.complete(preferences);
          return true;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            nostrSessionProvider.overrideWith(() => nostrSession),
            pushNotificationServiceProvider.overrideWith((ref) {
              final readiness = ref.watch(nostrSessionProvider);
              return readiness.isReadyForActiveClient ? pushService : null;
            }),
          ],
        );
        addTearDown(container.dispose);
        container.read(notificationPreferencesDirtySyncBridgeProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        container.read(pushNotificationSyncProvider);

        await container
            .read(notificationPreferencesServiceProvider)
            .updatePreferences(prefs);

        verifyNever(() => pushService.updatePreferences(any()));

        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        expect(await published.future, prefs);
        await preferenceStore.waitForClear(pubkeyA);

        verify(() => pushService.updatePreferences(prefs)).called(1);
        expect(
          preferenceStore.dirtyPreferencesByPubkey,
          isNot(contains(pubkeyA)),
        );
      },
    );

    test(
      'drains dirty preferences when bridge is mounted without push sync listener',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        final published = Completer<NotificationPreferences>();
        when(() => pushService.updatePreferences(any())).thenAnswer((
          invocation,
        ) async {
          final preferences =
              invocation.positionalArguments.single as NotificationPreferences;
          if (!published.isCompleted) published.complete(preferences);
          return true;
        });

        await preferenceStore.markDirty(pubkeyA, prefs);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            nostrSessionProvider.overrideWith(() => nostrSession),
            pushNotificationServiceProvider.overrideWithValue(pushService),
          ],
        );
        addTearDown(container.dispose);

        container.read(notificationPreferencesDirtySyncBridgeProvider);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );

        expect(await published.future, prefs);
        await preferenceStore.waitForClear(pubkeyA);

        verify(() => pushService.updatePreferences(prefs)).called(1);
        expect(
          preferenceStore.dirtyPreferencesByPubkey,
          isNot(contains(pubkeyA)),
        );
      },
    );

    test(
      'publishes queued preferences without push sync listener mounted',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        final published = Completer<NotificationPreferences>();
        when(() => pushService.updatePreferences(any())).thenAnswer((
          invocation,
        ) async {
          final preferences =
              invocation.positionalArguments.single as NotificationPreferences;
          if (!published.isCompleted) published.complete(preferences);
          return true;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            nostrSessionProvider.overrideWith(() => nostrSession),
            pushNotificationServiceProvider.overrideWith((ref) {
              final readiness = ref.watch(nostrSessionProvider);
              return readiness.isReadyForActiveClient ? pushService : null;
            }),
          ],
        );
        addTearDown(container.dispose);
        container.read(notificationPreferencesDirtySyncBridgeProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);

        await container
            .read(notificationPreferencesServiceProvider)
            .updatePreferences(prefs);

        verifyNever(() => pushService.updatePreferences(any()));

        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        expect(await published.future, prefs);
        await preferenceStore.waitForClear(pubkeyA);

        verify(() => pushService.updatePreferences(prefs)).called(1);
        expect(
          preferenceStore.dirtyPreferencesByPubkey,
          isNot(contains(pubkeyA)),
        );
      },
    );

    test(
      'queues preferences when push service exists before matching readiness',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        final published = Completer<NotificationPreferences>();
        when(() => pushService.updatePreferences(any())).thenAnswer((
          invocation,
        ) async {
          final preferences =
              invocation.positionalArguments.single as NotificationPreferences;
          if (!published.isCompleted) published.complete(preferences);
          return true;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            nostrSessionProvider.overrideWith(() => nostrSession),
            pushNotificationServiceProvider.overrideWithValue(pushService),
          ],
        );
        addTearDown(container.dispose);
        container.read(notificationPreferencesDirtySyncBridgeProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);

        await container
            .read(notificationPreferencesServiceProvider)
            .updatePreferences(prefs);

        verifyNever(() => pushService.updatePreferences(any()));

        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        expect(await published.future, prefs);
        await preferenceStore.waitForClear(pubkeyA);

        verify(() => pushService.updatePreferences(prefs)).called(1);
        expect(
          preferenceStore.dirtyPreferencesByPubkey,
          isNot(contains(pubkeyA)),
        );
      },
    );

    test(
      'keeps dirty preferences for original pubkey when another identity becomes known',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        final published = Completer<NotificationPreferences>();
        when(() => pushService.updatePreferences(any())).thenAnswer((
          invocation,
        ) async {
          final preferences =
              invocation.positionalArguments.single as NotificationPreferences;
          if (!published.isCompleted) published.complete(preferences);
          return true;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.identityKnown(pubkey: pubkeyA),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            nostrSessionProvider.overrideWith(() => nostrSession),
            pushNotificationServiceProvider.overrideWithValue(pushService),
          ],
        );
        addTearDown(container.dispose);
        container.read(notificationPreferencesDirtySyncBridgeProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);

        await container
            .read(notificationPreferencesServiceProvider)
            .updatePreferences(prefs);

        nostrSession.setReadiness(
          const NostrSessionReadiness.identityKnown(pubkey: pubkeyB),
        );
        await pumpEventQueue(times: 1);
        expect(preferenceStore.dirtyPreferencesByPubkey[pubkeyA], prefs);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        expect(await published.future, prefs);
        await preferenceStore.waitForClear(pubkeyA);

        verify(() => pushService.updatePreferences(prefs)).called(1);
        expect(
          preferenceStore.dirtyPreferencesByPubkey,
          isNot(contains(pubkeyA)),
        );
      },
    );

    test(
      'keeps dirty preferences for original pubkey across sign out',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        final published = Completer<NotificationPreferences>();
        when(() => pushService.updatePreferences(any())).thenAnswer((
          invocation,
        ) async {
          final preferences =
              invocation.positionalArguments.single as NotificationPreferences;
          if (!published.isCompleted) published.complete(preferences);
          return true;
        });

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.identityKnown(pubkey: pubkeyA),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            nostrSessionProvider.overrideWith(() => nostrSession),
            pushNotificationServiceProvider.overrideWithValue(pushService),
          ],
        );
        addTearDown(container.dispose);
        container.read(notificationPreferencesDirtySyncBridgeProvider);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);

        await container
            .read(notificationPreferencesServiceProvider)
            .updatePreferences(prefs);

        nostrSession.setReadiness(const NostrSessionReadiness.signedOut());
        await pumpEventQueue(times: 1);
        expect(preferenceStore.dirtyPreferencesByPubkey[pubkeyA], prefs);

        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        );
        expect(await published.future, prefs);
        await preferenceStore.waitForClear(pubkeyA);

        verify(() => pushService.updatePreferences(prefs)).called(1);
        expect(
          preferenceStore.dirtyPreferencesByPubkey,
          isNot(contains(pubkeyA)),
        );
      },
    );

    test(
      'catches errors from queued preference publish after readiness',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        when(
          () => pushService.updatePreferences(any()),
        ).thenThrow(StateError('relay unreachable'));

        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.signedOut(),
        );
        final container = ProviderContainer(
          overrides: [
            firebaseMessagingProvider.overrideWithValue(messaging),
            authServiceProvider.overrideWithValue(authService),
            notificationPreferencesStoreProvider.overrideWithValue(
              preferenceStore,
            ),
            nostrSessionProvider.overrideWith(() => nostrSession),
            pushNotificationServiceProvider.overrideWith((ref) {
              final readiness = ref.watch(nostrSessionProvider);
              return readiness.isReadyForActiveClient ? pushService : null;
            }),
          ],
        );
        addTearDown(container.dispose);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        container.read(pushNotificationSyncProvider);

        await container
            .read(notificationPreferencesServiceProvider)
            .updatePreferences(prefs);

        final unhandled = <Object>[];
        await runZonedGuarded(() async {
          nostrSession.setReadiness(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          );
          await pumpEventQueue(times: 1);
          await pumpEventQueue(times: 1);
          await pumpEventQueue(times: 1);
        }, (error, stack) => unhandled.add(error));

        expect(unhandled, isEmpty);
        verify(() => pushService.updatePreferences(prefs)).called(4);
        expect(preferenceStore.dirtyPreferencesByPubkey[pubkeyA], prefs);
      },
    );

    test(
      'catches errors from direct preference publish retries when already ready',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        when(
          () => pushService.updatePreferences(any()),
        ).thenThrow(StateError('relay unreachable'));
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = buildContainer(
          nostrSession: _TestNostrSession(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          ),
        );

        await expectLater(
          container
              .read(notificationPreferencesServiceProvider)
              .updatePreferences(prefs),
          completes,
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        verify(() => pushService.updatePreferences(prefs)).called(5);
        expect(preferenceStore.dirtyPreferencesByPubkey[pubkeyA], prefs);
      },
    );

    test(
      'retries newer dirty preferences after stale direct publish succeeds',
      () async {
        const publishedPrefs = NotificationPreferences(commentsEnabled: false);
        const newerPrefs = NotificationPreferences(likesEnabled: false);
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => pushService.updatePreferences(any())).thenAnswer((
          invocation,
        ) async {
          final preferences =
              invocation.positionalArguments.single as NotificationPreferences;
          if (preferences == publishedPrefs) {
            await preferenceStore.markDirty(pubkeyA, newerPrefs);
          }
          return true;
        });

        final container = buildContainer(
          nostrSession: _TestNostrSession(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          ),
        );

        await container
            .read(notificationPreferencesServiceProvider)
            .updatePreferences(publishedPrefs);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        verify(() => pushService.updatePreferences(publishedPrefs)).called(1);
        verify(() => pushService.updatePreferences(newerPrefs)).called(1);
        expect(
          preferenceStore.dirtyPreferencesByPubkey,
          isNot(contains(pubkeyA)),
        );
      },
    );

    test('retries dirty preferences after direct publish failure', () async {
      const prefs = NotificationPreferences(commentsEnabled: false);
      var attempts = 0;
      when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
      when(() => pushService.updatePreferences(prefs)).thenAnswer((_) async {
        attempts += 1;
        if (attempts == 1) {
          throw StateError('relay unreachable');
        }
        return true;
      });

      final container = buildContainer(
        nostrSession: _TestNostrSession(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: nostrClient,
          ),
        ),
      );

      await container
          .read(notificationPreferencesServiceProvider)
          .updatePreferences(prefs);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      expect(attempts, equals(2));
      expect(
        preferenceStore.dirtyPreferencesByPubkey,
        isNot(contains(pubkeyA)),
      );
    });

    test(
      'retries dirty preferences after same-session publish returns false',
      () async {
        const prefs = NotificationPreferences(commentsEnabled: false);
        var attempts = 0;
        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyA));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
        when(() => pushService.updatePreferences(prefs)).thenAnswer((_) async {
          attempts += 1;
          return attempts > 1;
        });
        await preferenceStore.markDirty(pubkeyA, prefs);

        final container = buildContainer(
          nostrSession: _TestNostrSession(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          ),
        );
        container.read(pushNotificationSyncProvider);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(attempts, equals(2));
        expect(
          preferenceStore.dirtyPreferencesByPubkey,
          isNot(contains(pubkeyA)),
        );
      },
    );

    test('survives rapid account switch (A → B) without unhandled error', () {
      // This is the exact E2E scenario: register A, sign out, register B.
      // First requestPermission is still pending when B's auth event fires,
      // causing the "already running" PlatformException.
      fakeAsync((async) {
        var requestCount = 0;
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.notDetermined));
        when(
          () => messaging.requestPermission(
            alert: any(named: 'alert'),
            announcement: any(named: 'announcement'),
            badge: any(named: 'badge'),
            carPlay: any(named: 'carPlay'),
            criticalAlert: any(named: 'criticalAlert'),
            provisional: any(named: 'provisional'),
            sound: any(named: 'sound'),
            providesAppNotificationSettings: any(
              named: 'providesAppNotificationSettings',
            ),
          ),
        ).thenAnswer((_) async {
          requestCount++;
          if (requestCount >= 2) {
            throw PlatformException(
              code: 'firebase_messaging/unknown',
              message: 'A request for permissions is already running',
            );
          }
          return _settings(AuthorizationStatus.authorized);
        });

        final container = buildContainer();
        container.read(pushNotificationSyncProvider);

        final unhandled = <Object>[];
        runZonedGuarded(() {
          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
          when(
            () => authService.currentIdentity,
          ).thenReturn(_identity(pubkeyA));
          final nostrSession =
              container.read(nostrSessionProvider.notifier)
                  as _TestNostrSession;
          nostrSession.setReadiness(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: nostrClient,
            ),
          );
          async.flushMicrotasks();

          when(() => authService.currentPublicKeyHex).thenReturn(null);
          when(() => authService.currentIdentity).thenReturn(null);
          authStateController.add(AuthState.unauthenticated);
          async.flushMicrotasks();

          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);
          when(
            () => authService.currentIdentity,
          ).thenReturn(_identity(pubkeyB));
          when(() => nostrClient.publicKey).thenReturn(pubkeyB);
          nostrSession.setReadiness(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyB,
              client: nostrClient,
            ),
          );
          async.flushMicrotasks();
        }, (error, stack) => unhandled.add(error));

        expect(unhandled, isEmpty);
      });
    });

    test(
      'retries current account after overlapping permission request settles',
      () async {
        final events = <String>[];
        final permissionCompleter = Completer<NotificationSettings>();
        var requestCount = 0;
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.notDetermined));
        when(
          () => messaging.requestPermission(
            alert: any(named: 'alert'),
            announcement: any(named: 'announcement'),
            badge: any(named: 'badge'),
            carPlay: any(named: 'carPlay'),
            criticalAlert: any(named: 'criticalAlert'),
            provisional: any(named: 'provisional'),
            sound: any(named: 'sound'),
            providesAppNotificationSettings: any(
              named: 'providesAppNotificationSettings',
            ),
          ),
        ).thenAnswer((_) {
          requestCount += 1;
          if (requestCount > 1) {
            throw PlatformException(
              code: 'firebase_messaging/unknown',
              message: 'A request for permissions is already running',
            );
          }
          return permissionCompleter.future;
        });
        when(
          () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
        ).thenAnswer((invocation) async {
          events.add('register ${invocation.positionalArguments.single}');
          return PushRegistrationResult.published;
        });

        final container = buildContainer();
        container.read(pushNotificationSyncProvider);
        final nostrSession =
            container.read(nostrSessionProvider.notifier) as _TestNostrSession;

        await emitReady(nostrSession, pubkeyA);
        expect(requestCount, 1);

        when(() => authService.currentIdentity).thenReturn(_identity(pubkeyB));
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);
        when(() => nostrClient.publicKey).thenReturn(pubkeyB);
        authStateController.add(AuthState.authenticated);
        nostrSession.setReadiness(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyB,
            client: nostrClient,
          ),
        );
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        permissionCompleter.complete(_settings(AuthorizationStatus.authorized));
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(requestCount, 1);
        expect(events, ['register $pubkeyB']);
      },
    );
  });
}
