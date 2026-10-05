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
        'rejected merge retains the confirmed external winner for reconciliation',
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
        'acknowledged set reads reject optimistic values and accept replacements',
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
  });
}
