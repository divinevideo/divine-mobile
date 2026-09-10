// ABOUTME: Regression tests for #7001 — one account must never publish a
// ABOUTME: second live `+` on a target it already reacted to, on any path.

import 'dart:async';

import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockLikesLocalStorage extends Mock implements LikesLocalStorage {}

class _MockEvent extends Mock implements Event {}

typedef _RelaySnapshot = ({
  List<Event> events,
  bool timedOut,
  bool noRelays,
  bool anyRelayAnswered,
  List<String> unsettledRelays,
});

/// Holds the startup relay snapshot open so a tap can race it.
class _GatedRelaySnapshot {
  final reactions = Completer<_RelaySnapshot>();
  final deletions = Completer<_RelaySnapshot>();

  /// Lets reconciliation land as a complete, uncapped snapshot.
  void land({
    List<Event> reactions = const [],
    List<Event> deletions = const [],
  }) {
    this.reactions.complete(
      (
        events: reactions,
        timedOut: false,
        noRelays: false,
        anyRelayAnswered: false,
        unsettledRelays: const <String>[],
      ),
    );
    this.deletions.complete(
      (
        events: deletions,
        timedOut: false,
        noRelays: false,
        anyRelayAnswered: false,
        unsettledRelays: const <String>[],
      ),
    );
  }
}

void main() {
  group('LikesRepository repeat-publish guards (#7001)', () {
    late _MockNostrClient nostrClient;
    late _MockLikesLocalStorage storage;
    late LikesRepository repository;

    const user = 'repeat_like_user_pubkey_1234567890abcdef1234567890abcdef';
    const otherUser = 'repeat_like_other_pubkey_1234567890abcdef1234567890abcd';
    const author = 'repeat_like_author_pubkey_1234567890abcdef1234567890abcde';
    const target = 'repeat_like_target_event_id_1234567890abcdef1234567890abc';
    const editedTarget =
        'repeat_like_edited_target_id_1234567890abcdef1234567890ab';
    const coordinate = '34236:$author:repeat-like-d-tag';
    const landedReactionId =
        'repeat_like_landed_reaction_1234567890abcdef1234567890abcd';
    const freshReactionId =
        'repeat_like_fresh_reaction_1234567890abcdef1234567890abcde';

    _MockEvent reaction({
      required String id,
      String content = '+',
      String pubkey = user,
      int createdAt = 1700000000,
      List<List<String>>? tags,
    }) {
      final event = _MockEvent();
      when(() => event.id).thenReturn(id);
      when(() => event.pubkey).thenReturn(pubkey);
      when(() => event.kind).thenReturn(EventKind.reaction);
      when(() => event.content).thenReturn(content);
      when(() => event.createdAt).thenReturn(createdAt);
      when(() => event.tags).thenReturn(
        tags ??
            [
              ['e', target],
            ],
      );
      return event;
    }

    _MockEvent deletion(List<String> reactionIds, {String pubkey = user}) {
      final event = _MockEvent();
      when(() => event.id).thenReturn('deletion_of_${reactionIds.join('_')}');
      when(() => event.pubkey).thenReturn(pubkey);
      when(() => event.kind).thenReturn(EventKind.eventDeletion);
      when(() => event.content).thenReturn('');
      when(() => event.createdAt).thenReturn(1700000001);
      when(
        () => event.tags,
      ).thenReturn([
        for (final id in reactionIds) ['e', id],
      ]);
      return event;
    }

    /// Answers reaction queries with [reactions] and deletion queries with
    /// [deletions], whatever order the repository issues them in.
    void stubRelay({
      List<Event> reactions = const [],
      List<Event> deletions = const [],
    }) {
      when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments.first as List<Filter>;
        final kinds = filters.first.kinds ?? const <int>[];
        if (kinds.contains(EventKind.reaction)) return reactions;
        if (kinds.contains(EventKind.eventDeletion)) return deletions;
        return const <Event>[];
      });
    }

    void stubCompleteRelaySnapshot({
      List<Event> reactions = const [],
      List<Event> deletions = const [],
      bool timedOut = false,
      bool noRelays = false,
    }) {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments.first as List<Filter>;
        final kinds = filters.first.kinds ?? const <int>[];
        return (
          events: kinds.contains(EventKind.reaction) ? reactions : deletions,
          timedOut: timedOut,
          noRelays: noRelays,
          anyRelayAnswered: false,
          unsettledRelays: const <String>[],
        );
      });
    }

    /// Like [stubCompleteRelaySnapshot], but the answer waits for
    /// [_GatedRelaySnapshot.land] so a tap can be interleaved with startup.
    _GatedRelaySnapshot gateRelaySnapshot() {
      final gate = _GatedRelaySnapshot();
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((invocation) {
        final filters = invocation.positionalArguments.first as List<Filter>;
        final kinds = filters.first.kinds ?? const <int>[];
        return kinds.contains(EventKind.reaction)
            ? gate.reactions.future
            : gate.deletions.future;
      });
      return gate;
    }

    void stubSendLike(Future<Event?> Function() answer) {
      when(
        () => nostrClient.sendLike(
          any(),
          content: any(named: 'content'),
          addressableId: any(named: 'addressableId'),
          targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
          targetKind: any(named: 'targetKind'),
        ),
      ).thenAnswer((_) => answer());
    }

    void expectNoPublish() {
      verifyNever(
        () => nostrClient.sendLike(
          any(),
          content: any(named: 'content'),
          addressableId: any(named: 'addressableId'),
          targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
          targetKind: any(named: 'targetKind'),
        ),
      );
    }

    void expectPublishedOnce() {
      verify(
        () => nostrClient.sendLike(
          target,
          content: any(named: 'content'),
          addressableId: any(named: 'addressableId'),
          targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
          targetKind: any(named: 'targetKind'),
        ),
      ).called(1);
    }

    LikeRecord placeholderRecord() => LikeRecord(
      targetEventId: target,
      reactionEventId: 'pending_like_1_$target',
      createdAt: DateTime.now(),
      addressableId: coordinate,
    );

    /// Every group writes through the store; declared per group so the stubs
    /// sit next to the tests that depend on them.
    void stubStorageWrites() {
      when(() => storage.saveLikeRecord(any())).thenAnswer((_) async {});
      when(
        () => storage.saveLikeRecordsBatch(any()),
      ).thenAnswer((_) async {});
      when(
        () => storage.deleteLikeRecord(any()),
      ).thenAnswer((_) async => true);
    }

    setUpAll(() {
      registerFallbackValue(_MockEvent());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(
        LikeRecord(
          targetEventId: 'fallback',
          reactionEventId: 'fallback',
          createdAt: DateTime.now(),
        ),
      );
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      storage = _MockLikesLocalStorage();
      when(() => nostrClient.publicKey).thenReturn(user);
      when(() => nostrClient.resolvePublicKey()).thenAnswer((_) async => user);
      when(() => nostrClient.hasKeys).thenReturn(true);
      when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => nostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => storage.getAllLikeRecords()).thenAnswer((_) async => []);
      when(() => storage.isLiked(any())).thenAnswer((_) async => false);
      when(() => storage.getLikeRecord(any())).thenAnswer((_) async => null);
      when(
        () => storage.getLikeRecordByAddressableId(any()),
      ).thenAnswer((_) async => null);
      repository = LikesRepository(
        nostrClient: nostrClient,
        localStorage: storage,
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
    });

    tearDown(() => repository.dispose());

    group('executeLikeAction', () {
      setUp(stubStorageWrites);

      test(
        'does not publish again when the record already holds a real '
        'reaction id',
        () async {
          // The replay row outlives the reaction it was queued for: the
          // original publish landed (the live subscription or a confirmed
          // swap upgraded the record) while the pending row still says
          // "retry". Publishing again mints a second live `+`.
          when(() => storage.getAllLikeRecords()).thenAnswer(
            (_) async => [
              LikeRecord(
                targetEventId: target,
                reactionEventId: landedReactionId,
                createdAt: DateTime.now(),
                addressableId: coordinate,
              ),
            ],
          );
          stubRelay();

          final resolved = await repository.executeLikeAction(
            eventId: target,
            authorPubkey: author,
            addressableId: coordinate,
          );

          expect(resolved, equals(landedReactionId));
          expectNoPublish();
        },
      );

      test(
        'adopts the reaction the relay already holds instead of '
        'republishing a placeholder',
        () async {
          // A publish can land without the OK ever reaching the client —
          // the frame is queued and replayed on reconnect, or the OK is
          // simply late. The client reports failure, queues a retry, and
          // the retry finds only its own placeholder locally.
          when(
            () => storage.getAllLikeRecords(),
          ).thenAnswer((_) async => [placeholderRecord()]);
          stubRelay(
            reactions: [
              reaction(
                id: landedReactionId,
                tags: [
                  ['e', target],
                  ['a', coordinate],
                ],
              ),
            ],
          );

          final resolved = await repository.executeLikeAction(
            eventId: target,
            authorPubkey: author,
            addressableId: coordinate,
          );

          expect(resolved, equals(landedReactionId));
          expectNoPublish();
          final record = await repository.getLikeRecord(target);
          expect(record?.reactionEventId, equals(landedReactionId));
          verify(
            () => storage.saveLikeRecord(
              any(
                that: isA<LikeRecord>().having(
                  (r) => r.reactionEventId,
                  'reactionEventId',
                  landedReactionId,
                ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'adopts a coordinate-tagged reaction cast on a superseded revision',
        () async {
          // NIP-25: an addressable target's reaction carries the `a`
          // coordinate alongside `e`. After an edit the `e` tag points at
          // the old revision, so only the coordinate can find it.
          when(
            () => storage.getAllLikeRecords(),
          ).thenAnswer(
            (_) async => [
              LikeRecord(
                targetEventId: editedTarget,
                reactionEventId: 'pending_like_2_$editedTarget',
                createdAt: DateTime.now(),
                addressableId: coordinate,
              ),
            ],
          );
          stubRelay(
            reactions: [
              reaction(
                id: landedReactionId,
                tags: [
                  ['e', target],
                  ['a', coordinate],
                ],
              ),
            ],
          );

          final resolved = await repository.executeLikeAction(
            eventId: editedTarget,
            authorPubkey: author,
            addressableId: coordinate,
          );

          expect(resolved, equals(landedReactionId));
          expectNoPublish();
          expect(await repository.isLikedByCoordinate(coordinate), isTrue);
        },
      );

      test('republishes when the relay copy was retracted', () async {
        when(
          () => storage.getAllLikeRecords(),
        ).thenAnswer((_) async => [placeholderRecord()]);
        stubRelay(
          reactions: [reaction(id: landedReactionId)],
          deletions: [
            deletion([landedReactionId]),
          ],
        );
        stubSendLike(() async => reaction(id: freshReactionId));

        final resolved = await repository.executeLikeAction(
          eventId: target,
          authorPubkey: author,
          addressableId: coordinate,
        );

        expect(resolved, equals(freshReactionId));
        expectPublishedOnce();
      });

      test('ignores a live reaction from another account', () async {
        // The REQ carries an `authors` filter, but a relay that ignores it
        // (or a merged cache hit) must not make this account adopt someone
        // else's reaction as its own.
        when(
          () => storage.getAllLikeRecords(),
        ).thenAnswer((_) async => [placeholderRecord()]);
        stubRelay(
          reactions: [reaction(id: landedReactionId, pubkey: otherUser)],
        );
        stubSendLike(() async => reaction(id: freshReactionId));

        final resolved = await repository.executeLikeAction(
          eventId: target,
          authorPubkey: author,
          addressableId: coordinate,
        );

        expect(resolved, equals(freshReactionId));
        expectPublishedOnce();
      });

      test('ignores a downvote when looking for a live like', () async {
        when(
          () => storage.getAllLikeRecords(),
        ).thenAnswer((_) async => [placeholderRecord()]);
        stubRelay(
          reactions: [reaction(id: landedReactionId, content: '-')],
        );
        stubSendLike(() async => reaction(id: freshReactionId));

        final resolved = await repository.executeLikeAction(
          eventId: target,
          authorPubkey: author,
          addressableId: coordinate,
        );

        expect(resolved, equals(freshReactionId));
        expectPublishedOnce();
      });

      test("ignores another account's downvote during adoption", () async {
        stubRelay(
          reactions: [
            reaction(id: landedReactionId, content: '-', pubkey: otherUser),
          ],
        );
        stubSendLike(() async => reaction(id: freshReactionId, content: '-'));

        final resolved = await repository.downvoteEvent(
          eventId: target,
          authorPubkey: author,
          addressableId: coordinate,
        );

        expect(resolved, equals(freshReactionId));
        expectPublishedOnce();
      });
    });

    group('likeEvent', () {
      setUp(stubStorageWrites);

      test(
        'adopts a live relay reaction and reports AlreadyLiked instead of '
        'minting a second +',
        () async {
          // Fresh install, new device, wiped cache: the local store knows
          // nothing, the heart reads unfilled, and the relay already holds
          // this account's `+`. Kind 7 is a regular event with no
          // per-pubkey uniqueness (NIP-01, NIP-25), so nothing downstream
          // collapses a second one — the client is the only guard.
          stubRelay(reactions: [reaction(id: landedReactionId)]);

          await expectLater(
            repository.likeEvent(eventId: target, authorPubkey: author),
            throwsA(isA<AlreadyLikedException>()),
          );

          expectNoPublish();
          expect(await repository.isLiked(target), isTrue);
          expect(
            (await repository.getLikeRecord(target))?.reactionEventId,
            equals(landedReactionId),
          );
          verify(
            () => storage.saveLikeRecord(
              any(
                that: isA<LikeRecord>().having(
                  (r) => r.reactionEventId,
                  'reactionEventId',
                  landedReactionId,
                ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'restores the cached count when adopting a relay reaction',
        () async {
          // The existing reaction is already inside the count the UI shows,
          // so the optimistic +1 has to come back off.
          when(
            () => nostrClient.countEvents(any()),
          ).thenAnswer((_) async => const CountResult(count: 10));
          stubRelay(reactions: [reaction(id: landedReactionId)]);
          expect(await repository.getLikeCount(target), equals(10));

          await expectLater(
            repository.likeEvent(eventId: target, authorPubkey: author),
            throwsA(isA<AlreadyLikedException>()),
          );

          expect(await repository.getLikeCount(target), equals(10));
        },
      );

      test(
        'keeps an e-tag-only adopted reaction indexed by the known '
        'coordinate through unlike and re-like',
        () async {
          stubRelay(reactions: [reaction(id: landedReactionId)]);

          await expectLater(
            repository.likeEvent(
              eventId: target,
              authorPubkey: author,
              addressableId: coordinate,
            ),
            throwsA(isA<AlreadyLikedException>()),
          );
          expect(await repository.isLikedByCoordinate(coordinate), isTrue);

          when(
            () => nostrClient.deleteEvent(landedReactionId),
          ).thenAnswer((_) async => _MockEvent());
          await repository.unlikeEvent(target, addressableId: coordinate);
          expect(await repository.isLikedByCoordinate(coordinate), isFalse);

          stubRelay(
            reactions: [reaction(id: landedReactionId)],
            deletions: [
              deletion([landedReactionId]),
            ],
          );
          stubSendLike(() async => reaction(id: freshReactionId));

          expect(
            await repository.toggleLike(
              eventId: target,
              authorPubkey: author,
              addressableId: coordinate,
            ),
            isTrue,
          );
          expectPublishedOnce();
        },
      );

      test(
        'adopts an empty-content reaction consistently with NIP-25',
        () async {
          stubRelay(
            reactions: [reaction(id: landedReactionId, content: '')],
          );

          await expectLater(
            repository.likeEvent(eventId: target, authorPubkey: author),
            throwsA(isA<AlreadyLikedException>()),
          );

          expectNoPublish();
          expect(await repository.isLiked(target), isTrue);
        },
      );

      test(
        'publishes without a target lookup after a complete startup snapshot',
        () async {
          stubCompleteRelaySnapshot();
          await repository.initialize();
          clearInteractions(nostrClient);
          stubSendLike(() async => reaction(id: freshReactionId));

          expect(
            await repository.likeEvent(eventId: target, authorPubkey: author),
            equals(freshReactionId),
          );

          verifyNever(() => nostrClient.queryEvents(any()));
          expectPublishedOnce();
        },
      );

      test(
        'retains the target lookup when startup reconciliation times out',
        () async {
          stubCompleteRelaySnapshot(timedOut: true);
          await repository.initialize();
          clearInteractions(nostrClient);
          stubRelay();
          stubSendLike(() async => reaction(id: freshReactionId));

          expect(
            await repository.likeEvent(eventId: target, authorPubkey: author),
            equals(freshReactionId),
          );

          verify(() => nostrClient.queryEvents(any())).called(1);
          expectPublishedOnce();
        },
      );

      test(
        'retains the target lookup when startup sees no relays',
        () async {
          stubCompleteRelaySnapshot(noRelays: true);
          await repository.initialize();
          clearInteractions(nostrClient);
          stubRelay();
          stubSendLike(() async => reaction(id: freshReactionId));

          expect(
            await repository.likeEvent(eventId: target, authorPubkey: author),
            equals(freshReactionId),
          );

          verify(() => nostrClient.queryEvents(any())).called(1);
          expectPublishedOnce();
        },
      );

      test(
        'retains the target lookup when startup reaches the reaction cap',
        () async {
          final cappedReactions = List<Event>.generate(
            500,
            (index) => reaction(
              id: 'capped_reaction_$index',
              tags: [
                ['e', 'capped_target_$index'],
              ],
            ),
          );
          stubCompleteRelaySnapshot(reactions: cappedReactions);
          await repository.initialize();
          clearInteractions(nostrClient);
          stubRelay();
          stubSendLike(() async => reaction(id: freshReactionId));

          expect(
            await repository.likeEvent(eventId: target, authorPubkey: author),
            equals(freshReactionId),
          );

          verify(() => nostrClient.queryEvents(any())).called(1);
          expectPublishedOnce();
        },
      );

      test(
        'retains the target lookup when startup cannot index an a-only like',
        () async {
          final coordinateOnlyReaction = reaction(
            id: landedReactionId,
            tags: [
              ['a', coordinate],
            ],
          );
          stubCompleteRelaySnapshot(reactions: [coordinateOnlyReaction]);
          await repository.initialize();
          clearInteractions(nostrClient);
          stubRelay(reactions: [coordinateOnlyReaction]);

          await expectLater(
            repository.likeEvent(
              eventId: target,
              authorPubkey: author,
              addressableId: coordinate,
            ),
            throwsA(isA<AlreadyLikedException>()),
          );

          // The target resolver queries by event id and coordinate, then
          // checks candidate reaction ids for deletions.
          verify(() => nostrClient.queryEvents(any())).called(3);
          expectNoPublish();
        },
      );

      test(
        'joins startup reconciliation and adopts its reaction during a tap',
        () async {
          final gate = gateRelaySnapshot();

          final initialization = repository.initialize();
          await Future<void>.delayed(Duration.zero);
          final like = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
          );
          await Future<void>.delayed(Duration.zero);
          gate.land(reactions: [reaction(id: landedReactionId)]);
          await initialization;

          await expectLater(like, throwsA(isA<AlreadyLikedException>()));
          expectNoPublish();
          verifyNever(() => nostrClient.queryEvents(any()));
        },
      );

      test(
        'publishes when the relay holds only a retracted reaction',
        () async {
          stubRelay(
            reactions: [reaction(id: landedReactionId)],
            deletions: [
              deletion([landedReactionId]),
            ],
          );
          stubSendLike(() async => reaction(id: freshReactionId));

          final result = await repository.likeEvent(
            eventId: target,
            authorPubkey: author,
          );

          expect(result, equals(freshReactionId));
          expectPublishedOnce();
        },
      );

      test('publishes when the relay check itself fails', () async {
        // The guard fails open: an unreachable relay must not turn a like
        // into a silent no-op. The publish that follows fails the same way
        // and takes the existing retry path.
        when(
          () => nostrClient.queryEvents(any()),
        ).thenThrow(Exception('relay unreachable'));
        stubSendLike(() async => reaction(id: freshReactionId));

        final result = await repository.likeEvent(
          eventId: target,
          authorPubkey: author,
        );

        expect(result, equals(freshReactionId));
        expectPublishedOnce();
      });

      test(
        'keeps the double-tap window closed while the relay check is pending',
        () async {
          // The placeholder must be indexed before the first await, or two
          // taps inside the relay round-trip both pass the already-liked
          // check and both publish.
          final relayGate = Completer<List<Event>>();
          when(
            () => nostrClient.queryEvents(any()),
          ).thenAnswer((_) => relayGate.future);
          stubSendLike(() async => reaction(id: freshReactionId));

          final first = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
          );
          await expectLater(
            repository.likeEvent(eventId: target, authorPubkey: author),
            throwsA(isA<AlreadyLikedException>()),
          );

          relayGate.complete(const <Event>[]);
          expect(await first, equals(freshReactionId));
          expectPublishedOnce();
        },
      );

      test(
        'retracts the adopted reaction when the user unliked during the '
        'relay check',
        () async {
          when(
            () => nostrClient.countEvents(any()),
          ).thenAnswer((_) async => const CountResult(count: 10));
          expect(await repository.getLikeCount(target), equals(10));
          final relayGate = Completer<List<Event>>();
          when(
            () => nostrClient.queryEvents(any()),
          ).thenAnswer((_) => relayGate.future);
          when(
            () => nostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => _MockEvent());

          final inFlight = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
          );
          await Future<void>.delayed(Duration.zero);
          await repository.unlikeEvent(target);

          relayGate.complete([reaction(id: landedReactionId)]);
          await inFlight;

          verify(() => nostrClient.deleteEvent(landedReactionId)).called(1);
          expectNoPublish();
          expect(await repository.isLiked(target), isFalse);
          expect(await repository.getLikeCount(target), equals(9));
        },
      );

      test(
        'joins startup reconciliation and adopts the reaction it filed under '
        'a superseded revision of the tapped coordinate',
        () async {
          // The snapshot files the like under its own `e` target — the
          // revision that was current when it was cast — and under the
          // coordinate. The tapped event id holds only this tap's
          // placeholder, so the coordinate is the one place the like shows.
          final gate = gateRelaySnapshot();
          stubSendLike(() async => reaction(id: freshReactionId));
          when(
            () => nostrClient.deleteEvent(landedReactionId),
          ).thenAnswer((_) async => _MockEvent());

          final initialization = repository.initialize();
          await Future<void>.delayed(Duration.zero);
          final like = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
            addressableId: coordinate,
          );
          await Future<void>.delayed(Duration.zero);
          gate.land(
            reactions: [
              reaction(
                id: landedReactionId,
                tags: [
                  ['e', editedTarget],
                  ['a', coordinate],
                ],
              ),
            ],
          );
          await initialization;

          await expectLater(like, throwsA(isA<AlreadyLikedException>()));
          expectNoPublish();

          // The adopted reaction answers the tapped target, so unliking it
          // publishes the Kind 5 instead of discarding a placeholder.
          await repository.unlikeEvent(target, addressableId: coordinate);
          verify(() => nostrClient.deleteEvent(landedReactionId)).called(1);
          expect(await repository.isLiked(editedTarget), isFalse);
          expect(await repository.isLikedByCoordinate(coordinate), isFalse);
          verify(() => storage.deleteLikeRecord(editedTarget)).called(1);
        },
      );

      test(
        'joins startup reconciliation and keeps its coordinate-less reaction '
        'resolvable by the tapped coordinate',
        () async {
          // An older reaction carries only an `e` tag. Adopted as-is it
          // would leave this tap's placeholder in the coordinate index, so
          // the heart stays filled after the unlike that retracts it.
          final gate = gateRelaySnapshot();
          stubSendLike(() async => reaction(id: freshReactionId));
          when(
            () => nostrClient.deleteEvent(landedReactionId),
          ).thenAnswer((_) async => _MockEvent());

          final initialization = repository.initialize();
          await Future<void>.delayed(Duration.zero);
          final like = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
            addressableId: coordinate,
          );
          await Future<void>.delayed(Duration.zero);
          gate.land(reactions: [reaction(id: landedReactionId)]);
          await initialization;

          await expectLater(like, throwsA(isA<AlreadyLikedException>()));
          expectNoPublish();

          await repository.unlikeEvent(target, addressableId: coordinate);
          verify(() => nostrClient.deleteEvent(landedReactionId)).called(1);
          expect(await repository.isLiked(target), isFalse);
          expect(await repository.isLikedByCoordinate(coordinate), isFalse);
        },
      );

      test(
        'settles the count where it started when the reaction this tap '
        'published is retracted mid-publish',
        () async {
          // Unlike the adopted-reaction case above, the retracted reaction
          // was never inside the count the UI showed before the tap.
          when(
            () => nostrClient.countEvents(any()),
          ).thenAnswer((_) async => const CountResult(count: 10));
          expect(await repository.getLikeCount(target), equals(10));
          stubRelay();
          final publishGate = Completer<Event?>();
          stubSendLike(() => publishGate.future);
          when(
            () => nostrClient.deleteEvent(freshReactionId),
          ).thenAnswer((_) async => _MockEvent());

          final inFlight = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
          );
          await Future<void>.delayed(Duration.zero);
          expect(await repository.getLikeCount(target), equals(11));
          await repository.unlikeEvent(target);
          expect(await repository.getLikeCount(target), equals(10));

          publishGate.complete(reaction(id: freshReactionId));
          expect(await inFlight, equals(freshReactionId));

          verify(() => nostrClient.deleteEvent(freshReactionId)).called(1);
          expect(await repository.isLiked(target), isFalse);
          expect(await repository.getLikeCount(target), equals(10));
        },
      );

      test(
        'drops every record naming a startup-indexed reaction retracted '
        'during the join',
        () async {
          // The user takes the like back while the tap is still waiting on
          // startup, which then files the reaction under its own `e` target
          // and the coordinate. The Kind 5 lands against a reaction both of
          // those records still name.
          final gate = gateRelaySnapshot();
          when(
            () => nostrClient.deleteEvent(landedReactionId),
          ).thenAnswer((_) async => _MockEvent());

          final initialization = repository.initialize();
          await Future<void>.delayed(Duration.zero);
          final like = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
            addressableId: coordinate,
          );
          await Future<void>.delayed(Duration.zero);
          await repository.unlikeEvent(target, addressableId: coordinate);
          gate.land(
            reactions: [
              reaction(
                id: landedReactionId,
                tags: [
                  ['e', editedTarget],
                  ['a', coordinate],
                ],
              ),
            ],
          );
          await initialization;

          expect(await like, equals(landedReactionId));
          verify(() => nostrClient.deleteEvent(landedReactionId)).called(1);
          expectNoPublish();
          expect(await repository.isLiked(editedTarget), isFalse);
          expect(await repository.isLikedByCoordinate(coordinate), isFalse);
        },
      );
    });

    group('live subscription', () {
      setUp(stubStorageWrites);

      test(
        'upgrades a same-second placeholder to the reaction the relay stored',
        () async {
          // The relay echoes the stored reaction to the account's own
          // subscription. Its created_at is whole seconds, so it never
          // reads as "after" a placeholder stamped milliseconds earlier in
          // the same second — and a placeholder is not a real record to
          // defend, it is the absence of one.
          final live = StreamController<Event>.broadcast();
          addTearDown(live.close);
          when(
            () => nostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => live.stream);
          stubRelay();
          final publishGate = Completer<Event?>();
          stubSendLike(() => publishGate.future);
          await repository.initialize();

          final inFlight = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
          );
          await Future<void>.delayed(Duration.zero);
          final placeholder = await repository.getLikeRecord(target);
          expect(placeholder?.reactionEventId, startsWith('pending_like_'));

          final sameSecond = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          live.add(reaction(id: landedReactionId, createdAt: sameSecond));
          await Future<void>.delayed(Duration.zero);

          expect(
            (await repository.getLikeRecord(target))?.reactionEventId,
            equals(landedReactionId),
          );

          publishGate.complete(reaction(id: landedReactionId));
          await inFlight;
        },
      );

      test(
        'drops a reaction the relay echoed after the user unliked it '
        'mid-publish, once the retraction lands',
        () async {
          // The relay echoes the stored reaction on the account's own
          // subscription within milliseconds of storing it — before the OK
          // in the reproduction on the local stack. Unlike → echo → OK
          // leaves the retracted reaction indexed, so the heart reads liked
          // for a like the user already took back.
          final live = StreamController<Event>.broadcast();
          addTearDown(live.close);
          when(
            () => nostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => live.stream);
          stubRelay();
          final publishGate = Completer<Event?>();
          stubSendLike(() => publishGate.future);
          when(
            () => nostrClient.deleteEvent(any()),
          ).thenAnswer((_) async => _MockEvent());
          await repository.initialize();

          final inFlight = repository.likeEvent(
            eventId: target,
            authorPubkey: author,
          );
          await Future<void>.delayed(Duration.zero);
          await repository.unlikeEvent(target);

          live.add(reaction(id: landedReactionId));
          await Future<void>.delayed(Duration.zero);
          publishGate.complete(reaction(id: landedReactionId));
          await inFlight;

          verify(() => nostrClient.deleteEvent(landedReactionId)).called(1);
          expect(await repository.isLiked(target), isFalse);
          verify(() => storage.deleteLikeRecord(target)).called(2);
        },
      );

      test(
        'upgrades a same-second downvote placeholder before removal',
        () async {
          final live = StreamController<Event>.broadcast();
          addTearDown(live.close);
          when(
            () => nostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => live.stream);
          stubCompleteRelaySnapshot();
          final publishGate = Completer<Event?>();
          stubSendLike(() => publishGate.future);
          when(
            () => nostrClient.deleteEvent(landedReactionId),
          ).thenAnswer((_) async => _MockEvent());
          await repository.initialize();

          final inFlight = repository.downvoteEvent(
            eventId: target,
            authorPubkey: author,
          );
          await Future<void>.delayed(Duration.zero);
          final sameSecond = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          live.add(
            reaction(
              id: landedReactionId,
              content: '-',
              createdAt: sameSecond,
            ),
          );
          await Future<void>.delayed(Duration.zero);

          await repository.removeDownvote(target);
          verify(() => nostrClient.deleteEvent(landedReactionId)).called(1);

          publishGate.completeError(Exception('publish acknowledgement lost'));
          await expectLater(inFlight, throwsException);
        },
      );
    });

    test(
      'a like that joined a failing initialization still publishes',
      () async {
        // Startup reconciliation is best-effort, and a tap that joined the
        // attempt must not surface its failure as a failed like: the
        // optimistic heart is already filled and the queue never sees the
        // action. The snapshot stays incomplete, so the target-specific
        // safety check still guards the publish.
        stubStorageWrites();
        final signerGate = Completer<String?>();
        when(
          () => nostrClient.resolvePublicKey(),
        ).thenAnswer((_) => signerGate.future);
        stubRelay();
        stubSendLike(() async => reaction(id: freshReactionId));

        final initialization = repository.initialize();
        await Future<void>.delayed(Duration.zero);
        final like = repository.likeEvent(
          eventId: target,
          authorPubkey: author,
        );
        final published = expectLater(
          like,
          completion(equals(freshReactionId)),
        );
        final failed = expectLater(initialization, throwsA(isA<StateError>()));
        await Future<void>.delayed(Duration.zero);
        signerGate.completeError(StateError('signer failed'));

        await failed;
        await published;
        expectPublishedOnce();
      },
    );

    test('a failed initialization can be retried', () async {
      var attempts = 0;
      when(() => nostrClient.resolvePublicKey()).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw StateError('signer failed once');
        return user;
      });

      await expectLater(repository.initialize(), throwsA(isA<StateError>()));

      stubCompleteRelaySnapshot();
      await repository.initialize();
      // The retry resolves once for subscription setup and once for the
      // author-scoped startup snapshot.
      expect(attempts, equals(3));
    });
  });
}
