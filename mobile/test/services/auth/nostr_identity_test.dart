import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/local_key_signer.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockLocalKeySigner extends Mock implements LocalKeySigner {}

class _MockKeycastRpc extends Mock implements KeycastRpc {}

void main() {
  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() {
    registerFallbackValue(Event(testPublicKey, 0, [], ''));
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(<Map<String, dynamic>>[]);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String>[]);
  });

  group(LocalNostrIdentity, () {
    late _MockSecureKeyContainer mockKeyContainer;

    setUp(() {
      mockKeyContainer = _MockSecureKeyContainer();
      when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
      when(() => mockKeyContainer.isDisposed).thenReturn(false);
    });

    test('pubkey matches key container public key', () {
      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('npub encodes pubkey to bech32 format', () {
      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      expect(identity.npub, startsWith('npub1'));
      expect(identity.npub, equals(NostrKeyUtils.encodePubKey(testPublicKey)));
    });

    test('getPublicKey returns pubkey', () async {
      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      expect(await identity.getPublicKey(), equals(testPublicKey));
    });

    test('signEvent signs via LocalKeySigner', () async {
      when(() => mockKeyContainer.withPrivateKey<Event>(any())).thenAnswer((
        invocation,
      ) {
        final callback =
            invocation.positionalArguments[0] as Event Function(String);
        return callback(testPrivateKey);
      });

      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');

      final signed = await identity.signEvent(event);

      expect(signed, isNotNull);
      expect(signed!.sig, isNotEmpty);
    });

    test('signCanonicalPayload signs locally', () async {
      when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer((
        invocation,
      ) {
        final callback =
            invocation.positionalArguments[0] as String Function(String);
        return callback(testPrivateKey);
      });

      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);
      final payload = Uint8List.fromList([1, 2, 3]);

      final signature = await identity.signCanonicalPayload(payload);

      expect(signature, isNotNull);
      expect(signature, isNotEmpty);
    });
  });

  group(KeycastNostrIdentity, () {
    late _MockNostrSigner mockRpc;

    setUp(() {
      mockRpc = _MockNostrSigner();
    });

    // #7332: these four fallbacks were unreachable. The local signer threw
    // instead of producing a typed failure, so the identity had no explicit
    // failure it could catch before consulting RPC. A mocked local signer
    // cannot pin the LocalKeySigner boundary, so these drive a REAL signer
    // into a genuine crypto failure with an off-curve peer pubkey.
    group('crypto fallback to RPC when the local signer fails', () {
      // Well-formed 32-byte hex that is not a point on secp256k1.
      const offCurvePubkey =
          '0000000000000000000000000000000000000000000000000000000000000000';

      late KeycastNostrIdentity identity;
      late _MockSecureKeyContainer container;

      setUp(() {
        container = _MockSecureKeyContainer();
        when(() => container.publicKeyHex).thenReturn(testPublicKey);
        when(() => container.isDisposed).thenReturn(false);
        when(() => container.hasPrivateKey).thenReturn(true);
        when(() => container.withPrivateKey<Uint8List>(any())).thenAnswer((
          invocation,
        ) {
          final callback =
              invocation.positionalArguments[0] as Uint8List Function(String);
          return callback(testPrivateKey);
        });
        when(() => container.withPrivateKey<String>(any())).thenAnswer((
          invocation,
        ) {
          final callback =
              invocation.positionalArguments[0] as String Function(String);
          return callback(testPrivateKey);
        });

        identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockRpc,
          localSigner: LocalKeySigner(container),
        );
      });

      test('nip44Encrypt falls back to RPC', () async {
        when(
          () => mockRpc.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => 'rpc-ciphertext');

        expect(
          await identity.nip44Encrypt(offCurvePubkey, 'hello'),
          equals('rpc-ciphertext'),
        );
        verify(() => mockRpc.nip44Encrypt(any(), any())).called(1);
        // Pins that the local signer really attempted the operation and
        // failed, rather than an unstubbed mock handing back null.
        verify(() => container.withPrivateKey<Uint8List>(any())).called(1);
      });

      test('nip44Decrypt falls back to RPC', () async {
        when(
          () => mockRpc.nip44Decrypt(any(), any()),
        ).thenAnswer((_) async => 'rpc-plaintext');

        expect(
          await identity.nip44Decrypt(offCurvePubkey, 'AgAB'),
          equals('rpc-plaintext'),
        );
        verify(() => mockRpc.nip44Decrypt(any(), any())).called(1);
        // Pins that the local signer really attempted the operation and
        // failed, rather than an unstubbed mock handing back null.
        verify(() => container.withPrivateKey<Uint8List>(any())).called(1);
      });

      test('encrypt falls back to RPC', () async {
        when(
          () => mockRpc.encrypt(any(), any()),
        ).thenAnswer((_) async => 'rpc-nip04-ciphertext');

        expect(
          await identity.encrypt(offCurvePubkey, 'hello'),
          equals('rpc-nip04-ciphertext'),
        );
        verify(() => mockRpc.encrypt(any(), any())).called(1);
        // Pins that the local signer really attempted the operation and
        // failed, rather than an unstubbed mock handing back null.
        verify(() => container.withPrivateKey<String>(any())).called(1);
      });

      test('decrypt falls back to RPC', () async {
        when(
          () => mockRpc.decrypt(any(), any()),
        ).thenAnswer((_) async => 'rpc-nip04-plaintext');

        expect(
          await identity.decrypt(
            offCurvePubkey,
            'AA==?iv=AAAAAAAAAAAAAAAAAAAAAA==',
          ),
          equals('rpc-nip04-plaintext'),
        );
        verify(() => mockRpc.decrypt(any(), any())).called(1);
        // Pins that the local signer really attempted the operation and
        // failed, rather than an unstubbed mock handing back null.
        verify(() => container.withPrivateKey<String>(any())).called(1);
      });
    });

    test('pubkey is set at construction', () {
      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockRpc,
      );

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('signEvent delegates to RPC when no local signer', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      when(() => mockRpc.signEvent(any())).thenAnswer((_) async => event);

      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockRpc,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockRpc.signEvent(any())).called(1);
    });

    test('signEvent prefers local signer when available', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      final mockLocal = _MockLocalKeySigner();
      when(() => mockLocal.signEvent(any())).thenAnswer((_) async => event);

      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockRpc,
        localSigner: mockLocal,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockLocal.signEvent(any())).called(1);
      verifyNever(() => mockRpc.signEvent(any()));
    });

    test(
      'signEvent falls back to RPC when local signing fails and the '
      'RPC signature is valid',
      () async {
        final event = Event(testPublicKey, EventKind.textNote, [], 'test')
          ..sign(testPrivateKey);
        final mockLocal = _MockLocalKeySigner();
        when(() => mockLocal.signEvent(any())).thenThrow(
          const LocalSignerOperationException(
            LocalSignerOperation.signEvent,
            SecureKeyException('Local key unavailable'),
          ),
        );
        when(() => mockRpc.signEvent(any())).thenAnswer((_) async => event);

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockRpc,
          localSigner: mockLocal,
        );

        final signed = await identity.signEvent(event);

        expect(signed, equals(event));
        verify(() => mockLocal.signEvent(any())).called(1);
        verify(() => mockRpc.signEvent(any())).called(1);
      },
    );

    test(
      'signEvent rejects an invalid RPC fallback signature (#5450) so a remote '
      'result cannot bypass verification when signsWithLocalKey is true',
      () async {
        // signsWithLocalKey is true (local signer present), so the signing
        // core skips its post-sign verify. The local sign fails and the RPC
        // fallback returns an UNSIGNED event — it must be rejected, not
        // returned, or the remote result would slip through unverified.
        final unsigned = Event(testPublicKey, EventKind.textNote, [], 'test');
        final mockLocal = _MockLocalKeySigner();
        when(() => mockLocal.signEvent(any())).thenThrow(
          const LocalSignerOperationException(
            LocalSignerOperation.signEvent,
            SecureKeyException('Local key unavailable'),
          ),
        );
        when(() => mockRpc.signEvent(any())).thenAnswer((_) async => unsigned);

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockRpc,
          localSigner: mockLocal,
        );

        expect(identity.signsWithLocalKey, isTrue);
        final signed = await identity.signEvent(unsigned);

        expect(signed, isNull);
        verify(() => mockLocal.signEvent(any())).called(1);
        verify(() => mockRpc.signEvent(any())).called(1);
      },
    );

    test(
      'signCanonicalPayload returns null when no local signer and rpcSigner '
      'is a generic NostrSigner (not KeycastRpc)',
      () async {
        // Generic NostrSigner doesn't implement signCanonicalPayload, so the
        // identity must short-circuit to null rather than try to call it.
        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockRpc,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, isNull);
      },
    );

    test(
      'signCanonicalPayload falls back to KeycastRpc when no local signer',
      () async {
        // OAuth-only path: no local key, RPC backend supports sign_canonical.
        final mockKeycastRpc = _MockKeycastRpc();
        when(
          () => mockKeycastRpc.signCanonicalPayload(any()),
        ).thenAnswer((_) async => 'remote_sig_hex');

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockKeycastRpc,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, equals('remote_sig_hex'));
        verify(() => mockKeycastRpc.signCanonicalPayload(any())).called(1);
      },
    );

    test(
      'signCanonicalPayload returns null when KeycastRpc has no backend '
      'support yet (graceful skip)',
      () async {
        // Backend doesn't expose sign_canonical → KeycastRpc returns null →
        // identity returns null → caller skips creator-binding. Publish is
        // not blocked.
        final mockKeycastRpc = _MockKeycastRpc();
        when(
          () => mockKeycastRpc.signCanonicalPayload(any()),
        ).thenAnswer((_) async => null);

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockKeycastRpc,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, isNull);
      },
    );

    test(
      'nip17UnwrapBatch returns null when rpcSigner is a generic NostrSigner',
      () async {
        // A generic NostrSigner is not a GiftWrapBatchUnwrapper, so the
        // identity short-circuits to null and the DM drain falls back to the
        // per-wrap path. See #5471.
        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockRpc,
        );

        expect(await identity.nip17UnwrapBatch(const []), isNull);
      },
    );

    test('nip17UnwrapBatch delegates to KeycastRpc', () async {
      final mockKeycastRpc = _MockKeycastRpc();
      final slots = [const GiftWrapUnwrapSlot.failure('decrypt_failed')];
      when(
        () => mockKeycastRpc.nip17UnwrapBatch(any()),
      ).thenAnswer((_) async => slots);

      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockKeycastRpc,
      );

      final result = await identity.nip17UnwrapBatch([
        {'id': 'wrap'},
      ]);

      expect(result, same(slots));
      verify(() => mockKeycastRpc.nip17UnwrapBatch(any())).called(1);
    });

    test(
      'nip17WrapBatch returns null when rpcSigner is a generic NostrSigner',
      () async {
        // A generic NostrSigner is not a GiftWrapBatchWrapper, so the identity
        // short-circuits to null and the DM send falls back to the per-wrap
        // signing path. See #7090.
        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockRpc,
        );

        expect(await identity.nip17WrapBatch(const {}, const []), isNull);
      },
    );

    test('nip17WrapBatch delegates to KeycastRpc', () async {
      final mockKeycastRpc = _MockKeycastRpc();
      final slots = [const GiftWrapSlot.failure('encrypt_failed')];
      when(
        () => mockKeycastRpc.nip17WrapBatch(any(), any()),
      ).thenAnswer((_) async => slots);

      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockKeycastRpc,
      );

      final rumor = {'id': 'rumor', 'kind': 14};
      const recipients = ['peer', 'self'];
      final result = await identity.nip17WrapBatch(rumor, recipients);

      expect(result, same(slots));
      // Both params must reach the RPC unchanged: the server parses exactly
      // [rumorObject, [recipientHex...]].
      verify(() => mockKeycastRpc.nip17WrapBatch(rumor, recipients)).called(1);
    });

    test(
      'signCanonicalPayload prefers local signer when available',
      () async {
        final mockLocal = _MockLocalKeySigner();
        final mockKeycastRpc = _MockKeycastRpc();
        when(
          () => mockLocal.signCanonicalPayload(any()),
        ).thenAnswer((_) async => 'local_sig_hex');

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockKeycastRpc,
          localSigner: mockLocal,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, equals('local_sig_hex'));
        verify(() => mockLocal.signCanonicalPayload(any())).called(1);
        // Local short-circuit means RPC must NOT be called for the perf
        // optimisation to hold.
        verifyNever(() => mockKeycastRpc.signCanonicalPayload(any()));
      },
    );

    test(
      'signCanonicalPayload falls back to KeycastRpc when local signing fails',
      () async {
        final mockLocal = _MockLocalKeySigner();
        final mockKeycastRpc = _MockKeycastRpc();
        when(() => mockLocal.signCanonicalPayload(any())).thenThrow(
          const LocalSignerOperationException(
            LocalSignerOperation.signCanonicalPayload,
            SecureKeyException('Local key unavailable'),
          ),
        );
        when(
          () => mockKeycastRpc.signCanonicalPayload(any()),
        ).thenAnswer((_) async => 'remote_sig_hex');

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockKeycastRpc,
          localSigner: mockLocal,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, equals('remote_sig_hex'));
        verify(() => mockLocal.signCanonicalPayload(any())).called(1);
        verify(() => mockKeycastRpc.signCanonicalPayload(any())).called(1);
      },
    );

    test('does not hide unexpected local signer errors behind RPC', () async {
      final mockLocal = _MockLocalKeySigner();
      when(
        () => mockLocal.nip44Encrypt(any(), any()),
      ).thenThrow(StateError('broken signer invariant'));

      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockRpc,
        localSigner: mockLocal,
      );

      await expectLater(
        identity.nip44Encrypt(testPublicKey, 'hello'),
        throwsStateError,
      );
      verifyNever(() => mockRpc.nip44Encrypt(any(), any()));
    });
  });

  group(BunkerNostrIdentity, () {
    late _MockNostrSigner mockRemote;

    setUp(() {
      mockRemote = _MockNostrSigner();
    });

    test('pubkey is set at construction', () {
      final identity = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockRemote,
      );

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('signEvent delegates to remote signer', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      when(() => mockRemote.signEvent(any())).thenAnswer((_) async => event);

      final identity = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockRemote,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockRemote.signEvent(any())).called(1);
    });

    test('signCanonicalPayload returns null', () async {
      final identity = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockRemote,
      );

      final result = await identity.signCanonicalPayload(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isNull);
    });
  });

  group(AmberNostrIdentity, () {
    late _MockNostrSigner mockAmber;

    setUp(() {
      mockAmber = _MockNostrSigner();
    });

    test('pubkey is set at construction', () {
      final identity = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockAmber,
      );

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('signEvent delegates to amber signer', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      when(() => mockAmber.signEvent(any())).thenAnswer((_) async => event);

      final identity = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockAmber,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockAmber.signEvent(any())).called(1);
    });

    test('signCanonicalPayload returns null', () async {
      final identity = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockAmber,
      );

      final result = await identity.signCanonicalPayload(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isNull);
    });
  });

  group(Nip07NostrIdentity, () {
    late _MockNostrSigner mockNip07Signer;

    setUp(() {
      mockNip07Signer = _MockNostrSigner();
    });

    test('pubkey is set at construction', () {
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('signEvent delegates to nip07 signer', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      when(
        () => mockNip07Signer.signEvent(any()),
      ).thenAnswer((_) async => event);

      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockNip07Signer.signEvent(any())).called(1);
    });

    test('signCanonicalPayload returns null', () async {
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.signCanonicalPayload(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isNull);
    });

    test('encrypt delegates to nip07 signer', () async {
      when(
        () => mockNip07Signer.encrypt(any(), any()),
      ).thenAnswer((_) async => 'cipher');
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.encrypt(testPublicKey, 'plaintext');

      expect(result, equals('cipher'));
      verify(
        () => mockNip07Signer.encrypt(testPublicKey, 'plaintext'),
      ).called(1);
    });

    test('decrypt delegates to nip07 signer', () async {
      when(
        () => mockNip07Signer.decrypt(any(), any()),
      ).thenAnswer((_) async => 'plaintext');
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.decrypt(testPublicKey, 'cipher');

      expect(result, equals('plaintext'));
    });

    test('nip44Encrypt delegates to nip07 signer', () async {
      when(
        () => mockNip07Signer.nip44Encrypt(any(), any()),
      ).thenAnswer((_) async => 'nip44-cipher');
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.nip44Encrypt(testPublicKey, 'plaintext');

      expect(result, equals('nip44-cipher'));
    });

    test('nip44Decrypt delegates to nip07 signer', () async {
      when(
        () => mockNip07Signer.nip44Decrypt(any(), any()),
      ).thenAnswer((_) async => 'plaintext');
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.nip44Decrypt(testPublicKey, 'cipher');

      expect(result, equals('plaintext'));
    });

    test('npub encodes pubkey to bech32', () {
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      expect(identity.npub, equals(NostrKeyUtils.encodePubKey(testPublicKey)));
    });
  });

  group('structural desync prevention', () {
    test('pubkey used in event always matches signing key '
        'because both come from the same identity instance', () async {
      // This test proves that the PRIMARY-slot desync bug (#2233) is
      // structurally impossible with NostrIdentity: the pubkey embedded
      // in the event and the key used for signing both originate from
      // the same identity instance.
      final mockKeyContainer = _MockSecureKeyContainer();
      when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
      when(() => mockKeyContainer.isDisposed).thenReturn(false);
      when(() => mockKeyContainer.withPrivateKey<Event>(any())).thenAnswer((
        invocation,
      ) {
        final callback =
            invocation.positionalArguments[0] as Event Function(String);
        return callback(testPrivateKey);
      });

      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      // Simulate what createAndSignEvent does: use identity.pubkey for
      // the event, then identity.signEvent to sign it.
      final event = Event(
        identity.pubkey,
        EventKind.textNote,
        [],
        'test content',
      );
      final signed = await identity.signEvent(event);

      // The signed event's pubkey matches the identity's pubkey — they
      // cannot disagree because they come from the same object.
      expect(signed, isNotNull);
      expect(signed!.pubkey, equals(identity.pubkey));
      expect(signed.isSigned, isTrue);
    });

    test('different identity types all bind pubkey at construction time', () {
      // Each variant stores pubkey as a final field — it cannot change
      // after construction, so there is no window for desync.
      final mockSigner = _MockNostrSigner();
      final mockKeyContainer = _MockSecureKeyContainer();
      when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
      when(() => mockKeyContainer.isDisposed).thenReturn(false);

      final local = LocalNostrIdentity(keyContainer: mockKeyContainer);
      final keycast = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockSigner,
      );
      final bunker = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockSigner,
      );
      final amber = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockSigner,
      );
      final nip07 = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockSigner,
      );

      // All five variants expose the same pubkey — it's a final field,
      // not a getter that reads from a mutable slot.
      for (final identity in <NostrIdentity>[
        local,
        keycast,
        bunker,
        amber,
        nip07,
      ]) {
        expect(identity.pubkey, equals(testPublicKey));
      }
    });
  });

  group('signsRemotelyNonInteractive', () {
    late _MockNostrSigner mockSigner;

    setUp(() {
      mockSigner = _MockNostrSigner();
    });

    test('LocalNostrIdentity signs in-process — false', () {
      final mockKeyContainer = _MockSecureKeyContainer();
      when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
      when(() => mockKeyContainer.isDisposed).thenReturn(false);

      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      expect(identity.signsRemotelyNonInteractive, isFalse);
    });

    test('KeycastNostrIdentity without a local signer (OAuth-only) — true', () {
      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockSigner,
      );

      expect(identity.signsRemotelyNonInteractive, isTrue);
    });

    test('KeycastNostrIdentity with a local signer signs locally — false', () {
      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockSigner,
        localSigner: _MockLocalKeySigner(),
      );

      expect(identity.signsRemotelyNonInteractive, isFalse);
    });

    test('BunkerNostrIdentity is interactive (human-paced) — false', () {
      final identity = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockSigner,
      );

      expect(identity.signsRemotelyNonInteractive, isFalse);
    });

    test('AmberNostrIdentity is interactive (human-paced) — false', () {
      final identity = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockSigner,
      );

      expect(identity.signsRemotelyNonInteractive, isFalse);
    });

    test('Nip07NostrIdentity is interactive (human-paced) — false', () {
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockSigner,
      );

      expect(identity.signsRemotelyNonInteractive, isFalse);
    });
  });

  group('signsWithLocalKey', () {
    late _MockNostrSigner mockSigner;

    setUp(() {
      mockSigner = _MockNostrSigner();
    });

    test('LocalNostrIdentity signs in-process — true', () {
      final mockKeyContainer = _MockSecureKeyContainer();
      when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
      when(() => mockKeyContainer.isDisposed).thenReturn(false);

      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      expect(identity.signsWithLocalKey, isTrue);
    });

    test('KeycastNostrIdentity with a local signer — true', () {
      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockSigner,
        localSigner: _MockLocalKeySigner(),
      );

      expect(identity.signsWithLocalKey, isTrue);
    });

    test(
      'KeycastNostrIdentity without a local signer (OAuth-only) — false',
      () {
        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockSigner,
        );

        expect(identity.signsWithLocalKey, isFalse);
      },
    );

    test('BunkerNostrIdentity signs remotely — false', () {
      final identity = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockSigner,
      );

      expect(identity.signsWithLocalKey, isFalse);
    });

    test('AmberNostrIdentity signs remotely — false', () {
      final identity = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockSigner,
      );

      expect(identity.signsWithLocalKey, isFalse);
    });

    test('Nip07NostrIdentity signs remotely — false', () {
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockSigner,
      );

      expect(identity.signsWithLocalKey, isFalse);
    });
  });

  group(PubkeyOnlyNostrIdentity, () {
    late PubkeyOnlyNostrIdentity identity;

    setUp(() {
      identity = PubkeyOnlyNostrIdentity(pubkey: testPublicKey);
    });

    tearDown(() async {
      await LogCaptureService().clearAllLogs();
    });

    test('still reports the known public key', () async {
      expect(await identity.getPublicKey(), equals(testPublicKey));
    });

    // This identity is live — it is built on an offline Divine-OAuth restore
    // and becomes the app-wide NostrClient's signer. Because it reports a real
    // pubkey, `hasKeys` and `isReadyForActiveClient` are both true for it, so
    // it reaches signer call sites that catch only `Exception`, or do not
    // catch locally at all. These five must therefore return null rather than
    // throw; the warning log is what makes the skipped gate visible.
    test('signEvent returns null rather than throwing', () async {
      final event = Event(testPublicKey, 1, const <List<String>>[], 'hi');

      expect(await identity.signEvent(event), isNull);
    });

    test('signEvent logs the skipped signing gate', () async {
      final event = Event(testPublicKey, 1, const <List<String>>[], 'hi');

      await LogCaptureService().clearAllLogs();

      expect(await identity.signEvent(event), isNull);

      final logs = LogCaptureService().getRecentLogs();
      expect(
        logs.any(
          (entry) =>
              entry.level == LogLevel.warning &&
              entry.category == LogCategory.auth &&
              entry.name == 'PubkeyOnlyNostrIdentity' &&
              entry.message.contains('No signer: cannot sign an event') &&
              entry.message.contains(testPublicKey),
        ),
        isTrue,
      );
    });

    test('encrypt returns null rather than throwing', () async {
      expect(await identity.encrypt(testPublicKey, 'plaintext'), isNull);
    });

    test('decrypt returns null rather than throwing', () async {
      expect(await identity.decrypt(testPublicKey, 'ciphertext'), isNull);
    });

    test('nip44Encrypt returns null rather than throwing', () async {
      expect(await identity.nip44Encrypt(testPublicKey, 'plaintext'), isNull);
    });

    test('nip44Decrypt returns null rather than throwing', () async {
      expect(await identity.nip44Decrypt(testPublicKey, 'ciphertext'), isNull);
    });

    // Regression guard: signCanonicalPayload's null means "capability
    // unsupported" (same as Bunker/Amber/NIP-07, whose protocols have no such
    // verb), not "skipped gate" — so it must stay null and stay unlogged.
    test(
      'signCanonicalPayload returns null without logging',
      () async {
        await LogCaptureService().clearAllLogs();

        expect(
          await identity.signCanonicalPayload(Uint8List.fromList([1, 2, 3])),
          isNull,
        );
        expect(LogCaptureService().getRecentLogs(), isEmpty);
      },
    );

    test('getRelays returns null without logging', () async {
      await LogCaptureService().clearAllLogs();

      expect(await identity.getRelays(), isNull);
      expect(LogCaptureService().getRecentLogs(), isEmpty);
    });
  });
}
