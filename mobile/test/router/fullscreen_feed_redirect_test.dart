// ABOUTME: Tests the pooled-feed route redirect and builder: recovery without
// ABOUTME: `extra`, unsupported-extra warnings, and profile-args forwarding.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/pooled_fullscreen_feed_route.dart'
    show buildPooledFullscreenFeed, fullscreenFeedRedirect;
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:unified_logger/unified_logger.dart';

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

    test('asserts when extra is an unsupported type', () {
      expect(
        () => fullscreenFeedRedirect('not-args'),
        throwsA(
          isA<AssertionError>().having(
            (error) => '${error.message}',
            'message',
            allOf(
              contains('String'),
              matches(RegExp(r'\bPooledFullscreenVideoFeedArgs\b')),
              contains('ProfilePooledFullscreenVideoFeedArgs'),
            ),
          ),
        ),
      );
    });

    test('logs a warning when extra is an unsupported type', () async {
      final logCapture = LogCaptureService();
      await logCapture.clearAllLogs();
      addTearDown(logCapture.clearAllLogs);

      expect(() => fullscreenFeedRedirect('not-args'), throwsAssertionError);

      final warning = logCapture.getRecentLogs().singleWhere(
        (log) => log.level == LogLevel.warning,
      );
      expect(warning.name, equals('FullscreenFeedRoute'));
      expect(warning.category, equals(LogCategory.ui));
      expect(
        warning.message,
        equals(
          'Unsupported extra String for the fullscreen feed. '
          'Pass PooledFullscreenVideoFeedArgs or '
          'ProfilePooledFullscreenVideoFeedArgs.',
        ),
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
          localizationsDelegates: appLocalizationsDelegates,
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

    testWidgets('builder forwards profile args to $ProfileVideoFeedView', (
      tester,
    ) async {
      late Widget built;
      final pageChanges = <int>[];
      final seedVideos = [_video('1'), _video('2')];
      final args = ProfilePooledFullscreenVideoFeedArgs(
        userIdHex: 'profile-hex',
        initialIndex: 1,
        seedVideos: seedVideos,
        initialVideoId: '2',
        initialStableId: 'stable-2',
        contextTitle: 'Profile title',
        onPageChanged: pageChanges.add,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
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

      expect(built, isA<ProfileVideoFeedView>());
      final view = built as ProfileVideoFeedView;
      expect(view.userIdHex, equals('profile-hex'));
      expect(view.videoIndex, equals(1));
      expect(view.videos, equals(seedVideos));
      expect(view.initialVideoId, equals('2'));
      expect(view.initialStableId, equals('stable-2'));
      expect(view.contextTitleOverride, equals('Profile title'));
      view.onPageChanged?.call(3);
      expect(pageChanges, equals([3]));
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
