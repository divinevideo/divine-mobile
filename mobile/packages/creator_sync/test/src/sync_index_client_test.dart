// ABOUTME: Tests for publishing and fetching encrypted sync index events.
// ABOUTME: Pins tag shape, tombstone expiry, and foreign-event filtering.

import 'package:creator_sync/creator_sync.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:test/test.dart';

class _MockSigner extends Mock implements NostrSigner {}

class _MockClient extends Mock implements NostrClient {}

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

/// A publish one relay answered `OK true`.
PublishOutcome _accepted(Event event) => PublishOutcome(
  eventId: event.id,
  eventKind: event.kind,
  acceptedBy: const ['wss://relay.example'],
  rejectedBy: const {},
  noResponseFrom: const [],
);

/// A publish every targeted relay answered `OK false`.
PublishOutcome _rejected(Event event, {String reason = 'blocked'}) =>
    PublishOutcome(
      eventId: event.id,
      eventKind: event.kind,
      acceptedBy: const [],
      rejectedBy: {'wss://relay.example': reason},
      noResponseFrom: const [],
    );

void main() {
  group(SyncIndexClient, () {
    const pubkey =
        'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
    const foreignPubkey =
        'b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90a1';
    const soundId =
        'f1e2d3c4b5a6978869504132231405f6e7d8c9baab9c8d7e6f50413223140506';
    const ref = SyncItemRef(SyncItemKind.sound, soundId);

    late _MockSigner signer;
    late _MockClient client;
    late SyncCipher cipher;
    late SyncIndexClient indexClient;

    setUpAll(() {
      registerFallbackValue(Event(pubkey, 30078, const [], ''));
      registerFallbackValue(<Filter>[]);
    });

    setUp(() async {
      signer = _MockSigner();
      client = _MockClient();
      cipher = SyncCipher(await AesGcm.with256bits().newSecretKey());
      indexClient = SyncIndexClient(
        client: client,
        signer: signer,
        cipher: cipher,
      );
      when(signer.getPublicKey).thenAnswer((_) async => pubkey);
      when(() => signer.signEvent(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Event,
      );
      when(() => client.publishEventAwaitOk(any())).thenAnswer(
        (invocation) async => _accepted(
          invocation.positionalArguments.first as Event,
        ),
      );
    });

    Event capturedEvent() =>
        verify(() => client.publishEventAwaitOk(captureAny())).captured.single
            as Event;

    group('publish', () {
      test('publishes an encrypted item with the right d tag', () async {
        await indexClient.publish(
          ref,
          SyncIndexEntry.item(body: const {'id': 'abc'}),
        );

        final event = capturedEvent();
        expect(event.kind, equals(30078));
        expect(
          event.tags,
          contains(equals(['d', 'divine:sync:sound:$soundId'])),
        );
        expect(event.content, isNot(contains('abc')));
        expect(await cipher.open(event.content), contains('abc'));
      });

      test('adds a NIP-40 expiration tag to tombstones only', () async {
        await indexClient.publish(ref, SyncIndexEntry.tombstone());
        final tombstone = capturedEvent();
        final expiration = tombstone.tags.firstWhere(
          (t) => t[0] == 'expiration',
        );

        expect(
          int.parse(expiration[1]) - tombstone.createdAt,
          equals(const Duration(days: 90).inSeconds),
        );
      });

      test('omits the expiration tag on live items', () async {
        await indexClient.publish(
          ref,
          SyncIndexEntry.item(body: const {'id': 'abc'}),
        );

        expect(
          capturedEvent().tags.any((t) => t[0] == 'expiration'),
          isFalse,
        );
      });

      test('clamps created_at past a known remote timestamp', () async {
        await indexClient.publish(
          ref,
          SyncIndexEntry.item(body: const {'id': 'abc'}),
          latestKnownRemote: 4_000_000_000,
        );

        expect(capturedEvent().createdAt, equals(4_000_000_001));
      });

      test('returns the created_at it stamped on the event', () async {
        final stamped = await indexClient.publish(
          ref,
          SyncIndexEntry.item(body: const {'id': 'abc'}),
          latestKnownRemote: 4_000_000_000,
        );

        expect(stamped, equals(4_000_000_001));
        expect(stamped, equals(capturedEvent().createdAt));
      });

      test('throws $SyncIndexException when no relay is reachable', () async {
        when(() => client.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments.first as Event).id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        await expectLater(
          indexClient.publish(ref, SyncIndexEntry.tombstone()),
          throwsA(isA<SyncIndexException>()),
        );
      });

      test(
        'throws $SyncIndexException when every relay answers OK false',
        () async {
          // The frame reaches the relay and the socket accepts it, so the
          // pre-OK publish path reported this as success and let the caller
          // record applied state for an event no relay stored.
          when(() => client.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async => _rejected(
              invocation.positionalArguments.first as Event,
              reason: 'blocked: kind 30078 not in allowed list',
            ),
          );

          await expectLater(
            indexClient.publish(ref, SyncIndexEntry.tombstone()),
            throwsA(isA<SyncIndexException>()),
          );
        },
      );

      test('throws $SyncIndexException when signed out', () async {
        when(signer.getPublicKey).thenAnswer((_) async => null);

        await expectLater(
          indexClient.publish(ref, SyncIndexEntry.tombstone()),
          throwsA(isA<SyncIndexException>()),
        );
        verifyNever(() => client.publishEventAwaitOk(any()));
      });

      test(
        'throws $SyncIndexException when the signer refuses to sign',
        () async {
          when(() => signer.signEvent(any())).thenAnswer((_) async => null);

          await expectLater(
            indexClient.publish(ref, SyncIndexEntry.tombstone()),
            throwsA(isA<SyncIndexException>()),
          );
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );
    });

    group('fetch', () {
      test('decrypts records of the requested kind', () async {
        final sealed = await cipher.seal(
          SyncIndexEntry.item(body: const {'id': 'abc'}).toPayloadJson(),
        );
        when(() => client.queryEventsDetailed(any())).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              [
                ['d', ref.dTag],
              ],
              sealed,
              createdAt: 1_700_000_000,
            ),
          ]),
        );

        final records = await indexClient.fetch(SyncItemKind.sound);

        expect(records, hasLength(1));
        expect(records.single.ref, equals(ref));
        expect(records.single.createdAt, equals(1_700_000_000));
        expect(records.single.entry.body, equals({'id': 'abc'}));
      });

      test('skips foreign kind-30078 events', () async {
        // Sealed under the same vault key as a real item would be, so
        // removing the allowlist check would successfully decrypt these
        // and let them leak into the result instead of failing for an
        // unrelated reason (undecryptable content).
        final dmCursorPayload = await cipher.seal('opaque-dm-cursor');
        final vaultKeyPayload = await cipher.seal('wrapped-key');
        when(() => client.queryEventsDetailed(any())).thenAnswer(
          (_) async => _confirmed([
            Event(pubkey, 30078, const [
              ['d', 'divine:dm:read-cursor'],
            ], dmCursorPayload),
            Event(pubkey, 30078, const [
              ['d', vaultKeyDTag],
            ], vaultKeyPayload),
          ]),
        );

        expect(await indexClient.fetch(SyncItemKind.sound), isEmpty);
      });

      test('skips records of a different sync item kind', () async {
        const clipRef = SyncItemRef(SyncItemKind.clip, soundId);
        final sealed = await cipher.seal(
          SyncIndexEntry.item(body: const {'id': 'abc'}).toPayloadJson(),
        );
        when(() => client.queryEventsDetailed(any())).thenAnswer(
          (_) async => _confirmed([
            Event(pubkey, 30078, [
              ['d', clipRef.dTag],
            ], sealed),
          ]),
        );

        expect(await indexClient.fetch(SyncItemKind.sound), isEmpty);
      });

      test('skips records it cannot decrypt', () async {
        when(() => client.queryEventsDetailed(any())).thenAnswer(
          (_) async => _confirmed([
            Event(pubkey, 30078, [
              ['d', ref.dTag],
            ], 'not-decryptable'),
          ]),
        );

        expect(await indexClient.fetch(SyncItemKind.sound), isEmpty);
      });

      test('skips records with a malformed decrypted payload', () async {
        final sealed = await cipher.seal('not a payload envelope');
        when(() => client.queryEventsDetailed(any())).thenAnswer(
          (_) async => _confirmed([
            Event(pubkey, 30078, [
              ['d', ref.dTag],
            ], sealed),
          ]),
        );

        expect(await indexClient.fetch(SyncItemKind.sound), isEmpty);
      });

      test('keeps only the newest event per d tag', () async {
        final older = await cipher.seal(
          SyncIndexEntry.item(body: const {'gen': 'old'}).toPayloadJson(),
        );
        final newer = await cipher.seal(
          SyncIndexEntry.item(body: const {'gen': 'new'}).toPayloadJson(),
        );
        when(() => client.queryEventsDetailed(any())).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              [
                ['d', ref.dTag],
              ],
              older,
              createdAt: 1000,
            ),
            Event(
              pubkey,
              30078,
              [
                ['d', ref.dTag],
              ],
              newer,
              createdAt: 2000,
            ),
          ]),
        );

        final records = await indexClient.fetch(SyncItemKind.sound);

        expect(records, hasLength(1));
        expect(records.single.entry.body, equals({'gen': 'new'}));
      });

      test(
        'breaks a created_at tie on the lowest event id, whichever order '
        'the relay returns them in',
        () async {
          final lowerIdContent = await cipher.seal(
            SyncIndexEntry.item(
              body: const {'gen': 'lower-id'},
            ).toPayloadJson(),
          );
          final higherIdContent = await cipher.seal(
            SyncIndexEntry.item(
              body: const {'gen': 'higher-id'},
            ).toPayloadJson(),
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
              ['d', ref.dTag],
            ],
            'content': content,
            'sig': '',
          });
          final lower = tied('0' * 64, lowerIdContent);
          final higher = tied('f' * 64, higherIdContent);

          // Both relay orderings must land on the same record. Comparing
          // created_at alone passes one of these two and fails the other,
          // which is exactly the device-to-device disagreement NIP-01's
          // tie-break exists to stop.
          for (final ordering in [
            [lower, higher],
            [higher, lower],
          ]) {
            when(
              () => client.queryEventsDetailed(any()),
            ).thenAnswer((_) async => _confirmed(ordering));

            final records = await indexClient.fetch(SyncItemKind.sound);

            expect(records, hasLength(1));
            expect(records.single.entry.body, equals({'gen': 'lower-id'}));
          }
        },
      );

      test(
        'keeps the genuine record when a wrong-kind decoy shares its d '
        'tag with a newer created_at',
        () async {
          final sealed = await cipher.seal(
            SyncIndexEntry.item(body: const {'id': 'genuine'}).toPayloadJson(),
          );
          when(() => client.queryEventsDetailed(any())).thenAnswer(
            (_) async => _confirmed([
              Event(
                pubkey,
                30078,
                [
                  ['d', ref.dTag],
                ],
                sealed,
                createdAt: 1000,
              ),
              // Wrong kind, same d tag, newer created_at. Without a kind
              // check this decoy would win the dedup by created_at, fail
              // to decrypt as an unrelated text note, and silently drop
              // the genuine record instead of surfacing it.
              Event(
                pubkey,
                1,
                [
                  ['d', ref.dTag],
                ],
                'unrelated note',
                createdAt: 2000,
              ),
            ]),
          );

          final records = await indexClient.fetch(SyncItemKind.sound);

          expect(records, hasLength(1));
          expect(records.single.entry.body, equals({'id': 'genuine'}));
        },
      );

      test(
        'keeps the genuine record when a wrong-author decoy shares its '
        'd tag with a newer created_at',
        () async {
          final sealed = await cipher.seal(
            SyncIndexEntry.item(body: const {'id': 'genuine'}).toPayloadJson(),
          );
          when(() => client.queryEventsDetailed(any())).thenAnswer(
            (_) async => _confirmed([
              Event(
                pubkey,
                30078,
                [
                  ['d', ref.dTag],
                ],
                sealed,
                createdAt: 1000,
              ),
              // Different author, same d tag, newer created_at. A relay
              // answering a broad kind+author filter can hand this back;
              // without a pubkey check it would win the dedup and shadow
              // the genuine record from this account.
              Event(
                foreignPubkey,
                30078,
                [
                  ['d', ref.dTag],
                ],
                'someone-elses-payload',
                createdAt: 2000,
              ),
            ]),
          );

          final records = await indexClient.fetch(SyncItemKind.sound);

          expect(records, hasLength(1));
          expect(records.single.entry.body, equals({'id': 'genuine'}));
        },
      );

      test('sends kinds, authors, and since in the query filter', () async {
        when(
          () => client.queryEventsDetailed(any()),
        ).thenAnswer((_) async => _confirmed(const []));

        await indexClient.fetch(SyncItemKind.sound, since: 1_234_567);

        final filters =
            verify(
                  () => client.queryEventsDetailed(captureAny()),
                ).captured.single
                as List<Filter>;
        expect(filters, hasLength(1));
        expect(filters.single.kinds, equals([30078]));
        expect(filters.single.authors, equals([pubkey]));
        expect(filters.single.since, equals(1_234_567));
      });

      test('omits since from the filter when not passed', () async {
        when(
          () => client.queryEventsDetailed(any()),
        ).thenAnswer((_) async => _confirmed(const []));

        await indexClient.fetch(SyncItemKind.sound);

        final filters =
            verify(
                  () => client.queryEventsDetailed(captureAny()),
                ).captured.single
                as List<Filter>;
        expect(filters.single.since, isNull);
      });

      test('throws $SyncIndexException when the query fails', () async {
        when(
          () => client.queryEventsDetailed(any()),
        ).thenThrow(StateError('relay unreachable'));

        await expectLater(
          indexClient.fetch(SyncItemKind.sound),
          throwsA(isA<SyncIndexException>()),
        );
      });

      test(
        'throws $SyncIndexException rather than reading an empty library '
        'when no relays are connected',
        () async {
          when(() => client.queryEventsDetailed(any())).thenAnswer(
            (_) async => (
              events: <Event>[],
              timedOut: false,
              noRelays: true,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            ),
          );

          await expectLater(
            indexClient.fetch(SyncItemKind.sound),
            throwsA(isA<SyncIndexException>()),
          );
        },
      );

      test(
        'throws $SyncIndexException rather than reading an empty library '
        'when the relay query times out',
        () async {
          when(() => client.queryEventsDetailed(any())).thenAnswer(
            (_) async => (
              events: <Event>[],
              timedOut: true,
              noRelays: false,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            ),
          );

          await expectLater(
            indexClient.fetch(SyncItemKind.sound),
            throwsA(isA<SyncIndexException>()),
          );
        },
      );

      test('throws $SyncIndexException when signed out', () async {
        when(signer.getPublicKey).thenAnswer((_) async => null);

        await expectLater(
          indexClient.fetch(SyncItemKind.sound),
          throwsA(isA<SyncIndexException>()),
        );
        verifyNever(() => client.queryEventsDetailed(any()));
      });
    });
  });
}
