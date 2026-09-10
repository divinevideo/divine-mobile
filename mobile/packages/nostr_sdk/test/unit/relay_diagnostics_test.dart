// ABOUTME: Regression tests for structured relay diagnostics emitted by RelayPool.
// ABOUTME: Proves support-safe metadata is emitted while raw relay frames stay out.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _DiagnosticRelay extends Relay {
  _DiagnosticRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sent = [];

  @override
  Future<bool> doConnect() async {
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
    sent.add(message);
    return true;
  }

  Future<void> deliver(List<dynamic> message) async {
    final handler = onMessage;
    expect(handler, isNotNull);
    final dynamic result = handler!(this, message);
    if (result is Future) await result;
  }
}

void main() {
  group('Relay diagnostics', () {
    late List<RelayDiagnostic> diagnostics;
    late Nostr nostr;

    setUp(() {
      diagnostics = [];
      nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        (url) => _DiagnosticRelay(url),
        diagnosticsSink: diagnostics.add,
      );
    });

    test('emits connection, dispatch, and settlement metadata', () async {
      final relay = _DiagnosticRelay('wss://relay.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      final subscription = Subscription(
        const [
          {
            'kinds': [1],
          },
        ],
        (_) {},
        id: 'full-subscription-id',
      );
      expect(
        await nostr.relayPool.relayDoQuery(relay, subscription, false),
        isTrue,
      );
      await relay.deliver(['EOSE', subscription.id]);

      expect(diagnostics.map((entry) => entry.site).toList(), [
        RelayDiagnosticSite.connectionLifecycle,
        RelayDiagnosticSite.queryDispatch,
        RelayDiagnosticSite.queryDispatch,
        RelayDiagnosticSite.requestSettlement,
      ]);
      expect(
        diagnostics.map((entry) => entry.message),
        contains(contains('full-subscription-id')),
      );
    });

    test('reports a full-settlement relay that never settles', () async {
      final relay = _DiagnosticRelay('wss://silent.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      await nostr.relayPool.query(
        const [
          {
            'kinds': [1],
          },
        ],
        (_) {},
        id: 'silent-full-settlement-id',
        onComplete: () {},
        requireAllRelaysSettled: true,
      );
      nostr.unsubscribe('silent-full-settlement-id');

      final settlements = diagnostics.where(
        (entry) => entry.site == RelayDiagnosticSite.requestSettlement,
      );
      expect(
        settlements.where(
          (entry) =>
              entry.relayUrl == relay.url &&
              entry.message.contains('did not settle request'),
        ),
        hasLength(1),
      );
      expect(
        settlements.map((entry) => entry.message),
        contains(
          contains(
            'answered=false, closedWithoutAnswer=false, '
            'noRelayTookRequest=false',
          ),
        ),
      );
    });

    test('reports a full-settlement query that no relay took', () async {
      await nostr.relayPool.query(
        const [
          {
            'kinds': [1],
          },
        ],
        (_) {},
        id: 'no-relay-full-settlement-id',
        onComplete: () {},
        requireAllRelaysSettled: true,
      );

      expect(
        diagnostics.map((entry) => entry.message),
        contains(contains('noRelayTookRequest=true')),
      );
    });

    test(
      'classifies a refused full-settlement query before teardown',
      () async {
        final relay = _DiagnosticRelay('wss://refused.example');
        expect(await nostr.relayPool.add(relay), isTrue);

        await nostr.relayPool.query(
          const [
            {
              'kinds': [1],
            },
          ],
          (_) {},
          id: 'refused-full-settlement-id',
          onComplete: () {},
          requireAllRelaysSettled: true,
        );
        await relay.deliver([
          'CLOSED',
          'refused-full-settlement-id',
          'error: unavailable',
        ]);
        nostr.unsubscribe('refused-full-settlement-id');

        expect(
          diagnostics.map((entry) => entry.message),
          contains(contains('closedWithoutAnswer=true')),
        );
      },
    );

    test('does not warn when every full-settlement relay settles', () async {
      final relay = _DiagnosticRelay('wss://settled.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      await nostr.relayPool.query(
        const [
          {
            'kinds': [1],
          },
        ],
        (_) {},
        id: 'settled-full-settlement-id',
        onComplete: () {},
        requireAllRelaysSettled: true,
      );
      await relay.deliver(['EOSE', 'settled-full-settlement-id']);

      expect(
        diagnostics.where(
          (entry) =>
              entry.site == RelayDiagnosticSite.requestSettlement &&
              entry.level == RelayDiagnosticLevel.warning,
        ),
        isEmpty,
      );
    });

    test(
      'does not copy raw NOTICE or CLOSED bodies into diagnostics',
      () async {
        const rawSentinel = 'raw-frame-must-not-enter-support-export';
        final relay = _DiagnosticRelay('wss://relay.example');
        expect(await nostr.relayPool.add(relay), isTrue);

        await relay.deliver(['NOTICE', rawSentinel]);
        await relay.deliver(['CLOSED', 'full-subscription-id', rawSentinel]);

        final exportedMessages = diagnostics
            .map((entry) => entry.message)
            .join('\n');
        expect(exportedMessages, isNot(contains(rawSentinel)));
        expect(
          diagnostics.map((entry) => entry.site),
          containsAll([
            RelayDiagnosticSite.notice,
            RelayDiagnosticSite.requestSettlement,
          ]),
        );
      },
    );

    test('categorizes a CLOSED reason by its NIP-01 prefix', () async {
      final relay = _DiagnosticRelay('wss://relay.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      // The human-readable half mentions auth and rate limits; neither is
      // what the relay actually said, and both are what a substring search
      // would have reported.
      await relay.deliver([
        'CLOSED',
        'blocked-subscription-id',
        'blocked: too many failed auth attempts, slow your rate down',
      ]);
      await relay.deliver([
        'CLOSED',
        'unsupported-subscription-id',
        'unsupported: filter contains unknown elements',
      ]);

      final settlements = diagnostics
          .where((entry) => entry.site == RelayDiagnosticSite.requestSettlement)
          .map((entry) => entry.message)
          .toList();
      expect(settlements, hasLength(2));
      expect(settlements.first, contains('reason=blocked'));
      expect(settlements.first, isNot(contains('auth-required')));
      expect(settlements.first, isNot(contains('rate-limited')));
      expect(settlements.last, contains('reason=unsupported'));
    });

    test('a throwing diagnostics sink cannot break relay behavior', () async {
      final throwingNostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        (url) => _DiagnosticRelay(url),
        diagnosticsSink: (_) => throw StateError('diagnostics unavailable'),
      );

      expect(
        await throwingNostr.relayPool.add(
          _DiagnosticRelay('wss://relay.example'),
        ),
        isTrue,
      );
    });

    test(
      'a null sink disables structured diagnostics without affecting I/O',
      () async {
        final noSinkNostr = Nostr(
          LocalNostrSigner(
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
          ),
          [],
          (url) => _DiagnosticRelay(url),
        );

        final relay = _DiagnosticRelay('wss://relay.example');
        expect(await noSinkNostr.relayPool.add(relay), isTrue);

        final subscription = Subscription(
          const [
            {
              'kinds': [1],
            },
          ],
          (_) {},
          id: 'no-sink-subscription-id',
        );
        expect(
          await noSinkNostr.relayPool.relayDoQuery(relay, subscription, false),
          isTrue,
        );
        await relay.deliver(['EOSE', subscription.id]);

        expect(relay.sent, [
          ['REQ', subscription.id, ...subscription.filters],
          ['CLOSE', subscription.id],
        ]);
      },
    );
  });

  group('connectionDiagnosticLevelFor', () {
    // Every string below is copied verbatim from a `log(...)` call in
    // web_socket_connection_manager.dart, with its interpolations resolved
    // the way the manager resolves them — a Duration renders as
    // `0:00:05.000000`, which is why none of the give-up messages contains
    // the substring `timeout`.
    test('reports how a connection gave up as a warning', () {
      const gaveUp = [
        'Connection timed out after 0:00:05.000000',
        'Max reconnect attempts reached for wss://relay.example',
        'Connect abandoned: wss://relay.example - no handshake time left',
        'Reconnect budget cannot fit the next backoff for '
            'wss://relay.example; stopping before attempt 3',
        'Timed out closing orphaned channel after 0:00:02.000000',
      ];

      for (final message in gaveUp) {
        expect(
          RelayBase.connectionDiagnosticLevelFor(message),
          RelayDiagnosticLevel.warning,
          reason: 'a support export has to surface "$message"',
        );
      }
    });

    test('keeps already-classified failures at warning', () {
      const failures = [
        'Connection failed (WebSocket): WebSocketChannelException',
        'Stream error: connection reset by peer',
        'Health check failed: connection idle, forcing disconnect',
        'Connection idle for 90s (timeout: 60s), forcing disconnect',
      ];

      for (final message in failures) {
        expect(
          RelayBase.connectionDiagnosticLevelFor(message),
          RelayDiagnosticLevel.warning,
          reason: 'a support export has to surface "$message"',
        );
      }
    });

    test('leaves ordinary lifecycle progress at info', () {
      const progress = [
        'Connecting to wss://relay.example',
        'Connected to wss://relay.example',
        'Already connected to wss://relay.example',
        'Disconnected from wss://relay.example',
        'Reconnecting in 4s (attempt 2/5)',
      ];

      for (final message in progress) {
        expect(
          RelayBase.connectionDiagnosticLevelFor(message),
          RelayDiagnosticLevel.info,
          reason: '"$message" is not a failure',
        );
      }
    });
  });
}
