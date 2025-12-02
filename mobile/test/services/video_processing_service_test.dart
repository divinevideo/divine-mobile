// ABOUTME: Tests for video processing polling service that waits for Cloudflare Stream completion
// ABOUTME: Validates background polling, retry logic, and completion detection for uploaded videos

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/video_processing_service.dart';

@GenerateMocks([Dio])
import 'video_processing_service_test.mocks.dart';

void main() {
  group('VideoProcessingService', () {
    late VideoProcessingService service;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      service = VideoProcessingService(dio: mockDio);
    });

    test(
      'should poll blob descriptor until HTTP 200 and return processing result',
      () async {
        const serverUrl =
            'https://cf-stream-service-prod.protestnet.workers.dev';
        const fileHash =
            'fa54a5b814fe5b25c512025e83dd7acf8b40a75537080956a4f0ed6069f645fc';
        const videoId = 'bbdfb69ae2be4acda66edc3a8b8ef66a';

        // Mock sequence: 202 -> 202 -> 200 (processing -> processing -> ready)
        var callCount = 0;
        when(
          mockDio.get('$serverUrl/$fileHash', options: anyNamed('options')),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount <= 2) {
            return Response(
              statusCode: 202,
              data: 'Not Ready',
              requestOptions: RequestOptions(path: ''),
            );
          } else {
            return Response(
              statusCode: 200,
              data: {
                'sha256': fileHash,
                'url': 'https://stream.cloudflare.com/$videoId.mp4',
                'hls': 'https://stream.cloudflare.com/$videoId/manifest.m3u8',
                'thumbnail':
                    'https://stream.cloudflare.com/$videoId/thumbnail.jpg',
              },
              requestOptions: RequestOptions(path: ''),
            );
          }
        });

        final result = await service.pollForProcessingCompletion(
          serverUrl: serverUrl,
          fileHash: fileHash,
          videoId: videoId,
          maxAttempts: 5,
          pollInterval: const Duration(milliseconds: 100), // Fast for testing
        );

        expect(result.success, true);
        expect(result.videoId, videoId);
        expect(result.cdnUrl, 'https://stream.cloudflare.com/$videoId.mp4');
        expect(
          result.hlsUrl,
          'https://stream.cloudflare.com/$videoId/manifest.m3u8',
        );
        expect(
          result.thumbnailUrl,
          'https://stream.cloudflare.com/$videoId/thumbnail.jpg',
        );

        // Should have polled 3 times (202, 202, 200)
        verify(
          mockDio.get('$serverUrl/$fileHash', options: anyNamed('options')),
        ).called(3);
      },
    );

    test('should timeout after max attempts and return failure', () async {
      const serverUrl = 'https://cf-stream-service-prod.protestnet.workers.dev';
      const fileHash =
          'fa54a5b814fe5b25c512025e83dd7acf8b40a75537080956a4f0ed6069f645fc';
      const videoId = 'bbdfb69ae2be4acda66edc3a8b8ef66a';

      // Mock always returning 202 (never completes)
      when(
        mockDio.get('$serverUrl/$fileHash', options: anyNamed('options')),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 202,
          data: 'Not Ready',
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final result = await service.pollForProcessingCompletion(
        serverUrl: serverUrl,
        fileHash: fileHash,
        videoId: videoId,
        maxAttempts: 3,
        pollInterval: const Duration(milliseconds: 50), // Fast for testing
      );

      expect(result.success, false);
      expect(result.errorMessage, contains('Processing timeout'));

      // Should have polled 3 times then given up
      verify(
        mockDio.get('$serverUrl/$fileHash', options: anyNamed('options')),
      ).called(3);
    });

    test('should handle network errors gracefully and retry', () async {
      const serverUrl = 'https://cf-stream-service-prod.protestnet.workers.dev';
      const fileHash =
          'fa54a5b814fe5b25c512025e83dd7acf8b40a75537080956a4f0ed6069f645fc';
      const videoId = 'bbdfb69ae2be4acda66edc3a8b8ef66a';

      // Mock sequence: network error -> 202 -> 200 (error -> processing -> ready)
      var callCount = 0;
      when(
        mockDio.get('$serverUrl/$fileHash', options: anyNamed('options')),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          );
        } else if (callCount == 2) {
          return Response(
            statusCode: 202,
            data: 'Not Ready',
            requestOptions: RequestOptions(path: ''),
          );
        } else {
          return Response(
            statusCode: 200,
            data: {
              'sha256': fileHash,
              'url': 'https://stream.cloudflare.com/$videoId.mp4',
            },
            requestOptions: RequestOptions(path: ''),
          );
        }
      });

      final result = await service.pollForProcessingCompletion(
        serverUrl: serverUrl,
        fileHash: fileHash,
        videoId: videoId,
        maxAttempts: 5,
        pollInterval: const Duration(milliseconds: 100), // Fast for testing
      );

      expect(result.success, true);
      expect(result.cdnUrl, 'https://stream.cloudflare.com/$videoId.mp4');

      // Should have tried 3 times (error, 202, 200)
      verify(
        mockDio.get('$serverUrl/$fileHash', options: anyNamed('options')),
      ).called(3);
    });

    test('should call progress callback during polling', () async {
      const serverUrl = 'https://cf-stream-service-prod.protestnet.workers.dev';
      const fileHash =
          'fa54a5b814fe5b25c512025e83dd7acf8b40a75537080956a4f0ed6069f645fc';
      const videoId = 'bbdfb69ae2be4acda66edc3a8b8ef66a';

      final progressCalls = <double>[];

      var callCount = 0;
      when(
        mockDio.get('$serverUrl/$fileHash', options: anyNamed('options')),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return Response(
            statusCode: 202,
            data: 'Not Ready',
            requestOptions: RequestOptions(path: ''),
          );
        } else {
          return Response(
            statusCode: 200,
            data: {
              'sha256': fileHash,
              'url': 'https://stream.cloudflare.com/$videoId.mp4',
            },
            requestOptions: RequestOptions(path: ''),
          );
        }
      });

      final result = await service.pollForProcessingCompletion(
        serverUrl: serverUrl,
        fileHash: fileHash,
        videoId: videoId,
        maxAttempts: 5,
        pollInterval: const Duration(milliseconds: 100),
        onProgress: (progress) => progressCalls.add(progress),
      );

      expect(result.success, true);
      expect(progressCalls, isNotEmpty);
      expect(progressCalls.last, 1.0); // Should end at 100%
    });
  });
}
