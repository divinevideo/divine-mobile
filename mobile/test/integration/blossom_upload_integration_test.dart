// ABOUTME: Integration test for Blossom upload to verify actual server response
// ABOUTME: Uses real BlossomUploadService to see what fields the server returns

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/real_integration_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Blossom Upload Integration Test', () {
    late ProviderContainer container;
    late File testFile;
    late String testPrivateKey;
    late String testPublicKey;

    setUpAll(() async {
      await RealIntegrationTestHelper.setupTestEnvironment();
      await Hive.initFlutter();
    });

    setUp(() async {
      container = ProviderContainer();

      // Generate test keypair and create new identity
      testPrivateKey = keys.generatePrivateKey();
      testPublicKey = keys.getPublicKey(testPrivateKey);

      print('🔑 Creating test identity: $testPublicKey');

      // Configure Blossom server FIRST
      SharedPreferences.setMockInitialValues({
        'blossom_server': 'https://blossom.divine.video',
        'blossom_enabled': true,
      });

      // Get auth service and create test identity
      final authService = container.read(authServiceProvider);
      final authResult = await authService.createNewIdentity();

      if (!authResult.success) {
        throw Exception(
          'Failed to create test identity: ${authResult.errorMessage}',
        );
      }

      print('✅ Test identity created and authenticated');

      // Create test file
      final tempDir = await Directory.systemTemp.createTemp('blossom_test');
      testFile = File('${tempDir.path}/test.mp4');

      // Write minimal MP4 header
      await testFile.writeAsBytes([
        0x00,
        0x00,
        0x00,
        0x20,
        0x66,
        0x74,
        0x79,
        0x70,
        0x69,
        0x73,
        0x6F,
        0x6D,
        0x00,
        0x00,
        0x02,
        0x00,
        0x69,
        0x73,
        0x6F,
        0x6D,
        0x69,
        0x73,
        0x6F,
        0x32,
      ]);
    });

    tearDown(() async {
      if (await testFile.exists()) {
        await testFile.delete();
      }
      container.dispose();
    });

    test('should show what fields Blossom server returns', () async {
      // Get real services from providers
      final blossomService = container.read(blossomUploadServiceProvider);

      print('📤 Uploading to blossom.divine.video...');
      print('This test will show the actual server response structure');
      print('');

      // Use real upload service
      final result = await blossomService.uploadVideo(
        videoFile: testFile,
        nostrPubkey: testPublicKey,
        title: 'Integration Test',
        description: 'Testing Blossom response structure',
        onProgress: (progress) {
          print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      print('');
      print('==========================================');
      print('BLOSSOM UPLOAD RESULT');
      print('==========================================');
      print('Success: ${result.success}');
      print('Video ID: ${result.videoId}');
      print('CDN URL: ${result.cdnUrl}');
      print('GIF URL: ${result.gifUrl}');
      print('Thumbnail URL: ${result.thumbnailUrl}');
      print('Blurhash: ${result.blurhash}');
      print('Error: ${result.errorMessage}');
      print('==========================================');
      print('');

      // The enhanced logging in BlossomUploadService will show ALL server fields
      print('✅ Check the logs above for "BLOSSOM SERVER RESPONSE FIELDS"');
      print('   to see what the server actually returns');

      // Test just needs to not crash - we're inspecting logs
      expect(result, isNotNull);
    });
  });
}
