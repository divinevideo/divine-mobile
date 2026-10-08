import 'dart:async';

import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:test/test.dart';

void main() {
  group('FollowedPeopleListsWriteCoordinator', () {
    test(
      'writes serialize per viewer and errors release the next write',
      () async {
        final coordinator = FollowedPeopleListsWriteCoordinator();
        final entered = Completer<void>();
        final release = Completer<void>();
        final events = <String>[];
        final first = coordinator.run<void>(
          viewerPubkey: 'viewer-a',
          operation: () async {
            entered.complete();
            await release.future;
            events.add('first');
            throw StateError('write failed');
          },
        );
        final failure = expectLater(first, throwsStateError);
        await entered.future;
        final second = coordinator.run<void>(
          viewerPubkey: 'viewer-a',
          operation: () async => events.add('second'),
        );
        await coordinator.run<void>(
          viewerPubkey: 'viewer-b',
          operation: () async => events.add('other-viewer'),
        );
        expect(events, ['other-viewer']);
        release.complete();
        await failure;
        await second;
        expect(events, ['other-viewer', 'first', 'second']);
      },
    );

    test('refresh shares a read while any requester remains active', () async {
      final coordinator = FollowedPeopleListsWriteCoordinator();
      final release = Completer<void>();
      var closed = false;
      var queries = 0;
      var applied = false;
      final first = coordinator.refresh(
        viewerPubkey: 'viewer',
        isCancelled: () => closed,
        operation: (isCancelled) async {
          queries++;
          await release.future;
          applied = !isCancelled();
        },
      );
      final second = coordinator.refresh(
        viewerPubkey: 'viewer',
        operation: (_) async => queries++,
      );
      closed = true;
      release.complete();
      await Future.wait([first, second]);
      expect(queries, 1);
      expect(applied, isTrue);
    });

    test(
      'a fully canceled refresh retires without removing a newer job',
      () async {
        final coordinator = FollowedPeopleListsWriteCoordinator();
        final oldRelease = Completer<void>();
        final newRelease = Completer<void>();
        var closed = false;
        var queries = 0;
        var applied = 0;
        final old = coordinator.refresh(
          viewerPubkey: 'viewer',
          isCancelled: () => closed,
          operation: (isCancelled) async {
            queries++;
            await oldRelease.future;
            if (!isCancelled()) applied++;
          },
        );
        closed = true;
        final next = coordinator.refresh(
          viewerPubkey: 'viewer',
          operation: (isCancelled) async {
            queries++;
            await newRelease.future;
            if (!isCancelled()) applied++;
          },
        );
        oldRelease.complete();
        await old;
        final joined = coordinator.refresh(
          viewerPubkey: 'viewer',
          operation: (_) async => queries++,
        );
        newRelease.complete();
        await Future.wait([next, joined]);
        expect(queries, 2);
        expect(applied, 1);
      },
    );

    test(
      'failed refresh releases its job and allows another refresh',
      () async {
        final coordinator = FollowedPeopleListsWriteCoordinator();
        await expectLater(
          coordinator.refresh(
            viewerPubkey: 'viewer',
            operation: (_) async => throw StateError('read failed'),
          ),
          throwsStateError,
        );
        var refreshed = false;
        await coordinator.refresh(
          viewerPubkey: 'viewer',
          operation: (_) async => refreshed = true,
        );
        expect(refreshed, isTrue);
      },
    );
    test(
      'a live joiner retries when the operation client retires later',
      () async {
        final coordinator = FollowedPeopleListsWriteCoordinator();
        const viewer =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final oldRelease = Completer<void>();
        var retired = false;
        var oldApplied = false;
        var liveQueries = 0;
        final old = coordinator.refresh(
          viewerPubkey: viewer,
          isOperationUnavailable: () => retired,
          operation: (isCancelled) async {
            await oldRelease.future;
            oldApplied = !isCancelled();
          },
        );
        final joined = coordinator.refresh(
          viewerPubkey: viewer,
          operation: (_) async => liveQueries++,
        );
        final alsoJoined = coordinator.refresh(
          viewerPubkey: viewer,
          operation: (_) async => liveQueries++,
        );
        retired = true;
        oldRelease.complete();
        await Future.wait([old, joined, alsoJoined]);
        expect(oldApplied, isFalse);
        expect(liveQueries, 1);
      },
    );

    test('a canceled joiner does not retry a retired operation', () async {
      final coordinator = FollowedPeopleListsWriteCoordinator();
      const viewer =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final release = Completer<void>();
      var retired = false;
      var canceled = false;
      var newQueries = 0;
      final old = coordinator.refresh(
        viewerPubkey: viewer,
        isOperationUnavailable: () => retired,
        operation: (_) => release.future,
      );
      final joined = coordinator.refresh(
        viewerPubkey: viewer,
        isCancelled: () => canceled,
        operation: (_) async => newQueries++,
      );
      retired = true;
      canceled = true;
      release.complete();
      await Future.wait([old, joined]);
      expect(newQueries, 0);
    });
  });
}
