// ABOUTME: Tests for connectivityRelayReconnectProvider, the app-wide owner of
// ABOUTME: connectivity-driven relay repair (#3161, #8990), and relay stats.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/services/connectivity_transition_monitor.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockRelayStatisticsService extends Mock
    implements RelayStatisticsService {}

/// Serves [_initial] and lets a test replace the client the way an account
/// switch or a failed initialization does.
class _SwappableNostrService extends NostrService {
  _SwappableNostrService(this._initial);

  final NostrClient _initial;

  @override
  NostrClient build() => _initial;

  void replace(NostrClient client) => state = client;
}

/// Stands in for `connectivity_plus`, which replays the current state to a
/// new listener when its listener count goes from zero to one.
class _FakeConnectivity {
  _FakeConnectivity(this.current) {
    _reports = StreamController<List<ConnectivityResult>>.broadcast(
      onListen: () {
        subscriptions++;
        _reports.add(current);
      },
    );
  }

  List<ConnectivityResult> current;
  late final StreamController<List<ConnectivityResult>> _reports;
  int subscriptions = 0;

  Stream<List<ConnectivityResult>> get changes => _reports.stream;

  void change(List<ConnectivityResult> results) {
    current = results;
    _reports.add(results);
  }
}

void main() {
  group('connectivityRelayReconnectProvider', () {
    late _MockNostrClient first;
    late _MockNostrClient second;

    setUp(() {
      first = _MockNostrClient();
      second = _MockNostrClient();
      when(first.forceReconnectAll)
          .thenAnswer((_) async => ForceReconnectOutcome.completed);
      when(second.forceReconnectAll)
          .thenAnswer((_) async => ForceReconnectOutcome.completed);
    });

    ProviderContainer containerFor(_FakeConnectivity connectivity) {
      final container = ProviderContainer(
        overrides: [
          connectivityChangesProvider.overrideWithValue(connectivity.changes),
          connectivityCheckProvider.overrideWithValue(
            () async => connectivity.current,
          ),
          nostrServiceProvider.overrideWith(
            () => _SwappableNostrService(first),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    void replaceClient(ProviderContainer container, NostrClient client) {
      (container.read(nostrServiceProvider.notifier) as _SwappableNostrService)
          .replace(client);
    }

    test('neither resubscribes nor repairs when the client is replaced', () {
      // Re-subscribing replayed the current state, which the old provider
      // took for a reconnect: ~2 s after every launch and sign-in (#8990).
      // Listened, as AppRootSideEffects does, so a dependency change would
      // rebuild it.
      fakeAsync((async) {
        final connectivity = _FakeConnectivity(const [ConnectivityResult.wifi]);
        final container = containerFor(connectivity);
        container.listen(connectivityRelayReconnectProvider, (_, _) {});
        async.flushMicrotasks();

        replaceClient(container, second);
        async.elapse(const Duration(seconds: 5));

        expect(connectivity.subscriptions, equals(1));
        verifyNever(first.forceReconnectAll);
        verifyNever(second.forceReconnectAll);
      });
    });

    test('repairs the client that is active when the repair fires', () {
      fakeAsync((async) {
        final connectivity = _FakeConnectivity(const [ConnectivityResult.wifi]);
        final container = containerFor(connectivity);
        container.listen(connectivityRelayReconnectProvider, (_, _) {});
        async.flushMicrotasks();
        replaceClient(container, second);

        connectivity.change(const [ConnectivityResult.mobile]);
        async.elapse(const Duration(seconds: 2));

        verify(second.forceReconnectAll).called(1);
        verifyNever(first.forceReconnectAll);
      });
    });

    test('waits while the active client is still initializing', () {
      fakeAsync((async) {
        final connectivity = _FakeConnectivity(const [ConnectivityResult.wifi]);
        final container = containerFor(connectivity);
        container.listen(connectivityRelayReconnectProvider, (_, _) {});
        async.flushMicrotasks();
        final initialization = container.read(
          nostrInitializationInProgressProvider.notifier,
        )..begin(first);

        connectivity.change(const [ConnectivityResult.mobile]);
        async.elapse(const Duration(seconds: 10));
        verifyNever(first.forceReconnectAll);

        initialization.end(first);
        async.elapse(const Duration(seconds: 2));
        verify(first.forceReconnectAll).called(1);
      });
    });

    group('repair log', () {
      List<String> repairLogs(
        FakeAsync async, {
        required ForceReconnectOutcome outcome,
        required int connected,
      }) {
        unawaited(LogCaptureService().clearAllLogs());
        when(first.forceReconnectAll).thenAnswer((_) async => outcome);
        when(() => first.connectedRelayCount).thenReturn(connected);
        when(() => first.configuredRelayCount).thenReturn(2);
        final connectivity = _FakeConnectivity(const [ConnectivityResult.wifi]);
        final container = containerFor(connectivity);
        container.listen(connectivityRelayReconnectProvider, (_, _) {});
        async.flushMicrotasks();

        connectivity.change(const [ConnectivityResult.mobile]);
        async.elapse(const Duration(seconds: 2));

        verify(first.forceReconnectAll).called(1);
        return [
          for (final entry in LogCaptureService().getRecentLogs())
            entry.message,
        ];
      }

      test('logs how many relays connected when the repair finishes', () {
        fakeAsync((async) {
          final messages = repairLogs(
            async,
            outcome: ForceReconnectOutcome.completed,
            connected: 1,
          );

          expect(
            messages,
            contains(
              'Relay reconnect after a connectivity change finished: 1 of 2 '
              'relays connected',
            ),
          );
          expect(
            messages,
            isNot(
              contains(
                'Relay reconnect attempt after a connectivity change ended',
              ),
            ),
          );
        });
      });

      test('says relays are still connecting when the repair wait ends '
          'first', () {
        fakeAsync((async) {
          final messages = repairLogs(
            async,
            outcome: ForceReconnectOutcome.stillDialling,
            connected: 0,
          );

          expect(
            messages,
            contains(
              'Relay reconnect after a connectivity change ended with relays '
              'still connecting (0 of 2 connected)',
            ),
          );
          expect(
            messages,
            isNot(
              contains(
                'Relay reconnect attempt after a connectivity change ended',
              ),
            ),
          );
        });
      });
    });

    test('exposes the transitions for the DM retry sweep', () {
      fakeAsync((async) {
        final connectivity = _FakeConnectivity(const [ConnectivityResult.wifi]);
        final container = containerFor(connectivity);
        final transitions = <ConnectivityTransition>[];
        container
            .read(connectivityRelayReconnectProvider)
            .listen(transitions.add);
        async.flushMicrotasks();

        connectivity.change(const [ConnectivityResult.none]);
        async.flushMicrotasks();
        connectivity.change(const [ConnectivityResult.wifi]);
        async.elapse(const Duration(seconds: 2));

        expect(transitions, [
          ConnectivityTransition.offline,
          ConnectivityTransition.online,
        ]);
      });
    });
  });

  group('relayStatisticsStreamProvider', () {
    const relayUrl = 'wss://relay.example.com';

    test('emits the current statistics, then each change', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(relayStatisticsServiceProvider);
      final emitted = <Map<String, RelayStatistics>>[];
      container.listen(relayStatisticsStreamProvider, (_, next) {
        if (next case AsyncData(:final value)) emitted.add(value);
      });
      await pumpEventQueue();

      service.recordConnection(relayUrl);
      await pumpEventQueue();

      expect(emitted, hasLength(2));
      expect(emitted.first, isEmpty);
      expect(emitted.last[relayUrl]?.isConnected, isTrue);
    });

    group('when its Ref is unmounted before the stream starts', () {
      test(
        'reports no error when rebuilt in the same event-loop turn',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final uncaught = <Object>[];

          runZonedGuarded(() {
            final subscription = container.listen(
              relayStatisticsStreamProvider,
              (_, _) {},
            );
            addTearDown(subscription.close);
            container.refresh(relayStatisticsStreamProvider);
          }, (error, _) => uncaught.add(error));
          await pumpEventQueue();

          expect(uncaught, isEmpty);
          expect(container.read(relayStatisticsStreamProvider).value, isEmpty);
        },
      );

      test(
        'reports no error when disposed in the same event-loop turn',
        () async {
          final service = _MockRelayStatisticsService();
          final container = ProviderContainer(
            overrides: [
              relayStatisticsServiceProvider.overrideWithValue(service),
            ],
          );
          final uncaught = <Object>[];

          runZonedGuarded(() {
            container
              ..listen(relayStatisticsStreamProvider, (_, _) {})
              ..dispose();
          }, (error, _) => uncaught.add(error));
          await pumpEventQueue();

          expect(uncaught, isEmpty);
          // A read here would run after cancellation, where a throw is
          // unhandled.
          verifyNever(service.getAllStatistics);
        },
      );
    });
  });
}
