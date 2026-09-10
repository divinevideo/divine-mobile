// ABOUTME: Tests for DmSyncState — persistence of per-pubkey DM sync
// ABOUTME: boundaries (newestSyncedAt / oldestSyncedAt) in SharedPreferences.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(DmSyncState, () {
    late SharedPreferences prefs;
    late DmSyncState state;

    const pkA = 'npub1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const pkB = 'npub1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    // Ascending plausible Nostr timestamps (Nov 2023). The boundary
    // assertions below only care about relative order, but `recordSeen`
    // floors anything before [DmSyncState.minPlausibleCreatedAt], so the
    // fixtures have to be times a real event could carry.
    const tsOldest = 1700000000;
    const tsMid = 1700000500;
    const tsNewer = 1700001000;
    const tsNewest = 1700002000;
    const tsOther = 1700003000;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      state = DmSyncState(prefs);
    });

    test(
      'returns null for newestSyncedAt and oldestSyncedAt when nothing '
      'persisted',
      () {
        expect(state.newestSyncedAt(pkA), isNull);
        expect(state.oldestSyncedAt(pkA), isNull);
      },
    );

    test(
      'recordSeen sets both newest and oldest for the first event',
      () async {
        await state.recordSeen(pkA, createdAt: tsOldest);

        expect(state.newestSyncedAt(pkA), equals(tsOldest));
        expect(state.oldestSyncedAt(pkA), equals(tsOldest));
      },
    );

    test(
      'recordSeen advances newest monotonically — lower createdAt does '
      'not overwrite',
      () async {
        await state.recordSeen(pkA, createdAt: tsNewer);
        await state.recordSeen(pkA, createdAt: tsMid);

        expect(state.newestSyncedAt(pkA), equals(tsNewer));
      },
    );

    test(
      'recordSeen advances oldest monotonically downward — higher '
      'createdAt does not overwrite oldest',
      () async {
        await state.recordSeen(pkA, createdAt: tsOldest);
        await state.recordSeen(pkA, createdAt: tsNewer);

        expect(state.oldestSyncedAt(pkA), equals(tsOldest));
        expect(state.newestSyncedAt(pkA), equals(tsNewer));
      },
    );

    test(
      "recordSeen scopes state per pubkey — one user's boundary does "
      'not bleed into another',
      () async {
        await state.recordSeen(pkA, createdAt: tsOldest);
        await state.recordSeen(pkA, createdAt: tsNewer);

        expect(state.newestSyncedAt(pkB), isNull);
        expect(state.oldestSyncedAt(pkB), isNull);

        await state.recordSeen(pkB, createdAt: tsOther);

        expect(state.newestSyncedAt(pkA), equals(tsNewer));
        expect(state.oldestSyncedAt(pkA), equals(tsOldest));
        expect(state.newestSyncedAt(pkB), equals(tsOther));
        expect(state.oldestSyncedAt(pkB), equals(tsOther));
      },
    );

    test(
      'clear removes both newest and oldest for the given pubkey and '
      'leaves others intact',
      () async {
        await state.recordSeen(pkA, createdAt: tsOldest);
        await state.recordSeen(pkA, createdAt: tsNewer);
        await state.recordSeen(pkB, createdAt: tsNewest);

        await state.clear(pkA);

        expect(state.newestSyncedAt(pkA), isNull);
        expect(state.oldestSyncedAt(pkA), isNull);
        expect(state.newestSyncedAt(pkB), equals(tsNewest));
        expect(state.oldestSyncedAt(pkB), equals(tsNewest));
      },
    );

    test(
      'clearAll removes sync state for every pubkey and leaves '
      'non-dm keys intact',
      () async {
        await state.recordSeen(pkA, createdAt: tsOldest);
        await state.recordSeen(pkA, createdAt: tsNewer);
        await state.recordSeen(pkB, createdAt: tsNewest);
        await prefs.setString('unrelated_key', 'keep_me');

        await state.clearAll();

        expect(state.newestSyncedAt(pkA), isNull);
        expect(state.oldestSyncedAt(pkA), isNull);
        expect(state.newestSyncedAt(pkB), isNull);
        expect(state.oldestSyncedAt(pkB), isNull);
        expect(prefs.getString('unrelated_key'), equals('keep_me'));
      },
    );

    group('historyDrainComplete', () {
      test('defaults to false when nothing persisted', () {
        expect(state.historyDrainComplete(pkA), isFalse);
      });

      test('markHistoryDrainComplete flips the flag to true', () async {
        await state.markHistoryDrainComplete(pkA);

        expect(state.historyDrainComplete(pkA), isTrue);
      });

      test('is scoped per pubkey', () async {
        await state.markHistoryDrainComplete(pkA);

        expect(state.historyDrainComplete(pkA), isTrue);
        expect(state.historyDrainComplete(pkB), isFalse);
      });

      test('clear re-arms the drain for the given pubkey only', () async {
        await state.markHistoryDrainComplete(pkA);
        await state.markHistoryDrainComplete(pkB);

        await state.clear(pkA);

        expect(state.historyDrainComplete(pkA), isFalse);
        expect(state.historyDrainComplete(pkB), isTrue);
      });

      test('clearAll re-arms the drain for every pubkey', () async {
        await state.markHistoryDrainComplete(pkA);
        await state.markHistoryDrainComplete(pkB);

        await state.clearAll();

        expect(state.historyDrainComplete(pkA), isFalse);
        expect(state.historyDrainComplete(pkB), isFalse);
      });
    });

    // The inbox's recovery gate reads this rather than historyDrainComplete:
    // a forced recovery pass clears the latch on an install whose own replies
    // are already local, and gating on the latch alone hid every request and
    // raised the "haven't finished restoring" banner on each deferral (#8550).
    group('historyDrainCompletedBefore', () {
      test('is false until a drain completes', () async {
        expect(state.historyDrainCompletedBefore(pkA), isFalse);

        await state.migrateHistoryDrainCompletion(pkA);
        await state.setHistoryDrainCursor(pkA, 1234);
        await state.setDrainVersion(pkA, DmSyncState.currentDrainVersion);

        expect(state.historyDrainCompletedBefore(pkA), isFalse);
      });

      test('is true once a drain completes', () async {
        await state.markHistoryDrainComplete(pkA);

        expect(state.historyDrainCompletedBefore(pkA), isTrue);
        expect(state.historyDrainCompletedBefore(pkB), isFalse);
      });

      test(
        'survives a drain-version bump clearing the completion latch',
        () async {
          await state.markHistoryDrainComplete(pkA);
          await state.setDrainVersion(pkA, DmSyncState.currentDrainVersion - 1);

          await state.upgradeDrainVersionIfNeeded(pkA);

          expect(state.historyDrainComplete(pkA), isFalse);
          expect(state.historyDrainCompletedBefore(pkA), isTrue);
        },
      );

      test('survives the own-inbox coverage re-arm', () async {
        await state.markHistoryDrainComplete(pkA);

        await state.rearmDrainForOwnInbox(pkA);

        expect(state.historyDrainComplete(pkA), isFalse);
        expect(state.historyDrainCompletedBefore(pkA), isTrue);
      });

      test(
        'is inferred from drain generation 5 before migration',
        () async {
          await state.setDrainVersion(pkA, 5);

          expect(state.historyDrainComplete(pkA), isFalse);
          expect(state.historyDrainCompletedBefore(pkA), isTrue);
        },
      );

      test('migrates generation 5 to the durable completion record', () async {
        await state.setDrainVersion(pkA, 5);

        await state.migrateHistoryDrainCompletion(pkA);

        expect(state.historyDrainCompletedBefore(pkA), isTrue);
        await state.setDrainVersion(pkA, DmSyncState.currentDrainVersion + 1);
        expect(state.historyDrainCompletedBefore(pkA), isTrue);
      });

      test('keeps a fresh install gated when stamping its version', () async {
        await state.migrateHistoryDrainCompletion(pkA);
        await state.upgradeDrainVersionIfNeeded(pkA);

        expect(state.historyDrainCompletedBefore(pkA), isFalse);
      });

      test(
        'is not implied by a boundary repair on an install that never '
        'completed a drain',
        () async {
          // recordSeen clamps to now, so the poisoned value has to be written
          // the way an older build left it.
          final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          await prefs.setInt('dm.newestSyncedAt.$pkA', nowSec + 7 * 86400);

          await state.repairPoisonedBoundaries(pkA);

          expect(state.historyDrainCursor(pkA), isNotNull);
          expect(state.historyDrainCompletedBefore(pkA), isFalse);
        },
      );

      test('clear and clearAll reset it', () async {
        await state.markHistoryDrainComplete(pkA);
        await state.markHistoryDrainComplete(pkB);

        await state.clear(pkA);
        expect(state.historyDrainCompletedBefore(pkA), isFalse);
        expect(state.historyDrainCompletedBefore(pkB), isTrue);

        await state.clearAll();
        expect(state.historyDrainCompletedBefore(pkB), isFalse);
      });
    });

    group('historyDrainCursor', () {
      test('defaults to null when nothing persisted', () {
        expect(state.historyDrainCursor(pkA), isNull);
      });

      test('setHistoryDrainCursor round-trips the value', () async {
        await state.setHistoryDrainCursor(pkA, 1699000000);

        expect(state.historyDrainCursor(pkA), equals(1699000000));
      });

      test('is scoped per pubkey', () async {
        await state.setHistoryDrainCursor(pkA, 1000);

        expect(state.historyDrainCursor(pkA), equals(1000));
        expect(state.historyDrainCursor(pkB), isNull);
      });

      test('markHistoryDrainComplete clears the cursor', () async {
        await state.setHistoryDrainCursor(pkA, 1000);

        await state.markHistoryDrainComplete(pkA);

        expect(state.historyDrainCursor(pkA), isNull);
        expect(state.historyDrainComplete(pkA), isTrue);
      });

      test('clear removes the cursor for the given pubkey only', () async {
        await state.setHistoryDrainCursor(pkA, 1000);
        await state.setHistoryDrainCursor(pkB, 2000);

        await state.clear(pkA);

        expect(state.historyDrainCursor(pkA), isNull);
        expect(state.historyDrainCursor(pkB), equals(2000));
      });

      test('clearAll removes the cursor for every pubkey', () async {
        await state.setHistoryDrainCursor(pkA, 1000);
        await state.setHistoryDrainCursor(pkB, 2000);

        await state.clearAll();

        expect(state.historyDrainCursor(pkA), isNull);
        expect(state.historyDrainCursor(pkB), isNull);
      });
    });

    group('drainVersion', () {
      test('defaults to 0 when never recorded', () {
        expect(state.drainVersion(pkA), equals(0));
      });

      test('setDrainVersion persists per pubkey', () async {
        await state.setDrainVersion(pkA, 2);

        expect(state.drainVersion(pkA), equals(2));
        expect(state.drainVersion(pkB), equals(0));
      });

      test(
        'upgradeDrainVersionIfNeeded clears a stale completion flag, seeds the '
        'cursor at now, and stamps the current version when below it',
        () async {
          final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          // Simulate an established install stranded by an older, buggy drain.
          await state.recordSeen(pkA, createdAt: before - 3600);
          await state.markHistoryDrainComplete(pkA);
          await state.setHistoryDrainCursor(pkA, 1234);
          expect(state.historyDrainComplete(pkA), isTrue);

          await state.upgradeDrainVersionIfNeeded(pkA);
          final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;

          expect(state.historyDrainComplete(pkA), isFalse);
          // Seeded at now, NOT removed. Removing it would let the drain fall
          // back to oldestSyncedAt and re-read only history the install
          // already has, which is the whole defect in #8362.
          expect(
            state.historyDrainCursor(pkA),
            inInclusiveRange(before, after),
          );
          expect(state.drainVersion(pkA), DmSyncState.currentDrainVersion);
        },
      );

      test(
        'the seeded cursor is above a realistic oldestSyncedAt, so the forced '
        'pass covers the recent window a bare clear would skip — #8362',
        () async {
          final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          // Established install: months of history, drain long since latched.
          await state.recordSeen(pkA, createdAt: nowSec - 90 * 86400);
          await state.recordSeen(pkA, createdAt: nowSec - 3600);
          await state.markHistoryDrainComplete(pkA);
          await state.setDrainVersion(pkA, DmSyncState.currentDrainVersion - 1);

          await state.upgradeDrainVersionIfNeeded(pkA);

          final cursor = state.historyDrainCursor(pkA);
          expect(cursor, isNotNull);
          expect(
            cursor,
            greaterThan(state.oldestSyncedAt(pkA)!),
            reason: 'a cursor at oldestSyncedAt cannot reach the stranded band',
          );
          // The band #8361 re-exposes sits just under the two-day overlap.
          expect(cursor, greaterThan(nowSec - 2 * 86400));
        },
      );

      test(
        're-arms a completed pre-guard drain with no recorded messages',
        () async {
          final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          await state.markHistoryDrainComplete(pkA);
          await state.setDrainVersion(pkA, 0);

          expect(state.newestSyncedAt(pkA), isNull);
          expect(state.oldestSyncedAt(pkA), isNull);

          await state.upgradeDrainVersionIfNeeded(pkA);

          final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          expect(state.historyDrainComplete(pkA), isFalse);
          expect(
            state.historyDrainCursor(pkA),
            inInclusiveRange(before, after),
          );
          expect(state.drainVersion(pkA), DmSyncState.currentDrainVersion);
        },
      );

      test(
        'preserves an in-progress drain cursor while stamping its version',
        () async {
          await state.setHistoryDrainCursor(pkA, 1234);
          await state.setDrainVersion(pkA, 0);

          await state.upgradeDrainVersionIfNeeded(pkA);

          expect(state.historyDrainComplete(pkA), isFalse);
          expect(state.historyDrainCursor(pkA), 1234);
          expect(state.drainVersion(pkA), DmSyncState.currentDrainVersion);
        },
      );

      test(
        'upgradeDrainVersionIfNeeded is idempotent at the current version',
        () async {
          await state.upgradeDrainVersionIfNeeded(pkA);
          // A genuine completion at the current version must survive a second
          // upgrade pass (no re-drain loop on every inbox open).
          await state.markHistoryDrainComplete(pkA);

          await state.upgradeDrainVersionIfNeeded(pkA);

          expect(state.historyDrainComplete(pkA), isTrue);
          expect(state.drainVersion(pkA), DmSyncState.currentDrainVersion);
        },
      );

      test(
        'forces a one-time re-drain for installs stranded at the pre-#5304 '
        'drain version (2)',
        () async {
          // #5304 bumped the drain version so installs whose earlier drain
          // completed before the user's own messages were recovered (which
          // stranded established chats under "Message requests") get one fresh
          // recovery pass under the new recovery-aware gate + NIP-04 recovery.
          expect(
            DmSyncState.currentDrainVersion,
            greaterThanOrEqualTo(3),
            reason: 'drain version must advance past the pre-#5304 value (2)',
          );

          await state.recordSeen(
            pkA,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600,
          );
          await state.setDrainVersion(pkA, 2);
          await state.markHistoryDrainComplete(pkA);

          await state.upgradeDrainVersionIfNeeded(pkA);

          expect(state.historyDrainComplete(pkA), isFalse);
          expect(state.drainVersion(pkA), DmSyncState.currentDrainVersion);
        },
      );

      test('clear and clearAll reset the drain version', () async {
        await state.setDrainVersion(pkA, DmSyncState.currentDrainVersion);
        await state.setDrainVersion(pkB, DmSyncState.currentDrainVersion);

        await state.clear(pkA);
        expect(state.drainVersion(pkA), equals(0));
        expect(state.drainVersion(pkB), DmSyncState.currentDrainVersion);

        await state.clearAll();
        expect(state.drainVersion(pkB), equals(0));
      });
    });

    group('dmRelayListPublished (#4974)', () {
      test('defaults to false and flips to true after marking', () async {
        expect(state.dmRelayListPublished(pkA), isFalse);
        await state.markDmRelayListPublished(pkA);
        expect(state.dmRelayListPublished(pkA), isTrue);
      });

      test('is per-pubkey — marking one does not affect another', () async {
        await state.markDmRelayListPublished(pkA);
        expect(state.dmRelayListPublished(pkA), isTrue);
        expect(state.dmRelayListPublished(pkB), isFalse);
      });

      test('clear removes only the selected pubkey marker', () async {
        await state.markDmRelayListPublished(pkA);
        await state.markDmRelayListPublished(pkB);

        await state.clear(pkA);

        expect(state.dmRelayListPublished(pkA), isFalse);
        expect(state.dmRelayListPublished(pkB), isTrue);
      });

      test('clearAll removes all markers and leaves unrelated keys', () async {
        await state.markDmRelayListPublished(pkA);
        await state.markDmRelayListPublished(pkB);
        await prefs.setString('unrelated_key', 'keep_me');

        await state.clearAll();

        expect(state.dmRelayListPublished(pkA), isFalse);
        expect(state.dmRelayListPublished(pkB), isFalse);
        expect(prefs.getString('unrelated_key'), equals('keep_me'));
      });
    });

    group('unauthenticated rumor timestamps', () {
      // A NIP-59 rumor is unsigned, so `created_at` is attacker-chosen.
      // Absolute out-of-bounds values keep these deterministic without
      // needing to control the wall clock.
      const year2100 = 4102444800;
      const epochOne = 1;

      int nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

      test('recordSeen caps a far-future createdAt at now', () async {
        await state.recordSeen(pkA, createdAt: year2100);

        final newest = state.newestSyncedAt(pkA);
        expect(newest, isNotNull);
        expect(newest, lessThan(year2100));
        expect(newest, closeTo(nowSec(), 5));
      });

      test('recordSeen caps oldest for a first far-future createdAt', () async {
        await state.recordSeen(pkA, createdAt: year2100);

        final oldest = state.oldestSyncedAt(pkA);
        expect(oldest, isNotNull);
        expect(oldest, lessThan(year2100));
        expect(oldest, closeTo(nowSec(), 5));
      });

      test(
        'recordSeen floors newest for a first implausibly old createdAt',
        () async {
          await state.recordSeen(pkA, createdAt: epochOne);

          expect(
            state.newestSyncedAt(pkA),
            equals(DmSyncState.minPlausibleCreatedAt),
          );
        },
      );

      test(
        'a capped createdAt cannot push the live since: filter past now',
        () async {
          await state.recordSeen(pkA, createdAt: year2100);

          // DmRepository.startListening derives `since` this way; if it ever
          // lands in the future the relay returns nothing and the inbox is
          // silently blackholed.
          final since = state.newestSyncedAt(pkA)! - 2 * 86400;
          expect(since, lessThan(nowSec()));
        },
      );

      test('recordSeen floors an implausibly old createdAt', () async {
        await state.recordSeen(pkA, createdAt: epochOne);

        expect(
          state.oldestSyncedAt(pkA),
          equals(DmSyncState.minPlausibleCreatedAt),
        );
      });

      test('recordSeen leaves an in-range createdAt untouched', () async {
        final honest = nowSec() - 60;

        await state.recordSeen(pkA, createdAt: honest);

        expect(state.newestSyncedAt(pkA), equals(honest));
        expect(state.oldestSyncedAt(pkA), equals(honest));
      });

      test(
        'repairPoisonedBoundaries heals a cursor persisted by an older build '
        'and re-arms the drain',
        () async {
          // Simulate a pre-guard build having written the poisoned value.
          await prefs.setInt('dm.newestSyncedAt.$pkA', year2100);
          await state.markHistoryDrainComplete(pkA);
          await state.setHistoryDrainCursor(pkA, tsOldest);
          expect(state.historyDrainComplete(pkA), isTrue);

          await state.repairPoisonedBoundaries(pkA);

          expect(state.newestSyncedAt(pkA), closeTo(nowSec(), 5));
          expect(state.historyDrainComplete(pkA), isFalse);
          expect(state.historyDrainCursor(pkA), closeTo(nowSec(), 5));
          expect(state.historyDrainCompletedBefore(pkA), isTrue);
        },
      );

      test('repairPoisonedBoundaries heals an implausibly old floor', () async {
        await prefs.setInt('dm.oldestSyncedAt.$pkA', epochOne);

        await state.repairPoisonedBoundaries(pkA);

        expect(
          state.oldestSyncedAt(pkA),
          equals(DmSyncState.minPlausibleCreatedAt),
        );
      });

      test(
        'repairPoisonedBoundaries heals an implausibly future oldest',
        () async {
          await prefs.setInt('dm.oldestSyncedAt.$pkA', year2100);

          await state.repairPoisonedBoundaries(pkA);

          expect(state.oldestSyncedAt(pkA), closeTo(nowSec(), 5));
          expect(state.historyDrainCursor(pkA), closeTo(nowSec(), 5));
        },
      );

      test(
        'repairPoisonedBoundaries is a no-op for healthy boundaries',
        () async {
          final honest = nowSec() - 3600;
          await state.recordSeen(pkA, createdAt: honest);
          await state.markHistoryDrainComplete(pkA);

          await state.repairPoisonedBoundaries(pkA);

          expect(state.newestSyncedAt(pkA), equals(honest));
          expect(state.oldestSyncedAt(pkA), equals(honest));
          // A healthy install must not be forced through a re-drain.
          expect(state.historyDrainComplete(pkA), isTrue);
        },
      );

      test(
        'repairPoisonedBoundaries is a no-op when nothing is stored',
        () async {
          await state.repairPoisonedBoundaries(pkA);

          expect(state.newestSyncedAt(pkA), isNull);
          expect(state.oldestSyncedAt(pkA), isNull);
        },
      );
    });

    group('newestWireSyncedAt (#8209)', () {
      const year2100 = 4102444800;
      int nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

      test('defaults to null when nothing has been processed', () {
        expect(state.newestWireSyncedAt(pkA), isNull);
      });

      test('recordWireSeen persists the wire stamp', () async {
        await state.recordWireSeen(pkA, createdAt: tsMid);

        expect(state.newestWireSyncedAt(pkA), equals(tsMid));
      });

      test(
        'recordWireSeen advances monotonically — an older wire stamp does '
        'not roll the boundary back',
        () async {
          await state.recordWireSeen(pkA, createdAt: tsNewer);
          await state.recordWireSeen(pkA, createdAt: tsMid);

          expect(state.newestWireSyncedAt(pkA), equals(tsNewer));
        },
      );

      test(
        'the wire boundary is independent of the rumor boundary, so a '
        'backdated wrap cannot advance `since:` past its own stamp',
        () async {
          // One NIP-17 message: the rumor carries the honest send time, the
          // outer wrap is backdated ~1 day per NIP-17. Recording only the
          // rumor clock is what left `since:` a day ahead of the stamp the
          // relay filters. See #8209.
          const rumorAt = tsNewest;
          const wireAt = tsNewest - 86400;

          await state.recordSeen(pkA, createdAt: rumorAt);
          await state.recordWireSeen(pkA, createdAt: wireAt);

          expect(state.newestSyncedAt(pkA), equals(rumorAt));
          expect(state.newestWireSyncedAt(pkA), equals(wireAt));
        },
      );

      test('recordWireSeen is scoped per pubkey', () async {
        await state.recordWireSeen(pkA, createdAt: tsMid);

        expect(state.newestWireSyncedAt(pkB), isNull);
      });

      test(
        'recordWireSeen clamps a future wire stamp to now — an ephemeral '
        'key signs its own stamp, so the signature does not make it honest',
        () async {
          await state.recordWireSeen(pkA, createdAt: year2100);

          final stored = state.newestWireSyncedAt(pkA);
          expect(stored, isNotNull);
          expect(stored, lessThan(year2100));
          expect(stored, closeTo(nowSec(), 5));
        },
      );

      test(
        'recordWireSeen floors an implausibly old wire stamp',
        () async {
          await state.recordWireSeen(pkA, createdAt: 1);

          expect(
            state.newestWireSyncedAt(pkA),
            equals(DmSyncState.minPlausibleCreatedAt),
          );
        },
      );

      test(
        'repairPoisonedBoundaries heals a wire boundary poisoned by a build '
        'without the clamp, and re-arms the drain',
        () async {
          await prefs.setInt('dm.newestWireSyncedAt.$pkA', year2100);
          await state.markHistoryDrainComplete(pkA);
          expect(state.historyDrainComplete(pkA), isTrue);

          await state.repairPoisonedBoundaries(pkA);

          expect(state.newestWireSyncedAt(pkA), closeTo(nowSec(), 5));
          expect(state.historyDrainComplete(pkA), isFalse);
        },
      );

      test(
        'repairPoisonedBoundaries leaves a healthy wire boundary alone',
        () async {
          final honest = nowSec() - 3600;
          await state.recordWireSeen(pkA, createdAt: honest);
          await state.markHistoryDrainComplete(pkA);

          await state.repairPoisonedBoundaries(pkA);

          expect(state.newestWireSyncedAt(pkA), equals(honest));
          expect(state.historyDrainComplete(pkA), isTrue);
        },
      );

      test('clear removes the wire boundary for that pubkey only', () async {
        await state.recordWireSeen(pkA, createdAt: tsMid);
        await state.recordWireSeen(pkB, createdAt: tsNewer);

        await state.clear(pkA);

        expect(state.newestWireSyncedAt(pkA), isNull);
        expect(state.newestWireSyncedAt(pkB), equals(tsNewer));
      });

      test('clearAll removes the wire boundary for every pubkey', () async {
        await state.recordWireSeen(pkA, createdAt: tsMid);
        await state.recordWireSeen(pkB, createdAt: tsNewer);

        await state.clearAll();

        expect(state.newestWireSyncedAt(pkA), isNull);
        expect(state.newestWireSyncedAt(pkB), isNull);
      });
    });
    group('silent-holdout run counting', () {
      test('starts at zero', () {
        expect(state.drainSilentHoldoutRuns(pkA), 0);
        expect(state.drainSilentHoldoutRelays(pkA), isEmpty);
      });

      test('accumulates while the same relay stays silent', () async {
        expect(
          await state.recordDrainSilentHoldoutRun(
            pkA,
            holdouts: const ['wss://a'],
          ),
          1,
        );
        expect(
          await state.recordDrainSilentHoldoutRun(
            pkA,
            holdouts: const ['wss://a'],
          ),
          2,
        );
        expect(state.drainSilentHoldoutRuns(pkA), 2);
      });

      test('ignores the order the relays are reported in', () async {
        await state.recordDrainSilentHoldoutRun(
          pkA,
          holdouts: const ['wss://a', 'wss://b'],
        );
        expect(
          await state.recordDrainSilentHoldoutRun(
            pkA,
            holdouts: const ['wss://b', 'wss://a'],
          ),
          2,
        );
      });

      test(
        'restarts when a different relay is the holdout, so a rotating cast '
        'never accumulates toward the budget',
        () async {
          await state.recordDrainSilentHoldoutRun(
            pkA,
            holdouts: const ['wss://a'],
          );
          await state.recordDrainSilentHoldoutRun(
            pkA,
            holdouts: const ['wss://a'],
          );

          expect(
            await state.recordDrainSilentHoldoutRun(
              pkA,
              holdouts: const ['wss://b'],
            ),
            1,
            reason: 'run 2 said nothing about the window wss://b held',
          );
          expect(state.drainSilentHoldoutRelays(pkA), const ['wss://b']);
        },
      );

      test('restarts when the holdout set grows', () async {
        await state.recordDrainSilentHoldoutRun(
          pkA,
          holdouts: const ['wss://a'],
        );
        expect(
          await state.recordDrainSilentHoldoutRun(
            pkA,
            holdouts: const ['wss://a', 'wss://b'],
          ),
          1,
        );
      });

      test('is scoped per pubkey', () async {
        await state.recordDrainSilentHoldoutRun(
          pkA,
          holdouts: const ['wss://a'],
        );
        expect(state.drainSilentHoldoutRuns(pkB), 0);
      });

      test('clear resets both the count and the recorded set', () async {
        await state.recordDrainSilentHoldoutRun(
          pkA,
          holdouts: const ['wss://a'],
        );
        await state.clearDrainSilentHoldoutRuns(pkA);

        expect(state.drainSilentHoldoutRuns(pkA), 0);
        expect(state.drainSilentHoldoutRelays(pkA), isEmpty);
      });

      test('markHistoryDrainComplete clears the count', () async {
        await state.recordDrainSilentHoldoutRun(
          pkA,
          holdouts: const ['wss://a'],
        );
        await state.markHistoryDrainComplete(pkA);

        expect(state.drainSilentHoldoutRuns(pkA), 0);
      });
    });

    group('quorum completion record', () {
      test('round-trips the excluded relays and the held window', () async {
        await state.recordDrainQuorumCompletion(
          pkA,
          holdouts: const ['wss://silent'],
          cursor: tsMid,
        );

        expect(state.drainQuorumHoldouts(pkA), const ['wss://silent']);
        expect(state.drainQuorumCursor(pkA), tsMid);
      });

      test(
        'rearmDrainFromCursor clears the latch and seeds the window',
        () async {
          await state.markHistoryDrainComplete(pkA);
          expect(state.historyDrainComplete(pkA), isTrue);

          await state.rearmDrainFromCursor(pkA, tsMid);

          expect(state.historyDrainComplete(pkA), isFalse);
          expect(state.historyDrainCursor(pkA), tsMid);
        },
      );

      test('clear removes the record', () async {
        await state.recordDrainQuorumCompletion(
          pkA,
          holdouts: const ['wss://silent'],
          cursor: tsMid,
        );
        await state.clearDrainQuorumCompletion(pkA);

        expect(state.drainQuorumHoldouts(pkA), isEmpty);
        expect(state.drainQuorumCursor(pkA), isNull);
      });
    });

    group('account-boundary cleanup', () {
      test('clear removes every drain key this account owns', () async {
        await state.recordDrainSilentHoldoutRun(
          pkA,
          holdouts: const ['wss://a'],
        );
        await state.recordDrainQuorumCompletion(
          pkA,
          holdouts: const ['wss://a'],
          cursor: tsMid,
        );

        await state.clear(pkA);

        expect(state.drainSilentHoldoutRuns(pkA), 0);
        expect(state.drainSilentHoldoutRelays(pkA), isEmpty);
        expect(state.drainQuorumHoldouts(pkA), isEmpty);
        expect(state.drainQuorumCursor(pkA), isNull);
      });

      test('clearAll removes them for every account', () async {
        await state.recordDrainSilentHoldoutRun(
          pkA,
          holdouts: const ['wss://a'],
        );
        await state.recordDrainQuorumCompletion(
          pkB,
          holdouts: const ['wss://b'],
          cursor: tsMid,
        );

        await state.clearAll();

        expect(state.drainSilentHoldoutRuns(pkA), 0);
        expect(state.drainQuorumHoldouts(pkB), isEmpty);
      });
    });
  });
}
