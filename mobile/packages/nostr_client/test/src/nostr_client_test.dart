import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('NostrClient', () {
    test('can be instantiated', () async {
      final privateKey = generatePrivateKey();
      final signer = LocalNostrSigner(privateKey);
      final publicKey = await signer.getPublicKey();
      expect(publicKey, isNotNull);
      final config = NostrClientConfig(
        signer: signer,
        publicKey: publicKey!,
      );
      final client = NostrClient(config);
      expect(client, isNotNull);
      expect(client.publicKey, equals(publicKey));
      client.close();
    });

    test('can be instantiated with gateway enabled', () async {
      final privateKey = generatePrivateKey();
      final signer = LocalNostrSigner(privateKey);
      final publicKey = await signer.getPublicKey();
      expect(publicKey, isNotNull);
      final config = NostrClientConfig(
        signer: signer,
        publicKey: publicKey!,
        enableGateway: true,
        gatewayUrl: 'https://test.gateway',
      );
      final client = NostrClient(config);
      expect(client, isNotNull);
      expect(client.publicKey, equals(publicKey));
      client.close();
    });

    test('relay management is delegated to nostr_sdk', () async {
      final privateKey = generatePrivateKey();
      final signer = LocalNostrSigner(privateKey);
      final publicKey = await signer.getPublicKey();
      expect(publicKey, isNotNull);
      final config = NostrClientConfig(
        signer: signer,
        publicKey: publicKey!,
      );
      final client = NostrClient(config);

      // Relay management is handled by nostr_sdk through relayPool
      final relay = RelayBase('wss://test.relay', RelayStatus('wss://test.relay'));
      
      // First add should succeed
      final firstAdd = await client.relayPool.add(relay);
      expect(firstAdd, isTrue);

      // Second add should return true (nostr_sdk handles duplicates)
      final secondAdd = await client.relayPool.add(relay);
      expect(secondAdd, isTrue);

      client.close();
    });

    test('deduplicates subscriptions with identical filters', () {
      final privateKey = generatePrivateKey();
      final signer = LocalNostrSigner(privateKey);
      final config = NostrClientConfig(
        signer: signer,
        publicKey: 'test_pubkey',
      );
      final client = NostrClient(config);

      final filters = [
        Filter(kinds: [EventKind.TEXT_NOTE], limit: 10),
      ];

      // Create first subscription
      final stream1 = client.subscribe(filters);
      expect(stream1, isNotNull);

      // Create second subscription with same filters
      final stream2 = client.subscribe(filters);
      expect(stream2, isNotNull);

      // Both should be the same stream (deduplicated)
      expect(stream1, equals(stream2));

      client.close();
    });
  });
}
