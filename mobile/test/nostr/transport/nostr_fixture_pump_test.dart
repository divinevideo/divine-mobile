// ABOUTME: Tests for NDJSON fixture loader for Nostr testing
// ABOUTME: Verifies fixture files are parsed and injected correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/nostr/transport/in_memory_transport.dart';
import 'package:openvine/nostr/transport/nostr_fixture_pump.dart';

void main() {
  group('NostrFixturePump', () {
    test('loads and injects NDJSON fixture lines', () async {
      final transport = InMemoryNostrTransport();
      addTearDown(transport.dispose);

      final messages = <String>[];
      transport.incoming.listen(messages.add);

      // Fixture content as string (simulating file content)
      const fixtureContent = '''
["EVENT","sub1",{"id":"abc","kind":1}]
["EVENT","sub1",{"id":"def","kind":1}]
["EOSE","sub1"]
''';

      final pump = NostrFixturePump(transport);
      pump.pumpFromString(fixtureContent);

      await Future.delayed(Duration.zero); // Flush microtasks

      expect(messages, [
        '["EVENT","sub1",{"id":"abc","kind":1}]',
        '["EVENT","sub1",{"id":"def","kind":1}]',
        '["EOSE","sub1"]',
      ]);
    });

    test('skips empty lines and trims whitespace', () async {
      final transport = InMemoryNostrTransport();
      addTearDown(transport.dispose);

      final messages = <String>[];
      transport.incoming.listen(messages.add);

      const fixtureContent = '''

["EVENT","sub1",{"id":"abc"}]

["EOSE","sub1"]

''';

      final pump = NostrFixturePump(transport);
      pump.pumpFromString(fixtureContent);

      await Future.delayed(Duration.zero);

      expect(messages, ['["EVENT","sub1",{"id":"abc"}]', '["EOSE","sub1"]']);
    });

    test('handles malformed JSON by throwing exception', () {
      final transport = InMemoryNostrTransport();
      addTearDown(transport.dispose);

      const fixtureContent = '''
["EVENT","sub1",{"id":"abc"}]
{this is not valid JSON}
["EOSE","sub1"]
''';

      final pump = NostrFixturePump(transport);

      expect(
        () => pump.pumpFromString(fixtureContent),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates Nostr message format', () {
      final transport = InMemoryNostrTransport();
      addTearDown(transport.dispose);

      // Valid JSON but not a Nostr message (not an array)
      const fixtureContent = '{"event": "data"}';

      final pump = NostrFixturePump(transport);

      expect(
        () => pump.pumpFromString(fixtureContent),
        throwsA(isA<FormatException>()),
      );
    });

    test('can pump multiple fixtures sequentially', () async {
      final transport = InMemoryNostrTransport();
      addTearDown(transport.dispose);

      final messages = <String>[];
      transport.incoming.listen(messages.add);

      const fixture1 = '["EVENT","sub1",{"id":"abc"}]';
      const fixture2 = '["EVENT","sub2",{"id":"def"}]';

      final pump = NostrFixturePump(transport);
      pump.pumpFromString(fixture1);
      pump.pumpFromString(fixture2);

      await Future.delayed(Duration.zero);

      expect(messages, [
        '["EVENT","sub1",{"id":"abc"}]',
        '["EVENT","sub2",{"id":"def"}]',
      ]);
    });
  });
}
