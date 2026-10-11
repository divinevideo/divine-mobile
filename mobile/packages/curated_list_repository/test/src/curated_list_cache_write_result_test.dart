import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  final owner = 'a' * 64;
  CuratedList list(String id, {int revision = 1}) => CuratedList(
    id: id,
    name: id,
    pubkey: owner,
    videoEventIds: const [],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026).add(Duration(seconds: revision)),
  );

  group('write result reconciliation', () {
    test('rejected write restores the acknowledged external winner', () {
      final original = list('crew');
      final attempted = list('crew', revision: 2);
      final winner = list('crew', revision: 3);
      final unrelated = list('other');
      final result = CuratedCacheWriteResult<List<CuratedList>>(
        status: CuratedCacheWriteStatus.storageRejected,
        baseline: [original],
        requested: [attempted],
        acknowledgedBeforeWrite: [winner],
      );
      expect(result.persisted, isNull);
      expect(result.succeeded, isFalse);
      expect(result.reconcile([attempted, unrelated]), [winner, unrelated]);
      expect(result.nextBaseline, [original]);
    });

    test('rejected write cannot restore a row from a cleared key', () {
      final original = list('crew');
      final attempted = list('crew', revision: 2);
      final result = CuratedCacheWriteResult<List<CuratedList>>(
        status: CuratedCacheWriteStatus.storageRejected,
        baseline: [original],
        requested: [attempted],
        acknowledgedBeforeWrite: const [],
      );
      expect(result.reconcile([attempted]), isEmpty);
      expect(result.persisted, isNull);
    });

    test(
      'rejected follow removal preserves an acknowledged external follow',
      () {
        const result = CuratedCacheWriteResult<Set<String>>(
          status: CuratedCacheWriteStatus.storageRejected,
          baseline: {'follow'},
          requested: {},
          acknowledgedBeforeWrite: {'follow', 'external'},
        );
        expect(result.persisted, isNull);
        expect(result.reconcile({'unrelated'}), {'follow', 'unrelated'});
      },
    );

    test('failed lists restore only unchanged attempted coordinates', () {
      final original = list('crew');
      final edit = list('crew', revision: 2);
      final newer = list('crew', revision: 3);
      final added = list('added');
      final deleted = list('deleted');
      final unrelated = list('other');
      final result = CuratedCacheWriteResult<List<CuratedList>>(
        status: CuratedCacheWriteStatus.storageRejected,
        baseline: [original, deleted],
        requested: [edit, added],
      );
      expect(result.succeeded, isFalse);
      expect(result.reconcile([edit, added, unrelated]), [
        original,
        unrelated,
        deleted,
      ]);
      expect(result.reconcile([newer, unrelated]), [newer, unrelated, deleted]);
      expect(result.nextBaseline, [original, deleted]);
      expect(() => result.reconcile([edit]).clear(), throwsUnsupportedError);
    });

    test(
      'partial conflict reconciles the winner but retains its old baseline',
      () {
        final original = list('crew');
        final stale = list('crew', revision: 2);
        final winner = list('crew', revision: 5);
        final removed = list('removed');
        final added = list('added');
        final external = list('external');
        final result = CuratedCacheWriteResult<List<CuratedList>>(
          status: CuratedCacheWriteStatus.conflict,
          baseline: [original, removed],
          requested: [stale, added],
          persisted: [winner, added, external],
          conflictedIds: {original.authorScopedId},
        );
        expect(result.reconcile([stale, added]), [winner, added]);
        expect(result.nextBaseline, [original, added]);
      },
    );

    test('accepted deletion and addition advance only local records', () {
      final removed = list('removed');
      final added = list('added');
      final external = list('external');
      final result = CuratedCacheWriteResult<List<CuratedList>>(
        status: CuratedCacheWriteStatus.saved,
        baseline: [removed],
        requested: [added],
        persisted: [added, external],
      );
      expect(result.succeeded, isTrue);
      expect(result.reconcile([added]), [added]);
      expect(result.nextBaseline, [added]);
    });

    test(
      'subscription rollback preserves unrelated and already changed IDs',
      () {
        const result = CuratedCacheWriteResult<Set<String>>(
          status: CuratedCacheWriteStatus.storageRejected,
          baseline: {'kept', 'removed'},
          requested: {'kept', 'added'},
        );
        expect(result.reconcile({'kept', 'added', 'external'}), {
          'kept',
          'removed',
          'external',
        });
        expect(result.reconcile({'kept', 'removed', 'external'}), {
          'kept',
          'removed',
          'external',
        });
        expect(() => result.reconcile({}).clear(), throwsUnsupportedError);
      },
    );

    test(
      'subscription confirmation uses the actual merged persisted values',
      () {
        const result = CuratedCacheWriteResult<Set<String>>(
          status: CuratedCacheWriteStatus.saved,
          baseline: {'removed'},
          requested: {'added'},
          persisted: {'added', 'external'},
        );
        expect(result.reconcile({'added', 'local'}), {'added', 'local'});
      },
    );

    test('lists keep a change another writer made to an untouched row', () {
      final kept = list('kept');
      final keptElsewhere = list('kept', revision: 4);
      final added = list('added');
      final addedWinner = list('added', revision: 5);
      final result = CuratedCacheWriteResult<List<CuratedList>>(
        status: CuratedCacheWriteStatus.conflict,
        baseline: [kept],
        requested: [kept, added],
        persisted: [keptElsewhere, addedWinner],
        conflictedIds: {added.authorScopedId},
      );
      expect(result.reconcile([kept, added]), [kept, addedWinner]);
    });

    test('follows keep a change another writer made to an untouched id', () {
      const result = CuratedCacheWriteResult<Set<String>>(
        status: CuratedCacheWriteStatus.storageRejected,
        baseline: {'kept'},
        requested: {'kept', 'added'},
        acknowledgedBeforeWrite: {},
      );
      expect(result.reconcile({'kept', 'added'}), {'kept'});
    });

    test('a saved follow removal leaves a follow added since', () {
      const result = CuratedCacheWriteResult<Set<String>>(
        status: CuratedCacheWriteStatus.saved,
        baseline: {'followed'},
        requested: {},
        persisted: {},
      );
      expect(result.reconcile({'followed'}), {'followed'});
    });

    test('a rejected follow removal does not restore another removal', () {
      const result = CuratedCacheWriteResult<Set<String>>(
        status: CuratedCacheWriteStatus.storageRejected,
        baseline: {'followed'},
        requested: {},
        acknowledgedBeforeWrite: {},
      );
      expect(result.reconcile({}), isEmpty);
    });

    test('queued list deltas exclude a preceding rejected edit', () {
      final original = list('crew');
      final rejected = list('crew', revision: 2);
      final removed = list('removed');
      final added = list('added');
      expect(
        CuratedCacheWriteSnapshots.rebaseLists(
          [original, removed],
          [rejected, removed],
          [rejected, added],
        ),
        [original, added],
      );
      expect(
        CuratedCacheWriteSnapshots.rebaseLists(
          [original],
          [rejected],
          [rejected],
        ),
        [original],
      );
    });

    test('queued subscription deltas exclude preceding rejected follows', () {
      expect(
        CuratedCacheWriteSnapshots.rebaseSubscriptions(
          {'original', 'removed'},
          {'rejected', 'removed'},
          {'rejected', 'added'},
        ),
        {'original', 'added'},
      );
    });

    test('typed error contains an outcome without private cache contents', () {
      for (final status in CuratedCacheWriteStatus.values) {
        final error = CuratedCacheWriteException(status);
        expect(error.status, status);
        expect(error.toString(), 'Curated cache write: ${status.name}');
      }
    });
  });
}
