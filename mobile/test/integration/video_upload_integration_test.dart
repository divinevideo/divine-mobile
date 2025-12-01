// ABOUTME: Integration test for video upload using real app services
// ABOUTME: Tests the actual upload flow by calling app functions directly

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../helpers/real_integration_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Video Upload Integration Test', () {
    late ProviderContainer container;
    late File testVideoFile;
    late String testPrivateKey;
    late String testPublicKey;

    setUpAll(() async {
      // Setup test environment (handles platform channels, etc.)
      await RealIntegrationTestHelper.setupTestEnvironment();

      // Initialize Hive for testing
      await Hive.initFlutter();
    });

    setUp(() async {
      // Create provider container with real services
      container = ProviderContainer();

      // Generate a test Nostr keypair for this test
      testPrivateKey = keys.generatePrivateKey();
      testPublicKey = keys.getPublicKey(testPrivateKey);

      print('🔑 Generated test keypair: ${testPublicKey}...');

      // Create a small test video file in current directory
      testVideoFile = File(
        'test_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      // Write minimal MP4 file (just needs to be a valid file for the test)
      await testVideoFile.writeAsBytes([
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // ftyp box header
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00, // isom brand
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32, // compatible brands
      ]);
    });

    tearDown(() async {
      // Clean up
      if (await testVideoFile.exists()) {
        await testVideoFile.delete();
      }

      // Dispose container first
      container.dispose();

      // Clean up Hive boxes
      try {
        if (Hive.isBoxOpen('pending_uploads')) {
          final box = Hive.box('pending_uploads');
          await box.clear();
          await box.close();
        }
      } catch (e) {
        // Ignore errors - box might not exist
      }
    });

    test(
      'should create pending upload with real upload manager',
      () async {
        // Get real upload manager from providers
        final uploadManager = container.read(uploadManagerProvider);

        print('📤 Starting upload test with test user: ${testPublicKey}...');

        // ACT: Call the actual upload function with test keypair
        final upload = await uploadManager.startUpload(
          videoFile: testVideoFile,
          nostrPubkey: testPublicKey,
          title: 'Integration Test Video',
          description: 'Test video uploaded by integration test',
          hashtags: ['test', 'integration'],
          videoDuration: const Duration(seconds: 1),
        );

        // ASSERT: Upload was created
        expect(upload, isNotNull);
        expect(upload.localVideoPath, equals(testVideoFile.path));
        expect(upload.nostrPubkey, equals(testPublicKey));
        expect(upload.title, equals('Integration Test Video'));
        expect(upload.hashtags, contains('test'));
        expect(upload.hashtags, contains('integration'));

        print('✅ Upload created: ${upload.id}');
        print('   Status: ${upload.status}');
        print('   Title: ${upload.title}');
        print('   Hashtags: ${upload.hashtags}');

        // Wait a bit for upload to potentially start processing
        await Future.delayed(const Duration(seconds: 2));

        // Check upload status
        final updatedUpload = uploadManager.getUpload(upload.id);
        expect(updatedUpload, isNotNull);

        print('   Updated status: ${updatedUpload!.status}');

        // Upload should have been created successfully
        expect(upload.id, isNotEmpty);
        expect(upload.createdAt, isNotNull);

        // Note: Actual Blossom upload may fail in test environment without proper auth/network,
        // but we've verified the upload manager accepts the request and creates the upload
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('should accept video with full metadata', () async {
      final uploadManager = container.read(uploadManagerProvider);

      // Create upload with full metadata
      final upload = await uploadManager.startUpload(
        videoFile: testVideoFile,
        nostrPubkey: testPublicKey,
        title: 'Test Video Title',
        description: 'This is a test description',
        hashtags: ['flutter', 'test', 'video'],
        videoDuration: const Duration(seconds: 5),
        videoWidth: 480,
        videoHeight: 480,
      );

      // Verify all metadata was captured
      expect(upload.title, equals('Test Video Title'));
      expect(upload.description, equals('This is a test description'));
      expect(upload.hashtags, hasLength(3));
      expect(upload.videoWidth, equals(480));
      expect(upload.videoHeight, equals(480));

      print('✅ Full metadata test passed');
    });

    test('should handle multiple uploads', () async {
      final uploadManager = container.read(uploadManagerProvider);

      // Create first upload
      final upload1 = await uploadManager.startUpload(
        videoFile: testVideoFile,
        nostrPubkey: testPublicKey,
        title: 'Video 1',
        videoDuration: const Duration(seconds: 1),
      );

      // Create second upload
      final upload2 = await uploadManager.startUpload(
        videoFile: testVideoFile,
        nostrPubkey: testPublicKey,
        title: 'Video 2',
        videoDuration: const Duration(seconds: 1),
      );

      // Both uploads should be created with unique IDs
      expect(upload1.id, isNotEmpty);
      expect(upload2.id, isNotEmpty);
      expect(upload1.id, isNot(equals(upload2.id)));

      print('✅ Multiple uploads test passed');
    });

    test('can generate test keypairs for testing', () {
      expect(testPublicKey, isNotEmpty);
      expect(testPublicKey.length, equals(64)); // Hex public key is 64 chars
      print('✅ Keypair generation works');
    });
  });
}
