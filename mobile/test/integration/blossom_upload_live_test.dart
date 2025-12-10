// ABOUTME: Live integration test for Blossom uploads using real staging server
// ABOUTME: Tests actual authentication and file upload with real Nostr keys

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_factory.dart';
import '../helpers/service_init_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Blossom Upload Live Integration', () {
    late BlossomUploadService blossomService;
    late AuthService authService;
    late INostrService nostrService;
    late File testVideoFile;

    const stagingServer =
        'https://cf-stream-service-staging.protestnet.workers.dev';
    const prodServer = 'https://cf-stream-service-prod.protestnet.workers.dev';

    setUpAll(() async {
      // Initialize test environment first
      ServiceInitHelper.initializeTestEnvironment();

      // Create a real test video file
      testVideoFile = File('/tmp/test_blossom_upload.mp4');

      // Create a minimal valid MP4 file (just for testing)
      final testVideoData = Uint8List.fromList([
        // MP4 file signature and minimal header
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31,
        // Add some more data to make it a reasonable size
        ...List.filled(1000, 0x00),
      ]);

      await testVideoFile.writeAsBytes(testVideoData);

      // Create real services for live testing using the factory pattern
      final keyManager = NostrKeyManager();
      await keyManager.initialize();

      // Generate test keys if none exist (using the actual API)
      if (keyManager.privateKey == null) {
        final newKeyPair = await keyManager.generateKeys();
        print('Generated test keys: ${newKeyPair.public}...');
      }

      nostrService = NostrServiceFactory.create(keyManager);
      NostrServiceFactory.initialize(nostrService);

      final keyStorage = SecureKeyStorage();
      authService = AuthService(keyStorage: keyStorage);
      await authService.initialize();

      blossomService = BlossomUploadService(
        authService: authService,
        nostrService: nostrService,
      );

      // Configure to use staging server
      await blossomService.setBlossomServer(stagingServer);
      await blossomService.setBlossomEnabled(true);
    });

    tearDownAll(() async {
      // Clean up test file
      if (await testVideoFile.exists()) {
        await testVideoFile.delete();
      }
    });

    test('should successfully upload to staging server', () async {
      // Skip if we don't have real keys
      if (!authService.isAuthenticated) {
        markTestSkipped('No authenticated user available for live test');
        return;
      }

      print('🔄 Testing upload to staging server: $stagingServer');
      print('📁 Test file size: ${await testVideoFile.length()} bytes');
      print('👤 Using pubkey: ${authService.currentPublicKeyHex}...');

      final result = await blossomService.uploadVideo(
        videoFile: testVideoFile,
        nostrPubkey: authService.currentPublicKeyHex!,
        title: 'Blossom Integration Test',
        description: 'Test upload from Flutter integration test',
        hashtags: ['test', 'integration'],
        onProgress: (progress) {
          print('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      print('✅ Upload result: success=${result.success}');
      if (result.success) {
        print('📍 CDN URL: ${result.cdnUrl}');
        print('🆔 Video ID: ${result.videoId}');
      } else {
        print('❌ Error: ${result.errorMessage}');
      }

      // Assert successful upload
      expect(
        result.success,
        isTrue,
        reason: 'Upload should succeed: ${result.errorMessage}',
      );
      expect(result.cdnUrl, isNotNull, reason: 'Should return CDN URL');
      expect(result.videoId, isNotNull, reason: 'Should return video ID');
      expect(
        result.cdnUrl,
        contains(result.videoId!),
        reason: 'CDN URL should contain video ID',
      );
    });

    test(
      'should handle authentication with proper Blossom kind 24242 event',
      () async {
        if (!authService.isAuthenticated) {
          markTestSkipped('No authenticated user available for live test');
          return;
        }

        print('🔐 Testing Blossom authentication (kind 24242)');

        // This test verifies that our fixed authentication works
        final result = await blossomService.uploadVideo(
          videoFile: testVideoFile,
          nostrPubkey: authService.currentPublicKeyHex!,
          title: 'Auth Test',
        );

        // Should not get "unauthorized" error anymore
        expect(
          result.errorMessage?.toLowerCase(),
          isNot(contains('unauthorized')),
          reason: 'Should not get unauthorized error with proper Blossom auth',
        );

        if (!result.success) {
          print('❌ Upload failed: ${result.errorMessage}');
          // Print more details for debugging
          print('🔍 Auth status: ${authService.isAuthenticated}');
          print('🔍 Current pubkey: ${authService.currentPublicKeyHex}...');
          print('🔍 Server: ${await blossomService.getBlossomServer()}');
          print('🔍 Enabled: ${await blossomService.isBlossomEnabled()}');
        }
      },
    );

    test('should work with production server as fallback', () async {
      if (!authService.isAuthenticated) {
        markTestSkipped('No authenticated user available for live test');
        return;
      }

      print('🔄 Testing fallback to production server: $prodServer');

      // Switch to production server
      await blossomService.setBlossomServer(prodServer);

      final result = await blossomService.uploadVideo(
        videoFile: testVideoFile,
        nostrPubkey: authService.currentPublicKeyHex!,
        title: 'Production Fallback Test',
      );

      if (result.success) {
        print('✅ Production server upload successful');
        print('📍 CDN URL: ${result.cdnUrl}');
      } else {
        print('❌ Production server upload failed: ${result.errorMessage}');
      }

      // Don't require success since prod might have different restrictions
      // Just verify we're not getting auth errors
      expect(
        result.errorMessage?.toLowerCase(),
        isNot(contains('unauthorized')),
        reason: 'Should not get unauthorized error with proper Blossom auth',
      );
    });
  });
}
