// ABOUTME: Tests pooled-feed route recovery when lifecycle restoration loses
// ABOUTME: in-memory `extra`, including durable selected-video URL fallback.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/pooled_fullscreen_feed_route.dart'
    show buildPooledFullscreenFeed, fullscreenFeedRedirect;
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'author',
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
);

class _RestoredPooledFeedState extends Fake implements GoRouterState {
  _RestoredPooledFeedState(String videoId)
    : uri = Uri.parse(PooledFullscreenVideoFeedScreen.pathForVideoId(videoId));

  @override
  final Uri uri;

  @override
  Object? get extra => null;
}

class _PooledFeedState extends Fake implements GoRouterState {
  _PooledFeedState(this.extra);

  @override
  final Object? extra;

  @override
  Uri get uri => Uri.parse(PooledFullscreenVideoFeedScreen.path);
}

void main() {
  group('fullscreenFeedRedirect', () {
    test('redirects to the home feed when extra is null (web reload)', () {
      expect(
        fullscreenFeedRedirect(null),
        equals(VideoFeedPage.pathForIndex(0)),
      );
    });

    test(
      'recovers the selected video when lifecycle restoration loses extra',
      () {
        expect(
          fullscreenFeedRedirect(null, fallbackVideoId: 'video-123'),
          equals(VideoDetailScreen.pathForId('video-123')),
        );
      },
    );

    test('redirects to the home feed when extra is the wrong type', () {
      expect(
        fullscreenFeedRedirect('not-args'),
        equals(VideoFeedPage.pathForIndex(0)),
      );
    });

    test('does not redirect when valid pooled feed args are present', () {
      final args = PooledFullscreenVideoFeedArgs(
        source: SingleVideoViewSource(_video('1')),
        feedRepository: StaticFeedRepository(),
        initialIndex: 0,
      );

      expect(fullscreenFeedRedirect(args), isNull);
    });

    test('does not redirect when valid profile feed args are present', () {
      const args = ProfilePooledFullscreenVideoFeedArgs(
        userIdHex: 'abc',
        initialIndex: 0,
      );

      expect(fullscreenFeedRedirect(args), isNull);
    });
  });

  group('PooledFullscreenVideoFeedScreen.pathForVideoId', () {
    test('puts the selected video identity in the route URL', () {
      expect(
        PooledFullscreenVideoFeedScreen.pathForVideoId('video/with spaces'),
        equals('/pooled-video-feed?video=video%2Fwith+spaces'),
      );
    });

    testWidgets('builder forwards the sponsor disclosure', (tester) async {
      late Widget built;
      final args = PooledFullscreenVideoFeedArgs(
        source: SingleVideoViewSource(_video('1')),
        feedRepository: StaticFeedRepository(),
        initialIndex: 0,
        sponsorName: 'Acme Bikes',
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              built = buildPooledFullscreenFeed(
                context,
                _PooledFeedState(args),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(built, isA<PooledFullscreenVideoFeedScreen>());
      expect(
        (built as PooledFullscreenVideoFeedScreen).sponsorName,
        'Acme Bikes',
      );
    });

    testWidgets(
      'builder recovers directly if extra disappears after redirect',
      (tester) async {
        late Widget recovered;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                recovered = buildPooledFullscreenFeed(
                  context,
                  _RestoredPooledFeedState('video-123'),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(recovered, isA<VideoDetailScreen>());
        expect((recovered as VideoDetailScreen).videoId, 'video-123');
      },
    );
  });
}
