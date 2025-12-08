// ABOUTME: Unit tests for NIP71VideoKinds constants
// ABOUTME: Verifies correct video kind values per NIP-71 spec

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/nip71_migration.dart';

void main() {
  group('NIP71VideoKinds', () {
    test(
      'isVideoKind returns true for kind 34236 (addressable short video)',
      () {
        expect(NIP71VideoKinds.isVideoKind(34236), isTrue);
      },
    );

    test('isVideoKind returns false for kind 32222 (incorrect kind)', () {
      // This documents the bug: 32222 is NOT a valid video kind
      // The 'a' tag in reposts should use 34236, not 32222
      expect(NIP71VideoKinds.isVideoKind(32222), isFalse);
    });

    test('getAllVideoKinds returns only 34236', () {
      final kinds = NIP71VideoKinds.getAllVideoKinds();
      expect(kinds, equals([34236]));
      expect(kinds.contains(32222), isFalse);
    });

    test('getPreferredAddressableKind returns 34236', () {
      expect(NIP71VideoKinds.getPreferredAddressableKind(), equals(34236));
    });

    test('repost constant is 16 (NIP-18 generic repost)', () {
      expect(NIP71VideoKinds.repost, equals(16));
    });

    group('addressable ID format validation', () {
      test('correct format uses 34236 in a tag', () {
        // The correct addressable ID format for a video repost is:
        // 34236:pubkey:d-tag
        const correctAddressableId = '34236:abc123:video-d-tag';
        final parts = correctAddressableId.split(':');
        expect(parts.length, greaterThanOrEqualTo(3));

        final kind = int.tryParse(parts[0]);
        expect(kind, equals(34236));
        expect(NIP71VideoKinds.isVideoKind(kind!), isTrue);
      });

      test('incorrect format with 32222 fails isVideoKind check', () {
        // This is the bug: reposts were being created with 32222 instead of 34236
        const buggyAddressableId = '32222:abc123:video-d-tag';
        final parts = buggyAddressableId.split(':');

        final kind = int.tryParse(parts[0]);
        expect(kind, equals(32222));
        expect(NIP71VideoKinds.isVideoKind(kind!), isFalse);
      });
    });
  });
}
