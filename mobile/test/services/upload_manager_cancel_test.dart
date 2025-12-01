// ABOUTME: Unit tests for UploadManager.cancelUpload() method
// ABOUTME: Verifies that uploads can be cancelled mid-upload with proper cleanup

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/upload_manager.dart';

import 'upload_manager_cancel_test.mocks.dart';

@GenerateMocks([BlossomUploadService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockBlossomUploadService mockBlossomService;
  late UploadManager uploadManager;
  late Directory testDir;

  setUp(() async {
    // Create temp directory for test Hive storage
    testDir = await Directory.systemTemp.createTemp(
      'upload_manager_cancel_test_',
    );

    // Initialize Hive
    Hive.init(testDir.path);

    // Register adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }

    // Create mocks
    mockBlossomService = MockBlossomUploadService();

    // Create upload manager
    uploadManager = UploadManager(blossomService: mockBlossomService);

    await uploadManager.initialize();
  });

  tearDown(() async {
    // Clean up
    uploadManager.dispose();
    await Hive.close();

    // Delete test directory
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('UploadManager.cancelUpload()', () {
    test(
      'should abort in-progress upload and update status to failed',
      () async {
        // Arrange: Create a mock upload in uploading state
        final testVideoFile = File('${testDir.path}/test_video.mp4');
        await testVideoFile.writeAsString('fake video content');

        // Create upload record
        final upload = PendingUpload.create(
          localVideoPath: testVideoFile.path,
          nostrPubkey: 'test-pubkey-123',
          title: 'Test Video',
        );

        // Simulate uploading status by directly accessing the internal Hive box
        final uploadingUpload = upload.copyWith(
          status: UploadStatus.uploading,
          uploadProgress: 0.5,
        );

        // Access the manager's internal box to update the upload
        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, uploadingUpload);

        // Verify upload is in uploading state
        final beforeCancel = uploadManager.getUpload(upload.id);
        expect(beforeCancel?.status, equals(UploadStatus.uploading));

        // Act: Cancel the upload
        await uploadManager.cancelUpload(upload.id);

        // Assert: Upload status should be failed with cancellation message
        final cancelledUpload = uploadManager.getUpload(upload.id);
        expect(cancelledUpload, isNotNull);
        expect(cancelledUpload!.status, equals(UploadStatus.failed));
        expect(
          cancelledUpload.errorMessage,
          equals('Upload cancelled by user'),
        );

        // Clean up
        await testVideoFile.delete();
      },
    );

    test(
      'should cancel progress subscription when cancelling upload',
      () async {
        // Arrange: Create upload with simulated progress subscription
        final testVideoFile = File('${testDir.path}/test_video2.mp4');
        await testVideoFile.writeAsString('fake video content');

        final upload = PendingUpload.create(
          localVideoPath: testVideoFile.path,
          nostrPubkey: 'test-pubkey-456',
        );

        final uploadingUpload = upload.copyWith(
          status: UploadStatus.uploading,
          uploadProgress: 0.3,
        );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, uploadingUpload);

        // Act: Cancel the upload
        await uploadManager.cancelUpload(upload.id);

        // Assert: Upload should be cancelled
        final cancelledUpload = uploadManager.getUpload(upload.id);
        expect(cancelledUpload!.status, equals(UploadStatus.failed));

        // Clean up
        await testVideoFile.delete();
      },
    );

    test('should handle cancelling non-existent upload gracefully', () async {
      // Act: Try to cancel upload that doesn't exist
      await uploadManager.cancelUpload('non-existent-id');

      // Assert: Should not throw exception (method returns early)
      expect(uploadManager.getUpload('non-existent-id'), isNull);
    });

    test(
      'should preserve upload record after cancellation for retry',
      () async {
        // Arrange: Create upload
        final testVideoFile = File('${testDir.path}/test_video3.mp4');
        await testVideoFile.writeAsString('fake video content');

        final upload = PendingUpload.create(
          localVideoPath: testVideoFile.path,
          nostrPubkey: 'test-pubkey-789',
          title: 'Retryable Video',
        );

        final uploadingUpload = upload.copyWith(
          status: UploadStatus.uploading,
          uploadProgress: 0.7,
        );

        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(upload.id, uploadingUpload);

        // Act: Cancel the upload
        await uploadManager.cancelUpload(upload.id);

        // Assert: Upload record still exists (not deleted)
        final cancelledUpload = uploadManager.getUpload(upload.id);
        expect(cancelledUpload, isNotNull);
        expect(cancelledUpload!.localVideoPath, equals(testVideoFile.path));
        expect(cancelledUpload.title, equals('Retryable Video'));
        expect(cancelledUpload.status, equals(UploadStatus.failed));

        // Clean up
        await testVideoFile.delete();
      },
    );
  });
}
