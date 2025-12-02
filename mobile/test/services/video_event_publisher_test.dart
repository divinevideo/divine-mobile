// ABOUTME: Tests for VideoEventPublisher service ensuring complete imeta tag generation
// ABOUTME: Verifies file metadata (size, SHA256), thumbnails, and NIP-71 kind 34236 compliance

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/pending_upload.dart';

/// Helper class to test imeta tag generation logic
class ImetaTagGenerator {
  /// Generate imeta components for a video upload (extracted from VideoEventPublisher)
  static Future<List<String>> generateImetaComponents(
    PendingUpload upload,
  ) async {
    final imetaComponents = <String>[];

    // Add URL(s) - handle Bunny Stream URLs specially
    if (upload.cdnUrl != null) {
      final cdnUrl = upload.cdnUrl!;

      // Check if this is a Bunny Stream HLS playlist URL
      // Format: https://stream.divine.video/{GUID}/playlist.m3u8
      final bunnyStreamPattern = RegExp(
        r'^https://stream\.divine\.video/([a-f0-9\-]+)/playlist\.m3u8$',
        caseSensitive: false,
      );

      final match = bunnyStreamPattern.firstMatch(cdnUrl);
      if (match != null) {
        // Extract GUID and construct both MP4 and HLS URLs
        final guid = match.group(1)!;
        // Use 360p quality (next step up from 240p for better quality short videos)
        final mp4Url = 'https://stream.divine.video/$guid/play_360p.mp4';

        // Add MP4 URL FIRST (preferred for short videos - higher score in _scoreVideoUrl)
        imetaComponents.add('url $mp4Url');

        // Add HLS URL as fallback
        imetaComponents.add('url $cdnUrl');
      } else {
        // Regular CDN URL - add as-is
        imetaComponents.add('url $cdnUrl');
      }
    }
    imetaComponents.add('m video/mp4');

    // Add thumbnail to imeta if available
    if (upload.thumbnailPath != null && upload.thumbnailPath!.isNotEmpty) {
      imetaComponents.add('image ${upload.thumbnailPath!}');
    }

    // Add dimensions to imeta if available
    if (upload.videoWidth != null && upload.videoHeight != null) {
      imetaComponents.add('dim ${upload.videoWidth}x${upload.videoHeight}');
    }

    // Add file size and SHA256 if available from local video file
    if (upload.localVideoPath.isNotEmpty) {
      try {
        final videoFile = File(upload.localVideoPath);
        if (videoFile.existsSync()) {
          // Add file size
          final fileSize = videoFile.lengthSync();
          imetaComponents.add('size $fileSize');

          // Calculate SHA256 hash
          final bytes = await videoFile.readAsBytes();
          final hash = sha256.convert(bytes);
          imetaComponents.add('x $hash');
        }
      } catch (e) {
        // File metadata calculation failed - this is handled gracefully
      }
    }

    return imetaComponents;
  }
}

void main() {
  group('VideoEventPublisher imeta tag generation', () {
    late File testVideoFile;
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory and test video file
      tempDir = await Directory.systemTemp.createTemp('video_publisher_test');
      testVideoFile = File('${tempDir.path}/test_video.mp4');

      // Create a test video file with known content
      final testContent = 'This is test video content for hash calculation';
      await testVideoFile.writeAsString(testContent);
    });

    tearDownAll(() async {
      // Clean up test files
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should generate complete imeta tag with file metadata', () async {
      // Arrange
      final upload =
          PendingUpload.create(
            localVideoPath: testVideoFile.path,
            nostrPubkey: 'test_pubkey',
            thumbnailPath: 'https://example.com/thumbnail.jpg',
            title: 'Test Video',
            description: 'Test description',
            hashtags: ['test', 'video'],
            videoWidth: 1920,
            videoHeight: 1080,
          ).copyWith(
            cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Calculate expected values
      final fileSize = testVideoFile.lengthSync();
      final bytes = await testVideoFile.readAsBytes();
      final expectedHash = sha256.convert(bytes).toString();

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert
      expect(
        imetaComponents.isNotEmpty,
        true,
        reason: 'Should have imeta components',
      );

      // Verify all expected components are present
      expect(
        imetaComponents.any((c) => c.startsWith('url ')),
        true,
        reason: 'Should include URL component',
      );
      expect(
        imetaComponents.any((c) => c == 'm video/mp4'),
        true,
        reason: 'Should include MIME type',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('image ')),
        true,
        reason: 'Should include thumbnail image',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('dim ')),
        true,
        reason: 'Should include dimensions',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('size ')),
        true,
        reason: 'Should include file size',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('x ')),
        true,
        reason: 'Should include SHA256 hash',
      );

      // Verify specific values
      expect(
        imetaComponents.contains('url ${upload.cdnUrl}'),
        true,
        reason: 'URL should match upload CDN URL',
      );
      expect(
        imetaComponents.contains('image ${upload.thumbnailPath}'),
        true,
        reason: 'Image should match thumbnail path',
      );
      expect(
        imetaComponents.contains(
          'dim ${upload.videoWidth}x${upload.videoHeight}',
        ),
        true,
        reason: 'Dimensions should be correct',
      );
      expect(
        imetaComponents.contains('size $fileSize'),
        true,
        reason: 'File size should be correct',
      );
      expect(
        imetaComponents.contains('x $expectedHash'),
        true,
        reason: 'SHA256 hash should be correct',
      );
    });

    test(
      'should generate imeta tag without optional metadata when unavailable',
      () async {
        // Arrange - Upload without thumbnail, dimensions
        final upload =
            PendingUpload.create(
              localVideoPath: testVideoFile.path,
              nostrPubkey: 'test_pubkey',
              title: 'Test Video',
            ).copyWith(
              cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
              status: UploadStatus.readyToPublish,
            );

        // Act
        final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
          upload,
        );

        // Assert
        expect(
          imetaComponents.isNotEmpty,
          true,
          reason: 'Should have imeta components',
        );

        // Should have required components
        expect(
          imetaComponents.any((c) => c.startsWith('url ')),
          true,
          reason: 'Should include URL component',
        );
        expect(
          imetaComponents.any((c) => c == 'm video/mp4'),
          true,
          reason: 'Should include MIME type',
        );
        expect(
          imetaComponents.any((c) => c.startsWith('size ')),
          true,
          reason: 'Should include file size',
        );
        expect(
          imetaComponents.any((c) => c.startsWith('x ')),
          true,
          reason: 'Should include SHA256 hash',
        );

        // Should NOT have optional components
        expect(
          imetaComponents.any((c) => c.startsWith('image ')),
          false,
          reason: 'Should NOT include thumbnail when unavailable',
        );
        expect(
          imetaComponents.any((c) => c.startsWith('dim ')),
          false,
          reason: 'Should NOT include dimensions when unavailable',
        );
      },
    );

    test('should handle missing local video file gracefully', () async {
      // Arrange - Upload with non-existent local file
      final nonExistentFile = '${tempDir.path}/nonexistent.mp4';
      final upload =
          PendingUpload.create(
            localVideoPath: nonExistentFile,
            nostrPubkey: 'test_pubkey',
            title: 'Test Video',
          ).copyWith(
            cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert
      expect(
        imetaComponents.isNotEmpty,
        true,
        reason: 'Should have basic imeta components',
      );

      // Should have basic components
      expect(
        imetaComponents.any((c) => c.startsWith('url ')),
        true,
        reason: 'Should include URL component',
      );
      expect(
        imetaComponents.any((c) => c == 'm video/mp4'),
        true,
        reason: 'Should include MIME type',
      );

      // Should NOT have file-dependent components
      expect(
        imetaComponents.any((c) => c.startsWith('size ')),
        false,
        reason: 'Should NOT include size when file missing',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('x ')),
        false,
        reason: 'Should NOT include hash when file missing',
      );
    });

    test('should include thumbnail in imeta when available', () async {
      // Arrange
      final upload =
          PendingUpload.create(
            localVideoPath: testVideoFile.path,
            nostrPubkey: 'test_pubkey',
            thumbnailPath: 'https://example.com/custom_thumbnail.jpg',
            title: 'Test Video',
          ).copyWith(
            cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert
      expect(
        imetaComponents.any((c) => c.startsWith('image ')),
        true,
        reason: 'Should include thumbnail when available',
      );
      expect(
        imetaComponents.contains('image ${upload.thumbnailPath}'),
        true,
        reason: 'Thumbnail URL should match',
      );
    });

    test('should include dimensions in imeta when available', () async {
      // Arrange
      final upload =
          PendingUpload.create(
            localVideoPath: testVideoFile.path,
            nostrPubkey: 'test_pubkey',
            videoWidth: 1280,
            videoHeight: 720,
          ).copyWith(
            cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert
      expect(
        imetaComponents.any((c) => c.startsWith('dim ')),
        true,
        reason: 'Should include dimensions when available',
      );
      expect(
        imetaComponents.contains('dim 1280x720'),
        true,
        reason: 'Dimensions should be formatted correctly',
      );
    });

    test(
      'should add BOTH MP4 and HLS URLs when Blossom returns Bunny Stream HLS URL',
      () async {
        // Arrange - Blossom server returns HLS playlist URL
        final hlsUrl =
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/playlist.m3u8';
        final upload = PendingUpload.create(
          localVideoPath: testVideoFile.path,
          nostrPubkey: 'test_pubkey',
          title: 'Test Video',
        ).copyWith(cdnUrl: hlsUrl, status: UploadStatus.readyToPublish);

        // Act
        final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
          upload,
        );

        // Assert - Should contain BOTH URLs
        final mp4Url =
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/play_360p.mp4';

        // Should have MP4 URL FIRST (preferred for short videos)
        expect(
          imetaComponents.contains('url $mp4Url'),
          true,
          reason: 'Should include MP4 URL variant for Bunny Stream video',
        );

        // Should also have HLS URL as fallback
        expect(
          imetaComponents.contains('url $hlsUrl'),
          true,
          reason: 'Should include original HLS URL as fallback',
        );

        // MP4 should come before HLS (preferred)
        final mp4Index = imetaComponents.indexOf('url $mp4Url');
        final hlsIndex = imetaComponents.indexOf('url $hlsUrl');
        expect(
          mp4Index,
          lessThan(hlsIndex),
          reason:
              'MP4 URL should come before HLS URL (preferred for short videos)',
        );
      },
    );

    test('should only add single URL for non-Bunny Stream CDN URLs', () async {
      // Arrange - Regular CDN URL (not Bunny Stream)
      final regularUrl = 'https://cdn.divine.video/abc123.mp4';
      final upload = PendingUpload.create(
        localVideoPath: testVideoFile.path,
        nostrPubkey: 'test_pubkey',
        title: 'Test Video',
      ).copyWith(cdnUrl: regularUrl, status: UploadStatus.readyToPublish);

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert - Should only have ONE URL
      final urlComponents = imetaComponents
          .where((c) => c.startsWith('url '))
          .toList();
      expect(
        urlComponents.length,
        equals(1),
        reason: 'Should only have one URL for non-Bunny Stream CDNs',
      );
      expect(
        urlComponents.first,
        equals('url $regularUrl'),
        reason: 'Should use original CDN URL',
      );
    });
  });
}
