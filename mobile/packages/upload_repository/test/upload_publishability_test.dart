import 'package:flutter_test/flutter_test.dart';
import 'package:upload_repository/upload_repository.dart';

void main() {
  group('readyUploadIsPublishable', () {
    test('accepts ready uploads with video id and HTTP media URLs', () {
      final upload = _upload();

      expect(readyUploadIsPublishable(upload), isTrue);
    });

    test('rejects uploads that are not ready to publish', () {
      final upload = _upload(status: UploadStatus.uploading);

      expect(readyUploadIsPublishable(upload), isFalse);
    });

    test('rejects ready uploads without a video id', () {
      final upload = _upload(videoId: '');

      expect(readyUploadIsPublishable(upload), isFalse);
    });

    test('rejects ready uploads without an HTTP CDN URL', () {
      final upload = _upload(cdnUrl: '/tmp/local-video.mp4');

      expect(readyUploadIsPublishable(upload), isFalse);
    });

    test('rejects ready uploads without an HTTP thumbnail URL', () {
      final upload = _upload(thumbnailPath: '/tmp/local-thumbnail.jpg');

      expect(readyUploadIsPublishable(upload), isFalse);
    });
  });
}

PendingUpload _upload({
  UploadStatus status = UploadStatus.readyToPublish,
  String? videoId = 'video-123',
  String? cdnUrl = 'https://media.divine.video/video-123',
  String? thumbnailPath = 'https://media.divine.video/thumb-123',
}) {
  return PendingUpload(
    id: 'upload-123',
    localVideoPath: '/tmp/video.mp4',
    nostrPubkey: 'npub-test',
    status: status,
    createdAt: DateTime(2026),
    videoId: videoId,
    cdnUrl: cdnUrl,
    thumbnailPath: thumbnailPath,
  );
}
