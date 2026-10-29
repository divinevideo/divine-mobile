import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/services/notification_activity_session_coordinator.dart';

void main() {
  group(NotificationActivitySessionCoordinator, () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherOwner =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    test(
      'waits for foreground and signer readiness, preserving one session',
      () {
        fakeAsync((async) {
          final sent = <NotificationActivityUpdate>[];
          final coordinator = NotificationActivitySessionCoordinator(
            send: (_, update, _) async => sent.add(update),
          );
          addTearDown(coordinator.dispose);
          coordinator.setAccount(owner: owner, ready: false);
          coordinator.setForeground(true);
          async.flushMicrotasks();
          expect(sent, isEmpty);

          coordinator.setAccount(owner: owner, ready: true);
          async.flushMicrotasks();
          expect(sent.single.state, NotificationActivityState.foreground);
          expect(sent.single.sequence, 1);
          final session = sent.single.sessionId;

          coordinator.setForeground(false);
          async.flushMicrotasks();
          coordinator.setForeground(true);
          async.flushMicrotasks();
          expect(sent.map((update) => update.sequence), [1, 2, 3]);
          expect(sent.map((update) => update.visit), [1, 1, 2]);
          expect(sent.map((update) => update.sessionId).toSet(), {session});
        });
      },
    );

    test('first offline visit catches up after it backgrounds', () {
      fakeAsync((async) {
        final sent = <NotificationActivityUpdate>[];
        final coordinator = NotificationActivitySessionCoordinator(
          send: (_, update, _) async => sent.add(update),
        );
        addTearDown(coordinator.dispose);
        coordinator.setAccount(owner: owner, ready: false);
        coordinator.setForeground(true);
        coordinator.setForeground(false);
        coordinator.setAccount(owner: owner, ready: true);
        async.flushMicrotasks();

        expect(sent, hasLength(1));
        expect(sent.single.state, NotificationActivityState.background);
        expect(sent.single.visit, 1);
        expect(sent.single.sequence, 1);
      });
    });

    test('a background launch sends no visit or heartbeat', () {
      fakeAsync((async) {
        final sent = <NotificationActivityUpdate>[];
        final coordinator = NotificationActivitySessionCoordinator(
          send: (_, update, _) async => sent.add(update),
        );
        addTearDown(coordinator.dispose);
        coordinator.setAccount(owner: owner, ready: true);
        async.elapse(const Duration(minutes: 5));
        expect(sent, isEmpty);
      });
    });

    test('renews foreground every 60 seconds and stops in background', () {
      fakeAsync((async) {
        final sent = <NotificationActivityUpdate>[];
        final coordinator = NotificationActivitySessionCoordinator(
          send: (_, update, _) async => sent.add(update),
        );
        addTearDown(coordinator.dispose);
        coordinator.setAccount(owner: owner, ready: true);
        coordinator.setForeground(true);
        async.flushMicrotasks();
        coordinator.setForeground(true);
        async.elapse(const Duration(seconds: 59));
        expect(sent, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(sent.map((update) => update.sequence), [1, 2]);
        expect(sent.map((update) => update.visit), [1, 1]);
        coordinator.setForeground(false);
        async.flushMicrotasks();
        expect(sent.last.state, NotificationActivityState.background);
        async.elapse(const Duration(minutes: 5));
        expect(sent, hasLength(3));
      });
    });

    test('retries uncertainty with identical session, sequence, and body', () {
      fakeAsync((async) {
        final sent = <NotificationActivityUpdate>[];
        final coordinator = NotificationActivitySessionCoordinator(
          send: (_, update, _) async {
            sent.add(update);
            if (sent.length == 1) throw StateError('transport unavailable');
          },
        );
        addTearDown(coordinator.dispose);
        coordinator.setAccount(owner: owner, ready: true);
        coordinator.setForeground(true);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        expect(sent, hasLength(2));
        expect(sent.last.body, sent.first.body);
      });
    });

    test(
      'newer background supersedes an in-flight foreground and its retry',
      () {
        fakeAsync((async) {
          final sent = <NotificationActivityUpdate>[];
          final currentChecks = <bool Function()>[];
          final signing = Completer<void>();
          final coordinator = NotificationActivitySessionCoordinator(
            send: (_, update, isCurrent) async {
              sent.add(update);
              currentChecks.add(isCurrent);
              if (sent.length == 1) await signing.future;
            },
          );
          addTearDown(coordinator.dispose);
          coordinator.setAccount(owner: owner, ready: true);
          coordinator.setForeground(true);
          coordinator.setForeground(false);
          expect(currentChecks.first(), isFalse);
          signing.completeError(StateError('uncertain foreground'));
          async.flushMicrotasks();
          expect(sent.map((update) => update.state), [
            NotificationActivityState.foreground,
            NotificationActivityState.background,
          ]);
          expect(sent.last.sequence, 2);
          async.elapse(const Duration(seconds: 30));
          expect(sent, hasLength(2));
        });
      },
    );

    test('account switch retires old signing and starts a fresh session', () {
      fakeAsync((async) {
        final sent = <(String, NotificationActivityUpdate)>[];
        final currentChecks = <bool Function()>[];
        final signing = Completer<void>();
        final coordinator = NotificationActivitySessionCoordinator(
          send: (account, update, isCurrent) async {
            sent.add((account, update));
            currentChecks.add(isCurrent);
            if (sent.length == 1) await signing.future;
          },
        );
        addTearDown(coordinator.dispose);
        coordinator.setAccount(owner: owner, ready: true);
        coordinator.setForeground(true);
        coordinator.setAccount(owner: otherOwner, ready: true);
        expect(currentChecks.first(), isFalse);
        signing.complete();
        async.flushMicrotasks();
        expect(sent.map((entry) => entry.$1), [owner, otherOwner]);
        expect(sent.last.$2.sequence, 1);
        expect(sent.last.$2.sessionId, isNot(sent.first.$2.sessionId));
      });
    });

    test('temporary signer unavailability keeps sequence and session', () {
      fakeAsync((async) {
        final sent = <NotificationActivityUpdate>[];
        final coordinator = NotificationActivitySessionCoordinator(
          send: (_, update, _) async => sent.add(update),
        );
        addTearDown(coordinator.dispose);
        coordinator.setAccount(owner: owner, ready: true);
        coordinator.setForeground(true);
        async.flushMicrotasks();
        coordinator.setAccount(owner: owner, ready: false);
        async.elapse(const Duration(minutes: 5));
        expect(sent, hasLength(1));
        coordinator.setAccount(owner: owner, ready: true);
        async.flushMicrotasks();
        expect(sent.last.sessionId, sent.first.sessionId);
        expect(sent.last.sequence, 2);
      });
    });

    test(
      'counts visits even when every intervening background was offline',
      () {
        fakeAsync((async) {
          final sent = <NotificationActivityUpdate>[];
          final coordinator = NotificationActivitySessionCoordinator(
            send: (_, update, _) async => sent.add(update),
          );
          addTearDown(coordinator.dispose);
          coordinator.setAccount(owner: owner, ready: true);
          coordinator.setForeground(true);
          async.flushMicrotasks();
          coordinator.setAccount(owner: owner, ready: false);
          coordinator.setForeground(false);
          coordinator.setForeground(true);
          coordinator.setForeground(false);
          coordinator.setForeground(true);
          coordinator.setAccount(owner: owner, ready: true);
          async.flushMicrotasks();

          expect(sent, hasLength(2));
          expect(sent.map((update) => update.visit), [1, 3]);
          expect(sent.last.sequence, greaterThanOrEqualTo(sent.last.visit));
          expect(sent.last.sessionId, sent.first.sessionId);
        });
      },
    );

    test('dispose cancels retries and heartbeats', () {
      fakeAsync((async) {
        var attempts = 0;
        final coordinator = NotificationActivitySessionCoordinator(
          send: (_, _, _) async {
            attempts++;
            throw StateError('transport unavailable');
          },
        );
        coordinator.setAccount(owner: owner, ready: true);
        coordinator.setForeground(true);
        async.flushMicrotasks();
        expect(attempts, 1);
        coordinator.dispose();
        async.elapse(const Duration(minutes: 5));
        expect(attempts, 1);
      });
    });

    test(
      'reports a background transition once signing becomes ready again',
      () {
        fakeAsync((async) {
          final sent = <NotificationActivityUpdate>[];
          final coordinator = NotificationActivitySessionCoordinator(
            send: (_, update, _) async => sent.add(update),
          );
          addTearDown(coordinator.dispose);
          coordinator.setAccount(owner: owner, ready: true);
          coordinator.setForeground(true);
          async.flushMicrotasks();
          coordinator.setAccount(owner: owner, ready: false);
          coordinator.setForeground(false);
          coordinator.setAccount(owner: owner, ready: true);
          async.flushMicrotasks();

          expect(sent.map((update) => update.state), [
            NotificationActivityState.foreground,
            NotificationActivityState.background,
          ]);
          expect(sent.last.sequence, 2);
        });
      },
    );
  });
}
