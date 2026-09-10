// ABOUTME: Covers d=notify list read/publish, mutation serialization, and
// ABOUTME: that an unreadable list is never used as a base for a publish.

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const creatorA =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const creatorB =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const creatorC =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

Event _notifyEvent(List<String> pubkeys, {int createdAt = 1710000000}) => Event(
  ownerPubkey,
  Nip51PeopleListCodec.kind,
  [
    ['d', Nip51PeopleListCodec.notifyDTag],
    ['title', 'Notify'],
    for (final p in pubkeys) ['p', p],
  ],
  '',
  createdAt: createdAt,
);

/// Shapes a `queryEventsDetailed` answer.
({
  List<Event> events,
  bool timedOut,
  bool noRelays,
  bool anyRelayAnswered,
  List<String> unsettledRelays,
})
_readResult(
  List<Event> events, {
  bool timedOut = false,
  bool noRelays = false,
}) => (
  events: events,
  timedOut: timedOut,
  noRelays: noRelays,
  anyRelayAnswered: false,
  unsettledRelays: const <String>[],
);

/// Member pubkeys carried on the event handed to `publishEvent`.
List<String> _publishedMembers(Event event) => event.tags
    .where((t) => t.length >= 2 && t[0] == 'p')
    .map((t) => t[1])
    .toList();

void main() {
  setUpAll(() {
    registerFallbackValue(_notifyEvent(const []));
    registerFallbackValue(<Filter>[]);
  });

  group(NotifySubscriptionsUnavailableException, () {
    test('names the owner in full, never truncated', () {
      const exception = NotifySubscriptionsUnavailableException(ownerPubkey);

      expect(exception.ownerPubkey, equals(ownerPubkey));
      expect(exception.toString(), contains(ownerPubkey));
    });
  });

  group(NotifySubscriptionsRepositoryImpl, () {
    late _MockNostrClient client;
    late NotifySubscriptionsRepositoryImpl repository;

    setUp(() {
      client = _MockNostrClient();
      repository = NotifySubscriptionsRepositoryImpl(nostrClient: client);
    });

    tearDown(() async {
      await repository.dispose();
    });

    void stubPublishSuccess() {
      when(() => client.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );
    }

    void stubRead(
      List<Event> events, {
      bool timedOut = false,
      bool noRelays = false,
    }) {
      when(() => client.queryEventsDetailed(any())).thenAnswer(
        (_) async =>
            _readResult(events, timedOut: timedOut, noRelays: noRelays),
      );
    }

    group('readSubscriptions', () {
      test('returns an empty set when the user has no notify list', () async {
        stubRead(const []);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          isEmpty,
        );
      });

      test('decodes members from the notify list event', () async {
        stubRead([
          _notifyEvent([creatorA, creatorB]),
        ]);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA, creatorB}),
        );
      });

      test('keeps the newest generation when relays return several', () async {
        stubRead([
          _notifyEvent([creatorA, creatorB]),
          _notifyEvent([creatorA], createdAt: 1710000500),
        ]);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
        );
      });

      test('throws rather than reporting empty when the read throws', () async {
        when(
          () => client.queryEventsDetailed(any()),
        ).thenThrow(StateError('relay down'));

        await expectLater(
          repository.readSubscriptions(ownerPubkey: ownerPubkey),
          throwsA(isA<NotifySubscriptionsUnavailableException>()),
        );
      });

      test('throws when the query reached no relay', () async {
        stubRead(const [], noRelays: true);

        await expectLater(
          repository.readSubscriptions(ownerPubkey: ownerPubkey),
          throwsA(isA<NotifySubscriptionsUnavailableException>()),
        );
      });

      test('throws when the query timed out', () async {
        stubRead(const [], timedOut: true);

        await expectLater(
          repository.readSubscriptions(ownerPubkey: ownerPubkey),
          throwsA(isA<NotifySubscriptionsUnavailableException>()),
        );
      });
    });

    group('unreadable list', () {
      test(
        'subscribe publishes nothing when the list could not be read',
        () async {
          stubRead(const [], noRelays: true);
          stubPublishSuccess();

          final result = await repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          );

          expect(result.status, equals(PeopleListPublishStatus.failed));
          verifyNever(() => client.publishEvent(any()));
        },
      );

      test(
        'unsubscribe publishes nothing when the list could not be read',
        () async {
          stubRead(const [], timedOut: true);
          stubPublishSuccess();

          final result = await repository.unsubscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          );

          expect(result.status, equals(PeopleListPublishStatus.failed));
          verifyNever(() => client.publishEvent(any()));
        },
      );

      test(
        'watchSubscriptions stays silent so the UI cannot enable a bell',
        () async {
          stubRead(const [], noRelays: true);

          final emitted = <Set<String>>[];
          final subscription = repository
              .watchSubscriptions(ownerPubkey: ownerPubkey)
              .listen(emitted.add);
          addTearDown(subscription.cancel);

          await expectLater(
            repository.readSubscriptions(ownerPubkey: ownerPubkey),
            throwsA(isA<NotifySubscriptionsUnavailableException>()),
          );
          await Future<void>.delayed(Duration.zero);

          expect(
            emitted,
            isEmpty,
            reason:
                'an unverified empty set would look like "no subscriptions"',
          );
        },
      );

      test(
        're-reads on the next mount instead of caching the failure',
        () async {
          var attempts = 0;
          when(() => client.queryEventsDetailed(any())).thenAnswer((_) async {
            attempts++;
            if (attempts == 1) return _readResult(const [], noRelays: true);
            return _readResult([
              _notifyEvent([creatorA]),
            ]);
          });

          await expectLater(
            repository.readSubscriptions(ownerPubkey: ownerPubkey),
            throwsA(isA<NotifySubscriptionsUnavailableException>()),
          );

          expect(
            await repository.readSubscriptions(ownerPubkey: ownerPubkey),
            equals({creatorA}),
          );
          expect(attempts, equals(2));
        },
      );

      test('shares one relay read across concurrent mounts', () async {
        var attempts = 0;
        when(() => client.queryEventsDetailed(any())).thenAnswer((_) async {
          attempts++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return _readResult([
            _notifyEvent([creatorA]),
          ]);
        });

        await Future.wait([
          repository.readSubscriptions(ownerPubkey: ownerPubkey),
          repository.readSubscriptions(ownerPubkey: ownerPubkey),
        ]);

        expect(attempts, equals(1));
      });
    });

    group('subscribe', () {
      test(
        'preserves source metadata, member positions, and content',
        () async {
          final source = Event(
            ownerPubkey,
            Nip51PeopleListCodec.kind,
            const [
              ['d', 'notify'],
              ['title', 'Renamed elsewhere'],
              ['p', creatorA, 'wss://relay.example', 'friend'],
              ['alt', 'Notification subscriptions'],
            ],
            'nip44-ciphertext-written-by-another-client',
            createdAt: 1710000000,
          );
          stubRead([source]);
          stubPublishSuccess();

          await repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorB,
          );

          final published =
              verify(() => client.publishEvent(captureAny())).captured.single
                  as Event;
          expect(published.tags, const [
            ['d', 'notify'],
            ['title', 'Renamed elsewhere'],
            ['p', creatorA, 'wss://relay.example', 'friend'],
            ['alt', 'Notification subscriptions'],
            ['p', creatorB],
          ]);
          expect(
            published.content,
            'nip44-ciphertext-written-by-another-client',
          );
        },
      );

      test(
        'two sequential edits retain the complete published source',
        () async {
          final source = Event(
            ownerPubkey,
            Nip51PeopleListCodec.kind,
            const [
              ['d', 'notify'],
              ['alt', 'Keep me'],
              ['p', creatorA, 'wss://relay.example'],
            ],
            'ciphertext',
            createdAt: 1710000000,
          );
          stubRead([source]);
          stubPublishSuccess();

          await repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorB,
          );
          await repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorC,
          );

          final published = verify(
            () => client.publishEvent(captureAny()),
          ).captured.cast<Event>();
          expect(published.last.tags, const [
            ['d', 'notify'],
            ['alt', 'Keep me'],
            ['p', creatorA, 'wss://relay.example'],
            ['p', creatorB],
            ['p', creatorC],
          ]);
          expect(published.last.content, 'ciphertext');
        },
      );

      test('mints the canonical tags when no source event exists', () async {
        stubRead(const []);
        stubPublishSuccess();

        await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(published.tags, const [
          ['d', 'notify'],
          ['title', 'Notify'],
          ['p', creatorA],
        ]);
        expect(published.content, isEmpty);
      });

      test('publishes the full list including the new creator', () async {
        stubRead([
          _notifyEvent([creatorA]),
        ]);
        stubPublishSuccess();

        final result = await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorB,
        );

        expect(result.submitted, isTrue);
        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(_publishedMembers(published), containsAll([creatorA, creatorB]));
      });

      test('never truncates the creator pubkey', () async {
        stubRead(const []);
        stubPublishSuccess();

        await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(_publishedMembers(published), equals([creatorA]));
        expect(creatorA, hasLength(64));
      });

      test('is a no-op when already subscribed', () async {
        stubRead([
          _notifyEvent([creatorA]),
        ]);

        final result = await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEvent(any()));
      });

      test('refuses to subscribe the owner to themselves', () async {
        stubRead(const []);

        final result = await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: ownerPubkey,
        );

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEvent(any()));
      });

      test('leaves the snapshot unchanged when the publish fails', () async {
        stubRead([
          _notifyEvent([creatorA]),
        ]);
        when(
          () => client.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final result = await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorB,
        );

        expect(result.status, equals(PeopleListPublishStatus.failed));
        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
          reason: 'a failed publish must not leave optimistic state behind',
        );
      });
    });

    group('unsubscribe', () {
      test('removes every matching tag while preserving the source', () async {
        final source = Event(
          ownerPubkey,
          Nip51PeopleListCodec.kind,
          const [
            ['d', 'notify'],
            ['p', creatorA, 'wss://relay.example'],
            ['alt', 'Keep me'],
            ['p', creatorA, 'wss://backup.example'],
            ['p', creatorB, 'wss://relay.example', 'friend'],
          ],
          'ciphertext',
          createdAt: 1710000000,
        );
        stubRead([source]);
        stubPublishSuccess();

        await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(published.tags, const [
          ['d', 'notify'],
          ['alt', 'Keep me'],
          ['p', creatorB, 'wss://relay.example', 'friend'],
        ]);
        expect(published.content, 'ciphertext');
      });

      test('publishes the list without the creator', () async {
        stubRead([
          _notifyEvent([creatorA, creatorB]),
        ]);
        stubPublishSuccess();

        final result = await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        expect(result.submitted, isTrue);
        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(_publishedMembers(published), equals([creatorB]));
      });

      test('publishes an empty list when the last bell is removed', () async {
        stubRead([
          _notifyEvent([creatorA]),
        ]);
        stubPublishSuccess();

        await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(_publishedMembers(published), isEmpty);
        expect(
          published.tags.any((t) => t.isNotEmpty && t[0] == 'd'),
          isTrue,
          reason: 'clearing the list must still be a valid d=notify event',
        );
      });

      test('is a no-op when not subscribed, so unfollow can call it '
          'unconditionally', () async {
        stubRead(const []);

        final result = await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEvent(any()));
      });
    });

    group('outstanding removals', () {
      test('a failed removal is reapplied by the next publish', () async {
        stubRead([
          _notifyEvent([creatorA, creatorB]),
        ]);
        when(
          () => client.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final teardown = await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );
        expect(teardown.status, equals(PeopleListPublishStatus.failed));

        stubPublishSuccess();
        await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorC,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.last
                as Event;
        expect(
          _publishedMembers(published),
          equals([creatorB, creatorC]),
          reason: 'the abandoned bell must not survive the next publish',
        );
      });

      test('reconcile republishes an outstanding removal', () async {
        stubRead([
          _notifyEvent([creatorA, creatorB]),
        ]);
        when(
          () => client.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        stubPublishSuccess();
        final result = await repository.reconcile(ownerPubkey: ownerPubkey);

        expect(result.submitted, isTrue);
        final published =
            verify(() => client.publishEvent(captureAny())).captured.last
                as Event;
        expect(_publishedMembers(published), equals([creatorB]));
        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorB}),
        );
      });

      test('reconcile is a no-op when nothing is outstanding', () async {
        stubRead([
          _notifyEvent([creatorA]),
        ]);
        stubPublishSuccess();

        final result = await repository.reconcile(ownerPubkey: ownerPubkey);

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEvent(any()));
      });

      test(
        'a removal that failed on an unreadable list is retried later',
        () async {
          var attempts = 0;
          when(() => client.queryEventsDetailed(any())).thenAnswer((_) async {
            attempts++;
            if (attempts == 1) return _readResult(const [], noRelays: true);
            return _readResult([
              _notifyEvent([creatorA, creatorB]),
            ]);
          });
          stubPublishSuccess();

          final teardown = await repository.unsubscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          );
          expect(teardown.status, equals(PeopleListPublishStatus.failed));
          verifyNever(() => client.publishEvent(any()));

          final result = await repository.reconcile(ownerPubkey: ownerPubkey);

          expect(result.submitted, isTrue);
          final published =
              verify(() => client.publishEvent(captureAny())).captured.last
                  as Event;
          expect(_publishedMembers(published), equals([creatorB]));
        },
      );
    });

    group('mutation serialization', () {
      test('concurrent subscribes both survive in the final list', () async {
        stubRead(const []);
        // A slow publish widens the window a naive implementation would race
        // in: both mutations would read the same empty base set.
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          );
        });

        await Future.wait([
          repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          ),
          repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorB,
          ),
        ]);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA, creatorB}),
        );

        final published = verify(
          () => client.publishEvent(captureAny()),
        ).captured.cast<Event>();
        expect(published, hasLength(2));
        expect(
          _publishedMembers(published.last),
          containsAll([creatorA, creatorB]),
          reason: 'the second publish must build on the first, not clobber it',
        );
      });

      test('a rapid on/off/on sequence converges to on', () async {
        stubRead(const []);
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          );
        });

        await Future.wait([
          repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          ),
          repository.unsubscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          ),
          repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          ),
        ]);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
        );
        // Each toggle must observe the previous one's result. Unserialized,
        // all three read the same empty base set, so the unsubscribe collapses
        // to a no-op and only two events are published.
        expect(
          verify(() => client.publishEvent(captureAny())).captured,
          hasLength(3),
        );
      });

      test(
        'a failed mutation does not abort the ones queued behind it',
        () async {
          stubRead(const []);
          var call = 0;
          when(() => client.publishEvent(any())).thenAnswer((invocation) async {
            call++;
            if (call == 1) throw StateError('relay rejected');
            return PublishSuccess(
              event: invocation.positionalArguments.first as Event,
            );
          });

          final results = await Future.wait([
            repository.subscribe(
              ownerPubkey: ownerPubkey,
              creatorPubkey: creatorA,
            ),
            repository.subscribe(
              ownerPubkey: ownerPubkey,
              creatorPubkey: creatorB,
            ),
          ]);

          expect(results.first.status, equals(PeopleListPublishStatus.failed));
          expect(results.last.submitted, isTrue);
          expect(
            await repository.readSubscriptions(ownerPubkey: ownerPubkey),
            equals({creatorB}),
          );
        },
      );

      test('steps created_at past the previous event so replacement is not '
          'a coin flip', () async {
        final nowSeconds =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        // A list published "in the future" relative to this device's clock.
        stubRead([
          _notifyEvent([creatorA], createdAt: nowSeconds + 500),
        ]);
        stubPublishSuccess();

        await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorB,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(published.createdAt, greaterThan(nowSeconds + 500));
      });
    });

    group('refresh', () {
      test(
        'picks the same tied revision whichever order relays return',
        () async {
          final higherId = _notifyEvent([creatorA])
            ..id =
                'ffffffffffffffffffffffffffffffff'
                'ffffffffffffffffffffffffffffffff';
          final lowerId = _notifyEvent([creatorB])
            ..id =
                '00000000000000000000000000000000'
                '00000000000000000000000000000000';

          // Both orders must agree, or the tie-break is still relay order in
          // disguise: a "last one wins" rule also answers creatorB for the
          // first order alone, so one ordering cannot tell the two apart.
          stubRead([higherId, lowerId]);
          final higherFirst = await repository.readSubscriptions(
            ownerPubkey: ownerPubkey,
          );

          final reversedClient = _MockNostrClient();
          when(() => reversedClient.queryEventsDetailed(any())).thenAnswer(
            (_) async => _readResult([lowerId, higherId]),
          );
          final reversedRepository = NotifySubscriptionsRepositoryImpl(
            nostrClient: reversedClient,
          );
          addTearDown(reversedRepository.dispose);
          final lowerFirst = await reversedRepository.readSubscriptions(
            ownerPubkey: ownerPubkey,
          );

          expect(higherFirst, equals({creatorB}));
          expect(lowerFirst, equals(higherFirst));
        },
      );

      test('replaces a stale snapshot and emits the new set', () async {
        var events = [
          _notifyEvent([creatorA]),
        ];
        when(
          () => client.queryEventsDetailed(any()),
        ).thenAnswer((_) async => _readResult(events));

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
        );

        // The list changed elsewhere — another device, or another client.
        events = [
          _notifyEvent([creatorB], createdAt: 1710000900),
        ];

        final emitted = <Set<String>>[];
        final subscription = repository
            .watchSubscriptions(ownerPubkey: ownerPubkey)
            .listen(emitted.add);
        addTearDown(subscription.cancel);

        await repository.refresh(ownerPubkey: ownerPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorB}),
        );
        expect(emitted.last, equals({creatorB}));
      });

      test('keeps the last good snapshot when the re-read fails', () async {
        var reads = 0;
        when(() => client.queryEventsDetailed(any())).thenAnswer((_) async {
          reads++;
          if (reads == 1) {
            return _readResult([
              _notifyEvent([creatorA]),
            ]);
          }
          return _readResult(const [], noRelays: true);
        });

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
        );

        await repository.refresh(ownerPubkey: ownerPubkey);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
          reason: 'a failed re-read must not clear the known subscriptions',
        );
      });
    });

    group('watchSubscriptions', () {
      test('emits the loaded set then each mutation', () async {
        stubRead([
          _notifyEvent([creatorA]),
        ]);
        stubPublishSuccess();

        final emitted = <Set<String>>[];
        final subscription = repository
            .watchSubscriptions(ownerPubkey: ownerPubkey)
            .listen(emitted.add);
        addTearDown(subscription.cancel);

        await repository.readSubscriptions(ownerPubkey: ownerPubkey);
        await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorB,
        );
        await Future<void>.delayed(Duration.zero);

        expect(emitted.last, equals({creatorA, creatorB}));
        expect(
          emitted,
          contains(equals({creatorA})),
          reason: 'a late listener must see the loaded set, not only changes',
        );
      });
    });
  });
}
