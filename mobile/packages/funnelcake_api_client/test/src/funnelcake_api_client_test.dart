// ABOUTME: Tests for FunnelcakeApiClient HTTP client.
// ABOUTME: Tests API calls, error handling, and edge cases.

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  group('FunnelcakeApiClient', () {
    late MockHttpClient mockHttpClient;
    late FunnelcakeApiClient client;

    const testBaseUrl = 'https://api.example.com';
    const testPubkey =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    setUp(() {
      mockHttpClient = MockHttpClient();
      client = FunnelcakeApiClient(
        baseUrl: testBaseUrl,
        httpClient: mockHttpClient,
      );
    });

    tearDown(() {
      client.dispose();
    });

    group('constructor', () {
      test('can be instantiated with required parameters', () {
        final apiClient = FunnelcakeApiClient(baseUrl: testBaseUrl);
        expect(apiClient, isNotNull);
        apiClient.dispose();
      });

      test('removes trailing slash from baseUrl', () {
        final apiClient = FunnelcakeApiClient(
          baseUrl: '$testBaseUrl/',
          httpClient: mockHttpClient,
        );
        expect(apiClient.baseUrl, equals(testBaseUrl));
        apiClient.dispose();
      });

      test('preserves baseUrl without trailing slash', () {
        expect(client.baseUrl, equals(testBaseUrl));
      });
    });

    group('isAvailable', () {
      test('returns true when baseUrl is configured', () {
        expect(client.isAvailable, isTrue);
      });

      test('returns false when baseUrl is empty', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );
        expect(emptyClient.isAvailable, isFalse);
        emptyClient.dispose();
      });
    });

    group('getTrendingVideos', () {
      const validResponseBody =
          '''
[
  {
    "id": "abc123def456",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "trending-1",
    "title": "Trending Video",
    "content": "A trending video",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 500,
    "comments": 50,
    "reposts": 25,
    "engagement_score": 575,
    "trending_score": 9.5
  }
]
''';

      test('returns videos on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final videos = await client.getTrendingVideos();

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('abc123def456'));
        expect(videos.first.title, equals('Trending Video'));
        expect(videos.first.reactions, equals(500));
      });

      test('constructs correct URL with sort=trending', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getTrendingVideos();

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos'));
        expect(uri.queryParameters['sort'], equals('trending'));
        expect(uri.queryParameters['limit'], equals('50'));
        expect(uri.queryParameters['nsfw'], equals('show'));
        expect(
          uri.queryParameters['moderation_profile'],
          equals(FunnelcakeApiClient.defaultModerationProfile),
        );
      });

      test('includes before parameter when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getTrendingVideos(before: 1700000000);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['before'], equals('1700000000'));
      });

      test('constructs correct URL with custom limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getTrendingVideos(limit: 25);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['limit'], equals('25'));
      });

      test('filters out videos with empty id', () async {
        const responseWithEmptyId =
            '''
[
  {
    "id": "",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test",
    "title": "Invalid",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmptyId, 200));

        final videos = await client.getTrendingVideos();

        expect(videos, isEmpty);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          emptyClient.getTrendingVideos,
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getTrendingVideos(),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getTrendingVideos(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getTrendingVideos(),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch trending videos'),
            ),
          ),
        );
      });
    });

    group('getRecentVideos', () {
      const validResponseBody =
          '''
[
  {
    "id": "recent123",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "recent-1",
    "title": "Recent Video",
    "content": "A recent video",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 10,
    "comments": 2,
    "reposts": 1,
    "engagement_score": 13
  }
]
''';

      test('returns videos on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final videos = await client.getRecentVideos();

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('recent123'));
        expect(videos.first.title, equals('Recent Video'));
      });

      test('constructs New-feed URL with sort=published', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getRecentVideos();

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos'));
        expect(uri.queryParameters['sort'], equals('published'));
        expect(uri.queryParameters['limit'], equals('50'));
        expect(uri.queryParameters['nsfw'], equals('show'));
        expect(
          uri.queryParameters['moderation_profile'],
          equals(FunnelcakeApiClient.defaultModerationProfile),
        );
      });

      test('includes before parameter when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getRecentVideos(before: 1700000000);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['before'], equals('1700000000'));
      });

      test('constructs correct URL with custom limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getRecentVideos(limit: 10);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['limit'], equals('10'));
      });

      test('filters out videos with empty videoUrl', () async {
        const responseWithEmptyUrl =
            '''
[
  {
    "id": "abc123",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test",
    "title": "Invalid",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmptyUrl, 200));

        final videos = await client.getRecentVideos();

        expect(videos, isEmpty);
      });

      // Callers page this feed by comparing the row count against the limit
      // they asked for. Dropping the malformed row without reporting it made
      // a full server page look like the end of the feed.
      test(
        'reports the server row count alongside the filtered videos',
        () async {
          const responseWithOneBadRow =
              '''
[
  {
    "id": "good123",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "good",
    "title": "Valid",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/good.mp4",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  },
  {
    "id": "bad456",
    "pubkey": "$testPubkey",
    "created_at": 1699999999,
    "kind": 34236,
    "d_tag": "bad",
    "title": "Invalid",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  }
]
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(responseWithOneBadRow, 200));

          final page = await client.getRecentVideosPage(limit: 2);

          expect(page.videos, hasLength(1));
          expect(page.serverItemCount, equals(2));
        },
      );

      test('leaves hasMore null for the bare-list response shape', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final page = await client.getRecentVideosPage();

        expect(page.hasMore, isNull);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          emptyClient.getRecentVideos,
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getRecentVideos(),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getRecentVideos(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getRecentVideos(),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch recent videos'),
            ),
          ),
        );
      });
    });

    group('getLeaderboardVideos', () {
      const responseBody =
          '''
{
  "period": "week",
  "entries": [
    {
      "id": "abc123",
      "pubkey": "$testPubkey",
      "kind": 34236,
      "d_tag": "leader-1",
      "title": "Top of the Week",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/video.mp4",
      "author_name": "Alice",
      "author_avatar": "https://example.com/alice.jpg",
      "views": 50000,
      "unique_viewers": 25000,
      "loops": 37500
    }
  ]
}
''';

      test('returns parsed videos from the entries field', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final videos = await client.getLeaderboardVideos(
          period: LeaderboardPeriod.week,
        );

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('abc123'));
        expect(videos.first.title, equals('Top of the Week'));
        expect(videos.first.views, equals(50000));
        expect(videos.first.loops, equals(37500));
      });

      test(
        'constructs URL /api/leaderboard/videos?period=week&limit=50',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response('{"period":"week","entries":[]}', 200),
          );

          await client.getLeaderboardVideos(period: LeaderboardPeriod.week);

          final captured = verify(
            () => mockHttpClient.get(
              captureAny(),
              headers: any(named: 'headers'),
            ),
          ).captured;
          final uri = captured.first as Uri;
          expect(uri.path, equals('/api/leaderboard/videos'));
          expect(uri.queryParameters['period'], equals('week'));
          expect(uri.queryParameters['limit'], equals('50'));
          expect(uri.queryParameters.containsKey('offset'), isFalse);
        },
      );

      test('passes period=alltime when period is alltime', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"period":"alltime","entries":[]}', 200),
        );

        await client.getLeaderboardVideos(period: LeaderboardPeriod.alltime);

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.first
                as Uri;
        expect(uri.queryParameters['period'], equals('alltime'));
      });

      test('passes day (not today) on the wire', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"period":"day","entries":[]}', 200),
        );

        await client.getLeaderboardVideos(period: LeaderboardPeriod.day);

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.first
                as Uri;
        expect(uri.queryParameters['period'], equals('day'));
      });

      test('includes offset when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"period":"week","entries":[]}', 200),
        );

        await client.getLeaderboardVideos(
          period: LeaderboardPeriod.week,
          limit: 25,
          offset: 50,
        );

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.first
                as Uri;
        expect(uri.queryParameters['limit'], equals('25'));
        expect(uri.queryParameters['offset'], equals('50'));
      });

      test('filters out entries with empty id or video_url', () async {
        const bodyWithJunk =
            '''
{
  "period": "week",
  "entries": [
    {"id": "", "pubkey": "$testPubkey", "kind": 34236, "title": "no id",
     "thumbnail": "x", "video_url": "https://x", "d_tag": "x"},
    {"id": "no-url", "pubkey": "$testPubkey", "kind": 34236,
     "title": "empty url",
     "thumbnail": "x", "video_url": "", "d_tag": "x"},
    {"id": "good", "pubkey": "$testPubkey", "kind": 34236, "title": "valid",
     "thumbnail": "x", "video_url": "https://x", "d_tag": "x"}
  ]
}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(bodyWithJunk, 200));

        final videos = await client.getLeaderboardVideos(
          period: LeaderboardPeriod.week,
        );

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('good'));
      });

      test('returns empty list when entries field is missing', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('{"period":"week"}', 200));

        final videos = await client.getLeaderboardVideos(
          period: LeaderboardPeriod.week,
        );

        expect(videos, isEmpty);
      });

      test(
        'returns empty list when response body is not a JSON object',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[]', 200));

          final videos = await client.getLeaderboardVideos(
            period: LeaderboardPeriod.week,
          );

          expect(videos, isEmpty);
        },
      );

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () =>
              emptyClient.getLeaderboardVideos(period: LeaderboardPeriod.week),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on non-200 status', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('boom', 502));

        expect(
          () => client.getLeaderboardVideos(period: LeaderboardPeriod.week),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(502),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on TimeoutException', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('slow'));

        expect(
          () => client.getLeaderboardVideos(period: LeaderboardPeriod.week),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getHomeFeed', () {
      const validFeedResponse =
          '''
{
  "videos": [
    {
      "id": "feed123",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "feed-1",
      "title": "Feed Video",
      "content": "A feed video",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/video.mp4",
      "reactions": 42,
      "comments": 5,
      "reposts": 3,
      "engagement_score": 50
    }
  ],
  "next_cursor": "1699999000",
  "has_more": true
}
''';

      test('returns feed response on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validFeedResponse, 200));

        final result = await client.getHomeFeed(pubkey: testPubkey);

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('feed123'));
        expect(result.nextCursor, equals(1699999000));
        expect(result.hasMore, isTrue);
      });

      test('constructs correct URL with default params', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"videos": [], "has_more": false}', 200),
        );

        await client.getHomeFeed(pubkey: testPubkey);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/feed'));
        expect(uri.queryParameters['limit'], equals('50'));
        expect(uri.queryParameters['sort'], equals('recent'));
        expect(uri.queryParameters.containsKey('nsfw'), isFalse);
        expect(uri.queryParameters.containsKey('moderation_profile'), isFalse);
        expect(uri.queryParameters.containsKey('content_safety'), isFalse);
        expect(uri.queryParameters.containsKey('exclude_label'), isFalse);
        expect(uri.queryParameters.containsKey('before'), isFalse);
      });

      test('includes before and sort params when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"videos": [], "has_more": false}', 200),
        );

        await client.getHomeFeed(
          pubkey: testPubkey,
          sort: 'trending',
          before: 1700000000,
        );

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['sort'], equals('trending'));
        expect(uri.queryParameters['before'], equals('1700000000'));
      });

      test('parses next_cursor as string', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            '{"videos": [], "next_cursor": "1699999000", "has_more": true}',
            200,
          ),
        );

        final result = await client.getHomeFeed(pubkey: testPubkey);

        expect(result.nextCursor, equals(1699999000));
        expect(result.hasMore, isTrue);
      });

      test('parses next_cursor as int', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            '{"videos": [], "next_cursor": 1699999000, "has_more": true}',
            200,
          ),
        );

        final result = await client.getHomeFeed(pubkey: testPubkey);

        expect(result.nextCursor, equals(1699999000));
      });

      test('handles null next_cursor', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"videos": [], "has_more": false}', 200),
        );

        final result = await client.getHomeFeed(pubkey: testPubkey);

        expect(result.nextCursor, isNull);
        expect(result.hasMore, isFalse);
      });

      test('filters out videos with empty id or videoUrl', () async {
        const responseWithInvalid =
            '''
{
  "videos": [
    {
      "id": "",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "test",
      "title": "Invalid",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/video.mp4",
      "reactions": 0,
      "comments": 0,
      "reposts": 0,
      "engagement_score": 0
    }
  ],
  "has_more": false
}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithInvalid, 200));

        final result = await client.getHomeFeed(pubkey: testPubkey);

        expect(result.videos, isEmpty);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getHomeFeed(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getHomeFeed(pubkey: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeNotFoundException on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        expect(
          () => client.getHomeFeed(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotFoundException>()),
        );
      });

      test(
        'throws FunnelcakeApiException on other error status codes',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response('Internal Server Error', 500),
          );

          expect(
            () => client.getHomeFeed(pubkey: testPubkey),
            throwsA(
              isA<FunnelcakeApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                equals(500),
              ),
            ),
          );
        },
      );

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getHomeFeed(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getHomeFeed(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch home feed'),
            ),
          ),
        );
      });

      // Envelope shape tolerance (divine-funnelcake#238 / issue #3521)
      test('returns feed from legacy {videos} shape', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validFeedResponse, 200));

        final result = await client.getHomeFeed(pubkey: testPubkey);
        expect(result.videos, hasLength(1));
        expect(result.hasMore, isTrue);
        expect(result.nextCursor, equals(1699999000));
      });

      test('returns feed from {data, pagination} envelope shape', () async {
        const envelope =
            '''
{
  "data": [
    {
      "id": "feed-env-1",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "env-feed",
      "title": "Envelope Feed Video",
      "content": "",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/feed.mp4",
      "reactions": 5,
      "comments": 1,
      "reposts": 0,
      "engagement_score": 6
    }
  ],
  "pagination": {"has_more": true, "next_cursor": "1699998000"}
}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(envelope, 200));

        final result = await client.getHomeFeed(pubkey: testPubkey);
        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('feed-env-1'));
        expect(result.hasMore, isTrue);
        expect(result.nextCursor, equals(1699998000));
      });
    });

    group('getVideosByAuthor', () {
      const validResponseBody =
          '''
[
  {
    "id": "abc123def456",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test-video-1",
    "title": "Test Video",
    "content": "A test video description",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 100,
    "comments": 10,
    "reposts": 5,
    "engagement_score": 115
  }
]
''';

      test('parses v2 envelope pagination metadata', () async {
        const envelope =
            '''
{
  "data": [
    {
      "id": "abc123def456",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "test-video-1",
      "title": "Test Video",
      "content": "A test video description",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/video.mp4",
      "reactions": 100,
      "comments": 10,
      "reposts": 5,
      "engagement_score": 115
    }
  ],
  "pagination": {"has_more": true, "next_offset": 50}
}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(envelope, 200));

        final result = await client.getVideosByAuthor(pubkey: testPubkey);

        expect(result.videos, hasLength(1));
        expect(result.nextOffset, 50);
        expect(result.hasMore, isTrue);
      });

      test(
        'returns null pagination metadata for legacy array responses',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(validResponseBody, 200));

          final result = await client.getVideosByAuthor(pubkey: testPubkey);

          expect(result.nextOffset, isNull);
          expect(result.hasMore, isNull);
        },
      );

      test('returns videos on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            validResponseBody,
            200,
            headers: {'x-total-count': '42'},
          ),
        );

        final result = await client.getVideosByAuthor(pubkey: testPubkey);

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('abc123def456'));
        expect(result.videos.first.pubkey, equals(testPubkey));
        expect(result.videos.first.title, equals('Test Video'));
        expect(result.videos.first.reactions, equals(100));
        expect(result.totalCount, equals(42));
      });

      test(
        'getWatchingVideosPage parses v2 envelope pagination metadata',
        () async {
          const envelope =
              '''
{
  "data": [
    {
      "id": "watching-env-1",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "watching-env-1",
      "title": "Watching Video",
      "content": "",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/video.mp4",
      "reactions": 5,
      "comments": 1,
      "reposts": 0,
      "engagement_score": 6
    }
  ],
  "pagination": {"has_more": true, "next_cursor": "1699998000"}
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(envelope, 200));

          final result = await client.getWatchingVideosPage();

          expect(result.videos, hasLength(1));
          expect(result.videos.first.id, 'watching-env-1');
          expect(result.nextCursor, 1699998000);
          expect(result.hasMore, isTrue);
        },
      );

      test(
        'parses total_loops and total_views from author videos response',
        () async {
          const responseWithLoopMetrics =
              '''
[
  {
    "id": "abc123def456",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test-video-1",
    "title": "Test Video",
    "content": "A test video description",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "total_loops": 42.0,
    "total_views": 100.0,
    "reactions": 100,
    "comments": 10,
    "reposts": 5,
    "engagement_score": 115
  }
]
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response(
              responseWithLoopMetrics,
              200,
              headers: {'x-total-count': '42'},
            ),
          );

          final result = await client.getVideosByAuthor(pubkey: testPubkey);
          final video = result.videos.single.toVideoEvent();

          expect(video.originalLoops, equals(42));
          expect(video.rawTags['views'], equals('100'));
          expect(video.totalLoops, equals(142));
        },
      );

      test('constructs correct URL with default limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByAuthor(pubkey: testPubkey);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/videos'));
        expect(uri.queryParameters['limit'], equals('50'));
        expect(uri.queryParameters['nsfw'], equals('show'));
        expect(
          uri.queryParameters['moderation_profile'],
          equals(FunnelcakeApiClient.defaultModerationProfile),
        );
      });

      test('constructs correct URL with custom limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByAuthor(pubkey: testPubkey, limit: 100);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['limit'], equals('100'));
      });

      test('includes offset parameter when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByAuthor(pubkey: testPubkey, offset: 50);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['offset'], equals('50'));
      });

      test('sends correct headers', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByAuthor(pubkey: testPubkey);

        final captured = verify(
          () => mockHttpClient.get(
            any(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;
        final headers = captured.whereType<Map<String, String>>().first;
        expect(headers['Accept'], 'application/json');
        expect(
          headers['User-Agent'],
          matches(RegExp(r'^Divine-Mobile/\S+ \(\w[\w.]*\)$')),
        );
        expect(headers['User-Agent'], isNot('OpenVine-Mobile/1.0'));
        expect(
          headers['X-Divine-Platform'],
          matches(RegExp(r'^[a-z][a-z0-9_]*$')),
        );
      });

      test(
        'wires the appVersion constructor parameter into the header',
        () async {
          final versionedClient = FunnelcakeApiClient(
            baseUrl: 'https://api.divine.video',
            httpClient: mockHttpClient,
            appVersion: '1.0.20',
          );
          addTearDown(versionedClient.dispose);

          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[]', 200));

          await versionedClient.getVideosByAuthor(pubkey: testPubkey);

          final captured = verify(
            () => mockHttpClient.get(
              any(),
              headers: captureAny(named: 'headers'),
            ),
          ).captured;
          final headers = captured.whereType<Map<String, String>>().last;
          expect(
            headers['User-Agent'],
            matches(RegExp(r'^Divine-Mobile/1\.0\.20 \(\w[\w.]*\)$')),
          );
        },
      );

      test('filters out videos with empty id', () async {
        const responseWithEmptyId =
            '''
[
  {
    "id": "",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test",
    "title": "Invalid Video",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmptyId, 200));

        final result = await client.getVideosByAuthor(pubkey: testPubkey);

        expect(result.videos, isEmpty);
      });

      test('filters out videos with empty videoUrl', () async {
        const responseWithEmptyUrl =
            '''
[
  {
    "id": "abc123",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test",
    "title": "Invalid Video",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmptyUrl, 200));

        final result = await client.getVideosByAuthor(pubkey: testPubkey);

        expect(result.videos, isEmpty);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getVideosByAuthor(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getVideosByAuthor(pubkey: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeNotFoundException on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        expect(
          () => client.getVideosByAuthor(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotFoundException>()),
        );
      });

      test(
        'throws FunnelcakeApiException on other error status codes',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response('Internal Server Error', 500),
          );

          expect(
            () => client.getVideosByAuthor(pubkey: testPubkey),
            throwsA(
              isA<FunnelcakeApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                equals(500),
              ),
            ),
          );
        },
      );

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getVideosByAuthor(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getVideosByAuthor(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch author videos'),
            ),
          ),
        );
      });
    });

    group('searchProfiles', () {
      const validProfileResponse =
          '''
[
  {
    "pubkey": "$testPubkey",
    "name": "testuser",
    "display_name": "Test User",
    "about": "A test profile",
    "picture": "https://example.com/avatar.jpg",
    "nip05": "testuser@example.com",
    "created_at": 1700000000,
    "event_id": "event123"
  }
]
''';

      test('returns profiles on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validProfileResponse, 200));

        final profiles = await client.searchProfiles(query: 'test');

        expect(profiles, hasLength(1));
        expect(profiles.first.pubkey, equals(testPubkey));
        expect(profiles.first.name, equals('testuser'));
        expect(profiles.first.displayName, equals('Test User'));
        expect(profiles.first.nip05, equals('testuser@example.com'));
      });

      test('constructs correct URL with default limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchProfiles(query: 'test');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/search/profiles'));
        expect(uri.queryParameters['q'], equals('test'));
        expect(uri.queryParameters['limit'], equals('50'));
        expect(uri.queryParameters.containsKey('offset'), isFalse);
      });

      test('constructs correct URL with custom limit and offset', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchProfiles(query: 'test', limit: 25, offset: 10);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['limit'], equals('25'));
        expect(uri.queryParameters['offset'], equals('10'));
      });

      test('trims whitespace from query', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchProfiles(query: '  test  ');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['q'], equals('test'));
      });

      test('filters out profiles with empty pubkey', () async {
        const responseWithEmptyPubkey = '''
[
  {
    "pubkey": "",
    "name": "invalid",
    "display_name": "Invalid User"
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmptyPubkey, 200));

        final profiles = await client.searchProfiles(query: 'test');

        expect(profiles, isEmpty);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.searchProfiles(query: 'test'),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when query is empty', () {
        expect(
          () => client.searchProfiles(query: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Search query cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeException when query is only whitespace', () {
        expect(
          () => client.searchProfiles(query: '   '),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Search query cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.searchProfiles(query: 'test'),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.searchProfiles(query: 'test'),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.searchProfiles(query: 'test'),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to search profiles'),
            ),
          ),
        );
      });

      test('includes sort_by query param when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchProfiles(query: 'test', sortBy: 'followers');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['sort_by'], equals('followers'));
      });

      test('includes has_videos query param when true', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchProfiles(query: 'test', hasVideos: true);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['has_videos'], equals('true'));
      });

      test('omits has_videos when false (default)', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchProfiles(query: 'test');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters.containsKey('has_videos'), isFalse);
      });

      test('omits sort_by when not provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchProfiles(query: 'test');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters.containsKey('sort_by'), isFalse);
      });

      test('constructs URL with all params', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchProfiles(
          query: 'test',
          limit: 25,
          offset: 50,
          sortBy: 'followers',
          hasVideos: true,
        );

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['q'], equals('test'));
        expect(uri.queryParameters['limit'], equals('25'));
        expect(uri.queryParameters['offset'], equals('50'));
        expect(uri.queryParameters['sort_by'], equals('followers'));
        expect(uri.queryParameters['has_videos'], equals('true'));
      });

      test('handles pubkey as byte array', () async {
        // Funnelcake sometimes returns IDs as ASCII byte arrays
        const byteArrayResponse = '''
[
  {
    "pubkey": [49, 50, 51, 52, 53, 54, 55, 56],
    "name": "testuser"
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(byteArrayResponse, 200));

        final profiles = await client.searchProfiles(query: 'test');

        expect(profiles, hasLength(1));
        expect(profiles.first.pubkey, equals('12345678'));
      });
    });

    group('getCollabVideos', () {
      const collabAuthorPubkey =
          'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
      const validCollabResponse =
          '''
[
  {
    "id": "collab123def456",
    "pubkey": "$collabAuthorPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "collab-video-1",
    "title": "Collab Video",
    "content": "A collab video",
    "tags": [["p", "$testPubkey", "", "Collaborator"]],
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 50,
    "comments": 5,
    "reposts": 2,
    "engagement_score": 57
  }
]
''';

      test(
        'returns confirmed collaborator videos on successful response',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(validCollabResponse, 200));

          final videos = await client.getCollabVideos(pubkey: testPubkey);

          expect(videos, hasLength(1));
          expect(videos.first.id, equals('collab123def456'));
          expect(videos.first.title, equals('Collab Video'));
          expect(videos.first.pubkey, equals(collabAuthorPubkey));
          expect(videos.first.collaboratorPubkeys, equals([testPubkey]));
        },
      );

      test('constructs correct URL with default limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getCollabVideos(pubkey: testPubkey);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/collabs'));
        expect(uri.queryParameters['limit'], equals('50'));
      });

      test('includes before parameter when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getCollabVideos(pubkey: testPubkey, before: 1700000000);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['before'], equals('1700000000'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getCollabVideos(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getCollabVideos(pubkey: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeNotFoundException on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        expect(
          () => client.getCollabVideos(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotFoundException>()),
        );
      });

      test(
        'throws FunnelcakeApiException on other error status codes',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response('Internal Server Error', 500),
          );

          expect(
            () => client.getCollabVideos(pubkey: testPubkey),
            throwsA(
              isA<FunnelcakeApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                equals(500),
              ),
            ),
          );
        },
      );

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getCollabVideos(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('filters out videos with empty id', () async {
        const responseWithEmptyId =
            '''
[
  {
    "id": "",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test",
    "title": "Invalid",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmptyId, 200));

        final videos = await client.getCollabVideos(pubkey: testPubkey);

        expect(videos, isEmpty);
      });
    });

    group('searchHashtags', () {
      const validHashtagResponse = '''
[
  {"hashtag": "bitcoin", "video_count": 156},
  {"hashtag": "nostr", "video_count": 89}
]
''';

      test('returns hashtags on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validHashtagResponse, 200));

        final hashtags = await client.searchHashtags(query: 'bit');

        expect(hashtags, hasLength(2));
        expect(hashtags.first, equals('bitcoin'));
        expect(hashtags.last, equals('nostr'));
      });

      test('parses response using tag field as fallback', () async {
        const tagFieldResponse = '''
[
  {"tag": "bitcoin", "score": 95.2}
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(tagFieldResponse, 200));

        final hashtags = await client.searchHashtags(query: 'bit');

        expect(hashtags, equals(['bitcoin']));
      });

      test('handles plain string response format', () async {
        const stringResponse = '["bitcoin", "nostr"]';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(stringResponse, 200));

        final hashtags = await client.searchHashtags(query: 'bit');

        expect(hashtags, equals(['bitcoin', 'nostr']));
      });

      // A lone surrogate in a chip label throws out of Flutter's paragraph
      // builder, and the plain-string branch bypasses HashtagSearchResult.
      // fromJson, so it needs the same normalization as the mapped one.
      test('normalizes malformed UTF-16 in both response shapes', () async {
        const malformedResponse = r'["bit\ud83dcoin", {"tag": "no\ud83dstr"}]';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(malformedResponse, 200));

        final hashtags = await client.searchHashtags(query: 'bit');

        expect(hashtags, equals(['bit�coin', 'no�str']));
      });

      test('constructs correct URL with query parameter', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchHashtags(query: 'bitcoin');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/hashtags/trending'));
        expect(uri.queryParameters['q'], equals('bitcoin'));
        expect(uri.queryParameters['limit'], equals('20'));
      });

      test('constructs correct URL without query when query is null', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchHashtags();

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters.containsKey('q'), isFalse);
        expect(uri.queryParameters['limit'], equals('20'));
      });

      test(
        'constructs correct URL without query when query is empty',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[]', 200));

          await client.searchHashtags(query: '');

          final captured = verify(
            () => mockHttpClient.get(
              captureAny(),
              headers: any(named: 'headers'),
            ),
          ).captured;

          final uri = captured.first as Uri;
          expect(uri.queryParameters.containsKey('q'), isFalse);
        },
      );

      test('passes query through without normalization', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchHashtags(query: 'Bitcoin');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['q'], equals('Bitcoin'));
      });

      test('constructs correct URL with custom limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchHashtags(query: 'test', limit: 50);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['limit'], equals('50'));
      });

      test('filters out empty hashtag names', () async {
        const responseWithEmpty = '''
[
  {"hashtag": "bitcoin"},
  {"hashtag": ""},
  {"hashtag": "nostr"}
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmpty, 200));

        final hashtags = await client.searchHashtags(query: 'test');

        expect(hashtags, equals(['bitcoin', 'nostr']));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.searchHashtags(query: 'test'),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.searchHashtags(query: 'test'),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.searchHashtags(query: 'test'),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.searchHashtags(query: 'test'),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to search hashtags'),
            ),
          ),
        );
      });

      test('constructs correct URL with offset parameter', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchHashtags(query: 'test', offset: 10);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['offset'], equals('10'));
      });

      test('omits offset from URL when offset is zero', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchHashtags(query: 'test');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters.containsKey('offset'), isFalse);
      });
    });

    group('getVideosByLoops', () {
      const validResponseBody =
          '''
[
  {
    "id": "loops123",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "loops-1",
    "title": "Viral Video",
    "content": "",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 100,
    "comments": 10,
    "reposts": 5,
    "engagement_score": 115
  }
]
''';

      test('returns videos on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final videos = await client.getVideosByLoops();

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('loops123'));
      });

      test('constructs correct URL with sort=loops', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByLoops();

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos'));
        expect(uri.queryParameters['sort'], equals('loops'));
        expect(uri.queryParameters['limit'], equals('50'));
      });

      test('includes before parameter when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByLoops(before: 1700000000);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['before'], equals('1700000000'));
      });

      test('filters out videos with empty id', () async {
        const responseWithEmptyId =
            '''
[{"id": "", "pubkey": "$testPubkey", "created_at": 1700000000,
  "kind": 34236, "d_tag": "t", "title": "X", "thumbnail": "",
  "video_url": "https://example.com/v.mp4",
  "reactions": 0, "comments": 0, "reposts": 0, "engagement_score": 0}]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmptyId, 200));

        final videos = await client.getVideosByLoops();

        expect(videos, isEmpty);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          emptyClient.getVideosByLoops,
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getVideosByLoops(),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getVideosByLoops(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getVideosByLoops(),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch videos by loops'),
            ),
          ),
        );
      });
    });

    group('getVideosByHashtag', () {
      const validResponseBody =
          '''
[
  {
    "id": "hash123",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "hash-1",
    "title": "Hashtag Video",
    "content": "",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 50,
    "comments": 5,
    "reposts": 2,
    "engagement_score": 57
  }
]
''';

      test('returns videos on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final videos = await client.getVideosByHashtag(hashtag: 'flutter');

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('hash123'));
      });

      test('constructs correct URL with tag and sort=trending', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByHashtag(hashtag: 'Flutter');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos'));
        expect(uri.queryParameters['tag'], equals('flutter'));
        expect(uri.queryParameters['sort'], equals('trending'));
      });

      test('strips # prefix from hashtag', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByHashtag(hashtag: '#bitcoin');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['tag'], equals('bitcoin'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getVideosByHashtag(hashtag: 'test'),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when hashtag is empty', () {
        expect(
          () => client.getVideosByHashtag(hashtag: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Hashtag cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeException when hashtag is just #', () {
        expect(
          () => client.getVideosByHashtag(hashtag: '#'),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Hashtag cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getVideosByHashtag(hashtag: 'test'),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getVideosByHashtag(hashtag: 'test'),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getVideosByHashtag(hashtag: 'test'),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch videos by hashtag'),
            ),
          ),
        );
      });
    });

    group('getClassicVideosByHashtag', () {
      test('constructs URL with sort=loops', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getClassicVideosByHashtag(hashtag: 'comedy');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['tag'], equals('comedy'));
        expect(uri.queryParameters['sort'], equals('loops'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getClassicVideosByHashtag(hashtag: 'test'),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when hashtag is empty', () {
        expect(
          () => client.getClassicVideosByHashtag(hashtag: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Hashtag cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getClassicVideosByHashtag(hashtag: 'test'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getClassicVideosByHashtag(hashtag: 'test'),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('searchVideos', () {
      const validResponseBody =
          '''
{
  "data": [
    {
      "id": "search123",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "search-1",
      "title": "Search Result",
      "content": "",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/video.mp4",
      "reactions": 10,
      "comments": 1,
      "reposts": 0,
      "engagement_score": 11
    }
  ],
  "pagination": {
    "next_cursor": "o:1",
    "has_more": true
  }
}
''';

      test('returns videos on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final result = await client.searchVideos(query: 'flutter');

        expect(result, isA<VideoSearchResponse>());
        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('search123'));
        expect(result.hasMore, isTrue);
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchVideos(query: 'dart');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/v2/search'));
        expect(uri.queryParameters['q'], equals('dart'));
        expect(uri.queryParameters['limit'], equals('50'));
        expect(uri.queryParameters['sort'], equals('trending'));
        expect(uri.queryParameters['type'], equals('video'));
      });

      test('includes custom sort query parameter', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchVideos(query: 'dart', sort: 'recent');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['sort'], equals('recent'));
        expect(uri.queryParameters['type'], equals('video'));
      });

      test('uses v2 cursor pagination for offsets', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchVideos(query: 'dart', offset: 50);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['cursor'], equals('o:50'));
        expect(uri.queryParameters.containsKey('offset'), isFalse);
      });

      test('trims whitespace from query', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.searchVideos(query: '  flutter  ');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['q'], equals('flutter'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.searchVideos(query: 'test'),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when query is empty', () {
        expect(
          () => client.searchVideos(query: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Search query cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeException when query is only whitespace', () {
        expect(
          () => client.searchVideos(query: '   '),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Search query cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.searchVideos(query: 'test'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.searchVideos(query: 'test'),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.searchVideos(query: 'test'),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to search videos'),
            ),
          ),
        );
      });

      test(
        'includes cursor query parameter when offset is greater than 0',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[]', 200));

          await client.searchVideos(query: 'flutter', offset: 20);

          final captured = verify(
            () => mockHttpClient.get(
              captureAny(),
              headers: any(named: 'headers'),
            ),
          ).captured;

          final uri = captured.first as Uri;
          expect(uri.queryParameters['cursor'], equals('o:20'));
          expect(uri.queryParameters.containsKey('offset'), isFalse);
        },
      );

      test('parses X-Total-Count header into totalCount', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            validResponseBody,
            200,
            headers: {'x-total-count': '42'},
          ),
        );

        final result = await client.searchVideos(query: 'flutter');

        expect(result.totalCount, equals(42));
        expect(result.videos, hasLength(1));
      });

      test(
        'defaults totalCount to videos length when header is missing',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(validResponseBody, 200));

          final result = await client.searchVideos(query: 'flutter');

          expect(result.totalCount, equals(result.videos.length));
        },
      );
    });

    group('getV2PopularVideos', () {
      test(
        'classic mode requests monthly popular imported Vine videos',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[]', 200));

          await client.getV2PopularVideos(
            variant: PopularVideosVariant.classic,
          );

          final uri =
              verify(
                    () => mockHttpClient.get(
                      captureAny(),
                      headers: any(named: 'headers'),
                    ),
                  ).captured.single
                  as Uri;
          expect(uri.path, equals('/api/v2/videos'));
          expect(uri.queryParameters['sort'], equals('popular'));
          expect(uri.queryParameters['period'], equals('month'));
          expect(uri.queryParameters['platform'], equals('vine'));
          expect(uri.queryParameters.containsKey('exclude_platform'), isFalse);
        },
      );

      test('native mode requests now-popular non-Vine videos', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getV2PopularVideos(variant: PopularVideosVariant.native);

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.path, equals('/api/v2/videos'));
        expect(uri.queryParameters['sort'], equals('popular'));
        expect(uri.queryParameters['period'], equals('now'));
        expect(uri.queryParameters['exclude_platform'], equals('vine'));
        expect(uri.queryParameters.containsKey('platform'), isFalse);
      });

      test(
        'page mode sends opaque cursor and returns pagination metadata',
        () async {
          const envelope =
              '''
{
  "data": [
    {
      "id": "abc123def456",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "test-video-1",
      "title": "Test Video",
      "content": "A test video description",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/video.mp4",
      "reactions": 100,
      "comments": 10,
      "reposts": 5,
      "engagement_score": 115
    }
  ],
  "pagination": {"has_more": true, "next_cursor": "o:4"}
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(envelope, 200));

          final result = await client.getV2PopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 2,
            cursor: 'o:2',
          );

          expect(result.videos, hasLength(1));
          expect(result.nextCursor, equals('o:4'));
          expect(result.hasMore, isTrue);

          final uri =
              verify(
                    () => mockHttpClient.get(
                      captureAny(),
                      headers: any(named: 'headers'),
                    ),
                  ).captured.single
                  as Uri;
          expect(uri.path, equals('/api/v2/videos'));
          expect(uri.queryParameters['cursor'], equals('o:2'));
          expect(uri.queryParameters.containsKey('before'), isFalse);
        },
      );

      test('sends viewer language and country hints', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getV2PopularVideosPage(
          variant: PopularVideosVariant.native,
          preferredLanguages: const ['pt', 'en'],
          viewerCountry: 'BR',
        );

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.queryParameters['preferred_languages'], equals('pt,en'));
        expect(uri.queryParameters['viewer_country'], equals('BR'));
      });
    });

    group('getClassicVines', () {
      const validResponseBody =
          '''
[
  {
    "id": "vine123",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "vine-1",
    "title": "Classic Vine",
    "content": "",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 1000,
    "comments": 100,
    "reposts": 50,
    "engagement_score": 1150
  }
]
''';

      test('returns videos on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final videos = await client.getClassicVines();

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('vine123'));
      });

      test('constructs correct URL with defaults', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getClassicVines();

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos'));
        expect(uri.queryParameters['classic'], equals('true'));
        expect(uri.queryParameters['platform'], equals('vine'));
        expect(uri.queryParameters['sort'], equals('loops'));
      });

      test('includes offset when sort is not recent and offset > 0', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getClassicVines(offset: 50);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['offset'], equals('50'));
      });

      test(
        'includes before when sort is recent and before is provided',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[]', 200));

          await client.getClassicVines(sort: 'recent', before: 1700000000);

          final captured = verify(
            () => mockHttpClient.get(
              captureAny(),
              headers: any(named: 'headers'),
            ),
          ).captured;

          final uri = captured.first as Uri;
          expect(uri.queryParameters['before'], equals('1700000000'));
          expect(uri.queryParameters.containsKey('offset'), isFalse);
        },
      );

      test('handles wrapped object response format', () async {
        const wrappedResponse =
            '''
{"videos": [
  {
    "id": "vine456",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "vine-2",
    "title": "Wrapped Vine",
    "content": "",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 50,
    "comments": 5,
    "reposts": 2,
    "engagement_score": 57
  }
]}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(wrappedResponse, 200));

        final videos = await client.getClassicVines();

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('vine456'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          emptyClient.getClassicVines,
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getClassicVines(),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getClassicVines(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('fetchTrendingHashtags', () {
      const validResponseBody = '''
[
  {"hashtag": "bitcoin", "video_count": 156, "unique_creators": 42},
  {"hashtag": "nostr", "video_count": 89, "unique_creators": 20}
]
''';

      test('returns hashtags on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final hashtags = await client.fetchTrendingHashtags();

        expect(hashtags, hasLength(2));
        expect(hashtags.first.tag, equals('bitcoin'));
        expect(hashtags.first.videoCount, equals(156));
        expect(hashtags.last.tag, equals('nostr'));
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.fetchTrendingHashtags(limit: 10);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/hashtags'));
        expect(uri.queryParameters['limit'], equals('10'));
      });

      test('filters out hashtags with empty tag', () async {
        const responseWithEmpty = '''
[{"hashtag": "bitcoin", "video_count": 10}, {"hashtag": "", "video_count": 5}]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithEmpty, 200));

        final hashtags = await client.fetchTrendingHashtags();

        expect(hashtags, hasLength(1));
        expect(hashtags.first.tag, equals('bitcoin'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          emptyClient.fetchTrendingHashtags,
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.fetchTrendingHashtags(),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.fetchTrendingHashtags(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.fetchTrendingHashtags(),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch trending hashtags'),
            ),
          ),
        );
      });
    });

    group('getVideoStats', () {
      const testEventId =
          'abcdef1234567890abcdef1234567890'
          'abcdef1234567890abcdef1234567890';

      test('returns video stats on successful response', () async {
        const validResponse =
            '''
{
  "id": "$testEventId",
  "pubkey": "$testPubkey",
  "created_at": 1700000000,
  "kind": 34236,
  "d_tag": "test",
  "title": "Test Video",
  "content": "",
  "thumbnail": "https://example.com/thumb.jpg",
  "video_url": "https://example.com/video.mp4",
  "reactions": 100,
  "comments": 10,
  "reposts": 5,
  "engagement_score": 115
}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final stats = await client.getVideoStats(testEventId);

        expect(stats, isNotNull);
        expect(stats!.id, equals(testEventId));
        expect(stats.reactions, equals(100));
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        await client.getVideoStats(testEventId);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos/$testEventId/stats'));
      });

      test('returns null on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final stats = await client.getVideoStats(testEventId);

        expect(stats, isNull);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getVideoStats(testEventId),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when event ID is empty', () {
        expect(
          () => client.getVideoStats(''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Event ID cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getVideoStats(testEventId),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getVideoStats(testEventId),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getVideoLikers', () {
      const testEventId =
          'abcdef1234567890abcdef1234567890'
          'abcdef1234567890abcdef1234567890';
      const addressableId = '34236:$testPubkey:d-tag';

      const likersResponse = '''
{
  "data": [
    {"pubkey": "liker1", "created_at": 1700000100, "event_id": "reaction1"},
    {"pubkey": "liker2", "created_at": 1700000000, "event_id": "reaction2"}
  ],
  "pagination": {"next_cursor": null, "has_more": false}
}
''';

      test('returns liker pubkeys in server order', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(likersResponse, 200));

        final likers = await client.getVideoLikers(testEventId);

        expect(likers.pubkeys, equals(['liker1', 'liker2']));
        expect(likers.hasMore, isFalse);
      });

      test('constructs correct URL with the server-max limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(likersResponse, 200));

        await client.getVideoLikers(testEventId);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos/$testEventId/likers'));
        expect(
          uri.queryParameters['limit'],
          equals('${FunnelcakeApiClient.maxVideoLikersLimit}'),
        );
        expect(uri.queryParameters.containsKey('a'), isFalse);
      });

      test('sends the addressable coordinate as the a parameter', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(likersResponse, 200));

        await client.getVideoLikers(testEventId, addressableId: addressableId);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['a'], equals(addressableId));
      });

      test('omits the a parameter when the coordinate is blank', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(likersResponse, 200));

        await client.getVideoLikers(testEventId, addressableId: '');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters.containsKey('a'), isFalse);
      });

      test('throws FunnelcakeNotFoundException on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Video not found', 404));

        expect(
          () => client.getVideoLikers(testEventId),
          throwsA(isA<FunnelcakeNotFoundException>()),
        );
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getVideoLikers(testEventId),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when event ID is empty', () {
        expect(
          () => client.getVideoLikers(''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Event ID cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getVideoLikers(testEventId),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getVideoLikers(testEventId),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getVideoViews', () {
      const testEventId =
          'abcdef1234567890abcdef1234567890'
          'abcdef1234567890abcdef1234567890';

      test('returns view count from views key', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('{"views": 1500}', 200));

        final views = await client.getVideoViews(testEventId);

        expect(views, equals(1500));
      });

      test('returns view count from view_count key', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('{"view_count": 2000}', 200));

        final views = await client.getVideoViews(testEventId);

        expect(views, equals(2000));
      });

      test('returns 0 on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final views = await client.getVideoViews(testEventId);

        expect(views, equals(0));
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        await client.getVideoViews(testEventId);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos/$testEventId/views'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getVideoViews(testEventId),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when event ID is empty', () {
        expect(
          () => client.getVideoViews(''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Event ID cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getVideoViews(testEventId),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getVideoViews(testEventId),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getVideoEvent', () {
      const testVideoId =
          'e96357668c72c8923340b0ecf4bfacea505172c4190e9953e603124c67175f3b';
      const testEventId =
          'e46ff7d0d71d6c8114b58728afa43f08d6286fd9a704683af799fd8f855586c2';

      test('returns raw event from wrapped response', () async {
        const validResponse =
            '''
{
  "event": {
    "id": "$testEventId",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "tags": [["d", "$testVideoId"], ["url", "https://example.com/video.mp4"]],
    "content": "",
    "sig": "sig"
  },
  "stats": {
    "reactions": 1
  }
}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final event = await client.getVideoEvent(testVideoId);

        expect(event, isNotNull);
        expect(event!.id, equals(testEventId));
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        await client.getVideoEvent(testVideoId);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/videos/$testVideoId'));
      });

      test('returns null on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final event = await client.getVideoEvent(testVideoId);

        expect(event, isNull);
      });
    });

    group('getVideoComments', () {
      const testVideoId =
          'feedfeedfeedfeedfeedfeedfeedfeed'
          'feedfeedfeedfeedfeedfeedfeedfeed';
      const validResponse =
          '''
{
  "data": [
    {
      "id": "comment1",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 1111,
      "content": "First",
      "sig": "sig1",
      "tags": [["E", "$testVideoId"], ["e", "$testVideoId"]],
      "author_name": "Tester",
      "author_avatar": "https://example.com/avatar.jpg",
      "reply_to_event_id": null,
      "reply_to_pubkey": null
    },
    {
      "id": "comment2",
      "pubkey": "$testPubkey",
      "created_at": 1700000010,
      "kind": 1111,
      "content": "Reply",
      "sig": "sig2",
      "tags": [["E", "$testVideoId"], ["e", "comment1"]],
      "author_name": null,
      "author_avatar": null,
      "reply_to_event_id": "comment1",
      "reply_to_pubkey": "$testPubkey"
    }
  ],
  "pagination": {
    "next_cursor": "o:102",
    "has_more": true
  }
}
''';

      test('returns parsed comments response on success', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final response = await client.getVideoComments(videoId: testVideoId);

        expect(response, isNotNull);
        expect(response!.total, equals(2));
        expect(response.hasMore, isTrue);
        expect(response.hasExactTotal, isFalse);
        expect(response.comments, hasLength(2));
        expect(response.comments.first.id, equals('comment1'));
        expect(response.comments.first.authorName, equals('Tester'));
        expect(
          response.comments.first.authorAvatar,
          equals('https://example.com/avatar.jpg'),
        );
        expect(response.comments.last.replyToEventId, equals('comment1'));
        expect(response.comments.last.replyToPubkey, equals(testPubkey));
      });

      test('constructs correct URL with query parameters', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        await client.getVideoComments(
          videoId: testVideoId,
          sort: 'oldest',
          limit: 50,
          offset: 100,
        );

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/v2/videos/$testVideoId/comments'));
        expect(uri.queryParameters['sort'], equals('oldest'));
        expect(uri.queryParameters['limit'], equals('50'));
        expect(uri.queryParameters['offset'], equals('100'));
      });

      test('includes _cb param when cacheBustToken is set (#5854)', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        await client.getVideoComments(
          videoId: testVideoId,
          cacheBustToken: '1700000000123456',
        );

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.first
                as Uri;
        expect(uri.queryParameters['_cb'], equals('1700000000123456'));
      });

      test('omits _cb param by default so reads stay edge-cacheable', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        await client.getVideoComments(videoId: testVideoId);

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.first
                as Uri;
        expect(uri.queryParameters.containsKey('_cb'), isFalse);
      });

      test('derives pagination lower-bound total from v2 has_more', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final response = await client.getVideoComments(
          videoId: testVideoId,
          limit: 50,
          offset: 100,
        );

        expect(response, isNotNull);
        expect(response!.comments, hasLength(2));
        expect(response.total, equals(102));
        expect(response.hasMore, isTrue);
        expect(response.hasExactTotal, isFalse);
      });

      test('returns null on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final response = await client.getVideoComments(videoId: testVideoId);

        expect(response, isNull);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getVideoComments(videoId: testVideoId),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when video ID is empty', () {
        expect(
          () => client.getVideoComments(videoId: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Video ID cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getVideoComments(videoId: testVideoId),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getVideoComments(videoId: testVideoId),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getUserProfile', () {
      test('returns UserProfileFound on successful response', () async {
        const validResponse = '''
{
  "profile": {
    "name": "testuser",
    "display_name": "Test User",
    "about": "A test profile",
    "picture": "https://example.com/avatar.jpg",
    "nip05": "test@example.com",
    "profile_updated": "2023-11-14T22:13:20Z"
  }
}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final result = await client.getUserProfile(testPubkey);

        expect(result, isA<UserProfileFound>());
        final found = result! as UserProfileFound;
        expect(found.profile.pubkey, equals(testPubkey));
        expect(found.profile.name, equals('testuser'));
        expect(found.profile.displayName, equals('Test User'));
        // The original Nostr Kind 0 timestamp is carried through (#3141).
        expect(
          found.profile.createdAt,
          equals(DateTime.utc(2023, 11, 14, 22, 13, 20)),
        );
      });

      test(
        'includes social, stats, and engagement in UserProfileFound',
        () async {
          const responseWithStats = '''
{
  "profile": {
    "name": "testuser",
    "display_name": "Test User"
  },
  "social": {
    "follower_count": 42,
    "following_count": 10
  },
  "stats": {
    "video_count": 5,
    "reaction_count": 20
  },
  "engagement": {
    "total_reactions": 100,
    "total_loops": 50.5,
    "total_views": 200
  }
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(responseWithStats, 200));

          final result = await client.getUserProfile(testPubkey);

          expect(result, isA<UserProfileFound>());
          final found = result! as UserProfileFound;
          expect(found.profile.name, equals('testuser'));

          // Social
          expect(found.social, isNotNull);
          expect(found.social!.followerCount, equals(42));
          expect(found.social!.followingCount, equals(10));

          // Stats
          expect(found.stats, isNotNull);
          expect(found.stats!.videoCount, equals(5));

          // Engagement
          expect(found.engagement, isNotNull);
          expect(found.engagement!.totalReactions, equals(100));
          expect(found.engagement!.totalLoops, equals(50.5));
        },
      );

      test(
        'returns UserProfileNotPublished when profile is null, includes stats',
        () async {
          const noProfileWithStats = '''
{
  "profile": null,
  "social": {
    "follower_count": 15,
    "following_count": 3
  },
  "stats": {
    "video_count": 8
  },
  "engagement": {
    "total_reactions": 500,
    "total_loops": 120.0,
    "total_views": 300
  }
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(noProfileWithStats, 200));

          final result = await client.getUserProfile(testPubkey);

          expect(result, isA<UserProfileNotPublished>());
          final notPublished = result! as UserProfileNotPublished;
          expect(notPublished.pubkey, equals(testPubkey));

          // Stats should be preserved even for UserProfileNotPublished
          expect(notPublished.social, isNotNull);
          expect(notPublished.social!.followerCount, equals(15));

          expect(notPublished.engagement, isNotNull);
          expect(notPublished.engagement!.totalReactions, equals(500));
          expect(notPublished.engagement!.totalLoops, equals(120.0));
        },
      );

      test(
        'returns UserProfileNotPublished when profile has no name fields',
        () async {
          const noNameResponse = '''
{"profile": {"about": "just about"}}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(noNameResponse, 200));

          final result = await client.getUserProfile(testPubkey);

          expect(result, isA<UserProfileNotPublished>());
          expect(
            (result! as UserProfileNotPublished).pubkey,
            equals(testPubkey),
          );
        },
      );

      test('returns UserProfileNotPublished when profile is null', () async {
        const nullProfileResponse = '{"profile": null}';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(nullProfileResponse, 200));

        final result = await client.getUserProfile(testPubkey);

        expect(result, isA<UserProfileNotPublished>());
        expect((result! as UserProfileNotPublished).pubkey, equals(testPubkey));
      });

      test('a vanish request with no profile is vanished', () async {
        // Both the pending and the completed-with-nothing-republished states
        // reach the client this way: the server suppresses the Kind 0 for the
        // first and erased it for the second.
        const vanishedResponse =
            '{"has_vanish_request": true, "profile": null}';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(vanishedResponse, 200));

        final result = await client.getUserProfile(testPubkey);

        expect(result, isA<UserProfileVanished>());
        expect((result! as UserProfileVanished).pubkey, equals(testPubkey));
      });

      test('ignores the legacy deleted field', () async {
        const legacyDeletedResponse = '{"deleted": true, "profile": null}';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(legacyDeletedResponse, 200));

        final result = await client.getUserProfile(testPubkey);

        expect(result, isA<UserProfileNotPublished>());
      });

      test('a vanish request alongside a served profile is live', () async {
        // `has_vanish_request` is historical and never goes false again, so a
        // completed vanish that republished a Kind 0 still carries it while
        // the server serves the account as live. Hiding on the flag alone
        // would erase that account from every device permanently.
        const vanishedWithProfile =
            '{"has_vanish_request": true, "profile": {"name": "meylis", '
            '"display_name": "meylis.divine"}}';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(vanishedWithProfile, 200));

        final result = await client.getUserProfile(testPubkey);

        expect(
          result,
          isA<UserProfileFound>(),
          reason:
              'the server serves a republished account as live, and the '
              'client must not hide it on the historical flag alone',
        );
      });

      test('no vanish request with a null profile is not vanished', () async {
        // The discriminator: a user who never published a Kind 0 looks
        // identical on the wire apart from this flag, and must not be treated
        // as deleted.
        const notPublishedResponse =
            '{"has_vanish_request": false, "profile": null}';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(notPublishedResponse, 200));

        final result = await client.getUserProfile(testPubkey);

        expect(result, isA<UserProfileNotPublished>());
      });

      test('a missing vanish-request field is not vanished', () async {
        // Servers that predate the field must keep the previous behaviour.
        const legacyResponse = '{"profile": null}';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(legacyResponse, 200));

        final result = await client.getUserProfile(testPubkey);

        expect(result, isA<UserProfileNotPublished>());
      });

      test('returns null on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final profile = await client.getUserProfile(testPubkey);

        expect(profile, isNull);
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        await client.getUserProfile(testPubkey);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getUserProfile(testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getUserProfile(''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getUserProfile(testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getUserProfile(testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getSocialCounts', () {
      test('returns counts on successful response', () async {
        const validResponse =
            '''
{"pubkey": "$testPubkey", "follower_count": 100, "following_count": 50}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final counts = await client.getSocialCounts(testPubkey);

        expect(counts, isNotNull);
        expect(counts!.followerCount, equals(100));
        expect(counts.followingCount, equals(50));
      });

      test('returns null on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final counts = await client.getSocialCounts(testPubkey);

        expect(counts, isNull);
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        await client.getSocialCounts(testPubkey);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/social'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getSocialCounts(testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getSocialCounts(''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getSocialCounts(testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getSocialCounts(testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getFollowers', () {
      test('returns paginated pubkeys on success', () async {
        const validResponse = '''
{"followers": ["abc", "def"], "total": 50, "has_more": true}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final result = await client.getFollowers(pubkey: testPubkey);

        expect(result.pubkeys, equals(['abc', 'def']));
        expect(result.total, equals(50));
        expect(result.hasMore, isTrue);
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"followers": [], "total": 0}', 200),
        );

        await client.getFollowers(pubkey: testPubkey);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/followers'));
        expect(uri.queryParameters['limit'], equals('100'));
      });

      test('sends the trimmed search query as q', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"followers": [], "total": 0}', 200),
        );

        await client.getFollowers(pubkey: testPubkey, query: '  ali  ');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        expect((captured.first as Uri).queryParameters['q'], equals('ali'));
      });

      test('omits q for a blank query', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"followers": [], "total": 0}', 200),
        );

        await client.getFollowers(pubkey: testPubkey, query: '   ');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        expect(
          (captured.first as Uri).queryParameters.containsKey('q'),
          isFalse,
        );
      });

      test('includes offset when > 0', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"followers": [], "total": 0}', 200),
        );

        await client.getFollowers(pubkey: testPubkey, offset: 50);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['offset'], equals('50'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getFollowers(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getFollowers(pubkey: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeNotFoundException on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        expect(
          () => client.getFollowers(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotFoundException>()),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getFollowers(pubkey: testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getFollowers(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      // Envelope shape tolerance (divine-funnelcake#238 / issue #3521)
      test('returns followers from legacy {followers} shape', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            '{"followers": ["$testPubkey"], "total": 1, "has_more": false}',
            200,
          ),
        );

        final result = await client.getFollowers(pubkey: testPubkey);
        expect(result.pubkeys, hasLength(1));
        expect(result.hasMore, isFalse);
      });

      test(
        'returns followers from {data, pagination} envelope shape',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response(
              '{"data": ["$testPubkey"], '
              '"pagination": {"has_more": true, "next_cursor": "50"}}',
              200,
            ),
          );

          final result = await client.getFollowers(pubkey: testPubkey);
          expect(result.pubkeys, hasLength(1));
          expect(result.pubkeys.first, equals(testPubkey));
          expect(result.hasMore, isTrue);
        },
      );
    });

    group('getFollowing', () {
      test('returns paginated pubkeys on success', () async {
        const validResponse = '''
{"following": ["xyz"], "total": 10, "has_more": false}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final result = await client.getFollowing(pubkey: testPubkey);

        expect(result.pubkeys, equals(['xyz']));
        expect(result.total, equals(10));
        expect(result.hasMore, isFalse);
      });

      test('constructs correct URL', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('{"following": [], "total": 0}', 200),
        );

        await client.getFollowing(pubkey: testPubkey);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/following'));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getFollowing(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getFollowing(pubkey: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeNotFoundException on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        expect(
          () => client.getFollowing(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotFoundException>()),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getFollowing(pubkey: testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getFollowing(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      // Envelope shape tolerance (divine-funnelcake#238 / issue #3521)
      test('returns following from legacy {following} shape', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            '{"following": ["$testPubkey"], "total": 1, "has_more": false}',
            200,
          ),
        );

        final result = await client.getFollowing(pubkey: testPubkey);
        expect(result.pubkeys, hasLength(1));
        expect(result.hasMore, isFalse);
      });

      test(
        'returns following from {data, pagination} envelope shape',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response(
              '{"data": ["$testPubkey"], '
              '"pagination": {"has_more": true, "next_cursor": "100"}}',
              200,
            ),
          );

          final result = await client.getFollowing(pubkey: testPubkey);
          expect(result.pubkeys, hasLength(1));
          expect(result.pubkeys.first, equals(testPubkey));
          expect(result.hasMore, isTrue);
        },
      );
    });

    group('getRecommendations', () {
      const validResponse =
          '''
{
  "videos": [
    {
      "id": "rec123",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "rec-1",
      "title": "Recommended",
      "content": "",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/video.mp4",
      "reactions": 200,
      "comments": 20,
      "reposts": 10,
      "engagement_score": 230
    }
  ],
  "source": "personalized"
}
''';

      test('returns recommendations on success', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final result = await client.getRecommendations(pubkey: testPubkey);

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('rec123'));
        expect(result.source, equals('personalized'));
        expect(result.isPersonalized, isTrue);
      });

      test('constructs correct URL with params', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async =>
              http.Response('{"videos": [], "source": "popular"}', 200),
        );

        await client.getRecommendations(
          pubkey: testPubkey,
          limit: 10,
          fallback: 'recent',
          category: 'comedy',
        );

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/recommendations'));
        expect(uri.queryParameters['limit'], equals('10'));
        expect(uri.queryParameters['fallback'], equals('recent'));
        expect(uri.queryParameters['category'], equals('comedy'));
      });

      test('sends recommendations cursor for paginated requests', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async =>
              http.Response('{"videos": [], "source": "popular"}', 200),
        );

        await client.getRecommendations(
          pubkey: testPubkey,
          cursor: 'rec-page-2',
        );

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/recommendations'));
        expect(uri.queryParameters['cursor'], equals('rec-page-2'));
      });

      test('sends session seed when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async =>
              http.Response('{"videos": [], "source": "popular"}', 200),
        );

        await client.getRecommendations(
          pubkey: testPubkey,
          cursor: 'rec-page-2',
          seed: 'session-seed-1',
        );

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/recommendations'));
        expect(uri.queryParameters['cursor'], equals('rec-page-2'));
        expect(uri.queryParameters['seed'], equals('session-seed-1'));
      });

      test('omits session seed when not provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async =>
              http.Response('{"videos": [], "source": "popular"}', 200),
        );

        await client.getRecommendations(pubkey: testPubkey);

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.queryParameters.containsKey('seed'), isFalse);
      });

      test('sends viewer language and country hints', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async =>
              http.Response('{"videos": [], "source": "popular"}', 200),
        );

        await client.getRecommendations(
          pubkey: testPubkey,
          preferredLanguages: const ['pt'],
          viewerCountry: 'BR',
        );

        final uri =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/recommendations'));
        expect(uri.queryParameters['preferred_languages'], equals('pt'));
        expect(uri.queryParameters['viewer_country'], equals('BR'));
      });

      test('defaults source to unknown when missing', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('{"videos": []}', 200));

        final result = await client.getRecommendations(pubkey: testPubkey);

        expect(result.source, equals('unknown'));
      });

      test('filters invalid videos', () async {
        const responseWithInvalid =
            '''
{
  "videos": [
    {"id": "", "pubkey": "$testPubkey", "created_at": 1700000000,
     "kind": 34236, "d_tag": "t", "title": "X", "thumbnail": "",
     "video_url": "https://example.com/v.mp4",
     "reactions": 0, "comments": 0, "reposts": 0,
     "engagement_score": 0}
  ],
  "source": "popular"
}
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseWithInvalid, 200));

        final result = await client.getRecommendations(pubkey: testPubkey);

        expect(result.videos, isEmpty);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getRecommendations(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getRecommendations(pubkey: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeNotFoundException on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        expect(
          () => client.getRecommendations(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotFoundException>()),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getRecommendations(pubkey: testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getRecommendations(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getRecommendations(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch recommendations'),
            ),
          ),
        );
      });

      // Envelope shape tolerance (divine-funnelcake#238 / issue #3521)
      test('returns videos from legacy {videos} shape (pre-#238)', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final result = await client.getRecommendations(pubkey: testPubkey);
        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('rec123'));
        expect(result.source, equals('personalized'));
      });

      test(
        'returns videos from post-#238 {data, pagination} envelope shape',
        () async {
          const envelopeResponse =
              '''
{
  "data": [
    {
      "id": "rec-env-1",
      "pubkey": "$testPubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "rec-env",
      "title": "Envelope Rec",
      "content": "",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "https://example.com/env.mp4",
      "reactions": 100,
      "comments": 10,
      "reposts": 5,
      "engagement_score": 115
    }
  ],
  "pagination": {"has_more": true, "next_cursor": "opaque-1"},
  "source": "personalized"
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(envelopeResponse, 200));

          final result = await client.getRecommendations(pubkey: testPubkey);
          expect(result.videos, hasLength(1));
          expect(result.videos.first.id, equals('rec-env-1'));
          expect(result.source, equals('personalized'));
          expect(result.hasMore, isTrue);
          expect(result.nextCursor, equals('opaque-1'));
        },
      );
    }); // end group('getRecommendations')

    group('getBulkProfiles', () {
      test('returns profiles on success', () async {
        const validResponse = '''
{
  "users": [
    {
      "pubkey": "pub1",
      "profile": {"name": "Alice", "display_name": "Alice A"}
    },
    {
      "pubkey": "pub2",
      "profile": {"name": "Bob"}
    }
  ]
}
''';
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final result = await client.getBulkProfiles(['pub1', 'pub2']);

        expect(result.profiles, hasLength(2));
        expect(result.profiles['pub1'], isA<UserProfileFound>());
        expect(
          (result.profiles['pub1']! as UserProfileFound).profile.name,
          equals('Alice'),
        );
        expect(result.profiles['pub2'], isA<UserProfileFound>());
        expect(
          (result.profiles['pub2']! as UserProfileFound).profile.name,
          equals('Bob'),
        );
      });

      test('sends correct POST body', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('{"users": []}', 200));

        await client.getBulkProfiles(['pub1', 'pub2']);

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final uri = captured[0] as Uri;
        expect(uri.path, equals('/api/users/bulk'));

        final body = captured[1] as String;
        expect(body, contains('"pubkeys"'));
        expect(body, contains('pub1'));
      });

      test('filters out entries without pubkey', () async {
        const responseWithInvalid = '''
{
  "users": [
    {"pubkey": "", "profile": {"name": "No Key"}},
    {"pubkey": "pub1", "profile": {"name": "Valid"}}
  ]
}
''';
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(responseWithInvalid, 200));

        final result = await client.getBulkProfiles(['pub1']);

        expect(result.profiles, hasLength(1));
        expect(result.profiles['pub1'], isA<UserProfileFound>());
        expect(
          (result.profiles['pub1']! as UserProfileFound).profile.name,
          equals('Valid'),
        );
      });

      test(
        'returns UserProfileNotPublished for users with null profile',
        () async {
          const response = '''
{
  "users": [
    {"pubkey": "pub1", "profile": null},
    {"pubkey": "pub2", "profile": {"name": "Valid"}}
  ]
}
''';
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => http.Response(response, 200));

          final result = await client.getBulkProfiles(['pub1', 'pub2']);

          expect(result.profiles, hasLength(2));
          expect(result.profiles['pub1'], isA<UserProfileNotPublished>());
          expect(result.profiles['pub2'], isA<UserProfileFound>());
          expect(
            (result.profiles['pub2']! as UserProfileFound).profile.name,
            equals('Valid'),
          );
        },
      );

      test(
        'returns UserProfileVanished for has_vanish_request with null profile',
        () async {
          const response = '''
{
  "users": [
    {"pubkey": "pub1", "has_vanish_request": true, "profile": null}
  ]
}
''';
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => http.Response(response, 200));

          final result = await client.getBulkProfiles(['pub1']);

          expect(result.profiles, hasLength(1));
          expect(result.profiles['pub1'], isA<UserProfileVanished>());
        },
      );

      test('returns UserProfileFound for has_vanish_request with populated '
          'profile', () async {
        const response = '''
{
  "users": [
    {
      "pubkey": "pub1",
      "has_vanish_request": true,
      "profile": {"name": "Restored", "display_name": "Restored User"}
    }
  ]
}
''';
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(response, 200));

        final result = await client.getBulkProfiles(['pub1']);

        expect(result.profiles, hasLength(1));
        expect(result.profiles['pub1'], isA<UserProfileFound>());
        expect(
          (result.profiles['pub1']! as UserProfileFound).profile.name,
          equals('Restored'),
        );
      });

      test(
        'returns UserProfileNotPublished for users with all-null profile',
        () async {
          const response = '''
{
  "users": [
    {
      "pubkey": "pub1",
      "profile": {"name": null, "display_name": null, "about": null}
    }
  ]
}
''';
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => http.Response(response, 200));

          final result = await client.getBulkProfiles(['pub1']);

          expect(result.profiles, hasLength(1));
          expect(result.profiles['pub1'], isA<UserProfileNotPublished>());
        },
      );

      test('a vanish request with no profile is vanished', () async {
        // The bulk handler strips a *pending* request upstream, so the only
        // way the flag reaches this parser is a completed vanish that has
        // post-boundary activity but no republished Kind 0.
        const response = '''
{
  "users": [
    {"pubkey": "pub1", "has_vanish_request": true, "profile": null},
    {"pubkey": "pub2", "profile": {"name": "Valid"}}
  ]
}
''';
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(response, 200));

        final result = await client.getBulkProfiles(['pub1', 'pub2']);

        expect(result.profiles['pub1'], isA<UserProfileVanished>());
        expect(result.profiles['pub2'], isA<UserProfileFound>());
      });

      test('a vanish request alongside a served profile is live', () async {
        // Same reconciliation as getUserProfile: the flag is historical, so a
        // republished account still carries it and must not be hidden.
        const response = '''
{
  "users": [
    {
      "pubkey": "pub1",
      "has_vanish_request": true,
      "profile": {"name": "Republished"}
    }
  ]
}
''';
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(response, 200));

        final result = await client.getBulkProfiles(['pub1']);

        expect(result.profiles['pub1'], isA<UserProfileFound>());
        expect(
          (result.profiles['pub1']! as UserProfileFound).profile.name,
          equals('Republished'),
        );
      });

      test('sends correct headers for POST', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('{"users": []}', 200));

        await client.getBulkProfiles(['pub1']);

        final captured = verify(
          () => mockHttpClient.post(
            any(),
            headers: captureAny(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).captured;
        final headers = captured.whereType<Map<String, String>>().first;
        expect(headers['Content-Type'], 'application/json');
        expect(
          headers['User-Agent'],
          matches(RegExp(r'^Divine-Mobile/\S+ \(\w[\w.]*\)$')),
        );
        expect(headers['User-Agent'], isNot('OpenVine-Mobile/1.0'));
        expect(
          headers['X-Divine-Platform'],
          matches(RegExp(r'^[a-z][a-z0-9_]*$')),
        );
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getBulkProfiles(['pub1']),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkeys list is empty', () {
        expect(
          () => client.getBulkProfiles([]),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkeys list cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getBulkProfiles(['pub1']),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getBulkProfiles(['pub1']),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getBulkProfiles(['pub1']),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch bulk profiles'),
            ),
          ),
        );
      });
    });

    group('getBulkVideoStats', () {
      test('returns stats from list format response', () async {
        const validResponse = '''
{
  "stats": [
    {"event_id": "ev1", "reactions": 10, "comments": 5, "reposts": 2},
    {"event_id": "ev2", "reactions": 20, "comments": 10, "reposts": 4}
  ]
}
''';
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(validResponse, 200));

        final result = await client.getBulkVideoStats(['ev1', 'ev2']);

        expect(result.stats, hasLength(2));
        expect(result.stats['ev1']?.reactions, equals(10));
        expect(result.stats['ev2']?.reactions, equals(20));
      });

      test('returns stats from map format response', () async {
        const mapResponse = '''
{
  "stats": {
    "ev1": {"reactions": 10, "comments": 5, "reposts": 2},
    "ev2": {"reactions": 20, "comments": 10, "reposts": 4}
  }
}
''';
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(mapResponse, 200));

        final result = await client.getBulkVideoStats(['ev1', 'ev2']);

        expect(result.stats, hasLength(2));
        expect(result.stats['ev1']?.reactions, equals(10));
      });

      test('sends correct POST body', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('{"stats": []}', 200));

        await client.getBulkVideoStats(['ev1', 'ev2']);

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final uri = captured[0] as Uri;
        expect(uri.path, equals('/api/videos/stats/bulk'));

        final body = captured[1] as String;
        expect(body, contains('"event_ids"'));
        expect(body, contains('ev1'));
      });

      test('filters out entries with empty event ID', () async {
        const responseWithEmpty = '''
{
  "stats": [
    {"event_id": "", "reactions": 10, "comments": 5, "reposts": 2},
    {"event_id": "ev1", "reactions": 20, "comments": 10, "reposts": 4}
  ]
}
''';
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(responseWithEmpty, 200));

        final result = await client.getBulkVideoStats(['ev1']);

        expect(result.stats, hasLength(1));
        expect(result.stats.containsKey('ev1'), isTrue);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getBulkVideoStats(['ev1']),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when eventIds list is empty', () {
        expect(
          () => client.getBulkVideoStats([]),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Event IDs list cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on error status codes', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        expect(
          () => client.getBulkVideoStats(['ev1']),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getBulkVideoStats(['ev1']),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getBulkVideoStats(['ev1']),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch bulk video stats'),
            ),
          ),
        );
      });
    });

    group('dispose', () {
      test('does not close externally provided httpClient', () {
        client.dispose();

        verifyNever(() => mockHttpClient.close());
      });

      test('closes internally created httpClient', () {
        // Create client without providing httpClient
        final internalClient = FunnelcakeApiClient(baseUrl: testBaseUrl);
        // We can't verify the internal client is closed, but we can verify
        // the method doesn't throw
        expect(internalClient.dispose, returnsNormally);
      });
    });

    group('getCategories', () {
      const validResponseBody = '''
[
  {"name": "music", "video_count": 1500},
  {"name": "comedy", "video_count": 900}
]
''';

      test('returns categories on success', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final categories = await client.getCategories();

        expect(categories, hasLength(2));
        expect(categories[0], isA<VideoCategory>());
        expect(categories[0].name, equals('music'));
        expect(categories[0].videoCount, equals(1500));
        expect(categories[1].name, equals('comedy'));
      });

      test('includes query parameter when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        await client.getCategories(query: 'mus');

        final captured =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.first
                as Uri;

        expect(captured.queryParameters['q'], equals('mus'));
      });

      test(
        'throws FunnelcakeNotConfiguredException when unavailable',
        () async {
          final emptyClient = FunnelcakeApiClient(
            baseUrl: '',
            httpClient: mockHttpClient,
          );

          expect(
            emptyClient.getCategories,
            throwsA(isA<FunnelcakeNotConfiguredException>()),
          );

          emptyClient.dispose();
        },
      );

      test('throws FunnelcakeApiException on non-200 response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Server error', 500));

        expect(
          () => client.getCategories(),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getCategories(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getVideosByCategory', () {
      const validResponseBody =
          '''
[
  {
    "id": "cat_video_1",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "cat_video_1",
    "title": "Music Video",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 10,
    "comments": 5,
    "reposts": 2,
    "engagement_score": 17
  }
]
''';

      test('returns videos on success', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(validResponseBody, 200));

        final videos = await client.getVideosByCategory(category: 'music');

        expect(videos, hasLength(1));
        expect(videos.first.title, equals('Music Video'));
      });

      test('includes category and sort in query params', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('[]', 200));

        await client.getVideosByCategory(category: 'Music', sort: 'loops');

        final captured =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.first
                as Uri;

        expect(captured.queryParameters['category'], equals('music'));
        expect(captured.queryParameters['sort'], equals('loops'));
      });

      test('throws FunnelcakeException when category is empty', () async {
        expect(
          () => client.getVideosByCategory(category: ''),
          throwsA(isA<FunnelcakeException>()),
        );
      });

      test(
        'throws FunnelcakeNotConfiguredException when unavailable',
        () async {
          final emptyClient = FunnelcakeApiClient(
            baseUrl: '',
            httpClient: mockHttpClient,
          );

          expect(
            () => emptyClient.getVideosByCategory(category: 'music'),
            throwsA(isA<FunnelcakeNotConfiguredException>()),
          );

          emptyClient.dispose();
        },
      );

      test('throws FunnelcakeApiException on non-200 response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Error', 500));

        expect(
          () => client.getVideosByCategory(category: 'music'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });
    // -------------------------------------------------------------------------
    // Envelope shape tolerance tests (divine-funnelcake#238 / issue #3521)
    //
    // Each representative parser must handle BOTH the legacy raw-array shape
    // (current production) AND the new {data, pagination} envelope shape
    // (post-flag-flip) without throwing or returning empty.
    // -------------------------------------------------------------------------

    group('envelope shape tolerance', () {
      const videoJson =
          '''
{
  "id": "envvideo01",
  "pubkey": "$testPubkey",
  "created_at": 1700000000,
  "kind": 34236,
  "d_tag": "env-video",
  "title": "Envelope Video",
  "content": "Test",
  "thumbnail": "https://example.com/thumb.jpg",
  "video_url": "https://example.com/video.mp4",
  "reactions": 10,
  "comments": 2,
  "reposts": 1,
  "engagement_score": 13
}
''';

      group('_unwrapListResponse via getTrendingVideos', () {
        test('raw-array shape returns items correctly', () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[$videoJson]', 200));

          final videos = await client.getTrendingVideos();
          expect(videos, hasLength(1));
          expect(videos.first.id, equals('envvideo01'));
        });

        test(
          '{data, pagination} envelope shape returns items correctly',
          () async {
            const envelope =
                '''
{
  "data": [$videoJson],
  "pagination": {
    "has_more": true,
    "next_cursor": "1699999999"
  }
}
''';
            when(
              () => mockHttpClient.get(any(), headers: any(named: 'headers')),
            ).thenAnswer((_) async => http.Response(envelope, 200));

            final videos = await client.getTrendingVideos();
            expect(videos, hasLength(1));
            expect(videos.first.id, equals('envvideo01'));
          },
        );

        test(
          'envelope with next_offset instead of next_cursor returns items',
          () async {
            const envelope =
                '''
{
  "data": [$videoJson],
  "pagination": {
    "has_more": true,
    "next_offset": 50
  }
}
''';
            when(
              () => mockHttpClient.get(any(), headers: any(named: 'headers')),
            ).thenAnswer((_) async => http.Response(envelope, 200));

            final videos = await client.getTrendingVideos();
            expect(videos, hasLength(1));
          },
        );

        test(
          'unrecognised shape returns empty list without throwing',
          () async {
            when(
              () => mockHttpClient.get(any(), headers: any(named: 'headers')),
            ).thenAnswer(
              (_) async => http.Response('{"unexpected": "shape"}', 200),
            );

            final videos = await client.getTrendingVideos();
            expect(videos, isEmpty);
          },
        );

        test(
          'unrecognised shape logs a warning while staying non-throwing',
          () async {
            final originalLogger = FunnelcakeApiClient.warningLogger;
            addTearDown(
              () => FunnelcakeApiClient.warningLogger = originalLogger,
            );

            final warnings = <String>[];
            FunnelcakeApiClient.warningLogger = warnings.add;

            when(
              () => mockHttpClient.get(any(), headers: any(named: 'headers')),
            ).thenAnswer(
              (_) async => http.Response('{"unexpected": "shape"}', 200),
            );

            // Behavior contract: still returns empty, never throws.
            final videos = await client.getTrendingVideos();
            expect(videos, isEmpty);

            // Observability contract: the regression is surfaced exactly once
            // with a non-sensitive shape description (counts, not body/keys).
            expect(warnings, hasLength(1));
            expect(
              warnings.single,
              allOf(
                contains('Unrecognised funnelcake list response shape'),
                contains(
                  'Map(keyCount: 1, structuralKeys: [], unknownKeyCount: 1)',
                ),
                isNot(contains('unexpected')),
              ),
            );
          },
        );
      });

      group('searchVideos envelope shape', () {
        test('envelope returns videos, uses length for totalCount', () async {
          const envelope =
              '''
{
  "data": [$videoJson],
  "pagination": {
    "has_more": false,
    "next_cursor": null
  }
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(envelope, 200));

          final result = await client.searchVideos(query: 'test');
          expect(result.videos, hasLength(1));
          // X-Total-Count header is absent; fallback to videos.length.
          expect(result.totalCount, equals(1));
        });

        test('raw-array shape still returns videos', () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[$videoJson]', 200));

          final result = await client.searchVideos(query: 'test');
          expect(result.videos, hasLength(1));
        });
      });

      group('fetchTrendingHashtags envelope shape', () {
        const hashtagJson = '''{"tag": "funny", "count": 42}''';

        test('{data, pagination} envelope returns hashtags', () async {
          const envelope =
              '''
{
  "data": [$hashtagJson],
  "pagination": {"has_more": false, "next_cursor": null}
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(envelope, 200));

          final hashtags = await client.fetchTrendingHashtags();
          expect(hashtags, hasLength(1));
          expect(hashtags.first.tag, equals('funny'));
        });

        test('raw-array shape returns hashtags', () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[$hashtagJson]', 200));

          final hashtags = await client.fetchTrendingHashtags();
          expect(hashtags, hasLength(1));
          expect(hashtags.first.tag, equals('funny'));
        });
      });

      group('searchProfiles envelope shape', () {
        const profileJson =
            '''
{
  "pubkey": "$testPubkey",
  "name": "Alice",
  "display_name": "Alice",
  "about": "",
  "picture": "",
  "nip05": "",
  "follower_count": 0,
  "following_count": 0,
  "video_count": 1
}
''';

        test('{data, pagination} envelope returns profiles', () async {
          const envelope =
              '''
{
  "data": [$profileJson],
  "pagination": {"has_more": false, "next_cursor": null}
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(envelope, 200));

          final profiles = await client.searchProfiles(query: 'alice');
          expect(profiles, hasLength(1));
          expect(profiles.first.pubkey, equals(testPubkey));
        });

        test('raw-array shape returns profiles', () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[$profileJson]', 200));

          final profiles = await client.searchProfiles(query: 'alice');
          expect(profiles, hasLength(1));
        });
      });

      group('getCategories envelope shape', () {
        const categoryJson =
            '{"name": "comedy", "display_name": "Comedy", "video_count": 100}';

        test('{data, pagination} envelope returns categories', () async {
          const envelope =
              '''
{
  "data": [$categoryJson],
  "pagination": {"has_more": false, "next_cursor": null}
}
''';
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(envelope, 200));

          final categories = await client.getCategories();
          expect(categories, hasLength(1));
          expect(categories.first.name, equals('comedy'));
        });

        test('raw-array shape returns categories', () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response('[$categoryJson]', 200));

          final categories = await client.getCategories();
          expect(categories, hasLength(1));
        });
      }); // end group('getCategories envelope shape')
    }); // end group('envelope shape tolerance')
  }); // end group('FunnelcakeApiClient')

  group('Exceptions', () {
    test('FunnelcakeException has correct toString', () {
      const exception = FunnelcakeException('Test error');
      expect(exception.toString(), equals('FunnelcakeException: Test error'));
    });

    test('FunnelcakeException preserves wrapped cause', () {
      const cause = FormatException('bad response');
      const exception = FunnelcakeException('Test error', cause: cause);

      expect(exception.cause, same(cause));
      expect(
        exception.toString(),
        equals(
          'FunnelcakeException: Test error '
          '(cause: FormatException: bad response)',
        ),
      );
    });

    test('FunnelcakeNotConfiguredException has correct message', () {
      const exception = FunnelcakeNotConfiguredException();
      expect(exception.message, equals('Funnelcake API not configured'));
    });

    test('FunnelcakeApiException includes status code', () {
      const exception = FunnelcakeApiException(
        message: 'Test error',
        statusCode: 500,
        url: 'https://example.com',
      );
      expect(exception.statusCode, equals(500));
      expect(exception.url, equals('https://example.com'));
      expect(
        exception.toString(),
        equals(
          'FunnelcakeApiException: Test error '
          '(status: 500, url: https://example.com)',
        ),
      );
    });

    test('FunnelcakeNotFoundException has correct resource message', () {
      final exception = FunnelcakeNotFoundException(
        resource: 'Video',
        url: 'https://example.com',
      );
      expect(exception.message, equals('Video not found'));
      expect(exception.statusCode, equals(404));
    });

    test('FunnelcakeTimeoutException includes URL when provided', () {
      const exceptionWithUrl = FunnelcakeTimeoutException(
        'https://example.com',
      );
      expect(
        exceptionWithUrl.message,
        equals('Request timed out for https://example.com'),
      );

      const exceptionWithoutUrl = FunnelcakeTimeoutException();
      expect(exceptionWithoutUrl.message, equals('Request timed out'));
    });
  }); // end group('Exceptions')
} // end main
