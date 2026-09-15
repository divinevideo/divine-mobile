// ABOUTME: Tests for PushNotificationService covering FCM token registration,
// ABOUTME: deregistration, preference updates, and foreground message handling.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_helpers.dart'
    show localNotificationTapPayload;
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {
  @override
  String get id => 'push-control-event-id';
}

class _MockEvent extends Mock implements Event {}

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
  late _MockAuthService mockAuthService;
  late _MockNostrClient mockNostrClient;
  late _MockNotificationService mockNotificationService;
  late _MockNostrSigner mockNostrSigner;

  const testPubkey =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  const testToken = 'fcm-test-token-abc123';
  const encryptedPayload = 'encrypted-payload-xyz';
  const pushPublishTimeout = Duration(seconds: 5);

  const configuredPushServicePubkey =
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

  const testEnvironment = _ConfiguredEnvironmentConfig(
    environment: AppEnvironment.staging,
    configuredPushServicePubkey: configuredPushServicePubkey,
  );

  const placeholderEnvironment = _ConfiguredEnvironmentConfig(
    environment: AppEnvironment.staging,
    configuredPushServicePubkey: 'TODO_TEST_PUBKEY',
  );

  setUp(() {
    mockAuthService = _MockAuthService();
    mockNostrClient = _MockNostrClient();
    mockNotificationService = _MockNotificationService();
    mockNostrSigner = _MockNostrSigner();

    when(() => mockNostrClient.signer).thenReturn(mockNostrSigner);
    when(() => mockNostrSigner.nip44Encrypt(any(), any()))
        .thenAnswer((_) async => encryptedPayload);

    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<String>[]);
    registerFallbackValue(Duration.zero);
  });

  PushNotificationService buildService({
    String? token = testToken,
    Future<String?> Function()? getToken,
    FutureOr<bool> Function()? isCurrent,
  }) {
    return PushNotificationService(
      authService: mockAuthService,
      nostrClient: mockNostrClient,
      notificationService: mockNotificationService,
      environmentConfig: testEnvironment,
      getToken: getToken ?? () async => token,
      isCurrent: isCurrent,
    );
  }

  group(PushNotificationService, () {
    group('register', () {
      test('encrypts token JSON and publishes kind 3079 event to environment relay with OK timeout', () async {
        when(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            any(),
          ),
        ).thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushRegistrationKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: [testEnvironment.relayUrl],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final service = buildService();
        await service.register(testPubkey);

        final registrationCapture = verify(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            captureAny(),
          ),
        );
        registrationCapture.called(1);
        final registrationJson = jsonDecode(
          registrationCapture.captured.single as String,
        ) as Map<String, dynamic>;
        expect(registrationJson['token'], testToken);
        expect(
          registrationJson['timezoneOffsetMinutes'],
          DateTime.now().timeZoneOffset.inMinutes,
        );

        verify(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushRegistrationKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).called(1);

        verify(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).called(1);
        service.dispose();
      });

      test('includes required tags on registration event', () async {
        List<List<String>>? capturedTags;

        when(() => mockNostrSigner.nip44Encrypt(any(), any()))
            .thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags =
              invocation.namedArguments[const Symbol('tags')]
                  as List<List<String>>?;
          return fakeEvent;
        });

        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: [testEnvironment.relayUrl],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final service = buildService();
        expect(
          await service.register(testPubkey),
          PushRegistrationResult.published,
        );

        expect(capturedTags, isNotNull);

        final pTag = capturedTags!.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'p',
          orElse: () => [],
        );
        expect(pTag, hasLength(greaterThanOrEqualTo(2)));
        expect(pTag[1], equals(testEnvironment.pushServicePubkey));

        final appTag = capturedTags!.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'app',
          orElse: () => [],
        );
        expect(appTag, hasLength(greaterThanOrEqualTo(2)));
        expect(appTag[1], equals(PushNotificationService.pushAppIdentifier));

        final expirationTag = capturedTags!.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'expiration',
          orElse: () => [],
        );
        expect(expirationTag, hasLength(greaterThanOrEqualTo(2)));
        final expirationValue = int.tryParse(expirationTag[1]);
        expect(expirationValue, isNotNull);
        expect(
          expirationValue,
          greaterThan(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        );

        service.dispose();
      });

      test('does nothing when FCM token is null', () async {
        final service = buildService(token: null);
        expect(
          await service.register(testPubkey),
          PushRegistrationResult.terminalFailure,
        );

        verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
          ),
        );
        service.dispose();
      });

      test('returns terminal failure when FCM token lookup throws', () async {
        final service = buildService(
          getToken: () => throw StateError('apns-token-not-set'),
        );

        expect(
          await service.register(testPubkey),
          PushRegistrationResult.terminalFailure,
        );
        verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
        service.dispose();
      });

      test(
        'skips registration when push service pubkey is still placeholder',
        () async {
          final service = PushNotificationService(
            authService: mockAuthService,
            nostrClient: mockNostrClient,
            notificationService: mockNotificationService,
            environmentConfig: placeholderEnvironment,
            getToken: () async => testToken,
          );

          expect(
            await service.register(testPubkey),
            PushRegistrationResult.terminalFailure,
          );

          verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
          service.dispose();
        },
      );

      test('does nothing when NIP-44 encryption fails', () async {
        when(() => mockNostrSigner.nip44Encrypt(any(), any()))
            .thenAnswer((_) async => null);

        final service = buildService();
        expect(
          await service.register(testPubkey),
          PushRegistrationResult.terminalFailure,
        );

        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
          ),
        );
        service.dispose();
      });

      test('does nothing when event signing returns null', () async {
        when(() => mockNostrSigner.nip44Encrypt(any(), any()))
            .thenAnswer((_) async => encryptedPayload);

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final service = buildService();
        expect(
          await service.register(testPubkey),
          PushRegistrationResult.terminalFailure,
        );

        verifyNever(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
        service.dispose();
      });

      test('returns uncertain failure when registration publish receives no OK response', () async {
        when(() => mockNostrSigner.nip44Encrypt(any(), any()))
            .thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: [testEnvironment.relayUrl],
          ),
        );

        final service = buildService();
        expect(
          await service.register(testPubkey),
          PushRegistrationResult.uncertainFailure,
        );
        service.dispose();
      });

      test(
        'returns terminal failure when registration publish is rejected',
        () async {
          when(() => mockNostrSigner.nip44Encrypt(any(), any()))
              .thenAnswer((_) async => encryptedPayload);

          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);

          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: {testEnvironment.relayUrl: 'blocked'},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          expect(
            await service.register(testPubkey),
            PushRegistrationResult.terminalFailure,
          );
          service.dispose();
        },
      );

      test('retries when no relay received the registration', () async {
        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);
        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final service = buildService();
        expect(
          await service.register(testPubkey),
          PushRegistrationResult.retryableFailure,
        );
        service.dispose();
      });

      test('retries when the configured relay is unreachable', () async {
        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);
        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const [],
            unreachableTargets: [testEnvironment.relayUrl],
          ),
        );

        final service = buildService();
        expect(
          await service.register(testPubkey),
          PushRegistrationResult.retryableFailure,
        );
        service.dispose();
      });
    });

    group('deregister', () {
      test(
        'encrypts the FCM token into the deregistration event content',
        () async {
          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushDeregistrationKind,
              content: encryptedPayload,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);
          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: [testEnvironment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          await service.deregister(testPubkey);

          verify(
            () => mockNostrSigner.nip44Encrypt(
              testEnvironment.pushServicePubkey,
              '{"token":"$testToken"}',
            ),
          ).called(1);
          verify(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushDeregistrationKind,
              content: encryptedPayload,
              tags: any(named: 'tags'),
            ),
          ).called(1);
          service.dispose();
        },
      );

      test(
        'does not publish deregistration when the FCM token is unavailable',
        () async {
          await LogCaptureService().clearAllLogs();
          final service = buildService(token: null);

          await service.deregister(testPubkey);

          verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
          verifyNever(
            () => mockNostrClient.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          );
          final messages = LogCaptureService().getRecentLogs().map(
            (entry) => entry.message,
          );
          expect(
            messages,
            contains(
              'FCM token is null — skipping push notification deregistration',
            ),
          );
          expect(
            messages,
            isNot(contains('Failed to sign deregistration event')),
          );
          service.dispose();
        },
      );

      test(
        'publishes kind 3080 event to environment relay with OK timeout',
        () async {
          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushDeregistrationKind,
              content: encryptedPayload,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);

          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: [testEnvironment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          await service.deregister(testPubkey);

          verify(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushDeregistrationKind,
              content: encryptedPayload,
              tags: any(named: 'tags'),
            ),
          ).called(1);

          verify(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
            ),
          ).called(1);
          service.dispose();
        },
      );

      test('does not publish when event signing fails', () async {
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final service = buildService();
        await service.deregister(testPubkey);

        verifyNever(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
        service.dispose();
      });
      test('completes without error when deregistration publish receives no OK response', () async {
        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: [testEnvironment.relayUrl],
          ),
        );

        final service = buildService();
        await expectLater(service.deregister(testPubkey), completes);
        service.dispose();
      });

      test(
        'completes without error when deregistration publish is rejected',
        () async {
          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);

          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: {testEnvironment.relayUrl: 'blocked'},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          await expectLater(service.deregister(testPubkey), completes);
          service.dispose();
        },
      );

      test(
        'does not sign deregistration when session is already stale',
        () async {
          final service = buildService(isCurrent: () => false);

          await service.deregister(testPubkey);

          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
          verifyNever(() => mockNostrClient.publishEvent(any()));
          service.dispose();
        },
      );

      test('does not publish deregistration when session becomes stale after signing', () async {
        var current = true;
        final fakeEvent = _MockEvent();
        when(() => fakeEvent.id).thenReturn('captured-deregistration-event-id');
        when(() => fakeEvent.isSigned).thenReturn(true);
        when(() => fakeEvent.isValid).thenReturn(true);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushDeregistrationKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          current = false;
          return fakeEvent;
        });

        final service = buildService(isCurrent: () => current);

        await service.deregister(testPubkey);

        verify(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushDeregistrationKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).called(1);
        verifyNever(() => mockNostrClient.publishEvent(any()));
        service.dispose();
      });

      test('can sign deregistration with captured outgoing identity', () async {
        final capturedSigner = _MockNostrSigner();
        final capturedIdentity = KeycastNostrIdentity(
          pubkey: testPubkey,
          rpcSigner: capturedSigner,
        );
        final fakeEvent = _MockEvent();
        when(() => fakeEvent.id).thenReturn('captured-deregistration-event-id');
        when(() => fakeEvent.isSigned).thenReturn(true);
        when(() => fakeEvent.isValid).thenReturn(true);
        when(() => capturedSigner.nip44Encrypt(any(), any()))
            .thenAnswer((_) async => encryptedPayload);
        when(() => capturedSigner.signEvent(any()))
            .thenAnswer((_) async => fakeEvent);
        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: [testEnvironment.relayUrl],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final service = buildService(isCurrent: () => false);
        await service.deregister(testPubkey, signingIdentity: capturedIdentity);

        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        verify(() => capturedSigner.signEvent(any())).called(1);
        verify(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).called(1);
        service.dispose();
      });

      test('publishes captured-identity deregistration with supplied cleanup client', () async {
        final capturedSigner = _MockNostrSigner();
        final capturedIdentity = KeycastNostrIdentity(
          pubkey: testPubkey,
          rpcSigner: capturedSigner,
        );
        final cleanupClient = _MockNostrClient();
        final fakeEvent = _MockEvent();
        when(() => fakeEvent.id).thenReturn('cleanup-deregistration-event-id');
        when(() => fakeEvent.isSigned).thenReturn(true);
        when(() => fakeEvent.isValid).thenReturn(true);
        when(() => capturedSigner.nip44Encrypt(any(), any()))
            .thenAnswer((_) async => encryptedPayload);
        when(() => capturedSigner.signEvent(any()))
            .thenAnswer((_) async => fakeEvent);
        when(
          () => cleanupClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: [testEnvironment.relayUrl],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final service = buildService(isCurrent: () => false);
        await service.deregister(
          testPubkey,
          signingIdentity: capturedIdentity,
          publishClient: cleanupClient,
        );

        verify(() => capturedSigner.signEvent(any())).called(1);
        verifyNever(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
        verify(
          () => cleanupClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).called(1);
        service.dispose();
      });
    });

    group('updatePreferences', () {
      test('encrypts kinds JSON and publishes kind 3083 event to environment relay with OK timeout', () async {
        const prefs = NotificationPreferences(
          commentsEnabled: false,
          mentionsEnabled: false,
          repostsEnabled: false,
        );

        when(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            any(),
          ),
        ).thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushPreferencesKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: [testEnvironment.relayUrl],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final service = buildService();
        await service.updatePreferences(prefs);

        final captureResult = verify(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            captureAny(),
          ),
        );
        captureResult.called(1);

        final capturedJson = captureResult.captured.first as String;
        expect(capturedJson, contains('"kinds"'));
        expect(capturedJson, contains('"campaignsEnabled":false'));

        final kinds = prefs.toKindsList();
        for (final kind in kinds) {
          expect(capturedJson, contains(kind.toString()));
        }

        verify(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushPreferencesKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).called(1);

        verify(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).called(1);
        service.dispose();
      });

      test(
        'skips preferences update when push service pubkey is placeholder',
        () async {
          const prefs = NotificationPreferences();
          final service = PushNotificationService(
            authService: mockAuthService,
            nostrClient: mockNostrClient,
            notificationService: mockNotificationService,
            environmentConfig: placeholderEnvironment,
            getToken: () async => testToken,
          );

          await service.updatePreferences(prefs);

          verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
          service.dispose();
        },
      );
      test('completes without error when preferences publish receives no OK response', () async {
        const prefs = NotificationPreferences();

        when(() => mockNostrSigner.nip44Encrypt(any(), any()))
            .thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: [testEnvironment.relayUrl],
          ),
        );

        final service = buildService();
        await expectLater(service.updatePreferences(prefs), completes);
        service.dispose();
      });

      test(
        'completes without error when preferences publish is rejected',
        () async {
          const prefs = NotificationPreferences();

          when(() => mockNostrSigner.nip44Encrypt(any(), any()))
              .thenAnswer((_) async => encryptedPayload);

          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);

          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: {testEnvironment.relayUrl: 'blocked'},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          await expectLater(service.updatePreferences(prefs), completes);
          service.dispose();
        },
      );

      test(
        'drops preferences update when session changes after signing',
        () async {
          const prefs = NotificationPreferences();
          var current = true;
          when(() => mockNostrSigner.nip44Encrypt(any(), any()))
              .thenAnswer((_) async => encryptedPayload);

          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushPreferencesKind,
              content: encryptedPayload,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            current = false;
            return fakeEvent;
          });

          final service = buildService(isCurrent: () => current);
          await service.updatePreferences(prefs);

          verifyNever(() => mockNostrClient.publishEvent(any()));
          service.dispose();
        },
      );
    });

    group('handleForegroundMessage', () {
      test('displays a local notification carrying the normalized tap '
          'payload', () async {
        when(
          () => mockNotificationService.sendLocal(
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async {});

        const data = {
          'title': 'New comment',
          'body': 'alice commented',
          'type': 'comment',
          'eventId': 'comment_event',
          'referencedEventId': 'video_event',
          'senderPubkey': 'alice_hex',
        };

        final service = buildService();
        await service.handleForegroundMessage(data);

        final payload =
            verify(
                  () => mockNotificationService.sendLocal(
                    title: 'New comment',
                    body: 'alice commented',
                    payload: captureAny(named: 'payload'),
                  ),
                ).captured.single
                as String;
        // The foreground banner attaches exactly the shared payload shape.
        expect(jsonDecode(payload), equals(localNotificationTapPayload(data)));
        expect((jsonDecode(payload) as Map)['notificationType'], 'comment');
        service.dispose();
      });

      test(
        'preserves senderPubkey for a follow (no referencedEventId)',
        () async {
          when(
            () => mockNotificationService.sendLocal(
              title: any(named: 'title'),
              body: any(named: 'body'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) async {});

          const data = {
            'title': 'New follower',
            'body': 'bob started following you',
            'type': 'follow',
            'eventId': 'contact_event',
            'senderPubkey': 'bob_hex',
          };

          final service = buildService();
          await service.handleForegroundMessage(data);

          final payload =
              verify(
                    () => mockNotificationService.sendLocal(
                      title: any(named: 'title'),
                      body: any(named: 'body'),
                      payload: captureAny(named: 'payload'),
                    ),
                  ).captured.single
                  as String;
          final decoded = jsonDecode(payload) as Map<String, dynamic>;
          expect(decoded['notificationType'], 'follow');
          expect(decoded['senderPubkey'], 'bob_hex');
          expect(decoded['referencedEventId'], isNull);
          service.dispose();
        },
      );

      test('uses default app name as title when title is missing', () async {
        when(
          () => mockNotificationService.sendLocal(
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async {});

        final service = buildService();
        await service.handleForegroundMessage({
          'body': 'Someone liked your video',
        });

        verify(
          () => mockNotificationService.sendLocal(
            title: 'Divine',
            body: 'Someone liked your video',
            payload: any(named: 'payload'),
          ),
        ).called(1);
        service.dispose();
      });

      test('does not send notification when body is missing', () async {
        final service = buildService();
        await service.handleForegroundMessage({'title': 'New Like'});

        verifyNever(
          () => mockNotificationService.sendLocal(
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          ),
        );
        service.dispose();
      });
    });

    group('registerToken', () {
      test('publishes provided refreshed token through environment relay OK publish', () async {
        when(() => mockNostrSigner.nip44Encrypt(any(), any()))
            .thenAnswer((_) async => encryptedPayload);
        when(() => mockAuthService.currentIdentity).thenReturn(
          KeycastNostrIdentity(pubkey: testPubkey, rpcSigner: mockNostrSigner),
        );

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: [testEnvironment.relayUrl],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final service = buildService();

        await service.registerToken(testPubkey, 'new-refreshed-token');

        final registrationCapture = verify(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            captureAny(),
          ),
        );
        registrationCapture.called(1);
        final registrationJson = jsonDecode(
          registrationCapture.captured.single as String,
        ) as Map<String, dynamic>;
        expect(registrationJson['token'], 'new-refreshed-token');
        expect(
          registrationJson['timezoneOffsetMinutes'],
          DateTime.now().timeZoneOffset.inMinutes,
        );

        verify(
          () => mockNostrClient.publishEventAwaitOk(
            fakeEvent,
            targetRelays: [testEnvironment.relayUrl],
            timeout: pushPublishTimeout,
          ),
        ).called(1);

        service.dispose();
      });

      test(
        'drops refreshed token registration when session is stale',
        () async {
          when(() => mockAuthService.currentIdentity).thenReturn(
            KeycastNostrIdentity(
              pubkey: testPubkey,
              rpcSigner: mockNostrSigner,
            ),
          );
          final service = buildService(isCurrent: () => false);

          await service.registerToken(testPubkey, 'new-refreshed-token');

          verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
          service.dispose();
        },
      );
    });

    group('dispose', () {
      test('completes without errors', () {
        final service = buildService();
        expect(service.dispose, returnsNormally);
      });
    });
  });
}
