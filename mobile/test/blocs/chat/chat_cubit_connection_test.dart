// ABOUTME: Pins how a room handles losing its chat relay: a retryable
// ABOUTME: connection status for the UI, and no crash report.

import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/observability/divine_bloc_observer.dart';
import 'package:openvine/services/crash_reporting_service.dart';

class _CrashReporting extends Mock implements CrashReportingService {}

class _Repo extends Mock implements ConcordRepository {}

/// Hands out a fresh wrap stream per subscription, as the real gateway does.
class _Relay implements RelayGateway {
  final subscriptions = <StreamController<Map<String, dynamic>>>[];

  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) {
    final wraps = StreamController<Map<String, dynamic>>();
    subscriptions.add(wraps);
    return wraps.stream;
  }

  @override
  Future<void> publish(Map<String, dynamic> event) async {}
}

class _NoLegacyCipher implements StreamCipher {
  @override
  String seal(String plaintext, String streamId) =>
      throw StateError('legacy not supported');

  @override
  String open(String ciphertext, String streamId) =>
      throw StateError('legacy not supported');
}

ChatCubit _roomOver(RelayGateway relay) => ChatCubit(
  ConcordRepository(
    relay: relay,
    store: InMemoryConcordStore('a' * 64),
    cipher: _NoLegacyCipher(),
    sealedTransport: SealedChatTransport(
      relay: relay,
      signer: (_) async => throw StateError('signer unused'),
    ),
  ),
  sealedAuthor: '01' * 32,
  pocStreamForChannel: (_) => GroupKey('02' * 32, '03' * 32),
  channelIdFor: (_) => '04' * 32,
  ownsRepository: true,
);

void main() {
  group('ChatCubit relay connection', () {
    late BlocObserver previousObserver;
    late _CrashReporting crashReporting;

    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
      registerFallbackValue(<String, Object>{});
    });

    setUp(() {
      previousObserver = Bloc.observer;
      crashReporting = _CrashReporting();
      when(
        () => crashReporting.recordErrorWithCustomKeys(
          any<Object>(),
          any<StackTrace?>(),
          customKeys: any(named: 'customKeys'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      Bloc.observer = DivineBlocObserver(crashReporting: crashReporting);
    });

    tearDown(() => Bloc.observer = previousObserver);

    VerificationResult verifyCrashReports() => verify(
      () => crashReporting.recordErrorWithCustomKeys(
        any<Object>(),
        any<StackTrace?>(),
        customKeys: any(named: 'customKeys'),
        reason: any(named: 'reason'),
      ),
    );

    void verifyNoCrashReport() => verifyNever(
      () => crashReporting.recordErrorWithCustomKeys(
        any<Object>(),
        any<StackTrace?>(),
        customKeys: any(named: 'customKeys'),
        reason: any(named: 'reason'),
      ),
    );

    test(
      'an unreachable relay offers a reconnect without a crash report',
      () async {
        // Nothing listens on port 1, so every connection attempt fails and
        // the gateway gives up after its single reconnect.
        final cubit = _roomOver(
          WebSocketRelayGateway(
            'ws://127.0.0.1:1',
            connectionTimeout: const Duration(milliseconds: 200),
            reconnectDelay: const Duration(milliseconds: 1),
            maxReconnectAttempts: 1,
          ),
        );
        addTearDown(cubit.close);
        final failed = cubit.stream.firstWhere((state) => state.loadFailed);

        await cubit.start();
        final state = await failed.timeout(const Duration(seconds: 10));

        expect(state.loadFailure, ChatLoadFailure.connection);
        verifyNoCrashReport();
      },
    );

    test('retrying after a lost relay subscribes again', () async {
      final relay = _Relay();
      final cubit = _roomOver(relay);
      addTearDown(cubit.close);
      await cubit.start();
      relay.subscriptions.single.addError(
        const RelayConnectionException('Relay reconnect exhausted'),
      );
      await pumpEventQueue();
      expect(cubit.state.loadFailure, ChatLoadFailure.connection);

      await cubit.start();

      expect(cubit.state.loadFailure, ChatLoadFailure.none);
      expect(relay.subscriptions, hasLength(2));
      expect(relay.subscriptions.last.hasListener, isTrue);
    });

    test(
      'a relay that closes the room shows a load error without a crash '
      'report',
      () async {
        final relay = _Relay();
        final cubit = _roomOver(relay);
        addTearDown(cubit.close);
        await cubit.start();

        relay.subscriptions.single.addError(
          const RelayRejectedException('Relay closed subscription: restricted'),
        );
        await pumpEventQueue();

        expect(cubit.state.loadFailure, ChatLoadFailure.other);
        verifyNoCrashReport();
      },
    );

    for (final error in [
      const RelayConnectionException('Relay reconnect exhausted'),
      TimeoutException('Relay history boundary not received'),
    ]) {
      test(
        'a shared room whose history fails with $error offers a reconnect',
        () async {
          final repository = _Repo();
          when(() => repository.changes)
              .thenAnswer((_) => const Stream.empty());
          final cubit = ChatCubit(
            repository,
            initialize: () async => throw error,
          );
          addTearDown(cubit.close);

          await cubit.start();

          expect(cubit.state.loadFailure, ChatLoadFailure.connection);
          verifyNoCrashReport();
        },
      );
    }

    test('work that outlives the relay is still reported', () async {
      final relay = _Relay();
      final cubit = _roomOver(relay);
      addTearDown(cubit.close);
      await cubit.start();

      relay.subscriptions.single.addError(
        StateError('Relay gateway is closed'),
      );
      await pumpEventQueue();

      expect(cubit.state.loadFailure, ChatLoadFailure.other);
      verifyCrashReports().called(1);
    });
  });
}
