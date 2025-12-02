// ABOUTME: Unit tests for ThumbnailApiService URL generation and logic
// ABOUTME: Tests URL construction, parameter handling, and validation logic

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/thumbnail_api_service.dart';

void main() {
  group('ThumbnailApiService', () {
    group('getThumbnailUrl', () {
      test('generates correct URL with default parameters', () {
        final url = ThumbnailApiService.getThumbnailUrl('test-video-id');
        expect(
          url,
          equals('https://api.openvine.co/thumbnail/test-video-id?t=2.5'),
        );
      });

      test('generates correct URL with custom time', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-video-id',
          timeSeconds: 5,
        );
        expect(
          url,
          equals('https://api.openvine.co/thumbnail/test-video-id?t=5.0'),
        );
      });

      test('generates correct URL with small size', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-video-id',
          size: ThumbnailSize.small,
        );
        expect(
          url,
          equals(
            'https://api.openvine.co/thumbnail/test-video-id?t=2.5&size=small',
          ),
        );
      });

      test('generates correct URL with large size', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-video-id',
          size: ThumbnailSize.large,
        );
        expect(
          url,
          equals(
            'https://api.openvine.co/thumbnail/test-video-id?t=2.5&size=large',
          ),
        );
      });

      test('generates correct URL with medium size (no size param)', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-video-id',
          size: ThumbnailSize.medium,
        );
        expect(
          url,
          equals('https://api.openvine.co/thumbnail/test-video-id?t=2.5'),
        );
      });

      test('handles special characters in video ID', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-video-id-with-dashes',
        );
        expect(
          url,
          equals(
            'https://api.openvine.co/thumbnail/test-video-id-with-dashes?t=2.5',
          ),
        );
      });

      test('handles complex video ID', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          '87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344',
        );
        expect(
          url,
          equals(
            'https://api.openvine.co/thumbnail/87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344?t=2.5',
          ),
        );
      });

      test('handles zero time', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-video-id',
          timeSeconds: 0,
        );
        expect(
          url,
          equals('https://api.openvine.co/thumbnail/test-video-id?t=0.0'),
        );
      });

      test('handles decimal time', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-video-id',
          timeSeconds: 3.7,
        );
        expect(
          url,
          equals('https://api.openvine.co/thumbnail/test-video-id?t=3.7'),
        );
      });

      test('handles all size combinations correctly', () {
        final testCases = [
          {'size': ThumbnailSize.small, 'expected': '&size=small'},
          {'size': ThumbnailSize.medium, 'expected': ''},
          {'size': ThumbnailSize.large, 'expected': '&size=large'},
        ];

        for (final testCase in testCases) {
          final size = testCase['size'] as ThumbnailSize;
          final expectedSuffix = testCase['expected'] as String;
          final url = ThumbnailApiService.getThumbnailUrl(
            'test-id',
            timeSeconds: 1,
            size: size,
          );
          expect(
            url,
            equals(
              'https://api.openvine.co/thumbnail/test-id?t=1.0$expectedSuffix',
            ),
          );
        }
      });
    });

    group('ThumbnailSize enum', () {
      test('has correct values', () {
        expect(ThumbnailSize.small.name, equals('small'));
        expect(ThumbnailSize.medium.name, equals('medium'));
        expect(ThumbnailSize.large.name, equals('large'));
      });

      test('has all expected values', () {
        const values = ThumbnailSize.values;
        expect(values.length, equals(3));
        expect(values, contains(ThumbnailSize.small));
        expect(values, contains(ThumbnailSize.medium));
        expect(values, contains(ThumbnailSize.large));
      });
    });

    group('ThumbnailApiException', () {
      test('creates exception with message only', () {
        const exception = ThumbnailApiException('Test error');
        expect(exception.message, equals('Test error'));
        expect(exception.statusCode, isNull);
        expect(
          exception.toString(),
          equals('ThumbnailApiException: Test error'),
        );
      });

      test('creates exception with message and status code', () {
        const exception = ThumbnailApiException('Test error', 404);
        expect(exception.message, equals('Test error'));
        expect(exception.statusCode, equals(404));
        expect(
          exception.toString(),
          equals('ThumbnailApiException: Test error (HTTP 404)'),
        );
      });

      test('handles various status codes', () {
        final testCases = [
          {
            'code': 400,
            'expected': 'ThumbnailApiException: Bad request (HTTP 400)',
          },
          {
            'code': 500,
            'expected': 'ThumbnailApiException: Server error (HTTP 500)',
          },
          {
            'code': 404,
            'expected': 'ThumbnailApiException: Not found (HTTP 404)',
          },
        ];

        for (final testCase in testCases) {
          final code = testCase['code'] as int;
          final expected = testCase['expected'] as String;
          final exception = ThumbnailApiException(
            code == 400
                ? 'Bad request'
                : code == 500
                ? 'Server error'
                : 'Not found',
            code,
          );
          expect(exception.toString(), equals(expected));
        }
      });
    });

    group('Parameter validation', () {
      test('handles empty video ID gracefully', () {
        final url = ThumbnailApiService.getThumbnailUrl('');
        expect(url, equals('https://api.openvine.co/thumbnail/?t=2.5'));
      });

      test('handles very long video ID', () {
        final longId = 'a' * 100;
        final url = ThumbnailApiService.getThumbnailUrl(longId);
        expect(url, startsWith('https://api.openvine.co/thumbnail/'));
        expect(url, contains(longId));
      });

      test('handles negative time (should still work)', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-id',
          timeSeconds: -1,
        );
        expect(url, equals('https://api.openvine.co/thumbnail/test-id?t=-1.0'));
      });

      test('handles very large time values', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-id',
          timeSeconds: 99999.99,
        );
        expect(
          url,
          equals('https://api.openvine.co/thumbnail/test-id?t=99999.99'),
        );
      });
    });

    group('Base URL consistency', () {
      test('all URLs use the same base URL', () {
        final urls = [
          ThumbnailApiService.getThumbnailUrl('test1'),
          ThumbnailApiService.getThumbnailUrl(
            'test2',
            size: ThumbnailSize.large,
          ),
          ThumbnailApiService.getThumbnailUrl('test3', timeSeconds: 10),
        ];

        for (final url in urls) {
          expect(url, startsWith('https://api.openvine.co/thumbnail/'));
        }
      });

      test('URLs are properly formatted', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-video-id',
          timeSeconds: 5.5,
          size: ThumbnailSize.large,
        );

        // Should have proper format: base/id?t=time&size=size
        expect(
          url,
          matches(
            r'^https://api\.openvine\.co/thumbnail/[\w\-]+\?t=\d+(\.\d+)?(&size=\w+)?$',
          ),
        );
      });
    });

    group('Edge cases', () {
      test('handles video ID with URL-unsafe characters', () {
        final url = ThumbnailApiService.getThumbnailUrl('test@video#id!');
        expect(url, contains('test@video#id!'));
        // Note: URL encoding should be handled by the HTTP library when making requests
      });

      test('handles extreme decimal precision', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-id',
          timeSeconds: 1.23456789,
        );
        expect(url, contains('t=1.23456789'));
      });

      test('handles very small time values', () {
        final url = ThumbnailApiService.getThumbnailUrl(
          'test-id',
          timeSeconds: 0.001,
        );
        expect(url, contains('t=0.001'));
      });
    });

    group('Size parameter combinations', () {
      test(
        'medium size with different times does not include size parameter',
        () {
          final times = [0.0, 1.5, 5.0, 10.0];

          for (final time in times) {
            final url = ThumbnailApiService.getThumbnailUrl(
              'test-id',
              timeSeconds: time,
              size: ThumbnailSize.medium,
            );
            expect(url, isNot(contains('size=')));
            expect(url, contains('t=$time'));
          }
        },
      );

      test('non-medium sizes always include size parameter', () {
        final sizes = [ThumbnailSize.small, ThumbnailSize.large];

        for (final size in sizes) {
          final url = ThumbnailApiService.getThumbnailUrl(
            'test-id',
            size: size,
          );
          expect(url, contains('size=${size.name}'));
        }
      });
    });
  });
}
