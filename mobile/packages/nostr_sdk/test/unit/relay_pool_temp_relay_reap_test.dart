// ABOUTME: Pins which disconnected temp relays the idle sweep may reap.
// ABOUTME: Reaping disposes the relay, so it must not cut off a reconnect a
// ABOUTME: caller is still waiting on, nor a socket that never got to open.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// A relay that never manages to connect — the shape of an entry sitting in
/// reconnect backoff, or one whose first `connect()` has not landed yet.
class _NeverConnectsRelay extends Relay {
  _NeverConnectsRelay(String url) : super(url, RelayStatus(url));

  @override
  Future<bool> doConnect() async => false;

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
  }) async => false;
}

void main() {
  group('RelayPool temp relay reaping', () {
    RelayPool buildPool({required Duration idleTimeout}) {
      final signer = LocalNostrSigner(
        '0000000000000000000000000000000000000000000000000000000000000001',
      );
      Relay gener(String url) => _NeverConnectsRelay(url);
      final nostr = Nostr(signer, [], gener);
      return RelayPool(
        nostr,
        [],
        gener,
        tempRelayIdleTimeout: idleTimeout,
        tempRelaySweepInterval: const Duration(hours: 1),
      );
    }

    test('reaps a disconnected temp relay that is holding nothing', () async {
      final pool = buildPool(idleTimeout: Duration.zero);
      pool.checkAndGenTempRelay('wss://idle.example');
      expect(pool.tempRelayUrls, hasLength(1));

      pool.sweepIdleTempRelays();

      // Positive control: without this the two tests below would pass
      // vacuously, because nothing would ever be reaped.
      expect(pool.tempRelayUrls, isEmpty);
    });

    test('spares a disconnected temp relay with a publish queued behind '
        'its reconnect', () async {
      final pool = buildPool(idleTimeout: Duration.zero);
      final relay = pool.checkAndGenTempRelay('wss://parked.example');
      // What a gift wrap parked behind a NIP-42 handshake looks like: the
      // caller is waiting for the reconnect to replay it.
      relay.pendingAuthedMessages.add(['EVENT', <String, dynamic>{}]);

      pool.sweepIdleTempRelays();

      expect(
        pool.tempRelayUrls,
        hasLength(1),
        reason:
            'reaping disposes the relay and cancels the reconnect that '
            'would have flushed the queued publish',
      );
    });

    test('spares a disconnected temp relay holding a publish it has not '
        'answered', () async {
      final pool = buildPool(idleTimeout: Duration.zero);
      pool.checkAndGenTempRelay('wss://unanswered.example').savePublish(
        'held-event-id',
        ['EVENT', <String, dynamic>{}],
        DateTime.now().add(const Duration(minutes: 1)),
      );

      pool.sweepIdleTempRelays();

      expect(
        pool.tempRelayUrls,
        hasLength(1),
        reason: 'its next socket sends the publish again (#11446)',
      );
    });

    test(
      'spares a temp relay whose first connect has not landed yet',
      () async {
        final pool = buildPool(idleTimeout: const Duration(milliseconds: 200));
        pool.checkAndGenTempRelay('wss://still-dialing.example');

        pool.sweepIdleTempRelays();
        expect(
          pool.tempRelayUrls,
          hasLength(1),
          reason: 'an entry younger than one idle window is still dialing',
        );

        await Future<void>.delayed(const Duration(milliseconds: 250));
        pool.sweepIdleTempRelays();
        expect(
          pool.tempRelayUrls,
          isEmpty,
          reason: 'once the window has passed a dead entry must be reclaimed',
        );
      },
    );
  });
}
