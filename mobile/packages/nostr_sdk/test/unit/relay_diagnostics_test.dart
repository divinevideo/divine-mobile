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

      expect(
        diagnostics.map((entry) => entry.site),
        containsAll([
          RelayDiagnosticSite.connectionLifecycle,
          RelayDiagnosticSite.queryDispatch,
          RelayDiagnosticSite.requestSettlement,
        ]),
      );
      expect(
        diagnostics.map((entry) => entry.message),
        contains(contains('full-subscription-id')),
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
  });
}
