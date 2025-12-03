// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:nostr_client/nostr_client.dart';
import 'package:test/test.dart';

void main() {
  group('NostrClient', () {
    test('can be instantiated', () {
      expect(NostrClient(), isNotNull);
    });
  });
}
