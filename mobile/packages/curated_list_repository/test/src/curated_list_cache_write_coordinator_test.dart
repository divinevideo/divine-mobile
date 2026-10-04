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
  });
}
