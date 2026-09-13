import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upload_repository/upload_repository.dart';

void main() {
  group('PendingUpload resumable upload sessions', () {
    test('stores resumable session metadata', () {
      final upload =
          PendingUpload.create(
            localVideoPath: '/path/to/video.mp4',
            nostrPubkey: 'pubkey123',
          ).copyWith(
            resumableSession: const BlossomResumableUploadSession(
              uploadId: 'up_123',
              uploadUrl: 'https://upload.divine.video/sessions/up_123',
              chunkSize: 8 * 1024 * 1024,
              nextOffset: 16 * 1024 * 1024,
            ),
          );

      expect(upload.resumableSession?.uploadId, equals('up_123'));
      expect(
        upload.resumableSession?.uploadUrl,
        equals('https://upload.divine.video/sessions/up_123'),
      );
      expect(upload.resumableSession?.chunkSize, equals(8 * 1024 * 1024));
      expect(upload.resumableSession?.nextOffset, equals(16 * 1024 * 1024));
    });

    test('copyWith can clear resumable session metadata', () {
      final upload =
          PendingUpload.create(
            localVideoPath: '/path/to/video.mp4',
            nostrPubkey: 'pubkey123',
          ).copyWith(
            resumableSession: const BlossomResumableUploadSession(
              uploadId: 'up_123',
              uploadUrl: 'https://upload.divine.video/sessions/up_123',
              chunkSize: 8 * 1024 * 1024,
              nextOffset: 16 * 1024 * 1024,
            ),
          );

      final cleared = upload.copyWith(resumableSession: null);

      expect(cleared.resumableSession, isNull);
    });
  });
}
