// ABOUTME: Tests NostrClient.countEvents: completeness is passed through and a
// ABOUTME: redial asks again within what is left of the caller's timeout.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class _MockNostr extends Mock implements Nostr {}

class _MockRelayManager extends Mock implements RelayManager {}

void main() {
  group('NostrClient.countEvents', () {
    setUpAll(() {
      registerFallbackValue(Duration.zero);
      registerFallbackValue(<Map<String, dynamic>>[]);
      registerFallbackValue(<int>[]);
    });

    test(
      'reports a count another relay did not settle as incomplete',
      () async {
        final nostr = _MockNostr();
        final relayManager = _MockRelayManager();
        when(
          () => nostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => const CountResponse(count: 3, isComplete: false),
        );
        when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
        final client = NostrClient.forTesting(
          nostr: nostr,
          relayManager: relayManager,
        );

        final result = await client.countEvents([
          Filter(kinds: [EventKind.reaction]),
        ]);

        expect(result.count, equals(3));
        expect(result.isComplete, isFalse);
      },
    );

    test('asks again with what is left of the caller timeout after a 2 s '
        'redial', () {
      fakeAsync((async) {
        final nostr = _MockNostr();
        final relayManager = _MockRelayManager();
        final budgets = <Duration>[];
        when(
          () => nostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          budgets.add(invocation.namedArguments[#timeout] as Duration);
          if (budgets.length == 1) {
            throw CountNotSentException('No relay accepted COUNT');
          }
          return const CountResponse(isComplete: true, count: 4);
        });
        when(
          relayManager.retryDisconnectedRelays,
        ).thenAnswer((_) => Future<void>.delayed(const Duration(seconds: 2)));
        when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
        final client = NostrClient.forTesting(
          nostr: nostr,
          relayManager: relayManager,
        );

        int? count;
        unawaited(
          client
              .countEvents([
                Filter(kinds: [EventKind.reaction]),
              ])
              .then((r) => count = r.count),
        );
        async
          ..elapse(const Duration(seconds: 3))
          ..flushMicrotasks();

        expect(count, equals(4));
        expect(budgets, hasLength(2));
        expect(budgets.first, equals(const Duration(seconds: 5)));
        expect(budgets.last, equals(const Duration(seconds: 3)));
      }, initialTime: DateTime.utc(2000));
    });
  });
}
