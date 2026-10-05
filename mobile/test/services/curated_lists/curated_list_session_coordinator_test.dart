// ABOUTME: Verifies disk-write draining and permanent account-session retirement.
// ABOUTME: Exercises queued cancellation, rollback, and inactive account cleanup.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CuratedListSessionCoordinator', () {
    late SharedPreferences prefs;
    late CuratedListSessionCoordinator sessions;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      sessions = CuratedListSessionCoordinator.forPreferences(prefs);
    });

    test('the backing store has one barrier across service containers', () {
      expect(
        CuratedListSessionCoordinator.forPreferences(prefs),
        same(sessions),
      );
    });

    test('the first caller fixes the write queue for the preference store', () {
      final later = CuratedListCacheWriteCoordinator();

      final again = CuratedListSessionCoordinator.forPreferences(
        prefs,
        writes: later,
      );

      expect(again, same(sessions));
      expect(again.writes, same(sessions.writes));
      expect(again.writes, isNot(same(later)));
    });

    test('a separate preference store gets its own write queue', () async {
      SharedPreferences.setMockInitialValues({});
      final otherPrefs = await SharedPreferences.getInstance();
      expect(otherPrefs, isNot(same(prefs)));

      final other = CuratedListSessionCoordinator.forPreferences(otherPrefs);

      expect(other, isNot(same(sessions)));
      expect(other.writes, isNot(same(sessions.writes)));
    });

    test(
      'cleanup drains a dispatched write and cancels queued old writes',
      () async {
        final lease = sessions.acquire();
        final started = Completer<void>();
        final release = Completer<void>();
        final events = <String>[];
        final writing = sessions.runCurrent<bool>(lease, () async {
          started.complete();
          await release.future;
          events.add('old disk write finishes');
          return prefs.setString('curated_lists', 'old private row');
        }, cancelled: false);
        await started.future;
        final queued = sessions.runCurrent<bool>(lease, () async {
          events.add('queued old writer ran');
          return prefs.setString('curated_lists', 'queued old row');
        }, cancelled: false);
        final cleaning = sessions.clearCaches(() async {
          events.add('wipe');
          await prefs.remove('curated_lists');
        });
        expect(lease.isCurrent, isFalse);
        expect(sessions.acquire().isCurrent, isFalse);
        expect(events, isEmpty);
        release.complete();
        expect(await writing, isFalse);
        expect(await queued, isFalse);
        await cleaning;
        expect(events, ['old disk write finishes', 'wipe']);
        expect(prefs.containsKey('curated_lists'), isFalse);
        final incoming = sessions.acquire();
        expect(
          await sessions.runCurrent<bool>(
            incoming,
            () => prefs.setString('curated_lists', 'incoming row'),
            cancelled: false,
          ),
          isTrue,
        );
        expect(prefs.getString('curated_lists'), 'incoming row');
      },
    );

    test(
      'A to B to A never authorizes a captured old A continuation',
      () async {
        final oldA = sessions.acquire();
        await sessions.retireAndDrain();
        final accountB = sessions.acquire();
        await sessions.retireAndDrain();
        final restoredA = sessions.acquire();
        expect(oldA.isCurrent, isFalse);
        expect(accountB.isCurrent, isFalse);
        expect(restoredA.isCurrent, isTrue);
        expect(
          await sessions.runCurrent<bool>(
            oldA,
            () => prefs.setString('curated_lists', 'old ACK'),
            cancelled: false,
          ),
          isFalse,
        );
        expect(
          await sessions.runCurrent<bool>(
            restoredA,
            () => prefs.setString('curated_lists', 'fresh A'),
            cancelled: false,
          ),
          isTrue,
        );
        expect(prefs.getString('curated_lists'), 'fresh A');
      },
    );

    test(
      'failed cleanup opens only new leases instead of reviving old work',
      () async {
        final old = sessions.acquire();
        await expectLater(
          sessions.clearCaches<void>(() async {
            throw StateError('disk unavailable');
          }),
          throwsStateError,
        );
        expect(old.isCurrent, isFalse);
        expect(sessions.acquire().isCurrent, isTrue);
      },
    );

    test(
      'removing an inactive account leaves active list writers usable',
      () async {
        final current = sessions.acquire();
        await UserDataCleanupService(prefs).deleteAccountData(
          'a' * 64,
          userNpub: 'inactive-account',
          preserveActiveSession: true,
        );
        expect(current.isCurrent, isTrue);
        expect(
          await sessions.runCurrent<bool>(
            current,
            () => prefs.setString('curated_lists', 'active rows'),
            cancelled: false,
          ),
          isTrue,
        );
      },
    );

    test('removing the active account retires its list writers', () async {
      final current = sessions.acquire();
      await UserDataCleanupService(prefs).deleteAccountData(
        'a' * 64,
        userNpub: 'active-account',
        preserveActiveSession: false,
      );
      expect(current.isCurrent, isFalse);
    });
  });
}
