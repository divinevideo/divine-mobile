// ABOUTME: Regression tests for structured relay diagnostics emitted by RelayPool.
// ABOUTME: Proves support-safe metadata is emitted while raw relay frames stay out.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _DiagnosticRelay extends Relay {
  _DiagnosticRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sent = [];
  final Completer<void> firstReq = Completer<void>();

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
    if (message.isNotEmpty && message.first == 'REQ' && !firstReq.isCompleted) {
      firstReq.complete();
    }
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
      expect(
        diagnostics
            .where(
              (entry) =>
                  entry.site == RelayDiagnosticSite.requestSettlement &&
                  entry.message.contains('noRelayTookRequest=true'),
            )
            .single
            .relayUrl,
        RelayDiagnostic.poolScope,
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

    test('includes a sanitized NOTICE body but excludes CLOSED body', () async {
      const noticeReason = 'rate-limited: too many concurrent requests';
      const closedReason = 'raw-closed-frame-must-not-enter-support-export';
      final relay = _DiagnosticRelay('wss://relay.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      await relay.deliver(['NOTICE', noticeReason]);
      await relay.deliver(['CLOSED', 'full-subscription-id', closedReason]);

      final exportedMessages = diagnostics
          .map((entry) => entry.message)
          .join('\n');
      expect(exportedMessages, contains(noticeReason));
      expect(exportedMessages, isNot(contains(closedReason)));
      expect(
        diagnostics.map((entry) => entry.site),
        containsAll([
          RelayDiagnosticSite.notice,
          RelayDiagnosticSite.requestSettlement,
        ]),
      );
    });

    test('sanitizes and bounds NOTICE diagnostics', () async {
      final relay = _DiagnosticRelay('wss://relay.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final publicEventId = 'a' * 64;

      await relay.deliver([
        'NOTICE',
        'denied\npassword=hunter2 authorization: Bearer token-value '
            'nsec1${'q' * 58} event=$publicEventId',
      ]);
      await relay.deliver(['NOTICE', 'word ${'x' * 300}']);

      final notices = diagnostics
          .where((entry) => entry.site == RelayDiagnosticSite.notice)
          .map((entry) => entry.message)
          .toList();
      expect(notices.first, isNot(contains('hunter2')));
      expect(notices.first, isNot(contains('token-value')));
      expect(notices.first, isNot(contains('nsec1')));
      expect(notices.first, isNot(contains('\n')));
      expect(notices.first, contains(publicEventId));
      expect(notices.last, contains('[truncated]'));
      expect(notices.last, isNot(contains('x')));
    });

    test('includes a sanitized AUTH rejection reason in diagnostics', () async {
      final relay = _DiagnosticRelay('wss://auth-rejects.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final pending = nostr.queryEventsDetailed(
        [
          {
            'kinds': [1],
          },
        ],
        timeout: const Duration(milliseconds: 200),
        requireAllRelaysSettled: true,
      );

      await relay.firstReq.future;
      await relay.deliver(['AUTH', 'test-challenge']);
      final authFrame = relay.sent.firstWhere(
        (message) => message.first == 'AUTH',
      );
      final authEventId = (authFrame[1] as Map)['id'] as String;
      await relay.deliver([
        'OK',
        authEventId,
        false,
        'invalid: token=auth-secret via 203.0.113.9 and 2001:db8::4',
      ]);
      await pending;

      final authDiagnostic = diagnostics.singleWhere(
        (entry) =>
            entry.site == RelayDiagnosticSite.authentication &&
            entry.message.startsWith('Relay authentication failed (reason='),
      );
      expect(
        authDiagnostic.message,
        'Relay authentication failed (reason=invalid)',
      );
      expect(
        diagnostics.map((entry) => entry.message),
        everyElement(isNot(contains('auth-secret'))),
      );
      expect(authDiagnostic.message, isNot(contains('203.0.113.9')));
      expect(authDiagnostic.message, isNot(contains('2001:db8::4')));
    });

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

  group('relayNoticeForDiagnostics', () {
    test('strips Unicode controls and format characters, not just ASCII', () {
      // NEL is a C1 line break; the bidi override and zero-width joiner are
      // format characters that leave no visible trace but change how the
      // rest of the log line is read or copied.
      const notice = 'rate\u0085limited\u202e for\u200d now';

      final sanitized = relayNoticeForDiagnostics(notice);

      expect(sanitized, 'rate limited for now');
    });

    test('omits an identifier the length limit lands inside, whole', () {
      // 230 characters of prose put the 256-character limit 26 characters
      // into the event id, which is where a plain substring cut would leave
      // a partial id that looks usable and is not.
      final eventId = 'e' * 64;
      final notice = '${'w ' * 115}$eventId';

      final sanitized = relayNoticeForDiagnostics(notice);

      expect(sanitized, '${'w ' * 114}w … [truncated]');
    });

    test('keeps a message at exactly the length limit untouched', () {
      final notice = 'y' * 256;

      expect(relayNoticeForDiagnostics(notice), notice);
    });

    test('replaces an overlong message that has no token boundary', () {
      final sanitized = relayNoticeForDiagnostics('x' * 300);

      expect(sanitized, '[NOTICE omitted: message exceeds 256 characters]');
    });

    test('redacts encrypted signing material', () {
      final sanitized = relayNoticeForDiagnostics(
        'rejected ncryptsec1${'q' * 40} for this key',
      );

      expect(sanitized, 'rejected [REDACTED] for this key');
    });
  });

  group('relayRefusalCategoryForDiagnostics', () {
    test('categorizes a bare prefix carrying no human-readable half', () {
      // NIP-42's own example `OK` rejection is the prefix alone. Requiring a
      // colon reported it as `other`, which callers read as unclassified.
      expect(
        relayRefusalCategoryForDiagnostics('auth-required'),
        'auth-required',
      );
      expect(relayRefusalCategoryForDiagnostics('restricted'), 'restricted');
    });

    test('keeps the relay text out of the category', () {
      expect(
        relayRefusalCategoryForDiagnostics(
          'invalid: token=secret via 203.0.113.9',
        ),
        'invalid',
      );
    });

    test('matches the prefix rather than searching the whole message', () {
      // `blocked: too many failed auth attempts` is an account block, not a
      // NIP-42 problem; searching would send triage to the wrong place.
      expect(
        relayRefusalCategoryForDiagnostics(
          'blocked: too many failed auth-required attempts',
        ),
        'blocked',
      );
    });

    test('reports an unrecognized or absent prefix as other', () {
      expect(relayRefusalCategoryForDiagnostics('go away'), 'other');
      expect(relayRefusalCategoryForDiagnostics(''), 'other');
      expect(
        relayRefusalCategoryForDiagnostics('teapot: short and stout'),
        'other',
      );
    });

    test('maps every known prefix to itself', () {
      for (final prefix in relayRefusalPrefixes) {
        expect(
          relayRefusalCategoryForDiagnostics('$prefix: relay said so'),
          prefix,
          reason: 'one refusal vocabulary serves CLOSED and the AUTH OK path',
        );
      }
    });
  });
}
