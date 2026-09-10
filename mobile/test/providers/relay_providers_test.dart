// ABOUTME: Tests for connectivityRelayReconnectProvider, the app-wide owner of
// ABOUTME: connectivity-driven relay repair (#3161, #8990).

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

class _MockNostrClient extends Mock implements NostrClient {}

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
      when(first.forceReconnectAll).thenAnswer((_) async {});
      when(second.forceReconnectAll).thenAnswer((_) async {});
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
}
