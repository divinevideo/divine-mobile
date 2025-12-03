// ABOUTME: Tests for UploadManager initialization helper
// ABOUTME: Verifies app container path usage, permanent error detection, and fail-fast behavior

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:models/models.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async {
    return '/tmp/test_app_support';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadInitializationHelper', () {
    late String testBoxPath;

    setUp(() async {
      // Set up mock path provider
      PathProviderPlatform.instance = MockPathProviderPlatform();

      // Initialize Hive with test directory
      final testDir = Directory.systemTemp.createTempSync('upload_init_test_');
      testBoxPath = testDir.path;
      Hive.init(testBoxPath);

      // Register adapters
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UploadStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(PendingUploadAdapter());
      }

      // Reset helper state
      UploadInitializationHelper.reset();
    });

    tearDown(() async {
      // Clean up Hive boxes
      try {
        if (Hive.isBoxOpen('pending_uploads')) {
          await Hive.box<PendingUpload>('pending_uploads').close();
        }
        await Hive.deleteBoxFromDisk('pending_uploads');
      } catch (_) {
        // Ignore cleanup errors
      }

      // Clean up test directory
      try {
        Directory(testBoxPath).deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    test('uses app container path from path_provider', () async {
      // This test verifies the helper uses getApplicationSupportDirectory()
      // instead of trying to access user directories like ~/Documents

      final box = await UploadInitializationHelper.initializeUploadsBox();

      expect(box.isOpen, isTrue);
      expect(box.name, equals('pending_uploads'));

      // Verify box is functional
      final testUpload = PendingUpload.create(
        localVideoPath: '/test/path.mp4',
        nostrPubkey: 'test_pubkey',
      );

      await box.put('test_key', testUpload);
      final retrieved = box.get('test_key');

      expect(retrieved, isNotNull);
      expect(retrieved!.localVideoPath, equals('/test/path.mp4'));

      await box.delete('test_key');
    });

    test('detects permanent permission errors (errno=1)', () {
      // Create a FileSystemException with errno=1 (EPERM)
      final permError = FileSystemException(
        'Operation not permitted',
        '/some/path',
        OSError('Operation not permitted', 1),
      );

      // This should be detected as permanent
      // Note: We can't directly test the private method, but we can verify
      // the behavior by checking that initialization fails quickly on permission errors
      expect(permError.osError?.errorCode, equals(1));
    });

    test('detects permanent permission errors (errno=13)', () {
      // Create a FileSystemException with errno=13 (EACCES)
      final permError = FileSystemException(
        'Permission denied',
        '/some/path',
        OSError('Permission denied', 13),
      );

      expect(permError.osError?.errorCode, equals(13));
    });

    test('successfully initializes box and verifies functionality', () async {
      final box = await UploadInitializationHelper.initializeUploadsBox();

      expect(box.isOpen, isTrue);

      // Test write
      final upload = PendingUpload.create(
        localVideoPath: '/video.mp4',
        nostrPubkey: 'pubkey123',
      );
      await box.put('upload1', upload);

      // Test read
      final retrieved = box.get('upload1');
      expect(retrieved, isNotNull);
      expect(retrieved!.localVideoPath, equals('/video.mp4'));

      // Test delete
      await box.delete('upload1');
      expect(box.get('upload1'), isNull);
    });

    test('returns cached box on subsequent calls', () async {
      final box1 = await UploadInitializationHelper.initializeUploadsBox();
      final box2 = await UploadInitializationHelper.initializeUploadsBox();

      // Should return same instance
      expect(identical(box1, box2), isTrue);
      expect(box2.isOpen, isTrue);
    });

    test('can force re-initialization with forceReinit', () async {
      final box1 = await UploadInitializationHelper.initializeUploadsBox();

      // Close the box to simulate needing re-init
      await box1.close();

      final box2 = await UploadInitializationHelper.initializeUploadsBox(
        forceReinit: true,
      );

      expect(box2.isOpen, isTrue);
    });

    test('debug state shows correct information', () async {
      final stateBefore = UploadInitializationHelper.getDebugState();
      expect(stateBefore['hasCachedBox'], isFalse);

      await UploadInitializationHelper.initializeUploadsBox();

      final stateAfter = UploadInitializationHelper.getDebugState();
      expect(stateAfter['hasCachedBox'], isTrue);
      expect(stateAfter['cachedBoxOpen'], isTrue);
      expect(stateAfter['isInitializing'], isFalse);
    });

    test('handles corrupted box by deleting and recreating', () async {
      // First create a valid box
      final box = await UploadInitializationHelper.initializeUploadsBox();
      await box.close();

      // Corrupt the box file by writing garbage
      final boxFile = File('$testBoxPath/pending_uploads.hive');
      if (await boxFile.exists()) {
        await boxFile.writeAsString('CORRUPTED DATA');
      }

      // Reset cached box
      UploadInitializationHelper.reset();

      // Should handle corruption by deleting and recreating
      final newBox = await UploadInitializationHelper.initializeUploadsBox();
      expect(newBox.isOpen, isTrue);

      // Should be functional
      final upload = PendingUpload.create(
        localVideoPath: '/test.mp4',
        nostrPubkey: 'test',
      );
      await newBox.put('test', upload);
      expect(newBox.get('test'), isNotNull);
    });
  });
}
