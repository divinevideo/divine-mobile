// ABOUTME: Tests for NostrConnectCoordinator — session lifecycle, the
// ABOUTME: single-flight wait, failure-reason mapping, the connection ports,
// ABOUTME: and the deep-link callback-handoff timers.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/auth_result.dart';
import 'package:openvine/services/auth/nostr_connect_coordinator.dart';

class _MockNostrConnectSession extends Mock implements NostrConnectSession {}

void main() {
  group(NostrConnectCoordinator, () {
    late _MockNostrConnectSession session;
    late List<String> createdRelays;
    late int waitStartedCalls;
    late int waitFailedCalls;
    late List<NostrConnectResult> connectedResults;
    late List<Object> connectFailedErrors;
    late List<String> reportedReasons;
    late Future<AuthResult> Function(NostrConnectResult) onConnectedImpl;

    setUpAll(() {
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      session = _MockNostrConnectSession();
      createdRelays = [];
      waitStartedCalls = 0;
      waitFailedCalls = 0;
      connectedResults = [];
      connectFailedErrors = [];
      reportedReasons = [];
      onConnectedImpl = (_) async => const AuthResult(success: true);

      when(() => session.start()).thenAnswer((_) async {});
      when(session.cancel).thenReturn(null);
      when(session.dispose).thenReturn(null);
      when(session.ensureConnected).thenAnswer((_) async {});
      when(() => session.addRelay(any())).thenAnswer((_) async {});
      when(() => session.connectUrl).thenReturn('nostrconnect://abc');
      when(() => session.state).thenReturn(NostrConnectState.listening);
      when(() => session.failureReason).thenReturn(null);
    });

    NostrConnectCoordinator build() => NostrConnectCoordinator(
      onConnected: (result) {
        connectedResults.add(result);
        return onConnectedImpl(result);
      },
      onConnectFailed: connectFailedErrors.add,
      onWaitStarted: () => waitStartedCalls++,
      onWaitFailed: () => waitFailedCalls++,
      reportError: (
        error,
        stack, {
        required String reason,
        required String logMessage,
      }) => reportedReasons.add(reason),
      sessionFactory: (relays) {
        createdRelays = relays;
        return session;
      },
    );

    NostrConnectResult resultFor(String pubkey) => NostrConnectResult(
      remoteSignerPubkey: pubkey,
      userPubkey: pubkey,
      info: NostrRemoteSignerInfo(remoteSignerPubkey: pubkey, relays: const []),
    );

    group('initiate', () {
      test('creates a session via the factory and starts it', () async {
        final coordinator = build();
        final s = await coordinator.initiate();
        expect(s, session);
        verify(() => session.start()).called(1);
        expect(createdRelays, isNotEmpty);
      });

      test('uses custom relays when provided', () async {
        final coordinator = build();
        await coordinator.initiate(customRelays: const ['wss://custom']);
        expect(createdRelays, ['wss://custom']);
      });

      test('exposes connectUrl + state from the session', () async {
        final coordinator = build();
        expect(coordinator.connectUrl, isNull);
        expect(coordinator.state, isNull);
        await coordinator.initiate();
        expect(coordinator.connectUrl, 'nostrconnect://abc');
        expect(coordinator.state, NostrConnectState.listening);
      });
    });

    group('waitForResponse', () {
      test('returns failure when no session is active', () async {
        final result = await build().waitForResponse();
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('No active nostrconnect session'));
        expect(waitStartedCalls, 0);
      });

      test(
        'applies the connection and disposes the session on success',
        () async {
          when(
            () => session.waitForConnection(timeout: any(named: 'timeout')),
          ).thenAnswer((_) async => resultFor('a' * 64));
          final coordinator = build();
          await coordinator.initiate();

          final result = await coordinator.waitForResponse();

          expect(result.success, isTrue);
          expect(waitStartedCalls, 1);
          expect(connectedResults.single.remoteSignerPubkey, 'a' * 64);
          verify(() => session.dispose()).called(1);
        },
      );

      test('shares a single in-flight wait', () async {
        final completer = Completer<NostrConnectResult?>();
        when(
          () => session.waitForConnection(timeout: any(named: 'timeout')),
        ).thenAnswer((_) => completer.future);
        final coordinator = build();
        await coordinator.initiate();

        final a = coordinator.waitForResponse();
        final b = coordinator.waitForResponse();
        expect(identical(a, b), isTrue);

        completer.complete(null);
        await a;
        await b;
        verify(
          () => session.waitForConnection(timeout: any(named: 'timeout')),
        ).called(1);
      });

      test('maps timeout state to timedOut', () async {
        when(
          () => session.waitForConnection(timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => null);
        when(() => session.state).thenReturn(NostrConnectState.timeout);
        final coordinator = build();
        await coordinator.initiate();

        final result = await coordinator.waitForResponse();

        expect(
          result.nostrConnectFailureReason,
          NostrConnectFailureReason.timedOut,
        );
        expect(waitFailedCalls, 1);
      });

      test('maps an error state to the session failure reason', () async {
        when(
          () => session.waitForConnection(timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => null);
        when(() => session.state).thenReturn(NostrConnectState.error);
        when(
          () => session.failureReason,
        ).thenReturn(NostrConnectFailureReason.startFailed);
        final coordinator = build();
        await coordinator.initiate();

        final result = await coordinator.waitForResponse();

        expect(
          result.nostrConnectFailureReason,
          NostrConnectFailureReason.startFailed,
        );
      });

      test('reports the noExpectedSecret invariant to Crashlytics', () async {
        when(
          () => session.waitForConnection(timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => null);
        when(() => session.state).thenReturn(NostrConnectState.error);
        when(
          () => session.failureReason,
        ).thenReturn(NostrConnectFailureReason.noExpectedSecret);
        final coordinator = build();
        await coordinator.initiate();

        final result = await coordinator.waitForResponse();

        expect(
          result.nostrConnectFailureReason,
          NostrConnectFailureReason.noExpectedSecret,
        );
        expect(reportedReasons, ['NostrConnect.noExpectedSecret']);
      });

      test('treats cancellation during the wait as cancelled', () async {
        final completer = Completer<NostrConnectResult?>();
        when(
          () => session.waitForConnection(timeout: any(named: 'timeout')),
        ).thenAnswer((_) => completer.future);
        final coordinator = build();
        await coordinator.initiate();

        final future = coordinator.waitForResponse();
        coordinator.cancel();
        completer.complete(resultFor('a' * 64));

        final result = await future;
        expect(
          result.nostrConnectFailureReason,
          NostrConnectFailureReason.cancelled,
        );
        expect(waitFailedCalls, 1);
      });

      test('routes application errors through onConnectFailed', () async {
        when(
          () => session.waitForConnection(timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => resultFor('a' * 64));
        onConnectedImpl = (_) async => throw Exception('boom');
        final coordinator = build();
        await coordinator.initiate();

        final result = await coordinator.waitForResponse();

        expect(
          result.nostrConnectFailureReason,
          NostrConnectFailureReason.postConnectFailed,
        );
        expect(connectFailedErrors, hasLength(1));
      });
    });

    group('cancel', () {
      test('cancels and disposes the active session', () async {
        final coordinator = build();
        await coordinator.initiate();
        coordinator.cancel();
        verify(() => session.cancel()).called(1);
        verify(() => session.dispose()).called(1);
      });

      test('is safe with no active session', () {
        expect(build().cancel, returnsNormally);
      });
    });

    group('callback handoff', () {
      test(
        'onSignerCallbackReceived activates handoff + ensures connected',
        () async {
          final coordinator = build();
          await coordinator.initiate();

          coordinator.onSignerCallbackReceived(relayUrl: 'wss://r');

          expect(coordinator.isCallbackHandoffActive, isTrue);
          verify(() => session.addRelay('wss://r')).called(1);
          verify(() => session.ensureConnected()).called(1);
        },
      );

      test('onSignerCallbackReceived no-ops when not listening', () async {
        when(() => session.state).thenReturn(NostrConnectState.idle);
        final coordinator = build();
        await coordinator.initiate();

        coordinator.onSignerCallbackReceived();

        expect(coordinator.isCallbackHandoffActive, isFalse);
        verifyNever(() => session.ensureConnected());
      });

      test('the handoff-active flag expires after 5s', () {
        fakeAsync((async) {
          final coordinator = build();
          unawaited(coordinator.initiate());
          async.flushMicrotasks();

          coordinator.onSignerCallbackReceived();
          expect(coordinator.isCallbackHandoffActive, isTrue);

          async.elapse(const Duration(seconds: 5));
          expect(coordinator.isCallbackHandoffActive, isFalse);
        });
      });

      test('preserveForCallbackHandoff no-ops when handoff is inactive', () {
        fakeAsync((async) {
          final coordinator = build();
          unawaited(coordinator.initiate());
          async.flushMicrotasks();

          coordinator.preserveForCallbackHandoff();
          async.elapse(const Duration(seconds: 5));

          verifyNever(() => session.cancel());
        });
      });

      test('claimCallbackHandoff is safe to call', () {
        expect(build().claimCallbackHandoff, returnsNormally);
      });

      test('dispose cancels the handoff timers', () {
        fakeAsync((async) {
          final coordinator = build();
          unawaited(coordinator.initiate());
          async.flushMicrotasks();

          coordinator.onSignerCallbackReceived();
          expect(coordinator.isCallbackHandoffActive, isTrue);

          coordinator.dispose();
          async.elapse(const Duration(seconds: 5));

          // The expiry timer was cancelled by dispose, so the flag never reset.
          expect(coordinator.isCallbackHandoffActive, isTrue);
        });
      });
    });

    group('reconnectListeningRelays', () {
      test('ensures connected when listening', () async {
        final coordinator = build();
        await coordinator.initiate();
        coordinator.reconnectListeningRelays();
        verify(() => session.ensureConnected()).called(1);
      });

      test('no-ops when not listening', () async {
        when(() => session.state).thenReturn(NostrConnectState.idle);
        final coordinator = build();
        await coordinator.initiate();
        coordinator.reconnectListeningRelays();
        verifyNever(() => session.ensureConnected());
      });
    });
  });
}
