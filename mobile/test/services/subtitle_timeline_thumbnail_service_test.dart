// ABOUTME: Tests for SubtitleTimelineThumbnailService — caching a published
// ABOUTME: video before extracting the timeline's filmstrip.

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/subtitle_timeline_thumbnail_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

void main() {
  group(SubtitleTimelineThumbnailService, () {
    late Directory temp;
    late File video;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('subtitle_thumbnails');
      video = File('${temp.path}/video.mp4')..writeAsStringSync('not a video');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('extracts frames from the cached file', () async {
      final requestedPaths = <String>[];
      final downloadedUrls = <String>[];
      final service = SubtitleTimelineThumbnailService(
        downloadVideo: ({required String url, required String cacheKey}) async {
          downloadedUrls.add(url);
          return video;
        },
        resolveVideoUrl: (url) async => 'https://example.com/resolved.mp4',
        stripThumbnailStreamFactory:
            ({
              required String videoPath,
              required String clipId,
              required Duration duration,
              required Size outputSize,
              required int thumbsPerSecond,
              Duration startOffset = Duration.zero,
              List<Duration>? priorityTimestamps,
            }) {
              requestedPaths.add(videoPath);
              return Stream.value([
                StripThumbnail(
                  path: '$videoPath.jpg',
                  timestamp: Duration.zero,
                ),
              ]);
            },
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: const Duration(seconds: 6),
            devicePixelRatio: 2,
          )
          .toList();

      expect(requestedPaths, [video.path]);
      expect(downloadedUrls, ['https://example.com/resolved.mp4']);
      expect(batches.single.single.path, '${video.path}.jpg');
    });

    test('unresolved HLS manifests are not cached or extracted', () async {
      final service = SubtitleTimelineThumbnailService(
        downloadVideo: ({
          required String url,
          required String cacheKey,
        }) async => fail('HLS manifests must not be cached under the video id'),
        resolveVideoUrl: (url) async =>
            'https://media.divine.video/video/hls/master.m3u8',
        stripThumbnailStreamFactory: ({
          required String videoPath,
          required String clipId,
          required Duration duration,
          required Size outputSize,
          required int thumbsPerSecond,
          Duration startOffset = Duration.zero,
          List<Duration>? priorityTimestamps,
        }) => fail('extraction must not start for an HLS manifest'),
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://media.divine.video/video/hls/master.m3u8',
            videoId: 'v',
            duration: const Duration(seconds: 6),
            devicePixelRatio: 2,
          )
          .toList();

      expect(batches, isEmpty);
    });

    test('yields nothing when the video cannot be cached', () async {
      final service = SubtitleTimelineThumbnailService(
        downloadVideo: ({
          required String url,
          required String cacheKey,
        }) async => null,
        stripThumbnailStreamFactory: ({
          required String videoPath,
          required String clipId,
          required Duration duration,
          required Size outputSize,
          required int thumbsPerSecond,
          Duration startOffset = Duration.zero,
          List<Duration>? priorityTimestamps,
        }) => fail('extraction must not start without a file'),
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: const Duration(seconds: 6),
            devicePixelRatio: 2,
          )
          .toList();

      expect(batches, isEmpty);
    });

    test('a failed download leaves the timeline without frames', () async {
      final service = SubtitleTimelineThumbnailService(
        downloadVideo: ({
          required String url,
          required String cacheKey,
        }) async => throw const SocketException('offline'),
        stripThumbnailStreamFactory: ({
          required String videoPath,
          required String clipId,
          required Duration duration,
          required Size outputSize,
          required int thumbsPerSecond,
          Duration startOffset = Duration.zero,
          List<Duration>? priorityTimestamps,
        }) => fail('extraction must not start without a file'),
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: const Duration(seconds: 6),
            devicePixelRatio: 2,
          )
          .toList();

      expect(batches, isEmpty, reason: 'the failure never reaches the widget');
    });

    test('a failed extraction keeps the frames that arrived', () async {
      final service = SubtitleTimelineThumbnailService(
        downloadVideo: ({
          required String url,
          required String cacheKey,
        }) async => video,
        stripThumbnailStreamFactory:
            ({
              required String videoPath,
              required String clipId,
              required Duration duration,
              required Size outputSize,
              required int thumbsPerSecond,
              Duration startOffset = Duration.zero,
              List<Duration>? priorityTimestamps,
            }) async* {
              yield [
                StripThumbnail(
                  path: '$videoPath.jpg',
                  timestamp: Duration.zero,
                ),
              ];
              // How the extractor reports a native decode failure part-way
              // through: the batches already delivered stand, the rest never
              // arrive.
              throw StateError('decoder gave up');
            },
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: const Duration(seconds: 6),
            devicePixelRatio: 2,
          )
          .toList();

      expect(batches.single.single.path, '${video.path}.jpg');
    });

    test('an unknown duration skips extraction entirely', () async {
      final service = SubtitleTimelineThumbnailService(
        downloadVideo: ({
          required String url,
          required String cacheKey,
        }) async => fail('nothing to extract from, so nothing to download'),
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: Duration.zero,
            devicePixelRatio: 2,
          )
          .toList();

      expect(batches, isEmpty);
    });
  });
}
