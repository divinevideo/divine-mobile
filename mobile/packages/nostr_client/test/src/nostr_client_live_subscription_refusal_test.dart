// ABOUTME: A live subscription one relay refuses while another relay is still
// ABOUTME: being redialled survives, and reaches that relay once it connects.

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:test/test.dart';

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _refusingUrl = 'wss://refusing.example';
const _redialledUrl = 'wss://redialled.example';
const _liveId = 'live-reactions';

/// A relay socket whose connect can be held open, and which can answer every
/// REQ with `CLOSED`.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url, {this.held, this.refuseWith, this.connects = true})
    : super(url, RelayStatus(url));

  /// While non-null and incomplete, [doConnect] waits on it.
  final Completer<void>? held;

  /// When non-null, every REQ is answered with `CLOSED` and this reason.
  final String? refuseWith;

  /// Whether [doConnect] succeeds once [held] completes.
  final bool connects;

  final List<String> reqs = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connecting;
    await held?.future;
    if (!connects) {
      relayStatus.connected = ClientConnected.disconnect;
      return false;
    }
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.first == 'REQ') {
      final id = message[1] as String;
      reqs.add(id);
      final reason = refuseWith;
      if (reason != null) {
        scheduleMicrotask(() => onMessage!(this, ['CLOSED', id, reason]));
      }
    }
    return true;
  }
}

/// Hands out a fresh [_ScriptedRelay] per dial, scripted by [next].
class _Dialer {
  final Map<String, List<_ScriptedRelay>> dialled = {};
  final Map<String, _ScriptedRelay Function(String url)> next = {};

  Relay call(String url) {
    final relay = (next.remove(url) ?? _ScriptedRelay.new)(url);
    (dialled[url] ??= []).add(relay);
    return relay;
  }

  _ScriptedRelay latest(String url) => dialled[url]!.last;
}

void main() {
  group('$NostrClient live subscription refused by one relay', () {
    late _Dialer dialer;
    late Nostr nostr;
    late RelayManager manager;
    late NostrClient client;
    late List<Object> errors;
    late bool done;

    setUp(() {
      dialer = _Dialer();
      nostr = Nostr(LocalNostrSigner(_key), [], (url) {
        throw StateError('no temp relays: $url');
      });
      manager = RelayManager(
        config: RelayManagerConfig(
          defaultRelayUrl: _redialledUrl,
          storage: InMemoryRelayStorage([_refusingUrl, _redialledUrl]),
        ),
        relayPool: nostr.relayPool,
        relayFactory: dialer.call,
      );
      client = NostrClient.forTesting(nostr: nostr, relayManager: manager);
      errors = [];
      done = false;
    });

    tearDown(() => client.dispose());

    void subscribe() {
      client
          .subscribe([
            Filter(kinds: const [EventKind.reaction], limit: 1),
          ], subscriptionId: _liveId)
          .listen((_) {}, onError: errors.add, onDone: () => done = true);
    }

    group('forceReconnectAll', () {
      test(
        'keeps the subscription while the other relay is still redialling, '
        'and replays it to that relay once it connects',
        () async {
          await manager.initialize();
          subscribe();
          await pumpEventQueue();
          expect(dialer.latest(_redialledUrl).reqs, contains(_liveId));

          final redial = Completer<void>();
          dialer.next[_refusingUrl] = (url) =>
              _ScriptedRelay(url, refuseWith: 'rate-limited: slow down');
          dialer.next[_redialledUrl] = (url) =>
              _ScriptedRelay(url, held: redial);
          final reconnect = client.forceReconnectAll();
          await pumpEventQueue();

          expect(dialer.latest(_refusingUrl).reqs, contains(_liveId));
          expect(errors, isEmpty);
          expect(done, isFalse);

          redial.complete();
          await reconnect;
          await pumpEventQueue();

          expect(dialer.latest(_redialledUrl).reqs, contains(_liveId));
          expect(errors, isEmpty);
          expect(done, isFalse);
        },
      );

      test(
        'ends the subscription with the refusal once the relay it waited for '
        'fails to connect',
        () async {
          await manager.initialize();
          subscribe();
          await pumpEventQueue();

          final redial = Completer<void>();
          dialer.next[_refusingUrl] = (url) =>
              _ScriptedRelay(url, refuseWith: 'rate-limited: slow down');
          dialer.next[_redialledUrl] = (url) =>
              _ScriptedRelay(url, held: redial, connects: false);
          final reconnect = client.forceReconnectAll();
          await pumpEventQueue();

          expect(dialer.latest(_refusingUrl).reqs, contains(_liveId));
          expect(done, isFalse);

          redial.complete();
          await reconnect;
          await pumpEventQueue();

          expect(errors, [
            isA<RelaySubscriptionRefusedException>().having(
              (e) => e.reason,
              'reason',
              'rate-limited: slow down',
            ),
          ]);
          expect(done, isTrue);
        },
      );
    });

    group('the relay it waits for leaves the pool', () {
      late Completer<void> redial;

      setUp(() async {
        await manager.initialize();
        subscribe();
        await pumpEventQueue();
        redial = Completer<void>();
        dialer.next[_refusingUrl] = (url) =>
            _ScriptedRelay(url, refuseWith: 'rate-limited: slow down');
        dialer.next[_redialledUrl] = (url) => _ScriptedRelay(url, held: redial);
        unawaited(client.forceReconnectAll());
        await pumpEventQueue();
        expect(done, isFalse);
      });

      tearDown(() => redial.complete());

      test('ends the subscription once that relay is removed', () async {
        nostr.relayPool.remove(_redialledUrl);
        await pumpEventQueue();

        expect(errors, [isA<RelaySubscriptionRefusedException>()]);
        expect(done, isTrue);
      });

      test('ends the subscription once every relay is removed', () async {
        nostr.relayPool.removeAll();
        await pumpEventQueue();

        expect(errors, [isA<RelaySubscriptionRefusedException>()]);
        expect(done, isTrue);
      });
    });

    group('subscribe', () {
      test('ends the subscription at once when every connected relay refuses '
          'it and none is still connecting', () async {
        dialer.next[_refusingUrl] = (url) =>
            _ScriptedRelay(url, refuseWith: 'rate-limited: slow down');
        dialer.next[_redialledUrl] = (url) =>
            _ScriptedRelay(url, refuseWith: 'restricted: members only');
        await manager.initialize();

        subscribe();
        await pumpEventQueue();

        expect(dialer.latest(_refusingUrl).reqs, contains(_liveId));
        expect(dialer.latest(_redialledUrl).reqs, contains(_liveId));
        expect(errors, [isA<RelaySubscriptionRefusedException>()]);
        expect(done, isTrue);
      });
    });

    group('initialize', () {
      test(
        'keeps a subscription opened before the pool connects when the first '
        'relay refuses it and the other is still connecting',
        () async {
          final connect = Completer<void>();
          dialer.next[_refusingUrl] = (url) => _ScriptedRelay(
            url,
            refuseWith: 'error: could not complete query',
          );
          dialer.next[_redialledUrl] = (url) =>
              _ScriptedRelay(url, held: connect);
          subscribe();
          final initialized = manager.initialize();
          await pumpEventQueue();

          expect(dialer.latest(_refusingUrl).reqs, contains(_liveId));
          expect(errors, isEmpty);
          expect(done, isFalse);

          connect.complete();
          await initialized;
          await pumpEventQueue();

          expect(dialer.latest(_redialledUrl).reqs, contains(_liveId));
          expect(errors, isEmpty);
          expect(done, isFalse);
        },
      );
    });
  });
}
