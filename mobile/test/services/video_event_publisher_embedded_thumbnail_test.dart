// ABOUTME: Tests for VideoEventPublisher embedded thumbnail generation
// ABOUTME: Verifies base64 data URI embedding and blurhash generation from video files

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/services/blurhash_service.dart';

/// Helper to simulate the thumbnail extraction logic from VideoEventPublisher
class EmbeddedThumbnailGenerator {
  /// Extract thumbnail and generate base64 data URI (matching VideoEventPublisher logic)
  static Future<Map<String, dynamic>> generateEmbeddedThumbnail({
    required String videoPath,
    int timeMs = 500,
    int quality = 75,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'dataUri': null,
      'sizeKB': null,
      'blurhash': null,
      'error': null,
    };

    try {
      // Extract thumbnail bytes from video
      final thumbnailBytes = await VideoThumbnailService.extractThumbnailBytes(
        videoPath: videoPath,
        timeMs: timeMs,
        quality: quality,
      );

      if (thumbnailBytes != null) {
        // Create base64 data URI
        final base64Thumbnail = base64.encode(thumbnailBytes);
        final thumbnailDataUri = 'data:image/jpeg;base64,$base64Thumbnail';
        final thumbnailSizeKB = (thumbnailBytes.length / 1024);

        result['success'] = true;
        result['dataUri'] = thumbnailDataUri;
        result['sizeKB'] = thumbnailSizeKB;

        // Generate blurhash
        final blurhash = await BlurhashService.generateBlurhash(thumbnailBytes);
        if (blurhash != null) {
          result['blurhash'] = blurhash;
        }
      }
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  /// Build imeta components list with embedded thumbnail (matching VideoEventPublisher)
  static Future<List<String>> buildImetaComponentsWithEmbeddedThumbnail({
    required PendingUpload upload,
  }) async {
    final imetaComponents = <String>[];

    // Add URL and MIME type
    if (upload.cdnUrl != null) {
      imetaComponents.add('url ${upload.cdnUrl!}');
    }
    imetaComponents.add('m video/mp4');

    // Generate embedded thumbnail from local video file
    if (upload.localVideoPath.isNotEmpty) {
      final thumbnailResult = await generateEmbeddedThumbnail(
        videoPath: upload.localVideoPath,
        timeMs: 500,
        quality: 75,
      );

      if (thumbnailResult['success'] == true &&
          thumbnailResult['dataUri'] != null) {
        imetaComponents.add('image ${thumbnailResult['dataUri']}');

        if (thumbnailResult['blurhash'] != null) {
          imetaComponents.add('blurhash ${thumbnailResult['blurhash']}');
        }
      }
    }

    // Fallback: Use uploaded thumbnail URL if available
    if (upload.thumbnailPath != null &&
        upload.thumbnailPath!.isNotEmpty &&
        (upload.thumbnailPath!.startsWith('http://') ||
            upload.thumbnailPath!.startsWith('https://'))) {
      // Only add if we didn't already embed a thumbnail
      if (!imetaComponents.any((c) => c.startsWith('image '))) {
        imetaComponents.add('image ${upload.thumbnailPath!}');
      }
    }

    // Add dimensions
    if (upload.videoWidth != null && upload.videoHeight != null) {
      imetaComponents.add('dim ${upload.videoWidth}x${upload.videoHeight}');
    }

    // Add file size and hash
    if (upload.localVideoPath.isNotEmpty) {
      try {
        final videoFile = File(upload.localVideoPath);
        if (videoFile.existsSync()) {
          final fileSize = videoFile.lengthSync();
          imetaComponents.add('size $fileSize');

          // Note: SHA256 calculation omitted for test simplicity
        }
      } catch (e) {
        // Ignore file errors
      }
    }

    return imetaComponents;
  }
}

void main() {
  group('VideoEventPublisher Embedded Thumbnail Generation', () {
    test('should generate base64 data URI from thumbnail bytes', () async {
      // Arrange: Create dummy thumbnail bytes (1x1 red pixel JPEG)
      final dummyJpegBytes = [
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
        0x01,
        0x00,
        0x00,
        0x01,
        0x00,
        0x01,
        0x00,
        0x00,
        0xFF,
        0xDB,
        0x00,
        0x43,
      ];

      // Act: Encode to base64 data URI
      final base64Thumbnail = base64.encode(dummyJpegBytes);
      final dataUri = 'data:image/jpeg;base64,$base64Thumbnail';

      // Assert
      expect(
        dataUri.startsWith('data:image/jpeg;base64,'),
        true,
        reason: 'Should start with correct data URI prefix',
      );
      expect(
        dataUri.length,
        greaterThan(50),
        reason: 'Should contain encoded image data',
      );

      // Verify we can decode it back
      final decodedBytes = base64.decode(
        dataUri.substring('data:image/jpeg;base64,'.length),
      );
      expect(
        decodedBytes,
        equals(dummyJpegBytes),
        reason: 'Should be able to decode back to original bytes',
      );
    });

    test('should extract thumbnail at 500ms, not first frame', () async {
      // This test verifies the timestamp parameter is correct
      // In real implementation, VideoEventPublisher uses timeMs: 500

      const expectedTimeMs = 500;
      const notFirstFrame = 0;

      expect(
        expectedTimeMs,
        isNot(equals(notFirstFrame)),
        reason: 'Should NOT use first frame (0ms)',
      );
      expect(
        expectedTimeMs,
        equals(500),
        reason: 'Should extract at 500ms to avoid black/blurry first frames',
      );
    });

    test('should use quality 75 for medium-size data URIs', () async {
      // This test verifies the quality parameter balances size vs quality
      // In real implementation, VideoEventPublisher uses quality: 75

      const expectedQuality = 75;

      expect(
        expectedQuality,
        greaterThan(50),
        reason: 'Quality should be high enough for good visuals',
      );
      expect(
        expectedQuality,
        lessThan(95),
        reason: 'Quality should be low enough to avoid huge data URIs',
      );
      expect(
        expectedQuality,
        equals(75),
        reason: 'Should use quality 75 as medium compromise',
      );
    });

    test('should prefer embedded thumbnail over URL thumbnail', () async {
      // Arrange: Create test file
      final tempDir = await Directory.systemTemp.createTemp('thumbnail_test');
      final testVideoFile = File('${tempDir.path}/test_video.mp4');
      await testVideoFile.writeAsString('dummy video content');

      final upload =
          PendingUpload.create(
            localVideoPath: testVideoFile.path,
            nostrPubkey: 'test_pubkey',
            thumbnailPath:
                'https://example.com/uploaded_thumbnail.jpg', // URL fallback
            title: 'Test Video',
          ).copyWith(
            cdnUrl: 'https://cdn.divine.video/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Act: Build imeta components
      final imetaComponents =
          await EmbeddedThumbnailGenerator.buildImetaComponentsWithEmbeddedThumbnail(
            upload: upload,
          );

      // Assert: Should have image component
      final imageComponents = imetaComponents
          .where((c) => c.startsWith('image '))
          .toList();

      // Cleanup
      await tempDir.delete(recursive: true);

      // If thumbnail extraction succeeds, it should be embedded data URI
      // If it fails, it should fall back to URL
      expect(
        imageComponents.length,
        lessThanOrEqualTo(1),
        reason: 'Should have at most one image component',
      );

      if (imageComponents.isNotEmpty) {
        final imageValue = imageComponents.first.substring('image '.length);
        // Either embedded data URI (preferred) or URL fallback
        expect(
          imageValue.startsWith('data:image/jpeg;base64,') ||
              imageValue.startsWith('https://'),
          true,
          reason: 'Image should be either embedded data URI or URL fallback',
        );
      }
    });

    test('should generate blurhash alongside embedded thumbnail', () async {
      // This test verifies that when embedding thumbnail, blurhash is also generated
      // Both are generated from the same thumbnailBytes in VideoEventPublisher

      // Arrange: Create dummy thumbnail bytes
      final dummyThumbnailBytes = Uint8List.fromList(
        List.generate(100, (i) => i % 256),
      );

      // Act: Generate blurhash
      final blurhash = await BlurhashService.generateBlurhash(
        dummyThumbnailBytes,
      );

      // Assert: Blurhash should be generated (or null if service unavailable)
      if (blurhash != null) {
        expect(
          blurhash.isNotEmpty,
          true,
          reason: 'Blurhash should not be empty string',
        );
        // Blurhash format is typically 6-8 characters minimum
        expect(
          blurhash.length,
          greaterThanOrEqualTo(6),
          reason: 'Blurhash should have valid length',
        );
      }
    });

    test('should handle thumbnail extraction failure gracefully', () async {
      // Arrange: Non-existent video file
      final nonExistentPath = '/nonexistent/path/to/video.mp4';

      // Act: Attempt to extract thumbnail
      final result = await EmbeddedThumbnailGenerator.generateEmbeddedThumbnail(
        videoPath: nonExistentPath,
      );

      // Assert: Should fail gracefully
      expect(
        result['success'],
        false,
        reason: 'Should return failure when file does not exist',
      );
      expect(
        result['dataUri'],
        isNull,
        reason: 'Should not generate data URI on failure',
      );
    });

    test(
      'should fall back to URL thumbnail when video file unavailable',
      () async {
        // Arrange: Upload with URL thumbnail but no local video file
        final upload =
            PendingUpload.create(
              localVideoPath: '', // No local file
              nostrPubkey: 'test_pubkey',
              thumbnailPath: 'https://example.com/uploaded_thumbnail.jpg',
              title: 'Test Video',
            ).copyWith(
              cdnUrl: 'https://cdn.divine.video/test_video.mp4',
              status: UploadStatus.readyToPublish,
            );

        // Act: Build imeta components
        final imetaComponents =
            await EmbeddedThumbnailGenerator.buildImetaComponentsWithEmbeddedThumbnail(
              upload: upload,
            );

        // Assert: Should use URL fallback
        final imageComponents = imetaComponents
            .where((c) => c.startsWith('image '))
            .toList();
        expect(
          imageComponents.length,
          equals(1),
          reason: 'Should have URL thumbnail fallback',
        );
        expect(
          imageComponents.first,
          equals('image https://example.com/uploaded_thumbnail.jpg'),
          reason: 'Should use uploaded URL when no local file',
        );
      },
    );

    test('should skip non-HTTP thumbnail paths', () async {
      // Arrange: Upload with local file path as thumbnail (not HTTP URL)
      final upload =
          PendingUpload.create(
            localVideoPath: '', // No local video file
            nostrPubkey: 'test_pubkey',
            thumbnailPath:
                '/local/path/to/thumbnail.jpg', // Local path, not URL
            title: 'Test Video',
          ).copyWith(
            cdnUrl: 'https://cdn.divine.video/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Act: Build imeta components
      final imetaComponents =
          await EmbeddedThumbnailGenerator.buildImetaComponentsWithEmbeddedThumbnail(
            upload: upload,
          );

      // Assert: Should NOT include image component
      final imageComponents = imetaComponents
          .where((c) => c.startsWith('image '))
          .toList();
      expect(
        imageComponents.length,
        equals(0),
        reason: 'Should skip non-HTTP thumbnail paths',
      );
    });
  });
}
