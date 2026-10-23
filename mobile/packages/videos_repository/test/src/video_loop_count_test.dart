import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  final video = VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: 1700000000,
    content: '',
    timestamp: DateTime.utc(2026),
    originalLoops: 100,
  );

  group('fetchLoopCount', () {
    test(
      'adds archival loops once and preserves the larger live playback total',
      () async {
        final client = _MockFunnelcakeApiClient();
        when(() => client.isAvailable).thenReturn(true);
        final repository = VideosRepository(
          nostrClient: _MockNostrClient(),
          funnelcakeApiClient: client,
        );
        for (final sample in [
          (loops: 12, views: 5, want: 112),
          (loops: 3, views: 8, want: 108),
        ]) {
          when(() => client.getBulkVideoStats([video.id])).thenAnswer(
            (_) async => BulkVideoStatsResponse(
              stats: {
                video.id: BulkVideoStatsEntry(
                  eventId: video.id,
                  reactions: 0,
                  comments: 0,
                  reposts: 0,
                  loops: sample.loops,
                  views: sample.views,
                  embeddedLoops: 100,
                ),
              },
            ),
          );
          expect(await repository.fetchLoopCount(video), sample.want);
        }
      },
    );

    test('no API or missing video produces no invented server total', () async {
      final repository = VideosRepository(nostrClient: _MockNostrClient());
      expect(await repository.fetchLoopCount(video), isNull);
      final client = _MockFunnelcakeApiClient();
      when(() => client.isAvailable).thenReturn(true);
      when(
        () => client.getBulkVideoStats([video.id]),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      final withApi = VideosRepository(
        nostrClient: _MockNostrClient(),
        funnelcakeApiClient: client,
      );
      expect(await withApi.fetchLoopCount(video), isNull);
    });
  });
}
