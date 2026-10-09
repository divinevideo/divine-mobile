// ABOUTME: Owner-scoped signer removal verifies raw credentials and deletion readback.
// ABOUTME: Retains foreign or unreadable evidence and owner markers for safe retry.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show NostrRemoteSignerInfo;
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

  group('Owner-scoped signer account removal', () {
    late AuthServiceChannelMocks mocks;
    late SignerSecureStore store;

    setUp(() {
      mocks = AuthServiceChannelMocks.install();
      store = SignerSecureStore(const FlutterSecureStorage());
    });

    tearDown(AuthServiceChannelMocks.remove);

    group('clearAccount', () {
      test('deletes only credentials owned by the named account', () async {
        await store.saveAmber(_pubkeyB, 'com.example.signer');
        mocks.secureStorage['amber_pubkey_$_pubkeyA'] = _pubkeyA;
        mocks.secureStorage['bunker_info_$_pubkeyA'] = _bunkerInfo(
          userPubkey: _pubkeyA,
        ).toString();

        await store.clearAccount(_pubkeyA);

        expect(mocks.secureStorage['amber_pubkey'], _pubkeyB);
        expect(
          mocks.secureStorage.containsKey('amber_pubkey_$_pubkeyA'),
          isFalse,
        );
        expect(
          mocks.secureStorage.containsKey('bunker_info_$_pubkeyA'),
          isFalse,
        );
      });

      test('propagates secure-storage deletion failures', () async {
        final throwingStorage = _MockSecureStorage();
        when(
          () => throwingStorage.read(key: any(named: 'key')),
        ).thenAnswer(
          (invocation) async =>
              invocation.namedArguments[#key] == 'amber_pubkey'
              ? _pubkeyA
              : null,
        );
        when(
          () => throwingStorage.delete(key: any(named: 'key')),
        ).thenThrow(Exception('keychain unavailable'));

        await expectLater(
          SignerSecureStore(throwingStorage).clearAccount(_pubkeyA),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Account signer removal is incomplete',
            ),
          ),
        );
      });

      test(
        'retains the Amber owner marker and completes on retry',
        () async {
          final throwingStorage = _MockSecureStorage();
          final values = <String, String>{
            'amber_pubkey': _pubkeyA,
            'amber_package': 'com.example.signer',
          };
          var packageDeleteAttempts = 0;
          when(
            () => throwingStorage.read(key: any(named: 'key')),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key]! as String;
            return values[key];
          });
          when(
            () => throwingStorage.delete(key: any(named: 'key')),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key]! as String;
            if (key == 'amber_package' && packageDeleteAttempts++ == 0) {
              throw Exception('keychain unavailable');
            }
            values.remove(key);
          });

          await expectLater(
            SignerSecureStore(throwingStorage).clearAccount(_pubkeyA),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'Account signer removal is incomplete',
              ),
            ),
          );
          expect(values['amber_pubkey'], _pubkeyA);

          await SignerSecureStore(throwingStorage).clearAccount(_pubkeyA);
          expect(values.containsKey('amber_pubkey'), isFalse);
          expect(values.containsKey('amber_package'), isFalse);
        },
      );

      test('retains the Keycast session and completes on retry', () async {
        final throwingStorage = _MockSecureStorage();
        final values = <String, String>{
          'keycast_session': jsonEncode(
            const KeycastSession(
              bunkerUrl: 'bunker://x',
              userPubkey: _pubkeyA,
              refreshToken: 'refresh-token',
              authorizationHandle: 'auth-handle',
            ).toJson(),
          ),
          'keycast_refresh_token': 'refresh-token',
          'keycast_auth_handle': 'auth-handle',
        };
        var authHandleDeleteAttempts = 0;
        when(
          () => throwingStorage.read(key: any(named: 'key')),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key]! as String;
          return values[key];
        });
        when(
          () => throwingStorage.delete(key: any(named: 'key')),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key]! as String;
          if (key == 'keycast_auth_handle' && authHandleDeleteAttempts++ == 0) {
            throw Exception('keychain unavailable');
          }
          values.remove(key);
        });

        await expectLater(
          SignerSecureStore(throwingStorage).clearAccount(_pubkeyA),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Account signer removal is incomplete',
            ),
          ),
        );
        expect(values.containsKey('keycast_session'), isTrue);

        await SignerSecureStore(throwingStorage).clearAccount(_pubkeyA);
        expect(values.containsKey('keycast_session'), isFalse);
        expect(values.containsKey('keycast_auth_handle'), isFalse);
        expect(values.containsKey('keycast_refresh_token'), isFalse);
      });
      for (final kind in ['amber', 'bunker', 'oauth']) {
        for (final defect in ['foreign', 'unreadable']) {
          test('$kind archive $defect is preserved byte-for-byte', () async {
            final key = switch (kind) {
              'amber' => 'amber_pubkey_$_pubkeyA',
              'bunker' => 'bunker_info_$_pubkeyA',
              _ => 'keycast_session_$_pubkeyA',
            };
            final raw = defect == 'unreadable'
                ? '{unreadable'
                : switch (kind) {
                    'amber' => _pubkeyB,
                    'bunker' => _bunkerInfo(userPubkey: _pubkeyB).toString(),
                    _ => jsonEncode(
                      const KeycastSession(
                        bunkerUrl: 'https://keycast.example.com',
                        userPubkey: _pubkeyB,
                      ).toJson(),
                    ),
                  };
            mocks.secureStorage[key] = raw;
            await store.saveAmber(_pubkeyB, 'com.example.bob');
            final before = Map<String, String>.of(mocks.secureStorage);

            await expectLater(store.clearAccount(_pubkeyA), throwsStateError);

            expect(mocks.secureStorage, before);
          });
        }
      }

      test(
        'unreadable globals and orphan tokens never imply absence',
        () async {
          for (final values in [
            {'keycast_session': '{damaged'},
            {'keycast_refresh_token': 'unattributed-refresh'},
            {'amber_package': 'unattributed.package'},
            {'bunker_info': 'bunker://unattributed'},
          ]) {
            mocks.secureStorage.clear();
            mocks.secureStorage.addAll(values);
            await expectLater(store.clearAccount(_pubkeyA), throwsStateError);
            expect(mocks.secureStorage, values);
          }
        },
      );

      test(
        'matching foreign global OAuth tokens remain byte-for-byte',
        () async {
          const foreign = KeycastSession(
            bunkerUrl: 'https://keycast.example.com',
            userPubkey: _pubkeyB,
            refreshToken: 'bob-refresh',
            authorizationHandle: 'bob-handle',
          );
          mocks.secureStorage.addAll({
            'keycast_session': jsonEncode(foreign.toJson()),
            'keycast_refresh_token': foreign.refreshToken!,
            'keycast_auth_handle': foreign.authorizationHandle!,
            'amber_pubkey': _pubkeyB,
            'amber_package': 'com.example.bob',
            'bunker_info': _bunkerInfo(userPubkey: _pubkeyB).toString(),
          });
          final before = Map<String, String>.of(mocks.secureStorage);
          await store.clearAccount(_pubkeyA);
          expect(mocks.secureStorage, before);
        },
      );

      test(
        'known owned copies still removed while uncertain archive remains',
        () async {
          mocks.secureStorage.addAll({
            'amber_pubkey': _pubkeyA,
            'amber_package': 'com.example.alice',
            'amber_pubkey_$_pubkeyA': _pubkeyA,
            'bunker_info_$_pubkeyA': '{damaged',
          });
          await expectLater(store.clearAccount(_pubkeyA), throwsStateError);
          expect(mocks.secureStorage, {'bunker_info_$_pubkeyA': '{damaged'});
        },
      );

      for (final slot in [
        'amber_package',
        'keycast_refresh_token',
        'keycast_session_$_pubkeyA',
      ]) {
        test(
          '$slot silent delete acknowledgement keeps removal incomplete',
          () async {
            final silent = _MockSecureStorage();
            final values = <String, String>{
              'amber_pubkey': _pubkeyA,
              'amber_package': 'com.example.alice',
              'keycast_session': jsonEncode(
                const KeycastSession(
                  bunkerUrl: 'https://keycast.example.com',
                  userPubkey: _pubkeyA,
                  refreshToken: 'alice-refresh',
                ).toJson(),
              ),
              'keycast_refresh_token': 'alice-refresh',
              'keycast_session_$_pubkeyA': jsonEncode(
                const KeycastSession(
                  bunkerUrl: 'https://keycast.example.com',
                  userPubkey: _pubkeyA,
                ).toJson(),
              ),
            };
            when(() => silent.read(key: any(named: 'key')))
                .thenAnswer((call) async => values[call.namedArguments[#key]]);
            when(() => silent.delete(key: any(named: 'key')))
                .thenAnswer((call) async {
                  final key = call.namedArguments[#key] as String;
                  if (key != slot) values.remove(key);
                });

            await expectLater(
              SignerSecureStore(silent).clearAccount(_pubkeyA),
              throwsStateError,
            );

            expect(values.containsKey(slot), isTrue);
            if (slot == 'amber_package') {
              expect(values['amber_pubkey'], _pubkeyA);
            }
            if (slot == 'keycast_refresh_token') {
              expect(values.containsKey('keycast_session'), isTrue);
            }
          },
        );
      }

      test('nullable injected store reads actual native bytes', () async {
        mocks.secureStorage['amber_pubkey_$_pubkeyA'] = '{damaged';
        await expectLater(
          SignerSecureStore(null).clearAccount(_pubkeyA),
          throwsStateError,
        );
        expect(mocks.secureStorage['amber_pubkey_$_pubkeyA'], '{damaged');
      });
    });
  });
}
