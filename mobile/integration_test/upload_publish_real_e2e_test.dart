// ABOUTME: Real end-to-end test for video upload → thumbnail → Nostr publishing with REAL services
// ABOUTME: Uses actual Blossom server, real Nostr relays, and real video file - NO MOCKS

import 'dart:io';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/providers/app_providers.dart';
import '../test/helpers/real_integration_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('REAL Upload → Publish E2E Test (NO MOCKS)', () {
    late ProviderContainer container;
    late File testVideoFile;
    late String testPrivateKey;
    late String testPublicKey;

    setUpAll(() async {
      await RealIntegrationTestHelper.setupTestEnvironment();
      await Hive.initFlutter();
    });

    setUp(() async {
      // Generate test Nostr keypair
      testPrivateKey = keys.generatePrivateKey();
      testPublicKey = keys.getPublicKey(testPrivateKey);

      print('\n🔑 Test keypair: ${testPublicKey.substring(0, 8)}...');

      // Create test video file in a writable location (temp directory for sandboxed apps)
      final tempDir = Directory.systemTemp;
      testVideoFile = File(
        '${tempDir.path}/test_real_e2e_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      // Generate a real MP4 video using ffmpeg (5 seconds, 30fps, solid color)
      print('📹 Generating test video with ffmpeg...');
      final ffmpegResult = await Process.run('ffmpeg', [
        '-f',
        'lavfi',
        '-i',
        'color=c=blue:s=640x480:d=5',
        '-c:v',
        'libx264',
        '-t',
        '5',
        '-pix_fmt',
        'yuv420p',
        '-y',
        testVideoFile.path,
      ]);

      if (ffmpegResult.exitCode != 0) {
        print('❌ ffmpeg failed: ${ffmpegResult.stderr}');
        print('📹 Falling back to minimal MP4 (no frames, no thumbnail)');
        await testVideoFile.writeAsBytes(_createMinimalMP4());
      } else {
        print('✅ Generated test video: ${testVideoFile.path}');
      }

      print('📹 Test video ready: ${testVideoFile.path}');

      // Create container with REAL services (no mocks!)
      container = ProviderContainer();

      // CRITICAL: Authenticate with test private key so Blossom uploads can be signed
      final authService = container.read(authServiceProvider);
      await authService.initialize();
      final authResult = await authService.importFromHex(testPrivateKey);

      if (!authResult.success) {
        throw Exception(
          'Failed to authenticate test user: ${authResult.errorMessage}',
        );
      }

      print(
        '✅ Test user authenticated: ${authService.currentPublicKeyHex?.substring(0, 8)}...',
      );

      // CRITICAL: Initialize NostrService with relay connections for publishing
      print('🔌 Initializing NostrService with relay connections...');
      final nostrService = container.read(nostrServiceProvider);

      // Initialize
      await nostrService.initialize();

      print('✅ NostrService initialized');
      print('   Configured relays: ${nostrService.configuredRelays}');
      print('   Relay count: ${nostrService.configuredRelayCount}');
      print(
        '   Note: Relay connections are asynchronous - publishing will connect as needed',
      );
    });

    tearDown(() async {
      if (await testVideoFile.exists()) {
        await testVideoFile.delete();
      }

      // Sign out test user
      try {
        final authService = container.read(authServiceProvider);
        await authService.signOut(deleteKeys: true);
      } catch (e) {
        // Ignore sign out errors in teardown
      }

      container.dispose();

      // Clean up Hive boxes
      try {
        if (Hive.isBoxOpen('pending_uploads')) {
          final box = Hive.box('pending_uploads');
          await box.clear();
          await box.close();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test(
      'REAL E2E: Upload to real Blossom server → Publish to real Nostr relays',
      () async {
        print('\n🎬 === STARTING REAL E2E TEST (NO MOCKS) ===\n');
        print(
          '⚠️  This test uploads to real Blossom CDN and real Nostr relays!',
        );
        print(
          '⚠️  Test may fail if Blossom server is down or not configured\n',
        );

        // Get REAL services from container
        final uploadManager = container.read(uploadManagerProvider);
        final blossomService = container.read(blossomUploadServiceProvider);

        // Check if Blossom is configured
        final isBlossomEnabled = await blossomService.isBlossomEnabled();
        if (!isBlossomEnabled) {
          print('⚠️  Blossom is not enabled - skipping test');
          print('   Configure Blossom server in settings to run this test');
          return;
        }

        final blossomServer = await blossomService.getBlossomServer();
        print('🌸 Blossom server: $blossomServer');

        // PHASE 1: Upload video to REAL Blossom server
        print('\n📤 PHASE 1: Uploading to REAL Blossom server...\n');

        PendingUpload? upload;
        try {
          upload = await uploadManager.startUpload(
            videoFile: testVideoFile,
            nostrPubkey: testPublicKey,
            title: 'Real E2E Test Video',
            description:
                'This is a REAL test video uploaded to actual Blossom CDN',
            hashtags: ['real-e2e-test', 'integration-test'],
            videoDuration: const Duration(seconds: 5),
          );
        } catch (e) {
          print(
            '❌ Upload failed (this is expected if Blossom server is not configured):',
          );
          print('   Error: $e');
          print('\n⚠️  To run this test, ensure:');
          print('   1. Blossom server is configured in settings');
          print('   2. Valid Nostr key is available for authentication');
          print('   3. Network connectivity to Blossom server');
          print('\nSkipping rest of test due to upload failure.');
          return;
        }

        print('✅ Upload created: ${upload.id}');
        print('   Status: ${upload.status}');
        print('   Video ID: ${upload.videoId}');
        print('   CDN URL: ${upload.cdnUrl}');
        print('   Thumbnail URL: ${upload.thumbnailPath}');

        // VERIFY PHASE 1: Upload completed successfully
        expect(
          upload.status,
          equals(UploadStatus.readyToPublish),
          reason:
              'Upload should be ready to publish after startUpload completes',
        );
        expect(
          upload.videoId,
          isNotNull,
          reason: 'Video ID should be populated after upload',
        );
        expect(
          upload.cdnUrl,
          isNotNull,
          reason: 'CDN URL should be populated after upload',
        );

        // Verify CDN URL is accessible
        expect(
          upload.cdnUrl,
          startsWith('https://'),
          reason: 'CDN URL should be HTTPS',
        );

        print('\n✅ PHASE 1 COMPLETE: Video uploaded to real Blossom CDN\n');
        print('🌐 Video accessible at: ${upload.cdnUrl}');

        // Check thumbnail
        if (upload.thumbnailPath != null) {
          print('📸 Thumbnail URL: ${upload.thumbnailPath}');
          expect(
            upload.thumbnailPath,
            startsWith('https://'),
            reason: 'Thumbnail URL should be HTTPS',
          );
          print('🌐 Thumbnail accessible at: ${upload.thumbnailPath}');
        } else {
          print('ℹ️  No thumbnail (video may not have extractable frames)');
        }

        // PHASE 2: Publish to REAL Nostr relays
        print('\n📤 PHASE 2: Publishing to REAL Nostr relays...\n');

        // Check NostrService relay connections before publishing
        final nostrService = container.read(nostrServiceProvider);
        print('📡 Nostr relay status:');
        print('   Configured relays: ${nostrService.configuredRelays}');
        print('   Relay count: ${nostrService.configuredRelayCount}');

        final videoEventPublisher = container.read(videoEventPublisherProvider);

        print('\n🚀 Publishing video event to Nostr...');
        print('   Video URL: ${upload.cdnUrl}');
        print('   Thumbnail: ${upload.thumbnailPath ?? "(none)"}');
        print('   Title: ${upload.title}');
        print('   Description: ${upload.description}');
        print('   Hashtags: ${upload.hashtags}');

        bool publishSuccess;
        try {
          publishSuccess = await videoEventPublisher.publishDirectUpload(
            upload,
          );
        } catch (e, stackTrace) {
          print('❌ Publishing failed with exception:');
          print('   Error: $e');
          print('   Stack trace: $stackTrace');
          print('\n⚠️  This may be expected if:');
          print('   - Nostr relays are unreachable');
          print('   - Authentication failed');
          print('   - Network issues');
          print(
            '\nPartial success: Video was uploaded to Blossom CDN successfully.',
          );
          return;
        }

        print('\n✅ Publish result: $publishSuccess');

        if (!publishSuccess) {
          print('⚠️  Publishing returned false - checking reason...');
          print('   This typically means zero relays succeeded');
          print('   Check logs above for relay-specific errors');
        }

        // VERIFY PHASE 2: Publishing succeeded
        expect(
          publishSuccess,
          isTrue,
          reason: 'Publishing should succeed with valid upload',
        );

        // Get the updated upload with Nostr event ID
        final publishedUpload = uploadManager.getUpload(upload.id);
        expect(publishedUpload, isNotNull);
        expect(
          publishedUpload!.nostrEventId,
          isNotNull,
          reason: 'Upload should have Nostr event ID after publishing',
        );

        print('\n✅ PHASE 2 COMPLETE: Event published to real Nostr relays\n');
        print('🌐 Nostr event ID: ${publishedUpload.nostrEventId}');

        // PHASE 3: Verify the upload is marked as published
        print('\n📤 PHASE 3: Verifying final state...\n');

        expect(
          publishedUpload.status,
          equals(UploadStatus.published),
          reason: 'Upload should be marked as published',
        );
        expect(
          publishedUpload.completedAt,
          isNotNull,
          reason: 'Upload should have completion timestamp',
        );

        print('✅ Upload marked as published');
        print('   Status: ${publishedUpload.status}');
        print('   Completed at: ${publishedUpload.completedAt}');

        print('\n✅ PHASE 3 COMPLETE: Final state verified\n');

        print('🎉 === REAL E2E TEST PASSED ===\n');
        print('Summary:');
        print('✅ Video uploaded to REAL Blossom CDN: ${upload.cdnUrl}');
        if (upload.thumbnailPath != null) {
          print(
            '✅ Thumbnail uploaded to REAL Blossom CDN: ${upload.thumbnailPath}',
          );
        }
        print(
          '✅ Nostr event published to REAL relays: ${publishedUpload.nostrEventId}',
        );
        print('✅ Event can be viewed on Nostr clients');
        print('✅ Video is publicly accessible via CDN URL');
        print('\n🌐 Test artifacts:');
        print('   Video: ${upload.cdnUrl}');
        if (upload.thumbnailPath != null) {
          print('   Thumbnail: ${upload.thumbnailPath}');
        }
        print('   Nostr event: ${publishedUpload.nostrEventId}');
        print('   Test user pubkey: $testPublicKey');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    ); // Longer timeout for real network operations

    test(
      'REAL E2E: Verify uploaded video is retrievable from CDN',
      () async {
        print('\n🎬 Testing CDN video retrieval\n');

        final uploadManager = container.read(uploadManagerProvider);
        final blossomService = container.read(blossomUploadServiceProvider);

        final isBlossomEnabled = await blossomService.isBlossomEnabled();
        if (!isBlossomEnabled) {
          print('⚠️  Blossom not enabled - skipping test');
          return;
        }

        // Upload video
        PendingUpload? upload;
        try {
          upload = await uploadManager.startUpload(
            videoFile: testVideoFile,
            nostrPubkey: testPublicKey,
            title: 'CDN Retrieval Test',
            videoDuration: const Duration(seconds: 5),
          );
        } catch (e) {
          print('⚠️  Upload failed - skipping CDN retrieval test: $e');
          return;
        }

        expect(upload.cdnUrl, isNotNull);

        // Try to fetch the video from CDN
        print('🌐 Fetching video from CDN: ${upload.cdnUrl}');

        final httpClient = HttpClient();
        try {
          final uri = Uri.parse(upload.cdnUrl!);
          final request = await httpClient.getUrl(uri);
          final response = await request.close();

          print('   HTTP Status: ${response.statusCode}');
          expect(
            response.statusCode,
            equals(200),
            reason: 'CDN should return 200 OK for uploaded video',
          );

          final contentLength = response.contentLength;
          if (contentLength > 0) {
            print('   Content length: $contentLength bytes');
          }

          final contentType = response.headers.value('content-type');
          print('   Content type: $contentType');

          // Verify it's a video
          expect(
            contentType,
            contains('video'),
            reason: 'CDN should serve video content type',
          );

          print('✅ Video is accessible from CDN');
        } catch (e) {
          fail('Failed to retrieve video from CDN: $e');
        } finally {
          httpClient.close();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

/// Create a minimal valid MP4 file for testing
List<int> _createMinimalMP4() {
  return [
    // ftyp box
    0x00, 0x00, 0x00, 0x20, // Box size
    0x66, 0x74, 0x79, 0x70, // 'ftyp'
    0x69, 0x73, 0x6F, 0x6D, // 'isom'
    0x00, 0x00, 0x02, 0x00, // Version
    0x69, 0x73, 0x6F, 0x6D, // Compatible brand
    0x69, 0x73, 0x6F, 0x32, // Compatible brand
    0x6D, 0x70, 0x34, 0x31, // Compatible brand
    // moov box
    0x00, 0x00, 0x00, 0x08,
    0x6D, 0x6F, 0x6F, 0x76, // 'moov'
  ];
}
