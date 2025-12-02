// ABOUTME: Test to verify actual Blossom server response structure
// ABOUTME: Uploads real file to blossom.divine.video to see what fields are returned

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  test(
    'Verify Blossom server response structure',
    () async {
      // Create a small test video file
      final tempDir = await Directory.systemTemp.createTemp('blossom_test');
      final testFile = File('${tempDir.path}/test_video.mp4');

      // Write some test content (small file)
      final testContent = List.generate(1024, (i) => i % 256); // 1KB file
      await testFile.writeAsBytes(testContent);

      try {
        // Initialize services
        final authService = AuthService();
        final blossomService = BlossomUploadService(authService: authService);

        // Override Blossom server to blossom.divine.video
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('blossom_server', 'https://blossom.divine.video');
        await prefs.setBool('blossom_enabled', true);

        Log.info('🧪 Starting test upload to blossom.divine.video');

        // Upload the file
        final result = await blossomService.uploadVideo(
          videoFile: testFile,
          nostrPubkey: 'test_pubkey',
          title: 'Test Upload',
          description: 'Testing Blossom response structure',
          onProgress: (progress) {
            Log.info(
              'Upload progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          },
        );

        // Print the FULL result
        Log.info('');
        Log.info('==========================================');
        Log.info('BLOSSOM SERVER RESPONSE ANALYSIS');
        Log.info('==========================================');
        Log.info('Success: ${result.success}');
        Log.info('Video ID: ${result.videoId}');
        Log.info('CDN URL: ${result.cdnUrl}');
        Log.info('GIF URL: ${result.gifUrl}');
        Log.info('Thumbnail URL: ${result.thumbnailUrl}');
        Log.info('Blurhash: ${result.blurhash}');
        Log.info('Error: ${result.errorMessage}');
        Log.info('==========================================');
        Log.info('');

        // The test passes regardless - we just want to see the response
        expect(result.success, isTrue, reason: 'Upload should succeed');

        // Print guidance for next steps
        if (result.cdnUrl != null) {
          Log.info('✅ CDN URL received: ${result.cdnUrl}');

          if (result.cdnUrl!.contains('playlist.m3u8')) {
            Log.info('⚠️  Server returned HLS playlist URL');
            Log.info(
              '💡 We need to check if server also returns mp4Url and fallbackUrl fields',
            );
          } else if (result.cdnUrl!.contains('.mp4')) {
            Log.info('✅ Server returned MP4 URL');
          }
        }
      } finally {
        // Cleanup
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
    skip:
        'Manual test - requires authentication. Run with: flutter test test/services/blossom_server_response_test.dart',
  );
}
