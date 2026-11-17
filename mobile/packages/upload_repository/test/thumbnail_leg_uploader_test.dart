// ABOUTME: Pins that each way the thumbnail leg can end without a CDN URL
// ABOUTME: comes back as a ThumbnailUploadException naming its real cause.

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:upload_repository/upload_repository.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group(ThumbnailLegUploader, () {
    late Directory tempDir;
    late _MockBlossomUploadService blossom;
    late File videoFile;
    late PendingUpload upload;

    ThumbnailLegUploader leg(ThumbnailExtractor extractor) =>
        ThumbnailLegUploader(
          blossomService: blossom,
          thumbnailExtractor: extractor,
          blurhashGenerator: (Uint8List bytes) async => 'blurhash',
          telemetry: (phase, elapsed, {bytes, detail}) {},
          defaultThumbnailTimestamp: Duration.zero,
        );

    /// Writes a thumbnail file the way the native extractor would.
    Future<ThumbnailExtraction?> extractFrame({
      required String videoPath,
      required Duration targetTimestamp,
      required int quality,
    }) async {
      final path = '${tempDir.path}/thumb.jpg';
      File(path).writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      return (path: path);
    }

    void stubThumbnailUpload(BlossomUploadResult result) {
      when(
        () => blossom.uploadImage(
          imageFile: any(named: 'imageFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          allowResumable: any(named: 'allowResumable'),
        ),
      ).thenAnswer((_) async => result);
    }

    setUpAll(() {
      registerFallbackValue(File(''));
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('thumbnail_leg_');
      addTearDown(() => tempDir.delete(recursive: true));
      blossom = _MockBlossomUploadService();
      videoFile = File('${tempDir.path}/video.mp4')..writeAsBytesSync([0, 1]);
      upload = PendingUpload.create(
        localVideoPath: videoFile.path,
        nostrPubkey: _pubkey,
      );
    });

    group('run', () {
      test('returns the CDN URL and blurhash with no failure', () async {
        stubThumbnailUpload(
          const BlossomUploadResult(
            success: true,
            url: 'https://media.divine.video/thumb',
          ),
        );

        final result = await leg(
          extractFrame,
        ).run(videoFile: videoFile, nostrPubkey: _pubkey, upload: upload);

        expect(result.cdnUrl, equals('https://media.divine.video/thumb'));
        expect(result.blurhash, equals('blurhash'));
        expect(result.failure, isNull);
      });

      test('names an extractor that found no frame', () async {
        final result =
            await leg(
              ({
                required String videoPath,
                required Duration targetTimestamp,
                required int quality,
              }) async => null,
            ).run(
              videoFile: videoFile,
              nostrPubkey: _pubkey,
              upload: upload,
            );

        expect(result.cdnUrl, isNull);
        expect(
          result.failure?.stage,
          equals(ThumbnailUploadFailureStage.extraction),
        );
        expect(result.failure?.cause, contains('no frame'));
      });

      test('names a thumbnail file that vanished after extraction', () async {
        final result =
            await leg(
              ({
                required String videoPath,
                required Duration targetTimestamp,
                required int quality,
              }) async => (path: '${tempDir.path}/gone.jpg'),
            ).run(
              videoFile: videoFile,
              nostrPubkey: _pubkey,
              upload: upload,
            );

        expect(
          result.failure?.stage,
          equals(ThumbnailUploadFailureStage.extraction),
        );
        expect(result.failure?.cause, contains('missing'));
      });

      test('keeps what an extractor threw as an extraction failure', () async {
        final result =
            await leg(
              ({
                required String videoPath,
                required Duration targetTimestamp,
                required int quality,
              }) async => throw const FileSystemException('decoder busy'),
            ).run(
              videoFile: videoFile,
              nostrPubkey: _pubkey,
              upload: upload,
            );

        expect(
          result.failure?.stage,
          equals(ThumbnailUploadFailureStage.extraction),
        );
        expect(result.failure?.cause, contains('decoder busy'));
      });

      test('keeps the server status of a rejected upload', () async {
        stubThumbnailUpload(
          const BlossomUploadResult(
            success: false,
            statusCode: 503,
            errorMessage: 'Upload failed: 503',
            failureReason: BlossomUploadFailureReason.server,
          ),
        );

        final result = await leg(
          extractFrame,
        ).run(videoFile: videoFile, nostrPubkey: _pubkey, upload: upload);

        expect(result.cdnUrl, isNull);
        expect(result.blurhash, equals('blurhash'));
        expect(
          result.failure?.stage,
          equals(ThumbnailUploadFailureStage.upload),
        );
        expect(result.failure?.statusCode, equals(503));
        expect(result.failure?.isTransient, isTrue);
      });

      test('keeps what the upload threw as an upload failure', () async {
        when(
          () => blossom.uploadImage(
            imageFile: any(named: 'imageFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            allowResumable: any(named: 'allowResumable'),
          ),
        ).thenThrow(StateError('auth provider closed'));

        final result = await leg(
          extractFrame,
        ).run(videoFile: videoFile, nostrPubkey: _pubkey, upload: upload);

        expect(
          result.failure?.stage,
          equals(ThumbnailUploadFailureStage.upload),
        );
        expect(result.failure?.cause, contains('auth provider closed'));
        expect(result.failure?.isTransient, isFalse);
      });
    });
  });
}
