// ABOUTME: Tests for in-memory Nostr transport implementation
// ABOUTME: Verifies bidirectional message flow without network IO

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/nostr/transport/in_memory_transport.dart';

void main() {
  group('InMemoryNostrTransport', () {
    test('incoming stream receives injected relay messages', () async {
      final transport = InMemoryNostrTransport();
      addTearDown(transport.dispose);

      final messages = <String>[];
      transport.incoming.listen(messages.add);

      transport.injectFromRelay('["EVENT","sub1",{"id":"abc"}]');
      transport.injectFromRelay('["EOSE","sub1"]');

      await Future.delayed(Duration.zero); // Flush microtasks

      expect(messages, ['["EVENT","sub1",{"id":"abc"}]', '["EOSE","sub1"]']);
    });

    test('send() adds messages to outgoing stream', () async {
      final transport = InMemoryNostrTransport();
      addTearDown(transport.dispose);

      final outgoing = <String>[];
      transport.outgoingFromClient.listen(outgoing.add);

      transport.send('["REQ","sub1",{"kinds":[1]}]');
      transport.send('["CLOSE","sub1"]');

      await Future.delayed(Duration.zero); // Flush microtasks

      expect(outgoing, ['["REQ","sub1",{"kinds":[1]}]', '["CLOSE","sub1"]']);
    });

    test('dispose closes both streams', () {
      final transport = InMemoryNostrTransport();

      bool incomingClosed = false;
      bool outgoingClosed = false;

      transport.incoming.listen(null, onDone: () => incomingClosed = true);
      transport.outgoingFromClient.listen(
        null,
        onDone: () => outgoingClosed = true,
      );

      transport.dispose();

      expect(incomingClosed, isTrue);
      expect(outgoingClosed, isTrue);
    });

    test('ignores messages after disposal', () async {
      final transport = InMemoryNostrTransport();

      final messages = <String>[];
      transport.incoming.listen(messages.add);

      transport.injectFromRelay('["EVENT","sub1",{"id":"abc"}]');
      await Future.delayed(Duration.zero);

      transport.dispose();

      // These should be ignored
      transport.injectFromRelay('["EVENT","sub2",{"id":"def"}]');
      transport.send('["REQ","sub2",{}]');

      await Future.delayed(Duration.zero);

      expect(messages, ['["EVENT","sub1",{"id":"abc"}]']);
    });

    test('supports multiple listeners on broadcast streams', () async {
      final transport = InMemoryNostrTransport();
      addTearDown(transport.dispose);

      final listener1 = <String>[];
      final listener2 = <String>[];

      transport.incoming.listen(listener1.add);
      transport.incoming.listen(listener2.add);

      transport.injectFromRelay('["EVENT","sub1",{"id":"abc"}]');

      await Future.delayed(Duration.zero);

      expect(listener1, ['["EVENT","sub1",{"id":"abc"}]']);
      expect(listener2, ['["EVENT","sub1",{"id":"abc"}]']);
    });
  });
}
