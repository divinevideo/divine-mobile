// ABOUTME: Unit tests for VideoEvent blurhash parsing from kind 34236 Nostr events
// ABOUTME: Validates imeta tag parsing and blurhash extraction functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:models/models.dart';

void main() {
  group('VideoEvent blurhash parsing', () {
    test('should extract blurhash from imeta tag in kind 34236 event', () {
      // Arrange - Real event data with blurhash
      final eventTags = [
        ["d", "5vwdwxAM9r9"],
        ["title", "Gon & Killua"],
        [
          "imeta",
          "url https://api.openvine.co/media/1754036101685-cff088e5",
          "m video/mp4",
          "dim 640x640",
          "size 823129",
          "x cff088e5d7a6e60e9b184918a6ce986c02bc7232d6389ca7c323393fea37c35b",
          "blurhash U~NAr3ofRjj[oefQayay~qj[t6ofoza|oej[",
          "image https://api.openvine.co/media/1754036131638-5c4cb845",
        ],
        ["origin", "vine", "5vwdwxAM9r9", "https://vine.co/v/5vwdwxAM9r9"],
        ["vine_id", "5vwdwxAM9r9"],
        ["loops", "5416"],
        ["likes", "236"],
        ["h", "vine"],
        ["client", "openvine"],
        ["expiration", "1754122534"],
      ];

      // Add expiration tag to eventTags
      eventTags.add([
        'expiration',
        '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
      ]);

      final event = Event(
        "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef", // pubkey
        34236, // kind
        eventTags, // tags
        "Gon & Killua", // content
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Assert
      expect(
        videoEvent.blurhash,
        equals("U~NAr3ofRjj[oefQayay~qj[t6ofoza|oej["),
      );
      expect(
        videoEvent.videoUrl,
        equals("https://api.openvine.co/media/1754036101685-cff088e5"),
      );
      expect(
        videoEvent.thumbnailUrl,
        equals("https://api.openvine.co/media/1754036131638-5c4cb845"),
      );
      expect(videoEvent.mimeType, equals("video/mp4"));
      expect(videoEvent.dimensions, equals("640x640"));
      expect(videoEvent.fileSize, equals(823129));
      expect(
        videoEvent.sha256,
        equals(
          "cff088e5d7a6e60e9b184918a6ce986c02bc7232d6389ca7c323393fea37c35b",
        ),
      );
    });

    test('should extract blurhash from another real event format', () {
      // Arrange - Second real event with different blurhash
      final eventTags = [
        ["d", "5D3KYEaPzrn"],
        ["title", "(ㅍ_ㅍ) まいど！どうもお久しぶりです！ (号泣) #平野紫耀 #ジャニーズJr #まいジャニ #MrKING"],
        [
          "imeta",
          "url https://api.openvine.co/media/1754036101682-1a1905f3",
          "m video/mp4",
          "dim 640x640",
          "size 1036587",
          "x 1a1905f3170a63367c76059dd475f2dac3cf4bcec741b37c8313129604205f8f",
          "blurhash UEDb+[-q0Jt5-?X8ITM{4nM{tRR*?bkBRjxu",
          "image https://api.openvine.co/media/1754036131643-bbdd76bf",
        ],
        ["t", "mrking"],
        ["origin", "vine", "5D3KYEaPzrn", "https://vine.co/v/5D3KYEaPzrn"],
        ["vine_id", "5D3KYEaPzrn"],
        ["loops", "411"],
        ["likes", "9"],
        ["h", "vine"],
        ["client", "openvine"],
        ["expiration", "1754122534"],
      ];

      // Add expiration tag to eventTags
      eventTags.add([
        'expiration',
        '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
      ]);

      final event = Event(
        "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890", // pubkey
        34236, // kind
        eventTags, // tags
        "(ㅍ_ㅍ) まいど！どうもお久しぶりです！ (号泣) #平野紫耀 #ジャニーズJr #まいジャニ #MrKING", // content
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Assert
      expect(
        videoEvent.blurhash,
        equals("UEDb+[-q0Jt5-?X8ITM{4nM{tRR*?bkBRjxu"),
      );
      expect(
        videoEvent.videoUrl,
        equals("https://api.openvine.co/media/1754036101682-1a1905f3"),
      );
      expect(
        videoEvent.thumbnailUrl,
        equals("https://api.openvine.co/media/1754036131643-bbdd76bf"),
      );
    });

    test('should handle event without blurhash gracefully', () {
      // Arrange - Event without blurhash in imeta
      final eventTags = [
        ["d", "no_blurhash_test"],
        ["title", "Video without blurhash"],
        [
          "imeta",
          "url https://api.openvine.co/media/test-video",
          "m video/mp4",
          "dim 640x640",
          // No blurhash key-value pair
        ],
      ];

      // Add expiration tag to eventTags
      eventTags.add([
        'expiration',
        '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
      ]);

      final event = Event(
        "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321", // pubkey
        34236, // kind
        eventTags, // tags
        "Video without blurhash", // content
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Assert
      expect(videoEvent.blurhash, isNull);
      expect(
        videoEvent.videoUrl,
        equals("https://api.openvine.co/media/test-video"),
      );
    });

    test('should handle malformed imeta tag gracefully', () {
      // Arrange - Odd number of elements in imeta (missing value)
      final eventTags = [
        ["d", "malformed_test"],
        ["title", "Malformed imeta"],
        [
          "imeta",
          "url https://api.openvine.co/media/test-video",
          "m video/mp4",
          "blurhash", // Missing value - should not crash (malformed NIP-92 format)
        ],
      ];

      // Add expiration tag to eventTags
      eventTags.add([
        'expiration',
        '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
      ]);

      final event = Event(
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", // pubkey
        34236, // kind
        eventTags, // tags
        "Malformed imeta", // content
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Act & Assert - Should not throw
      expect(() => VideoEvent.fromNostrEvent(event), returnsNormally);

      final videoEvent = VideoEvent.fromNostrEvent(event);
      expect(
        videoEvent.blurhash,
        isNull,
      ); // Last key without value should be ignored
      expect(
        videoEvent.videoUrl,
        equals("https://api.openvine.co/media/test-video"),
      );
      expect(videoEvent.mimeType, equals("video/mp4"));
    });
  });
}
