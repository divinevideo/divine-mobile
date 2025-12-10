// ABOUTME: TDD tests for NostrService.publishFileMetadata() method
// ABOUTME: Tests NIP-94 file metadata publishing with proper validation and error handling

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart'
    show NIP94Metadata, NIP94ValidationException;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/nostr_service_interface.dart';

import '../helpers/test_nostr_service.dart';

void main() {
  group('NostrService.publishFileMetadata() - TDD', () {
    late TestNostrService nostrService;

    setUp(() async {
      nostrService = TestNostrService();
      await nostrService.initialize();
    });

    tearDown(() {
      nostrService.dispose();
    });

    group('Validation Tests', () {
      test(
        'should throw NIP94ValidationException for invalid metadata',
        () async {
          // Arrange - Create invalid metadata (empty sha256Hash)
          final invalidMetadata = NIP94Metadata(
            url: 'https://example.com/video.mp4',
            mimeType: 'video/mp4',
            sha256Hash: '', // Invalid - empty hash
            sizeBytes: 1024,
            dimensions: '640x480',
          );

          // Act & Assert
          expect(
            () => nostrService.publishFileMetadata(
              metadata: invalidMetadata,
              content: 'Test video',
            ),
            throwsA(isA<NIP94ValidationException>()),
          );
        },
      );

      test('should throw StateError when no keys available', () async {
        // Arrange - Valid metadata but no keys
        final validMetadata = NIP94Metadata(
          url: 'https://example.com/video.mp4',
          mimeType: 'video/mp4',
          sha256Hash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          sizeBytes: 1024,
          dimensions: '640x480',
        );

        // Ensure no keys are loaded in test service
        expect(nostrService.hasKeys, isFalse);

        // Act & Assert
        expect(
          () => nostrService.publishFileMetadata(
            metadata: validMetadata,
            content: 'Test video',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Event Creation Tests', () {
      test(
        'should create NIP-94 event (kind 1063) with valid metadata',
        () async {
          // Arrange - Set a test pubkey
          final privateKey = generatePrivateKey();
          final publicKey = getPublicKey(privateKey);
          nostrService.setCurrentUserPubkey(publicKey);

          final metadata = NIP94Metadata(
            url: 'https://example.com/video.mp4',
            mimeType: 'video/mp4',
            sha256Hash:
                'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            sizeBytes: 1048576,
            dimensions: '1920x1080',
            blurhash: 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
            altText: 'Test video alt text',
            durationMs: 30000,
          );

          // Act
          final result = await nostrService.publishFileMetadata(
            metadata: metadata,
            content: 'Test video description',
            hashtags: ['test', 'video'],
          );

          // Assert
          expect(result, isA<NostrBroadcastResult>());
          expect(result.event.kind, equals(1063)); // NIP-94 kind

          // Verify required tags are present
          final tags = result.event.tags;
          expect(tags.any((tag) => tag[0] == 'url'), isTrue);
          expect(tags.any((tag) => tag[0] == 'm'), isTrue); // mimeType
          expect(tags.any((tag) => tag[0] == 'x'), isTrue); // sha256Hash
          expect(tags.any((tag) => tag[0] == 'size'), isTrue);
          expect(tags.any((tag) => tag[0] == 'dim'), isTrue);

          // Verify optional tags
          expect(tags.any((tag) => tag[0] == 'blurhash'), isTrue);
          expect(tags.any((tag) => tag[0] == 'alt'), isTrue);
          expect(tags.any((tag) => tag[0] == 'duration'), isTrue);

          // Verify hashtags
          expect(tags.any((tag) => tag[0] == 't' && tag[1] == 'test'), isTrue);
          expect(tags.any((tag) => tag[0] == 't' && tag[1] == 'video'), isTrue);

          // Verify event pubkey and content
          expect(result.event.pubkey, equals(publicKey));
          expect(result.event.content, equals('Test video description'));
        },
      );

      test('should include all optional metadata fields when provided', () async {
        // Arrange
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        nostrService.setCurrentUserPubkey(publicKey);

        final metadata = NIP94Metadata(
          url: 'https://example.com/video.mp4',
          mimeType: 'video/mp4',
          sha256Hash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          sizeBytes: 2097152,
          dimensions: '3840x2160',
          blurhash: 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
          altText: 'High resolution test video',
          summary: 'A summary of the video',
          durationMs: 60000,
          fps: 60.0,
          thumbnailUrl: 'https://example.com/thumb.jpg',
          originalHash:
              'a3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          additionalTags: {'custom': 'value'},
        );

        // Act
        final result = await nostrService.publishFileMetadata(
          metadata: metadata,
          content: 'Complete metadata test',
        );

        // Assert
        final tags = result.event.tags;
        expect(tags.any((tag) => tag[0] == 'blurhash'), isTrue);
        expect(tags.any((tag) => tag[0] == 'alt'), isTrue);
        expect(tags.any((tag) => tag[0] == 'summary'), isTrue);
        expect(tags.any((tag) => tag[0] == 'duration'), isTrue);
        expect(tags.any((tag) => tag[0] == 'fps'), isTrue);
        expect(tags.any((tag) => tag[0] == 'thumb'), isTrue);
        expect(tags.any((tag) => tag[0] == 'ox'), isTrue); // original hash
        expect(
          tags.any((tag) => tag[0] == 'custom' && tag[1] == 'value'),
          isTrue,
        );
      });
    });

    group('Broadcasting Tests', () {
      test('should broadcast event to embedded relay', () async {
        // Arrange
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        nostrService.setCurrentUserPubkey(publicKey);

        final metadata = NIP94Metadata(
          url: 'https://example.com/video.mp4',
          mimeType: 'video/mp4',
          sha256Hash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          sizeBytes: 1024,
          dimensions: '640x480',
        );

        // Act
        final result = await nostrService.publishFileMetadata(
          metadata: metadata,
          content: 'Broadcast test',
        );

        // Assert
        expect(result.isSuccessful, isTrue);
        expect(result.totalRelays, greaterThan(0));
        expect(result.successCount, greaterThan(0));
      });

      test('should return broadcast results with relay status', () async {
        // Arrange
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        nostrService.setCurrentUserPubkey(publicKey);

        final metadata = NIP94Metadata(
          url: 'https://example.com/video.mp4',
          mimeType: 'video/mp4',
          sha256Hash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          sizeBytes: 1024,
          dimensions: '640x480',
        );

        // Act
        final result = await nostrService.publishFileMetadata(
          metadata: metadata,
          content: 'Result test',
        );

        // Assert
        expect(result, isA<NostrBroadcastResult>());
        expect(result.results, isA<Map<String, bool>>());
        expect(result.errors, isA<Map<String, String>>());
        expect(result.successfulRelays, isA<List<String>>());
        expect(result.failedRelays, isA<List<String>>());
      });
    });

    group('Edge Cases', () {
      test('should handle metadata with minimal required fields only', () async {
        // Arrange
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        nostrService.setCurrentUserPubkey(publicKey);

        final minimalMetadata = NIP94Metadata(
          url: 'https://example.com/minimal.mp4',
          mimeType: 'video/mp4',
          sha256Hash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          sizeBytes: 512,
          dimensions: '320x240',
        );

        // Act
        final result = await nostrService.publishFileMetadata(
          metadata: minimalMetadata,
          content: 'Minimal test',
        );

        // Assert
        expect(result.isSuccessful, isTrue);
        expect(result.event.kind, equals(1063));

        // Verify only required tags are present
        final tags = result.event.tags;
        expect(tags.any((tag) => tag[0] == 'url'), isTrue);
        expect(tags.any((tag) => tag[0] == 'm'), isTrue);
        expect(tags.any((tag) => tag[0] == 'x'), isTrue);
        expect(tags.any((tag) => tag[0] == 'size'), isTrue);
        expect(tags.any((tag) => tag[0] == 'dim'), isTrue);

        // Verify optional tags are NOT present
        expect(tags.any((tag) => tag[0] == 'blurhash'), isFalse);
        expect(tags.any((tag) => tag[0] == 'alt'), isFalse);
        expect(tags.any((tag) => tag[0] == 'duration'), isFalse);
      });

      test('should handle empty hashtags array', () async {
        // Arrange
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        nostrService.setCurrentUserPubkey(publicKey);

        final metadata = NIP94Metadata(
          url: 'https://example.com/video.mp4',
          mimeType: 'video/mp4',
          sha256Hash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          sizeBytes: 1024,
          dimensions: '640x480',
        );

        // Act
        final result = await nostrService.publishFileMetadata(
          metadata: metadata,
          content: 'No hashtags test',
          hashtags: [],
        );

        // Assert
        expect(result.isSuccessful, isTrue);

        // Verify no hashtag tags are present
        final tags = result.event.tags;
        expect(tags.where((tag) => tag[0] == 't').length, equals(0));
      });

      test('should validate all metadata fields before publishing', () async {
        // Arrange - Invalid hash length
        final invalidHashMetadata = NIP94Metadata(
          url: 'https://example.com/video.mp4',
          mimeType: 'video/mp4',
          sha256Hash: 'invalid_hash', // Invalid - wrong length
          sizeBytes: 1024,
          dimensions: '640x480',
        );

        // Act & Assert
        expect(
          () => nostrService.publishFileMetadata(
            metadata: invalidHashMetadata,
            content: 'Test',
          ),
          throwsA(isA<NIP94ValidationException>()),
        );
      });
    });
  });
}
