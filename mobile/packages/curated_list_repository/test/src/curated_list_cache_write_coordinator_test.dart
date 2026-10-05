import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('CuratedListCacheWriteCoordinator', () {
    final author = 'a' * 64;
    final other = 'b' * 64;
    CuratedList list(String? owner, {int revision = 1, String name = 'List'}) =>
        CuratedList(
          id: 'same:d-tag',
          name: name,
          pubkey: owner,
          videoEventIds: const [],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026).add(Duration(seconds: revision)),
        );

    test('exclusive cleanup drains an already dispatched cache save', () async {
      final writer = CuratedListCacheWriteCoordinator();
      final started = Completer<void>();
      final release = Completer<void>();
      var stored = [list(author)];
      final saving = writer.saveLists(
        baseline: stored,
        current: [list(author, revision: 2)],
        read: () => stored,
        write: (value) async {
          started.complete();
          await release.future;
          stored = value;
          return true;
        },
      );
      await started.future;
      final clearing = writer.runExclusive(() async {
        stored = [];
        return 'cleared';
      });
      release.complete();
      expect(await saving, isTrue);
      expect(await clearing, 'cleared');
      expect(stored, isEmpty);
    });

    test('an invalid read cannot discard a later repaired row', () async {
      final writer = CuratedListCacheWriteCoordinator();
      final repaired = list(author);
      final added = list(other);
      var reads = 0;
      var writes = 0;
      var preflights = 0;
      final refused = await writer.saveListsWithResult(
        baseline: [],
        current: [repaired],
        cacheKey: 'lists',
        read: () {
          reads++;
          return [];
        },
        isReadValid: () => false,
        preflightConflicts: (_) {
          preflights++;
          return {};
        },
        write: (_) async {
          writes++;
          return false;
        },
      );

      expect(refused.status, CuratedCacheWriteStatus.storageRejected);
      expect(refused.baseline, isEmpty);
      expect(refused.persisted, isNull);
      expect(refused.acknowledgedBeforeWrite, isNull);
      expect(refused.nextBaseline, isEmpty);
      expect(refused.reconcile([repaired]), isEmpty);
      expect(reads, 1);
      expect(writes, 0);
      expect(preflights, 0);

      var stored = [repaired];
      final retry = await writer.saveListsWithResult(
        baseline: [repaired],
        current: [repaired, added],
        cacheKey: 'lists',
        read: () => stored,
        isReadValid: () => true,
        write: (merged) async {
          stored = merged;
          return true;
        },
      );
      expect(retry.succeeded, isTrue);
      expect(stored, [repaired, added]);
    });

    test('an invalid read retains an existing rejected overlay', () async {
      final writer = CuratedListCacheWriteCoordinator();
      final original = list(author);
      final refusedEdit = list(author, name: 'Rejected edit');
      final added = list(other);
      var stored = [original];
      final rejected = await writer.saveListsWithResult(
        baseline: [original],
        current: [refusedEdit],
        cacheKey: 'lists',
        read: () => stored,
        write: (merged) async {
          stored = merged;
          return false;
        },
      );
      expect(rejected.status, CuratedCacheWriteStatus.storageRejected);
      expect(stored, [refusedEdit]);

      var writes = 0;
      final invalid = await writer.saveListsWithResult(
        baseline: [],
        current: [],
        cacheKey: 'lists',
        read: () => [],
        isReadValid: () => false,
        write: (_) async {
          writes++;
          return true;
        },
      );
      expect(invalid.status, CuratedCacheWriteStatus.storageRejected);
      expect(invalid.acknowledgedBeforeWrite, isNull);
      expect(writes, 0);

      final next = await writer.saveListsWithResult(
        baseline: [original],
        current: [original, added],
        cacheKey: 'lists',
        read: () => stored,
        write: (merged) async {
          stored = merged;
          return true;
        },
      );
      expect(next.succeeded, isTrue);
      expect(stored, [original, added]);
    });

    test(
      'list preflight reads distinguish rejection from replacement',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final original = list(author);
        final attempted = list(author, name: 'Rejected edit');
        final replacement = list(other);
        var stored = [original];
        final rejected = await writer.saveListsWithResult(
          baseline: [original],
          current: [attempted],
          cacheKey: 'lists',
          read: () => stored,
          write: (merged) async {
            stored = merged;
            return false;
          },
        );
        expect(rejected.status, CuratedCacheWriteStatus.storageRejected);
        expect(stored, [attempted]);
        expect(
          writer.readAcknowledgedLists(cacheKey: 'lists', read: () => stored),
          [original],
        );

        stored = [replacement];
        expect(
          writer.readAcknowledgedLists(cacheKey: 'lists', read: () => stored),
          [replacement],
        );
        stored = [attempted];
        expect(
          writer.readAcknowledgedLists(cacheKey: 'lists', read: () => stored),
          [attempted],
        );
      },
    );

    test('read validation waits for the preceding writer', () async {
      final writer = CuratedListCacheWriteCoordinator();
      final original = list(author);
      final started = Completer<void>();
      final release = Completer<void>();
      var stored = <CuratedList>[];
      final previous = writer.saveListsWithResult(
        baseline: [],
        current: [original],
        read: () => stored,
        write: (merged) async {
          started.complete();
          await release.future;
          stored = merged;
          return true;
        },
      );
      await started.future;
      var readable = true;
      var reads = 0;
      var validations = 0;
      var writes = 0;
      final pending = writer.saveListsWithResult(
        baseline: [],
        current: [list(other)],
        read: () {
          reads++;
          return stored;
        },
        isReadValid: () {
          validations++;
          return readable;
        },
        write: (_) async {
          writes++;
          return true;
        },
      );
      expect(reads, 0);
      expect(validations, 0);
      readable = false;
      release.complete();
      expect((await previous).succeeded, isTrue);
      expect((await pending).status, CuratedCacheWriteStatus.storageRejected);
      expect(reads, 1);
      expect(validations, 1);
      expect(writes, 0);
      expect(stored, [original]);
    });

    test(
      'preflight conflict aborts before writes '
      'and exposes acknowledged rows for reconciliation',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final local = list(null);
        final owned = list(author, revision: 0, name: 'Acknowledged owner');
        final claimed = local.copyWith(pubkey: author, name: 'Claimed');
        var writes = 0;
        final result = await writer.saveListsWithResult(
          baseline: [local],
          current: [claimed],
          read: () => [local, owned],
          preflightConflicts: (acknowledged) => {
            if (acknowledged.any(
              (row) => row.authorScopedId == claimed.authorScopedId,
            ))
              claimed.authorScopedId,
          },
          write: (_) async {
            writes++;
            return true;
          },
        );
        expect(result.status, CuratedCacheWriteStatus.conflict);
        expect(result.persisted, isNull);
        expect(result.acknowledgedBeforeWrite, [local, owned]);
        expect(result.nextBaseline, [local]);
        expect(result.reconcile([claimed]), [owned, local]);
        expect(writes, 0);
      },
    );

    test(
      'preflight sees a preceding writer only after its acknowledgement',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final local = list(null);
        final owned = list(author, revision: 0);
        final claimed = local.copyWith(pubkey: author);
        var stored = [local];
        final started = Completer<void>();
        final release = Completer<void>();
        final previous = writer.saveListsWithResult(
          baseline: [local],
          current: [local, owned],
          read: () => stored,
          write: (rows) async {
            started.complete();
            await release.future;
            stored = rows;
            return true;
          },
        );
        await started.future;
        var preflights = 0;
        var claimWrites = 0;
        final pending = writer.saveListsWithResult(
          baseline: [local],
          current: [claimed],
          read: () => stored,
          preflightConflicts: (acknowledged) {
            preflights++;
            expect(acknowledged, [local, owned]);
            return {claimed.authorScopedId};
          },
          write: (_) async {
            claimWrites++;
            return true;
          },
        );
        expect(preflights, 0);
        release.complete();
        expect((await previous).succeeded, isTrue);
        expect((await pending).status, CuratedCacheWriteStatus.conflict);
        expect(preflights, 1);
        expect(claimWrites, 0);
        expect(stored, [local, owned]);
      },
    );

    test(
      'a late account snapshot preserves another account additions and edits',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final original = list(author);
        final otherList = list(other, name: 'New account');
        var stored = [original, otherList];
        final updated = list(author, revision: 2, name: 'Late accepted');
        expect(
          await writer.saveLists(
            baseline: [original],
            current: [updated],
            read: () => stored,
            write: (value) async {
              stored = value;
              return true;
            },
          ),
          isTrue,
        );
        expect(stored, [updated, otherList]);
        final editedOther = list(other, revision: 3, name: 'Edited account');
        await writer.saveLists(
          baseline: [original, otherList],
          current: [original, editedOther],
          read: () => stored,
          write: (value) async {
            stored = value;
            return true;
          },
        );
        expect(stored, [updated, editedOther]);
      },
    );

    test(
      'overlapping snapshots accept an identical row already written',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        CuratedList owned(String id) => CuratedList(
          id: id,
          name: id,
          pubkey: author,
          videoEventIds: const [],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final initial = [owned('first'), owned('second')];
        final firstAdded = initial[0].copyWith(
          videoEventIds: ['c' * 64],
          updatedAt: DateTime.utc(2026).add(const Duration(seconds: 1)),
        );
        final secondAdded = initial[1].copyWith(
          videoEventIds: ['c' * 64],
          updatedAt: DateTime.utc(2026).add(const Duration(seconds: 1)),
        );
        var stored = initial;
        final firstWritten = Completer<void>();
        final finishFirst = Completer<void>();
        final first = writer.saveLists(
          baseline: initial,
          current: [firstAdded, initial[1]],
          read: () => stored,
          write: (value) async {
            stored = value;
            firstWritten.complete();
            await finishFirst.future;
            return true;
          },
        );
        await firstWritten.future;
        final second = writer.saveLists(
          baseline: initial,
          current: [firstAdded, secondAdded],
          read: () => stored,
          write: (value) async {
            stored = value;
            return true;
          },
        );
        finishFirst.complete();
        expect(await Future.wait([first, second]), [true, true]);
        expect(stored, [firstAdded, secondAdded]);
      },
    );

    test(
      'a late older revision and stale deletion preserve the newest coordinate',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final original = list(author);
        final newest = list(author, revision: 5, name: 'New permissions');
        var stored = [newest];
        Future<bool> save(List<CuratedList> current) => writer.saveLists(
          baseline: [original],
          current: current,
          read: () => stored,
          write: (value) async {
            stored = value;
            return true;
          },
        );
        expect(await save([list(author, revision: 2)]), isFalse);
        expect(stored, [newest]);
        expect(await save([list(author, revision: 5)]), isFalse);
        expect(stored, [newest]);
        expect(await save([]), isFalse);
        expect(stored, [newest]);
      },
    );

    test(
      'local metadata based on the current source can have an earlier '
      'wall clock',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final source = list(author, revision: 5);
        final metadata = list(author, name: 'Pending local edit');
        var stored = [source];
        await writer.saveLists(
          baseline: [source],
          current: [metadata],
          read: () => stored,
          write: (value) async {
            stored = value;
            return true;
          },
        );
        expect(stored, [metadata]);
      },
    );

    test(
      'deletion and assigning a legacy owner affect only changed coordinates',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final unpublished = list(null);
        final otherList = list(other);
        var stored = [unpublished, otherList];
        await writer.saveLists(
          baseline: [unpublished],
          current: [list(author)],
          read: () => stored,
          write: (value) async {
            stored = value;
            return true;
          },
        );
        expect(stored, [otherList, list(author)]);
      },
    );

    test(
      'a save leaves rows it did not change to the writers that did',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final untouched = list(author);
        final removedElsewhere = list(other);
        final added = untouched.copyWith(id: 'added:d-tag');
        final editedElsewhere = list(author, revision: 2, name: 'Edited');
        var stored = [editedElsewhere];
        final result = await writer.saveListsWithResult(
          baseline: [untouched, removedElsewhere],
          current: [untouched, removedElsewhere, added],
          read: () => stored,
          write: (value) async {
            stored = value;
            return true;
          },
        );
        expect(result.status, CuratedCacheWriteStatus.saved);
        expect(stored, [editedElsewhere, added]);
      },
    );

    test(
      'subscription deltas preserve additions outside the local snapshot',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        var stored = {'author:old', 'other:new'};
        await writer.saveSubscriptions(
          baseline: {'author:old'},
          current: {'author:new'},
          read: () => stored,
          write: (value) async {
            stored = value;
            return true;
          },
        );
        expect(stored, {'other:new', 'author:new'});
      },
    );

    test(
      'subscription deltas do not restore follows another writer removed',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        var stored = {'author:kept'};
        final saved = await writer.saveSubscriptions(
          baseline: {'author:kept', 'author:removed'},
          current: {'author:kept', 'author:removed', 'author:new'},
          read: () => stored,
          write: (value) async {
            stored = value;
            return true;
          },
        );
        expect(saved, isTrue);
        expect(stored, {'author:kept', 'author:new'});
      },
    );

    test(
      'read and write stay serialized, failures release the next writer',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final gate = Completer<bool>();
        final read = <String>[];
        final first = writer.saveSubscriptions(
          baseline: {},
          current: {'first'},
          read: () {
            read.add('first');
            return {};
          },
          write: (_) => gate.future,
        );
        final failed = expectLater(first, throwsStateError);
        final next = writer.saveSubscriptions(
          baseline: {},
          current: {'second'},
          read: () {
            read.add('second');
            return {};
          },
          write: (_) async => false,
        );
        await Future<void>.value();
        expect(read, ['first']);
        gate.completeError(StateError('write refused'));
        await failed;
        expect(await next, isFalse);
        expect(read, ['first', 'second']);
      },
    );

    test(
      'unreadable storage is preserved and does not poison later writes',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        var writes = 0;
        await expectLater(
          writer.saveLists(
            baseline: [],
            current: [list(author)],
            read: () => throw const FormatException('invalid cached rows'),
            write: (_) async {
              writes++;
              return true;
            },
          ),
          throwsFormatException,
        );
        expect(writes, 0);
        expect(
          await writer.saveLists(
            baseline: [],
            current: [list(author)],
            read: () => [],
            write: (_) async => true,
          ),
          isTrue,
        );
      },
    );
    group('typed outcomes and optimistic cache', () {
      test(
        'a removed key invalidates a rejected empty cache overlay',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          final original = list(author);
          final replacement = list(other);
          var stored = [original];
          var follows = <String>{'old'};
          await writer.saveListsWithResult(
            baseline: [original],
            current: [],
            cacheKey: 'lists',
            read: () => stored,
            write: (merged) async {
              stored = merged;
              return false;
            },
          );
          await writer.saveSubscriptionsWithResult(
            baseline: {'old'},
            current: {},
            cacheKey: 'follows',
            read: () => follows,
            write: (merged) async {
              follows = merged;
              return false;
            },
          );
          writer
            ..cacheKeyRemoved('lists')
            ..cacheKeyRemoved('follows');
          final saved = await writer.saveListsWithResult(
            baseline: [],
            current: [replacement],
            cacheKey: 'lists',
            read: () => stored,
            write: (merged) async {
              stored = merged;
              return true;
            },
          );
          expect(saved.persisted, [replacement]);
          expect(
            writer.readAcknowledgedSubscriptions(
              cacheKey: 'follows',
              read: () => follows,
            ),
            isEmpty,
          );
        },
      );

      test(
        'rejected merge retains the confirmed external winner '
        'for reconciliation',
        () async {
          final original = list(author);
          final attempted = list(author, revision: 2);
          final winner = list(author, revision: 3);
          final writer = CuratedListCacheWriteCoordinator();
          var stored = [winner];
          final result = await writer.saveListsWithResult(
            baseline: [original],
            current: [attempted],
            cacheKey: 'lists',
            read: () => stored,
            write: (merged) async {
              stored = merged;
              return false;
            },
          );
          expect(result.status, CuratedCacheWriteStatus.storageRejected);
          expect(result.persisted, isNull);
          expect(result.acknowledgedBeforeWrite, [winner]);
          expect(result.reconcile([attempted]), [winner]);
          final newerEdit = list(author, revision: 4);
          final subsequent = await writer.saveListsWithResult(
            baseline: result.nextBaseline,
            current: [newerEdit],
            cacheKey: 'lists',
            read: () => stored,
            write: (merged) async {
              stored = merged;
              return true;
            },
          );
          expect(subsequent.succeeded, isTrue);
          expect(stored, [newerEdit]);
        },
      );

      test(
        'reports a real version conflict with the confirmed merged winner',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          final original = list(author);
          final winner = list(author, revision: 5);
          final stale = list(author, revision: 2);
          final result = await writer.saveListsWithResult(
            baseline: [original],
            current: [stale],
            read: () => [winner],
            write: (_) async => true,
          );
          expect(result.status, CuratedCacheWriteStatus.conflict);
          expect(result.persisted, [winner]);
          expect(result.conflictedIds, {original.authorScopedId});
        },
      );

      test(
        'a refused optimistic list write is not flushed by another delta',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          var stored = <CuratedList>[];
          final rejected = list(author);
          final accepted = list(other);
          final failed = await writer.saveListsWithResult(
            baseline: [],
            current: [rejected],
            cacheKey: 'lists',
            read: () => stored,
            write: (value) async {
              stored = value;
              return false;
            },
          );
          expect(failed.status, CuratedCacheWriteStatus.storageRejected);
          expect(failed.persisted, isNull);
          await writer.saveListsWithResult(
            baseline: [],
            current: [accepted],
            cacheKey: 'lists',
            read: () => stored,
            write: (value) async {
              stored = value;
              return true;
            },
          );
          expect(stored, [accepted]);
        },
      );

      test(
        'a retry that is saved forgets the refused list snapshot',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          final original = list(author);
          final edited = list(author, revision: 2, name: 'Edited');
          final added = list(other);
          var stored = [original];
          var accept = false;
          Future<CuratedCacheWriteResult<List<CuratedList>>> save(
            List<CuratedList> baseline,
            List<CuratedList> current,
          ) => writer.saveListsWithResult(
            baseline: baseline,
            current: current,
            cacheKey: 'lists',
            read: () => stored,
            write: (value) async {
              stored = value;
              return accept;
            },
          );
          final refused = await save([original], [edited]);
          expect(refused.status, CuratedCacheWriteStatus.storageRejected);
          accept = true;
          final retried = await save([original], [edited]);
          expect(retried.status, CuratedCacheWriteStatus.saved);
          final next = await save([edited], [edited, added]);
          expect(next.status, CuratedCacheWriteStatus.saved);
          expect(stored, [edited, added]);
        },
      );

      test(
        'a retry that is saved forgets the refused subscription snapshot',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          var stored = {'old'};
          var accept = false;
          Future<CuratedCacheWriteResult<Set<String>>> save(
            Set<String> baseline,
            Set<String> current,
          ) => writer.saveSubscriptionsWithResult(
            baseline: baseline,
            current: current,
            cacheKey: 'follows',
            read: () => stored,
            write: (value) async {
              stored = value;
              return accept;
            },
          );
          final refused = await save({'old'}, {'old', 'new'});
          expect(refused.status, CuratedCacheWriteStatus.storageRejected);
          expect(refused.acknowledgedBeforeWrite, {'old'});
          accept = true;
          final retried = await save({'old'}, {'old', 'new'});
          expect(retried.status, CuratedCacheWriteStatus.saved);
          final next = await save({'old', 'new'}, {'old', 'new', 'later'});
          expect(next.status, CuratedCacheWriteStatus.saved);
          expect(stored, {'old', 'new', 'later'});
        },
      );

      test(
        'a refused list write from a superseded session keeps its snapshot',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          var stored = <CuratedList>[];
          var live = true;
          final refused = list(author);
          final accepted = list(other);
          final superseded = await writer.saveListsWithResult(
            baseline: [],
            current: [refused],
            cacheKey: 'lists',
            isCurrent: () => live,
            read: () => stored,
            write: (value) async {
              stored = value;
              live = false;
              return false;
            },
          );
          expect(superseded.status, CuratedCacheWriteStatus.superseded);
          await writer.saveListsWithResult(
            baseline: [],
            current: [accepted],
            cacheKey: 'lists',
            read: () => stored,
            write: (value) async {
              stored = value;
              return true;
            },
          );
          expect(stored, [accepted]);
        },
      );

      test(
        'a refused follow write from a superseded session keeps its snapshot',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          var stored = <String>{};
          var live = true;
          final superseded = await writer.saveSubscriptionsWithResult(
            baseline: {},
            current: {'refused'},
            cacheKey: 'follows',
            isCurrent: () => live,
            read: () => stored,
            write: (value) async {
              stored = value;
              live = false;
              return false;
            },
          );
          expect(superseded.status, CuratedCacheWriteStatus.superseded);
          await writer.saveSubscriptionsWithResult(
            baseline: {},
            current: {'accepted'},
            cacheKey: 'follows',
            read: () => stored,
            write: (value) async {
              stored = value;
              return true;
            },
          );
          expect(stored, {'accepted'});
        },
      );

      test(
        'changed cached rows supersede the rejected snapshot overlay',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          final rejected = list(author);
          var stored = [rejected];
          await writer.saveListsWithResult(
            baseline: [],
            current: [rejected],
            cacheKey: 'lists',
            read: () => <CuratedList>[],
            write: (value) async {
              stored = value;
              return false;
            },
          );
          final external = list(author, revision: 5);
          stored = [external];
          await writer.saveListsWithResult(
            baseline: [],
            current: [list(other)],
            cacheKey: 'lists',
            read: () => stored,
            write: (value) async {
              stored = value;
              return true;
            },
          );
          expect(stored, [external, list(other)]);
        },
      );

      test(
        'throwing optimistic writes release the queue without leaking rows',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          var stored = <CuratedList>[];
          await expectLater(
            writer.saveListsWithResult(
              baseline: [],
              current: [list(author)],
              cacheKey: 'lists',
              read: () => stored,
              write: (value) async {
                stored = value;
                throw StateError('rejected');
              },
            ),
            throwsStateError,
          );
          await writer.saveListsWithResult(
            baseline: [],
            current: [],
            cacheKey: 'lists',
            read: () => stored,
            write: (value) async {
              stored = value;
              return true;
            },
          );
          expect(stored, isEmpty);
        },
      );

      test(
        'throwing optimistic subscription writes do not become saved follows',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          var stored = <String>{};
          await expectLater(
            writer.saveSubscriptionsWithResult(
              baseline: {},
              current: {'rejected'},
              cacheKey: 'subscriptions',
              read: () => stored,
              write: (value) async {
                stored = value;
                throw StateError('rejected');
              },
            ),
            throwsStateError,
          );
          final retried = await writer.saveSubscriptionsWithResult(
            baseline: {},
            current: {'accepted'},
            cacheKey: 'subscriptions',
            read: () => stored,
            write: (value) async {
              stored = value;
              return true;
            },
          );
          expect(retried.persisted, {'accepted'});
          expect(stored, {'accepted'});
        },
      );

      test(
        'acknowledged set reads reject optimistic values '
        'and accept replacements',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          var stored = <String>{'confirmed'};
          Set<String> acknowledged() => writer.readAcknowledgedSubscriptions(
            cacheKey: 'deletions',
            read: () => stored,
          );
          await writer.saveSubscriptionsWithResult(
            baseline: {'confirmed'},
            current: {'refused'},
            cacheKey: 'deletions',
            read: () => stored,
            write: (value) async {
              stored = value;
              return false;
            },
          );
          expect(stored, {'refused'});
          expect(acknowledged(), {'confirmed'});
          expect(
            writer.readAcknowledgedSubscriptions(
              cacheKey: 'another key',
              read: () => stored,
            ),
            {'refused'},
          );
          stored = {'replacement'};
          expect(acknowledged(), {'replacement'});
          stored = {};
          expect(acknowledged(), isEmpty);
          stored = {'refused'};
          expect(acknowledged(), {'refused'});
        },
      );

      test(
        'refused optimistic subscriptions and replacement snapshots '
        'are distinct',
        () async {
          final writer = CuratedListCacheWriteCoordinator();
          var stored = <String>{};
          Future<CuratedCacheWriteResult<Set<String>>> save(
            Set<String> ids, {
            required bool accepts,
          }) => writer.saveSubscriptionsWithResult(
            baseline: {},
            current: ids,
            cacheKey: 'subscriptions',
            read: () => stored,
            write: (value) async {
              stored = value;
              return accepts;
            },
          );
          expect((await save({'rejected'}, accepts: false)).persisted, isNull);
          expect((await save({'accepted'}, accepts: true)).persisted, {
            'accepted',
          });
          await save({'another rejected'}, accepts: false);
          stored = {'replacement'};
          expect((await save({'replacement'}, accepts: true)).persisted, {
            'replacement',
          });
        },
      );

      for (final lists in [true, false]) {
        test(
          'superseded ${lists ? 'lists' : 'subscriptions'} '
          'are never read or written',
          () async {
            final writer = CuratedListCacheWriteCoordinator();
            if (lists) {
              final result = await writer.saveListsWithResult(
                baseline: [],
                current: [list(author)],
                isCurrent: () => false,
                read: () => throw StateError('must not read'),
                write: (_) async => throw StateError('must not write'),
              );
              expect(result.status, CuratedCacheWriteStatus.superseded);
            } else {
              final result = await writer.saveSubscriptionsWithResult(
                baseline: {},
                current: {'follow'},
                isCurrent: () => false,
                read: () => throw StateError('must not read'),
                write: (_) async => throw StateError('must not write'),
              );
              expect(result.status, CuratedCacheWriteStatus.superseded);
            }
          },
        );

        test(
          'an account replacement during ${lists ? 'list' : 'subscription'} '
          'save is not reported accepted',
          () async {
            final writer = CuratedListCacheWriteCoordinator();
            var active = true;
            if (lists) {
              final result = await writer.saveListsWithResult(
                baseline: [],
                current: [list(author)],
                isCurrent: () => active,
                read: () => [],
                write: (_) async {
                  active = false;
                  return true;
                },
              );
              expect(result.status, CuratedCacheWriteStatus.superseded);
              expect(result.persisted, isNull);
            } else {
              final result = await writer.saveSubscriptionsWithResult(
                baseline: {},
                current: {'follow'},
                isCurrent: () => active,
                read: () => {},
                write: (_) async {
                  active = false;
                  return true;
                },
              );
              expect(result.status, CuratedCacheWriteStatus.superseded);
              expect(result.persisted, isNull);
            }
          },
        );
      }
    });

    group('runExclusive', () {
      test('runs operations in call order and returns their values', () async {
        final writer = CuratedListCacheWriteCoordinator();
        final order = <String>[];
        final firstGate = Completer<void>();

        final first = writer.runExclusive(() async {
          order.add('first:start');
          await firstGate.future;
          order.add('first:end');
          return 1;
        });
        final second = writer.runExclusive(() async {
          order.add('second');
          return 2;
        });
        await pumpEventQueue();
        expect(order, ['first:start']);

        firstGate.complete();
        expect(await first, 1);
        expect(await second, 2);
        expect(order, ['first:start', 'first:end', 'second']);
      });

      test('queues behind a list save already in flight', () async {
        final writer = CuratedListCacheWriteCoordinator();
        final original = list(author);
        final updated = list(author, revision: 2, name: 'Updated');
        final writeGate = Completer<bool>();
        final order = <String>[];

        final save = writer.saveLists(
          baseline: [original],
          current: [updated],
          read: () => [original],
          write: (_) {
            order.add('write');
            return writeGate.future;
          },
        );
        final clear = writer.runExclusive(() async => order.add('clear'));
        await pumpEventQueue();
        expect(order, ['write']);

        writeGate.complete(true);
        await save;
        await clear;
        expect(order, ['write', 'clear']);
      });

      test(
        'a failing operation rethrows and does not block the next one',
        () async {
          final writer = CuratedListCacheWriteCoordinator();

          await expectLater(
            writer.runExclusive<void>(() async => throw StateError('boom')),
            throwsStateError,
          );

          expect(
            await writer.runExclusive(() async => 'recovered'),
            'recovered',
          );
        },
      );
    });
  });
}
