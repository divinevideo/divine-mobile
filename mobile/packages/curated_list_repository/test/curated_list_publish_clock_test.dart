// ABOUTME: Verifies monotonic publication clocks and bounded retry policy.
// ABOUTME: Keeps revisions scoped to full author and list identities.

import 'package:clock/clock.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('CuratedListPublishClock.next', () {
    final owner = 'a' * 64;
    final other = 'b' * 64;
    var now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    const seconds = 1700000000;
    CuratedList source({
      String? pubkey,
      String? eventId,
      bool pending = false,
      int revision = seconds,
    }) => CuratedList(
      id: 'clock-list',
      name: 'Clock',
      pubkey: pubkey,
      nostrEventId: eventId,
      videoEventIds: const [],
      createdAt: now,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(revision * 1000),
      pendingRepublish: pending,
    );

    setUp(() {
      now = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    });

    test(
      'unpublished and unknown-owner copies do not allocate source revisions',
      () {
        withClock(Clock(() => now), () {
          final revisions = CuratedListPublishClock()
            ..observe(source(eventId: 'c' * 64))
            ..observe(source(pubkey: owner, revision: seconds + 9));
          expect(
            revisions.next(ownerPubkey: owner, listId: 'clock-list'),
            seconds,
          );
          expect(
            revisions.next(ownerPubkey: owner, listId: 'clock-list'),
            seconds + 1,
          );
          expect(
            revisions.next(ownerPubkey: other, listId: 'clock-list'),
            seconds,
          );
        });
      },
    );

    test('stored attempts and received revisions never move backwards', () {
      withClock(Clock(() => now), () {
        final revisions = CuratedListPublishClock()
          ..observe(source(pubkey: owner, pending: true, revision: seconds + 3))
          ..observe(
            source(pubkey: owner, eventId: 'c' * 64, revision: seconds + 2),
          );
        expect(
          revisions.next(ownerPubkey: owner, listId: 'clock-list'),
          seconds + 4,
        );
        now = now.add(const Duration(seconds: 10));
        expect(
          revisions.next(ownerPubkey: owner, listId: 'clock-list'),
          seconds + 10,
        );
      });
    });

    test(
      'future ceiling preserves the revision until the clock catches up',
      () {
        withClock(Clock(() => now), () {
          final revisions = CuratedListPublishClock()
            ..observe(
              source(pubkey: owner, eventId: 'c' * 64, revision: seconds + 59),
            );
          expect(
            revisions.next(ownerPubkey: owner, listId: 'clock-list'),
            seconds + 60,
          );
          expect(
            () => revisions.next(ownerPubkey: owner, listId: 'clock-list'),
            throwsA(isA<CuratedListClockException>()),
          );
          now = now.add(const Duration(seconds: 1));
          expect(
            revisions.next(ownerPubkey: owner, listId: 'clock-list'),
            seconds + 61,
          );
        });
      },
    );

    test('future relay rejection waits for clock advancement before retry', () {
      withClock(Clock(() => now), () {
        final revisions = CuratedListPublishClock();
        expect(
          revisions.next(ownerPubkey: owner, listId: 'clock-list'),
          seconds,
        );
        revisions.rejectedFuture(
          ownerPubkey: owner,
          listId: 'clock-list',
          createdAt: seconds + 2,
        );
        expect(
          () => revisions.next(ownerPubkey: owner, listId: 'clock-list'),
          throwsA(isA<CuratedListClockException>()),
        );
        expect(
          revisions.next(ownerPubkey: other, listId: 'clock-list'),
          seconds,
        );
        now = now.add(const Duration(seconds: 3));
        expect(
          revisions.next(ownerPubkey: owner, listId: 'clock-list'),
          seconds + 3,
        );
      });
    });
    test(
      'rapid revisions stop at the configured client ceiling without reserving a rejected revision',
      () {
        withClock(Clock(() => now), () {
          final revisions = CuratedListPublishClock();
          for (var offset = 0; offset <= 60; offset++) {
            expect(
              revisions.next(ownerPubkey: owner, listId: 'clock-list'),
              seconds + offset,
            );
          }
          expect(
            () => revisions.next(ownerPubkey: owner, listId: 'clock-list'),
            throwsA(isA<CuratedListClockException>()),
          );
          now = now.add(const Duration(seconds: 1));
          expect(
            revisions.next(ownerPubkey: owner, listId: 'clock-list'),
            seconds + 61,
          );
        });
      },
    );
  });
}
