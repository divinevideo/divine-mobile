import 'dart:async';
import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';
import 'package:unified_logger/unified_logger.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockLikesLocalStorage extends Mock implements LikesLocalStorage {}

class MockEvent extends Mock implements Event {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group('LikesRepository', () {
    late MockNostrClient mockNostrClient;
    late MockLikesLocalStorage mockLocalStorage;
    late LikesRepository repository;

    // Test constants
    const testUserPubkey = 'test_user_pubkey_1234567890abcdef';
    const testEventId = 'test_event_id_1234567890abcdef';
    const testAuthorPubkey = 'test_author_pubkey_1234567890abcdef';
    const testReactionEventId = 'test_reaction_event_id_1234567890abcdef';
    const defaultTimestamp = 1700000000;

    // Helper to create a LikeRecord
    LikeRecord createLikeRecord({
      String targetEventId = testEventId,
      String reactionEventId = testReactionEventId,
      DateTime? createdAt,
      String? addressableId,
    }) => LikeRecord(
      targetEventId: targetEventId,
      reactionEventId: reactionEventId,
      createdAt: createdAt ?? DateTime.now(),
      addressableId: addressableId,
    );

    // Helper to create a mock reaction event
    MockEvent createMockReaction({
      required String id,
      required String targetEventId,
      String authorPubkey = 'reaction_author_pubkey_1234567890abcdef',
      String content = '+',
      int createdAt = defaultTimestamp,
      List<List<String>>? tags,
    }) {
      final event = MockEvent();
      when(() => event.id).thenReturn(id);
      when(() => event.pubkey).thenReturn(authorPubkey);
      when(() => event.content).thenReturn(content);
      when(() => event.createdAt).thenReturn(createdAt);
      when(() => event.tags).thenReturn(
        tags ??
            [
              ['e', targetEventId],
            ],
      );
      return event;
    }

    // Helper to create a mock deletion event
    MockEvent createMockDeletion(
      List<String> deletedEventIds, {
      String authorPubkey = 'reaction_author_pubkey_1234567890abcdef',
    }) {
      final event = MockEvent();
      when(() => event.id).thenReturn('deletion_of_${deletedEventIds.join()}');
      when(() => event.pubkey).thenReturn(authorPubkey);
      when(
        () => event.tags,
      ).thenReturn(deletedEventIds.map((id) => ['e', id]).toList());
      return event;
    }

    /// Stubs relay reads with sequential [responses] in call order, shared by
    /// queryEvents and the settled reads a likers list makes (#10846), each
    /// of those settling in full.
    void mockQueryEventsSequence(List<List<Event>> responses) {
      var callCount = 0;
      when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
        return responses[callCount++ % responses.length];
      });
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
        ),
      ).thenAnswer(
        (_) async => (
          events: responses[callCount++ % responses.length],
          timedOut: false,
          noRelays: false,
        ),
      );
    }

    /// Stubs the reads that must tell a complete answer from a short one —
    /// the sync's and the like check's — with [responses] in call order,
    /// each a complete read.
    void mockReadEventsSequence(List<List<Event>> responses) {
      var callCount = 0;
      when(
        () => mockNostrClient.readEvents(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => QueryResult(
          events: responses[callCount++ % responses.length],
          endedBy: QueryEnd.complete,
        ),
      );
    }

    /// Asserts no relay list read ran, through queryEvents or the settled read
    /// the likers fallback now makes (#10846). It does not cover readEvents,
    /// which the sync and retraction reads use.
    void verifyNoFallbackReads() {
      verifyNever(() => mockNostrClient.queryEvents(any()));
      verifyNever(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
        ),
      );
    }

    /// Stubs the reads a likers list waits on every relay for (#10846)
    /// with [events], each ending unfinished unless [finished].
    void stubSettledReads(
      List<Event> events, {
      bool finished = true,
      bool noRelays = false,
    }) {
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
        ),
      ).thenAnswer(
        (_) async => (events: events, timedOut: !finished, noRelays: noRelays),
      );
    }

    // Helper to create repository with standard setup
    LikesRepository createRepository({
      bool withLocalStorage = true,
      IsOnlineCallback? isOnline,
      QueueOfflineActionCallback? queueOfflineAction,
      BlockedLikerFilter? blockFilter,
      FunnelcakeApiClient? funnelcakeApiClient,
      LikesRepositoryErrorReporter? errorReporter,
    }) {
      return LikesRepository(
        nostrClient: mockNostrClient,
        localStorage: withLocalStorage ? mockLocalStorage : null,
        isOnline: isOnline,
        queueOfflineAction: queueOfflineAction,
        blockFilter: blockFilter,
        funnelcakeApiClient: funnelcakeApiClient,
        errorReporter: errorReporter,
      );
    }

    setUpAll(() {
      registerFallbackValue(MockEvent());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(createLikeRecord());
      registerFallbackValue('');
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockLocalStorage = MockLikesLocalStorage();

      // Default mock behaviors
      when(() => mockNostrClient.publicKey).thenReturn(testUserPubkey);
      when(
        () => mockNostrClient.resolvePublicKey(),
      ).thenAnswer((_) async => testUserPubkey);
      when(() => mockNostrClient.hasKeys).thenReturn(false);
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockLocalStorage.getAllLikeRecords(),
      ).thenAnswer((_) async => []);
      when(
        () => mockLocalStorage.isLiked(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockLocalStorage.getLikeRecord(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockLocalStorage.getLikeRecordByAddressableId(any()),
      ).thenAnswer((_) async => null);
    });

    tearDown(() => repository.dispose());

    group('constructor', () {
      test('creates repository without local storage', () {
        repository = createRepository(withLocalStorage: false);
        expect(repository, isNotNull);
      });

      test('creates repository with local storage', () {
        repository = createRepository();
        expect(repository, isNotNull);
      });
    });

    group('isLiked', () {
      test('returns false when event is not liked', () async {
        repository = createRepository();
        expect(await repository.isLiked(testEventId), isFalse);
      });

      test('returns true when event is liked', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);

        repository = createRepository();
        expect(await repository.isLiked(testEventId), isTrue);
      });
    });

    group('getLikedEventIds', () {
      test('returns empty set when no likes', () async {
        repository = createRepository();
        expect(await repository.getLikedEventIds(), isEmpty);
      });

      test('returns set of liked event IDs', () async {
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(targetEventId: 'event1', reactionEventId: 'r1'),
            createLikeRecord(targetEventId: 'event2', reactionEventId: 'r2'),
          ],
        );

        repository = createRepository();
        final result = await repository.getLikedEventIds();

        expect(result, containsAll(['event1', 'event2']));
        expect(result.length, equals(2));
      });
    });

    group('getOrderedLikedEventIds', () {
      test('returns empty list when no likes', () async {
        repository = createRepository();
        expect(await repository.getOrderedLikedEventIds(), isEmpty);
      });

      test('returns event IDs ordered by createdAt descending', () async {
        final oldest = DateTime(2024, 1, 1, 10);
        final middle = DateTime(2024, 1, 1, 12);
        final newest = DateTime(2024, 1, 1, 14);

        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: 'oldest_event_id_1234567890abcdef',
              reactionEventId: 'r_oldest',
              createdAt: oldest,
            ),
            createLikeRecord(
              targetEventId: 'newest_event_id_1234567890abcdef',
              reactionEventId: 'r_newest',
              createdAt: newest,
            ),
            createLikeRecord(
              targetEventId: 'middle_event_id_1234567890abcdef',
              reactionEventId: 'r_middle',
              createdAt: middle,
            ),
          ],
        );

        repository = createRepository();
        final result = await repository.getOrderedLikedEventIds();

        expect(result, [
          'newest_event_id_1234567890abcdef',
          'middle_event_id_1234567890abcdef',
          'oldest_event_id_1234567890abcdef',
        ]);
      });

      test('works without local storage', () async {
        repository = createRepository(withLocalStorage: false);
        expect(await repository.getOrderedLikedEventIds(), isEmpty);
      });
    });

    group('unavailable local storage', () {
      // The local database is a cache, not a precondition. When it is
      // unreadable (at-rest cipher bootstrap left it unopenable, runtime
      // corruption, disk full) the Kind 7 must still reach relays: the signed
      // reaction is the irreplaceable half, the cache row is not. Mirrors the
      // same guarantee in RepostsRepository.
      final storageFailure = Exception('database is unavailable');

      void stubSendLike(MockEvent event) {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => event);
      }

      test('publishes the like when local storage cannot be read', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        stubSendLike(mockEvent);
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenThrow(storageFailure);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, equals(testReactionEventId));
        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            targetAuthorPubkey: testAuthorPubkey,
          ),
        ).called(1);
      });

      test('publishes the like when the local write fails', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        stubSendLike(mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenThrow(storageFailure);

        repository = createRepository();
        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, equals(testReactionEventId));
        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            targetAuthorPubkey: testAuthorPubkey,
          ),
        ).called(1);
      });

      test(
        'a failed read does not strand the repository uninitialized',
        () async {
          // Without the latch every call re-runs the throwing read instead of
          // degrading once.
          when(
            () => mockLocalStorage.getAllLikeRecords(),
          ).thenThrow(storageFailure);

          repository = createRepository();
          await repository.getLikedEventIds();
          await repository.getLikedEventIds();

          verify(() => mockLocalStorage.getAllLikeRecords()).called(1);
        },
      );

      test(
        'reports an invariant violation raised by a storage write',
        () async {
          // An Error from the storage layer means the storage layer itself is
          // broken. Still swallowed so the Kind 7 goes out, but routed to the
          // reporter — a swallowed bug nobody can see is how a real defect
          // ships behind a warning log.
          final mockEvent = MockEvent();
          when(() => mockEvent.id).thenReturn(testReactionEventId);
          stubSendLike(mockEvent);
          final reported = <({Object error, String site})>[];
          when(
            () => mockLocalStorage.saveLikeRecord(any()),
          ).thenThrow(StateError('storage invariant violated'));

          repository = createRepository(
            errorReporter: (error, stackTrace, {required site}) {
              reported.add((error: error, site: site));
            },
          );
          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );

          expect(reported.first.error, isA<StateError>());
          expect(
            reported.map((r) => r.site),
            equals([
              LikesRepositoryReportableSites.likeEventSavePlaceholder,
              LikesRepositoryReportableSites.likeEventSaveConfirmed,
            ]),
          );
        },
      );

      test(
        'reports an invariant violation raised by the initial read',
        () async {
          final reported = <String>[];
          when(
            () => mockLocalStorage.getAllLikeRecords(),
          ).thenThrow(TypeError());

          repository = createRepository(
            errorReporter: (error, stackTrace, {required site}) {
              reported.add(site);
            },
          );
          await repository.getLikedEventIds();

          expect(
            reported,
            equals([
              LikesRepositoryReportableSites.ensureInitializedLoadRecords,
            ]),
          );
        },
      );

      test('does not report an expected storage failure', () async {
        // SqliteException and friends are Exceptions, not Errors: expected on
        // a broken device and explicitly not Crashlytics-reportable per the
        // decision matrix in `.claude/rules/error_handling.md`.
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        stubSendLike(mockEvent);
        var reportCount = 0;
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenThrow(storageFailure);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenThrow(storageFailure);

        repository = createRepository(
          errorReporter: (error, stackTrace, {required site}) {
            reportCount++;
          },
        );
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(reportCount, isZero);
      });

      test('publishes the like when the toggle state read fails', () async {
        // The like button only ever reaches the repository through
        // toggleLike (video_interactions_bloc.dart), so a storage read that
        // throws there costs the Kind 7 just as surely as one inside
        // likeEvent. likeEvent's own guard never gets a chance to run.
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        stubSendLike(mockEvent);
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenThrow(storageFailure);
        when(() => mockLocalStorage.isLiked(any())).thenThrow(storageFailure);

        repository = createRepository();
        final isNowLiked = await repository.toggleLike(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(isNowLiked, isTrue);
        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            targetAuthorPubkey: testAuthorPubkey,
          ),
        ).called(1);
      });

      test(
        'unlikes from the in-memory cache when the state read fails',
        () async {
          // The swallowed read must fall back to the cache, not to "not
          // liked" — otherwise the toggle publishes a duplicate reaction
          // instead of deleting the live one.
          final mockEvent = MockEvent();
          when(() => mockEvent.id).thenReturn(testReactionEventId);
          stubSendLike(mockEvent);
          final deletionEvent = MockEvent();
          when(() => deletionEvent.id).thenReturn('deletion_event_id');
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => deletionEvent);

          repository = createRepository();
          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );
          when(() => mockLocalStorage.isLiked(any())).thenThrow(storageFailure);

          final isNowLiked = await repository.toggleLike(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );

          expect(isNowLiked, isFalse);
          verify(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).called(1);
        },
      );

      test('syncs from relays when the persisted read fails', () async {
        // The relay half is the authoritative one. A cache read that throws
        // used to escape syncUserReactions before the fetch below ever ran,
        // so the profile Likes tab errored while relays were reachable.
        const targetId = 'sync_target_1234567890abcdef';
        const reactionId = 'sync_reaction_1234567890abcdef';
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenThrow(storageFailure);
        mockReadEventsSequence([
          [createMockReaction(id: reactionId, targetEventId: targetId)],
          [],
        ]);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetId));
      });

      test('completes the sync when the batch save fails', () async {
        const targetId = 'batch_target_1234567890abcdef';
        const reactionId = 'batch_reaction_1234567890abcdef';
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenThrow(storageFailure);
        mockReadEventsSequence([
          [createMockReaction(id: reactionId, targetEventId: targetId)],
          [],
        ]);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetId));
      });

      test('completes the sync when the deleted-record purge fails', () async {
        const targetId = 'purge_target_1234567890abcdef';
        const reactionId = 'purge_reaction_1234567890abcdef';
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: targetId,
              reactionEventId: reactionId,
            ),
          ],
        );
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenThrow(storageFailure);
        mockReadEventsSequence([
          [createMockReaction(id: reactionId, targetEventId: targetId)],
          [
            createMockDeletion([reactionId]),
          ],
        ]);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isNot(contains(targetId)));
      });

      test('still subscribes when the startup read fails', () async {
        // initialize() reads storage before _subscribeToReactions, so a
        // throw there costs the session its cross-device sync too.
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenThrow(storageFailure);
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        repository = createRepository();
        await repository.initialize();

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1);
      });

      test('caches a subscription reaction when its write fails', () async {
        // The write is fire-and-forget, so an unguarded rejection would be
        // an uncaught async error rather than a swallowed cache miss.
        const targetId = 'live_target_1234567890abcdef';
        final controller = StreamController<Event>();
        addTearDown(controller.close);
        final reaction = createMockReaction(
          id: 'live_reaction_1234567890abcdef',
          targetEventId: targetId,
          authorPubkey: testUserPubkey,
        );
        when(() => reaction.kind).thenReturn(EventKind.reaction);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenThrow(storageFailure);
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        repository = createRepository();
        await repository.initialize();

        controller.add(reaction);
        await Future<void>.delayed(Duration.zero);

        expect(await repository.isLiked(targetId), isTrue);
      });
    });

    late List<({Object error, String site})> reported;
    late Set<LogEntry> priorLogs;

    List<LogEntry> missingCoordinateWarnings() => LogCaptureService()
        .getRecentLogs()
        .where(
          (entry) =>
              !priorLogs.contains(entry) &&
              entry.name == 'LikesRepository' &&
              entry.level == LogLevel.warning &&
              entry.message.contains('publishing without an a tag'),
        )
        .toList();

    /// Stubs every publish to succeed with a reaction for [testEventId].
    void stubAnyPublish() {
      when(
        () => mockNostrClient.sendLike(
          any(),
          content: any(named: 'content'),
          addressableId: any(named: 'addressableId'),
          targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
          targetKind: any(named: 'targetKind'),
        ),
      ).thenAnswer(
        (_) async => createMockReaction(
          id: testReactionEventId,
          targetEventId: testEventId,
        ),
      );
    }

    /// A repository with no local storage that records reporter calls.
    LikesRepository createReportingRepository() {
      reported = [];
      priorLogs = LogCaptureService().getRecentLogs().toSet();
      return createRepository(
        withLocalStorage: false,
        errorReporter: (error, stackTrace, {required site}) {
          reported.add((error: error, site: site));
        },
      );
    }

    group('likeEvent', () {
      group('on an addressable target with no coordinate (#6980)', () {
        test('still publishes the like with its kind', () async {
          stubAnyPublish();
          repository = createReportingRepository();

          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            targetKind: 34236,
          );

          verify(
            () => mockNostrClient.sendLike(
              testEventId,
              content: '+',
              targetAuthorPubkey: testAuthorPubkey,
              targetKind: 34236,
            ),
          ).called(1);
        });

        test('logs missing remote data without a crash report', () async {
          stubAnyPublish();
          repository = createReportingRepository();

          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            targetKind: 34236,
          );

          expect(missingCoordinateWarnings(), hasLength(1));
          expect(reported, isEmpty);
        });

        test('adds no warning for a like it does not publish', () async {
          stubAnyPublish();
          repository = createReportingRepository();
          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            targetKind: 34236,
          );
          expect(missingCoordinateWarnings(), hasLength(1));

          await expectLater(
            repository.likeEvent(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
              targetKind: 34236,
            ),
            throwsA(isA<AlreadyLikedException>()),
          );

          expect(missingCoordinateWarnings(), hasLength(1));
          expect(reported, isEmpty);
        });

        test('logs no warning when the coordinate is known', () async {
          stubAnyPublish();
          repository = createReportingRepository();

          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            addressableId: '34236:$testAuthorPubkey:test-d-tag',
            targetKind: 34236,
          );

          expect(missingCoordinateWarnings(), isEmpty);
          expect(reported, isEmpty);
        });

        test('logs no warning for a regular target kind', () async {
          stubAnyPublish();
          repository = createReportingRepository();

          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            targetKind: 1111,
          );

          expect(missingCoordinateWarnings(), isEmpty);
          expect(reported, isEmpty);
        });
      });

      test('publishes like reaction and stores record', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, equals(testReactionEventId));
        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            targetAuthorPubkey: testAuthorPubkey,
          ),
        ).called(1);
        // Optimistic-first: storage is written twice — once for the
        // pending placeholder before sendLike, once for the confirmed
        // record after sendLike returns.
        final saved = verify(
          () => mockLocalStorage.saveLikeRecord(captureAny()),
        ).captured.cast<LikeRecord>();
        expect(saved, hasLength(2));
        expect(saved.first.reactionEventId, startsWith('pending_like_'));
        expect(saved.last.reactionEventId, equals(testReactionEventId));
      });

      test('publishes like with addressable ID when provided', () async {
        const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          addressableId: testAddressableId,
          targetKind: 34236,
        );

        expect(result, equals(testReactionEventId));
        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            addressableId: testAddressableId,
            targetAuthorPubkey: testAuthorPubkey,
            targetKind: 34236,
          ),
        ).called(1);
      });

      test('throws LikeFailedException when publish fails', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => null);
        // Optimistic-first writes the placeholder then rolls back on failure;
        // both storage methods need stubs so the rollback path resolves.
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        repository = createRepository();

        await expectLater(
          repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeFailedException>()),
        );
      });

      test('throws AlreadyLikedException when already liked', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize

        expect(
          () => repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<AlreadyLikedException>()),
        );
      });

      test(
        'writes optimistic placeholder to storage before sendLike resolves',
        () async {
          // Suspend sendLike with a Completer so we can observe the local
          // state mid-call. This is the heart of the Follow-pattern fix:
          // the local DB update + stream emit must happen before the
          // network round-trip returns.
          final sendLikeCompleter = Completer<Event?>();
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) => sendLikeCompleter.future);
          when(
            () => mockLocalStorage.saveLikeRecord(any()),
          ).thenAnswer((_) async {});

          repository = createRepository();

          final likeFuture = repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );

          // Yield so the optimistic phase of likeEvent runs.
          await Future<void>.delayed(Duration.zero);

          final saved = verify(
            () => mockLocalStorage.saveLikeRecord(captureAny()),
          ).captured.cast<LikeRecord>();
          expect(saved, hasLength(1));
          expect(saved.first.targetEventId, equals(testEventId));
          expect(
            saved.first.reactionEventId,
            startsWith('pending_like_'),
            reason: 'optimistic record should use a placeholder ID',
          );
          expect(
            await repository.isLiked(testEventId),
            isTrue,
            reason: 'isLiked must reflect the optimistic state pre-network',
          );

          // Resolve the network call with the real reaction event.
          final mockEvent = MockEvent();
          when(() => mockEvent.id).thenReturn(testReactionEventId);
          sendLikeCompleter.complete(mockEvent);
          final result = await likeFuture;

          expect(result, equals(testReactionEventId));
        },
      );

      test('rolls back optimistic record when sendLike returns null', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        repository = createRepository();

        await expectLater(
          repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeFailedException>()),
        );

        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
        expect(await repository.isLiked(testEventId), isFalse);
      });

      test('rolls back optimistic record when sendLike throws', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenThrow(Exception('relay closed'));
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        repository = createRepository();

        await expectLater(
          repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
        expect(await repository.isLiked(testEventId), isFalse);
      });

      test('restricted like rolls back and is never queued', () async {
        final event = MockEvent();
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenThrow(
          SocialPublishException(
            SocialPublishResult(
              status: SocialPublishStatus.accountRestricted,
              event: event,
              outcome: const PublishOutcome(
                eventId: testReactionEventId,
                acceptedBy: [],
                rejectedBy: {
                  'wss://relay.divine.video': 'blocked: pubkey is suspended',
                },
                noResponseFrom: [],
              ),
            ),
          ),
        );
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        // The relay holds no like, so the tap goes on to publish.
        mockReadEventsSequence([<Event>[]]);
        var queueCalls = 0;
        repository = createRepository(
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queueCalls++;
              },
        );

        await expectLater(
          repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeAccountRestrictedException>()),
        );

        expect(queueCalls, isZero);
        expect(await repository.isLiked(testEventId), isFalse);
        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
      });

      test(
        'stale restricted rollback preserves a newer confirmed record',
        () async {
          LikeRecord? storedRecord;
          final firstPublish = Completer<Event>();
          final deleteStarted = Completer<void>();
          final finishDelete = Completer<void>();
          var publishCalls = 0;
          final restrictedEvent = MockEvent();
          final newerReaction = createMockReaction(
            id: 'newer_reaction_id',
            targetEventId: testEventId,
          );
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) {
            publishCalls++;
            return publishCalls == 1
                ? firstPublish.future
                : Future.value(newerReaction);
          });
          when(() => mockLocalStorage.saveLikeRecord(any())).thenAnswer((
            call,
          ) async {
            storedRecord = call.positionalArguments.single as LikeRecord;
          });
          when(() => mockLocalStorage.deleteLikeRecord(testEventId)).thenAnswer(
            (
              _,
            ) async {
              if (!deleteStarted.isCompleted) deleteStarted.complete();
              await finishDelete.future;
              storedRecord = null;
              return true;
            },
          );
          repository = createRepository();

          final staleLike = repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );
          final staleExpectation = expectLater(
            staleLike,
            throwsA(isA<LikeAccountRestrictedException>()),
          );
          await Future<void>.delayed(Duration.zero);
          firstPublish.completeError(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.accountRestricted,
                event: restrictedEvent,
              ),
            ),
          );
          await deleteStarted.future;

          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );
          finishDelete.complete();
          await staleExpectation;

          expect(storedRecord?.reactionEventId, 'newer_reaction_id');
          expect(await repository.isLiked(testEventId), isTrue);
        },
      );

      test(
        'stale relay-failure rollback preserves a newer confirmed record',
        () async {
          LikeRecord? storedRecord;
          final firstPublish = Completer<Event>();
          final deleteStarted = Completer<void>();
          final finishDelete = Completer<void>();
          var publishCalls = 0;
          final failedEvent = MockEvent();
          final newerReaction = createMockReaction(
            id: 'newer_reaction_id',
            targetEventId: testEventId,
          );
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) {
            publishCalls++;
            return publishCalls == 1
                ? firstPublish.future
                : Future.value(newerReaction);
          });
          when(() => mockLocalStorage.saveLikeRecord(any())).thenAnswer((
            call,
          ) async {
            storedRecord = call.positionalArguments.single as LikeRecord;
          });
          when(() => mockLocalStorage.deleteLikeRecord(testEventId)).thenAnswer(
            (
              _,
            ) async {
              if (!deleteStarted.isCompleted) deleteStarted.complete();
              await finishDelete.future;
              storedRecord = null;
              return true;
            },
          );
          repository = createRepository();

          final staleLike = repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );
          final staleExpectation = expectLater(
            staleLike,
            throwsA(isA<LikeFailedException>()),
          );
          await Future<void>.delayed(Duration.zero);
          firstPublish.completeError(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.noResponse,
                event: failedEvent,
              ),
            ),
          );
          await deleteStarted.future;

          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );
          finishDelete.complete();
          await staleExpectation;

          expect(storedRecord?.reactionEventId, 'newer_reaction_id');
          expect(await repository.isLiked(testEventId), isTrue);
        },
      );

      // Defense-in-depth: when the publish fails but the offline-action
      // callback is wired, the optimistic state must be preserved and the
      // action queued for retry. This covers the "device says online but
      // relays are unhealthy" case where the existing `if (!_isOnline())`
      // guard at the top of likeEvent does not fire.
      test('queues offline action and preserves optimistic state when '
          'sendLike returns null and queueOfflineAction is wired', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        var queueCalls = 0;
        String? queuedEventId;
        bool? queuedIsLike;
        repository = createRepository(
          isOnline: () => true,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queueCalls++;
                queuedEventId = eventId;
                queuedIsLike = isLike;
              },
        );

        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(
          result,
          startsWith('pending_like_'),
          reason: 'must return placeholder ID, not throw',
        );
        expect(queueCalls, equals(1));
        expect(queuedEventId, equals(testEventId));
        expect(queuedIsLike, isTrue);
        expect(
          await repository.isLiked(testEventId),
          isTrue,
          reason: 'optimistic state must be preserved across the failure',
        );
        verifyNever(() => mockLocalStorage.deleteLikeRecord(any()));
      });

      test('queues offline action when sendLike throws and '
          'queueOfflineAction is wired', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenThrow(Exception('relay closed'));
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        var queueCalls = 0;
        repository = createRepository(
          isOnline: () => true,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queueCalls++;
              },
        );

        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, startsWith('pending_like_'));
        expect(queueCalls, equals(1));
        expect(await repository.isLiked(testEventId), isTrue);
      });
    });

    group('unlikeEvent', () {
      test(
        'retracts a reaction whose publish is still in flight (#7001)',
        () async {
          // The placeholder id means "the confirmed swap has not run yet",
          // NOT "the reaction never reached a relay" — likeEvent only swaps
          // it after sendLike returns, and RelayPool.send reports success as
          // soon as one socket takes the frame. Unliking inside that window
          // must still publish the Kind 5, or the reaction stays live and
          // counted forever while local state says "not liked", so the next
          // tap publishes a second one.
          final publishGate = Completer<Event>();
          final reactionA = MockEvent();
          when(() => reactionA.id).thenReturn('reaction_a');
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) => publishGate.future);
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => MockEvent());

          repository = createRepository();
          final inFlightLike = repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );
          await Future<void>.delayed(Duration.zero);

          // The user taps again before the relay round-trip resolves.
          await repository.unlikeEvent(testEventId);

          // The relay had already stored it.
          publishGate.complete(reactionA);
          await inFlightLike;

          verify(() => mockNostrClient.deleteEvent('reaction_a')).called(1);
          expect(
            await repository.isLiked(testEventId),
            isFalse,
            reason: 'the confirmed swap must not resurrect an unliked record',
          );
        },
      );
      test(
        'does not retract a later like for a stale pending placeholder',
        () async {
          when(
            () => mockLocalStorage.getAllLikeRecords(),
          ).thenAnswer(
            (_) async => [
              createLikeRecord(
                reactionEventId: 'pending_like_$testEventId',
              ),
            ],
          );
          when(
            () => mockLocalStorage.deleteLikeRecord(testEventId),
          ).thenAnswer((_) async => true);
          when(
            () => mockLocalStorage.saveLikeRecord(any()),
          ).thenAnswer((_) async {});

          final reactionB = MockEvent();
          when(() => reactionB.id).thenReturn('reaction_b');
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) async => reactionB);

          repository = createRepository(
            isOnline: () => true,
            queueOfflineAction:
                ({
                  required isLike,
                  required eventId,
                  required authorPubkey,
                  addressableId,
                  targetKind,
                }) async {},
          );
          await repository.isLiked(testEventId); // Initialize stale placeholder

          await repository.unlikeEvent(testEventId);
          expect(await repository.isLiked(testEventId), isFalse);

          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );

          verifyNever(() => mockNostrClient.deleteEvent(any()));
          expect(await repository.isLiked(testEventId), isTrue);
        },
      );
      test(
        'queues retry and restores count when mid-publish retraction fails',
        () async {
          when(
            () => mockNostrClient.countEvents(any()),
          ).thenAnswer((_) async => const CountResult(count: 10));
          when(
            () => mockLocalStorage.saveLikeRecord(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockLocalStorage.deleteLikeRecord(testEventId),
          ).thenAnswer((_) async => true);

          final publishGate = Completer<Event>();
          final reactionA = MockEvent();
          when(() => reactionA.id).thenReturn('reaction_a');
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) => publishGate.future);
          when(
            () => mockNostrClient.deleteEvent('reaction_a'),
          ).thenAnswer((_) async => null);

          // The relay holds no like, so the tap goes on to publish.
          mockReadEventsSequence([<Event>[]]);
          bool? queuedIsLike;
          String? queuedEventId;
          repository = createRepository(
            isOnline: () => true,
            queueOfflineAction:
                ({
                  required isLike,
                  required eventId,
                  required authorPubkey,
                  addressableId,
                  targetKind,
                }) async {
                  queuedIsLike = isLike;
                  queuedEventId = eventId;
                },
          );
          expect(await repository.getLikeCount(testEventId), equals(10));

          final inFlightLike = repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );
          await Future<void>.delayed(Duration.zero);
          expect(await repository.getLikeCount(testEventId), equals(11));

          await repository.unlikeEvent(testEventId);
          expect(await repository.getLikeCount(testEventId), equals(10));

          publishGate.complete(reactionA);
          await inFlightLike;

          verify(() => mockNostrClient.deleteEvent('reaction_a')).called(1);
          expect(queuedIsLike, isFalse);
          expect(queuedEventId, equals(testEventId));
          expect(await repository.isLiked(testEventId), isTrue);
          expect(await repository.getLikeCount(testEventId), equals(11));
        },
      );
      test('publishes deletion and removes record', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => MockEvent());
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize
        await repository.unlikeEvent(testEventId);

        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
      });

      test('throws NotLikedException when not liked', () async {
        repository = createRepository();
        expect(
          () => repository.unlikeEvent(testEventId),
          throwsA(isA<NotLikedException>()),
        );
      });

      test('throws UnlikeFailedException when deletion fails', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => null);
        // Optimistic-first removes then rolls back on failure; storage
        // methods need stubs so the rollback path resolves.
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize

        await expectLater(
          repository.unlikeEvent(testEventId),
          throwsA(isA<UnlikeFailedException>()),
        );
      });

      test('falls back to database when record not in memory cache', () async {
        when(
          () => mockLocalStorage.getLikeRecord(testEventId),
        ).thenAnswer((_) async => createLikeRecord());
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => MockEvent());
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = createRepository();
        await repository.unlikeEvent(testEventId);

        verify(() => mockLocalStorage.getLikeRecord(testEventId)).called(1);
        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
      });

      test(
        'removes optimistic record from storage before deleteEvent resolves',
        () async {
          when(
            () => mockLocalStorage.getAllLikeRecords(),
          ).thenAnswer((_) async => [createLikeRecord()]);
          when(
            () => mockLocalStorage.deleteLikeRecord(testEventId),
          ).thenAnswer((_) async => true);

          // Suspend deleteEvent so we can observe the optimistic phase.
          final deleteCompleter = Completer<Event?>();
          when(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).thenAnswer((_) => deleteCompleter.future);

          repository = createRepository();
          await repository.isLiked(testEventId); // Initialize cache

          final unlikeFuture = repository.unlikeEvent(testEventId);

          // Yield so the optimistic phase runs.
          await Future<void>.delayed(Duration.zero);

          verify(
            () => mockLocalStorage.deleteLikeRecord(testEventId),
          ).called(1);
          expect(
            await repository.isLiked(testEventId),
            isFalse,
            reason: 'isLiked must reflect optimistic removal pre-network',
          );

          deleteCompleter.complete(MockEvent());
          await unlikeFuture;
        },
      );

      test(
        'restores optimistic removal when deleteEvent returns null',
        () async {
          when(
            () => mockLocalStorage.getAllLikeRecords(),
          ).thenAnswer((_) async => [createLikeRecord()]);
          when(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).thenAnswer((_) async => null);
          when(
            () => mockLocalStorage.deleteLikeRecord(testEventId),
          ).thenAnswer((_) async => true);
          when(
            () => mockLocalStorage.saveLikeRecord(any()),
          ).thenAnswer((_) async {});

          repository = createRepository();
          await repository.isLiked(testEventId); // Initialize cache

          await expectLater(
            repository.unlikeEvent(testEventId),
            throwsA(isA<UnlikeFailedException>()),
          );

          // The original record should be saved back during rollback.
          verify(() => mockLocalStorage.saveLikeRecord(any())).called(1);
          expect(await repository.isLiked(testEventId), isTrue);
        },
      );

      test('restores optimistic removal when deleteEvent throws', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenThrow(Exception('relay closed'));
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize cache

        await expectLater(
          repository.unlikeEvent(testEventId),
          throwsA(isA<Exception>()),
        );

        verify(() => mockLocalStorage.saveLikeRecord(any())).called(1);
        expect(await repository.isLiked(testEventId), isTrue);
      });

      // Defense-in-depth (mirror of likeEvent): when the kind-5 deletion
      // fails but the offline-action callback is wired, the optimistic
      // removal must be preserved and the unlike queued for retry.
      test('queues offline action and preserves optimistic removal when '
          'deleteEvent returns null and queueOfflineAction is wired', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => null);
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        var queueCalls = 0;
        bool? queuedIsLike;
        repository = createRepository(
          isOnline: () => true,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queueCalls++;
                queuedIsLike = isLike;
              },
        );
        await repository.isLiked(testEventId); // Initialize cache

        await repository.unlikeEvent(testEventId);

        expect(queueCalls, equals(1));
        expect(queuedIsLike, isFalse);
        expect(
          await repository.isLiked(testEventId),
          isFalse,
          reason: 'optimistic removal must be preserved',
        );
        verifyNever(() => mockLocalStorage.saveLikeRecord(any()));
      });

      test('queues offline action when deleteEvent throws and '
          'queueOfflineAction is wired', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenThrow(Exception('relay closed'));
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        var queueCalls = 0;
        repository = createRepository(
          isOnline: () => true,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queueCalls++;
              },
        );
        await repository.isLiked(testEventId); // Initialize cache

        await repository.unlikeEvent(testEventId);

        expect(queueCalls, equals(1));
        expect(await repository.isLiked(testEventId), isFalse);
      });

      test('stale restricted restore preserves a newer unlike', () async {
        LikeRecord? storedRecord = createLikeRecord();
        final firstDeletion = Completer<Event>();
        final saveStarted = Completer<void>();
        final finishSave = Completer<void>();
        var deletionCalls = 0;
        final restrictedEvent = MockEvent();
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [storedRecord!]);
        when(() => mockLocalStorage.deleteLikeRecord(testEventId)).thenAnswer((
          _,
        ) async {
          storedRecord = null;
          return true;
        });
        when(() => mockLocalStorage.saveLikeRecord(any())).thenAnswer((
          call,
        ) async {
          if (!saveStarted.isCompleted) saveStarted.complete();
          await finishSave.future;
          storedRecord = call.positionalArguments.single as LikeRecord;
        });
        when(() => mockNostrClient.deleteEvent(testReactionEventId)).thenAnswer(
          (
            _,
          ) {
            deletionCalls++;
            return deletionCalls == 1
                ? firstDeletion.future
                : Future.value(MockEvent());
          },
        );
        repository = createRepository();
        await repository.isLiked(testEventId);

        final staleUnlike = repository.unlikeEvent(testEventId);
        final staleExpectation = expectLater(
          staleUnlike,
          throwsA(isA<LikeAccountRestrictedException>()),
        );
        await Future<void>.delayed(Duration.zero);
        firstDeletion.completeError(
          SocialPublishException(
            SocialPublishResult(
              status: SocialPublishStatus.accountRestricted,
              event: restrictedEvent,
            ),
          ),
        );
        await saveStarted.future;

        await repository.unlikeEvent(testEventId);
        finishSave.complete();
        await staleExpectation;

        expect(storedRecord, isNull);
        expect(await repository.isLiked(testEventId), isFalse);
      });

      test('stale relay-failure restore preserves a newer unlike', () async {
        LikeRecord? storedRecord = createLikeRecord();
        final firstDeletion = Completer<Event>();
        final saveStarted = Completer<void>();
        final finishSave = Completer<void>();
        var deletionCalls = 0;
        final failedEvent = MockEvent();
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [storedRecord!]);
        when(() => mockLocalStorage.deleteLikeRecord(testEventId)).thenAnswer((
          _,
        ) async {
          storedRecord = null;
          return true;
        });
        when(() => mockLocalStorage.saveLikeRecord(any())).thenAnswer((
          call,
        ) async {
          if (!saveStarted.isCompleted) saveStarted.complete();
          await finishSave.future;
          storedRecord = call.positionalArguments.single as LikeRecord;
        });
        when(() => mockNostrClient.deleteEvent(testReactionEventId)).thenAnswer(
          (
            _,
          ) {
            deletionCalls++;
            return deletionCalls == 1
                ? firstDeletion.future
                : Future.value(MockEvent());
          },
        );
        repository = createRepository();
        await repository.isLiked(testEventId);

        final staleUnlike = repository.unlikeEvent(testEventId);
        final staleExpectation = expectLater(
          staleUnlike,
          throwsA(isA<UnlikeFailedException>()),
        );
        await Future<void>.delayed(Duration.zero);
        firstDeletion.completeError(
          SocialPublishException(
            SocialPublishResult(
              status: SocialPublishStatus.noResponse,
              event: failedEvent,
            ),
          ),
        );
        await saveStarted.future;

        await repository.unlikeEvent(testEventId);
        finishSave.complete();
        await staleExpectation;

        expect(storedRecord, isNull);
        expect(await repository.isLiked(testEventId), isFalse);
      });
    });

    group('toggleLike', () {
      test('likes when not liked and returns true', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        expect(
          await repository.toggleLike(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          isTrue,
        );
      });

      test('toggleLike passes addressableId and targetKind', () async {
        const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        await repository.toggleLike(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          addressableId: testAddressableId,
          targetKind: 34236,
        );

        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            addressableId: testAddressableId,
            targetAuthorPubkey: testAuthorPubkey,
            targetKind: 34236,
          ),
        ).called(1);
      });

      test('unlikes when liked and returns false', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockLocalStorage.isLiked(testEventId),
        ).thenAnswer((_) async => true);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => MockEvent());
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize

        expect(
          await repository.toggleLike(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          isFalse,
        );
      });

      test('uses in-memory cache when no localStorage', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => MockEvent());

        repository = createRepository(withLocalStorage: false);
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(
          await repository.toggleLike(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          isFalse,
        );
      });
    });

    group('downvoteEvent', () {
      test('logs a missing coordinate on an addressable target '
          '(#6980)', () async {
        stubAnyPublish();
        repository = createReportingRepository();

        await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          targetKind: 34236,
        );

        expect(missingCoordinateWarnings(), hasLength(1));
        expect(reported, isEmpty);
      });

      test('ticks watchDownvotedEventIds before sendLike completes', () async {
        // Block sendLike on a completer so the optimistic stream emit
        // is observable before the network call returns.
        final publishCompleter = Completer<Event?>();
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) => publishCompleter.future);

        repository = createRepository(withLocalStorage: false);

        final emitted = <List<String>>[];
        final subscription = repository.watchDownvotedEventIds().listen(
          emitted.add,
        );

        final downvoteFuture = repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          emitted.last,
          contains(testEventId),
          reason: 'stream must tick before publish completes',
        );

        publishCompleter.complete(
          createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );
        await downvoteFuture;
        await subscription.cancel();
      });

      test('publishes kind-7 with content "-" and tracks the record', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );

        repository = createRepository(withLocalStorage: false);
        final result = await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, equals(testReactionEventId));
        expect(await repository.isDownvoted(testEventId), isTrue);
        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '-',
            targetAuthorPubkey: testAuthorPubkey,
          ),
        ).called(1);
      });

      test('throws AlreadyDownvotedException when already downvoted', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );

        repository = createRepository(withLocalStorage: false);
        await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        await expectLater(
          repository.downvoteEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<AlreadyDownvotedException>()),
        );
      });

      test('throws AlreadyDownvotedException when relay has coordinate '
          'downvote after cold start (#6124)', () async {
        const supersededId = 'superseded_reply_id_1234567890abcdef';
        const editedId = 'edited_reply_id_1234567890abcdef';
        const coordinate = '34236:$testAuthorPubkey:reply-d-tag';
        mockQueryEventsSequence([
          <Event>[],
          [
            createMockReaction(
              id: testReactionEventId,
              targetEventId: supersededId,
              authorPubkey: testUserPubkey,
              content: '-',
              tags: [
                ['e', supersededId],
                ['a', coordinate],
              ],
            ),
          ],
          <Event>[],
        ]);

        repository = createRepository(withLocalStorage: false);

        await expectLater(
          repository.downvoteEvent(
            eventId: editedId,
            authorPubkey: testAuthorPubkey,
            addressableId: coordinate,
            targetKind: 34236,
          ),
          throwsA(isA<AlreadyDownvotedException>()),
        );

        verifyNever(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        );
      });

      test('rolls back record + stream when publish returns null', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => null);

        repository = createRepository(withLocalStorage: false);

        await expectLater(
          repository.downvoteEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeFailedException>()),
        );

        expect(await repository.isDownvoted(testEventId), isFalse);
      });

      test('rolls back record + stream when publish throws', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenThrow(Exception('relay unreachable'));

        repository = createRepository(withLocalStorage: false);

        await expectLater(
          repository.downvoteEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<Exception>()),
        );

        expect(await repository.isDownvoted(testEventId), isFalse);
      });

      test(
        'translates relay publish results to repository exceptions',
        () async {
          final event = MockEvent();
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenThrow(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.noResponse,
                event: event,
              ),
            ),
          );
          repository = createRepository(withLocalStorage: false);

          await expectLater(
            repository.downvoteEvent(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
            throwsA(isA<LikeFailedException>()),
          );
        },
      );

      test('terminalizes a trusted account restriction', () async {
        final event = MockEvent();
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenThrow(
          SocialPublishException(
            SocialPublishResult(
              status: SocialPublishStatus.accountRestricted,
              event: event,
            ),
          ),
        );
        repository = createRepository(withLocalStorage: false);

        await expectLater(
          repository.downvoteEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeAccountRestrictedException>()),
        );
      });
    });

    group('removeDownvote', () {
      test('publishes deletion event and removes the record', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );
        final deletionEvent = MockEvent();
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => deletionEvent);

        repository = createRepository(withLocalStorage: false);
        await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        await repository.removeDownvote(testEventId);

        expect(await repository.isDownvoted(testEventId), isFalse);
        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
      });

      test('resolves a downvote by coordinate after the target is edited '
          '(#6124)', () async {
        // An edit mints a new event id under the same coordinate. Without the
        // coordinate companion index the pre-edit downvote is unreachable, so
        // the deletion is never published and re-tapping mints a duplicate.
        const coordinate = '34236:$testAuthorPubkey:reply-d-tag';
        const supersededId = 'superseded_event_id_1234567890abcdef';
        const editedId = 'edited_event_id_1234567890abcdef';

        repository = createRepository(withLocalStorage: false);
        mockQueryEventsSequence([<Event>[], <Event>[], <Event>[]]);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: supersededId,
            content: '-',
          ),
        );
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => MockEvent());

        await repository.downvoteEvent(
          eventId: supersededId,
          authorPubkey: testAuthorPubkey,
          addressableId: coordinate,
        );

        // The edited revision answers to a different id, same coordinate.
        await repository.removeDownvote(editedId, addressableId: coordinate);

        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
      });

      test('passes the coordinate through to sendLike (#6124)', () async {
        const coordinate = '34236:$testAuthorPubkey:reply-d-tag';
        repository = createRepository(withLocalStorage: false);
        mockQueryEventsSequence([<Event>[], <Event>[], <Event>[]]);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );

        await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          targetKind: 34236,
          addressableId: coordinate,
        );

        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '-',
            addressableId: coordinate,
            targetAuthorPubkey: testAuthorPubkey,
            targetKind: 34236,
          ),
        ).called(1);
      });

      test(
        'throws NotDownvotedException when neither cache nor relay has one',
        () async {
          repository = createRepository(withLocalStorage: false);
          // Relay reports no reaction and no deletion.
          mockQueryEventsSequence([<Event>[], <Event>[]]);

          await expectLater(
            repository.removeDownvote(testEventId),
            throwsA(isA<NotDownvotedException>()),
          );
        },
      );

      test(
        'deletes the relay copy when the in-memory cache is cold (#6124)',
        () async {
          // Downvotes are never persisted, so a cold start leaves the cache
          // empty while the kind-7 is still live. Without the relay fallback
          // this threw and the deletion was never published.
          repository = createRepository(withLocalStorage: false);
          mockQueryEventsSequence([
            [
              createMockReaction(
                id: testReactionEventId,
                targetEventId: testEventId,
                authorPubkey: testUserPubkey,
                content: '-',
              ),
            ],
            <Event>[],
          ]);
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => MockEvent());

          await repository.removeDownvote(testEventId);

          verify(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).called(1);
        },
      );

      test(
        'chunks the cold-cache deletion probe so no REQ exceeds the frame '
        'limit',
        () async {
          // 600 live relay downvotes on one target force the Kind 5 probe
          // into 2 `#e` chunks (500 + 100) — this was the last query leg in
          // the file still building its filter unchunked.
          repository = createRepository(withLocalStorage: false);
          final reactions = [
            for (var i = 0; i < 600; i++)
              createMockReaction(
                id: 'downvote_$i',
                targetEventId: testEventId,
                authorPubkey: testUserPubkey,
                content: '-',
              ),
          ];
          mockQueryEventsSequence([reactions, <Event>[], <Event>[]]);
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => MockEvent());

          await repository.removeDownvote(testEventId);

          final deletionFilters =
              verify(() => mockNostrClient.queryEvents(captureAny())).captured
                  .cast<List<Filter>>()
                  .map((filters) => filters.single)
                  .where(
                    (f) => f.kinds?.contains(EventKind.eventDeletion) ?? false,
                  )
                  .toList();

          expect(deletionFilters, hasLength(2));
          expect(deletionFilters[0].e, hasLength(500));
          expect(deletionFilters[1].e, hasLength(100));
          for (final filter in deletionFilters) {
            expect(
              filter.authors,
              equals([testUserPubkey]),
              reason: 'probe stays scoped to own deletions in every chunk',
            );
          }
          expect(
            {...deletionFilters[0].e!, ...deletionFilters[1].e!},
            hasLength(600),
            reason: 'chunks partition every candidate id without overlap',
          );
        },
      );

      test(
        'does not delete a relay downvote that was already deleted (#6124)',
        () async {
          repository = createRepository(withLocalStorage: false);
          mockQueryEventsSequence([
            [
              createMockReaction(
                id: testReactionEventId,
                targetEventId: testEventId,
                content: '-',
              ),
            ],
            [
              createMockDeletion([testReactionEventId]),
            ],
          ]);

          await expectLater(
            repository.removeDownvote(testEventId),
            throwsA(isA<NotDownvotedException>()),
          );
          verifyNever(() => mockNostrClient.deleteEvent(any()));
        },
      );

      test('rolls back record + stream when deletion returns null', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => null);

        repository = createRepository(withLocalStorage: false);
        await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        await expectLater(
          repository.removeDownvote(testEventId),
          throwsA(isA<UnlikeFailedException>()),
        );

        // Memory: record restored after rollback.
        expect(await repository.isDownvoted(testEventId), isTrue);
      });

      test('rolls back record + stream when deletion throws', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenThrow(Exception('relay unreachable'));

        repository = createRepository(withLocalStorage: false);
        await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        await expectLater(
          repository.removeDownvote(testEventId),
          throwsA(isA<Exception>()),
        );

        expect(await repository.isDownvoted(testEventId), isTrue);
      });

      test(
        'translates typed relay failures to UnlikeFailedException',
        () async {
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer(
            (_) async => createMockReaction(
              id: testReactionEventId,
              targetEventId: testEventId,
              content: '-',
            ),
          );
          final failedEvent = MockEvent();
          when(() => mockNostrClient.deleteEvent(any())).thenThrow(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.noResponse,
                event: failedEvent,
              ),
            ),
          );
          repository = createRepository(withLocalStorage: false);
          await repository.downvoteEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );

          await expectLater(
            repository.removeDownvote(testEventId),
            throwsA(isA<UnlikeFailedException>()),
          );
          expect(await repository.isDownvoted(testEventId), isTrue);
        },
      );
    });

    group('toggleDownvote', () {
      test('downvotes when not downvoted and returns true', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );

        repository = createRepository(withLocalStorage: false);
        final result = await repository.toggleDownvote(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, isTrue);
        expect(await repository.isDownvoted(testEventId), isTrue);
      });

      test(
        'removes downvote when already downvoted and returns false',
        () async {
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer(
            (_) async => createMockReaction(
              id: testReactionEventId,
              targetEventId: testEventId,
              content: '-',
            ),
          );
          final deletionEvent = MockEvent();
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => deletionEvent);

          repository = createRepository(withLocalStorage: false);
          await repository.downvoteEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );

          final result = await repository.toggleDownvote(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );

          expect(result, isFalse);
          expect(await repository.isDownvoted(testEventId), isFalse);
        },
      );
    });

    group('deleteReaction', () {
      test(
        'translates typed relay failures to UnlikeFailedException',
        () async {
          final failedEvent = MockEvent();
          when(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).thenThrow(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.noResponse,
                event: failedEvent,
              ),
            ),
          );
          repository = createRepository(withLocalStorage: false);

          await expectLater(
            repository.deleteReaction(testReactionEventId),
            throwsA(isA<UnlikeFailedException>()),
          );
        },
      );
    });

    group('isDownvoted / getDownvoteRecord / getDownvotedEventIds', () {
      test('isDownvoted returns false for non-downvoted event', () async {
        repository = createRepository(withLocalStorage: false);
        expect(await repository.isDownvoted(testEventId), isFalse);
      });

      test('getDownvoteRecord returns null when not downvoted', () async {
        repository = createRepository(withLocalStorage: false);
        expect(await repository.getDownvoteRecord(testEventId), isNull);
      });

      test('getDownvoteRecord returns record after downvoteEvent', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );

        repository = createRepository(withLocalStorage: false);
        await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        final record = await repository.getDownvoteRecord(testEventId);
        expect(record, isNotNull);
        expect(record!.targetEventId, equals(testEventId));
        expect(record.reactionEventId, equals(testReactionEventId));
      });

      test('getDownvotedEventIds returns ordered set', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
            content: '-',
          ),
        );

        repository = createRepository(withLocalStorage: false);
        await repository.downvoteEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(await repository.getDownvotedEventIds(), contains(testEventId));
        expect(
          await repository.getOrderedDownvotedEventIds(),
          equals([testEventId]),
        );
      });

      test(
        'watchDownvotedEventIds emits initial empty + new state on downvote',
        () async {
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer(
            (_) async => createMockReaction(
              id: testReactionEventId,
              targetEventId: testEventId,
              content: '-',
            ),
          );

          repository = createRepository(withLocalStorage: false);

          final emitted = <List<String>>[];
          final subscription = repository.watchDownvotedEventIds().listen(
            emitted.add,
          );

          await Future<void>.delayed(Duration.zero);
          expect(emitted.last, isEmpty);

          await repository.downvoteEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          );

          expect(emitted.last, contains(testEventId));
          await subscription.cancel();
        },
      );
    });

    group('getLikeCount', () {
      test('returns null and caches nothing when no relay answered', () async {
        when(() => mockNostrClient.countEvents(any())).thenThrow(
          const CountUnavailableException('No relay responded to COUNT'),
        );

        repository = createRepository();
        expect(await repository.getLikeCount(testEventId), isNull);
        expect(await repository.getLikeCount(testEventId), isNull);
        verify(() => mockNostrClient.countEvents(any())).called(2);
      });

      test('queries relay for like count by event ID', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 42));

        repository = createRepository();
        expect(await repository.getLikeCount(testEventId), equals(42));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test(
        'counts active likers across e and a tags',
        () async {
          const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';
          const likerA = 'liker_a_pubkey_1234567890abcdef';
          const likerB = 'liker_b_pubkey_1234567890abcdef';

          final eTagReaction = createMockReaction(
            id: 'reaction_e',
            targetEventId: testEventId,
            authorPubkey: likerA,
          );
          final duplicateFromATag = createMockReaction(
            id: 'reaction_e',
            targetEventId: testEventId,
            authorPubkey: likerA,
            tags: [
              ['e', testEventId],
              ['a', testAddressableId],
            ],
          );
          final aTagOnlyReaction = createMockReaction(
            id: 'reaction_a',
            targetEventId: testEventId,
            authorPubkey: likerB,
            tags: [
              ['a', testAddressableId],
            ],
          );

          mockQueryEventsSequence([
            [eTagReaction],
            [duplicateFromATag, aTagOnlyReaction],
            <Event>[],
          ]);

          repository = createRepository();
          final count = await repository.getLikeCount(
            testEventId,
            addressableId: testAddressableId,
          );

          expect(count, equals(2));
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).called(2);
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        },
      );

      test(
        'excludes deleted, downvoted, and blocked reactions from the count',
        () async {
          const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';
          const likerA = 'liker_a_pubkey_1234567890abcdef';
          const likerB = 'liker_b_pubkey_1234567890abcdef';
          const likerC = 'liker_c_pubkey_1234567890abcdef';
          const blockedLiker = 'blocked_liker_pubkey_1234567890abcdef';

          final deletedReaction = createMockReaction(
            id: 'reaction_deleted',
            targetEventId: testEventId,
            authorPubkey: likerA,
          );
          final downvote = createMockReaction(
            id: 'reaction_downvote',
            targetEventId: testEventId,
            authorPubkey: likerB,
            content: '-',
          );
          final liveReaction = createMockReaction(
            id: 'reaction_live',
            targetEventId: testEventId,
            authorPubkey: likerC,
            tags: [
              ['a', testAddressableId],
            ],
          );
          final blockedReaction = createMockReaction(
            id: 'reaction_blocked',
            targetEventId: testEventId,
            authorPubkey: blockedLiker,
            tags: [
              ['a', testAddressableId],
            ],
          );
          final deletion = MockEvent();
          when(() => deletion.pubkey).thenReturn(likerA);
          when(() => deletion.tags).thenReturn([
            ['e', 'reaction_deleted'],
          ]);

          mockQueryEventsSequence([
            [deletedReaction, downvote],
            [liveReaction, blockedReaction],
            [deletion],
            [deletedReaction, downvote],
            [liveReaction, blockedReaction],
            [deletion],
          ]);

          repository = createRepository(
            blockFilter: (pubkey) {
              return pubkey == blockedLiker;
            },
          );
          final count = await repository.getLikeCount(
            testEventId,
            addressableId: testAddressableId,
          );
          final likers = await repository.fetchEventLikers(
            eventId: testEventId,
            addressableId: testAddressableId,
          );

          expect(count, equals(likers.pubkeys.length));
          expect(likers.pubkeys, [likerC]);
        },
      );

      test(
        'returns null and caches nothing when the addressable read runs out '
        'of time (#10846)',
        () async {
          const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';
          final reaction = createMockReaction(
            id: 'reaction_e',
            targetEventId: testEventId,
            authorPubkey: 'liker_a_pubkey_1234567890abcdef',
          );
          final laterReaction = createMockReaction(
            id: 'reaction_later',
            targetEventId: testEventId,
            authorPubkey: 'liker_b_pubkey_1234567890abcdef',
          );
          var finished = false;
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[reaction, if (finished) laterReaction],
              timedOut: !finished,
              noRelays: false,
            ),
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository();
          final whileUnfinished = await repository.getLikeCount(
            testEventId,
            addressableId: testAddressableId,
          );
          finished = true;
          final onceFinished = await repository.getLikeCount(
            testEventId,
            addressableId: testAddressableId,
          );

          expect(whileUnfinished, isNull);
          expect(onceFinished, equals(2));
        },
      );

      test(
        'reads an addressable count without waiting for every relay (#10846)',
        () async {
          const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';
          stubSettledReads([
            createMockReaction(
              id: 'reaction_e',
              targetEventId: testEventId,
              authorPubkey: 'liker_a_pubkey_1234567890abcdef',
            ),
          ]);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository();
          final count = await repository.getLikeCount(
            testEventId,
            addressableId: testAddressableId,
          );

          expect(count, equals(1));
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(
                named: 'requireAllRelaysSettled',
                that: isFalse,
              ),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).called(2);
        },
      );

      test('ignores empty addressableId', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 7));

        repository = createRepository();
        final count = await repository.getLikeCount(
          testEventId,
          addressableId: '',
        );

        expect(count, equals(7));
        // Should only call once (e-tag only) since addressableId is empty
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('returns cached count on second call without relay query', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 42));

        repository = createRepository();

        final first = await repository.getLikeCount(testEventId);
        final second = await repository.getLikeCount(testEventId);

        expect(first, equals(42));
        expect(second, equals(42));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('cache is adjusted after likeEvent', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 10));

        final reactionEvent = MockEvent();
        when(() => reactionEvent.id).thenReturn('reaction_1');
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => reactionEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => []);
        when(
          () => mockLocalStorage.isLiked(any()),
        ).thenAnswer((_) async => false);

        repository = createRepository();

        await repository.getLikeCount(testEventId);
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );
        final cached = await repository.getLikeCount(testEventId);

        expect(cached, equals(11));
      });

      test('cache is adjusted after offline likeEvent', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 10));

        var queuedAction = false;
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queuedAction = true;
              },
        );

        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => []);
        when(
          () => mockLocalStorage.isLiked(any()),
        ).thenAnswer((_) async => false);

        await repository.getLikeCount(testEventId);
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );
        final cached = await repository.getLikeCount(testEventId);

        expect(queuedAction, isTrue);
        expect(cached, equals(11));
      });

      test('cache is adjusted after unlikeEvent', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 10));
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => MockEvent());

        repository = createRepository();
        await repository.initialize();

        await repository.getLikeCount(testEventId);
        await repository.unlikeEvent(testEventId);
        final cached = await repository.getLikeCount(testEventId);

        expect(cached, equals(9));
      });

      test('clearCache resets count cache', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 42));
        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = createRepository();
        await repository.getLikeCount(testEventId);
        await repository.clearCache();

        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 99));

        final fresh = await repository.getLikeCount(testEventId);
        expect(fresh, equals(99));
        verify(() => mockNostrClient.countEvents(any())).called(2);
      });
    });

    group('getLikeCounts', () {
      test('returns empty map for empty input', () async {
        repository = createRepository();
        expect(await repository.getLikeCounts([]), isEmpty);
        verifyNoFallbackReads();
      });

      test('queries relay for multiple event counts', () async {
        const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';
        const eventId2 = 'event_id_2_1234567890abcdef01234567890abcdef';
        const eventId3 = 'event_id_3_1234567890abcdef01234567890abcdef';

        final mockReaction1 = MockEvent();
        when(() => mockReaction1.tags).thenReturn([
          ['e', eventId1],
        ]);
        final mockReaction2 = MockEvent();
        when(() => mockReaction2.tags).thenReturn([
          ['e', eventId1],
        ]);
        final mockReaction3 = MockEvent();
        when(() => mockReaction3.tags).thenReturn([
          ['e', eventId2],
        ]);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockReaction1, mockReaction2, mockReaction3],
        );

        repository = createRepository();
        final result = await repository.getLikeCounts([
          eventId1,
          eventId2,
          eventId3,
        ]);

        expect(result, {eventId1: 2, eventId2: 1, eventId3: 0});
      });

      test(
        'chunks the reaction query so no REQ exceeds the frame limit',
        () async {
          // 600 target ids must split into 2 `#e` chunks (500 + 100). A single
          // filter with all of them approaches the relay's
          // max_message_length, and an oversized frame errors the socket —
          // queryEvents then fails open and every count reads 0 (#5751).
          final eventIds = [for (var i = 0; i < 600; i++) 'event_id_$i'];
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository();
          await repository.getLikeCounts(eventIds);

          final filters =
              verify(() => mockNostrClient.queryEvents(captureAny())).captured
                  .cast<List<Filter>>()
                  .map((filters) => filters.single)
                  .toList();

          expect(filters, hasLength(2));
          expect(filters[0].e, hasLength(500));
          expect(filters[1].e, hasLength(100));
          expect(
            {...filters[0].e!, ...filters[1].e!},
            hasLength(600),
            reason: 'chunks partition every id without overlap',
          );
        },
      );

      test(
        'chunks the reaction query on the addressable path too',
        () async {
          // The addressable branch resolves through a different call site, so
          // it needs its own guard against an oversized `#e` frame.
          final eventIds = [for (var i = 0; i < 600; i++) 'event_id_$i'];
          stubSettledReads(<Event>[]);

          repository = createRepository();
          await repository.getLikeCounts(
            eventIds,
            addressableIds: {
              for (final id in eventIds) id: '34236:author_pubkey:$id',
            },
          );

          final reactionFilters =
              verify(
                    () => mockNostrClient.queryEventsDetailed(
                      captureAny(),
                      requireAllRelaysSettled: any(
                        named: 'requireAllRelaysSettled',
                      ),
                      acceptRelayClosedWhenOthersAnswered: any(
                        named: 'acceptRelayClosedWhenOthersAnswered',
                      ),
                    ),
                  ).captured
                  .cast<List<Filter>>()
                  .map((filters) => filters.single)
                  .where(
                    (f) => f.kinds?.contains(EventKind.reaction) ?? false,
                  )
                  .toList();
          final reactionEFilters = reactionFilters
              .where((filter) => filter.e != null)
              .toList();
          final reactionAFilters = reactionFilters
              .where((filter) => filter.a != null)
              .toList();

          expect(reactionEFilters, hasLength(2));
          for (final filter in reactionEFilters) {
            expect(filter.e!.length, lessThanOrEqualTo(500));
          }
          expect(
            {for (final f in reactionEFilters) ...f.e!},
            hasLength(600),
            reason: 'chunks partition every id without overlap',
          );
          expect(reactionAFilters, hasLength(2));
          for (final filter in reactionAFilters) {
            expect(filter.a!.length, lessThanOrEqualTo(500));
          }
          expect(
            {for (final f in reactionAFilters) ...f.a!},
            hasLength(600),
            reason: 'chunks partition every coordinate without overlap',
          );
        },
      );

      test('deduplicates a reaction returned from two chunks', () async {
        // Each chunk is its own queryEvents call with its own dedup box, so a
        // reaction targeting an event in chunk 1 can come back from both.
        // _queryChunked must deduplicate it before counting.
        final eventIds = [for (var i = 0; i < 600; i++) 'event_id_$i'];
        final reaction = createMockReaction(
          id: 'reaction_spanning_chunks',
          targetEventId: 'event_id_0',
          tags: [
            ['e', 'event_id_500'],
          ],
        );
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [reaction]);

        repository = createRepository();
        final counts = await repository.getLikeCounts(eventIds);

        expect(counts['event_id_0'], 0);
        expect(counts['event_id_500'], 1);
      });

      test('counts a reaction only for its last e tag', () async {
        const threadRoot = 'thread_root_event_1234567890abcdef';
        const reactedTo = 'reacted_to_event_abcdef1234567890';
        final reaction = createMockReaction(
          id: 'reaction_with_thread_context',
          targetEventId: threadRoot,
          tags: [
            ['e', threadRoot],
            ['e', reactedTo],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [reaction]);

        repository = createRepository();
        final counts = await repository.getLikeCounts([threadRoot, reactedTo]);

        expect(counts, {threadRoot: 0, reactedTo: 1});
      });

      test('handles events with non-list or empty tags', () async {
        const eventId = 'event_id_1234567890abcdef01234567890abcdef';

        final mockReaction1 = MockEvent();
        when(() => mockReaction1.tags).thenReturn([
          ['not_a_list'],
        ]);
        final mockReaction2 = MockEvent();
        when(() => mockReaction2.tags).thenReturn([]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockReaction1, mockReaction2]);

        repository = createRepository();
        expect(await repository.getLikeCounts([eventId]), {eventId: 0});
      });

      test(
        'queries by both e and a tags when addressableIds provided',
        () async {
          const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';
          const eventId2 = 'event_id_2_1234567890abcdef01234567890abcdef';
          const aTag1 = '34236:author1:d1';
          const aTag2 = '34236:author2:d2';
          const likerA = 'liker_a_pubkey_1234567890abcdef';
          const likerB = 'liker_b_pubkey_1234567890abcdef';
          const likerC = 'liker_c_pubkey_1234567890abcdef';

          // Reaction found via e-tag for event1
          final mockReactionByE = createMockReaction(
            id: 'reaction_e_event1',
            targetEventId: eventId1,
            authorPubkey: likerA,
          );

          // Reactions found via a-tag for event2
          final mockReactionByA1 = createMockReaction(
            id: 'reaction_a_event2_1',
            targetEventId: eventId2,
            authorPubkey: likerB,
            tags: [
              ['a', aTag2],
            ],
          );
          final mockReactionByA2 = createMockReaction(
            id: 'reaction_a_event2_2',
            targetEventId: eventId2,
            authorPubkey: likerC,
            tags: [
              ['a', aTag2],
            ],
          );

          mockQueryEventsSequence([
            [mockReactionByE],
            [mockReactionByA1, mockReactionByA2],
            <Event>[],
          ]);

          repository = createRepository();
          final counts = await repository.getLikeCounts(
            [eventId1, eventId2],
            addressableIds: {eventId1: aTag1, eventId2: aTag2},
          );

          // event1 has 1 from e-tag, event2 has 2 from a-tag
          expect(counts, {eventId1: 1, eventId2: 2});
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).called(2);
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        },
      );

      test('counts distinct likers when merging e and a tag results', () async {
        const eventId = 'event_id_1234567890abcdef01234567890abcdef';
        const aTag = '34236:author:d-tag';
        const likerA = 'liker_a_pubkey_1234567890abcdef';
        const likerB = 'liker_b_pubkey_1234567890abcdef';
        const likerC = 'liker_c_pubkey_1234567890abcdef';
        const likerD = 'liker_d_pubkey_1234567890abcdef';

        final mockReactionByE1 = createMockReaction(
          id: 'reaction_e_1',
          targetEventId: eventId,
          authorPubkey: likerA,
        );
        final mockReactionByE2 = createMockReaction(
          id: 'reaction_e_2',
          targetEventId: eventId,
          authorPubkey: likerB,
        );
        final mockReactionByE3 = createMockReaction(
          id: 'reaction_e_3',
          targetEventId: eventId,
          authorPubkey: likerC,
        );

        // One a-tag reaction is from an e-tag liker; only likerD is new.
        final mockReactionByA1 = createMockReaction(
          id: 'reaction_a_duplicate_pubkey',
          targetEventId: eventId,
          authorPubkey: likerC,
          tags: [
            ['a', aTag],
          ],
        );
        final mockReactionByA2 = createMockReaction(
          id: 'reaction_a_new_pubkey',
          targetEventId: eventId,
          authorPubkey: likerD,
          tags: [
            ['a', aTag],
          ],
        );

        mockQueryEventsSequence([
          [mockReactionByE1, mockReactionByE2, mockReactionByE3],
          [mockReactionByA1, mockReactionByA2],
          <Event>[],
        ]);

        repository = createRepository();
        final counts = await repository.getLikeCounts(
          [eventId],
          addressableIds: {eventId: aTag},
        );

        expect(counts[eventId], equals(4));
      });

      test(
        'applies resolved-liker semantics to non-addressable ids in a mixed '
        'batch',
        () async {
          // Production shape: addressableIds covers only the addressable subset
          // (video_event_service.dart:4809). When any uncached id is
          // addressable, ALL uncached ids resolve through the distinct-liker
          // path — so the non-addressable id here must be deduped + filtered
          // too, not raw-tallied.
          const addrEvent = 'addr_event_1234567890abcdef01234567890abcdef';
          const plainEvent = 'plain_event_1234567890abcdef01234567890abcdef';
          const aTag = '34236:author:d-tag';
          const likerA = 'liker_a_pubkey_1234567890abcdef';
          const likerB = 'liker_b_pubkey_1234567890abcdef';
          const likerC = 'liker_c_pubkey_1234567890abcdef';

          // plainEvent: same liker reacts twice (dedupe to 1) + a downvote
          // (excluded) => resolved count 1; a raw tally would give 3.
          final plainReaction1 = createMockReaction(
            id: 'plain_reaction_1',
            targetEventId: plainEvent,
            authorPubkey: likerA,
          );
          final plainReactionDuplicatePubkey = createMockReaction(
            id: 'plain_reaction_2',
            targetEventId: plainEvent,
            authorPubkey: likerA,
          );
          final plainDownvote = createMockReaction(
            id: 'plain_reaction_downvote',
            targetEventId: plainEvent,
            authorPubkey: likerB,
            content: '-',
          );
          // addrEvent: one e-tag liker + one a-tag liker => 2 distinct.
          final addrReactionByE = createMockReaction(
            id: 'addr_reaction_e',
            targetEventId: addrEvent,
            authorPubkey: likerB,
          );
          final addrReactionByA = createMockReaction(
            id: 'addr_reaction_a',
            targetEventId: addrEvent,
            authorPubkey: likerC,
            tags: [
              ['a', aTag],
            ],
          );

          mockQueryEventsSequence([
            [
              plainReaction1,
              plainReactionDuplicatePubkey,
              plainDownvote,
              addrReactionByE,
            ],
            [addrReactionByA],
            <Event>[],
          ]);

          repository = createRepository();
          final counts = await repository.getLikeCounts(
            [addrEvent, plainEvent],
            addressableIds: {addrEvent: aTag},
          );

          expect(counts[plainEvent], equals(1));
          expect(counts[addrEvent], equals(2));
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).called(2);
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        },
      );

      test(
        'caches resolved addressable counts so a repeat batch skips relays',
        () async {
          const eventId = 'cached_addr_event_1234567890abcdef0123456789';
          const aTag = '34236:author:d-tag';
          const likerA = 'liker_a_pubkey_1234567890abcdef';

          final reactionByE = createMockReaction(
            id: 'reaction_e',
            targetEventId: eventId,
            authorPubkey: likerA,
          );

          mockQueryEventsSequence([
            [reactionByE],
            <Event>[],
            <Event>[],
          ]);

          repository = createRepository();
          final first = await repository.getLikeCounts(
            [eventId],
            addressableIds: {eventId: aTag},
          );
          final second = await repository.getLikeCounts(
            [eventId],
            addressableIds: {eventId: aTag},
          );

          expect(first[eventId], equals(1));
          expect(second[eventId], equals(1));
          // First batch: e + a + deletion = 3 queries; the second is served
          // from _likeCountCache with no further relay calls.
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).called(2);
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        },
      );

      test(
        'leaves out ids whose addressable read ran out of time, and asks '
        'again next time (#10846)',
        () async {
          const eventId = 'unfinished_addr_event_1234567890abcdef0123';
          const aTag = '34236:author:d-tag';
          final reaction = createMockReaction(
            id: 'reaction_e',
            targetEventId: eventId,
            authorPubkey: 'liker_a_pubkey_1234567890abcdef',
          );
          final laterReaction = createMockReaction(
            id: 'reaction_later',
            targetEventId: eventId,
            authorPubkey: 'liker_b_pubkey_1234567890abcdef',
          );
          var finished = false;
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).thenAnswer(
            (_) async => (
              events: <Event>[reaction, if (finished) laterReaction],
              timedOut: !finished,
              noRelays: false,
            ),
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository();
          final whileUnfinished = await repository.getLikeCounts(
            [eventId],
            addressableIds: {eventId: aTag},
          );
          finished = true;
          final onceFinished = await repository.getLikeCounts(
            [eventId],
            addressableIds: {eventId: aTag},
          );

          expect(whileUnfinished, isEmpty);
          expect(onceFinished, equals({eventId: 2}));
        },
      );

      test(
        'reads addressable counts without waiting for every relay (#10846)',
        () async {
          const eventId = 'settle_window_event_1234567890abcdef012345';
          const aTag = '34236:author:d-tag';
          stubSettledReads([
            createMockReaction(
              id: 'reaction_e',
              targetEventId: eventId,
              authorPubkey: 'liker_a_pubkey_1234567890abcdef',
            ),
          ]);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository();
          final counts = await repository.getLikeCounts(
            [eventId],
            addressableIds: {eventId: aTag},
          );

          expect(counts, equals({eventId: 1}));
          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(
                named: 'requireAllRelaysSettled',
                that: isFalse,
              ),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).called(2);
        },
      );

      test('skips relay query for already-cached event IDs', () async {
        const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';
        const eventId2 = 'event_id_2_1234567890abcdef01234567890abcdef';

        // Pre-populate cache via a single-event getLikeCount
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 5));

        repository = createRepository();
        await repository.getLikeCount(eventId1);

        // Now batch-fetch both; only eventId2 should hit relays
        final reactionForId2 = MockEvent();
        when(() => reactionForId2.tags).thenReturn([
          ['e', eventId2],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [reactionForId2]);

        final counts = await repository.getLikeCounts([eventId1, eventId2]);

        expect(counts[eventId1], equals(5));
        expect(counts[eventId2], equals(1));
        // countEvents called once for getLikeCount; queryEvents once for batch
        verify(() => mockNostrClient.countEvents(any())).called(1);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });
    });

    group('signer readiness (#6813)', () {
      test(
        'syncUserReactions filters on the resolved key, not the stale cache',
        () async {
          // The cache stays empty when the signer acquired its key after the
          // client initialized. Reading it directly would query
          // authors: [''], which matches no event.
          when(() => mockNostrClient.publicKey).thenReturn('');
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenAnswer((_) async => testUserPubkey);
          mockReadEventsSequence([<Event>[]]);

          repository = createRepository();
          await repository.syncUserReactions();

          final captured = verify(
            () => mockNostrClient.readEvents(
              captureAny(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              timeout: any(named: 'timeout'),
            ),
          ).captured.cast<List<Filter>>();
          expect(captured, isNotEmpty);
          for (final filters in captured) {
            expect(filters.single.authors, equals([testUserPubkey]));
          }
        },
      );

      test(
        'syncUserReactions keeps local data and skips relays with no key',
        () async {
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenAnswer((_) async => null);
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [createLikeRecord()],
          );

          repository = createRepository();
          final result = await repository.syncUserReactions();

          verifyNoFallbackReads();
          verifyNever(
            () => mockNostrClient.readEvents(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              timeout: any(named: 'timeout'),
            ),
          );
          expect(result.orderedEventIds, contains(testEventId));
        },
      );

      test(
        'syncUserReactions keeps local data when key resolution throws',
        () async {
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenThrow(StateError('signer unavailable'));
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [createLikeRecord()],
          );

          repository = createRepository();
          final result = await repository.syncUserReactions();

          verifyNoFallbackReads();
          verifyNever(
            () => mockNostrClient.readEvents(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              timeout: any(named: 'timeout'),
            ),
          );
          expect(result.orderedEventIds, contains(testEventId));
        },
      );

      test(
        'getUserVoteStatuses returns empty without querying with no key',
        () async {
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenAnswer((_) async => null);

          repository = createRepository();
          final statuses = await repository.getUserVoteStatuses([testEventId]);

          verifyNoFallbackReads();
          expect(statuses.upvotedIds, isEmpty);
          expect(statuses.downvotedIds, isEmpty);
        },
      );
    });

    group('syncUserReactions', () {
      test('fetches reactions from relay and stores locally', () async {
        const targetId = 'target_event_1234567890abcdef';
        const reactionId = 'reaction_event_1234567890abcdef';

        final mockReaction = createMockReaction(
          id: reactionId,
          targetEventId: targetId,
        );

        mockReadEventsSequence([
          [mockReaction],
          [],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetId));
        expect(result.eventIdToReactionId[targetId], equals(reactionId));
      });

      test('filters out deleted reactions using Kind 5 events', () async {
        const targetId1 = 'target_event_1_1234567890abcdef';
        const reactionId1 = 'reaction_event_1_1234567890abcdef';
        const targetId2 = 'target_event_2_1234567890abcdef';
        const reactionId2 = 'reaction_event_2_1234567890abcdef';

        final mockReaction1 = createMockReaction(
          id: reactionId1,
          targetEventId: targetId1,
        );
        final mockReaction2 = createMockReaction(
          id: reactionId2,
          targetEventId: targetId2,
        );
        final mockDeletion = createMockDeletion([reactionId1]);

        mockReadEventsSequence([
          [mockReaction1, mockReaction2],
          [mockDeletion],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetId2));
        expect(result.orderedEventIds, isNot(contains(targetId1)));
      });

      test('removes deleted likes from local storage', () async {
        const targetId = 'target_event_1234567890abcdef';
        const reactionId = 'reaction_event_1234567890abcdef';

        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: targetId,
              reactionEventId: reactionId,
            ),
          ],
        );

        final mockReaction = createMockReaction(
          id: reactionId,
          targetEventId: targetId,
        );
        final mockDeletion = createMockDeletion([reactionId]);

        mockReadEventsSequence([
          [mockReaction],
          [mockDeletion],
        ]);
        when(
          () => mockLocalStorage.deleteLikeRecord(targetId),
        ).thenAnswer((_) async => true);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        await repository.syncUserReactions();

        verify(() => mockLocalStorage.deleteLikeRecord(targetId)).called(1);
      });

      test('ignores non-like reactions (content != "+")', () async {
        final mockReaction = createMockReaction(
          id: 'reaction_id_1234567890abcdef',
          targetEventId: 'target_id_1234567890abcdef',
          content: '-', // Dislike
        );

        mockReadEventsSequence([
          [mockReaction],
          [],
        ]);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isEmpty);
      });

      test('handles empty relay response', () async {
        mockReadEventsSequence([<Event>[]]);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isEmpty);
        expect(result.eventIdToReactionId, isEmpty);
      });

      test('falls back to local data when relay query fails', () async {
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: 'local_target_event_1234567890abcdef',
              reactionEventId: 'local_reaction_1234567890abcdef',
            ),
          ],
        );
        when(
          () => mockNostrClient.readEvents(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(Exception('Network error'));

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(
          result.orderedEventIds,
          contains('local_target_event_1234567890abcdef'),
        );
      });

      test(
        'throws SyncFailedException when relay fails and no local data',
        () async {
          when(
            () => mockNostrClient.readEvents(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              timeout: any(named: 'timeout'),
            ),
          ).thenThrow(Exception('Network error'));

          repository = createRepository();

          expect(
            () => repository.syncUserReactions(),
            throwsA(isA<SyncFailedException>()),
          );
        },
      );

      test('handles continuous like/unlike cycles correctly', () async {
        const targetId = 'target_event_1234567890abcdef';
        const reactionId1 = 'reaction_1_1234567890abcdef';
        const reactionId2 = 'reaction_2_1234567890abcdef';

        final mockReaction1 = createMockReaction(
          id: reactionId1,
          targetEventId: targetId,
        );
        final mockReaction2 = createMockReaction(
          id: reactionId2,
          targetEventId: targetId,
          createdAt: 1700000100,
        );
        final mockDeletion = createMockDeletion([reactionId1]);

        mockReadEventsSequence([
          [mockReaction1, mockReaction2],
          [mockDeletion],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetId));
        expect(result.eventIdToReactionId[targetId], equals(reactionId2));
      });

      test('handles deletion events with multiple e tags', () async {
        const targetId1 = 'target_1_1234567890abcdef';
        const reactionId1 = 'reaction_1_1234567890abcdef';
        const targetId2 = 'target_2_1234567890abcdef';
        const reactionId2 = 'reaction_2_1234567890abcdef';

        final mockReaction1 = createMockReaction(
          id: reactionId1,
          targetEventId: targetId1,
        );
        final mockReaction2 = createMockReaction(
          id: reactionId2,
          targetEventId: targetId2,
        );
        final mockDeletion = createMockDeletion([reactionId1, reactionId2]);

        mockReadEventsSequence([
          [mockReaction1, mockReaction2],
          [mockDeletion],
        ]);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isEmpty);
      });

      test(
        "keeps a reaction that only another account's deletion names",
        () async {
          const targetId = 'target_event_1234567890abcdef';
          const reactionId = 'reaction_event_1234567890abcdef';
          final mockReaction = createMockReaction(
            id: reactionId,
            targetEventId: targetId,
          );
          // NIP-09: only the reaction's author can retract it.
          final foreignDeletion = createMockDeletion(
            [reactionId],
            authorPubkey: 'another_account_pubkey_1234567890abcdef',
          );

          mockReadEventsSequence([
            [mockReaction],
            [foreignDeletion],
          ]);
          when(
            () => mockLocalStorage.saveLikeRecordsBatch(any()),
          ).thenAnswer((_) async {});

          repository = createRepository();
          final result = await repository.syncUserReactions();

          expect(result.orderedEventIds, contains(targetId));
        },
      );

      test('updates newer record when duplicate target events exist', () async {
        const targetId = 'target_event_1234567890abcdef';
        const olderReactionId = 'older_reaction_1234567890abcdef';
        const newerReactionId = 'newer_reaction_1234567890abcdef';

        final mockOlder = createMockReaction(
          id: olderReactionId,
          targetEventId: targetId,
        );
        final mockNewer = createMockReaction(
          id: newerReactionId,
          targetEventId: targetId,
          createdAt: 1700000100,
        );

        mockReadEventsSequence([
          [mockOlder, mockNewer],
          [],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.eventIdToReactionId[targetId], equals(newerReactionId));
      });

      // #6123: rows persisted before the addressable_id column existed
      // carry no coordinate, and the relay copy of the same reaction is
      // never *newer*, so the freshness guard alone would skip it and the
      // coordinate would stay null forever.
      test(
        'backfills addressableId onto a stored record when the relay copy '
        'of the same reaction is same-age but carries a coordinate the '
        'stored record lacks',
        () async {
          const oldEventId = 'old_event_id_1234567890abcdef';
          const newEventId = 'new_edit_event_id_1234567890abcdef';
          const reactionId = 'reaction_event_id_1234567890abcdef';
          const coordinate = '34236:$testAuthorPubkey:test-d-tag';

          // Persisted pre-migration row: no addressableId, same instant as
          // the relay reaction (so createdAt.isAfter is false).
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              createLikeRecord(
                targetEventId: oldEventId,
                reactionEventId: reactionId,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  defaultTimestamp * 1000,
                ),
              ),
            ],
          );
          final relayReaction = createMockReaction(
            id: reactionId,
            targetEventId: oldEventId,
            authorPubkey: testUserPubkey,
            tags: [
              ['e', oldEventId],
              ['a', coordinate],
            ],
          );
          mockReadEventsSequence([
            [relayReaction],
            <Event>[],
          ]);
          when(
            () => mockLocalStorage.saveLikeRecordsBatch(any()),
          ).thenAnswer((_) async {});

          repository = createRepository();
          await repository.syncUserReactions();

          expect(
            await repository.isLikedResolvingCoordinate(
              eventId: newEventId,
              addressableId: coordinate,
            ),
            isTrue,
          );
          verify(
            () => mockLocalStorage.saveLikeRecordsBatch(
              any(
                that: contains(
                  isA<LikeRecord>()
                      .having(
                        (r) => r.targetEventId,
                        'targetEventId',
                        oldEventId,
                      )
                      .having(
                        (r) => r.addressableId,
                        'addressableId',
                        coordinate,
                      ),
                ),
              ),
            ),
          ).called(1);
        },
      );

      // #6123: the backfill exemption must not repoint a stored record at a
      // *different* (older) reaction just because that reaction carries a
      // coordinate — unlike would then delete the wrong wire event.
      test(
        'does not replace a stored newer coordinate-less record with a '
        'different older reaction that carries a coordinate',
        () async {
          const targetId = 'target_event_1234567890abcdef';
          const newerReactionId = 'newer_reaction_1234567890abcdef';
          const olderReactionId = 'older_reaction_1234567890abcdef';
          const coordinate = '34236:$testAuthorPubkey:test-d-tag';

          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              createLikeRecord(
                targetEventId: targetId,
                reactionEventId: newerReactionId,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  (defaultTimestamp + 100) * 1000,
                ),
              ),
            ],
          );
          final olderRelayReaction = createMockReaction(
            id: olderReactionId,
            targetEventId: targetId,
            authorPubkey: testUserPubkey,
            tags: [
              ['e', targetId],
              ['a', coordinate],
            ],
          );
          mockReadEventsSequence([
            [olderRelayReaction],
            <Event>[],
          ]);

          repository = createRepository();
          final result = await repository.syncUserReactions();

          expect(
            result.eventIdToReactionId[targetId],
            equals(newerReactionId),
          );
          expect(await repository.isLikedByCoordinate(coordinate), isFalse);
          verifyNever(() => mockLocalStorage.saveLikeRecordsBatch(any()));
        },
      );
    });

    group('fetchUserLikes', () {
      const otherUserPubkey = 'other_user_pubkey_1234567890abcdef';

      test('fetches likes for another user from relay', () async {
        const targetId = 'target_event_1234567890abcdef';

        final mockReaction = MockEvent();
        when(() => mockReaction.content).thenReturn('+');
        when(() => mockReaction.createdAt).thenReturn(defaultTimestamp);
        when(() => mockReaction.tags).thenReturn([
          ['e', targetId],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockReaction]);

        repository = createRepository();
        expect(await repository.fetchUserLikes(otherUserPubkey), [targetId]);
      });

      test(
        'binds to the last e tag when a peer threads its reaction',
        () async {
          const threadRoot = 'thread_root_event_1234567890abcdef';
          const reactedTo = 'reacted_to_event_abcdef1234567890';

          // NIP-25: "If a client decides to include other `e`, which not
          // recommended, the target event `id` should be last of the `e` tags."
          final mockReaction = MockEvent();
          when(() => mockReaction.content).thenReturn('+');
          when(() => mockReaction.createdAt).thenReturn(defaultTimestamp);
          when(() => mockReaction.tags).thenReturn([
            ['e', threadRoot],
            ['e', reactedTo],
          ]);

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [mockReaction]);

          repository = createRepository();
          expect(await repository.fetchUserLikes(otherUserPubkey), [reactedTo]);
        },
      );

      test('returns likes ordered by recency', () async {
        const olderId = 'older_target_1234567890abcdef';
        const newerId = 'newer_target_1234567890abcdef';

        final mockOlder = MockEvent();
        when(() => mockOlder.content).thenReturn('+');
        when(() => mockOlder.createdAt).thenReturn(1700000000);
        when(() => mockOlder.tags).thenReturn([
          ['e', olderId],
        ]);

        final mockNewer = MockEvent();
        when(() => mockNewer.content).thenReturn('+');
        when(() => mockNewer.createdAt).thenReturn(1700000100);
        when(() => mockNewer.tags).thenReturn([
          ['e', newerId],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockOlder, mockNewer]);

        repository = createRepository();
        expect(await repository.fetchUserLikes(otherUserPubkey), [
          newerId,
          olderId,
        ]);
      });

      test('deduplicates target event IDs', () async {
        const targetId = 'target_event_1234567890abcdef';

        final mockReaction1 = MockEvent();
        when(() => mockReaction1.content).thenReturn('+');
        when(() => mockReaction1.createdAt).thenReturn(1700000000);
        when(() => mockReaction1.tags).thenReturn([
          ['e', targetId],
        ]);

        final mockReaction2 = MockEvent();
        when(() => mockReaction2.content).thenReturn('+');
        when(() => mockReaction2.createdAt).thenReturn(1700000100);
        when(() => mockReaction2.tags).thenReturn([
          ['e', targetId],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockReaction1, mockReaction2]);

        repository = createRepository();
        final result = await repository.fetchUserLikes(otherUserPubkey);

        expect(result, hasLength(1));
        expect(result[0], equals(targetId));
      });

      test('ignores non-like reactions', () async {
        final mockReaction = MockEvent();
        when(() => mockReaction.content).thenReturn('-'); // Dislike
        when(() => mockReaction.createdAt).thenReturn(defaultTimestamp);
        when(() => mockReaction.tags).thenReturn([
          ['e', 'target_id'],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockReaction]);

        repository = createRepository();
        expect(await repository.fetchUserLikes(otherUserPubkey), isEmpty);
      });

      test('throws FetchLikesFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        repository = createRepository();

        expect(
          () => repository.fetchUserLikes(otherUserPubkey),
          throwsA(isA<FetchLikesFailedException>()),
        );
      });
    });

    group('fetchEventLikers', () {
      const targetEventId = 'target_event_1234567890abcdef';
      const addressableId = '34236:author_pubkey_1234567890abcdef:d-tag';
      const likerA = 'liker_a_pubkey_1234567890abcdef';
      const likerB = 'liker_b_pubkey_1234567890abcdef';
      const likerC = 'liker_c_pubkey_1234567890abcdef';

      MockEvent createReaction({
        required String id,
        required String authorPubkey,
        String content = '+',
        int createdAt = defaultTimestamp,
        List<List<String>>? tags,
      }) {
        final event = MockEvent();
        when(() => event.id).thenReturn(id);
        when(() => event.pubkey).thenReturn(authorPubkey);
        when(() => event.content).thenReturn(content);
        when(() => event.createdAt).thenReturn(createdAt);
        when(() => event.tags).thenReturn(
          tags ??
              [
                ['e', targetEventId],
              ],
        );
        return event;
      }

      test('returns empty list when no reactions exist', () async {
        stubSettledReads(<Event>[]);

        repository = createRepository();
        expect(
          (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
          isEmpty,
        );
      });

      test('returns liker pubkeys ordered by recency', () async {
        final older = createReaction(
          id: 'reaction_older',
          authorPubkey: likerA,
          createdAt: 1699999900,
        );
        final newer = createReaction(
          id: 'reaction_newer',
          authorPubkey: likerB,
          createdAt: 1700000100,
        );

        mockQueryEventsSequence([
          [older, newer],
          <Event>[],
        ]);

        repository = createRepository();
        expect(
          (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
          [
            likerB,
            likerA,
          ],
        );
      });

      test('deduplicates pubkeys across e-tag and a-tag queries', () async {
        final eTagReaction = createReaction(
          id: 'reaction_shared',
          authorPubkey: likerA,
          createdAt: 1700000050,
        );
        final aTagOnlyReaction = createReaction(
          id: 'reaction_a_only',
          authorPubkey: likerB,
          createdAt: 1700000100,
          tags: [
            ['a', addressableId],
          ],
        );

        mockQueryEventsSequence([
          [eTagReaction],
          [eTagReaction, aTagOnlyReaction],
          <Event>[],
        ]);

        repository = createRepository();
        final likers = await repository.fetchEventLikers(
          eventId: targetEventId,
          addressableId: addressableId,
        );

        expect(likers.pubkeys, hasLength(2));
        expect(likers.pubkeys, [likerB, likerA]);
      });

      test('attributes a multi-e reaction only to its last e tag', () async {
        const threadRoot = 'thread_root_event_1234567890abcdef';
        final reaction = createReaction(
          id: 'reaction_with_thread_context',
          authorPubkey: likerA,
          tags: [
            ['e', threadRoot],
            ['e', targetEventId],
          ],
        );

        mockQueryEventsSequence([
          [reaction],
          <Event>[],
        ]);

        repository = createRepository();
        expect(
          (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
          [
            likerA,
          ],
        );
      });

      test(
        'chunks the Kind 5 deletion query so no REQ exceeds the frame limit',
        () async {
          // 600 reactions from distinct authors => the resolver must split the
          // deletion `#e` query into 2 chunks (500 + 100) so no single REQ
          // frame approaches the relay's max_message_length (#5751).
          final reactions = [
            for (var i = 0; i < 600; i++)
              createReaction(
                id: 'reaction_$i',
                authorPubkey: 'liker_pubkey_$i',
              ),
          ];
          // call 0: e-tag reaction query; calls 1-2: chunked deletion queries.
          mockQueryEventsSequence([reactions, <Event>[], <Event>[]]);

          repository = createRepository();
          final likers = await repository.fetchEventLikers(
            eventId: targetEventId,
          );
          expect(likers.pubkeys, hasLength(600));

          final calls = verify(
            () => mockNostrClient.queryEvents(captureAny()),
          ).captured.cast<List<Filter>>();
          // The reaction read is a settled read (#10846), so queryEvents sees
          // only the 2 chunked deletion queries.
          expect(calls, hasLength(2));

          final deletionFilters = calls
              .map((filters) => filters.single)
              .where(
                (f) => f.kinds?.contains(EventKind.eventDeletion) ?? false,
              )
              .toList();
          expect(deletionFilters, hasLength(2));
          expect(deletionFilters[0].e, hasLength(500));
          expect(deletionFilters[1].e, hasLength(100));
          for (final filter in deletionFilters) {
            expect(
              filter.authors,
              isNull,
              reason: 'authors filter dropped; consumer enforces author match',
            );
            expect(filter.e!.length, lessThanOrEqualTo(500));
          }
          // The chunks partition every fetched reaction id without overlap.
          final chunkedIds = <String>{
            ...deletionFilters[0].e!,
            ...deletionFilters[1].e!,
          };
          expect(chunkedIds, hasLength(600));
        },
      );

      test('excludes likers hidden by the block filter', () async {
        final blockedReaction = createReaction(
          id: 'reaction_blocked',
          authorPubkey: likerA,
          createdAt: 1700000100,
        );
        final allowedReaction = createReaction(
          id: 'reaction_allowed',
          authorPubkey: likerB,
          createdAt: 1699999900,
        );

        mockQueryEventsSequence([
          [blockedReaction, allowedReaction],
          <Event>[],
        ]);

        repository = createRepository(
          blockFilter: (pubkey) => pubkey == likerA,
        );
        expect(
          (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
          [
            likerB,
          ],
        );
      });

      test('excludes pubkeys whose only reactions are downvotes', () async {
        final downvote = createReaction(
          id: 'reaction_downvote',
          authorPubkey: likerA,
          content: '-',
          createdAt: 1699999900,
        );
        final upvote = createReaction(
          id: 'reaction_upvote',
          authorPubkey: likerB,
          createdAt: 1700000100,
        );

        mockQueryEventsSequence([
          [downvote, upvote],
          <Event>[],
        ]);

        repository = createRepository();
        expect(
          (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
          [
            likerB,
          ],
        );
      });

      test('excludes pubkeys whose reactions were deleted by author', () async {
        final deletedReaction = createReaction(
          id: 'reaction_deleted',
          authorPubkey: likerA,
          createdAt: 1699999900,
        );
        final liveReaction = createReaction(
          id: 'reaction_live',
          authorPubkey: likerB,
          createdAt: 1700000100,
        );

        final deletion = MockEvent();
        when(() => deletion.pubkey).thenReturn(likerA);
        when(() => deletion.tags).thenReturn([
          ['e', 'reaction_deleted'],
        ]);

        mockQueryEventsSequence([
          [deletedReaction, liveReaction],
          [deletion],
        ]);

        repository = createRepository();
        expect(
          (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
          [
            likerB,
          ],
        );
      });

      test(
        'includes pubkey when only some of their reactions were deleted',
        () async {
          final deletedReaction = createReaction(
            id: 'reaction_deleted',
            authorPubkey: likerA,
            createdAt: 1699999900,
          );
          final liveReaction = createReaction(
            id: 'reaction_live',
            authorPubkey: likerA,
            createdAt: 1700000100,
          );
          final otherLiker = createReaction(
            id: 'reaction_other',
            authorPubkey: likerC,
            createdAt: 1700000050,
          );

          final deletion = MockEvent();
          when(() => deletion.pubkey).thenReturn(likerA);
          when(() => deletion.tags).thenReturn([
            ['e', 'reaction_deleted'],
          ]);

          mockQueryEventsSequence([
            [deletedReaction, liveReaction, otherLiker],
            [deletion],
          ]);

          repository = createRepository();
          expect(
            (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
            [
              likerA,
              likerC,
            ],
          );
        },
      );

      test('ignores Kind 5 deletions whose author does not match the reaction '
          'author', () async {
        // likerA reacted, but likerB publishes a Kind 5 referencing likerA's
        // reaction id. Without the same-author guard this would suppress
        // likerA's like.
        final reactionA = createReaction(
          id: 'reaction_a',
          authorPubkey: likerA,
          createdAt: 1700000050,
        );
        final reactionB = createReaction(
          id: 'reaction_b',
          authorPubkey: likerB,
          createdAt: 1700000100,
        );

        final spoofedDeletion = MockEvent();
        when(() => spoofedDeletion.pubkey).thenReturn(likerB);
        when(() => spoofedDeletion.tags).thenReturn([
          ['e', 'reaction_a'],
        ]);

        mockQueryEventsSequence([
          [reactionA, reactionB],
          [spoofedDeletion],
        ]);

        repository = createRepository();
        expect(
          (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
          [
            likerB,
            likerA,
          ],
        );
      });

      test('throws FetchLikersFailedException when relay query fails', () {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            acceptRelayClosedWhenOthersAnswered: any(
              named: 'acceptRelayClosedWhenOthersAnswered',
            ),
          ),
        ).thenThrow(Exception('Network error'));

        repository = createRepository();

        expect(
          () => repository.fetchEventLikers(eventId: targetEventId),
          throwsA(
            isA<FetchLikersFailedException>().having(
              (e) => e.message,
              'message',
              contains('Network error'),
            ),
          ),
        );
      });

      // #6021: the relay filters only match the current event id and the
      // coordinate, so reactions stranded on a superseded revision are
      // invisible to them. Funnelcake resolves the whole coordinate.
      group('Funnelcake source', () {
        late _MockFunnelcakeApiClient mockFunnelcake;

        setUp(() {
          mockFunnelcake = _MockFunnelcakeApiClient();
          when(() => mockFunnelcake.isAvailable).thenReturn(true);
        });

        void stubLikers(List<String> pubkeys) {
          when(
            () => mockFunnelcake.getVideoLikers(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) async => PaginatedPubkeys(pubkeys: pubkeys));
        }

        // #9358: the endpoint caps a page at 500. Without the cursor the
        // Liked-by list simply stopped there, showing 500 of 5,565 people
        // with nothing on screen saying so.
        group('pagination', () {
          void stubPage(List<String> pubkeys, {String? nextCursor}) {
            when(
              () => mockFunnelcake.getVideoLikers(
                any(),
                addressableId: any(named: 'addressableId'),
                cursor: any(named: 'cursor'),
              ),
            ).thenAnswer(
              (_) async =>
                  PaginatedPubkeys(pubkeys: pubkeys, nextCursor: nextCursor),
            );
          }

          test('surfaces the cursor for the next page', () async {
            stubPage([likerA], nextCursor: 'cursor_page_2');

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, equals([likerA]));
            expect(page.nextCursor, equals('cursor_page_2'));
            expect(page.hasMore, isTrue);
          });

          test('reports no cursor on the last page', () async {
            stubPage([likerA]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.hasMore, isFalse);
            expect(page.nextCursor, isNull);
          });

          test('forwards the cursor when continuing a page', () async {
            stubPage([likerB]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            await repository.fetchEventLikers(
              eventId: targetEventId,
              cursor: 'cursor_page_2',
            );

            verify(
              () => mockFunnelcake.getVideoLikers(
                targetEventId,
                addressableId: any(named: 'addressableId'),
                cursor: 'cursor_page_2',
              ),
            ).called(1);
          });

          // Swallowing this would clear the cursor and end the list early
          // and silently — the very defect pagination exists to fix.
          test(
            'surfaces a failed continuation instead of truncating',
            () async {
              when(
                () => mockFunnelcake.getVideoLikers(
                  any(),
                  addressableId: any(named: 'addressableId'),
                  cursor: any(named: 'cursor'),
                ),
              ).thenThrow(const FunnelcakeException('boom'));

              repository = createRepository(
                funnelcakeApiClient: mockFunnelcake,
              );

              await expectLater(
                repository.fetchEventLikers(
                  eventId: targetEventId,
                  cursor: 'cursor_page_2',
                ),
                throwsA(isA<FetchLikersFailedException>()),
              );
              verifyNoFallbackReads();
            },
          );

          // A failing FIRST page keeps its relay fallback — that is what
          // stops an unreachable API becoming an error screen.
          test(
            'still falls back to relays when the first page fails',
            () async {
              when(
                () => mockFunnelcake.getVideoLikers(
                  any(),
                  addressableId: any(named: 'addressableId'),
                  cursor: any(named: 'cursor'),
                ),
              ).thenThrow(const FunnelcakeException('boom'));
              stubSettledReads(<Event>[]);

              repository = createRepository(
                funnelcakeApiClient: mockFunnelcake,
              );
              final page = await repository.fetchEventLikers(
                eventId: targetEventId,
              );

              expect(page.pubkeys, isEmpty);
              verify(
                () => mockNostrClient.queryEventsDetailed(
                  any(),
                  requireAllRelaysSettled: true,
                  acceptRelayClosedWhenOthersAnswered: true,
                ),
              ).called(greaterThan(0));
            },
          );

          // The relay path cannot continue someone else's page, so falling
          // back on a continuation would re-serve the likers already on
          // screen instead of ending the list.
          test('ends the list when a continuation comes back empty', () async {
            stubPage([]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
              cursor: 'cursor_page_2',
            );

            expect(page.pubkeys, isEmpty);
            expect(page.hasMore, isFalse);
            verifyNoFallbackReads();
          });

          // A full page whose every row the block filter removed still
          // carries the cursor for the next one. Dropping it here would end
          // the list with pages still to come, silently — the defect this
          // pagination exists to remove.
          test(
            'keeps the cursor when a continuation is fully filtered',
            () async {
              stubPage([], nextCursor: 'cursor_page_3');

              repository = createRepository(
                funnelcakeApiClient: mockFunnelcake,
              );
              final page = await repository.fetchEventLikers(
                eventId: targetEventId,
                cursor: 'cursor_page_2',
              );

              expect(page.pubkeys, isEmpty);
              expect(page.nextCursor, equals('cursor_page_3'));
              expect(page.hasMore, isTrue);
              verifyNoFallbackReads();
            },
          );
        });

        test('serves the API list without querying relays', () async {
          stubLikers([likerC, likerA]);

          repository = createRepository(funnelcakeApiClient: mockFunnelcake);

          expect(
            (await repository.fetchEventLikers(
              eventId: targetEventId,
              addressableId: addressableId,
            )).pubkeys,
            equals([likerC, likerA]),
          );
          verifyNoFallbackReads();
        });

        test('forwards the addressable coordinate to the API', () async {
          stubLikers([likerA]);

          repository = createRepository(funnelcakeApiClient: mockFunnelcake);
          await repository.fetchEventLikers(
            eventId: targetEventId,
            addressableId: addressableId,
          );

          verify(
            () => mockFunnelcake.getVideoLikers(
              targetEventId,
              addressableId: addressableId,
            ),
          ).called(1);
        });

        test('still hides blocked likers the API cannot know about', () async {
          stubLikers([likerA, likerB, likerC]);

          repository = createRepository(
            funnelcakeApiClient: mockFunnelcake,
            blockFilter: (pubkey) => pubkey == likerB,
          );

          expect(
            (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
            equals([likerA, likerC]),
          );
        });

        test('serves each API liker once, most recent first', () async {
          stubLikers([likerC, likerA, likerC]);

          repository = createRepository(funnelcakeApiClient: mockFunnelcake);

          expect(
            (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
            equals([likerC, likerA]),
          );
        });

        test('falls back to relays when the API fails', () async {
          when(
            () => mockFunnelcake.getVideoLikers(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenThrow(const FunnelcakeException('boom'));
          stubSettledReads([
            createReaction(id: 'reaction_a', authorPubkey: likerA),
          ]);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository(funnelcakeApiClient: mockFunnelcake);

          expect(
            (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
            equals([likerA]),
          );
        });

        test('falls back to relays when the API returns nobody', () async {
          stubLikers([]);
          stubSettledReads([
            createReaction(id: 'reaction_a', authorPubkey: likerA),
          ]);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository(funnelcakeApiClient: mockFunnelcake);

          expect(
            (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
            equals([likerA]),
          );
        });

        test('falls back to relays when the API is unconfigured', () async {
          when(() => mockFunnelcake.isAvailable).thenReturn(false);
          stubSettledReads([
            createReaction(id: 'reaction_a', authorPubkey: likerA),
          ]);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository(funnelcakeApiClient: mockFunnelcake);

          expect(
            (await repository.fetchEventLikers(eventId: targetEventId)).pubkeys,
            equals([likerA]),
          );
          verifyNever(
            () => mockFunnelcake.getVideoLikers(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          );
        });

        // #10846: the relay fallback used to read through queryEvents, which
        // cannot say whether the relays finished, so a read cut short looked
        // exactly like a video nobody liked.
        group('relay fallback that does not finish', () {
          void apiFails() {
            when(
              () => mockFunnelcake.getVideoLikers(
                any(),
                addressableId: any(named: 'addressableId'),
              ),
            ).thenThrow(const FunnelcakeException('boom'));
          }

          setUp(() {
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => <Event>[]);
          });

          test('marks an empty answer from an unfinished read', () async {
            apiFails();
            stubSettledReads(<Event>[], finished: false);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, isEmpty);
            expect(page.isComplete, isFalse);
          });

          test('keeps the likers an unfinished read found, marked', () async {
            apiFails();
            stubSettledReads([
              createReaction(id: 'reaction_a', authorPubkey: likerA),
            ], finished: false);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, equals([likerA]));
            expect(page.isComplete, isFalse);
          });

          test('marks a read every relay finished as complete', () async {
            apiFails();
            stubSettledReads([
              createReaction(id: 'reaction_a', authorPubkey: likerA),
            ]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, equals([likerA]));
            expect(page.isComplete, isTrue);
          });

          test('treats a read no relay took as unfinished', () async {
            apiFails();
            stubSettledReads(<Event>[], noRelays: true);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.isComplete, isFalse);
          });

          test('trusts an API that listed nobody over an unfinished read '
              'that found nobody', () async {
            stubLikers([]);
            stubSettledReads(<Event>[], finished: false);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, isEmpty);
            expect(page.isComplete, isTrue);
          });

          test('marks people an unfinished read found after the API listed '
              'nobody', () async {
            stubLikers([]);
            stubSettledReads([
              createReaction(id: 'reaction_a', authorPubkey: likerA),
            ], finished: false);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, equals([likerA]));
            expect(page.isComplete, isFalse);
          });

          test('waits for every relay, settling on refusals once another '
              'relay answered', () async {
            apiFails();
            stubSettledReads(<Event>[]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            await repository.fetchEventLikers(
              eventId: targetEventId,
              addressableId: addressableId,
            );

            verify(
              () => mockNostrClient.queryEventsDetailed(
                any(),
                requireAllRelaysSettled: true,
                acceptRelayClosedWhenOthersAnswered: true,
              ),
            ).called(2);
          });
        });

        // #9357: /likers is built from what reached Funnelcake's own relay,
        // so a like retracted with a kind 5 published only to another relay is
        // still listed. Each row names the reaction it reports; a kind 5 from
        // the same key naming it, found on the relays, removes that person.
        // Who the API lists is still the API's call.
        group('retractions the API never saw', () {
          const reactionA =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
          const reactionB =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

          void stubLikersWithReactions(Map<String, String> reactionByLiker) {
            when(
              () => mockFunnelcake.getVideoLikers(
                any(),
                addressableId: any(named: 'addressableId'),
              ),
            ).thenAnswer(
              (_) async => PaginatedPubkeys(
                pubkeys: reactionByLiker.keys.toList(),
                eventIdByPubkey: reactionByLiker,
              ),
            );
          }

          void stubRetractionRead(
            List<Event> events, {
            QueryEnd endedBy = QueryEnd.complete,
          }) {
            when(
              () => mockNostrClient.readEvents(
                any(),
                requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer(
              (_) async => QueryResult(events: events, endedBy: endedBy),
            );
          }

          test('drops an API liker whose reaction the same key retracted '
              'on a relay', () async {
            stubLikersWithReactions({likerA: reactionA, likerB: reactionB});
            stubRetractionRead([
              createMockDeletion([reactionB], authorPubkey: likerB),
            ]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);

            expect(
              (await repository.fetchEventLikers(
                eventId: targetEventId,
              )).pubkeys,
              equals([likerA]),
            );
          });

          test('asks the relays for kind 5s naming the reactions it lists, '
              'and only those', () async {
            stubLikersWithReactions({likerA: reactionA, likerB: reactionB});
            stubRetractionRead(const <Event>[]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            await repository.fetchEventLikers(eventId: targetEventId);

            final filters =
                verify(
                      () => mockNostrClient.readEvents(
                        captureAny(),
                        requireAllRelaysSettled: any(
                          named: 'requireAllRelaysSettled',
                        ),
                        timeout: any(named: 'timeout'),
                      ),
                    ).captured.single
                    as List<Filter>;
            expect(filters, hasLength(1));
            expect(filters.single.kinds, equals(const [5]));
            expect(
              filters.single.e,
              unorderedEquals(const [reactionA, reactionB]),
            );
            verifyNoFallbackReads();
          });

          test('keeps a liker when somebody else signed the kind 5 naming '
              'their reaction', () async {
            stubLikersWithReactions({likerA: reactionA, likerB: reactionB});
            stubRetractionRead([
              createMockDeletion([reactionB], authorPubkey: likerC),
            ]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);

            expect(
              (await repository.fetchEventLikers(
                eventId: targetEventId,
              )).pubkeys,
              equals([likerA, likerB]),
            );
          });

          // The signer must own the reaction it names: a listed liker's kind
          // 5 naming another listed liker's reaction retracts neither.
          test('keeps both likers when one signed a kind 5 naming the '
              "other's reaction", () async {
            stubLikersWithReactions({likerA: reactionA, likerB: reactionB});
            stubRetractionRead([
              createMockDeletion([reactionB], authorPubkey: likerA),
            ]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);

            expect(
              (await repository.fetchEventLikers(
                eventId: targetEventId,
              )).pubkeys,
              equals([likerA, likerB]),
            );
          });

          test('keeps everyone when the relays found no retraction and did '
              'not all answer', () async {
            stubLikersWithReactions({likerA: reactionA, likerB: reactionB});
            stubRetractionRead(const <Event>[], endedBy: QueryEnd.settledEarly);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);

            expect(
              (await repository.fetchEventLikers(
                eventId: targetEventId,
              )).pubkeys,
              equals([likerA, likerB]),
            );
          });

          test('still drops a retraction found by a read that did not '
              'finish', () async {
            stubLikersWithReactions({likerA: reactionA, likerB: reactionB});
            stubRetractionRead([
              createMockDeletion([reactionB], authorPubkey: likerB),
            ], endedBy: QueryEnd.settledEarly);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);

            expect(
              (await repository.fetchEventLikers(
                eventId: targetEventId,
              )).pubkeys,
              equals([likerA]),
            );
          });

          test('keeps everyone when the retraction read throws', () async {
            stubLikersWithReactions({likerA: reactionA, likerB: reactionB});
            when(
              () => mockNostrClient.readEvents(
                any(),
                requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
                timeout: any(named: 'timeout'),
              ),
            ).thenThrow(Exception('relay pool unavailable'));

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);

            expect(
              (await repository.fetchEventLikers(
                eventId: targetEventId,
              )).pubkeys,
              equals([likerA, likerB]),
            );
          });

          test(
            'does not read the relays for rows that name no reaction',
            () async {
              stubLikers([likerA, likerB]);

              repository = createRepository(
                funnelcakeApiClient: mockFunnelcake,
              );

              expect(
                (await repository.fetchEventLikers(
                  eventId: targetEventId,
                )).pubkeys,
                equals([likerA, likerB]),
              );
              verifyNever(
                () => mockNostrClient.readEvents(
                  any(),
                  requireAllRelaysSettled: any(
                    named: 'requireAllRelaysSettled',
                  ),
                  timeout: any(named: 'timeout'),
                ),
              );
            },
          );

          // The API listed people, so it answered. Emptying that list with
          // confirmed retractions must not read as "the API had nobody":
          // the relay union would add people the API chose not to list.
          test('returns an empty page, not the relay union, when every '
              'listed liker was retracted', () async {
            when(
              () => mockFunnelcake.getVideoLikers(
                any(),
                addressableId: any(named: 'addressableId'),
              ),
            ).thenAnswer(
              (_) async => const PaginatedPubkeys(
                pubkeys: [likerA],
                eventIdByPubkey: {likerA: reactionA},
                nextCursor: 'cursor_page_2',
              ),
            );
            stubRetractionRead([
              createMockDeletion([reactionA], authorPubkey: likerA),
            ]);
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [
                createReaction(id: 'reaction_hidden', authorPubkey: likerC),
              ],
            );

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, isEmpty);
            expect(page.nextCursor, equals('cursor_page_2'));
            verifyNoFallbackReads();
          });

          test('checks only the rows that name a reaction and keeps the '
              'rest listed', () async {
            when(
              () => mockFunnelcake.getVideoLikers(
                any(),
                addressableId: any(named: 'addressableId'),
              ),
            ).thenAnswer(
              (_) async => const PaginatedPubkeys(
                pubkeys: [likerA, likerB, likerC],
                eventIdByPubkey: {likerA: reactionA, likerB: reactionB},
              ),
            );
            stubRetractionRead([
              createMockDeletion([reactionB], authorPubkey: likerB),
            ]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, equals([likerA, likerC]));
            final filters =
                verify(
                      () => mockNostrClient.readEvents(
                        captureAny(),
                        requireAllRelaysSettled: any(
                          named: 'requireAllRelaysSettled',
                        ),
                        timeout: any(named: 'timeout'),
                      ),
                    ).captured.single
                    as List<Filter>;
            expect(
              filters.single.e,
              unorderedEquals(const [reactionA, reactionB]),
            );
          });

          test('does not ask the relays about a blocked liker', () async {
            stubLikersWithReactions({likerA: reactionA, likerB: reactionB});
            stubRetractionRead(const <Event>[]);

            repository = createRepository(
              funnelcakeApiClient: mockFunnelcake,
              blockFilter: (pubkey) => pubkey == likerB,
            );
            await repository.fetchEventLikers(eventId: targetEventId);

            final filters =
                verify(
                      () => mockNostrClient.readEvents(
                        captureAny(),
                        requireAllRelaysSettled: any(
                          named: 'requireAllRelaysSettled',
                        ),
                        timeout: any(named: 'timeout'),
                      ),
                    ).captured.single
                    as List<Filter>;
            expect(filters.single.e, equals(const [reactionA]));
          });

          // Rows come from a REST body, and what they name goes into a relay
          // filter. Only a real event id may.
          test('sends only well-formed event ids to the relays', () async {
            stubLikersWithReactions({
              likerA: 'not-an-event-id',
              likerB: reactionB,
            });
            stubRetractionRead(const <Event>[]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, equals([likerA, likerB]));
            final filters =
                verify(
                      () => mockNostrClient.readEvents(
                        captureAny(),
                        requireAllRelaysSettled: any(
                          named: 'requireAllRelaysSettled',
                        ),
                        timeout: any(named: 'timeout'),
                      ),
                    ).captured.single
                    as List<Filter>;
            expect(filters.single.e, equals(const [reactionB]));
          });

          test('does not read the relays when no row names a well-formed '
              'event id', () async {
            stubLikersWithReactions({likerA: 'not-an-event-id'});

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, equals([likerA]));
            verifyNever(
              () => mockNostrClient.readEvents(
                any(),
                requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
                timeout: any(named: 'timeout'),
              ),
            );
          });

          test('asks about at most one chunk of reactions per page', () async {
            final likers = [for (var i = 0; i < 501; i++) 'liker_$i'];
            stubLikersWithReactions({
              for (var i = 0; i < likers.length; i++)
                likers[i]: i.toRadixString(16).padLeft(64, '0'),
            });
            stubRetractionRead(const <Event>[]);

            repository = createRepository(funnelcakeApiClient: mockFunnelcake);
            final page = await repository.fetchEventLikers(
              eventId: targetEventId,
            );

            expect(page.pubkeys, hasLength(501));
            final filters =
                verify(
                      () => mockNostrClient.readEvents(
                        captureAny(),
                        requireAllRelaysSettled: any(
                          named: 'requireAllRelaysSettled',
                        ),
                        timeout: any(named: 'timeout'),
                      ),
                    ).captured.single
                    as List<Filter>;
            expect(filters.single.e, hasLength(500));
          });

          test(
            'drops a retracted liker from a continuation page too',
            () async {
              when(
                () => mockFunnelcake.getVideoLikers(
                  any(),
                  addressableId: any(named: 'addressableId'),
                  cursor: 'cursor_page_2',
                ),
              ).thenAnswer(
                (_) async => const PaginatedPubkeys(
                  pubkeys: [likerA, likerB],
                  eventIdByPubkey: {likerA: reactionA, likerB: reactionB},
                  nextCursor: 'cursor_page_3',
                ),
              );
              stubRetractionRead([
                createMockDeletion([reactionB], authorPubkey: likerB),
              ]);

              repository = createRepository(
                funnelcakeApiClient: mockFunnelcake,
              );
              final page = await repository.fetchEventLikers(
                eventId: targetEventId,
                cursor: 'cursor_page_2',
              );

              expect(page.pubkeys, equals([likerA]));
              expect(page.nextCursor, equals('cursor_page_3'));
            },
          );
        });

        test('leaves getLikeCount on the relay resolver', () async {
          stubLikers([likerA, likerB, likerC]);
          stubSettledReads([
            createReaction(id: 'reaction_a', authorPubkey: likerA),
          ]);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository(funnelcakeApiClient: mockFunnelcake);

          expect(
            await repository.getLikeCount(
              targetEventId,
              addressableId: addressableId,
            ),
            equals(1),
          );
        });
      });
    });

    group('getLikeRecord', () {
      test('returns record when event is liked', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);

        repository = createRepository();
        final result = await repository.getLikeRecord(testEventId);

        expect(result, isNotNull);
        expect(result!.targetEventId, equals(testEventId));
      });

      test('returns null when event is not liked', () async {
        repository = createRepository();
        expect(await repository.getLikeRecord('nonexistent'), isNull);
      });
    });

    group('clearCache', () {
      test('clears local storage and in-memory cache', () async {
        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = createRepository();
        await repository.clearCache();

        verify(() => mockLocalStorage.clearAll()).called(1);
        expect(await repository.getLikedEventIds(), isEmpty);
      });

      test('does not throw when called after dispose', () async {
        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = createRepository()..dispose();

        // clearCache after dispose should not throw "Cannot add new events
        // after calling close" on the BehaviorSubject.
        await expectLater(repository.clearCache(), completes);
      });

      test('a failing clearAll leaves the in-memory cache intact', () async {
        // Stubbed here rather than in the shared setUp so the failure stays
        // adjacent to the test that depends on it.
        when(
          () => mockLocalStorage.clearAll(),
        ).thenThrow(StateError('database is dead'));
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            LikeRecord(
              targetEventId: testEventId,
              reactionEventId: 'reaction_$testEventId',
              createdAt: DateTime.utc(2026),
            ),
          ],
        );
        repository = createRepository();

        // Pin the baseline: the record is genuinely loaded before we act, so
        // the assertion after the throw cannot pass on an empty cache.
        expect(await repository.getLikedEventIds(), {testEventId});

        await expectLater(repository.clearCache(), throwsA(isA<StateError>()));

        // All-or-nothing: the durable store rejected the clear, so the caches
        // derived from it must still describe what is on disk.
        expect(await repository.getLikedEventIds(), {testEventId});
        expect(await repository.isLiked(testEventId), isTrue);
      });
    });

    group('watchLikedEventIds', () {
      test('seeds from local storage, then streams repository cache', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => MockEvent());
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: 'older_event_id_1234567890abcdef',
              reactionEventId: 'older_reaction_id_1234567890abcdef',
              createdAt: DateTime.utc(2024),
            ),
            createLikeRecord(
              targetEventId: 'newer_event_id_1234567890abcdef',
              reactionEventId: 'newer_reaction_id_1234567890abcdef',
              createdAt: DateTime.utc(2024, 1, 2),
            ),
          ],
        );

        repository = createRepository();
        final stream = StreamIterator(repository.watchLikedEventIds());

        expect(await stream.moveNext(), isTrue);
        expect(stream.current, [
          'newer_event_id_1234567890abcdef',
          'older_event_id_1234567890abcdef',
        ]);

        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(await stream.moveNext(), isTrue);
        expect(stream.current, [
          testEventId,
          'newer_event_id_1234567890abcdef',
          'older_event_id_1234567890abcdef',
        ]);

        await repository.unlikeEvent(testEventId);

        expect(await stream.moveNext(), isTrue);
        expect(stream.current, [
          'newer_event_id_1234567890abcdef',
          'older_event_id_1234567890abcdef',
        ]);

        await stream.cancel();
      });

      test('returns internal stream when no local storage', () async {
        repository = createRepository(withLocalStorage: false);
        expect(await repository.watchLikedEventIds().first, isEmpty);
      });
    });

    group('initialize', () {
      test('loads records from local storage', () async {
        when(
          () => mockNostrClient.resolvePublicKey(),
        ).thenAnswer((_) async => null);
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: 'event_a_1234567890abcdef',
              reactionEventId: 'reaction_a_1234567890abcdef',
            ),
          ],
        );

        repository = createRepository();
        await repository.initialize();

        expect(await repository.isLiked('event_a_1234567890abcdef'), isTrue);
      });

      test('sets up subscription when the client resolves a key', () async {
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        repository = createRepository();
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

        repository = createRepository();
        await repository.initialize();

        verifyNever(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        );
      });

      test(
        'subscribes with the resolved key when the publicKey cache is stale',
        () async {
          when(() => mockNostrClient.publicKey).thenReturn('');
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenAnswer((_) async => testUserPubkey);
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => const Stream.empty());

          repository = createRepository();
          await repository.initialize();

          final captured =
              verify(
                    () => mockNostrClient.subscribe(
                      captureAny(),
                      subscriptionId: any(named: 'subscriptionId'),
                    ),
                  ).captured.single
                  as List<Filter>;
          expect(captured.single.authors, equals([testUserPubkey]));
        },
      );

      test(
        'keeps the reactions subscription id within the NIP-01 cap from '
        'subscribe to dispose',
        () async {
          // A full-length hex key: the short fixture above would hide an id
          // that runs past the cap.
          const hexPubkey =
              'c3d4e5f6789012345678901234567890'
              'abcdef1234567890123456789012ab12';
          when(() => mockNostrClient.publicKey).thenReturn(hexPubkey);
          when(
            () => mockNostrClient.resolvePublicKey(),
          ).thenAnswer((_) async => hexPubkey);

          repository = createRepository();
          await repository.initialize();
          repository.dispose();

          final id =
              verify(
                    () => mockNostrClient.subscribe(
                      any(),
                      subscriptionId: captureAny(named: 'subscriptionId'),
                    ),
                  ).captured.single
                  as String;
          expect(
            id.length,
            lessThanOrEqualTo(nip01MaxSubscriptionIdLength),
            reason:
                '"$id" is ${id.length} characters; relays enforcing '
                'NIP-01 refuse the REQ',
          );
          expect(
            id,
            equals(scopedSubscriptionId('likes_repo_reactions', hexPubkey)),
          );
          verify(() => mockNostrClient.unsubscribe(id)).called(1);
        },
      );

      test('is idempotent', () async {
        when(
          () => mockNostrClient.resolvePublicKey(),
        ).thenAnswer((_) async => null);

        repository = createRepository();
        await repository.initialize();
        await repository.initialize();

        verify(() => mockLocalStorage.getAllLikeRecords()).called(1);
      });

      // #6123: likes persisted before the addressable_id column shipped
      // must self-heal at startup — waiting for a Liked Videos visit
      // leaves every pre-existing like carrying bug #6020.
      test(
        'backfills coordinates via syncUserReactions when a loaded record '
        'lacks an addressableId',
        () async {
          const oldEventId = 'old_event_id_1234567890abcdef';
          const newEventId = 'new_edit_event_id_1234567890abcdef';
          const reactionId = 'reaction_event_id_1234567890abcdef';
          const coordinate = '34236:$testAuthorPubkey:test-d-tag';

          when(() => mockNostrClient.hasKeys).thenReturn(true);
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => const Stream.empty());
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              createLikeRecord(
                targetEventId: oldEventId,
                reactionEventId: reactionId,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  defaultTimestamp * 1000,
                ),
              ),
            ],
          );
          final relayReaction = createMockReaction(
            id: reactionId,
            targetEventId: oldEventId,
            authorPubkey: testUserPubkey,
            tags: [
              ['e', oldEventId],
              ['a', coordinate],
            ],
          );
          mockReadEventsSequence([
            [relayReaction],
            <Event>[],
          ]);
          when(
            () => mockLocalStorage.saveLikeRecordsBatch(any()),
          ).thenAnswer((_) async {});

          repository = createRepository();
          await repository.initialize();

          // The reactions read, then the deletions naming the one it found.
          verify(
            () => mockNostrClient.readEvents(
              any(),
              requireAllRelaysSettled: true,
              timeout: any(named: 'timeout'),
            ),
          ).called(2);
          expect(
            await repository.isLikedResolvingCoordinate(
              eventId: newEventId,
              addressableId: coordinate,
            ),
            isTrue,
          );
        },
      );

      test(
        'reconciles relay state even when loaded records have coordinates',
        () async {
          when(() => mockNostrClient.hasKeys).thenReturn(true);
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => const Stream.empty());
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              createLikeRecord(
                addressableId: '34236:$testAuthorPubkey:test-d-tag',
              ),
            ],
          );
          mockReadEventsSequence([
            <Event>[],
            <Event>[],
          ]);

          repository = createRepository();
          await repository.initialize();

          // No reaction came back, so there is no deletion to look for.
          verify(
            () => mockNostrClient.readEvents(
              any(),
              requireAllRelaysSettled: true,
              timeout: any(named: 'timeout'),
            ),
          ).called(1);
        },
      );

      test(
        'completes and keeps local state when the backfill sync fails',
        () async {
          const oldEventId = 'old_event_id_1234567890abcdef';

          when(() => mockNostrClient.hasKeys).thenReturn(true);
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => const Stream.empty());
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [createLikeRecord(targetEventId: oldEventId)],
          );
          when(
            () => mockNostrClient.readEvents(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              timeout: any(named: 'timeout'),
            ),
          ).thenThrow(Exception('offline'));

          repository = createRepository();
          await repository.initialize();

          expect(await repository.isLiked(oldEventId), isTrue);
        },
      );
    });

    group('real-time sync', () {
      test('processes incoming reaction event', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        await repository.initialize();

        // Emit a Kind 7 reaction event
        final reactionEvent = MockEvent();
        when(() => reactionEvent.id).thenReturn(testReactionEventId);
        when(() => reactionEvent.kind).thenReturn(EventKind.reaction);
        when(() => reactionEvent.content).thenReturn('+');
        when(() => reactionEvent.pubkey).thenReturn(testUserPubkey);
        when(() => reactionEvent.createdAt).thenReturn(defaultTimestamp);
        when(() => reactionEvent.tags).thenReturn([
          ['e', testEventId],
        ]);

        streamController.add(reactionEvent);
        await Future<void>.delayed(Duration.zero);

        expect(await repository.isLiked(testEventId), isTrue);
        verify(() => mockLocalStorage.saveLikeRecord(any())).called(1);

        await streamController.close();
      });

      test(
        'routes downvote reactions into _downvoteRecords (not _likeRecords)',
        () async {
          final streamController = StreamController<Event>.broadcast();
          when(() => mockNostrClient.hasKeys).thenReturn(true);
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => streamController.stream);

          repository = createRepository();
          await repository.initialize();

          final downvoteEvent = MockEvent();
          when(() => downvoteEvent.id).thenReturn('downvote_event_id');
          when(() => downvoteEvent.kind).thenReturn(EventKind.reaction);
          when(() => downvoteEvent.content).thenReturn('-');
          when(() => downvoteEvent.pubkey).thenReturn(testUserPubkey);
          when(() => downvoteEvent.tags).thenReturn([
            ['e', testEventId],
          ]);
          when(() => downvoteEvent.createdAt).thenReturn(defaultTimestamp);

          streamController.add(downvoteEvent);
          await Future<void>.delayed(Duration.zero);

          // Downvote reactions don't mark the event as liked, but they do
          // populate the downvote tracking so removeDownvote / isDownvoted
          // see them.
          expect(await repository.isLiked(testEventId), isFalse);
          expect(await repository.isDownvoted(testEventId), isTrue);

          await streamController.close();
        },
      );

      test('deduplicates older events', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        // Pre-populate with an existing record
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                defaultTimestamp * 1000,
              ),
            ),
          ],
        );

        repository = createRepository();
        await repository.initialize();

        // Emit an older event for the same target
        final olderEvent = MockEvent();
        when(() => olderEvent.id).thenReturn('older_reaction_id');
        when(() => olderEvent.kind).thenReturn(EventKind.reaction);
        when(() => olderEvent.content).thenReturn('+');
        when(() => olderEvent.pubkey).thenReturn(testUserPubkey);
        when(() => olderEvent.createdAt).thenReturn(defaultTimestamp - 100);
        when(() => olderEvent.tags).thenReturn([
          ['e', testEventId],
        ]);

        streamController.add(olderEvent);
        await Future<void>.delayed(Duration.zero);

        // The older event should not replace the existing record
        final record = await repository.getLikeRecord(testEventId);
        expect(record!.reactionEventId, equals(testReactionEventId));

        await streamController.close();
      });
    });

    group('offline queuing', () {
      test('likeEvent queues action when offline', () async {
        var queuedAction = <String, dynamic>{};

        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queuedAction = {
                  'isLike': isLike,
                  'eventId': eventId,
                  'authorPubkey': authorPubkey,
                  'addressableId': addressableId,
                  'targetKind': targetKind,
                };
              },
        );

        final reactionId = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          addressableId: '34236:author:video',
          targetKind: 34236,
        );

        expect(reactionId, startsWith('pending_like_'));
        expect(queuedAction['isLike'], isTrue);
        expect(queuedAction['eventId'], equals(testEventId));
        expect(queuedAction['authorPubkey'], equals(testAuthorPubkey));
        expect(queuedAction['addressableId'], equals('34236:author:video'));
        expect(queuedAction['targetKind'], equals(34236));

        // Should still show as liked locally
        expect(await repository.isLiked(testEventId), isTrue);

        // Should save to local storage
        verify(() => mockLocalStorage.saveLikeRecord(any())).called(1);
      });

      test('unlikeEvent queues action when offline', () async {
        var queuedAction = <String, dynamic>{};

        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        // Create repository with offline callbacks
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queuedAction = {'isLike': isLike, 'eventId': eventId};
              },
        );

        // Add a like (will be queued since offline)
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(await repository.isLiked(testEventId), isTrue);

        // Now unlike while offline
        await repository.unlikeEvent(testEventId);

        expect(queuedAction['isLike'], isFalse);
        expect(queuedAction['eventId'], equals(testEventId));

        // Should no longer show as liked locally
        expect(await repository.isLiked(testEventId), isFalse);
      });
    });

    group('executeLikeAction', () {
      test('logs a replayed like missing its coordinate (#6980)', () async {
        // The relay holds no like, so the replay goes on to publish.
        mockReadEventsSequence([<Event>[]]);
        stubAnyPublish();
        repository = createReportingRepository();

        await repository.executeLikeAction(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          targetKind: 34236,
        );

        expect(missingCoordinateWarnings(), hasLength(1));
        expect(reported, isEmpty);
      });

      test('publishes like directly to relays', () async {
        // The relay holds no like, so the replay goes on to publish.
        mockReadEventsSequence([<Event>[]]);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );

        repository = createRepository();

        final eventId = await repository.executeLikeAction(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(eventId, equals(testReactionEventId));

        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: testAuthorPubkey,
            targetKind: any(named: 'targetKind'),
          ),
        ).called(1);
      });

      test('updates placeholder record with real event ID', () async {
        // The relay holds no like, so the replay goes on to publish.
        mockReadEventsSequence([<Event>[]]);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        // First create a pending like (offline)
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {},
        );

        final placeholderId = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(placeholderId, startsWith('pending_like_'));

        // Now execute the real action (simulating sync)
        final realEventId = await repository.executeLikeAction(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(realEventId, equals(testReactionEventId));

        // Verify local storage was updated
        verify(() => mockLocalStorage.saveLikeRecord(any())).called(2);
      });

      test(
        // #6020: PendingActionService's own queue-time dedup only cancels
        // opposite actions on the *same* event id — it has no visibility
        // into a like that synced in from another device (under a
        // different event id) for the same coordinate while this action
        // sat in the offline queue. Without this guard, replay would
        // publish a second, duplicate live reaction.
        'reconciles to an already-synced coordinate reaction instead of '
        'publishing a duplicate, when another device liked the same '
        'coordinate while this action was queued',
        () async {
          const coordinate = '34236:$testAuthorPubkey:test-d-tag';
          const otherDeviceReactionId = 'other_device_reaction_id';
          const otherDeviceEventId = 'other_device_event_id';

          when(
            () => mockLocalStorage.saveLikeRecord(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockLocalStorage.saveLikeRecordsBatch(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockLocalStorage.deleteLikeRecord(any()),
          ).thenAnswer((_) async => true);

          // 1. Offline: queue a like for testEventId at this coordinate.
          repository = LikesRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
            isOnline: () => false,
            queueOfflineAction:
                ({
                  required isLike,
                  required eventId,
                  required authorPubkey,
                  addressableId,
                  targetKind,
                }) async {},
          );
          final placeholderId = await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            addressableId: coordinate,
          );
          expect(placeholderId, startsWith('pending_like_'));

          // 2. While still queued, another device's like for the SAME
          // coordinate (different event id, real reaction id) syncs in.
          final otherDeviceReaction = createMockReaction(
            id: otherDeviceReactionId,
            targetEventId: otherDeviceEventId,
            authorPubkey: testUserPubkey,
            tags: [
              ['e', otherDeviceEventId],
              ['a', coordinate],
            ],
          );
          mockReadEventsSequence([
            [otherDeviceReaction],
            <Event>[],
          ]);
          await repository.syncUserReactions();

          // 3. Sync replay executes the originally-queued action.
          final resolvedId = await repository.executeLikeAction(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            addressableId: coordinate,
          );

          expect(resolvedId, equals(otherDeviceReactionId));
          verifyNever(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          );
        },
      );

      test(
        // #6123 review: without dropping the pending_ placeholder while
        // reconciling, a later unlike resolves the placeholder by event id
        // first, hits the pending_ short-circuit, and never deletes the
        // live cross-device reaction — stranding it un-deletable.
        'drops the queued placeholder when reconciling to a cross-device '
        'coordinate reaction, so a later unlike deletes that reaction and '
        'clears both lookups',
        () async {
          const coordinate = '34236:$testAuthorPubkey:test-d-tag';
          const otherDeviceReactionId = 'other_device_reaction_id';
          const otherDeviceEventId = 'other_device_event_id';

          when(
            () => mockLocalStorage.saveLikeRecord(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockLocalStorage.saveLikeRecordsBatch(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockLocalStorage.deleteLikeRecord(any()),
          ).thenAnswer((_) async => true);
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer(
            (_) async => createMockDeletion([otherDeviceReactionId]),
          );

          // 1. Offline: queue a like for testEventId at this coordinate.
          var online = false;
          repository = LikesRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
            isOnline: () => online,
            queueOfflineAction:
                ({
                  required isLike,
                  required eventId,
                  required authorPubkey,
                  addressableId,
                  targetKind,
                }) async {},
          );
          await repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            addressableId: coordinate,
          );

          // 2. While queued, another device's like for the SAME coordinate
          // (different event id, real reaction id) syncs in.
          final otherDeviceReaction = createMockReaction(
            id: otherDeviceReactionId,
            targetEventId: otherDeviceEventId,
            authorPubkey: testUserPubkey,
            tags: [
              ['e', otherDeviceEventId],
              ['a', coordinate],
            ],
          );
          mockReadEventsSequence([
            [otherDeviceReaction],
            <Event>[],
          ]);
          await repository.syncUserReactions();

          // 3. Back online: replay reconciles, then the user unlikes.
          online = true;
          final resolvedId = await repository.executeLikeAction(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
            addressableId: coordinate,
          );
          await repository.unlikeEvent(testEventId, addressableId: coordinate);

          expect(resolvedId, equals(otherDeviceReactionId));
          verifyNever(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          );
          // Reconcile dropped the placeholder row; unlike removed the real
          // record and published Kind 5 for the real reaction.
          verify(
            () => mockLocalStorage.deleteLikeRecord(testEventId),
          ).called(1);
          verify(
            () => mockLocalStorage.deleteLikeRecord(otherDeviceEventId),
          ).called(1);
          verify(
            () => mockNostrClient.deleteEvent(otherDeviceReactionId),
          ).called(1);
          expect(
            await repository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: coordinate,
            ),
            isFalse,
          );
          expect(await repository.isLiked(otherDeviceEventId), isFalse);
        },
      );

      test('throws LikeFailedException when publish fails', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => null);

        repository = createRepository();

        expect(
          () => repository.executeLikeAction(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeFailedException>()),
        );
      });

      test(
        'terminalizes a trusted account restriction during replay',
        () async {
          // The relay holds no like, so the replay goes on to publish.
          mockReadEventsSequence([<Event>[]]);
          final event = MockEvent();
          when(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenThrow(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.accountRestricted,
                event: event,
              ),
            ),
          );

          repository = createRepository();

          await expectLater(
            repository.executeLikeAction(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
            throwsA(
              isA<LikeAccountRestrictedException>().having(
                (error) => error,
                'terminal marker',
                isA<TerminalSocialActionException>(),
              ),
            ),
          );
        },
      );
    });

    group('executeUnlikeAction', () {
      test('publishes deletion directly to relays', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => createMockDeletion([testReactionEventId]));
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        repository = createRepository();

        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        // Now execute unlike directly
        await repository.executeUnlikeAction(testEventId);

        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
      });

      test('skips deletion for pending likes', () async {
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        // Create a pending like (offline)
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {},
        );

        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        // Execute unlike - should not call deleteEvent since never synced
        await repository.executeUnlikeAction(testEventId);

        verifyNever(() => mockNostrClient.deleteEvent(any()));
        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
      });

      test('does nothing when no record exists', () async {
        when(
          () => mockLocalStorage.getLikeRecord(any()),
        ).thenAnswer((_) async => null);

        repository = createRepository();

        // Should not throw, just return
        await repository.executeUnlikeAction(testEventId);

        verifyNever(() => mockNostrClient.deleteEvent(any()));
        verifyNever(() => mockLocalStorage.deleteLikeRecord(testEventId));
      });

      test('throws UnlikeFailedException when deletion fails', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();

        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(
          () => repository.executeUnlikeAction(testEventId),
          throwsA(isA<UnlikeFailedException>()),
        );
      });

      test(
        'terminalizes a trusted account restriction during replay',
        () async {
          final event = MockEvent();
          when(
            () => mockLocalStorage.getLikeRecord(testEventId),
          ).thenAnswer((_) async => createLikeRecord());
          when(() => mockNostrClient.deleteEvent(any())).thenThrow(
            SocialPublishException(
              SocialPublishResult(
                status: SocialPublishStatus.accountRestricted,
                event: event,
              ),
            ),
          );
          repository = createRepository();

          await expectLater(
            repository.executeUnlikeAction(testEventId),
            throwsA(
              isA<LikeAccountRestrictedException>().having(
                (error) => error,
                'terminal marker',
                isA<TerminalSocialActionException>(),
              ),
            ),
          );
        },
      );

      test('falls back to local storage when not in cache', () async {
        final record = createLikeRecord();

        when(
          () => mockLocalStorage.getLikeRecord(testEventId),
        ).thenAnswer((_) async => record);
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => createMockDeletion([testReactionEventId]));
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        repository = createRepository();

        await repository.executeUnlikeAction(testEventId);

        verify(() => mockLocalStorage.getLikeRecord(testEventId)).called(1);
        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
      });

      test('decrements like count cache', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 10));
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => createMockDeletion([testReactionEventId]));
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        repository = createRepository();

        // Populate count cache
        await repository.getLikeCount(testEventId);
        // Like so there's a record to unlike
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );
        // Execute unlike via sync path
        await repository.executeUnlikeAction(testEventId);

        // Cache was 10 → likeEvent +1 → 11 → executeUnlikeAction −1 → 10
        final cached = await repository.getLikeCount(testEventId);
        expect(cached, equals(10));
      });
    });

    group('coordinate-aware own-like resolution (#6020)', () {
      const oldEventId = 'old_event_id_1234567890abcdef';
      const newEventId = 'new_event_id_1234567890abcdef';
      const coordinate = '34236:$testAuthorPubkey:test-d-tag';

      test(
        'isLikedByCoordinate resolves true after syncUserReactions ingests '
        'a reaction whose e tag is a different (old) id but whose a tag '
        'matches',
        () async {
          final reaction = createMockReaction(
            id: testReactionEventId,
            targetEventId: oldEventId,
            tags: [
              ['e', oldEventId],
              ['a', coordinate],
            ],
          );
          mockReadEventsSequence([
            [reaction],
            <Event>[],
          ]);
          when(
            () => mockLocalStorage.saveLikeRecordsBatch(any()),
          ).thenAnswer((_) async {});

          repository = createRepository();
          await repository.syncUserReactions();

          // The new (post-edit) event id was never liked directly...
          expect(await repository.isLiked(newEventId), isFalse);
          // ...but the coordinate resolves true, and isLikedResolvingCoordinate
          // (what VideoInteractionsBloc calls) composes the two correctly.
          expect(await repository.isLikedByCoordinate(coordinate), isTrue);
          expect(
            await repository.isLikedResolvingCoordinate(
              eventId: newEventId,
              addressableId: coordinate,
            ),
            isTrue,
          );
        },
      );

      test(
        'getLikeRecordByCoordinate returns the reactionEventId needed for '
        'unlike resolution',
        () async {
          final reaction = createMockReaction(
            id: testReactionEventId,
            targetEventId: oldEventId,
            tags: [
              ['e', oldEventId],
              ['a', coordinate],
            ],
          );
          mockReadEventsSequence([
            [reaction],
            <Event>[],
          ]);
          when(
            () => mockLocalStorage.saveLikeRecordsBatch(any()),
          ).thenAnswer((_) async {});

          repository = createRepository();
          await repository.syncUserReactions();

          final record = await repository.getLikeRecordByCoordinate(
            coordinate,
          );
          expect(record, isNotNull);
          expect(record!.targetEventId, equals(oldEventId));
          expect(record.reactionEventId, equals(testReactionEventId));
        },
      );

      test('clearCache wipes the addressable-id companion cache too', () async {
        final reaction = createMockReaction(
          id: testReactionEventId,
          targetEventId: oldEventId,
          tags: [
            ['e', oldEventId],
            ['a', coordinate],
          ],
        );
        mockReadEventsSequence([
          [reaction],
          <Event>[],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});
        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = createRepository();
        await repository.syncUserReactions();
        expect(await repository.isLikedByCoordinate(coordinate), isTrue);

        await repository.clearCache();

        expect(await repository.isLikedByCoordinate(coordinate), isFalse);
      });

      test(
        'cold start resolves isLikedByCoordinate from persisted storage '
        'alone, without any relay call (beats #4478s warm-cache-only limit)',
        () async {
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              createLikeRecord(
                targetEventId: oldEventId,
                addressableId: coordinate,
              ),
            ],
          );

          repository = createRepository();
          // initialize() loads from local storage only; no relay query is
          // stubbed for reactions/deletions, so a relay round-trip here
          // would surface as a Mocktail MissingStubError.
          await repository.initialize();

          expect(
            await repository.isLikedResolvingCoordinate(
              eventId: newEventId,
              addressableId: coordinate,
            ),
            isTrue,
          );
        },
      );
    });

    group('duplicate-reaction guard (#6020)', () {
      const oldEventId = 'old_event_id_1234567890abcdef';
      const newEventId = 'new_event_id_1234567890abcdef';
      const coordinate = '34236:$testAuthorPubkey:test-d-tag';

      test(
        'likeEvent throws AlreadyLikedException when the coordinate is '
        'already liked under a different event id',
        () async {
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              createLikeRecord(
                targetEventId: oldEventId,
                addressableId: coordinate,
              ),
            ],
          );

          repository = createRepository();
          await repository.initialize();

          expect(
            () => repository.likeEvent(
              eventId: newEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: coordinate,
            ),
            throwsA(isA<AlreadyLikedException>()),
          );
        },
      );

      test(
        'toggleLike treats the coordinate as currently liked and unlikes '
        'the original reaction rather than creating a duplicate',
        () async {
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              createLikeRecord(
                targetEventId: oldEventId,
                addressableId: coordinate,
              ),
            ],
          );
          when(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).thenAnswer((_) async => MockEvent());
          when(
            () => mockLocalStorage.deleteLikeRecord(oldEventId),
          ).thenAnswer((_) async => true);

          repository = createRepository();
          await repository.initialize();

          final isNowLiked = await repository.toggleLike(
            eventId: newEventId,
            authorPubkey: testAuthorPubkey,
            addressableId: coordinate,
          );

          expect(isNowLiked, isFalse);
          verifyNever(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          );
          verify(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).called(1);
        },
      );
    });

    group('legacy 34236 key of a Kind 34235 video (#10776)', () {
      const oldEventId = 'old_event_id_1234567890abcdef';
      const newEventId = 'new_event_id_1234567890abcdef';
      const coordinate = '34235:$testAuthorPubkey:test-d-tag';
      const legacyCoordinate = '34236:$testAuthorPubkey:test-d-tag';

      void stubLegacyRecord() {
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: oldEventId,
              addressableId: legacyCoordinate,
            ),
          ],
        );
      }

      group('on the relays after a cold start', () {
        test('likeEvent adopts the like left under the legacy key instead of '
            'sending another', () async {
          final reaction = createMockReaction(
            id: testReactionEventId,
            targetEventId: oldEventId,
            authorPubkey: testUserPubkey,
            tags: [
              ['e', oldEventId],
              ['a', legacyCoordinate],
            ],
          );
          when(
            () => mockNostrClient.readEvents(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((invocation) async {
            final filters = invocation.positionalArguments[0] as List<Filter>;
            return QueryResult(
              events:
                  filters.any(
                    (filter) => filter.a?.contains(legacyCoordinate) ?? false,
                  )
                  ? [reaction]
                  : <Event>[],
              endedBy: QueryEnd.complete,
            );
          });
          repository = createRepository(withLocalStorage: false);

          await expectLater(
            repository.likeEvent(
              eventId: newEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: coordinate,
              targetKind: 34235,
            ),
            throwsA(isA<AlreadyLikedException>()),
          );

          expect(
            (await repository.getLikeRecordByCoordinate(
              coordinate,
            ))?.reactionEventId,
            testReactionEventId,
          );
          verifyNever(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          );
          when(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).thenAnswer((_) async => MockEvent());

          await repository.unlikeEvent(
            newEventId,
            addressableId: coordinate,
          );

          expect(
            await repository.getLikeRecordByCoordinate(coordinate),
            isNull,
          );
          verify(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).called(1);
        });

        Event legacyDownvote() => createMockReaction(
          id: testReactionEventId,
          targetEventId: oldEventId,
          authorPubkey: testUserPubkey,
          content: '-',
          tags: [
            ['e', oldEventId],
            ['a', legacyCoordinate],
          ],
        );

        test('downvoteEvent finds the downvote left under the legacy key '
            'instead of sending another', () async {
          mockQueryEventsSequence([
            <Event>[],
            [legacyDownvote()],
            <Event>[],
          ]);
          repository = createRepository(withLocalStorage: false);

          await expectLater(
            repository.downvoteEvent(
              eventId: newEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: coordinate,
              targetKind: 34235,
            ),
            throwsA(isA<AlreadyDownvotedException>()),
          );
          verifyNever(
            () => mockNostrClient.sendLike(
              any(),
              content: any(named: 'content'),
              addressableId: any(named: 'addressableId'),
              targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          );
        });

        test('removeDownvote deletes the downvote left under the legacy '
            'key', () async {
          mockQueryEventsSequence([
            <Event>[],
            [legacyDownvote()],
            <Event>[],
          ]);
          when(
            () => mockNostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => MockEvent());
          repository = createRepository(withLocalStorage: false);

          await repository.removeDownvote(
            newEventId,
            addressableId: coordinate,
          );

          verify(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).called(1);
        });
      });

      test('resolves the like stored under the legacy key', () async {
        stubLegacyRecord();
        repository = createRepository();
        await repository.initialize();

        expect(
          await repository.isLikedResolvingCoordinate(
            eventId: newEventId,
            addressableId: coordinate,
          ),
          isTrue,
        );
      });

      test(
        'toggleLike unlikes the legacy reaction rather than creating a '
        'duplicate',
        () async {
          stubLegacyRecord();
          when(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).thenAnswer((_) async => MockEvent());
          when(
            () => mockLocalStorage.deleteLikeRecord(oldEventId),
          ).thenAnswer((_) async => true);
          repository = createRepository();
          await repository.initialize();

          final isNowLiked = await repository.toggleLike(
            eventId: newEventId,
            authorPubkey: testAuthorPubkey,
            addressableId: coordinate,
            targetKind: 34235,
          );

          expect(isNowLiked, isFalse);
          verify(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).called(1);
        },
      );

      test(
        'getLikeCounts credits a 34236 coordinate to the real Kind 34236 '
        'video, not to the alias of a 34235 video in the same batch',
        () async {
          const shortVideoId = 'short_video_id_1234567890abcdef';
          const normalVideoId = 'normal_video_id_1234567890abcdef';
          final reactionOnOlderShortVersion = createMockReaction(
            id: 'reaction_short',
            targetEventId: oldEventId,
            authorPubkey: 'liker_a_pubkey_1234567890abcdef',
            tags: [
              ['e', oldEventId],
              ['a', legacyCoordinate],
            ],
          );
          mockQueryEventsSequence([
            <Event>[],
            [reactionOnOlderShortVersion],
            <Event>[],
          ]);

          repository = createRepository();
          final counts = await repository.getLikeCounts(
            [shortVideoId, normalVideoId],
            addressableIds: {
              shortVideoId: legacyCoordinate,
              normalVideoId: coordinate,
            },
          );

          expect(counts, equals({shortVideoId: 1, normalVideoId: 0}));
        },
      );

      test('getLikeCount counts a like tagged with the legacy key', () async {
        const liker = 'liker_a_pubkey_1234567890abcdef';
        final legacyTaggedReaction = createMockReaction(
          id: 'reaction_legacy',
          targetEventId: oldEventId,
          authorPubkey: liker,
          tags: [
            ['e', oldEventId],
            ['a', legacyCoordinate],
          ],
        );
        mockQueryEventsSequence([
          <Event>[],
          [legacyTaggedReaction],
          <Event>[],
        ]);

        repository = createRepository();
        final count = await repository.getLikeCount(
          newEventId,
          addressableId: coordinate,
        );

        expect(count, equals(1));
      });
    });

    group('unlikeEvent resolves by coordinate (#6020)', () {
      const oldEventId = 'old_event_id_1234567890abcdef';
      const newEventId = 'new_event_id_1234567890abcdef';
      const coordinate = '34236:$testAuthorPubkey:test-d-tag';

      test(
        'unlikeEvent(newEventId, addressableId: coordinate) deletes the '
        'reaction recorded under oldEventId',
        () async {
          when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              createLikeRecord(
                targetEventId: oldEventId,
                addressableId: coordinate,
              ),
            ],
          );
          when(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).thenAnswer((_) async => MockEvent());
          when(
            () => mockLocalStorage.deleteLikeRecord(oldEventId),
          ).thenAnswer((_) async => true);

          repository = createRepository();
          await repository.initialize();

          await repository.unlikeEvent(newEventId, addressableId: coordinate);

          verify(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).called(1);
          verify(
            () => mockLocalStorage.deleteLikeRecord(oldEventId),
          ).called(1);
          expect(await repository.isLikedByCoordinate(coordinate), isFalse);
          expect(await repository.isLiked(oldEventId), isFalse);
        },
      );

      test(
        'unlikeEvent falls back to local storage by coordinate when '
        'neither the memory cache nor a direct database lookup by event id '
        'has the record',
        () async {
          when(
            () => mockLocalStorage.getLikeRecordByAddressableId(coordinate),
          ).thenAnswer(
            (_) async => createLikeRecord(
              targetEventId: oldEventId,
              addressableId: coordinate,
            ),
          );
          when(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).thenAnswer((_) async => MockEvent());
          when(
            () => mockLocalStorage.deleteLikeRecord(oldEventId),
          ).thenAnswer((_) async => true);

          repository = createRepository();

          await repository.unlikeEvent(newEventId, addressableId: coordinate);

          verify(
            () => mockLocalStorage.getLikeRecordByAddressableId(coordinate),
          ).called(1);
          verify(
            () => mockNostrClient.deleteEvent(testReactionEventId),
          ).called(1);
        },
      );
    });

    group('like count cache dual-key (#6020)', () {
      const oldEventId = 'old_event_id_1234567890abcdef';
      const newEventId = 'new_event_id_1234567890abcdef';
      const coordinate = '34236:$testAuthorPubkey:test-d-tag';

      test(
        'a count cached under the old event id resolves for the new event '
        'id via the coordinate, without an extra relay query',
        () async {
          final reaction = createMockReaction(
            id: 'liker_reaction',
            targetEventId: oldEventId,
            authorPubkey: 'some_liker_pubkey_1234567890abcdef',
            tags: [
              ['a', coordinate],
            ],
          );
          mockQueryEventsSequence([
            [reaction], // e-filter query for oldEventId
            [reaction], // a-filter query for coordinate
            <Event>[], // deletion-scoped query
          ]);

          repository = createRepository();
          final firstCount = await repository.getLikeCount(
            oldEventId,
            addressableId: coordinate,
          );
          expect(firstCount, equals(1));

          // Same coordinate, new (post-edit) event id — should be served
          // from the addressable-id companion cache, not a fresh query.
          final secondCount = await repository.getLikeCount(
            newEventId,
            addressableId: coordinate,
          );
          expect(secondCount, equals(1));

          verify(
            () => mockNostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
            ),
          ).called(2);
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        },
      );
    });

    group('coordinate-aware vote reads (#6124)', () {
      const supersededId = 'superseded_reply_id_1234567890abcdef';
      const editedId = 'edited_reply_id_1234567890abcdef';
      const coordinate = '34236:$testAuthorPubkey:reply-d-tag';

      test('getVoteCounts counts a vote cast before the target was edited', () {
        // The reaction names the pre-edit id in its `e` tag, so an `e`-only
        // query against the current id returns nothing and the score
        // disappears for every viewer.
        final reaction = createMockReaction(
          id: 'voter_reaction',
          targetEventId: supersededId,
          authorPubkey: 'some_voter_pubkey_1234567890abcdef',
          tags: [
            ['e', supersededId],
            ['a', coordinate],
          ],
        );
        mockQueryEventsSequence([
          <Event>[],
          [reaction],
        ]);

        repository = createRepository(withLocalStorage: false);

        return expectLater(
          repository.getVoteCounts(
            [editedId],
            addressableIds: const {editedId: coordinate},
          ),
          completion(
            isA<({Map<String, int> upvotes, Map<String, int> downvotes})>()
                .having((r) => r.upvotes[editedId], 'upvotes', 1)
                .having((r) => r.downvotes[editedId], 'downvotes', 0),
          ),
        );
      });

      test(
        'getVoteCounts queries e and a separately so cache stays active',
        () async {
          final reaction = createMockReaction(
            id: 'voter_reaction',
            targetEventId: editedId,
            authorPubkey: 'some_voter_pubkey_1234567890abcdef',
            tags: [
              ['e', editedId],
              ['a', coordinate],
            ],
          );
          mockQueryEventsSequence([
            [reaction],
            [reaction],
            <Event>[], // no deletions
          ]);

          repository = createRepository(withLocalStorage: false);

          final counts = await repository.getVoteCounts(
            [editedId],
            addressableIds: const {editedId: coordinate},
          );

          expect(counts.upvotes[editedId], equals(1));

          // Three single-filter requests: by `e`, by `a`, then the Kind 5
          // sweep over the reactions those returned. Every one has to stay
          // single-filter — NostrClient skips the local event cache the
          // moment a call carries more than one.
          final captured = verify(
            () => mockNostrClient.queryEvents(captureAny()),
          ).captured.cast<List<Filter>>();
          expect(captured, hasLength(3));
          expect(captured.every((filters) => filters.length == 1), isTrue);
          expect(captured[0].single.e, equals([editedId]));
          expect(captured[1].single.a, equals([coordinate]));
          expect(
            captured[2].single.kinds,
            equals([EventKind.eventDeletion]),
          );
        },
      );

      test(
        'chunks the vote-target reaction query so no REQ exceeds the frame '
        'limit',
        () async {
          // The vote path is a third unbounded Kind 7 `#e` filter, bounded
          // today only by the comment page size — the same incidental bound
          // the like path already stopped relying on.
          final eventIds = [for (var i = 0; i < 600; i++) 'vote_target_$i'];
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository(withLocalStorage: false);
          await repository.getVoteCounts(eventIds);

          final eFilters =
              verify(() => mockNostrClient.queryEvents(captureAny())).captured
                  .cast<List<Filter>>()
                  .map((filters) => filters.single)
                  .where((f) => f.e != null)
                  .toList();

          expect(eFilters, hasLength(2));
          expect(eFilters[0].e, hasLength(500));
          expect(eFilters[1].e, hasLength(100));
          expect(
            {...eFilters[0].e!, ...eFilters[1].e!},
            hasLength(600),
            reason: 'chunks partition every id without overlap',
          );
        },
      );

      test(
        'chunks the vote-target coordinate query too',
        () async {
          // A `kind:pubkey:dtag` coordinate is longer than a bare id, so the
          // `#a` leg reaches the frame cap sooner than the `#e` leg it runs
          // beside.
          final eventIds = [for (var i = 0; i < 600; i++) 'vote_target_$i'];
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository(withLocalStorage: false);
          await repository.getVoteCounts(
            eventIds,
            addressableIds: {
              for (final id in eventIds) id: '34236:$testAuthorPubkey:$id',
            },
          );

          final aFilters =
              verify(() => mockNostrClient.queryEvents(captureAny())).captured
                  .cast<List<Filter>>()
                  .map((filters) => filters.single)
                  .where((f) => f.a != null)
                  .toList();

          expect(aFilters, hasLength(2));
          expect(aFilters[0].a, hasLength(500));
          expect(aFilters[1].a, hasLength(100));
          expect(
            {...aFilters[0].a!, ...aFilters[1].a!},
            hasLength(600),
            reason: 'chunks partition every coordinate without overlap',
          );
        },
      );

      test(
        'chunks the coordinate query by bytes when d tags are oversized',
        () async {
          // An event id is fixed at 64 chars, so the 500-value count cap
          // byte-bounds the `#e` legs on its own. A coordinate is not fixed:
          // nothing validates `d` tag length, so the `#a` legs need the byte
          // budget too. 300 coordinates of ~1KB each is ~300KB of values —
          // far past the frame cap while nowhere near the count cap.
          final eventIds = [for (var i = 0; i < 300; i++) 'vote_target_$i'];
          final oversizedDTag = 'd' * 1024;
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          repository = createRepository(withLocalStorage: false);
          await repository.getVoteCounts(
            eventIds,
            addressableIds: {
              for (final id in eventIds)
                id: '34236:$testAuthorPubkey:$oversizedDTag$id',
            },
          );

          final aFilters =
              verify(() => mockNostrClient.queryEvents(captureAny())).captured
                  .cast<List<Filter>>()
                  .map((filters) => filters.single)
                  .where((f) => f.a != null)
                  .toList();

          expect(aFilters.length, greaterThan(1));
          for (final filter in aFilters) {
            final chunkBytes = filter.a!.fold<int>(
              0,
              (sum, value) => sum + utf8.encode(value).length,
            );
            expect(chunkBytes, lessThanOrEqualTo(128 * 1024));
          }
          expect(
            {for (final f in aFilters) ...f.a!},
            hasLength(300),
            reason: 'chunks partition every coordinate without overlap',
          );
        },
      );

      test('getUserVoteStatuses resolves the own vote by coordinate', () async {
        mockQueryEventsSequence([
          <Event>[],
          [
            createMockReaction(
              id: 'own_downvote',
              targetEventId: supersededId,
              authorPubkey: testUserPubkey,
              content: '-',
              tags: [
                ['e', supersededId],
                ['a', coordinate],
              ],
            ),
          ],
          <Event>[], // no deletions
        ]);

        repository = createRepository(withLocalStorage: false);

        final statuses = await repository.getUserVoteStatuses(
          [editedId],
          addressableIds: const {editedId: coordinate},
        );

        expect(statuses.downvotedIds, contains(editedId));
        expect(statuses.upvotedIds, isEmpty);
      });

      test('getUserVoteStatuses still excludes a deleted coordinate '
          'vote', () async {
        mockQueryEventsSequence([
          <Event>[],
          [
            createMockReaction(
              id: 'own_downvote',
              targetEventId: supersededId,
              authorPubkey: testUserPubkey,
              content: '-',
              tags: [
                ['e', supersededId],
                ['a', coordinate],
              ],
            ),
          ],
          [
            createMockDeletion(['own_downvote']),
          ],
        ]);

        repository = createRepository(withLocalStorage: false);

        final statuses = await repository.getUserVoteStatuses(
          [editedId],
          addressableIds: const {editedId: coordinate},
        );

        expect(statuses.downvotedIds, isEmpty);
      });

      test('getVoteCounts credits the last `e` tag when a reaction carries '
          'several', () async {
        // NIP-25: "the target event `id` should be last of the `e` tags".
        // A client that copies the thread's ancestor tags would otherwise
        // have its vote credited to the root comment instead of the reply.
        const rootCommentId = 'root_comment_id_1234567890abcdef';
        final reaction = createMockReaction(
          id: 'ancestor_tagged_reaction',
          targetEventId: editedId,
          authorPubkey: 'some_voter_pubkey_1234567890abcdef',
          tags: [
            ['e', rootCommentId],
            ['e', editedId],
          ],
        );
        mockQueryEventsSequence([
          [reaction],
          <Event>[],
          <Event>[],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts([
          rootCommentId,
          editedId,
        ]);

        expect(counts.upvotes[editedId], equals(1));
        expect(counts.upvotes[rootCommentId], equals(0));
      });

      test('getVoteCounts excludes a vote retracted on an earlier '
          'revision', () async {
        // Switching an upvote to a downvote on an edited reply publishes a
        // Kind 5 for the pre-edit reaction and a new downvote on the current
        // one. The coordinate leg reaches both, so counting the retracted
        // upvote would inflate the upvote total and zero the net score that
        // Top ranks by.
        const voter = 'some_voter_pubkey_1234567890abcdef';
        final retractedUpvote = createMockReaction(
          id: 'retracted_upvote',
          targetEventId: supersededId,
          authorPubkey: voter,
          tags: [
            ['e', supersededId],
            ['a', coordinate],
          ],
        );
        final liveDownvote = createMockReaction(
          id: 'live_downvote',
          targetEventId: editedId,
          authorPubkey: voter,
          content: '-',
          tags: [
            ['e', editedId],
            ['a', coordinate],
          ],
        );
        mockQueryEventsSequence([
          [liveDownvote],
          [retractedUpvote, liveDownvote],
          [
            createMockDeletion(['retracted_upvote'], authorPubkey: voter),
          ],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts(
          [editedId],
          addressableIds: const {editedId: coordinate},
        );

        expect(counts.upvotes[editedId], equals(0));
        expect(counts.downvotes[editedId], equals(1));
      });

      test('getVoteCounts ignores a deletion published by someone other than '
          'the voter', () async {
        // Otherwise anyone could suppress another user's vote by referencing
        // its reaction id.
        const voter = 'some_voter_pubkey_1234567890abcdef';
        final upvote = createMockReaction(
          id: 'honest_upvote',
          targetEventId: editedId,
          authorPubkey: voter,
          tags: [
            ['e', editedId],
            ['a', coordinate],
          ],
        );
        mockQueryEventsSequence([
          [upvote],
          [upvote],
          [
            createMockDeletion(
              ['honest_upvote'],
              authorPubkey: 'an_impostor_pubkey_1234567890abcdef',
            ),
          ],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts(
          [editedId],
          addressableIds: const {editedId: coordinate},
        );

        expect(counts.upvotes[editedId], equals(1));
      });

      test('getVoteCounts ignores an unrelated coordinate', () async {
        final reaction = createMockReaction(
          id: 'other_reaction',
          targetEventId: 'unrelated_event_id_1234567890abcdef',
          authorPubkey: 'some_voter_pubkey_1234567890abcdef',
          tags: [
            ['a', '34236:$testAuthorPubkey:some-other-d-tag'],
          ],
        );
        mockQueryEventsSequence([
          <Event>[],
          [reaction],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts(
          [editedId],
          addressableIds: const {editedId: coordinate},
        );

        expect(counts.upvotes[editedId], equals(0));
      });

      test('getVoteCounts counts one vote per account', () async {
        // Kind 7 is a regular event, so a relay keeps every reaction an
        // account publishes. Counting events would let one account cast any
        // number of votes and bury a comment in the Top order.
        const brigader = 'brigading_voter_pubkey_1234567890abcdef';
        const honest = 'honest_voter_pubkey_1234567890abcdef';
        mockQueryEventsSequence([
          [
            for (var i = 0; i < 3; i++)
              createMockReaction(
                id: 'repeat_downvote_$i',
                targetEventId: editedId,
                authorPubkey: brigader,
                content: '-',
                createdAt: defaultTimestamp + i,
              ),
            createMockReaction(
              id: 'honest_upvote',
              targetEventId: editedId,
              authorPubkey: honest,
            ),
          ],
          <Event>[],
          <Event>[],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts([editedId]);

        expect(counts.downvotes[editedId], equals(1));
        expect(counts.upvotes[editedId], equals(1));
      });

      test("getVoteCounts takes an account's newest vote", () async {
        // A voter who switched from up to down without the retraction
        // reaching this relay still holds one vote: the newer one.
        const voter = 'some_voter_pubkey_1234567890abcdef';
        mockQueryEventsSequence([
          [
            createMockReaction(
              id: 'newer_downvote',
              targetEventId: editedId,
              authorPubkey: voter,
              content: '-',
              createdAt: defaultTimestamp + 1,
            ),
            createMockReaction(
              id: 'older_upvote',
              targetEventId: editedId,
              authorPubkey: voter,
            ),
          ],
          <Event>[],
          <Event>[],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts([editedId]);

        expect(counts.upvotes[editedId], equals(0));
        expect(counts.downvotes[editedId], equals(1));
      });

      test('getVoteCounts keeps the same vote from one second in any relay '
          'order', () async {
        const voter = 'some_voter_pubkey_1234567890abcdef';
        final upvote = createMockReaction(
          id: 'reaction_a',
          targetEventId: editedId,
          authorPubkey: voter,
        );
        final downvote = createMockReaction(
          id: 'reaction_b',
          targetEventId: editedId,
          authorPubkey: voter,
          content: '-',
        );

        for (final order in [
          [upvote, downvote],
          [downvote, upvote],
        ]) {
          mockQueryEventsSequence([order, <Event>[], <Event>[]]);
          repository = createRepository(withLocalStorage: false);

          final counts = await repository.getVoteCounts([editedId]);

          expect(counts.upvotes[editedId], equals(0));
          expect(counts.downvotes[editedId], equals(1));
        }
      });

      test('getVoteCounts counts an emoji reaction as no vote', () async {
        // NIP-25: `+` or empty content is an upvote and `-` a downvote; an
        // emoji SHOULD NOT be read as either.
        mockQueryEventsSequence([
          [
            createMockReaction(
              id: 'emoji_reaction',
              targetEventId: editedId,
              authorPubkey: 'emoji_reactor_pubkey_1234567890abcdef',
              content: '🔥',
            ),
            createMockReaction(
              id: 'empty_reaction',
              targetEventId: editedId,
              authorPubkey: 'empty_reactor_pubkey_1234567890abcdef',
              content: '',
            ),
          ],
          <Event>[],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts([editedId]);

        expect(counts.upvotes[editedId], equals(1));
        expect(counts.downvotes[editedId], equals(0));
      });

      test('getVoteCounts keeps a downvote when a newer emoji reaction '
          'follows it', () async {
        const voter = 'some_voter_pubkey_1234567890abcdef';
        mockQueryEventsSequence([
          [
            createMockReaction(
              id: 'newer_emoji',
              targetEventId: editedId,
              authorPubkey: voter,
              content: '😂',
              createdAt: defaultTimestamp + 1,
            ),
            createMockReaction(
              id: 'older_downvote',
              targetEventId: editedId,
              authorPubkey: voter,
              content: '-',
            ),
          ],
          <Event>[],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts([editedId]);

        expect(counts.upvotes[editedId], equals(0));
        expect(counts.downvotes[editedId], equals(1));
      });

      test('getVoteCounts sends no deletion lookup for emoji-only '
          'reactions', () async {
        mockQueryEventsSequence([
          [
            createMockReaction(
              id: 'only_emoji',
              targetEventId: editedId,
              authorPubkey: 'emoji_reactor_pubkey_1234567890abcdef',
              content: '🔥',
            ),
          ],
        ]);

        repository = createRepository(withLocalStorage: false);

        final counts = await repository.getVoteCounts([editedId]);

        expect(counts.upvotes[editedId], equals(0));
        expect(counts.downvotes[editedId], equals(0));
        // Only the kind 7 read: a retracted emoji can't change a vote, so
        // no kind 5 query is sent for it.
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('getUserVoteStatuses skips an own emoji reaction and keeps own '
          'votes', () async {
        // The empty-content like on a second target is the positive
        // control: a skip that dropped upvotes too would still leave the
        // emoji target out of upvotedIds.
        const otherId = 'other_reply_id_1234567890abcdef';
        mockQueryEventsSequence([
          [
            createMockReaction(
              id: 'own_downvote',
              targetEventId: editedId,
              authorPubkey: testUserPubkey,
              content: '-',
            ),
            createMockReaction(
              id: 'own_newer_emoji',
              targetEventId: editedId,
              authorPubkey: testUserPubkey,
              content: '🔥',
              createdAt: defaultTimestamp + 1,
            ),
            createMockReaction(
              id: 'own_empty_upvote',
              targetEventId: otherId,
              authorPubkey: testUserPubkey,
              content: '',
            ),
          ],
          <Event>[],
        ]);

        repository = createRepository(withLocalStorage: false);

        final statuses = await repository.getUserVoteStatuses([
          editedId,
          otherId,
        ]);

        expect(statuses.upvotedIds, equals({otherId}));
        expect(statuses.downvotedIds, equals({editedId}));
      });

      test('deleting an older revision keeps the newer coordinate downvote '
          'indexed (#6124)', () async {
        const coordinate = '34236:$testAuthorPubkey:reply-d-tag';
        const oldId = 'old_reply_id_1234567890abcdef';
        const newId = 'new_reply_id_1234567890abcdef';
        const oldReactionId = 'old_downvote_reaction_id_1234567890abcdef';
        const newReactionId = 'new_downvote_reaction_id_1234567890abcdef';
        final oldReaction = createMockReaction(
          id: oldReactionId,
          targetEventId: oldId,
          content: '-',
          tags: [
            ['e', oldId],
            ['a', coordinate],
          ],
        );
        final newReaction = createMockReaction(
          id: newReactionId,
          targetEventId: newId,
          content: '-',
          createdAt: defaultTimestamp + 1,
          tags: [
            ['e', newId],
            ['a', coordinate],
          ],
        );

        mockReadEventsSequence([
          [oldReaction, newReaction],
          <Event>[],
          [oldReaction, newReaction],
          [
            createMockDeletion([oldReactionId]),
          ],
        ]);
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => MockEvent());

        repository = createRepository(withLocalStorage: false);

        await repository.syncUserReactions();
        await repository.syncUserReactions();
        await repository.removeDownvote(newId, addressableId: coordinate);

        verify(() => mockNostrClient.deleteEvent(newReactionId)).called(1);
      });
    });
  });
}
