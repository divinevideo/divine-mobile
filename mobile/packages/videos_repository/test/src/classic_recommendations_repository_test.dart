import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:videos_repository/videos_repository.dart';

class _Api extends Mock implements FunnelcakeApiClient {}

class _Nostr extends Mock implements NostrClient {}

String _id(int value) => value.toRadixString(16).padLeft(64, '0');
VideoStats _stats(int value, {bool classic = true, bool verified = true}) =>
    VideoStats.fromJson({
      'id': _id(value),
      'pubkey': _id(value + 100),
      'created_at': value,
      'video_url': 'https://example.com/$value.mp4',
      'platform': classic ? 'vine' : 'divine',
      'verified_archive': verified,
      'archive_provenance_available': true,
    });

void main() {
  const request = ClassicRecommendationsRequest(seed: 'independent-session');
  setUpAll(() {
    registerFallbackValue(request);
  });
  late _Api api;
  late VideosRepository repository;
  setUp(() {
    api = _Api();
    when(() => api.isAvailable).thenReturn(true);
    when(() => api.isDisposed).thenReturn(false);
    when(
      () => api.getBulkVideoStats(any()),
    ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
    final nostr = _Nostr();
    when(() => nostr.publicKey).thenReturn('');
    repository = VideosRepository(
      nostrClient: nostr,
      funnelcakeApiClient: api,
    );
  });

  test(
    'preserves server rank and rejects native and unverified candidates',
    () async {
      when(
        () => api.getClassicRecommendations(
          request: request,
          userPubkey: _id(1000),
        ),
      ).thenAnswer(
        (_) async => RecommendationsResponse(
          videos: [
            _stats(3),
            _stats(2, classic: false),
            _stats(4, verified: false),
            _stats(1),
          ],
          source: 'mixed',
          hasMore: true,
          nextCursor: 'opaque',
        ),
      );
      final result = await repository.getClassicRecommendations(
        request: request,
        userPubkey: _id(1000),
      );
      expect(result.videos.map((v) => v.id), [_id(3), _id(1)]);
      expect(result.paginationCursor, 'opaque');
      expect(result.hasMore, isTrue);
      expect(result.recommendationPageCount, 1);
    },
  );

  test(
    'disabled endpoint falls back to archive and carries its cursor',
    () async {
      when(
        () => api.getClassicRecommendations(request: request),
      ).thenThrow(const FunnelcakeException('disabled'));
      when(
        () => api.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => [
          _stats(1),
          _stats(2, classic: false),
          _stats(3, verified: false),
        ],
      );
      final result = await repository.getClassicRecommendations(
        request: request,
      );
      expect(result.videos.map((v) => v.id), [_id(1)]);
      expect(result.paginationCursor, startsWith('classic-offset:'));
      expect(result.recommendationPageCount, 0);
      final continued = ClassicRecommendationsRequest(
        seed: request.seed,
        cursor: result.paginationCursor,
      );
      await repository.getClassicRecommendations(request: continued);
      verifyNever(() => api.getClassicRecommendations(request: continued));
    },
  );

  test(
    'does not replace a failed adaptive continuation '
    'with an unrelated archive page',
    () async {
      const continued = ClassicRecommendationsRequest(
        seed: 'session',
        cursor: 'opaque',
      );
      when(
        () => api.getClassicRecommendations(request: continued),
      ).thenThrow(const FunnelcakeException('offline'));
      await expectLater(
        repository.getClassicRecommendations(request: continued),
        throwsA(isA<FunnelcakeException>()),
      );
      verifyNever(
        () => api.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      );
    },
  );
  test(
    'privacy withdrawal discards the reply before any filtered top-up',
    () async {
      var allowed = true;
      when(() => api.getClassicRecommendations(request: request)).thenAnswer((
        _,
      ) async {
        allowed = false;
        return RecommendationsResponse(
          videos: [_stats(1, classic: false)],
          source: 'mixed',
          hasMore: true,
          nextCursor: 'continue',
        );
      });
      await expectLater(
        repository.getClassicRecommendations(
          request: request,
          isCurrent: () => allowed,
        ),
        throwsA(isA<FunnelcakeException>()),
      );
      verify(() => api.getClassicRecommendations(request: request)).called(1);
      verifyNever(
        () => api.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      );
    },
  );
  test(
    'browsing rejects an old reply and rotates seed across privacy toggles',
    () async {
      var generation = 0;
      final requests = <ClassicRecommendationsRequest>[];
      final nostr = _Nostr();
      when(() => nostr.publicKey).thenReturn('');
      final browser = VideosRepository(
        nostrClient: nostr,
        funnelcakeApiClient: api,
        classicRecommendationsEnabled: true,
        classicViewerPubkey: () => _id(1000),
        classicContextKey: () => generation,
      );
      when(
        () => api.getClassicRecommendations(
          request: any(named: 'request'),
          userPubkey: _id(1000),
        ),
      ).thenAnswer((call) async {
        requests.add(
          call.namedArguments[#request] as ClassicRecommendationsRequest,
        );
        if (requests.length == 1) {
          generation += 2;
          return RecommendationsResponse(
            videos: [_stats(1, classic: false)],
            source: 'mixed',
            hasMore: true,
            nextCursor: 'old-page',
          );
        }
        return RecommendationsResponse(
          videos: [_stats(2)],
          source: 'mixed',
        );
      });
      await expectLater(
        browser.getClassicVideos(),
        throwsA(isA<FunnelcakeException>()),
      );
      expect(requests, hasLength(1));
      final next = await browser.getClassicVideos(cursor: 'old-page');
      expect(next.videos.map((v) => v.id), [_id(2)]);
      expect(requests.last.cursor, isNull);
      expect(requests.last.seed, isNot(requests.first.seed));
    },
  );
}
