import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/nostr_service_factory.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  group('NostrServiceFactory', () {
    group('create', () {
      test('creates client with LocalNostrIdentity signer', () {
        final mockKeyContainer = _MockSecureKeyContainer();
        when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
        when(() => mockKeyContainer.isDisposed).thenReturn(false);

        final signer = LocalNostrIdentity(keyContainer: mockKeyContainer);
        final client = NostrServiceFactory.create(signer: signer);

        expect(client, isA<NostrClient>());
        // Public key is empty before initialize() - signer is source of truth
        expect(client.publicKey, isEmpty);
      });

      test('creates client with mock signer', () {
        final mockSigner = _MockNostrSigner();
        when(mockSigner.getPublicKey).thenAnswer((_) async => testPublicKey);

        final client = NostrServiceFactory.create(signer: mockSigner);

        expect(client, isA<NostrClient>());
        expect(client.publicKey, isEmpty);
      });
    });

    group('no signer supplied', () {
      test('substitutes a keyless signer that reports no keys', () {
        final client = NostrServiceFactory.create();

        expect(client.signer, isA<UnauthenticatedSigner>());
        // hasKeys false is what gates every author-scoped query and the
        // NIP-42 AUTH handshake while signed out.
        expect(client.hasKeys, isFalse);
        expect(client.publicKey, isEmpty);
      });

      test('keyless signer throws instead of silently returning null', () {
        final client = NostrServiceFactory.create();
        final event = Event(testPublicKey, 1, const <List<String>>[], 'hi');

        expect(client.signer.signEvent(event), throwsStateError);
      });
    });

    group('environment relay isolation', () {
      test('production allows any relay host', () {
        final client = NostrServiceFactory.create(
          signer: _MockNostrSigner(),
          environmentConfig: EnvironmentConfig.production,
        );

        expect(client.isRelayAllowed('wss://relay.divine.video'), isTrue);
        expect(client.isRelayAllowed('wss://relay.example.com'), isTrue);
      });

      test('no environment config falls back to allow-all', () {
        final client = NostrServiceFactory.create(signer: _MockNostrSigner());

        expect(client.isRelayAllowed('wss://relay.divine.video'), isTrue);
        expect(client.isRelayAllowed('wss://relay.example.com'), isTrue);
      });

      test('staging locks to the staging relay host', () {
        final client = NostrServiceFactory.create(
          signer: _MockNostrSigner(),
          environmentConfig: const EnvironmentConfig(
            environment: AppEnvironment.staging,
          ),
        );

        expect(
          client.isRelayAllowed('wss://relay.staging.divine.video'),
          isTrue,
        );
        expect(client.isRelayAllowed('wss://relay.divine.video'), isFalse);
        expect(client.isRelayAllowed('wss://relay.example.com'), isFalse);
      });
    });

    // #6838: an author-scoped query skips when resolvePublicKey() is null.
    // That can only be re-driven if the same client later resolves a key, so
    // pin that an identity-backed client resolves on the first call, before
    // initialize() and whatever its inner remote signer answers.
    group('resolvePublicKey before initialize', () {
      late _MockNostrSigner unavailableRemote;

      setUp(() {
        unavailableRemote = _MockNostrSigner();
        when(unavailableRemote.getPublicKey).thenAnswer((_) async => null);
      });

      final identities = <String, NostrIdentity Function(NostrSigner)>{
        'LocalNostrIdentity': (_) {
          final keyContainer = _MockSecureKeyContainer();
          when(() => keyContainer.publicKeyHex).thenReturn(testPublicKey);
          when(() => keyContainer.isDisposed).thenReturn(false);
          return LocalNostrIdentity(keyContainer: keyContainer);
        },
        'PubkeyOnlyNostrIdentity': (_) =>
            PubkeyOnlyNostrIdentity(pubkey: testPublicKey),
        'KeycastNostrIdentity with an unavailable RPC signer': (remote) =>
            KeycastNostrIdentity(pubkey: testPublicKey, rpcSigner: remote),
        'BunkerNostrIdentity with an unavailable remote signer': (remote) =>
            BunkerNostrIdentity(pubkey: testPublicKey, remoteSigner: remote),
        'AmberNostrIdentity with an unavailable signer': (remote) =>
            AmberNostrIdentity(pubkey: testPublicKey, amberSigner: remote),
        'Nip07NostrIdentity with an unavailable extension': (remote) =>
            Nip07NostrIdentity(pubkey: testPublicKey, nip07Signer: remote),
      };

      for (final MapEntry(key: name, value: build) in identities.entries) {
        test('$name resolves its pubkey on the first call', () async {
          final client = NostrServiceFactory.create(
            signer: build(unavailableRemote),
          );

          expect(client.publicKey, isEmpty);
          expect(await client.resolvePublicKey(), equals(testPublicKey));
          verifyNever(unavailableRemote.getPublicKey);
        });
      }

      test('the keyless client resolves no key on any call', () async {
        final client = NostrServiceFactory.create();

        expect(await client.resolvePublicKey(), isNull);
        expect(await client.resolvePublicKey(), isNull);
      });
    });
  });
}
