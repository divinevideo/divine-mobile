// ABOUTME: Tests for SignerFactory — identity construction priority and the
// ABOUTME: createAndSignEvent dispatch/validation extracted from AuthService.

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth/signer_factory.dart';
import 'package:openvine/services/local_key_signer.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAndroidNostrSigner extends Mock implements AndroidNostrSigner {}

class _MockNip07Service extends Mock implements Nip07Service {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockNostrRemoteSigner extends Mock implements NostrRemoteSigner {}

class _MockKeycastRpc extends Mock implements KeycastRpc {}

class _MockLocalKeySigner extends Mock implements LocalKeySigner {}

/// Recorded crash-report invocation for asserting the reporter port.
class _ReportedError {
  _ReportedError(this.error, this.reason, this.logMessage);

  final Object error;
  final String reason;
  final String logMessage;
}

void main() {
  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
  const otherPublicKey =
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

  setUpAll(() {
    registerFallbackValue(Event(testPublicKey, 1, [], ''));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group(SignerFactory, () {
    group('buildIdentity', () {
      late SignerFactory factory;

      setUp(() {
        factory = SignerFactory();
      });

      SecureKeyContainer privateContainer() =>
          SecureKeyContainer.fromPrivateKeyHex(testPrivateKey);

      SecureKeyContainer pubOnlyContainer() =>
          SecureKeyContainer.fromPublicKey(testPublicKey);

      test('throws StateError when key container is null', () {
        expect(
          () => factory.buildIdentity(
            keyContainer: null,
            authSource: AuthenticationSource.importedKeys,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('no key container'),
            ),
          ),
        );
      });

      test('Amber wins over every other signer', () {
        final identity = factory.buildIdentity(
          keyContainer: privateContainer(),
          authSource: AuthenticationSource.amber,
          amberSigner: _MockAndroidNostrSigner(),
          nip07Service: _MockNip07Service(),
          bunkerSigner: _MockNostrRemoteSigner(),
          keycastSigner: _MockKeycastRpc(),
        );

        expect(identity, isA<AmberNostrIdentity>());
        expect(identity.pubkey, equals(testPublicKey));
      });

      test('NIP-07 wins when no Amber signer is set', () {
        final identity = factory.buildIdentity(
          keyContainer: privateContainer(),
          authSource: AuthenticationSource.nip07,
          nip07Service: _MockNip07Service(),
          bunkerSigner: _MockNostrRemoteSigner(),
          keycastSigner: _MockKeycastRpc(),
        );

        expect(identity, isA<Nip07NostrIdentity>());
      });

      test('Bunker wins when no Amber/NIP-07 signer is set', () {
        final identity = factory.buildIdentity(
          keyContainer: privateContainer(),
          authSource: AuthenticationSource.bunker,
          bunkerSigner: _MockNostrRemoteSigner(),
          keycastSigner: _MockKeycastRpc(),
        );

        expect(identity, isA<BunkerNostrIdentity>());
      });

      test('Keycast with a local private key attaches a local signer', () {
        final identity = factory.buildIdentity(
          keyContainer: privateContainer(),
          authSource: AuthenticationSource.divineOAuth,
          keycastSigner: _MockKeycastRpc(),
        );

        expect(identity, isA<KeycastNostrIdentity>());
        expect(identity.signsWithLocalKey, isTrue);
      });

      test('Keycast with a pub-key-only container has no local signer', () {
        final identity = factory.buildIdentity(
          keyContainer: pubOnlyContainer(),
          authSource: AuthenticationSource.divineOAuth,
          keycastSigner: _MockKeycastRpc(),
        );

        expect(identity, isA<KeycastNostrIdentity>());
        expect(identity.signsWithLocalKey, isFalse);
      });

      test('falls back to LocalNostrIdentity with private key and no '
          'remote signers', () {
        final identity = factory.buildIdentity(
          keyContainer: privateContainer(),
          authSource: AuthenticationSource.importedKeys,
        );

        expect(identity, isA<LocalNostrIdentity>());
        expect(identity.signsWithLocalKey, isTrue);
      });

      test('divineOAuth source still falls back to LocalNostrIdentity', () {
        final identity = factory.buildIdentity(
          keyContainer: privateContainer(),
          authSource: AuthenticationSource.divineOAuth,
        );

        expect(identity, isA<LocalNostrIdentity>());
      });

      test('divineOAuth with pub-key-only container and explicit opt-in '
          'builds PubkeyOnlyNostrIdentity', () {
        final identity = factory.buildIdentity(
          keyContainer: pubOnlyContainer(),
          authSource: AuthenticationSource.divineOAuth,
          allowPubkeyOnlyIdentity: true,
        );

        expect(identity, isA<PubkeyOnlyNostrIdentity>());
        expect(identity.signsWithLocalKey, isFalse);
      });

      test('divineOAuth with pub-key-only container and no opt-in throws', () {
        expect(
          () => factory.buildIdentity(
            keyContainer: pubOnlyContainer(),
            authSource: AuthenticationSource.divineOAuth,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('pub-key-only container'),
                contains(AuthenticationSource.divineOAuth.name),
              ),
            ),
          ),
        );
      });

      test('throws StateError for pub-key-only container with no remote '
          'signer', () {
        expect(
          () => factory.buildIdentity(
            keyContainer: pubOnlyContainer(),
            authSource: AuthenticationSource.importedKeys,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('pub-key-only container'),
                contains(AuthenticationSource.importedKeys.name),
              ),
            ),
          ),
        );
      });
    });

    group('createAndSignEvent', () {
      late List<_ReportedError> reported;
      late SignerFactory factory;

      setUp(() async {
        reported = [];
        factory = SignerFactory(
          crashReporter:
              (
                error,
                stackTrace, {
                required String reason,
                required String logMessage,
              }) {
                reported.add(_ReportedError(error, reason, logMessage));
              },
        );
        // Pin the NIP-89 static cache to a known state for each test.
        Nip89ClientTag.resetForTest();
        await Nip89ClientTag.setEnabled(enabled: false);
      });

      tearDown(() {
        // Never leak the mutated static cache or the mock prefs store into
        // later suites — CI runs all tests in one isolate (--optimization)
        // with shuffled ordering.
        Nip89ClientTag.resetForTest();
        SharedPreferences.setMockInitialValues({});
      });

      LocalNostrIdentity localIdentity() => LocalNostrIdentity(
        keyContainer: SecureKeyContainer.fromPrivateKeyHex(testPrivateKey),
      );

      test('signs a kind 1 event with a local identity', () async {
        final event = await factory.createAndSignEvent(
          identity: localIdentity(),
          authSource: AuthenticationSource.importedKeys,
          kind: 1,
          content: 'hello divine',
        );

        expect(event, isNotNull);
        expect(event!.pubkey, equals(testPublicKey));
        expect(event.kind, equals(1));
        expect(event.content, equals('hello divine'));
        expect(event.isValid, isTrue);
        expect(event.isSigned, isTrue);
        expect(reported, isEmpty);
      });

      test('kind 0 events preserve caller tags before expiration', () async {
        final event = await factory.createAndSignEvent(
          identity: localIdentity(),
          authSource: AuthenticationSource.importedKeys,
          kind: 0,
          content: '{}',
          tags: [
            ['p', otherPublicKey],
          ],
        );

        expect(event, isNotNull);
        // Caller tags come first; expiration is appended before signing,
        // preserving the exact pre-extraction tag construction order.
        expect(event!.tags.first, equals(['p', otherPublicKey]));
        final expiration = event.tags.where((t) => t.first == 'expiration');
        expect(expiration, hasLength(1));
        expect(int.parse(expiration.single[1]), greaterThan(0));
      });

      test('appends the NIP-89 client tag when enabled', () async {
        await Nip89ClientTag.setEnabled(enabled: true);

        final event = await factory.createAndSignEvent(
          identity: localIdentity(),
          authSource: AuthenticationSource.importedKeys,
          kind: 1,
          content: 'tagged',
        );

        expect(event, isNotNull);
        expect(event!.tags.any((t) => t.first == 'client'), isTrue);
      });

      test('omits the NIP-89 client tag when disabled', () async {
        final event = await factory.createAndSignEvent(
          identity: localIdentity(),
          authSource: AuthenticationSource.importedKeys,
          kind: 1,
          content: 'untagged',
        );

        expect(event, isNotNull);
        expect(event!.tags.any((t) => t.first == 'client'), isFalse);
      });

      test('omits the NIP-89 client tag for excluded kinds even when '
          'enabled', () async {
        await Nip89ClientTag.setEnabled(enabled: true);

        final event = await factory.createAndSignEvent(
          identity: localIdentity(),
          authSource: AuthenticationSource.importedKeys,
          kind: EventKind.giftWrap,
          content: 'sealed',
        );

        expect(event, isNotNull);
        expect(event!.tags.any((t) => t.first == 'client'), isFalse);
      });

      // The apps bridge hands this method a caller-supplied kind, so the
      // exclusion set is the only thing standing between a NIP-59 wrapper and
      // a public attribution tag on this path. NIP-59 defines two outer
      // wrapper kinds; 21059 arrived after the set was written (#8177).
      test('omits the NIP-89 client tag for ephemeral gift wraps even when '
          'enabled', () async {
        await Nip89ClientTag.setEnabled(enabled: true);

        final event = await factory.createAndSignEvent(
          identity: localIdentity(),
          authSource: AuthenticationSource.importedKeys,
          kind: EventKind.ephemeralGiftWrap,
          content: 'sealed',
        );

        expect(event, isNotNull);
        expect(event!.tags.any((t) => t.first == 'client'), isFalse);
      });

      test('does not duplicate a caller-supplied client tag', () async {
        await Nip89ClientTag.setEnabled(enabled: true);

        final event = await factory.createAndSignEvent(
          identity: localIdentity(),
          authSource: AuthenticationSource.importedKeys,
          kind: 1,
          content: 'pre-tagged',
          tags: [
            ['client', 'SomeOtherClient'],
          ],
        );

        expect(event, isNotNull);
        expect(event!.tags.where((t) => t.first == 'client'), hasLength(1));
        expect(event.tags.single, equals(['client', 'SomeOtherClient']));
      });

      test('honors an explicit createdAt', () async {
        const fixedCreatedAt = 1700000000;

        final event = await factory.createAndSignEvent(
          identity: localIdentity(),
          authSource: AuthenticationSource.importedKeys,
          kind: 1,
          content: 'pinned time',
          createdAt: fixedCreatedAt,
        );

        expect(event, isNotNull);
        expect(event!.createdAt, equals(fixedCreatedAt));
      });

      test(
        'returns null without reporting when the signer returns null',
        () async {
          final remoteSigner = _MockNostrSigner();
          when(
            () => remoteSigner.signEvent(any()),
          ).thenAnswer((_) async => null);
          final identity = BunkerNostrIdentity(
            pubkey: testPublicKey,
            remoteSigner: remoteSigner,
          );

          final event = await factory.createAndSignEvent(
            identity: identity,
            authSource: AuthenticationSource.bunker,
            kind: 1,
            content: 'never signed',
          );

          expect(event, isNull);
          expect(reported, isEmpty);
        },
      );

      test('returns null and reports when the signer answers for a '
          'different account', () async {
        final remoteSigner = _MockNostrSigner();
        when(() => remoteSigner.signEvent(any())).thenAnswer(
          (_) async => Event(otherPublicKey, 1, [], 'wrong account'),
        );
        final identity = BunkerNostrIdentity(
          pubkey: testPublicKey,
          remoteSigner: remoteSigner,
        );

        final event = await factory.createAndSignEvent(
          identity: identity,
          authSource: AuthenticationSource.bunker,
          kind: 1,
          content: 'mismatch',
        );

        expect(event, isNull);
        expect(reported, hasLength(1));
        expect(
          reported.single.error,
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<EventSignerAccountMismatchException>()
                .having((e) => e.expectedPubkey, 'expected', testPublicKey)
                .having((e) => e.actualPubkey, 'actual', otherPublicKey),
          ),
        );
        expect(
          reported.single.reason,
          equals('Signer returned an event for a different account'),
        );
        expect(
          reported.single.logMessage,
          equals('Signer account mismatch during createAndSignEvent'),
        );
      });

      test('returns null when a remote signature fails verification', () async {
        final remoteSigner = _MockNostrSigner();
        // Correct pubkey but no signature — remote identities must fail the
        // schnorr verification (local identities skip it).
        when(
          () => remoteSigner.signEvent(any()),
        ).thenAnswer((_) async => Event(testPublicKey, 1, [], 'unsigned'));
        final identity = BunkerNostrIdentity(
          pubkey: testPublicKey,
          remoteSigner: remoteSigner,
        );

        final event = await factory.createAndSignEvent(
          identity: identity,
          authSource: AuthenticationSource.bunker,
          kind: 1,
          content: 'unsigned',
        );

        expect(event, isNull);
        expect(reported, isEmpty);
      });

      test(
        'skips the schnorr re-verification for local-key identities',
        () async {
          // A Keycast identity with a local signer has signsWithLocalKey=true,
          // so an event that would fail isSigned still passes — pinning the
          // hot-path optimization that trusts our own in-process signature.
          final localSigner = _MockLocalKeySigner();
          when(() => localSigner.signEvent(any())).thenAnswer(
            (_) async => Event(testPublicKey, 1, [], 'trusted unsigned'),
          );
          final identity = KeycastNostrIdentity(
            pubkey: testPublicKey,
            rpcSigner: _MockKeycastRpc(),
            localSigner: localSigner,
          );

          final event = await factory.createAndSignEvent(
            identity: identity,
            authSource: AuthenticationSource.divineOAuth,
            kind: 1,
            content: 'trusted unsigned',
          );

          expect(event, isNotNull);
          expect(event!.isSigned, isFalse);
        },
      );

      test('falls back to inline verification when the verify isolate cannot '
          'spawn — a validly signed remote event is not dropped', () async {
        final failingFactory = SignerFactory(
          verifyOffMain: (_) async => throw StateError('isolate spawn refused'),
        );
        final remoteSigner = _MockNostrSigner();
        // Produce a REAL signature so the inline fallback can verify it.
        when(() => remoteSigner.signEvent(any())).thenAnswer((inv) async {
          final event = inv.positionalArguments.first as Event;
          return LocalNostrSigner(testPrivateKey).signEvent(event);
        });
        final identity = BunkerNostrIdentity(
          pubkey: testPublicKey,
          remoteSigner: remoteSigner,
        );

        final event = await failingFactory.createAndSignEvent(
          identity: identity,
          authSource: AuthenticationSource.bunker,
          kind: 1,
          content: 'valid despite spawn failure',
        );

        expect(event, isNotNull);
        expect(event!.isSigned, isTrue);
      });

      test('inline fallback still rejects an invalid remote signature when the '
          'verify isolate cannot spawn', () async {
        final failingFactory = SignerFactory(
          verifyOffMain: (_) async => throw StateError('isolate spawn refused'),
        );
        final remoteSigner = _MockNostrSigner();
        when(
          () => remoteSigner.signEvent(any()),
        ).thenAnswer((_) async => Event(testPublicKey, 1, [], 'unsigned'));
        final identity = BunkerNostrIdentity(
          pubkey: testPublicKey,
          remoteSigner: remoteSigner,
        );

        final event = await failingFactory.createAndSignEvent(
          identity: identity,
          authSource: AuthenticationSource.bunker,
          kind: 1,
          content: 'unsigned',
        );

        expect(event, isNull);
      });
    });
  });
}
