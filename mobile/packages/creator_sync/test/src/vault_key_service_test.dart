// ABOUTME: Tests for VaultKeyService generate/wrap/unwrap lifecycle.
// ABOUTME: Pins the never-fork invariant when the relay is unreachable.

import 'dart:convert';

import 'package:creator_sync/creator_sync.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:test/test.dart';

class _MockSigner extends Mock implements NostrSigner {}

class _MockClient extends Mock implements NostrClient {}

class _FakeCache implements VaultKeyCache {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String pubkeyHex) async => _store[pubkeyHex];

  @override
  Future<void> write(String pubkeyHex, String base64Key) async {
    _store[pubkeyHex] = base64Key;
  }
}

/// Shapes a `queryEventsDetailed` answer with a live (non-failed) relay
/// pool returning [events].
({
  List<Event> events,
  bool timedOut,
  bool noRelays,
  bool anyRelayAnswered,
  List<String> unsettledRelays,
})
_confirmed(
  List<Event> events,
) => (
  events: events,
  timedOut: false,
  noRelays: false,
  anyRelayAnswered: false,
  unsettledRelays: const <String>[],
);

void main() {
  group(VaultKeyService, () {
    const pubkey =
        'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

    late _MockSigner signer;
    late _MockClient client;
    late _FakeCache cache;
    late VaultKeyService service;

    setUpAll(() {
      registerFallbackValue(Event(pubkey, 30078, const [], ''));
      registerFallbackValue(<Filter>[]);
    });

    late List<Duration> settleWaits;

    setUp(() {
      signer = _MockSigner();
      client = _MockClient();
      cache = _FakeCache();
      settleWaits = [];
      service = VaultKeyService(
        signer: signer,
        client: client,
        cache: cache,
        settleDelay: (duration) async => settleWaits.add(duration),
      );
      when(signer.getPublicKey).thenAnswer((_) async => pubkey);
    });

    /// Wires the signer and client to behave like a relay that stores the
    /// vault-key event handed to it and serves it back on the next query,
    /// which is what the post-publish read-back needs to see.
    ///
    /// Wrapping is a reversible `wrapped:<plaintext>` marker rather than
    /// real NIP-44, so a test can assert *which* key came back.
    List<Event> stubStoringRelay({List<Event> seed = const []}) {
      final stored = [...seed];
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => _confirmed([...stored]));
      when(() => signer.nip44Encrypt(pubkey, any())).thenAnswer(
        (invocation) async => 'wrapped:${invocation.positionalArguments[1]}',
      );
      when(() => signer.nip44Decrypt(pubkey, any())).thenAnswer((invocation) {
        final wrapped = invocation.positionalArguments[1] as String;
        return Future.value(wrapped.replaceFirst('wrapped:', ''));
      });
      when(() => signer.signEvent(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Event,
      );
      when(() => client.publishEvent(any())).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        stored.add(event);
        return PublishSuccess(event: event);
      });
      return stored;
    }

    /// A vault-key event as another device would have published it.
    Event otherDeviceKeyEvent(String rawKey, {int createdAt = 5000}) => Event(
      pubkey,
      30078,
      const [
        ['d', vaultKeyDTag],
      ],
      'wrapped:$rawKey',
      createdAt: createdAt,
    );

    test('returns the cached key without touching the signer', () async {
      final key = await AesGcm.with256bits().newSecretKey();
      final raw = base64Encode(await key.extractBytes());
      await cache.write(pubkey, raw);

      final obtained = await service.obtain();

      expect(base64Encode(await obtained.extractBytes()), equals(raw));
      verifyNever(() => signer.nip44Decrypt(any(), any()));
      verifyNever(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      );
    });

    test('unwraps the remote key and caches it', () async {
      final key = await AesGcm.with256bits().newSecretKey();
      final raw = base64Encode(await key.extractBytes());
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => _confirmed([
          Event(
            pubkey,
            30078,
            const [
              ['d', vaultKeyDTag],
            ],
            'wrapped-ciphertext',
          ),
        ]),
      );
      when(
        () => signer.nip44Decrypt(pubkey, 'wrapped-ciphertext'),
      ).thenAnswer((_) async => raw);

      final obtained = await service.obtain();

      expect(base64Encode(await obtained.extractBytes()), equals(raw));
      expect(await cache.read(pubkey), equals(raw));
      verifyNever(() => client.publishEvent(any()));
    });

    test(
      'ignores non-matching events returned by an untrustworthy relay',
      () async {
        stubStoringRelay(
          seed: [
            // Wrong kind: a relay handing back an unrelated event for the
            // same author must not be mistaken for the vault key.
            Event(pubkey, 1, const [], 'unrelated note'),
            // Right kind, wrong d tag: a different app-data document.
            Event(
              pubkey,
              30078,
              const [
                ['d', 'divine:sync:something-else'],
              ],
              'not the vault key',
            ),
          ],
        );

        final obtained = await service.obtain();

        expect((await obtained.extractBytes()).length, equals(32));
        verify(() => client.publishEvent(any())).called(1);
      },
    );

    test(
      'keeps the genuine key when a wrong-author decoy shares its d tag '
      'with a newer created_at',
      () async {
        const foreignPubkey =
            'b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90a1';
        final key = await AesGcm.with256bits().newSecretKey();
        final raw = base64Encode(await key.extractBytes());
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'wrapped-ciphertext',
              createdAt: 1000,
            ),
            // Different author, same d tag, newer created_at. A relay
            // answering a broad kind+author filter can hand this back;
            // without a pubkey check it would win the dedup by created_at
            // and shadow the genuine vault-key event.
            Event(
              foreignPubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'someone-elses-wrapped-ciphertext',
              createdAt: 2000,
            ),
          ]),
        );
        when(
          () => signer.nip44Decrypt(pubkey, 'wrapped-ciphertext'),
        ).thenAnswer((_) async => raw);

        final obtained = await service.obtain();

        expect(base64Encode(await obtained.extractBytes()), equals(raw));
        verifyNever(() => signer.nip44Decrypt(foreignPubkey, any()));
      },
    );

    test(
      'breaks a created_at tie on the lowest event id, whichever order the '
      'relay returns them in',
      () async {
        final lowerIdKey = base64Encode(
          await (await AesGcm.with256bits().newSecretKey()).extractBytes(),
        );
        final higherIdKey = base64Encode(
          await (await AesGcm.with256bits().newSecretKey()).extractBytes(),
        );
        // Ids are set explicitly rather than derived from the content so
        // the comparison under test has a known answer; a content-derived
        // pair would make the expectation depend on a sha256 draw.
        Event tied(String id, String content) => Event.fromJson({
          'id': id,
          'pubkey': pubkey,
          'created_at': 2000,
          'kind': 30078,
          'tags': [
            ['d', vaultKeyDTag],
          ],
          'content': content,
          'sig': '',
        });
        final lower = tied('0' * 64, 'lower-id-wrap');
        final higher = tied('f' * 64, 'higher-id-wrap');
        when(
          () => signer.nip44Decrypt(pubkey, 'lower-id-wrap'),
        ).thenAnswer((_) async => lowerIdKey);
        when(
          () => signer.nip44Decrypt(pubkey, 'higher-id-wrap'),
        ).thenAnswer((_) async => higherIdKey);

        // Both relay orderings must resolve to the same key. Comparing
        // created_at alone passes one of these two and fails the other —
        // two devices handed the same pair would each cache a different
        // key and never be able to read each other's items again.
        for (final ordering in [
          [lower, higher],
          [higher, lower],
        ]) {
          cache = _FakeCache();
          service = VaultKeyService(
            signer: signer,
            client: client,
            cache: cache,
          );
          when(
            () => client.queryEventsDetailed(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => _confirmed(ordering));

          final obtained = await service.obtain();

          expect(base64Encode(await obtained.extractBytes()), lowerIdKey);
        }
      },
    );

    test('generates and publishes a key when none exists remotely', () async {
      stubStoringRelay();

      final obtained = await service.obtain();

      expect((await obtained.extractBytes()).length, equals(32));
      expect(await cache.read(pubkey), isNotNull);
      verify(() => client.publishEvent(any())).called(1);
    });

    test(
      'adopts the key another device published instead of the one it just '
      'minted',
      () async {
        final otherDeviceKey = base64Encode(
          await (await AesGcm.with256bits().newSecretKey()).extractBytes(),
        );
        // The relay answers "no vault key" — genuinely, not a flake — so
        // this device mints and publishes one, exactly as a second device
        // starting up at the same moment does. By the time the read-back
        // runs, the other device's event is the one the relays retained
        // (addressable events keep exactly one). Caching the locally minted
        // key here would leave this device sealing sounds under a key the
        // other device can never open, and it would never notice, because
        // every later obtain() short-circuits on its own cache.
        var published = false;
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed(
            published ? [otherDeviceKeyEvent(otherDeviceKey)] : const [],
          ),
        );
        when(() => signer.nip44Encrypt(pubkey, any())).thenAnswer(
          (invocation) async => 'wrapped:${invocation.positionalArguments[1]}',
        );
        when(() => signer.nip44Decrypt(pubkey, any())).thenAnswer((invocation) {
          final wrapped = invocation.positionalArguments[1] as String;
          return Future.value(wrapped.replaceFirst('wrapped:', ''));
        });
        when(() => signer.signEvent(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments.first as Event,
        );
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          published = true;
          return PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          );
        });

        final obtained = await service.obtain();

        expect(base64Encode(await obtained.extractBytes()), otherDeviceKey);
        expect(await cache.read(pubkey), equals(otherDeviceKey));
      },
    );

    test(
      'retries the read-back until the relay serves the published key',
      () async {
        final stored = stubStoringRelay();
        var queriesAfterPublish = 0;
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async {
          if (stored.isEmpty) return _confirmed(const []);
          // The relay acknowledged the publish from an in-memory queue and
          // commits afterwards, so the first two read-backs legitimately
          // see nothing yet.
          queriesAfterPublish++;
          if (queriesAfterPublish <= 2) return _confirmed(const []);
          return _confirmed([...stored]);
        });

        final obtained = await service.obtain();

        expect((await obtained.extractBytes()).length, equals(32));
        expect(await cache.read(pubkey), isNotNull);
        expect(
          settleWaits,
          equals([
            VaultKeyService.settleInterval,
            VaultKeyService.settleInterval,
          ]),
        );
      },
    );

    test(
      'throws rather than caching a key the relays never served back',
      () async {
        stubStoringRelay();
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );

        // Publishing did happen — this is the post-publish read-back
        // failing, not the pre-publish lookup. Leaving the cache empty is
        // the point: nothing was sealed under the discarded key, so the
        // next obtain() can find the published event and adopt it, or mint
        // again, without orphaning anything.
        verify(() => client.publishEvent(any())).called(1);
        expect(await cache.read(pubkey), isNull);
        expect(settleWaits, hasLength(VaultKeyService.settleAttempts - 1));
      },
    );

    test(
      'throws rather than caching the minted key when the read-back cannot '
      'reach a relay',
      () async {
        final stored = stubStoringRelay();
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => stored.isEmpty
              ? _confirmed(const [])
              : (
                  events: <Event>[],
                  timedOut: true,
                  noRelays: false,
                  anyRelayAnswered: false,
                  unsettledRelays: const <String>[],
                ),
        );

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verify(() => client.publishEvent(any())).called(1);
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than caching the minted key when the read-back returns '
      'an event it cannot unwrap',
      () async {
        var published = false;
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed(
            published
                ? [
                    Event(
                      pubkey,
                      30078,
                      const [
                        ['d', vaultKeyDTag],
                      ],
                      'sealed-to-a-key-this-signer-lost',
                    ),
                  ]
                : const [],
          ),
        );
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenAnswer((_) async => 'freshly-wrapped');
        when(
          () => signer.nip44Decrypt(pubkey, any()),
        ).thenAnswer((_) async => null);
        when(() => signer.signEvent(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments.first as Event,
        );
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          published = true;
          return PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          );
        });

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'resolves once for two concurrent calls that both miss the cache',
      () async {
        stubStoringRelay();

        final results = await Future.wait([
          service.obtain(),
          service.obtain(),
        ]);

        final rawKeys = await Future.wait(
          results.map((key) async => base64Encode(await key.extractBytes())),
        );
        expect(rawKeys[0], equals(rawKeys[1]));
        verify(() => client.publishEvent(any())).called(1);
      },
    );

    test(
      'clears the in-flight future on failure so a later call re-queries '
      'and can succeed',
      () async {
        var queryCount = 0;
        final stored = stubStoringRelay();
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async {
          queryCount++;
          if (queryCount == 1) {
            return (
              events: <Event>[],
              timedOut: true,
              noRelays: false,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            );
          }
          return _confirmed([...stored]);
        });

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );

        // If the failed future's in-flight entry were never cleared, this
        // second call would return the same already-rejected future
        // instead of re-querying — asserted below via queryCount rather
        // than just "does this resolve", since a stuck future would also
        // (wrongly) throw here, which could be mistaken for "still
        // guarding against forking" instead of "broken re-query".
        final obtained = await service.obtain();

        expect((await obtained.extractBytes()).length, equals(32));
        // 1: the timed-out first attempt. 2: the second attempt's lookup,
        // which finds nothing and mints. 3: the post-publish read-back.
        expect(queryCount, equals(3));
      },
    );

    test(
      'throws rather than forking when the relay lookup throws',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenThrow(StateError('relay unreachable'));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
      },
    );

    test(
      'throws rather than forking when no relays are connected',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[],
            timedOut: false,
            noRelays: true,
            anyRelayAnswered: false,
            unsettledRelays: const <String>[],
          ),
        );

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        // The dangerous failure mode is not "did it publish" but "did it
        // ever decide to generate a key at all" — deleting the noRelays
        // guard makes execution fall through to _generateAndPublish,
        // which calls nip44Encrypt before signEvent/publishEvent. Without
        // this assertion the earlier two still pass (mocktail's
        // MissingStubError on the unstubbed nip44Encrypt gets caught by
        // the generic catch and rethrown as VaultKeyUnavailableException),
        // so this is the one assertion that actually pins the invariant.
        verifyNever(() => signer.nip44Encrypt(any(), any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when the relay query times out',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[],
            timedOut: true,
            noRelays: false,
            anyRelayAnswered: false,
            unsettledRelays: const <String>[],
          ),
        );

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        // See the noRelays test above: this is the assertion that
        // actually proves generation was never reached, not just that
        // publish wasn't reached.
        verifyNever(() => signer.nip44Encrypt(any(), any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test('throws when the signer cannot unwrap the remote key', () async {
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => _confirmed([
          Event(
            pubkey,
            30078,
            const [
              ['d', vaultKeyDTag],
            ],
            'wrapped-ciphertext',
          ),
        ]),
      );
      when(
        () => signer.nip44Decrypt(pubkey, any()),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.obtain(),
        throwsA(isA<VaultKeyUnavailableException>()),
      );
      verifyNever(() => client.publishEvent(any()));
    });

    test('throws when signed out', () async {
      when(signer.getPublicKey).thenAnswer((_) async => null);

      await expectLater(
        service.obtain(),
        throwsA(isA<VaultKeyUnavailableException>()),
      );
      verifyNever(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      );
    });

    test(
      'does not leak the key material when the cached value fails to '
      'decode',
      () async {
        const badKey = '@@@@this-looks-like-a-leaked-vault-key@@@@';
        await cache.write(pubkey, badKey);

        await expectLater(
          service.obtain(),
          throwsA(
            isA<VaultKeyUnavailableException>().having(
              (e) => e.message,
              'message',
              isNot(contains(badKey)),
            ),
          ),
        );
      },
    );

    test(
      'throws rather than forking when the cached key is not valid base64',
      () async {
        await cache.write(pubkey, '@@@@not-base64@@@@');

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
      },
    );

    test(
      'throws rather than forking when the cached key is the wrong length',
      () async {
        await cache.write(pubkey, base64Encode(List<int>.filled(16, 0)));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
      },
    );

    test(
      'throws and does not poison the cache when the unwrapped key is '
      'not valid base64',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'wrapped-ciphertext',
            ),
          ]),
        );
        when(
          () => signer.nip44Decrypt(pubkey, any()),
        ).thenAnswer((_) async => '@@@@not-base64@@@@');

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws and does not poison the cache when the unwrapped key is '
      'the wrong length',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'wrapped-ciphertext',
            ),
          ]),
        );
        when(() => signer.nip44Decrypt(pubkey, any())).thenAnswer(
          (_) async => base64Encode(List<int>.filled(16, 0)),
        );

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when the signer errors unwrapping the '
      'remote key',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'wrapped-ciphertext',
            ),
          ]),
        );
        when(
          () => signer.nip44Decrypt(pubkey, any()),
        ).thenThrow(StateError('signer unreachable'));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
      },
    );

    test(
      'throws rather than forking when the signer errors wrapping a fresh '
      'key',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenThrow(StateError('signer unreachable'));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'does not leak the vault key material when the signer echoes '
      'request params in its wrap-refusal error',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
        when(() => signer.nip44Encrypt(pubkey, any())).thenAnswer((
          invocation,
        ) async {
          final plaintext = invocation.positionalArguments[1] as String;
          throw StateError('bunker rejected request for $plaintext');
        });

        await expectLater(
          service.obtain(),
          throwsA(
            isA<VaultKeyUnavailableException>().having(
              (e) => e.message,
              'message',
              isNot(contains('bunker rejected')),
            ),
          ),
        );
      },
    );

    test(
      'throws rather than forking when the signer returns an empty wrap',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenAnswer((_) async => '');

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when the signer refuses to sign the '
      'vault key event',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenAnswer((_) async => 'freshly-wrapped');
        when(() => signer.signEvent(any())).thenAnswer((_) async => null);

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when no relay accepts the vault key '
      'event',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenAnswer((_) async => 'freshly-wrapped');
        when(() => signer.signEvent(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments.first as Event,
        );
        when(
          () => client.publishEvent(any()),
        ).thenAnswer((_) async => const PublishNoRelays());

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        expect(await cache.read(pubkey), isNull);
      },
    );
  });
}
