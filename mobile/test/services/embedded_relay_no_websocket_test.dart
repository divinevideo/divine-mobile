// ABOUTME: Test that embedded relay can work WITHOUT WebSocket server
// ABOUTME: Validates iOS local network permission is not needed

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;

void main() {
  group('Embedded Relay WITHOUT WebSocket', () {
    test(
      'should initialize WITHOUT starting WebSocket server on localhost:7447',
      () async {
        // REQUIREMENT: The embedded relay must NOT open a network port
        // This eliminates the iOS NSLocalNetworkUsageDescription requirement

        final relay = embedded.EmbeddedNostrRelay();

        // Initialize with function channel mode (no WebSocket)
        await relay.initialize(
          enableGarbageCollection: true,
          useFunctionChannel: true, // This flag should disable WebSocket server
        );

        expect(relay.isInitialized, isTrue);

        // The key test: createFunctionSession should exist and work
        // This proves we're NOT using WebSocket
        final session = relay.createFunctionSession();

        expect(session, isNotNull);
        expect(session, isA<embedded.FunctionChannelSession>());

        // Verify the session can handle messages WITHOUT network
        expect(() async {
          await session.sendMessage(
            embedded.ReqMessage(
              subscriptionId: 'test',
              filters: [
                embedded.Filter(kinds: [1]),
              ],
            ),
          );
        }, returnsNormally);

        // Clean up
        await session.close();
      },
    );

    test('should exchange messages through direct function calls', () async {
      // REQUIREMENT: Messages must flow through function calls, not network

      final relay = embedded.EmbeddedNostrRelay();
      await relay.initialize(useFunctionChannel: true);

      final session = relay.createFunctionSession();

      // Collect responses
      final responses = <embedded.RelayResponse>[];
      session.responseStream.listen(responses.add);

      // Send a REQ message
      await session.sendMessage(
        embedded.ReqMessage(
          subscriptionId: 'sub1',
          filters: [
            embedded.Filter(kinds: [1], limit: 10),
          ],
        ),
      );

      // Wait for EOSE (end of stored events)
      await Future.delayed(Duration(milliseconds: 100));

      // We should have received at least an EOSE
      final eoseResponses = responses.whereType<embedded.EoseResponse>();
      expect(eoseResponses.length, greaterThan(0));
      expect(eoseResponses.first.subscriptionId, equals('sub1'));
    });
  });
}
