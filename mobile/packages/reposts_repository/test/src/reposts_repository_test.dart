import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockRepostsLocalStorage extends Mock implements RepostsLocalStorage {}

class MockEvent extends Mock implements Event {}

class FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeEvent());
    registerFallbackValue(
      RepostRecord(
        addressableId: 'addressableId',
        repostEventId: 'repostEventId',
        originalAuthorPubkey: 'originalAuthorPubkey',
        createdAt: DateTime.now(),
      ),
    );
    registerFallbackValue(<Filter>[]);
    registerFallbackValue('');
  });

  group('RepostsRepository', () {
    late MockNostrClient mockNostrClient;
    late MockRepostsLocalStorage mockLocalStorage;

    const testPubkey =
        'test_pubkey_hex_64_chars_'
        '00000000000000000000000000000000000000';
    const testEventId =
        'test_event_id_64_chars_00'
        '000000000000000000000000000000000000000';
    const testAddressableId = '34236:author_pubkey:test-dtag';
    const testAuthorPubkey = 'author_pubkey';
    const testRepostEventId =
        'repost_event_id_64_chars_'
        '000000000000000000000000000000000000000';

    Event createMockEvent({
      required String id,
      required int kind,
      required int createdAt,
      List<List<String>> tags = const [],
    }) {
      final event = MockEvent();
      when(() => event.id).thenReturn(id);
      when(() => event.kind).thenReturn(kind);
      when(() => event.createdAt).thenReturn(createdAt);
      when(() => event.tags).thenReturn(tags);
      when(() => event.pubkey).thenReturn(testPubkey);
      when(() => event.content).thenReturn('');
      when(() => event.sig).thenReturn('');
      return event;
    }

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockLocalStorage = MockRepostsLocalStorage();

      when(() => mockNostrClient.publicKey).thenReturn(testPubkey);
      when(
        () => mockNostrClient.resolvePublicKey(),
      ).thenAnswer((_) async => testPubkey);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      // Default sendGenericRepost mock - returns a valid event
      when(
        () => mockNostrClient.sendGenericRepost(
          addressableId: any(named: 'addressableId'),
          targetKind: any(named: 'targetKind'),
          authorPubkey: any(named: 'authorPubkey'),
          content: any(named: 'content'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => createMockEvent(
          id: testRepostEventId,
          kind: EventKind.genericRepost,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          tags: [
            ['k', '${EventKind.videoVertical}'],
            ['a', testAddressableId],
            ['p', testAuthorPubkey],
          ],
        ),
      );

      // Default local storage mocks
      when(
        () => mockLocalStorage.getAllRepostRecords(),
      ).thenAnswer((_) async => []);
      when(
        () => mockLocalStorage.saveRepostRecord(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalStorage.saveRepostRecordsBatch(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalStorage.deleteRepostRecord(any()),
      ).thenAnswer((_) async => true);
      when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});
      when(
        () => mockLocalStorage.isReposted(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockLocalStorage.getRepostRecord(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockLocalStorage.watchRepostedAddressableIds(),
      ).thenAnswer((_) => Stream.value({}));
    });

    group('constructor', () {
      test('can be instantiated with required parameters', () {
        final repository = RepostsRepository(nostrClient: mockNostrClient);
        expect(repository, isNotNull);
      });

      test('can be instantiated with all parameters', () {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => true,
        );
        expect(repository, isNotNull);
      });
    });

    group('isRepostedSync', () {
      test('returns false for non-reposted video', () {
        final repository = RepostsRepository(nostrClient: mockNostrClient);
        expect(repository.isRepostedSync(testAddressableId), isFalse);
      });

      test('returns true for reposted video in cache', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);
      });
    });

    group('isReposted', () {
      test('returns false for non-reposted video', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);
        expect(await repository.isReposted(testAddressableId), isFalse);
      });

      test('returns true after reposting', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(await repository.isReposted(testAddressableId), isTrue);
      });

      test('initializes from local storage', () async {
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testAuthorPubkey,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenAnswer((_) async => [record]);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        expect(await repository.isReposted(testAddressableId), isTrue);
      });
    });

    group('getRepostedAddressableIds', () {
      test('returns empty set when no reposts', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);
        expect(await repository.getRepostedAddressableIds(), isEmpty);
      });

      test('returns set of reposted IDs', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        final ids = await repository.getRepostedAddressableIds();
        expect(ids, contains(testAddressableId));
        expect(ids.length, equals(1));
      });
    });

    group('getOrderedRepostedAddressableIds', () {
      test('returns empty list when no reposts', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);
        expect(await repository.getOrderedRepostedAddressableIds(), isEmpty);
      });

      test('returns IDs ordered by recency (most recent first)', () async {
        final now = DateTime.now();
        final records = [
          RepostRecord(
            addressableId: '34236:author1:video1',
            repostEventId: 'event1',
            originalAuthorPubkey: 'author1',
            createdAt: now.subtract(const Duration(days: 2)),
          ),
          RepostRecord(
            addressableId: '34236:author2:video2',
            repostEventId: 'event2',
            originalAuthorPubkey: 'author2',
            createdAt: now.subtract(const Duration(days: 1)),
          ),
          RepostRecord(
            addressableId: '34236:author3:video3',
            repostEventId: 'event3',
            originalAuthorPubkey: 'author3',
            createdAt: now,
          ),
        ];

        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenAnswer((_) async => records);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final orderedIds = await repository.getOrderedRepostedAddressableIds();

        expect(orderedIds, hasLength(3));
        expect(orderedIds[0], equals('34236:author3:video3'));
        expect(orderedIds[1], equals('34236:author2:video2'));
        expect(orderedIds[2], equals('34236:author1:video1'));
      });
    });

    group('unavailable local storage', () {
      // The local database is a cache, not a precondition. When it is
      // unreadable (at-rest cipher bootstrap left it unopenable, runtime
      // corruption, disk full) the Kind 16 must still reach relays: the signed
      // event is the irreplaceable half of the operation, the cache row is not.
      // Regression for the SQLITE_NOTADB launch where every repost threw
      // before `sendGenericRepost` was ever called.
      final storageFailure = Exception('database is unavailable');

      test('publishes the repost when local storage cannot be read', () async {
        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenThrow(storageFailure);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final eventId = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(eventId, equals(testRepostEventId));
        verify(
          () => mockNostrClient.sendGenericRepost(
            addressableId: testAddressableId,
            targetKind: EventKind.videoVertical,
            authorPubkey: testAuthorPubkey,
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test('publishes the repost when the local write fails', () async {
        when(
          () => mockLocalStorage.saveRepostRecord(any()),
        ).thenThrow(storageFailure);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final eventId = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(eventId, equals(testRepostEventId));
        verify(
          () => mockNostrClient.sendGenericRepost(
            addressableId: testAddressableId,
            targetKind: EventKind.videoVertical,
            authorPubkey: testAuthorPubkey,
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test(
        'a failed read does not strand the repository uninitialized',
        () async {
          // Without this the `_isInitialized` latch never flips and every call
          // re-runs the throwing read — the retry storm that filled the report
          // with 26 identical failures for two taps.
          when(
            () => mockLocalStorage.getAllRepostRecords(),
          ).thenThrow(storageFailure);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          await repository.getRepostedAddressableIds();
          await repository.getRepostedAddressableIds();

          verify(() => mockLocalStorage.getAllRepostRecords()).called(1);
        },
      );

      test('publishes the deletion when the local delete fails', () async {
        when(
          () => mockLocalStorage.deleteRepostRecord(any()),
        ).thenThrow(storageFailure);
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: EventKind.eventDeletion,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // Establish the record in memory so the deletion knows which event id
        // to reference; an unknown repost still throws NotRepostedException.
        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        await repository.unrepostVideo(testAddressableId);

        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
      });

      test(
        'reports an invariant violation raised by a storage write',
        () async {
          // An Error from the storage layer means the storage layer itself is
          // broken. Still swallowed so the Kind 16 goes out, but routed to the
          // reporter — a swallowed bug nobody can see is how a real defect
          // ships behind a warning log.
          final reported = <({Object error, String site})>[];
          when(
            () => mockLocalStorage.saveRepostRecord(any()),
          ).thenThrow(StateError('storage invariant violated'));

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
            errorReporter: (error, stackTrace, {required site}) {
              reported.add((error: error, site: site));
            },
          );

          await repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          expect(reported, hasLength(2));
          expect(reported.first.error, isA<StateError>());
          expect(
            reported.map((r) => r.site),
            equals([
              RepostsRepositoryReportableSites.repostVideoSavePlaceholder,
              RepostsRepositoryReportableSites.repostVideoSaveConfirmed,
            ]),
          );
        },
      );

      test(
        'reports an invariant violation raised by the initial read',
        () async {
          final reported = <String>[];
          when(
            () => mockLocalStorage.getAllRepostRecords(),
          ).thenThrow(TypeError());

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
            errorReporter: (error, stackTrace, {required site}) {
              reported.add(site);
            },
          );

          await repository.getRepostedAddressableIds();

          expect(
            reported,
            equals([
              RepostsRepositoryReportableSites.ensureInitializedLoadRecords,
            ]),
          );
        },
      );

      test('does not report an expected storage failure', () async {
        // SqliteException and friends are Exceptions, not Errors: expected on
        // a broken device and explicitly not Crashlytics-reportable per the
        // decision matrix in `.claude/rules/error_handling.md`.
        var reportCount = 0;
        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenThrow(storageFailure);
        when(
          () => mockLocalStorage.saveRepostRecord(any()),
        ).thenThrow(storageFailure);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          errorReporter: (error, stackTrace, {required site}) {
            reportCount++;
          },
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(reportCount, isZero);
      });

      test('publishes the repost when the toggle state read fails', () async {
        // The repost button only ever reaches the repository through
        // toggleRepost (video_interactions_bloc.dart), so a storage read
        // that throws there costs the Kind 16 just as surely as one inside
        // repostVideo. repostVideo's own guard never gets a chance to run.
        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenThrow(storageFailure);
        when(
          () => mockLocalStorage.isReposted(any()),
        ).thenThrow(storageFailure);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final isNowReposted = await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(isNowReposted, isTrue);
        verify(
          () => mockNostrClient.sendGenericRepost(
            addressableId: testAddressableId,
            targetKind: EventKind.videoVertical,
            authorPubkey: testAuthorPubkey,
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test('unreposts from the in-memory cache when the read fails', () async {
        // The swallowed read must fall back to the cache, not to "not
        // reposted" — otherwise the toggle publishes a duplicate Kind 16
        // instead of deleting the live one.
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: EventKind.eventDeletion,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );
        when(
          () => mockLocalStorage.isReposted(any()),
        ).thenThrow(storageFailure);

        final isNowReposted = await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(isNowReposted, isFalse);
        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
      });

      test('syncs from relays when the persisted read fails', () async {
        // The relay half is the authoritative one. A cache read that throws
        // used to escape syncUserReposts before the fetch below ever ran,
        // so the profile Reposts tab errored while relays were reachable.
        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenThrow(storageFailure);
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            createMockEvent(
              id: testRepostEventId,
              kind: EventKind.genericRepost,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              tags: [
                ['a', testAddressableId],
                ['p', testAuthorPubkey],
              ],
            ),
          ],
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReposts();

        expect(result.orderedAddressableIds, equals([testAddressableId]));
      });

      test('completes the sync when the batch save fails', () async {
        when(
          () => mockLocalStorage.saveRepostRecordsBatch(any()),
        ).thenThrow(storageFailure);
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            createMockEvent(
              id: testRepostEventId,
              kind: EventKind.genericRepost,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              tags: [
                ['a', testAddressableId],
                ['p', testAuthorPubkey],
              ],
            ),
          ],
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReposts();

        expect(result.orderedAddressableIds, equals([testAddressableId]));
      });

      test('still subscribes when the startup read fails', () async {
        // initialize() reads storage before _subscribeToReposts, so a throw
        // there costs the session its cross-device sync too.
        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenThrow(storageFailure);
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.initialize();

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1);
      });

      test('caches a subscription repost when its write fails', () async {
        // The write is fire-and-forget, so an unguarded rejection would be
        // an uncaught async error rather than a swallowed cache miss.
        final controller = StreamController<Event>();
        addTearDown(controller.close);
        when(
          () => mockLocalStorage.saveRepostRecord(any()),
        ).thenThrow(storageFailure);
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.initialize();

        controller.add(
          createMockEvent(
            id: testRepostEventId,
            kind: EventKind.genericRepost,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            tags: [
              ['a', testAddressableId],
              ['p', testAuthorPubkey],
            ],
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(repository.isRepostedSync(testAddressableId), isTrue);
      });
    });

    group('repostVideo', () {
      test('creates and publishes Kind 16 event', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final eventId = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(eventId, equals(testRepostEventId));

        verify(
          () => mockNostrClient.sendGenericRepost(
            addressableId: testAddressableId,
            targetKind: EventKind.videoVertical,
            authorPubkey: testAuthorPubkey,
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test(
        'saves placeholder then confirmed record to local storage',
        () async {
          final captured = <RepostRecord>[];
          when(() => mockLocalStorage.saveRepostRecord(any())).thenAnswer((
            invocation,
          ) async {
            captured.add(invocation.positionalArguments[0] as RepostRecord);
          });

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          await repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          // Optimistic-first: placeholder is persisted before publish so the
          // record survives an app crash mid-publish; confirmed record swaps
          // the placeholder id for the real reaction id once relays return.
          expect(captured, hasLength(2));
          expect(captured[0].repostEventId, startsWith('pending_repost_'));
          expect(captured[1].repostEventId, equals(testRepostEventId));
        },
      );

      test(
        'ticks watchRepostedAddressableIds before sendGenericRepost completes',
        () async {
          // Make sendGenericRepost block until we tell it to complete, so we
          // can assert the stream tick races ahead of the network publish.
          final publishCompleter = Completer<Event?>();
          when(
            () => mockNostrClient.sendGenericRepost(
              addressableId: any(named: 'addressableId'),
              targetKind: any(named: 'targetKind'),
              authorPubkey: any(named: 'authorPubkey'),
              content: any(named: 'content'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) => publishCompleter.future);

          final repository = RepostsRepository(nostrClient: mockNostrClient);

          final emitted = <Set<String>>[];
          final subscription = repository.watchRepostedAddressableIds().listen(
            emitted.add,
          );

          final repostFuture = repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          // Yield so the optimistic stream tick is delivered to listeners.
          await Future<void>.delayed(Duration.zero);

          expect(
            emitted.last,
            contains(testAddressableId),
            reason: 'stream must tick before publish completes',
          );

          publishCompleter.complete(
            createMockEvent(
              id: testRepostEventId,
              kind: EventKind.genericRepost,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          );
          await repostFuture;
          await subscription.cancel();
        },
      );

      test('throws AlreadyRepostedException when already reposted', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(
          () => repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<AlreadyRepostedException>()),
        );
      });

      test(
        'throws RepostFailedException when sendGenericRepost returns null',
        () async {
          when(
            () => mockNostrClient.sendGenericRepost(
              addressableId: any(named: 'addressableId'),
              targetKind: any(named: 'targetKind'),
              authorPubkey: any(named: 'authorPubkey'),
              content: any(named: 'content'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => null);

          final repository = RepostsRepository(nostrClient: mockNostrClient);

          await expectLater(
            repository.repostVideo(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
            ),
            throwsA(isA<RepostFailedException>()),
          );
        },
      );

      test(
        'rolls back record + count + stream when publish returns null',
        () async {
          when(
            () => mockNostrClient.countEvents(any()),
          ).thenAnswer((_) async => const CountResult(count: 4));
          when(
            () => mockNostrClient.sendGenericRepost(
              addressableId: any(named: 'addressableId'),
              targetKind: any(named: 'targetKind'),
              authorPubkey: any(named: 'authorPubkey'),
              content: any(named: 'content'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => null);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          // Seed count cache with the relay value so the rollback has
          // something to restore to.
          await repository.getRepostCount(testAddressableId);

          await expectLater(
            repository.repostVideo(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
            ),
            throwsA(isA<RepostFailedException>()),
          );

          // Memory + storage: record is gone after rollback.
          expect(repository.isRepostedSync(testAddressableId), isFalse);
          verify(
            () => mockLocalStorage.deleteRepostRecord(testAddressableId),
          ).called(1);

          // Count cache: restored to pre-tap value (no second relay query).
          final count = await repository.getRepostCount(testAddressableId);
          expect(count, equals(4));
          verify(() => mockNostrClient.countEvents(any())).called(1);
        },
      );

      test('rolls back record + count + stream when publish throws', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 4));
        when(
          () => mockNostrClient.sendGenericRepost(
            addressableId: any(named: 'addressableId'),
            targetKind: any(named: 'targetKind'),
            authorPubkey: any(named: 'authorPubkey'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenThrow(Exception('relay unreachable'));

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.getRepostCount(testAddressableId);

        await expectLater(
          repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<Exception>()),
        );

        expect(repository.isRepostedSync(testAddressableId), isFalse);
        final count = await repository.getRepostCount(testAddressableId);
        expect(count, equals(4));
      });

      // Defense-in-depth: when the publish fails but the offline-action
      // callback is wired, the optimistic repost must be preserved and
      // the action queued for retry. Mirror of the LikesRepository test.
      test(
        'queues offline action and preserves optimistic state when '
        'sendGenericRepost returns null and queueOfflineAction is wired',
        () async {
          when(
            () => mockNostrClient.sendGenericRepost(
              addressableId: any(named: 'addressableId'),
              targetKind: any(named: 'targetKind'),
              authorPubkey: any(named: 'authorPubkey'),
              content: any(named: 'content'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => null);

          var queueCalls = 0;
          String? queuedAddressableId;
          bool? queuedIsRepost;
          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
            isOnline: () => true,
            queueOfflineAction:
                ({
                  required isRepost,
                  required addressableId,
                  required originalAuthorPubkey,
                  eventId,
                }) async {
                  queueCalls++;
                  queuedAddressableId = addressableId;
                  queuedIsRepost = isRepost;
                },
          );

          final result = await repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          expect(
            result,
            equals('pending_repost_$testAddressableId'),
            reason: 'must return placeholder ID, not throw',
          );
          expect(queueCalls, equals(1));
          expect(queuedAddressableId, equals(testAddressableId));
          expect(queuedIsRepost, isTrue);
          expect(
            repository.isRepostedSync(testAddressableId),
            isTrue,
            reason: 'optimistic state must be preserved across the failure',
          );
          verifyNever(() => mockLocalStorage.deleteRepostRecord(any()));
        },
      );

      test('queues offline action when sendGenericRepost throws and '
          'queueOfflineAction is wired', () async {
        when(
          () => mockNostrClient.sendGenericRepost(
            addressableId: any(named: 'addressableId'),
            targetKind: any(named: 'targetKind'),
            authorPubkey: any(named: 'authorPubkey'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenThrow(Exception('relay closed'));

        var queueCalls = 0;
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => true,
          queueOfflineAction:
              ({
                required isRepost,
                required addressableId,
                required originalAuthorPubkey,
                eventId,
              }) async {
                queueCalls++;
              },
        );

        final result = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(result, equals('pending_repost_$testAddressableId'));
        expect(queueCalls, equals(1));
        expect(repository.isRepostedSync(testAddressableId), isTrue);
      });
    });

    group('unrepostVideo', () {
      test('publishes deletion event and removes record', () async {
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);

        await repository.unrepostVideo(testAddressableId);

        expect(repository.isRepostedSync(testAddressableId), isFalse);
        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
        verify(
          () => mockLocalStorage.deleteRepostRecord(testAddressableId),
        ).called(1);
      });

      test('throws NotRepostedException when not reposted', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        expect(
          () => repository.unrepostVideo(testAddressableId),
          throwsA(isA<NotRepostedException>()),
        );
      });

      test('checks local storage when not in cache', () async {
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testAuthorPubkey,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getRepostRecord(testAddressableId),
        ).thenAnswer((_) async => record);
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.unrepostVideo(testAddressableId);

        verify(
          () => mockLocalStorage.getRepostRecord(testAddressableId),
        ).called(1);
        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
      });

      test('throws UnrepostFailedException when deletion fails', () async {
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => null);

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(
          () => repository.unrepostVideo(testAddressableId),
          throwsA(isA<UnrepostFailedException>()),
        );
      });

      test(
        'translates typed relay failures to UnrepostFailedException',
        () async {
          final failedEvent = createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
          when(() => mockNostrClient.deleteEvent(any())).thenThrow(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.noResponse,
                event: failedEvent,
              ),
            ),
          );
          final repository = RepostsRepository(nostrClient: mockNostrClient);
          await repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          await expectLater(
            repository.unrepostVideo(testAddressableId),
            throwsA(isA<UnrepostFailedException>()),
          );
        },
      );

      test(
        'ticks watchRepostedAddressableIds before deleteEvent completes',
        () async {
          // Seed a record by reposting first.
          final repository = RepostsRepository(nostrClient: mockNostrClient);
          await repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          final deleteCompleter = Completer<Event?>();
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer((_) => deleteCompleter.future);

          final emitted = <Set<String>>[];
          final subscription = repository.watchRepostedAddressableIds().listen(
            emitted.add,
          );

          final unrepostFuture = repository.unrepostVideo(testAddressableId);
          await Future<void>.delayed(Duration.zero);

          expect(
            emitted.last,
            isNot(contains(testAddressableId)),
            reason: 'stream must tick the removal before deleteEvent completes',
          );

          deleteCompleter.complete(
            createMockEvent(
              id: 'deletion_event_id',
              kind: EventKind.eventDeletion,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          );
          await unrepostFuture;
          await subscription.cancel();
        },
      );

      test(
        'rolls back record + count + stream when deletion returns null',
        () async {
          when(
            () => mockNostrClient.countEvents(any()),
          ).thenAnswer((_) async => const CountResult(count: 7));
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => null);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          // Seed a record + count cache so the rollback has something to
          // restore. countEvents mock returns 7 for the seed; after the
          // optimistic increment inside repostVideo it becomes 8.
          await repository.getRepostCount(testAddressableId);
          await repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          await expectLater(
            repository.unrepostVideo(testAddressableId),
            throwsA(isA<UnrepostFailedException>()),
          );

          // Memory: record restored after rollback.
          expect(repository.isRepostedSync(testAddressableId), isTrue);
          // Count cache: restored to the pre-unrepost value (8 after
          // the repost increment), no extra relay query.
          final count = await repository.getRepostCount(testAddressableId);
          expect(count, equals(8));
          verify(() => mockNostrClient.countEvents(any())).called(1);
        },
      );

      test('rolls back record + count + stream when deletion throws', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 7));
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenThrow(Exception('relay unreachable'));

        final repository = RepostsRepository(nostrClient: mockNostrClient);
        await repository.getRepostCount(testAddressableId);
        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        await expectLater(
          repository.unrepostVideo(testAddressableId),
          throwsA(isA<Exception>()),
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);
        final count = await repository.getRepostCount(testAddressableId);
        expect(count, equals(8));
      });

      // Defense-in-depth (mirror of repostVideo): when the kind-5 deletion
      // fails but the offline-action callback is wired, the optimistic
      // unrepost must be preserved and the action queued for retry.
      test('queues offline action and preserves optimistic removal when '
          'deleteEvent returns null and queueOfflineAction is wired', () async {
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => null);

        var queueCalls = 0;
        bool? queuedIsRepost;
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => true,
          queueOfflineAction:
              ({
                required isRepost,
                required addressableId,
                required originalAuthorPubkey,
                eventId,
              }) async {
                queueCalls++;
                queuedIsRepost = isRepost;
              },
        );
        // Establish a real (non-pending) repost record to delete.
        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        await repository.unrepostVideo(testAddressableId);

        expect(queueCalls, equals(1));
        expect(queuedIsRepost, isFalse);
        expect(
          repository.isRepostedSync(testAddressableId),
          isFalse,
          reason: 'optimistic removal must be preserved',
        );
      });

      test('queues offline action when deleteEvent throws and '
          'queueOfflineAction is wired', () async {
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenThrow(Exception('relay closed'));

        var queueCalls = 0;
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => true,
          queueOfflineAction:
              ({
                required isRepost,
                required addressableId,
                required originalAuthorPubkey,
                eventId,
              }) async {
                queueCalls++;
              },
        );
        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        await repository.unrepostVideo(testAddressableId);

        expect(queueCalls, equals(1));
        expect(repository.isRepostedSync(testAddressableId), isFalse);
      });
    });

    group('toggleRepost', () {
      test('reposts when not reposted and returns true', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final result = await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(result, isTrue);
        expect(repository.isRepostedSync(testAddressableId), isTrue);
      });

      test('unreposts when reposted and returns false', () async {
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        final result = await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(result, isFalse);
        expect(repository.isRepostedSync(testAddressableId), isFalse);
      });

      test('checks local storage for repost status', () async {
        when(
          () => mockLocalStorage.isReposted(testAddressableId),
        ).thenAnswer((_) async => false);
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        verify(() => mockLocalStorage.isReposted(testAddressableId)).called(1);
      });
    });

    group('getRepostCount', () {
      test('queries relays for repost count', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 42));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final count = await repository.getRepostCount(testAddressableId);

        expect(count, equals(42));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('returns zero when no reposts exist', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 0));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final count = await repository.getRepostCount(testAddressableId);

        expect(count, equals(0));
      });

      test('returns cached count incremented after toggleRepost', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 6));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        // Seed cache via relay query so the repost can increment it.
        await repository.getRepostCount(testAddressableId);

        // toggleRepost → repostVideo bumps cache from 6 → 7.
        await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        final count = await repository.getRepostCount(testAddressableId);

        expect(count, equals(7));
        // Only the seed call hits the relay; the post-toggle read is cached.
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('cached count clamps to zero for negative values', () async {
        // countEvents returns 0 so the seeded cache starts at 0.
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 0));
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: EventKind.eventDeletion,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        // Create a record (cache stays unseeded until getRepostCount runs).
        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        // Seed cache to 0 — this is the pathological state where the
        // displayed count is already at floor before the unrepost.
        await repository.getRepostCount(testAddressableId);

        // unrepostVideo: previousCount = 0, would cache max(0, -1) = 0.
        await repository.unrepostVideo(testAddressableId);

        final count = await repository.getRepostCount(testAddressableId);

        expect(count, equals(0));
      });

      test('caches relay-fetched count and reuses on second call', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 15));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final first = await repository.getRepostCount(testAddressableId);
        final second = await repository.getRepostCount(testAddressableId);

        expect(first, equals(15));
        expect(second, equals(15));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });
    });

    group('getRepostCountByEventId', () {
      test('caches relay-fetched count and reuses on second call', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 7));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final first = await repository.getRepostCountByEventId(testEventId);
        final second = await repository.getRepostCountByEventId(testEventId);

        expect(first, equals(7));
        expect(second, equals(7));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });
    });

    group('count caching via toggleRepost', () {
      test(
        'overrides relay count on subsequent getRepostCount calls',
        () async {
          when(
            () => mockNostrClient.countEvents(any()),
          ).thenAnswer((_) async => const CountResult(count: 10));

          final repository = RepostsRepository(nostrClient: mockNostrClient);

          // First call hits relay and seeds the cache at 10.
          final relayCount = await repository.getRepostCount(testAddressableId);
          expect(relayCount, equals(10));

          // toggleRepost → repostVideo bumps the cached count to 11.
          await repository.toggleRepost(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          // Second call uses the cache (11 from the increment).
          final cachedCount = await repository.getRepostCount(
            testAddressableId,
          );
          expect(cachedCount, equals(11));
          verify(() => mockNostrClient.countEvents(any())).called(1);
        },
      );

      test('is cleared by clearCache', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 10));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        // Seed cache via getRepostCount, then bump it via toggleRepost.
        await repository.getRepostCount(testAddressableId);
        await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );
        await repository.clearCache();

        // Post-clear, the cache is empty so getRepostCount queries relay
        // again and returns 10.
        final count = await repository.getRepostCount(testAddressableId);

        expect(count, equals(10));
        verify(() => mockNostrClient.countEvents(any())).called(2);
      });
    });

    group('getRepostCountByEventId', () {
      test('queries relays for repost count using event ID', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 15));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final count = await repository.getRepostCountByEventId(testEventId);

        expect(count, equals(15));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('returns zero when no reposts exist', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 0));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final count = await repository.getRepostCountByEventId(testEventId);

        expect(count, equals(0));
      });
    });

    group('getRepostRecord', () {
      test('returns null when not reposted', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        expect(await repository.getRepostRecord(testAddressableId), isNull);
      });

      test('returns record when reposted', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        final record = await repository.getRepostRecord(testAddressableId);
        expect(record, isNotNull);
        expect(record!.addressableId, equals(testAddressableId));
        expect(record.repostEventId, equals(testRepostEventId));
        expect(record.originalAuthorPubkey, equals(testAuthorPubkey));
      });
    });

    group('signer readiness (#6813)', () {
      test(
        'syncUserReposts filters on the resolved key, not the stale cache',
        () async {
          // The cache stays empty when the signer acquired its key after the
          // client initialized. Reading it directly would query
          // authors: [''], which matches no event.
          when(() => mockNostrClient.publicKey).thenReturn('');
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenAnswer((_) async => testPubkey);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );
          await repository.syncUserReposts();

          final captured = verify(
            () => mockNostrClient.queryEvents(captureAny()),
          ).captured.cast<List<Filter>>();
          expect(captured, isNotEmpty);
          for (final filters in captured) {
            expect(filters.single.authors, equals([testPubkey]));
          }
        },
      );

      test(
        'syncUserReposts keeps local data and skips relays with no key',
        () async {
          final record = RepostRecord(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId,
            originalAuthorPubkey: testAuthorPubkey,
            createdAt: DateTime.now(),
          );
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenAnswer((_) async => null);
          when(
            () => mockLocalStorage.getAllRepostRecords(),
          ).thenAnswer((_) async => [record]);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );
          final result = await repository.syncUserReposts();

          verifyNever(() => mockNostrClient.queryEvents(any()));
          expect(result.orderedAddressableIds, contains(testAddressableId));
        },
      );

      test(
        'syncUserReposts keeps local data when key resolution throws',
        () async {
          final record = RepostRecord(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId,
            originalAuthorPubkey: testAuthorPubkey,
            createdAt: DateTime.now(),
          );
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenThrow(StateError('signer unavailable'));
          when(
            () => mockLocalStorage.getAllRepostRecords(),
          ).thenAnswer((_) async => [record]);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );
          final result = await repository.syncUserReposts();

          verifyNever(() => mockNostrClient.queryEvents(any()));
          expect(result.orderedAddressableIds, contains(testAddressableId));
        },
      );
    });

    group('syncUserReposts', () {
      test('loads from local storage first', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.syncUserReposts();

        verify(() => mockLocalStorage.getAllRepostRecords()).called(1);
      });

      test('fetches from relays and updates local storage', () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final events = [
          createMockEvent(
            id: 'event1',
            kind: 16,
            createdAt: now,
            tags: [
              ['k', '34236'],
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReposts();

        expect(result.orderedAddressableIds, contains('34236:author1:video1'));
        verify(() => mockLocalStorage.saveRepostRecordsBatch(any())).called(1);
      });

      test('returns cached data when relay fetch fails', () async {
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testAuthorPubkey,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenAnswer((_) async => [record]);
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReposts();

        expect(result.orderedAddressableIds, contains(testAddressableId));
      });

      test(
        'throws SyncFailedException when no local data and relay fails',
        () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenThrow(Exception('Network error'));

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          expect(
            repository.syncUserReposts,
            throwsA(isA<SyncFailedException>()),
          );
        },
      );

      test(
        'updates existing record when newer version found from relay',
        () async {
          final oldTimestamp = DateTime.now().subtract(const Duration(days: 2));
          final newTimestamp = DateTime.now();

          final existingRecord = RepostRecord(
            addressableId: '34236:author1:video1',
            repostEventId: 'old_event_id',
            originalAuthorPubkey: 'author1',
            createdAt: oldTimestamp,
          );

          when(
            () => mockLocalStorage.getAllRepostRecords(),
          ).thenAnswer((_) async => [existingRecord]);

          final newEvent = createMockEvent(
            id: 'new_event_id',
            kind: 16,
            createdAt: newTimestamp.millisecondsSinceEpoch ~/ 1000,
            tags: [
              ['k', '34236'],
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [newEvent]);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          final result = await repository.syncUserReposts();

          expect(
            result.orderedAddressableIds,
            contains('34236:author1:video1'),
          );
          expect(
            result.addressableIdToRepostId['34236:author1:video1'],
            equals('new_event_id'),
          );
          verify(
            () => mockLocalStorage.saveRepostRecordsBatch(any()),
          ).called(1);
        },
      );
    });

    group('fetchUserReposts', () {
      test('fetches reposts for any user pubkey', () async {
        const otherUserPubkey =
            'other_user_pubkey_64_chars_'
            '0000000000000000000000000000000000000';
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final events = [
          createMockEvent(
            id: 'event1',
            kind: 16,
            createdAt: now,
            tags: [
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
          createMockEvent(
            id: 'event2',
            kind: 16,
            createdAt: now - 100,
            tags: [
              ['a', '34236:author2:video2'],
              ['p', 'author2'],
            ],
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final reposts = await repository.fetchUserReposts(otherUserPubkey);

        expect(reposts, hasLength(2));
        expect(reposts[0], equals('34236:author1:video1'));
        expect(reposts[1], equals('34236:author2:video2'));
      });

      test('deduplicates reposts', () async {
        const otherUserPubkey = 'other_user_pubkey';
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final events = [
          createMockEvent(
            id: 'event1',
            kind: 16,
            createdAt: now,
            tags: [
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
          createMockEvent(
            id: 'event2',
            kind: 16,
            createdAt: now - 100,
            tags: [
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final reposts = await repository.fetchUserReposts(otherUserPubkey);

        expect(reposts, hasLength(1));
      });

      test('throws FetchRepostsFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        expect(
          () => repository.fetchUserReposts('some_pubkey'),
          throwsA(isA<FetchRepostsFailedException>()),
        );
      });
    });

    group('fetchUserRepostRecords', () {
      test('returns full RepostRecord objects', () async {
        const otherUserPubkey = 'other_user_pubkey';
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final events = [
          createMockEvent(
            id: 'event1',
            kind: 16,
            createdAt: now,
            tags: [
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final records = await repository.fetchUserRepostRecords(
          otherUserPubkey,
        );

        expect(records, hasLength(1));
        expect(records[0].addressableId, equals('34236:author1:video1'));
        expect(records[0].repostEventId, equals('event1'));
        expect(records[0].originalAuthorPubkey, equals('author1'));
      });

      test('throws FetchRepostsFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        expect(
          () => repository.fetchUserRepostRecords('some_pubkey'),
          throwsA(isA<FetchRepostsFailedException>()),
        );
      });
    });

    group('fetchEventReposters', () {
      Event createReposterEvent({
        required String id,
        required String pubkey,
        required int kind,
        required int createdAt,
        List<List<String>> tags = const [],
      }) {
        final event = MockEvent();
        when(() => event.id).thenReturn(id);
        when(() => event.kind).thenReturn(kind);
        when(() => event.createdAt).thenReturn(createdAt);
        when(() => event.tags).thenReturn(tags);
        when(() => event.pubkey).thenReturn(pubkey);
        when(() => event.content).thenReturn('');
        when(() => event.sig).thenReturn('');
        return event;
      }

      // Intercept queryEvents based on the filter shape so e-tag, a-tag
      // and kind-5 deletion queries can return different fixtures.
      void wireQueryEvents({
        List<Event> eFilterEvents = const [],
        List<Event> aFilterEvents = const [],
        List<Event> deletionEvents = const [],
      }) {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final filter = filters.first;
          if (filter.kinds?.contains(EventKind.eventDeletion) ?? false) {
            return deletionEvents;
          }
          if (filter.a?.isNotEmpty ?? false) {
            return aFilterEvents;
          }
          return eFilterEvents;
        });
      }

      test('returns empty list when no reposts exist', () async {
        wireQueryEvents();

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final result = await repository.fetchEventReposters(
          eventId: testEventId,
        );

        expect(result, isEmpty);
      });

      test('excludes reposters hidden by the block filter', () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        wireQueryEvents(
          eFilterEvents: [
            createReposterEvent(
              id: 'repost_blocked',
              pubkey: 'blocked_reposter',
              kind: EventKind.genericRepost,
              createdAt: now,
              tags: [
                ['e', testEventId],
              ],
            ),
            createReposterEvent(
              id: 'repost_allowed',
              pubkey: 'allowed_reposter',
              kind: EventKind.genericRepost,
              createdAt: now - 100,
              tags: [
                ['e', testEventId],
              ],
            ),
          ],
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          blockFilter: (pubkey) => pubkey == 'blocked_reposter',
        );

        expect(await repository.fetchEventReposters(eventId: testEventId), [
          'allowed_reposter',
        ]);
      });

      test('returns reposter pubkeys ordered by recency', () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        wireQueryEvents(
          eFilterEvents: [
            createReposterEvent(
              id: 'repost1',
              pubkey: 'reposter1',
              kind: EventKind.genericRepost,
              createdAt: now - 200,
              tags: [
                ['e', testEventId],
              ],
            ),
            createReposterEvent(
              id: 'repost2',
              pubkey: 'reposter2',
              kind: EventKind.genericRepost,
              createdAt: now,
              tags: [
                ['e', testEventId],
              ],
            ),
            createReposterEvent(
              id: 'repost3',
              pubkey: 'reposter3',
              kind: EventKind.genericRepost,
              createdAt: now - 100,
              tags: [
                ['e', testEventId],
              ],
            ),
          ],
        );

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final result = await repository.fetchEventReposters(
          eventId: testEventId,
        );

        expect(result, equals(['reposter2', 'reposter3', 'reposter1']));
      });

      test('deduplicates pubkeys across e and a query results when '
          'addressableId is provided', () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        wireQueryEvents(
          eFilterEvents: [
            createReposterEvent(
              id: 'repost_e',
              pubkey: 'sharedReposter',
              kind: EventKind.genericRepost,
              createdAt: now,
              tags: [
                ['e', testEventId],
              ],
            ),
          ],
          aFilterEvents: [
            createReposterEvent(
              id: 'repost_a',
              pubkey: 'sharedReposter',
              kind: EventKind.genericRepost,
              createdAt: now - 50,
              tags: [
                ['a', testAddressableId],
              ],
            ),
            createReposterEvent(
              id: 'repost_a2',
              pubkey: 'otherReposter',
              kind: EventKind.genericRepost,
              createdAt: now - 100,
              tags: [
                ['a', testAddressableId],
              ],
            ),
          ],
        );

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final result = await repository.fetchEventReposters(
          eventId: testEventId,
          addressableId: testAddressableId,
        );

        expect(result, hasLength(2));
        expect(result, equals(['sharedReposter', 'otherReposter']));
      });

      test('excludes reposts deleted via kind 5', () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        wireQueryEvents(
          eFilterEvents: [
            createReposterEvent(
              id: 'live_repost',
              pubkey: 'liveReposter',
              kind: EventKind.genericRepost,
              createdAt: now,
              tags: [
                ['e', testEventId],
              ],
            ),
            createReposterEvent(
              id: 'deleted_repost',
              pubkey: 'deletingReposter',
              kind: EventKind.genericRepost,
              createdAt: now - 50,
              tags: [
                ['e', testEventId],
              ],
            ),
          ],
          deletionEvents: [
            createReposterEvent(
              id: 'deletion1',
              pubkey: 'deletingReposter',
              kind: EventKind.eventDeletion,
              createdAt: now - 10,
              tags: [
                ['e', 'deleted_repost'],
              ],
            ),
          ],
        );

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final result = await repository.fetchEventReposters(
          eventId: testEventId,
        );

        expect(result, equals(['liveReposter']));
      });

      test(
        'includes a pubkey with both a deleted and a non-deleted repost',
        () async {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          wireQueryEvents(
            eFilterEvents: [
              createReposterEvent(
                id: 'old_deleted',
                pubkey: 'churningReposter',
                kind: EventKind.genericRepost,
                createdAt: now - 200,
                tags: [
                  ['e', testEventId],
                ],
              ),
              createReposterEvent(
                id: 'new_live',
                pubkey: 'churningReposter',
                kind: EventKind.genericRepost,
                createdAt: now,
                tags: [
                  ['e', testEventId],
                ],
              ),
            ],
            deletionEvents: [
              createReposterEvent(
                id: 'deletion1',
                pubkey: 'churningReposter',
                kind: EventKind.eventDeletion,
                createdAt: now - 100,
                tags: [
                  ['e', 'old_deleted'],
                ],
              ),
            ],
          );

          final repository = RepostsRepository(nostrClient: mockNostrClient);

          final result = await repository.fetchEventReposters(
            eventId: testEventId,
          );

          expect(result, equals(['churningReposter']));
        },
      );

      test(
        'ignores deletions whose author does not own the targeted repost',
        () async {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          wireQueryEvents(
            eFilterEvents: [
              createReposterEvent(
                id: 'repost1',
                pubkey: 'authorA',
                kind: EventKind.genericRepost,
                createdAt: now,
                tags: [
                  ['e', testEventId],
                ],
              ),
            ],
            deletionEvents: [
              // Different author trying to delete authorA's repost.
              createReposterEvent(
                id: 'fraud_deletion',
                pubkey: 'authorA',
                kind: EventKind.eventDeletion,
                createdAt: now - 10,
                // Tag without an event id (malformed) — must be ignored.
                tags: [
                  ['e'],
                ],
              ),
            ],
          );

          final repository = RepostsRepository(nostrClient: mockNostrClient);

          final result = await repository.fetchEventReposters(
            eventId: testEventId,
          );

          expect(result, equals(['authorA']));
        },
      );

      test('includes both kind 6 and kind 16 reposts', () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        wireQueryEvents(
          eFilterEvents: [
            createReposterEvent(
              id: 'kind6_repost',
              pubkey: 'kind6Reposter',
              kind: EventKind.repost,
              createdAt: now,
              tags: [
                ['e', testEventId],
              ],
            ),
            createReposterEvent(
              id: 'kind16_repost',
              pubkey: 'kind16Reposter',
              kind: EventKind.genericRepost,
              createdAt: now - 50,
              tags: [
                ['e', testEventId],
              ],
            ),
          ],
        );

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final result = await repository.fetchEventReposters(
          eventId: testEventId,
        );

        expect(result, equals(['kind6Reposter', 'kind16Reposter']));
      });

      test(
        'throws FetchRepostersFailedException when relay query throws',
        () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenThrow(Exception('relay unreachable'));

          final repository = RepostsRepository(nostrClient: mockNostrClient);

          await expectLater(
            repository.fetchEventReposters(eventId: testEventId),
            throwsA(isA<FetchRepostersFailedException>()),
          );
        },
      );

      test(
        'treats empty addressableId the same as null (no a-tag query)',
        () async {
          var aFilterCalls = 0;
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((
            invocation,
          ) async {
            final filters = invocation.positionalArguments[0] as List<Filter>;
            final filter = filters.first;
            if (filter.a?.isNotEmpty ?? false) {
              aFilterCalls++;
            }
            return <Event>[];
          });

          final repository = RepostsRepository(nostrClient: mockNostrClient);

          await repository.fetchEventReposters(
            eventId: testEventId,
            addressableId: '',
          );

          expect(aFilterCalls, equals(0));
        },
      );
    });

    group('clearCache', () {
      test('clears in-memory cache', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);

        await repository.clearCache();

        expect(repository.isRepostedSync(testAddressableId), isFalse);
      });

      test('clears local storage', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.clearCache();

        verify(() => mockLocalStorage.clearAll()).called(1);
      });

      test('does not throw when called after dispose', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient)
          ..dispose();

        // clearCache after dispose should not throw "Cannot add new events
        // after calling close" on the BehaviorSubject.
        await expectLater(repository.clearCache(), completes);
      });

      test('a failing clearAll leaves the in-memory cache intact', () async {
        // The stub lives here rather than in the shared setUp so the failure
        // it describes stays adjacent to the test that depends on it.
        when(
          () => mockLocalStorage.clearAll(),
        ).thenThrow(StateError('database is dead'));
        when(() => mockLocalStorage.getAllRepostRecords()).thenAnswer(
          (_) async => [
            RepostRecord(
              addressableId: testAddressableId,
              repostEventId: testEventId,
              originalAuthorPubkey: testAuthorPubkey,
              createdAt: DateTime.utc(2026),
            ),
          ],
        );
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // Pin the baseline: the record is genuinely loaded before we act, so
        // the assertion after the throw cannot pass on an empty cache.
        expect(await repository.getRepostedAddressableIds(), {
          testAddressableId,
        });

        await expectLater(repository.clearCache(), throwsA(isA<StateError>()));

        // All-or-nothing: the durable store rejected the clear, so the caches
        // derived from it must still describe what is on disk.
        expect(repository.isRepostedSync(testAddressableId), isTrue);
        expect(await repository.getRepostedAddressableIds(), {
          testAddressableId,
        });
      });
    });

    group('watchRepostedAddressableIds', () {
      test('returns internal stream when no local storage', () async {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        final stream = repository.watchRepostedAddressableIds();
        expect(stream, isA<Stream<Set<String>>>());

        final emittedValues = <Set<String>>[];
        final subscription = stream.listen(emittedValues.add);

        await Future<void>.delayed(Duration.zero);
        expect(emittedValues.last, isEmpty);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        await Future<void>.delayed(Duration.zero);
        expect(emittedValues.last, contains(testAddressableId));

        await subscription.cancel();
      });

      test('delegates to local storage when available', () async {
        when(
          () => mockLocalStorage.watchRepostedAddressableIds(),
        ).thenAnswer((_) => Stream.value(<String>{'test-id'}));

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await expectLater(
          repository.watchRepostedAddressableIds(),
          emits(equals(<String>{'test-id'})),
        );
        verify(() => mockLocalStorage.watchRepostedAddressableIds()).called(1);
      });

      test(
        'falls back to the in-memory cache when storage is degraded',
        () async {
          // The regression: on a device whose database is present but
          // unreadable, storage's query stream never emits, so a UI wired to it
          // watches the repost publish succeed and the button never flip. Every
          // mutation still ticks the repository's own controller, so that is
          // what the stream must follow once storage has proven unusable.
          when(
            () => mockLocalStorage.getAllRepostRecords(),
          ).thenThrow(Exception('database is unavailable'));
          when(
            () => mockLocalStorage.watchRepostedAddressableIds(),
          ).thenAnswer((_) => const Stream<Set<String>>.empty());

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          final emittedValues = <Set<String>>[];
          final subscription = repository.watchRepostedAddressableIds().listen(
            emittedValues.add,
          );

          await Future<void>.delayed(Duration.zero);
          expect(emittedValues.last, isEmpty);

          await repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          await Future<void>.delayed(Duration.zero);
          expect(emittedValues.last, contains(testAddressableId));
          verifyNever(() => mockLocalStorage.watchRepostedAddressableIds());

          await subscription.cancel();
        },
      );
    });

    group('initialize', () {
      test('loads records from local storage', () async {
        when(
          () => mockNostrClient.resolvePublicKey(),
        ).thenAnswer((_) async => null);
        when(() => mockLocalStorage.getAllRepostRecords()).thenAnswer(
          (_) async => [
            RepostRecord(
              addressableId: testAddressableId,
              repostEventId: testRepostEventId,
              originalAuthorPubkey: testAuthorPubkey,
              createdAt: DateTime.now(),
            ),
          ],
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.initialize();

        expect(await repository.isReposted(testAddressableId), isTrue);
      });

      test('sets up subscription when the client resolves a key', () async {
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.initialize();

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1);
      });

      test('skips subscription when client has no keys', () async {
        when(
          () => mockNostrClient.resolvePublicKey(),
        ).thenAnswer((_) async => null);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.initialize();

        verifyNever(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        );
      });

      test('is idempotent', () async {
        when(
          () => mockNostrClient.resolvePublicKey(),
        ).thenAnswer((_) async => null);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.initialize();
        await repository.initialize();

        verify(() => mockLocalStorage.getAllRepostRecords()).called(1);
      });

      test(
        'subscribes with the resolved key when the publicKey cache is stale',
        () async {
          when(() => mockNostrClient.publicKey).thenReturn('');
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenAnswer((_) async => testPubkey);
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => const Stream.empty());

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );
          await repository.initialize();

          final captured =
              verify(
                    () => mockNostrClient.subscribe(
                      captureAny(),
                      subscriptionId: any(named: 'subscriptionId'),
                    ),
                  ).captured.single
                  as List<Filter>;
          expect(captured.single.authors, equals([testPubkey]));
        },
      );
    });

    group('real-time sync', () {
      test('processes incoming repost event', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.initialize();

        // Emit a Kind 16 repost event
        final repostEvent = createMockEvent(
          id: testRepostEventId,
          kind: EventKind.genericRepost,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          tags: [
            ['a', testAddressableId],
            ['p', testAuthorPubkey],
          ],
        );

        streamController.add(repostEvent);
        await Future<void>.delayed(Duration.zero);

        expect(repository.isRepostedSync(testAddressableId), isTrue);
        verify(() => mockLocalStorage.saveRepostRecord(any())).called(1);

        await streamController.close();
      });

      test('deduplicates older events', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);

        final now = DateTime.now();
        when(() => mockLocalStorage.getAllRepostRecords()).thenAnswer(
          (_) async => [
            RepostRecord(
              addressableId: testAddressableId,
              repostEventId: 'existing_repost_event_id',
              originalAuthorPubkey: testAuthorPubkey,
              createdAt: now,
            ),
          ],
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.initialize();

        // Emit an older event for the same addressable ID
        final olderEvent = createMockEvent(
          id: 'older_repost_id',
          kind: EventKind.genericRepost,
          createdAt:
              now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/
              1000,
          tags: [
            ['a', testAddressableId],
            ['p', testAuthorPubkey],
          ],
        );

        streamController.add(olderEvent);
        await Future<void>.delayed(Duration.zero);

        // The older event should not replace the existing record
        final record = await repository.getRepostRecord(testAddressableId);
        expect(record!.repostEventId, equals('existing_repost_event_id'));

        await streamController.close();
      });

      test('handles subscription errors without crashing', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenAnswer((_) async => []);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.initialize();

        // Emit an error on the stream
        streamController.addError(Exception('connection lost'));
        await Future<void>.delayed(Duration.zero);

        // Repository should still be functional
        expect(repository.isRepostedSync('any_id'), isFalse);

        await streamController.close();
      });
    });

    group('dispose', () {
      test('cancels subscription and closes stream controller', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        await repository.initialize();

        // Ensure stream is active
        final stream = repository.watchRepostedAddressableIds();
        final subscription = stream.listen((_) {});

        // Dispose should complete without error
        repository.dispose();

        verify(() => mockNostrClient.unsubscribe(any())).called(1);

        await subscription.cancel();
        await streamController.close();
      });

      test('can be called safely without subscription', () {
        final repository = RepostsRepository(nostrClient: mockNostrClient);

        // Should not throw when no subscription exists
        expect(repository.dispose, returnsNormally);
      });
    });

    group('offline queuing', () {
      test('repostVideo queues action when offline', () async {
        var queuedAction = <String, dynamic>{};

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isRepost,
                required addressableId,
                required originalAuthorPubkey,
                eventId,
              }) async {
                queuedAction = {
                  'isRepost': isRepost,
                  'addressableId': addressableId,
                  'originalAuthorPubkey': originalAuthorPubkey,
                  'eventId': eventId,
                };
              },
        );

        final eventId = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(eventId, startsWith('pending_repost_'));
        expect(queuedAction['isRepost'], isTrue);
        expect(queuedAction['addressableId'], equals(testAddressableId));
        expect(queuedAction['originalAuthorPubkey'], equals(testAuthorPubkey));

        // Should still show as reposted locally
        expect(repository.isRepostedSync(testAddressableId), isTrue);

        // Should save to local storage
        verify(() => mockLocalStorage.saveRepostRecord(any())).called(1);
      });

      test('unrepostVideo queues action when offline', () async {
        var queuedAction = <String, dynamic>{};

        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        // First repost while online
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);

        // Now create a new repository with offline callbacks
        final offlineRepository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isRepost,
                required addressableId,
                required originalAuthorPubkey,
                eventId,
              }) async {
                queuedAction = {
                  'isRepost': isRepost,
                  'addressableId': addressableId,
                  'originalAuthorPubkey': originalAuthorPubkey,
                };
              },
        );

        // Add the existing repost record to the new repository
        await offlineRepository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        // Now unrepost while offline
        await offlineRepository.unrepostVideo(testAddressableId);

        expect(queuedAction['isRepost'], isFalse);
        expect(queuedAction['addressableId'], equals(testAddressableId));

        // Should no longer show as reposted locally
        expect(offlineRepository.isRepostedSync(testAddressableId), isFalse);
      });
    });

    group('executeRepostAction', () {
      test('publishes repost directly to relays', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final eventId = await repository.executeRepostAction(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(eventId, equals(testRepostEventId));

        verify(
          () => mockNostrClient.sendGenericRepost(
            addressableId: testAddressableId,
            targetKind: EventKind.videoVertical,
            authorPubkey: testAuthorPubkey,
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test('updates placeholder record with real event ID', () async {
        // First create a pending repost (simulating offline queue)
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isRepost,
                required addressableId,
                required originalAuthorPubkey,
                eventId,
              }) async {},
        );

        final placeholderId = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(placeholderId, startsWith('pending_repost_'));

        // Now execute the real action (simulating sync)
        final realEventId = await repository.executeRepostAction(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(realEventId, equals(testRepostEventId));

        // Verify local storage was updated
        verify(() => mockLocalStorage.saveRepostRecord(any())).called(2);
      });

      test('throws RepostFailedException when publish fails', () async {
        when(
          () => mockNostrClient.sendGenericRepost(
            addressableId: any(named: 'addressableId'),
            targetKind: any(named: 'targetKind'),
            authorPubkey: any(named: 'authorPubkey'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final repository = RepostsRepository(nostrClient: mockNostrClient);

        expect(
          () => repository.executeRepostAction(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<RepostFailedException>()),
        );
      });
    });

    group('executeUnrepostAction', () {
      test('publishes deletion directly to relays', () async {
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        // First repost
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        // Now execute unrepost directly
        await repository.executeUnrepostAction(testAddressableId);

        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
        verify(
          () => mockLocalStorage.deleteRepostRecord(testAddressableId),
        ).called(1);
      });

      test('skips deletion for pending reposts', () async {
        // Create a pending repost (offline)
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isRepost,
                required addressableId,
                required originalAuthorPubkey,
                eventId,
              }) async {},
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        // Execute unrepost - should not call deleteEvent since never synced
        await repository.executeUnrepostAction(testAddressableId);

        verifyNever(() => mockNostrClient.deleteEvent(any()));
        verify(
          () => mockLocalStorage.deleteRepostRecord(testAddressableId),
        ).called(1);
      });

      test('does nothing when no record exists', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // Should not throw, just return
        await repository.executeUnrepostAction(testAddressableId);

        verifyNever(() => mockNostrClient.deleteEvent(any()));
        verifyNever(
          () => mockLocalStorage.deleteRepostRecord(testAddressableId),
        );
      });

      test('throws UnrepostFailedException when deletion fails', () async {
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => null);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(
          () => repository.executeUnrepostAction(testAddressableId),
          throwsA(isA<UnrepostFailedException>()),
        );
      });

      test(
        'translates typed relay failures to UnrepostFailedException',
        () async {
          final failedEvent = createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
          when(() => mockNostrClient.deleteEvent(any())).thenThrow(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.noResponse,
                event: failedEvent,
              ),
            ),
          );
          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );
          await repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          );

          await expectLater(
            repository.executeUnrepostAction(testAddressableId),
            throwsA(isA<UnrepostFailedException>()),
          );
        },
      );

      test('falls back to local storage when not in cache', () async {
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testAuthorPubkey,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getRepostRecord(testAddressableId),
        ).thenAnswer((_) async => record);
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.executeUnrepostAction(testAddressableId);

        verify(
          () => mockLocalStorage.getRepostRecord(testAddressableId),
        ).called(1);
        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
      });
    });
  });
}
