import 'dart:convert';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  late _MockSecureKeyContainer mockKeyContainer;
  late NostrCreatorBindingService service;

  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() {
    registerFallbackValue(_MockSecureKeyContainer());
  });

  setUp(() {
    mockKeyContainer = _MockSecureKeyContainer();
    when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
    when(() => mockKeyContainer.isDisposed).thenReturn(false);
    when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer((
      invocation,
    ) {
      final callback =
          invocation.positionalArguments[0] as String Function(String);
      return callback(testPrivateKey);
    });

    service = NostrCreatorBindingService(
      identity: LocalNostrIdentity(keyContainer: mockKeyContainer),
      now: () => DateTime.utc(2026, 3, 29, 8, 30),
    );
  });

  group('NostrCreatorBindingService', () {
    test(
      'creates deterministic canonical payload with sorted claims and references',
      () async {
        final first = await service.createAssertion(
          claims: const CreatorBindingClaims(
            nip05: 'alice@example.com',
            website: 'https://example.com',
            socialHandles: <CreatorSocialHandle>[
              CreatorSocialHandle(platform: 'x', handle: '@alice'),
              CreatorSocialHandle(platform: 'github', handle: 'alice'),
            ],
          ),
          hardBinding: const CreatorBindingHardBinding(
            alg: 'sha256',
            value: 'ef5d3d4f69d72df6d4d08f625f66ecfb17b3a6dd4e03f6f5a6a5f0e31ecfe8ee',
          ),
          referencedAssertions: const <String>[
            'c2pa.actions.v2',
            'c2pa.hash.data',
          ],
        );

        final second = await service.createAssertion(
          claims: const CreatorBindingClaims(
            nip05: 'alice@example.com',
            website: 'https://example.com',
            socialHandles: <CreatorSocialHandle>[
              CreatorSocialHandle(platform: 'x', handle: '@alice'),
              CreatorSocialHandle(platform: 'github', handle: 'alice'),
            ],
          ),
          hardBinding: const CreatorBindingHardBinding(
            alg: 'sha256',
            value: 'ef5d3d4f69d72df6d4d08f625f66ecfb17b3a6dd4e03f6f5a6a5f0e31ecfe8ee',
          ),
          referencedAssertions: const <String>[
            'c2pa.actions.v2',
            'c2pa.hash.data',
          ],
        );

        expect(first, isNotNull);
        expect(second, isNotNull);
        final firstAssertion = first!;
        final secondAssertion = second!;
        final payload =
            jsonDecode(firstAssertion.payloadJson) as Map<String, dynamic>;
        final claims = payload['claims'] as Map<String, dynamic>;
        final socialHandles = claims['social_handles'] as List<dynamic>;
        final unsignedPayload = Map<String, dynamic>.from(payload)
          ..remove('signature');
        final signingDigest = sha256
            .convert(utf8.encode(jsonEncode(unsignedPayload)))
            .toString();

        expect(
          firstAssertion.assertionLabel,
          equals('video.divine.nostr.creator_binding'),
        );
        expect(firstAssertion.pubkey, equals(testPublicKey));
        expect(firstAssertion.payloadJson, equals(secondAssertion.payloadJson));
        expect(firstAssertion.signature, equals(secondAssertion.signature));
        expect(payload['version'], equals(1));
        expect(payload['pubkey'], equals(testPublicKey));
        expect(payload['sig_alg'], equals('nostr.secp256k1'));
        expect(payload['created_at'], equals('2026-03-29T08:30:00.000Z'));
        expect(
          payload['referenced_assertions'],
          equals(const <String>['c2pa.actions.v2', 'c2pa.hash.data']),
        );
        expect(
          payload['hard_binding'],
          equals(const <String, String>{
            'alg': 'sha256',
            'value': 'ef5d3d4f69d72df6d4d08f625f66ecfb17b3a6dd4e03f6f5a6a5f0e31ecfe8ee',
          }),
        );
        expect(claims['nip05'], equals('alice@example.com'));
        expect(claims['website'], equals('https://example.com'));
        expect(
          socialHandles,
          equals(const <Map<String, String>>[
            <String, String>{'platform': 'github', 'handle': 'alice'},
            <String, String>{'platform': 'x', 'handle': '@alice'},
          ]),
        );
        expect(
          schnorr.verify(
            testPublicKey,
            signingDigest,
            payload['signature'] as String,
          ),
          isTrue,
        );
      },
    );

    test('throws when no authenticated signer is available', () async {
      final unauthenticatedService = NostrCreatorBindingService(
        identity: null,
        now: () => DateTime.utc(2026, 3, 29, 8, 30),
      );

      await expectLater(
        () => unauthenticatedService.createAssertion(
          claims: const CreatorBindingClaims(),
          hardBinding: const CreatorBindingHardBinding(
            alg: 'sha256',
            value: 'deadbeef',
          ),
          referencedAssertions: const <String>['c2pa.hash.data'],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'returns null (not throw) when identity does not support canonical '
      'signing',
      () async {
        // BunkerNostrIdentity always returns null from signCanonicalPayload
        // because NIP-46 has no canonical-sign primitive. The same fall-soft
        // path applies to OAuth users until the Keycast backend exposes
        // sign_canonical, and to Amber users.
        final mockSigner = _MockNostrSigner();
        final bunkerIdentity = BunkerNostrIdentity(
          pubkey: testPublicKey,
          remoteSigner: mockSigner,
        );
        final unsupportedService = NostrCreatorBindingService(
          identity: bunkerIdentity,
          now: () => DateTime.utc(2026, 3, 29, 8, 30),
        );

        final result = await unsupportedService.createAssertion(
          claims: const CreatorBindingClaims(),
          hardBinding: const CreatorBindingHardBinding(
            alg: 'sha256',
            value: 'deadbeef',
          ),
          referencedAssertions: const <String>['c2pa.hash.data'],
        );

        expect(result, isNull);
      },
    );
  });
}
