// ABOUTME: Checks operation ordering, author changes, and queue recovery.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:test/test.dart';

void main() {
  group('CuratedListMutationQueue.run', () {
    final a = 'a' * 64;
    final b = 'b' * 64;

    test('queued mutations wait and cancel when the account changes', () async {
      var owner = a;
      final queue = CuratedListMutationQueue();
      final blocked = Completer<bool>();
      final started = Completer<void>();
      final first = queue.run(
        'list',
        () {
          started.complete();
          return blocked.future;
        },
        currentOwner: () => owner,
        cancelled: false,
      );
      await started.future;
      var called = false;
      final second = queue.run(
        'list',
        () async {
          called = true;
          return true;
        },
        currentOwner: () => owner,
        cancelled: false,
      );
      owner = b;
      expect(
        await queue.run(
          'list',
          () async => true,
          currentOwner: () => owner,
          cancelled: false,
        ),
        isTrue,
      );
      blocked.complete(true);
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(called, isFalse);
    });

    test(
      'a failed operation releases its lane and leaves other authors free',
      () async {
        final queue = CuratedListMutationQueue();
        await expectLater(
          queue.run<bool>(
            'list',
            () async => throw StateError('failed'),
            currentOwner: () => a,
            cancelled: false,
          ),
          throwsStateError,
        );
        expect(
          await queue.run(
            'list',
            () async => true,
            currentOwner: () => a,
            cancelled: false,
          ),
          isTrue,
        );
      },
    );
  });
}
