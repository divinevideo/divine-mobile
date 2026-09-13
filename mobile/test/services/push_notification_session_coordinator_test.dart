// ABOUTME: Direct tests for push registration against Nostr session readiness.
// ABOUTME: Complements the provider-level push notification sync suite.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/services/push_notification_session_coordinator.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockPushNotificationService extends Mock
    implements PushNotificationService {}

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
      showPreviews: AppleShowPreviewSetting.always,
      sound: AppleNotificationSetting.enabled,
      timeSensitive: AppleNotificationSetting.disabled,
    );

void main() {
  group(PushNotificationSessionCoordinator, () {
    late _MockAuthService authService;
    late _MockFirebaseMessaging messaging;
    late _MockNostrClient client;
    late NostrIdentity identity;
    late _MockPushNotificationService pushService;
    late StreamController<String> tokenRefreshes;
    late NostrSessionReadiness readiness;
    late PushNotificationSessionCoordinator coordinator;

    setUp(() {
      authService = _MockAuthService();
      messaging = _MockFirebaseMessaging();
      client = _MockNostrClient();
      identity = KeycastNostrIdentity(
        pubkey: 'a' * 64,
        rpcSigner: _MockNostrSigner(),
      );
      pushService = _MockPushNotificationService();
      tokenRefreshes = StreamController<String>.broadcast();
      readiness = const NostrSessionReadiness.signedOut();
      when(
        () => messaging.onTokenRefresh,
      ).thenAnswer((_) => tokenRefreshes.stream);
      when(() => messaging.getNotificationSettings()).thenAnswer(
        (_) async => _settings(AuthorizationStatus.authorized),
      );
      when(() => authService.currentIdentity).thenReturn(identity);
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn('a' * 64);
      when(
        () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
      ).thenAnswer((_) async => PushRegistrationResult.published);
      coordinator = PushNotificationSessionCoordinator(
        authService: authService,
        firebaseMessaging: messaging,
        readReadiness: () => readiness,
        readPushService: () => pushService,
        readCleanupClientFactory: () =>
            (_) => _MockNostrClient(),
      );
    });

    tearDown(() async {
      coordinator.dispose();
      await tokenRefreshes.close();
    });

    test('does not register for identity-known readiness', () async {
      readiness = NostrSessionReadiness.identityKnown(pubkey: 'a' * 64);

      coordinator.handleReadiness(readiness);
      await pumpEventQueue();

      verifyNever(messaging.getNotificationSettings);
      verifyNever(
        () => pushService.register(any(), isCurrent: any(named: 'isCurrent')),
      );
    });

    test('registers once the matching signer-backed client is ready', () async {
      readiness = NostrSessionReadiness.nostrReady(
        pubkey: 'a' * 64,
        client: client,
      );

      coordinator.handleReadiness(readiness);
      await pumpEventQueue(times: 2);

      verify(messaging.getNotificationSettings).called(1);
      verify(
        () => pushService.register(
          'a' * 64,
          isCurrent: any(named: 'isCurrent'),
        ),
      ).called(1);
    });
  });
}
