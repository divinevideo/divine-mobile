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
      expect(EventKind.textNote, equals(1));
      expect(EventKind.metadata, equals(0));
      expect(EventKind.contactList, equals(3));
      expect(EventKind.directMessage, equals(4));
      expect(EventKind.reaction, equals(7));
    });

    test('Relay type constants are accessible', () {
      expect(RelayType.normal, equals(1));
      expect(RelayType.temp, equals(2));
      expect(RelayType.cache, equals(4));
      expect(RelayType.all, isA<List<int>>());
    });
  });
}
