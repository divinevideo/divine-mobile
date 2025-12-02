// ABOUTME: Test file to validate that all exported classes and functions are accessible
// ABOUTME: Systematically tests imports from the main package to catch export issues

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('Package Exports Validation', () {
    test('Core classes are exported and importable', () {
      // Test that we can reference core classes
      expect(Nostr, isA<Type>());
      expect(Event, isA<Type>());
      expect(EventKind, isA<Type>());
      expect(Subscription, isA<Type>());
    });

    test('Signing implementations are exported', () {
      expect(NostrSigner, isA<Type>());
      expect(LocalNostrSigner, isA<Type>());
      expect(PubkeyOnlyNostrSigner, isA<Type>());
    });

    test('Relay classes are exported', () {
      expect(Relay, isA<Type>());
      expect(RelayPool, isA<Type>());
      expect(RelayStatus, isA<Type>());
      expect(RelayType, isA<Type>());
      expect(EventFilter, isA<Type>());
    });

    test('Essential NIP implementations are exported', () {
      expect(Contact, isA<Type>());
      expect(ContactList, isA<Type>());
      expect(Nip19, isA<Type>());
      expect(GroupIdentifier, isA<Type>());
    });

    test('Utility classes are exported', () {
      expect(StringUtil, isA<Type>());
      expect(DateFormatUtil, isA<Type>());
      expect(UploadUtil, isA<Type>());
    });

    test('Event kind constants are accessible', () {
      expect(EventKind.TEXT_NOTE, equals(1));
      expect(EventKind.METADATA, equals(0));
      expect(EventKind.CONTACT_LIST, equals(3));
      expect(EventKind.DIRECT_MESSAGE, equals(4));
      expect(EventKind.REACTION, equals(7));
    });

    test('Relay type constants are accessible', () {
      expect(RelayType.NORMAL, equals(1));
      expect(RelayType.TEMP, equals(2));
      expect(RelayType.CACHE, equals(4));
      expect(RelayType.ALL, isA<List<int>>());
    });
  });
}
