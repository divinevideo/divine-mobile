// ABOUTME: Exercises push registration recovery through the real session drain.
// ABOUTME: A temporary missing token or signer must recover without a relaunch.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
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

class _KeyContainer extends Mock implements SecureKeyContainer {}

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

  for (final (failure, identityKind) in [
    ('missing token', 'keycast'),
    ('token lookup exception', 'keycast'),
    ('missing encryption', 'keycast'),
    ('encryption timeout', 'keycast'),
    ('missing signature', 'keycast'),
    ('missing encryption', 'offline restore'),
    ('missing encryption', 'local key'),
    ('missing signature', 'local key'),
    ('missing encryption', 'bunker'),
    ('encryption timeout', 'bunker'),
    ('missing signature', 'bunker'),
  ]) {
    final interactive = identityKind == 'bunker';
    final description = interactive
        ? 'does not re-prompt $identityKind after $failure'
        : 'registers after $failure recovers for $identityKind without relaunch';
    test(description, () {
      fakeAsync((async) {
        var recovered = false;
        final published = <Event>[];
        final auth = _Auth();
        final messaging = _Messaging();
        final client = _Client();
        final signer = _Signer();
        final settings = _Settings();
        final keys = _KeyContainer();
        when(() => keys.publicKeyHex).thenReturn(pubkey);
        final NostrIdentity identity = switch (identityKind) {
          'local key' => LocalNostrIdentity(keyContainer: keys),
          'bunker' => BunkerNostrIdentity(pubkey: pubkey, remoteSigner: signer),
          'offline restore' => PubkeyOnlyNostrIdentity(pubkey: pubkey),
          _ => KeycastNostrIdentity(pubkey: pubkey, rpcSigner: signer),
        };
        when(() => auth.currentIdentity).thenReturn(identity);
        when(() => client.signer).thenReturn(signer);
        when(() => client.hasKeys).thenReturn(true);
        when(() => client.publicKey).thenReturn(pubkey);
        when(() => settings.authorizationStatus)
            .thenReturn(AuthorizationStatus.authorized);
        when(messaging.getNotificationSettings)
            .thenAnswer((_) async => settings);
        when(() => messaging.onTokenRefresh)
            .thenAnswer((_) => const Stream<String>.empty());
        when(() => signer.nip44Encrypt(any(), any())).thenAnswer((_) async {
          if (!recovered && failure == 'missing encryption') return null;
          if (!recovered && failure == 'encryption timeout') {
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
          (_) async =>
              !recovered && failure == 'missing signature' ? null : event,
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
            if (!recovered && failure == 'missing token') return null;
            if (!recovered && failure == 'token lookup exception') {
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
        if (identityKind == 'offline restore') {
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

        coordinator.dispose();
        service.dispose();
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
      });
    });
  }
}
