// ABOUTME: Covers push encryption after an offline identity upgrades in place.
// ABOUTME: A retained client's old signer must not trap the active session.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

class _Signer extends Mock implements NostrSigner {}

class _Notifications extends Mock implements NotificationService {}

enum _Operation { register, updatePreferences, deregister }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const otherPubkey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const environment = EnvironmentConfig(environment: AppEnvironment.staging);
  setUpAll(() {
    registerFallbackValue(Event(pubkey, 3079, [], ''));
    registerFallbackValue(<String>[]);
    registerFallbackValue(Duration.zero);
  });

  for (final operation in _Operation.values) {
    group(operation.name, () {
      for (final (switchAccount, sameAccount) in [
        (false, false),
        (true, false),
        if (operation == _Operation.register) (true, true),
      ]) {
        test(
          sameAccount
              ? 'retries an in-flight same-account signer upgrade'
              : switchAccount
              ? 'drops work after account changes during encryption'
              : 'uses upgraded identity with retained pubkey-only client',
          () async {
            final auth = _Auth();
            final client = _Client();
            final signer = _Signer();
            final oldIdentity = PubkeyOnlyNostrIdentity(pubkey: pubkey);
            NostrIdentity identity = oldIdentity;
            when(() => auth.currentIdentity).thenAnswer((_) => identity);
            when(() => client.signer).thenReturn(oldIdentity);
            final published = <Event>[];
            final encryptionStarted = Completer<void>();
            final encryption = Completer<String?>();
            when(() => signer.nip44Encrypt(any(), any())).thenAnswer((_) {
              if (!encryptionStarted.isCompleted) encryptionStarted.complete();
              return switchAccount
                  ? encryption.future
                  : Future.value('encrypted');
            });
            when(
              () => auth.createAndSignEvent(
                kind: any(named: 'kind'),
                content: any(named: 'content'),
                tags: any(named: 'tags'),
              ),
            ).thenAnswer(
              (call) async => Event(
                identity.pubkey,
                call.namedArguments[#kind] as int,
                call.namedArguments[#tags] as List<List<String>>,
                call.namedArguments[#content] as String,
              ),
            );
            when(
              () => client.publishEventAwaitOk(
                any(),
                targetRelays: any(named: 'targetRelays'),
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((call) async {
              final event = call.positionalArguments.first as Event;
              published.add(event);
              return PublishOutcome(
                eventId: event.id,
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
              getToken: () async => 'token',
            );
            addTearDown(service.dispose);
            identity = KeycastNostrIdentity(pubkey: pubkey, rpcSigner: signer);
            PushRegistrationResult? registrationResult;
            Future<void> run() async {
              switch (operation) {
                case _Operation.register:
                  registrationResult = await service.register(pubkey);
                case _Operation.updatePreferences:
                  await service.updatePreferences(
                    const NotificationPreferences(),
                  );
                case _Operation.deregister:
                  await service.deregister(pubkey);
              }
            }

            final pending = run();
            if (switchAccount) {
              // Wait for encryption or operation completion so the broken old
              // signer produces an assertion failure instead of a hung test.
              await Future.any([encryptionStarted.future, pending]);
              identity = KeycastNostrIdentity(
                pubkey: sameAccount ? pubkey : otherPubkey,
                rpcSigner: signer,
              );
              encryption.complete('encrypted');
            }
            await pending;
            expect(encryptionStarted.isCompleted, isTrue);
            expect(published, switchAccount ? isEmpty : hasLength(1));
            if (!switchAccount) expect(published.single.pubkey, pubkey);
            if (sameAccount) {
              expect(
                registrationResult,
                PushRegistrationResult.retryableFailure,
              );
              await run();
              expect(registrationResult, PushRegistrationResult.published);
              expect(published.single.pubkey, pubkey);
            }
          },
        );
      }
    });
  }
}
