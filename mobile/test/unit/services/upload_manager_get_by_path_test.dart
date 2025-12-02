// ABOUTME: Unit tests for UploadManager.getUploadByFilePath method
// ABOUTME: Tests file path lookup functionality using the public API

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/upload_manager.dart';
import '../../helpers/real_integration_test_helper.dart';
import '../../helpers/test_helpers.dart';

class MockBlossomUploadService extends Mock implements BlossomUploadService {}

class MockFile extends Mock implements File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UploadManager uploadManager;
  late MockBlossomUploadService mockUploadService;

  setUpAll(() async {
    // Setup test environment with platform channel mocks
    await RealIntegrationTestHelper.setupTestEnvironment();
    // Initialize Hive for testing
    await Hive.initFlutter();

    // CRITICAL: Delete the entire pending_uploads box from disk ONCE before any tests run
    // This ensures we don't have accumulated data from previous test runs
    try {
      if (Hive.isBoxOpen('pending_uploads')) {
        await Hive.box('pending_uploads').close();
      }
      await Hive.deleteBoxFromDisk('pending_uploads');
    } catch (e) {
      // Box might not exist, that's fine
    }
  });

  setUp(() async {
    // Use the reusable test helper to ensure a fresh empty Hive box
    await TestHelpers.cleanupHiveBox('pending_uploads');

    mockUploadService = MockBlossomUploadService();
    uploadManager = UploadManager(blossomService: mockUploadService);

    // Initialize creates a fresh empty box
    await uploadManager.initialize();

    // CRITICAL: Explicitly clear the box after initialization to remove any stale data
    await TestHelpers.ensureBoxEmpty<PendingUpload>('pending_uploads');
  });

  tearDown() async {
    // Clean up after each test using proper async coordination
    try {
      // Dispose the upload manager and wait for completion
      uploadManager.dispose();

      // Use proper async coordination instead of arbitrary delays
      await Future.microtask(() {});

      // Close the box if it's still open
      if (Hive.isBoxOpen('pending_uploads')) {
        final box = Hive.box('pending_uploads');
        await box.close();
      }
    } catch (e) {
      // Manager or box might already be disposed/closed
    }
    reset(mockUploadService);
  }

  ;

  group('UploadManager.getUploadByFilePath', () {
    test('should return upload with matching file path', () async {
      // Arrange - Create some test uploads
      final mockFile1 = MockFile();
      final mockFile2 = MockFile();
      final mockFile3 = MockFile();

      when(() => mockFile1.path).thenReturn('/path/to/video1.mp4');
      when(() => mockFile2.path).thenReturn('/path/to/video2.mp4');
      when(() => mockFile3.path).thenReturn('/path/to/video3.mp4');
      when(mockFile1.exists).thenAnswer((_) async => true);
      when(mockFile2.exists).thenAnswer((_) async => true);
      when(mockFile3.exists).thenAnswer((_) async => true);
      when(mockFile1.existsSync).thenReturn(true);
      when(mockFile2.existsSync).thenReturn(true);
      when(mockFile3.existsSync).thenReturn(true);
      when(mockFile1.lengthSync).thenReturn(1000000);
      when(mockFile2.lengthSync).thenReturn(2000000);
      when(mockFile3.lengthSync).thenReturn(3000000);

      // Start uploads to create PendingUpload entries
      await uploadManager.startUpload(
        videoFile: mockFile1,
        nostrPubkey: 'pubkey1',
      );
      await uploadManager.startUpload(
        videoFile: mockFile2,
        nostrPubkey: 'pubkey2',
      );
      await uploadManager.startUpload(
        videoFile: mockFile3,
        nostrPubkey: 'pubkey3',
      );

      // Act
      final result = uploadManager.getUploadByFilePath('/path/to/video2.mp4');

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals('/path/to/video2.mp4'));
      expect(result?.nostrPubkey, equals('pubkey2'));
    });

    test('should return null when no upload matches file path', () async {
      // Arrange
      final mockFile1 = MockFile();
      when(() => mockFile1.path).thenReturn('/path/to/video1.mp4');
      when(mockFile1.exists).thenAnswer((_) async => true);
      when(mockFile1.existsSync).thenReturn(true);
      when(mockFile1.lengthSync).thenReturn(1000000);

      await uploadManager.startUpload(
        videoFile: mockFile1,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final result = uploadManager.getUploadByFilePath(
        '/path/to/nonexistent.mp4',
      );

      // Assert
      expect(result, isNull);
    });

    test('should return null when pendingUploads is empty', () {
      // Act
      final result = uploadManager.getUploadByFilePath('/path/to/video.mp4');

      // Assert
      expect(result, isNull);
    });

    test('should handle file paths with spaces', () async {
      // Arrange
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/path with spaces/my video.mp4');
      when(mockFile.exists).thenAnswer((_) async => true);
      when(mockFile.existsSync).thenReturn(true);
      when(mockFile.lengthSync).thenReturn(1000000);

      await uploadManager.startUpload(
        videoFile: mockFile,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final result = uploadManager.getUploadByFilePath(
        '/path with spaces/my video.mp4',
      );

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals('/path with spaces/my video.mp4'));
    });

    test('should handle special characters in file paths', () async {
      // Arrange
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn(r'/path/to/video@#$%^&()_+.mp4');
      when(mockFile.exists).thenAnswer((_) async => true);
      when(mockFile.existsSync).thenReturn(true);
      when(mockFile.lengthSync).thenReturn(1000000);

      await uploadManager.startUpload(
        videoFile: mockFile,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final result = uploadManager.getUploadByFilePath(
        r'/path/to/video@#$%^&()_+.mp4',
      );

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals(r'/path/to/video@#$%^&()_+.mp4'));
    });

    test(
      'should return first match when multiple uploads have same path',
      () async {
        // This shouldn't normally happen, but let's test the edge case
        // We'll create uploads with different timestamps
        final mockFile = MockFile();
        when(() => mockFile.path).thenReturn('/path/to/duplicate.mp4');
        when(mockFile.exists).thenAnswer((_) async => true);
        when(mockFile.existsSync).thenReturn(true);
        when(mockFile.lengthSync).thenReturn(1000000);

        await uploadManager.startUpload(
          videoFile: mockFile,
          nostrPubkey: 'pubkey1',
        );

        // Use proper async coordination to ensure different timestamps
        // Check that first upload is tracked before creating second
        expect(uploadManager.pendingUploads.length, equals(1));

        await uploadManager.startUpload(
          videoFile: mockFile,
          nostrPubkey: 'pubkey2',
        );

        // Act
        final result = uploadManager.getUploadByFilePath(
          '/path/to/duplicate.mp4',
        );
        final allUploads = uploadManager.pendingUploads;

        // Assert
        expect(result, isNotNull);
        expect(
          allUploads
              .where((u) => u.localVideoPath == '/path/to/duplicate.mp4')
              .length,
          equals(2),
        );
        // The method returns the first match from the sorted list (newest first)
        expect(
          result?.nostrPubkey,
          equals('pubkey2'),
        ); // The second upload should be newer
      },
    );

    test('should be case sensitive', () async {
      // Arrange
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/Path/To/Video.mp4');
      when(mockFile.exists).thenAnswer((_) async => true);
      when(mockFile.existsSync).thenReturn(true);
      when(mockFile.lengthSync).thenReturn(1000000);

      await uploadManager.startUpload(
        videoFile: mockFile,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final resultLowerCase = uploadManager.getUploadByFilePath(
        '/path/to/video.mp4',
      );
      final resultCorrectCase = uploadManager.getUploadByFilePath(
        '/Path/To/Video.mp4',
      );

      // Assert
      expect(resultLowerCase, isNull);
      expect(resultCorrectCase, isNotNull);
      expect(resultCorrectCase?.localVideoPath, equals('/Path/To/Video.mp4'));
    });
  });
}
