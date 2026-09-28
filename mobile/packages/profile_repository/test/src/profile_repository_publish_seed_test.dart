// ABOUTME: Pins how saveProfileEvent seeds a Kind 0 republish. A save defers
// ABOUTME: rather than replace a relay copy it could not read, and a raw read
// ABOUTME: that proved nothing never sticks as "no Kind 0" for the session.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockHttpClient extends Mock implements Client {}

typedef _RelayRead = ({List<Event> events, bool timedOut, bool noRelays});

void main() {
  group('ProfileRepository publish seed', () {
    const pubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const vineId = '1111111111111111111';

    // The tag set a Vine archive import publishes on its Kind 0. None of it
    // is content, so the profile cache cannot hold it.
    final relayTags = <List<String>>[
      ['i', 'vine:$vineId'],
      ['vine_user_id', vineId],
      ['vine_username', 'ExampleViner'],
      ['origin', 'vine', vineId, 'https://vine.co/u/$vineId'],
      ['client', 'vine-archive-importer'],
      ['vine_followers', '4213'],
      ['vine_loops', '99871'],
    ];

    Event relayKind0({int createdAt = 1790000000, String name = 'Before'}) =>
        Event(
          pubkey,
          0,
          relayTags,
          jsonEncode({'name': 'exampleviner', 'display_name': name}),
          createdAt: createdAt,
        );

    Event indexerKind0({int createdAt = 1790000000}) => Event(
      pubkey,
      0,
      const [],
      jsonEncode({'display_name': 'Indexer copy'}),
      createdAt: createdAt,
    );

    const answered = (events: <Event>[], timedOut: false, noRelays: false);

    late AppDatabase db;
    late _MockNostrClient client;
    late ProfileRepository repository;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      client = _MockNostrClient();
      repository = ProfileRepository(
        nostrClient: client,
        userProfilesDao: db.userProfilesDao,
        httpClient: _MockHttpClient(),
        pendingProfileSavesDao: db.pendingProfileSavesDao,
      );
      when(() => client.publicKey).thenReturn(pubkey);
      // The indexer read can only add a copy, so it answers nothing here and
      // the connected read alone decides each case.
      when(
        () => client.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => <Event>[]);
      when(
        () => client.sendProfileAwaitOk(
          profileContent: any(named: 'profileContent'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: Event(
            pubkey,
            0,
            invocation.namedArguments[#tags] as List<List<String>>,
            jsonEncode(invocation.namedArguments[#profileContent]),
          ),
        ),
      );
    });

    tearDown(() async => db.close());

    void stubRelayRead(Future<_RelayRead> Function() answer) {
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((_) => answer());
    }

    int relayReads() => verify(
      () => client.queryEventsDetailed(
        any(),
        useCache: any(named: 'useCache'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
      ),
    ).callCount;

    /// Caches [event] the way a relay fetch does and reads it back, which is
    /// where a profile loses its tags: `user_profiles` stores none.
    Future<UserProfile> cacheAndReadBack(Event event) async {
      await repository.cacheProfile(UserProfile.fromNostrEvent(event));
      final cached = await repository.getCachedProfile(pubkey: pubkey);
      expect(cached!.eventId, equals(event.id));
      expect(cached.rawTags, isEmpty);
      return cached;
    }

    List<List<String>> publishedTags() =>
        verify(
              () => client.sendProfileAwaitOk(
                profileContent: any(named: 'profileContent'),
                tags: captureAny(named: 'tags'),
              ),
            ).captured.single
            as List<List<String>>;

    void expectNoPublish() => verifyNever(
      () => client.sendProfileAwaitOk(
        profileContent: any(named: 'profileContent'),
        tags: any(named: 'tags'),
      ),
    );

    group('saveProfileEvent', () {
      test('republishes the relay copy with its tags', () async {
        final cached = await cacheAndReadBack(relayKind0());
        stubRelayRead(
          () async => (
            events: [relayKind0()],
            timedOut: false,
            noRelays: false,
          ),
        );

        await repository.saveProfileEvent(
          displayName: 'After',
          currentProfile: cached,
        );

        expect(publishedTags(), equals(relayTags));
      });

      test(
        'defers instead of republishing when the relay read times out',
        () async {
          final cached = await cacheAndReadBack(relayKind0());
          stubRelayRead(
            () async => (events: <Event>[], timedOut: true, noRelays: false),
          );

          await expectLater(
            repository.saveProfileEvent(
              displayName: 'After',
              currentProfile: cached,
            ),
            throwsA(isA<ProfilePublishFailedException>()),
          );
          expectNoPublish();
        },
      );

      test('defers when no relay took the read', () async {
        final cached = await cacheAndReadBack(relayKind0());
        stubRelayRead(
          () async => (events: <Event>[], timedOut: false, noRelays: true),
        );

        await expectLater(
          repository.saveProfileEvent(
            displayName: 'After',
            currentProfile: cached,
          ),
          throwsA(isA<ProfilePublishFailedException>()),
        );
        expectNoPublish();
      });

      test('defers when the relay read throws', () async {
        final cached = await cacheAndReadBack(relayKind0());
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenThrow(Exception('socket closed'));

        await expectLater(
          repository.saveProfileEvent(
            displayName: 'After',
            currentProfile: cached,
          ),
          throwsA(isA<ProfilePublishFailedException>()),
        );
        expectNoPublish();
      });

      test('defers when the relay read outlasts the save budget', () async {
        final cached = await cacheAndReadBack(relayKind0());
        fakeAsync((async) {
          stubRelayRead(() => Completer<_RelayRead>().future);
          Object? failure;
          unawaited(
            repository
                .saveProfileEvent(displayName: 'After', currentProfile: cached)
                .then<void>((_) {}, onError: (Object e) => failure = e),
          );

          async
            ..elapse(const Duration(seconds: 3, milliseconds: 999))
            ..flushMicrotasks();
          expect(failure, isNull);

          async
            ..elapse(const Duration(milliseconds: 2))
            ..flushMicrotasks();
          expect(failure, isA<ProfilePublishFailedException>());
          expectNoPublish();
        });
      });

      test(
        'defers a first save with no local copy when the read is inconclusive',
        () async {
          stubRelayRead(
            () async => (events: <Event>[], timedOut: true, noRelays: false),
          );

          await expectLater(
            repository.saveProfileEvent(displayName: 'First'),
            throwsA(isA<ProfilePublishFailedException>()),
          );
          expectNoPublish();
        },
      );

      test(
        'publishes from the local copy when every relay answered with none',
        () async {
          final cached = await cacheAndReadBack(relayKind0());
          stubRelayRead(() async => answered);

          await repository.saveProfileEvent(
            displayName: 'After',
            currentProfile: cached,
          );

          expect(publishedTags(), isEmpty);
        },
      );

      test('does not wait for a hanging indexer after connected relays confirm '
          'there is no Kind 0', () {
        final indexerRead = Completer<List<Event>>();
        when(
          () => client.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) => indexerRead.future);
        stubRelayRead(() async => answered);

        fakeAsync((async) {
          var completed = false;
          Object? failure;
          unawaited(
            repository
                .saveProfileEvent(displayName: 'First')
                .then<void>(
                  (_) => completed = true,
                  onError: (Object error) => failure = error,
                ),
          );

          async.flushMicrotasks();
          expect(completed, isTrue);
          expect(failure, isNull);
          expect(publishedTags(), isEmpty);

          indexerRead.complete(<Event>[]);
          async.flushMicrotasks();
        });
      });

      test('defers when the cached copy is newer than the relay copy but '
          'cannot carry its tags', () async {
        // The first save landed T1 and the cache holds it, tagless. The relay
        // still serves T0 because it has not indexed T1 yet.
        final cachedT1 = await cacheAndReadBack(
          relayKind0(createdAt: 1790000100, name: 'Edited once'),
        );
        stubRelayRead(
          () async => (
            events: [relayKind0()],
            timedOut: false,
            noRelays: false,
          ),
        );

        await expectLater(
          repository.saveProfileEvent(
            displayName: 'Edited twice',
            currentProfile: cachedT1,
          ),
          throwsA(isA<ProfilePublishFailedException>()),
        );
        expectNoPublish();
      });

      test(
        'waits for connected relays before choosing over an older indexer',
        () async {
          final cachedT1 = await cacheAndReadBack(
            relayKind0(createdAt: 1790000100, name: 'Edited once'),
          );
          final connectedRead = Completer<_RelayRead>();
          stubRelayRead(() => connectedRead.future);
          when(
            () => client.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [indexerKind0()]);

          final save = repository.saveProfileEvent(
            displayName: 'Edited twice',
            currentProfile: cachedT1,
          );
          await Future<void>.delayed(Duration.zero);
          connectedRead.complete((
            events: [relayKind0()],
            timedOut: false,
            noRelays: false,
          ));

          await expectLater(
            save,
            throwsA(isA<ProfilePublishFailedException>()),
          );
          expectNoPublish();
        },
      );

      test(
        'defers when a timed-out raw read contains a partial profile',
        () async {
          final cached = await cacheAndReadBack(relayKind0());
          stubRelayRead(
            () async =>
                (events: [relayKind0()], timedOut: true, noRelays: false),
          );

          await expectLater(
            repository.saveProfileEvent(
              displayName: 'After',
              currentProfile: cached,
            ),
            throwsA(isA<ProfilePublishFailedException>()),
          );
          expectNoPublish();
        },
      );

      test('publishes a newer local copy that carries its own tags', () async {
        final inMemoryT1 = UserProfile.fromNostrEvent(
          relayKind0(createdAt: 1790000100, name: 'Edited once'),
        );
        stubRelayRead(
          () async => (
            events: [relayKind0()],
            timedOut: false,
            noRelays: false,
          ),
        );

        await repository.saveProfileEvent(
          displayName: 'Edited twice',
          currentProfile: inMemoryT1,
        );

        expect(publishedTags(), equals(relayTags));
      });
    });

    group('drivePendingSave', () {
      test('re-reads the relays on the retry after an offline failure, '
          'and keeps the tags', () async {
        await cacheAndReadBack(relayKind0());
        stubRelayRead(
          () async => (events: <Event>[], timedOut: false, noRelays: true),
        );
        await repository.enqueuePendingSave(
          const PendingProfileSave(pubkey: pubkey, displayName: 'After'),
          claimConfirmed: true,
        );

        expect(
          await repository.drivePendingSave(pubkey),
          equals(PendingSaveDriveOutcome.retryableFailure),
        );
        expectNoPublish();

        stubRelayRead(
          () async => (
            events: [relayKind0()],
            timedOut: false,
            noRelays: false,
          ),
        );
        expect(
          await repository.drivePendingSave(pubkey),
          equals(PendingSaveDriveOutcome.confirmed),
        );
        expect(publishedTags(), equals(relayTags));
      });
    });

    group('fetchFreshProfile with requireRawKind0', () {
      test('upgrades the cache when a newer indexer copy arrives after the '
          'connected read', () async {
        final indexerRead = Completer<List<Event>>();
        when(
          () => client.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) => indexerRead.future);
        stubRelayRead(
          () async => (
            events: [relayKind0()],
            timedOut: false,
            noRelays: false,
          ),
        );

        final fresh = await repository.fetchFreshProfile(
          pubkey: pubkey,
          requireRawKind0: true,
        );
        expect(fresh?.displayName, equals('Before'));

        indexerRead.complete([indexerKind0(createdAt: 1790000100)]);
        await Future<void>.delayed(Duration.zero);

        final cached = await repository.getCachedProfile(pubkey: pubkey);
        expect(cached?.displayName, equals('Indexer copy'));
        expect(
          cached?.createdAt,
          equals(
            DateTime.fromMillisecondsSinceEpoch(
              1790000100 * 1000,
            ),
          ),
        );
      });

      test('asks the relays again after a read that timed out', () async {
        stubRelayRead(
          () async => (events: <Event>[], timedOut: true, noRelays: false),
        );

        final first = await repository.fetchFreshProfile(
          pubkey: pubkey,
          requireRawKind0: true,
        );
        final second = await repository.fetchFreshProfile(
          pubkey: pubkey,
          requireRawKind0: true,
        );

        expect(first, isNull);
        expect(second, isNull);
        expect(relayReads(), equals(2));
      });

      test('stops asking once every relay answered with no Kind 0', () async {
        stubRelayRead(() async => answered);

        final first = await repository.fetchFreshProfile(
          pubkey: pubkey,
          requireRawKind0: true,
        );
        final second = await repository.fetchFreshProfile(
          pubkey: pubkey,
          requireRawKind0: true,
        );

        expect(first, isNull);
        expect(second, isNull);
        expect(relayReads(), equals(1));
      });
    });
  });
}
