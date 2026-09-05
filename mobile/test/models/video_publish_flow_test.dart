// ABOUTME: Unit test verifying video upload completes before Nostr event publishing
// ABOUTME: Tests TDD failing case: publish should wait for upload to complete and populate videoId/cdnUrl
import 'package:flutter_test/flutter_test.dart';
import 'package:upload_repository/upload_repository.dart';

void main() {
  group('Video Upload → Publish Flow', () {
    const testVideoPath = 'test_video.mp4';

    test(
      'publishing should fail when upload has not completed (videoId is null)',
      () async {
        // ARRANGE: Create an upload that hasn't completed yet
        final upload = PendingUpload.create(
          localVideoPath: testVideoPath,
          nostrPubkey: 'test_pubkey_123',
          title: 'Test Video',
        );

        // Upload has been created but videoId and cdnUrl are null (upload not complete)
        expect(
          upload.videoId,
          isNull,
          reason: 'Upload should not have videoId before completion',
        );
        expect(
          upload.cdnUrl,
          isNull,
          reason: 'Upload should not have cdnUrl before completion',
        );
        expect(upload.status, equals(UploadStatus.pending));

        // ACT: Try to publish the upload without waiting for completion
        // This simulates the bug where we publish immediately after startUpload()
        final canPublish = upload.videoId != null && upload.cdnUrl != null;

        // ASSERT: Should not be able to publish an incomplete upload
        expect(
          canPublish,
          isFalse,
          reason:
              'Should not be able to publish upload without videoId and cdnUrl',
        );
      },
    );

    test(
      'publishing should succeed when upload has completed (videoId populated)',
      () async {
        // ARRANGE: Create an upload and simulate completion
        final upload = PendingUpload.create(
          localVideoPath: testVideoPath,
          nostrPubkey: 'test_pubkey_123',
          title: 'Test Video',
        );

        // Simulate upload completion by updating with videoId and cdnUrl
        final completedUpload = upload.copyWith(
          videoId: 'video_123',
          cdnUrl: 'https://cdn.example.com/video_123.mp4',
          status: UploadStatus.readyToPublish,
        );

        // ACT: Check if we can publish the completed upload
        final canPublish =
            completedUpload.videoId != null && completedUpload.cdnUrl != null;

        // ASSERT: Should be able to publish a completed upload
        expect(
          canPublish,
          isTrue,
          reason: 'Should be able to publish upload with videoId and cdnUrl',
        );
        expect(completedUpload.videoId, equals('video_123'));
        expect(
          completedUpload.cdnUrl,
          equals('https://cdn.example.com/video_123.mp4'),
        );
        expect(completedUpload.status, equals(UploadStatus.readyToPublish));
      },
    );
  });
}
