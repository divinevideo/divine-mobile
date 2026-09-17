// ABOUTME: Tests for VideoImetaBuilder: publishable-URL selection, file-derived
// ABOUTME: metadata, and the stored-blurhash shortcut of the imeta tag

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_publish/video_imeta_builder.dart';

void main() {
  group(VideoImetaBuilder, () {
    late Directory tempDir;
    late File testVideoFile;
    const builder = VideoImetaBuilder();

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('video_imeta_builder');
      testVideoFile = File('${tempDir.path}/test_video.mp4');
      await testVideoFile.writeAsString('not really a video');
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    PendingUpload upload({
      String? localVideoPath,
      String? cdnUrl = 'https://cdn.divine.video/abc123.mp4',
      String? streamingMp4Url,
      String? fallbackUrl,
      String? streamingHlsUrl,
      String? thumbnailPath,
      String? videoId,
      String? blurhash,
      int? videoWidth,
      int? videoHeight,
    }) =>
        PendingUpload.create(
          localVideoPath: localVideoPath ?? testVideoFile.path,
          nostrPubkey: 'test_pubkey',
          thumbnailPath: thumbnailPath,
          videoWidth: videoWidth,
          videoHeight: videoHeight,
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: cdnUrl,
          streamingMp4Url: streamingMp4Url,
          fallbackUrl: fallbackUrl,
          streamingHlsUrl: streamingHlsUrl,
          videoId: videoId,
          blurhash: blurhash,
        );

    group('hasPublishableVideoUrl', () {
      test('accepts any live HTTP video URL', () {
        expect(
          VideoImetaBuilder.hasPublishableVideoUrl(upload(cdnUrl: null)),
          isFalse,
        );
        expect(
          VideoImetaBuilder.hasPublishableVideoUrl(
            upload(cdnUrl: null, fallbackUrl: 'https://cdn.example/a.mp4'),
          ),
          isTrue,
        );
      });

      test('rejects local paths and known dead media hosts', () {
        expect(
          VideoImetaBuilder.hasPublishableVideoUrl(
            upload(cdnUrl: '/var/mobile/video.mp4'),
          ),
          isFalse,
        );
        expect(
          VideoImetaBuilder.hasPublishableVideoUrl(
            upload(
              cdnUrl: 'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/playlist.m3u8',
            ),
          ),
          isFalse,
        );
      });
    });

    group('build', () {
      test(
        'emits url, mime, image, dim, x, size and a stored blurhash',
        () async {
          final tag = await builder.build(
            upload(
              thumbnailPath: 'https://example.com/thumbnail.jpg',
              videoWidth: 1920,
              videoHeight: 1080,
              videoId: 'sha256-of-the-file',
              blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
            ),
            thumbnailTimestamp: null,
          );

          expect(
            tag,
            equals([
              'imeta',
              'url https://cdn.divine.video/abc123.mp4',
              'm video/mp4',
              'image https://example.com/thumbnail.jpg',
              'dim 1920x1080',
              'x sha256-of-the-file',
              'size ${testVideoFile.lengthSync()}',
              'blurhash LEHV6nWB2yk8pyo0adR*.7kCMdnj',
            ]),
          );
        },
      );

      test('omits optional components that are unavailable', () async {
        final tag = await builder.build(
          upload(localVideoPath: '${tempDir.path}/missing.mp4'),
          thumbnailTimestamp: null,
        );

        expect(tag, isNotNull);
        expect(tag!.where((c) => c.startsWith('url ')), hasLength(1));
        expect(tag, contains('m video/mp4'));
        expect(tag.any((c) => c.startsWith('image ')), isFalse);
        expect(tag.any((c) => c.startsWith('dim ')), isFalse);
        expect(tag.any((c) => c.startsWith('x ')), isFalse);
        expect(tag.any((c) => c.startsWith('size ')), isFalse);
      });

      test('carries x from the upload even when the file is gone', () async {
        final tag = await builder.build(
          upload(
            localVideoPath: '${tempDir.path}/missing.mp4',
            videoId: 'sha256-of-the-file',
          ),
          thumbnailTimestamp: null,
        );

        expect(tag, contains('x sha256-of-the-file'));
        expect(tag!.any((c) => c.startsWith('size ')), isFalse);
      });

      test('prefers Blossom URLs over the legacy cdnUrl', () async {
        final tag = await builder.build(
          upload(
            streamingMp4Url: 'https://media.divine.video/stream.mp4',
            fallbackUrl: 'https://r2.divine.video/fallback.mp4',
            streamingHlsUrl: 'https://media.divine.video/playlist.m3u8',
          ),
          thumbnailTimestamp: null,
        );

        expect(
          tag!.where((c) => c.startsWith('url ')),
          equals([
            'url https://media.divine.video/stream.mp4',
            'url https://r2.divine.video/fallback.mp4',
            'url https://media.divine.video/playlist.m3u8',
          ]),
        );
      });

      test('skips a local thumbnail path', () async {
        final tag = await builder.build(
          upload(thumbnailPath: '/tmp/thumbnail.jpg'),
          thumbnailTimestamp: null,
        );

        expect(tag!.any((c) => c.startsWith('image ')), isFalse);
      });

      test('returns null when no URL survives the filters', () async {
        final tag = await builder.build(
          upload(
            cdnUrl: 'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/playlist.m3u8',
            streamingMp4Url: '/var/mobile/video.mp4',
          ),
          thumbnailTimestamp: null,
        );

        expect(tag, isNull);
      });
    });
  });
}
