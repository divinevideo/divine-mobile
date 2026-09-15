import 'package:flutter_test/flutter_test.dart';
import 'package:upload_repository/upload_repository.dart';

void main() {
  group('PendingUpload copyWith', () {
    test('preserves URL fields when omitted', () {
      final upload =
          PendingUpload.create(
            localVideoPath: '/path/to/video.mp4',
            nostrPubkey: 'pubkey123',
          ).copyWith(
            cdnUrl: 'https://media.divine.video/video.mp4',
            thumbnailPath: 'https://media.divine.video/thumb.jpg',
            streamingMp4Url: 'https://media.divine.video/stream.mp4',
            streamingHlsUrl: 'https://media.divine.video/stream.m3u8',
            fallbackUrl: 'https://media.divine.video/fallback.mp4',
          );

      final copied = upload.copyWith(status: UploadStatus.readyToPublish);

      expect(copied.cdnUrl, equals(upload.cdnUrl));
      expect(copied.thumbnailPath, equals(upload.thumbnailPath));
      expect(copied.streamingMp4Url, equals(upload.streamingMp4Url));
      expect(copied.streamingHlsUrl, equals(upload.streamingHlsUrl));
      expect(copied.fallbackUrl, equals(upload.fallbackUrl));
    });

    test('clears URL fields when explicitly set to null', () {
      final upload =
          PendingUpload.create(
            localVideoPath: '/path/to/video.mp4',
            nostrPubkey: 'pubkey123',
          ).copyWith(
            cdnUrl: 'https://media.divine.video/video.mp4',
            thumbnailPath: 'https://media.divine.video/thumb.jpg',
            streamingMp4Url: 'https://media.divine.video/stream.mp4',
            streamingHlsUrl: 'https://media.divine.video/stream.m3u8',
            fallbackUrl: 'https://media.divine.video/fallback.mp4',
          );

      final cleared = upload.copyWith(
        cdnUrl: null,
        thumbnailPath: null,
        streamingMp4Url: null,
        streamingHlsUrl: null,
        fallbackUrl: null,
      );

      expect(cleared.cdnUrl, isNull);
      expect(cleared.thumbnailPath, isNull);
      expect(cleared.streamingMp4Url, isNull);
      expect(cleared.streamingHlsUrl, isNull);
      expect(cleared.fallbackUrl, isNull);
    });
  });
}
