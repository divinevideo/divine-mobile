// ABOUTME: Unit tests for UploadManager.getUploadByFilePath method
// ABOUTME: Tests file path lookup functionality using the public API

// Permanent: initializes Hive's process-wide box registry and the shared test
// platform-channel environment for UploadManager lookup coverage.
@Tags(['skip_very_good_optimization'])
library;

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../helpers/real_integration_test_helper.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/mock_path_provider_platform.dart';

class MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UploadManager uploadManager;
  late MockBlossomUploadService mockUploadService;
  late Directory tempDir;
  late PathProviderPlatform originalPathProviderInstance;

  setUpAll(() async {
    // Setup test environment with platform channel mocks
    await RealIntegrationTestHelper.setupTestEnvironment();
    originalPathProviderInstance = PathProviderPlatform.instance;
    registerFallbackValue(File(''));
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'upload_manager_get_by_path_test_',
    );
    final pathProvider = MockPathProviderPlatform()
      ..setTemporaryPath(tempDir.path)
      ..setApplicationDocumentsPath('${tempDir.path}/documents')
      ..setApplicationSupportPath('${tempDir.path}/support');
    PathProviderPlatform.instance = pathProvider;
    await TestHelpers.initHiveHome();

    // Use the reusable test helper to ensure a fresh empty Hive box. The
    // per-test path prevents concurrent Flutter test processes from sharing
    // the same pending_uploads file.
    await TestHelpers.cleanupHiveBox('pending_uploads');

    mockUploadService = MockBlossomUploadService();
    when(
      () => mockUploadService.isBlossomEnabled(),
    ).thenAnswer((_) async => false);
    when(
      () => mockUploadService.uploadVideoWithResume(
        videoFile: any(named: 'videoFile'),
        nostrPubkey: any(named: 'nostrPubkey'),
        taskId: any(named: 'taskId'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        hashtags: any(named: 'hashtags'),
        proofManifestJson: any(named: 'proofManifestJson'),
        useBackgroundFirst: any(named: 'useBackgroundFirst'),
        resumableTimeout: any(named: 'resumableTimeout'),
        resumableSession: any(named: 'resumableSession'),
        onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (_) async => const BlossomUploadResult(
        success: true,
        videoId: 'test-video-id',
        url: 'https://media.divine.video/test-video-id',
        fallbackUrl: 'https://media.divine.video/test-video-id',
        thumbnailUrl: 'https://media.divine.video/test-video-id-thumb.jpg',
      ),
    );

    uploadManager = UploadManager(
      backgroundActivityManager: BackgroundActivityManager(),
      blossomService: mockUploadService,
    );
    await uploadManager.initialize();
    expect(
      uploadManager.pendingUploads,
      isEmpty,
      reason: 'setUp must hand each test an empty pending_uploads box',
    );
  });

  tearDown(() async {
    // Detach the manager from the box first, then close and delete the box so
    // the next suite in the merged isolate does not inherit these rows (#6748).
    uploadManager.dispose();
    await TestHelpers.cleanupHiveBox('pending_uploads');
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    PathProviderPlatform.instance = originalPathProviderInstance;
    reset(mockUploadService);
  });

  File createVideoFile(String relativePath, List<int> bytes) {
    final file = File('${tempDir.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file;
  }

  group('UploadManager.getUploadByFilePath', () {
    test('should return upload with matching file path', () async {
      // Arrange - Create some test uploads
      final file1 = createVideoFile('path/to/video1.mp4', [0, 1, 2]);
      final file2 = createVideoFile('path/to/video2.mp4', [3, 4, 5]);
      final file3 = createVideoFile('path/to/video3.mp4', [6, 7, 8]);

      // Start uploads to create PendingUpload entries
      await uploadManager.startUpload(videoFile: file1, nostrPubkey: 'pubkey1');
      await uploadManager.startUpload(videoFile: file2, nostrPubkey: 'pubkey2');
      await uploadManager.startUpload(videoFile: file3, nostrPubkey: 'pubkey3');

      // Act
      final result = uploadManager.getUploadByFilePath(file2.path);

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals(file2.path));
      expect(result?.nostrPubkey, equals('pubkey2'));
    });

    test('should return null when no upload matches file path', () async {
      // Arrange
      final file1 = createVideoFile('path/to/video1.mp4', [0, 1, 2]);

      await uploadManager.startUpload(videoFile: file1, nostrPubkey: 'pubkey1');

      // Act
      final missingPath = '${tempDir.path}/path/to/nonexistent.mp4';
      final result = uploadManager.getUploadByFilePath(missingPath);

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
      final file = createVideoFile('path with spaces/my video.mp4', [0, 1, 2]);

      await uploadManager.startUpload(videoFile: file, nostrPubkey: 'pubkey1');

      // Act
      final result = uploadManager.getUploadByFilePath(file.path);

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals(file.path));
    });

    test('should handle special characters in file paths', () async {
      // Arrange
      final file = createVideoFile(r'path/to/video@#$%^&()_+.mp4', [0, 1, 2]);

      await uploadManager.startUpload(videoFile: file, nostrPubkey: 'pubkey1');

      // Act
      final result = uploadManager.getUploadByFilePath(file.path);

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals(file.path));
    });

    test(
      'should return first match when multiple uploads have same path',
      () async {
        // This shouldn't normally happen, but let's test the edge case
        // We'll create uploads with different timestamps
        final file = createVideoFile('path/to/duplicate.mp4', [0, 1, 2]);

        await uploadManager.startUpload(
          videoFile: file,
          nostrPubkey: 'pubkey1',
        );

        // Use proper async coordination to ensure different timestamps
        // Check that first upload is tracked before creating second
        expect(uploadManager.pendingUploads.length, equals(1));

        await uploadManager.startUpload(
          videoFile: file,
          nostrPubkey: 'pubkey2',
        );

        // Act
        final result = uploadManager.getUploadByFilePath(file.path);
        final allUploads = uploadManager.pendingUploads;

        // Assert
        expect(result, isNotNull);
        expect(
          allUploads.where((u) => u.localVideoPath == file.path).length,
          2,
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
      final file = createVideoFile('Path/To/Video.mp4', [0, 1, 2]);

      await uploadManager.startUpload(videoFile: file, nostrPubkey: 'pubkey1');

      // Act
      final resultLowerCase = uploadManager.getUploadByFilePath(
        '${tempDir.path}/path/to/video.mp4',
      );
      final resultCorrectCase = uploadManager.getUploadByFilePath(file.path);

      // Assert
      expect(resultLowerCase, isNull);
      expect(resultCorrectCase, isNotNull);
      expect(resultCorrectCase?.localVideoPath, equals(file.path));
    });
  });
}
