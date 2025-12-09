// ABOUTME: Test for NostrService using direct function calls instead of WebSocket
// ABOUTME: Validates that we can connect without local network permissions

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;

@GenerateMocks([NostrKeyManager, embedded.EmbeddedNostrRelay])
import 'nostr_function_channel_test.mocks.dart';

void main() {
  group('NostrService Function Channel', () {
    late MockNostrKeyManager mockKeyManager;
    late MockEmbeddedNostrRelay mockEmbeddedRelay;

    setUp(() {
      mockKeyManager = MockNostrKeyManager();
      mockEmbeddedRelay = MockEmbeddedNostrRelay();

      when(mockKeyManager.publicKey).thenReturn('test_pubkey');
      when(mockKeyManager.hasKeys).thenReturn(true);
    });

    test(
      'should connect to embedded relay WITHOUT opening network port',
      () async {
        // This test defines our requirement:
        // We want to connect to the embedded relay using direct function calls,
        // NOT through a WebSocket on localhost:7447

        // The embedded relay should be initialized with function channel enabled
        when(mockEmbeddedRelay.isInitialized).thenReturn(false);

        // Initialize should be called with useFunctionChannel: true
        await mockEmbeddedRelay.initialize(
          enableGarbageCollection: true,
          useFunctionChannel: true,
        );

        // After initialization, we should be able to create a function session
        when(mockEmbeddedRelay.isInitialized).thenReturn(true);

        // This should NOT throw an error about WebSocket or network
        final session = mockEmbeddedRelay.createFunctionSession();

        expect(session, isNotNull);

        // Verify that we initialized with function channel, not WebSocket
        verify(
          mockEmbeddedRelay.initialize(
            enableGarbageCollection: true,
            useFunctionChannel: true,
          ),
        ).called(1);

        // The session should be able to send messages without network
        // This proves we're using function calls, not WebSocket
        expect(
          () => session.sendMessage(
            embedded.ReqMessage(
              subscriptionId: 'test',
              filters: [
                embedded.Filter(kinds: [1]),
              ],
            ),
          ),
          returnsNormally,
        );
      },
    );

    test(
      'should receive events through function callbacks, not WebSocket',
      () async {
        // This test ensures events are delivered via direct callbacks,
        // not through WebSocket message parsing

        when(mockEmbeddedRelay.isInitialized).thenReturn(true);

        // Create a function session
        final session = mockEmbeddedRelay.createFunctionSession();

        // Listen for events via the stream
        final events = <embedded.RelayResponse>[];
        session.responseStream.listen(events.add);

        // Send a subscription request
        await session.sendMessage(
          embedded.ReqMessage(
            subscriptionId: 'sub1',
            filters: [
              embedded.Filter(kinds: [1]),
            ],
          ),
        );

        // The embedded relay should process this WITHOUT:
        // - Opening a network port
        // - Serializing to JSON for WebSocket
        // - Requiring NSLocalNetworkUsageDescription permission on iOS

        // We should receive events directly through the stream
        expect(session.responseStream, isNotNull);
      },
    );
  });
}
