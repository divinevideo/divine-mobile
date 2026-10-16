// ABOUTME: Characterization tests for SignerSecureStore — the client-tier
// ABOUTME: collaborator extracted from AuthService (#4741, PR4).
//
// The store owns secure-storage persistence for external-signer credentials
// (NIP-46 bunker, NIP-55 Amber, Divine/Keycast OAuth) plus the per-account
// archive used when switching accounts. These tests run it against the shared
// channel-backed in-memory secure storage so the KeycastSession static calls it
// makes internally hit the same backing map.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show NostrRemoteSignerInfo;
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/services/auth/signer_secure_store.dart';

import '../support/auth_service_test_harness.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkeyB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _signerPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

NostrRemoteSignerInfo _bunkerInfo({String? userPubkey}) =>
    NostrRemoteSignerInfo(
      remoteSignerPubkey: _signerPubkey,
      relays: const ['wss://relay.example.com'],
      optionalSecret: 'secret123',
      nsec: 'nsec1examplevalueforroundtrip',
      userPubkey: userPubkey,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(SignerSecureStore, () {
    late AuthServiceChannelMocks mocks;
    late SignerSecureStore store;

    setUp(() {
      mocks = AuthServiceChannelMocks.install();
      store = SignerSecureStore(const FlutterSecureStorage());
    });

    tearDown(AuthServiceChannelMocks.remove);

    group('bunker (NIP-46)', () {
      test(
        'saveBunker then loadBunker round-trips signer pubkey and relays',
        () async {
          await store.saveBunker(_bunkerInfo(userPubkey: _pubkeyA));

          final loaded = await store.loadBunker();

          expect(loaded, isNotNull);
          expect(loaded!.remoteSignerPubkey, equals(_signerPubkey));
          expect(loaded.relays, equals(const ['wss://relay.example.com']));
          expect(loaded.userPubkey, equals(_pubkeyA));
        },
      );

      test('loadBunker returns null when nothing is stored', () async {
        expect(await store.loadBunker(), isNull);
      });

      test('clearBunker removes the stored bunker info', () async {
        await store.saveBunker(_bunkerInfo());
        expect(mocks.secureStorage['bunker_info'], isNotNull);

        await store.clearBunker();

        expect(mocks.secureStorage.containsKey('bunker_info'), isFalse);
        expect(await store.loadBunker(), isNull);
      });

      test('null storage no-ops on save/load/clear', () async {
        final nullStore = SignerSecureStore(null);

        await nullStore.saveBunker(_bunkerInfo());
        expect(await nullStore.loadBunker(), isNull);
        await nullStore.clearBunker();

        expect(mocks.secureStorage, isEmpty);
      });

      test('clearBunker swallows a storage delete failure', () async {
        // AuthService calls _clearBunkerInfo() unguarded on both the normal
        // and the post-key-deletion sign-out paths (#3588). Those callers rely
        // on this method absorbing and logging a keychain failure itself; if it
        // ever started throwing, a destructive sign-out would abort partway and
        // strand the session authenticated-in-memory with no keys on disk.
        final throwingStorage = _MockSecureStorage();
        when(
          () => throwingStorage.delete(key: any(named: 'key')),
        ).thenThrow(Exception('keychain unavailable'));

        await expectLater(
          SignerSecureStore(throwingStorage).clearBunker(),
          completes,
        );
      });
    });

    group('amber (NIP-55)', () {
      test('saveAmber then loadAmber round-trips pubkey and package', () async {
        await store.saveAmber(_pubkeyA, 'com.example.signer');

        final loaded = await store.loadAmber();

        expect(loaded, isNotNull);
        expect(loaded!.pubkey, equals(_pubkeyA));
        expect(loaded.package, equals('com.example.signer'));
      });

      test('saveAmber with null package stores only the pubkey', () async {
        await store.saveAmber(_pubkeyA, null);

        final loaded = await store.loadAmber();

        expect(loaded!.pubkey, equals(_pubkeyA));
        expect(loaded.package, isNull);
      });

      test('loadAmber returns null when nothing is stored', () async {
        expect(await store.loadAmber(), isNull);
      });

      test('clearAmber removes pubkey and package', () async {
        await store.saveAmber(_pubkeyA, 'com.example.signer');

        await store.clearAmber();

        expect(mocks.secureStorage.containsKey('amber_pubkey'), isFalse);
        expect(mocks.secureStorage.containsKey('amber_package'), isFalse);
        expect(await store.loadAmber(), isNull);
      });

      test('null storage no-ops on save/load/clear', () async {
        final nullStore = SignerSecureStore(null);

        await nullStore.saveAmber(_pubkeyA, 'com.example.signer');
        expect(await nullStore.loadAmber(), isNull);
        await nullStore.clearAmber();

        expect(mocks.secureStorage, isEmpty);
      });

      test('clearAmber swallows a storage delete failure', () async {
        // Same contract as clearBunker: AuthService clears Amber info
        // unguarded on the sign-out paths (#3588), so a keychain failure must
        // be absorbed and logged here rather than aborting the sign-out.
        final throwingStorage = _MockSecureStorage();
        when(
          () => throwingStorage.delete(key: any(named: 'key')),
        ).thenThrow(Exception('keychain unavailable'));

        await expectLater(
          SignerSecureStore(throwingStorage).clearAmber(),
          completes,
        );
      });
    });

    group('clearKeycastSessionAndTokens', () {
      test('deletes the session, refresh token, and auth handle', () async {
        mocks.secureStorage['keycast_session'] = '{"bunker_url":"bunker://x"}';
        mocks.secureStorage['keycast_refresh_token'] = 'refresh-tok';
        mocks.secureStorage['keycast_auth_handle'] = 'handle';

        await store.clearKeycastSessionAndTokens();

        expect(mocks.secureStorage.containsKey('keycast_session'), isFalse);
        expect(
          mocks.secureStorage.containsKey('keycast_refresh_token'),
          isFalse,
        );
        expect(mocks.secureStorage.containsKey('keycast_auth_handle'), isFalse);
      });

      test('completes without throwing when nothing is stored', () async {
        await expectLater(store.clearKeycastSessionAndTokens(), completes);
      });

      test(
        'rethrows the first delete error after attempting all deletes',
        () async {
          final throwingStorage = _MockSecureStorage();
          when(
            () => throwingStorage.delete(key: any(named: 'key')),
          ).thenAnswer((_) async {});
          when(
            () => throwingStorage.delete(key: 'keycast_session'),
          ).thenThrow(Exception('boom'));
          final throwingStore = SignerSecureStore(throwingStorage);

          await expectLater(
            throwingStore.clearKeycastSessionAndTokens(),
            throwsA(isA<Exception>()),
          );
          // The standalone token/handle deletes still ran despite the failure.
          verify(
            () => throwingStorage.delete(key: 'keycast_refresh_token'),
          ).called(1);
          verify(
            () => throwingStorage.delete(key: 'keycast_auth_handle'),
          ).called(1);
        },
      );
    });

    group('archive', () {
      test('archives active amber info under per-account keys', () async {
        await store.saveAmber(_pubkeyA, 'com.example.signer');

        await store.archive(_pubkeyA);

        expect(
          mocks.secureStorage['amber_pubkey_$_pubkeyA'],
          equals(_pubkeyA),
        );
        expect(
          mocks.secureStorage['amber_package_$_pubkeyA'],
          equals('com.example.signer'),
        );
      });

      test('archives active bunker info under per-account keys', () async {
        await store.saveBunker(_bunkerInfo());
        final activeBunker = mocks.secureStorage['bunker_info'];

        await store.archive(_pubkeyA);

        expect(
          mocks.secureStorage['bunker_info_$_pubkeyA'],
          equals(activeBunker),
        );
      });

      test(
        'archives OAuth session when its userPubkey matches the account',
        () async {
          const session = KeycastSession(
            bunkerUrl: 'bunker://x',
            userPubkey: _pubkeyA,
          );
          await session.save(const FlutterSecureStorage());

          await store.archive(_pubkeyA);

          expect(
            mocks.secureStorage.containsKey('keycast_session_$_pubkeyA'),
            isTrue,
          );
        },
      );

      test('skips OAuth archive when the session pubkey mismatches', () async {
        const session = KeycastSession(
          bunkerUrl: 'bunker://x',
          userPubkey: _pubkeyB,
        );
        await session.save(const FlutterSecureStorage());

        await store.archive(_pubkeyA);

        expect(
          mocks.secureStorage.containsKey('keycast_session_$_pubkeyA'),
          isFalse,
        );
      });

      test(
        'skips OAuth archive when the session pubkey is null (legacy)',
        () async {
          const session = KeycastSession(bunkerUrl: 'bunker://x');
          await session.save(const FlutterSecureStorage());

          await store.archive(_pubkeyA);

          expect(
            mocks.secureStorage.containsKey('keycast_session_$_pubkeyA'),
            isFalse,
          );
        },
      );

      test('null storage no-ops', () async {
        await SignerSecureStore(null).archive(_pubkeyA);
        expect(mocks.secureStorage, isEmpty);
      });

      group('when the archive write fails', () {
        late SignerSecureStore throwingStore;

        setUp(() {
          final throwingStorage = _MockSecureStorage();
          when(
            () => throwingStorage.read(key: any(named: 'key')),
          ).thenAnswer((_) async => null);
          when(
            () => throwingStorage.read(key: 'bunker_info'),
          ).thenAnswer((_) async => 'bunker://a');
          when(
            () => throwingStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenThrow(Exception('keychain unavailable'));
          throwingStore = SignerSecureStore(throwingStorage);
        });

        test('rethrows for a caller that depends on it landing', () async {
          // The in-place account switch does: the incoming sign-in overwrites
          // the shared slots this copies from, so carrying on past a failed
          // write destroys the leaving account's session for a log line.
          await expectLater(
            throwingStore.archive(_pubkeyA, throwOnFailure: true),
            throwsA(isA<Exception>()),
          );
        });

        test('still swallows it on the sign-out path', () async {
          // Sign-out keeps the default: that session is going away either way.
          await expectLater(throwingStore.archive(_pubkeyA), completes);
        });
      });
    });

    group('restoreActiveKeys', () {
      test('restores archived amber to the active keys', () async {
        mocks.secureStorage['amber_pubkey_$_pubkeyA'] = _pubkeyA;
        mocks.secureStorage['amber_package_$_pubkeyA'] = 'com.example.signer';

        await store.restoreActiveKeys(_pubkeyA, AuthenticationSource.amber);

        expect(mocks.secureStorage['amber_pubkey'], equals(_pubkeyA));
        expect(
          mocks.secureStorage['amber_package'],
          equals('com.example.signer'),
        );
      });

      test('restores archived bunker to the active key', () async {
        await store.saveBunker(_bunkerInfo());
        final archived = mocks.secureStorage['bunker_info']!;
        mocks.secureStorage['bunker_info_$_pubkeyA'] = archived;
        await store.clearBunker();

        await store.restoreActiveKeys(_pubkeyA, AuthenticationSource.bunker);

        expect(mocks.secureStorage['bunker_info'], equals(archived));
      });

      test(
        'restores a matching OAuth session and its standalone tokens',
        () async {
          const session = KeycastSession(
            bunkerUrl: 'bunker://x',
            userPubkey: _pubkeyA,
            refreshToken: 'refresh-tok',
            authorizationHandle: 'handle',
          );
          mocks.secureStorage['keycast_session_$_pubkeyA'] = jsonEncode(
            session.toJson(),
          );

          await store.restoreActiveKeys(
            _pubkeyA,
            AuthenticationSource.divineOAuth,
          );

          final restored = await KeycastSession.load(
            const FlutterSecureStorage(),
          );
          expect(restored?.userPubkey, equals(_pubkeyA));
          expect(
            mocks.secureStorage['keycast_refresh_token'],
            equals('refresh-tok'),
          );
          expect(mocks.secureStorage['keycast_auth_handle'], equals('handle'));
        },
      );

      test(
        'deletes a corrupt OAuth archive (null userPubkey) on restore',
        () async {
          const session = KeycastSession(bunkerUrl: 'bunker://x');
          mocks.secureStorage['keycast_session_$_pubkeyA'] = jsonEncode(
            session.toJson(),
          );

          await store.restoreActiveKeys(
            _pubkeyA,
            AuthenticationSource.divineOAuth,
          );

          expect(
            mocks.secureStorage.containsKey('keycast_session_$_pubkeyA'),
            isFalse,
          );
          expect(
            await KeycastSession.load(const FlutterSecureStorage()),
            isNull,
          );
        },
      );

      test('local key-based sources clear stale global signer keys', () async {
        await store.saveBunker(_bunkerInfo());
        await store.saveAmber(_pubkeyA, 'com.example.signer');
        await const KeycastSession(
          bunkerUrl: 'bunker://x',
        ).save(const FlutterSecureStorage());

        await store.restoreActiveKeys(_pubkeyA, AuthenticationSource.nip07);

        expect(mocks.secureStorage.containsKey('bunker_info'), isFalse);
        expect(mocks.secureStorage.containsKey('amber_pubkey'), isFalse);
        expect(mocks.secureStorage.containsKey('keycast_session'), isFalse);
      });

      test('null storage no-ops', () async {
        await SignerSecureStore(
          null,
        ).restoreActiveKeys(_pubkeyA, AuthenticationSource.amber);
        expect(mocks.secureStorage, isEmpty);
      });
    });

    group('clearArchive', () {
      test('deletes all per-account archived signer keys', () async {
        mocks.secureStorage['amber_pubkey_$_pubkeyA'] = _pubkeyA;
        mocks.secureStorage['amber_package_$_pubkeyA'] = 'com.example.signer';
        mocks.secureStorage['bunker_info_$_pubkeyA'] = 'bunker://x';
        mocks.secureStorage['keycast_session_$_pubkeyA'] = '{}';

        await store.clearArchive(_pubkeyA);

        expect(
          mocks.secureStorage.containsKey('amber_pubkey_$_pubkeyA'),
          isFalse,
        );
        expect(
          mocks.secureStorage.containsKey('amber_package_$_pubkeyA'),
          isFalse,
        );
        expect(
          mocks.secureStorage.containsKey('bunker_info_$_pubkeyA'),
          isFalse,
        );
        expect(
          mocks.secureStorage.containsKey('keycast_session_$_pubkeyA'),
          isFalse,
        );
      });

      test('null storage no-ops', () async {
        await SignerSecureStore(null).clearArchive(_pubkeyA);
        expect(mocks.secureStorage, isEmpty);
      });
    });

    group('hasArchive', () {
      test('amber: true when archived, false when absent', () async {
        expect(
          await store.hasArchive(_pubkeyA, AuthenticationSource.amber),
          isFalse,
        );

        mocks.secureStorage['amber_pubkey_$_pubkeyA'] = _pubkeyA;

        expect(
          await store.hasArchive(_pubkeyA, AuthenticationSource.amber),
          isTrue,
        );
      });

      test('bunker: true when archived, false when absent', () async {
        expect(
          await store.hasArchive(_pubkeyA, AuthenticationSource.bunker),
          isFalse,
        );

        mocks.secureStorage['bunker_info_$_pubkeyA'] = 'bunker://x';

        expect(
          await store.hasArchive(_pubkeyA, AuthenticationSource.bunker),
          isTrue,
        );
      });

      test(
        'divineOAuth: true only when the archived session pubkey matches',
        () async {
          const matching = KeycastSession(
            bunkerUrl: 'bunker://x',
            userPubkey: _pubkeyA,
          );
          mocks.secureStorage['keycast_session_$_pubkeyA'] = jsonEncode(
            matching.toJson(),
          );

          expect(
            await store.hasArchive(_pubkeyA, AuthenticationSource.divineOAuth),
            isTrue,
          );

          const mismatched = KeycastSession(
            bunkerUrl: 'bunker://x',
            userPubkey: _pubkeyB,
          );
          mocks.secureStorage['keycast_session_$_pubkeyA'] = jsonEncode(
            mismatched.toJson(),
          );

          expect(
            await store.hasArchive(_pubkeyA, AuthenticationSource.divineOAuth),
            isFalse,
          );
        },
      );

      test('local key-based sources always return false', () async {
        expect(
          await store.hasArchive(_pubkeyA, AuthenticationSource.nip07),
          isFalse,
        );
        expect(
          await store.hasArchive(_pubkeyA, AuthenticationSource.importedKeys),
          isFalse,
        );
        expect(
          await store.hasArchive(_pubkeyA, AuthenticationSource.none),
          isFalse,
        );
        expect(
          await store.hasArchive(_pubkeyA, AuthenticationSource.automatic),
          isFalse,
        );
      });

      test('null storage returns false', () async {
        expect(
          await SignerSecureStore(
            null,
          ).hasArchive(_pubkeyA, AuthenticationSource.amber),
          isFalse,
        );
      });
    });
  });
}
