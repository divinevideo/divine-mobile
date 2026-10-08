// ABOUTME: Exercises push registration recovery through the real session drain.
// ABOUTME: A temporary missing token or signer must recover without a relaunch.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/services/push_notification_session_coordinator.dart';

class _Auth extends Mock implements AuthService {}

class _Messaging extends Mock implements FirebaseMessaging {}

class _Client extends Mock implements NostrClient {}

class _Signer extends Mock implements NostrSigner {}

class _Notifications extends Mock implements NotificationService {}

class _Settings extends Mock implements NotificationSettings {}

class _LocalIdentity extends Mock implements LocalNostrIdentity {}

enum _Failure {
  missingToken('missing token'),
  tokenLookupException('token lookup exception'),
  missingEncryption('missing encryption'),
  encryptionTimeout('encryption timeout'),
  missingSignature('missing signature');

  const _Failure(this.label);

  final String label;
}

enum _IdentityKind {
  keycast('keycast'),
  offlineRestore('offline restore'),
  localKey('local key'),
  bunker('bunker');

  const _IdentityKind(this.label);

  final String label;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const environment = EnvironmentConfig(environment: AppEnvironment.staging);
  final event = Event(pubkey, 3079, [], 'encrypted-token');

  setUpAll(() {
    registerFallbackValue(event);
    registerFallbackValue(<String>[]);
    registerFallbackValue(Duration.zero);
  });

  group('register', () {
    for (final (failure, identityKind) in [
      (_Failure.missingToken, _IdentityKind.keycast),
      (_Failure.tokenLookupException, _IdentityKind.keycast),
      (_Failure.missingEncryption, _IdentityKind.keycast),
      (_Failure.encryptionTimeout, _IdentityKind.keycast),
      (_Failure.missingSignature, _IdentityKind.keycast),
      (_Failure.missingEncryption, _IdentityKind.offlineRestore),
      (_Failure.missingEncryption, _IdentityKind.localKey),
      (_Failure.missingSignature, _IdentityKind.localKey),
      (_Failure.missingEncryption, _IdentityKind.bunker),
      (_Failure.encryptionTimeout, _IdentityKind.bunker),
      (_Failure.missingSignature, _IdentityKind.bunker),
    ]) {
      final interactive = identityKind == _IdentityKind.bunker;
      final description = interactive
          ? 'does not re-prompt ${identityKind.label} after ${failure.label}'
          : 'registers after ${failure.label} recovers for '
                '${identityKind.label} without relaunch';
      test(description, () {
        fakeAsync((async) {
          var recovered = false;
          final published = <Event>[];
          final auth = _Auth();
          final messaging = _Messaging();
          final client = _Client();
          final signer = _Signer();
          final settings = _Settings();
          final local = _LocalIdentity();
          when(() => local.pubkey).thenReturn(pubkey);
          when(() => local.signsWithLocalKey).thenReturn(true);
          when(() => local.nip44Encrypt(any(), any())).thenAnswer(
            (call) => signer.nip44Encrypt(
              call.positionalArguments[0] as String,
              call.positionalArguments[1] as String,
            ),
          );
          final NostrIdentity identity = switch (identityKind) {
            _IdentityKind.localKey => local,
            _IdentityKind.bunker => BunkerNostrIdentity(
              pubkey: pubkey,
              remoteSigner: signer,
            ),
            _IdentityKind.offlineRestore => PubkeyOnlyNostrIdentity(
              pubkey: pubkey,
            ),
            _IdentityKind.keycast => KeycastNostrIdentity(
              pubkey: pubkey,
              rpcSigner: signer,
            ),
          };
          when(() => auth.currentIdentity).thenReturn(identity);
          when(() => client.signer).thenReturn(identity);
          when(() => client.hasKeys).thenReturn(true);
          when(() => client.publicKey).thenReturn(pubkey);
          when(() => settings.authorizationStatus)
              .thenReturn(AuthorizationStatus.authorized);
          when(messaging.getNotificationSettings)
              .thenAnswer((_) async => settings);
          when(() => messaging.onTokenRefresh)
              .thenAnswer((_) => const Stream<String>.empty());
          when(() => signer.nip44Encrypt(any(), any())).thenAnswer((_) async {
            if (!recovered && failure == _Failure.missingEncryption) {
              return null;
            }
            if (!recovered && failure == _Failure.encryptionTimeout) {
              throw TimeoutException('signer unavailable');
            }
            return 'encrypted-token';
          });
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => !recovered && failure == _Failure.missingSignature
                ? null
                : event,
          );
          when(
            () => client.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((invocation) async {
            final sent = invocation.positionalArguments.single as Event;
            published.add(sent);
            return PublishOutcome(
              eventId: sent.id,
              acceptedBy: [environment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            );
          });
          final service = PushNotificationService(
            authService: auth,
            nostrClient: client,
            notificationService: _Notifications(),
            environmentConfig: environment,
            getToken: () async {
              if (!recovered && failure == _Failure.missingToken) return null;
              if (!recovered && failure == _Failure.tokenLookupException) {
                throw PlatformException(code: 'apns-token-not-set');
              }
              return 'test-fcm-token';
            },
          );
          final readiness = NostrSessionReadiness.nostrReady(
            pubkey: pubkey,
            client: client,
          );
          final coordinator = PushNotificationSessionCoordinator(
            authService: auth,
            firebaseMessaging: messaging,
            readReadiness: () => readiness,
            readPushService: () => service,
            readCleanupClientFactory: () =>
                (_) => client,
          );
          coordinator.handleReadiness(readiness);
          async.flushMicrotasks();
          expect(published, isEmpty);

          recovered = true;
          if (identityKind == _IdentityKind.offlineRestore) {
            when(() => auth.currentIdentity).thenReturn(
              KeycastNostrIdentity(pubkey: pubkey, rpcSigner: signer),
            );
          }
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          expect(published, interactive ? isEmpty : [event]);
          async.elapse(const Duration(minutes: 2));
          async.flushMicrotasks();
          expect(published, hasLength(interactive ? 0 : 1));
          if (interactive) {
            verify(() => signer.nip44Encrypt(any(), any())).called(1);
            if (failure == _Failure.missingSignature) {
              verify(
                () => auth.createAndSignEvent(
                  kind: any(named: 'kind'),
                  content: any(named: 'content'),
                  tags: any(named: 'tags'),
                ),
              ).called(1);
            }
          }

          coordinator.dispose();
          service.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      });
    }
  });
}
