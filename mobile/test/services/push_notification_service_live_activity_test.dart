// ABOUTME: Tests registering a post Live Activity with the push service over
// ABOUTME: the kind 3079 registration event.

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart'
    show AuthorizationStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {
  @override
  String get id => 'push-control-event-id';
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

void main() {
  const testPubkey =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  const pushServicePubkey =
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
  const environment = _ConfiguredEnvironmentConfig(
    environment: AppEnvironment.staging,
    configuredPushServicePubkey: pushServicePubkey,
  );

  late _MockAuthService authService;
  late _MockNostrClient nostrClient;
  late _MockNostrSigner signer;
  late _FakeEvent signedEvent;

  final registration = LiveActivityRegistration.forPost(
    activityId: 'activity-1',
    ownerPubkey: testPubkey,
    activityPushToken: 'activity-push-token',
    postCoordinate: '34236:$testPubkey:post-d-tag',
    postEventIds: const ['event-id-1'],
    postedAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    showFirstRunNote: true,
  );

  setUp(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<String>[]);
    registerFallbackValue(Duration.zero);

    authService = _MockAuthService();
    nostrClient = _MockNostrClient();
    signer = _MockNostrSigner();
    signedEvent = _FakeEvent();

    when(() => authService.currentIdentity).thenReturn(
      BunkerNostrIdentity(pubkey: testPubkey, remoteSigner: signer),
    );
    when(
      () => signer.nip44Encrypt(any(), any()),
    ).thenAnswer((_) async => 'ciphertext');
    when(
      () => authService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async => signedEvent);
    when(
      () => nostrClient.publishEventAwaitOk(
        any(),
        targetRelays: any(named: 'targetRelays'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (_) async => PublishOutcome(
        eventId: signedEvent.id,
        acceptedBy: [environment.relayUrl],
        rejectedBy: const {},
        noResponseFrom: const [],
      ),
    );
  });

  PushNotificationService buildService({String? token = 'fcm-token'}) =>
      PushNotificationService(
        authService: authService,
        nostrClient: nostrClient,
        notificationService: _MockNotificationService(),
        environmentConfig: environment,
        getToken: () async => token,
        timeZoneIdentifier: () async => 'Pacific/Auckland',
        timeZoneOffsetMinutes: () => -300,
      );

  Map<String, dynamic> capturedPlaintext() {
    final captured = verify(
      () => signer.nip44Encrypt(pushServicePubkey, captureAny()),
    ).captured.single;
    return jsonDecode(captured as String) as Map<String, dynamic>;
  }

  group('registerLiveActivity', () {
    test('keeps the registration fields and adds the activity', () async {
      final result = await buildService().registerLiveActivity(
        testPubkey,
        registration,
        notificationsAuthorized: true,
      );

      expect(result, PushRegistrationResult.published);
      final plaintext = capturedPlaintext();
      expect(plaintext['token'], 'fcm-token');
      expect(plaintext['timezone'], 'Pacific/Auckland');
      expect(plaintext['timezoneOffsetMinutes'], -300);
      expect(plaintext['campaignTargetTypes'], [
        'app_route',
        'video_address',
        'creator_profile',
      ]);
      expect(plaintext['notificationsAuthorized'], isTrue);
      expect(plaintext['liveActivity'], registration.liveActivityWire());
    });

    test('sends the ended state', () async {
      await buildService().registerLiveActivity(
        testPubkey,
        registration.ended(),
        notificationsAuthorized: false,
      );

      final plaintext = capturedPlaintext();
      expect(plaintext['notificationsAuthorized'], isFalse);
      expect(
        (plaintext['liveActivity'] as Map<String, dynamic>)['state'],
        'ended',
      );
    });

    test('publishes kind 3079 for both states, never 3080', () async {
      final service = buildService();
      await service.registerLiveActivity(
        testPubkey,
        registration,
        notificationsAuthorized: true,
      );
      await service.registerLiveActivity(
        testPubkey,
        registration.ended(),
        notificationsAuthorized: true,
      );

      verify(
        () => authService.createAndSignEvent(
          kind: PushNotificationService.pushRegistrationKind,
          content: 'ciphertext',
          tags: any(named: 'tags'),
        ),
      ).called(2);
      verifyNever(
        () => authService.createAndSignEvent(
          kind: PushNotificationService.pushDeregistrationKind,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test('can be retried when there is no FCM token yet', () async {
      final result = await buildService(token: null).registerLiveActivity(
        testPubkey,
        registration,
        notificationsAuthorized: true,
      );

      expect(result, PushRegistrationResult.retryableFailure);
      verifyNever(() => signer.nip44Encrypt(any(), any()));
    });

    test('does not publish a registration owned by another account', () async {
      final foreign = LiveActivityRegistration.forPost(
        activityId: 'activity-2',
        ownerPubkey: 'f' * 64,
        activityPushToken: 'activity-push-token',
        postCoordinate: '34236:${'f' * 64}:d',
        postEventIds: const ['event-id-2'],
        postedAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        showFirstRunNote: false,
      );

      final result = await buildService().registerLiveActivity(
        testPubkey,
        foreign,
        notificationsAuthorized: true,
      );

      expect(result, PushRegistrationResult.terminalFailure);
      verifyNever(() => signer.nip44Encrypt(any(), any()));
      verifyNever(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
        ),
      );
    });

    test('does not hide a timezone change from the notification '
        'registration', () async {
      var timezone = 'Pacific/Auckland';
      final service = PushNotificationService(
        authService: authService,
        nostrClient: nostrClient,
        notificationService: _MockNotificationService(),
        environmentConfig: environment,
        getToken: () async => 'fcm-token',
        timeZoneIdentifier: () async => timezone,
        timeZoneOffsetMinutes: () => -300,
      );
      await service.register(testPubkey);
      timezone = 'Pacific/Fiji';

      await service.registerLiveActivity(
        testPubkey,
        registration,
        notificationsAuthorized: true,
      );

      expect(await service.registrationTimezoneChanged(), isTrue);
    });

    test('does not publish for another account', () async {
      final result = await buildService().registerLiveActivity(
        'f' * 64,
        registration,
        notificationsAuthorized: true,
      );

      expect(result, PushRegistrationResult.terminalFailure);
      verifyNever(() => signer.nip44Encrypt(any(), any()));
    });
  });

  group('notificationsAuthorizedFor', () {
    test('is true for authorized and provisional only, whatever else the platform adds', () {
      expect(
        {
          for (final status in AuthorizationStatus.values)
            status: notificationsAuthorizedFor(status),
        },
        {
          AuthorizationStatus.authorized: true,
          AuthorizationStatus.provisional: true,
          AuthorizationStatus.denied: false,
          AuthorizationStatus.deniedPermanently: false,
          AuthorizationStatus.notDetermined: false,
        },
      );
    });
  });
}
