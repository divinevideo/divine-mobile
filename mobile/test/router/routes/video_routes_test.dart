// ABOUTME: Tests the video routes registered by videoRoutes.
// ABOUTME: Pins their locations against RoutePaths, the editor's path builder,
// ABOUTME: spelled-out URLs and the named locations callers used, their order,
// ABOUTME: pages and navigators, and how each route builds from its URL, with
// ABOUTME: an extra or without one.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent, VideoEvent;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/recorder_sound_selection.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/router/widgets/sound_detail_loader.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:openvine/widgets/release_cached_images_on_dispose.dart';

import '../../helpers/l10n.dart';

class _FakeBuildContext extends Fake implements BuildContext {}

const _hexId =
    'c218ed9ce99db3c216ca7c70f7a289a3da56fe0b9ba1492b3179db73c8e63a4d';
const _authorHex =
    '81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95';
const _dTag = 'ip1dd9tAlmw';
const _coordinate = '34236:$_authorHex:$_dTag';
const _nevent =
    'nevent1qqsvyx8dnn5emv7zzm98cu8h52y68kjklc9ehg2f9vchnkmnernr5ngvsmkn3';
const _naddr =
    'naddr1qq9kjup3v3jrjazpd3khwq3qsxktkuz8tw9hzhpc6pevaymknj3827parpu'
    'eqyt7crqpa2zfh72sxpqqqzzmcqtynsu';

/// The shape `DivineVideoDraft` gives every draft id.
const _draftId = 'draft_1757385263000';

/// Path values whose encoding has broken routes before: the ids and keys
/// callers pass, a literal `%` (#3413), a space, a slash, and the characters
/// that end a path.
final _pathValues = <String>[
  _hexId,
  NostrKeyUtils.encodePubKey(_authorHex),
  _naddr,
  '100%fun',
  'a b',
  'a/b',
  'what?#now',
];

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: _authorHex,
  createdAt: 1757385263,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
);

/// The app's video route table, behind a router whose navigator is the app's
/// root: the analytics routes are parented to it.
GoRouter _videoRouter() {
  final router = GoRouter(
    navigatorKey: NavigatorKeys.root,
    routes: videoRoutes(),
  );
  addTearDown(router.dispose);
  return router;
}

/// The route [location] matches in the real table, with the state go_router
/// hands it.
({GoRoute route, GoRouterState state}) _resolve(
  GoRouter router,
  String location, {
  Object? extra,
}) {
  final match = router.configuration.findMatch(
    Uri.parse(location),
    extra: extra,
  );
  expect(match.isError, isFalse, reason: 'no video route matches $location');
  return (
    route: match.last.route,
    state: router.configuration.buildTopLevelGoRouterState(match),
  );
}

/// What the route [location] matches builds, given [extra].
Widget _build(
  GoRouter router,
  String location, {
  Object? extra,
  BuildContext? context,
}) {
  final (:route, :state) = _resolve(router, location, extra: extra);
  return route.builder!(context ?? _FakeBuildContext(), state);
}

/// Where the route [location] matches redirects, given [extra].
Object? _redirect(GoRouter router, String location, {Object? extra}) {
  final (:route, :state) = _resolve(router, location, extra: extra);
  return route.redirect!(_FakeBuildContext(), state);
}

/// The recorder the recorder route mounts for [location], without building it.
VideoRecorderRoute _recorderAt(
  GoRouter router,
  String location, {
  Object? extra,
}) {
  final (:route, :state) = _resolve(router, location, extra: extra);
  final page = route.pageBuilder!(
    _FakeBuildContext(),
    state,
  ) as CustomTransitionPage<void>;
  return (page.child as ReleaseCachedImagesOnDispose).child
      as VideoRecorderRoute;
}

Iterable<GoRoute> _flatten(List<RouteBase> routes) sync* {
  for (final route in routes.whereType<GoRoute>()) {
    yield route;
    yield* _flatten(route.routes);
  }
}

GoRoute _routeNamed(String name) =>
    _flatten(videoRoutes()).singleWhere((route) => route.name == name);

void main() {
  group('videoRoutes', () {
    group('registration', () {
      // The patterns and names are what links, redirects, page-context
      // restoration and analytics read, so the typed table keeps the values
      // and the match order of the hand-written one.
      test('keeps every top-level pattern, in order', () {
        expect(
          videoRoutes().map((route) => (route as GoRoute).path),
          equals([
            '/video-recorder',
            '/creator-analytics',
            '/video/:id',
            '/sound/:id',
            '/original-sound/:pubkey',
            '/video-editor',
            '/video-editor/:draftId',
            '/video-metadata',
            '/video-edit/:videoId',
            '/subtitle-edit/:videoId',
            '/pooled-video-feed',
            '/video/:eventId/likers',
            '/video/:eventId/reposters',
          ]),
          reason:
              'The engagement lists must stay flat and top-level: nested, '
              'canPop() turns true on cold entry and retires the safePop '
              'fallback in VideoEngagementListView (#9359).',
        );
      });

      test('keeps every route name', () {
        expect(
          _flatten(videoRoutes()).map((route) => route.name),
          equals([
            'video-recorder',
            'creator-analytics',
            'creator-analytics-post',
            'video',
            'sound',
            'originalSound',
            'video-editor',
            'video-editor-draft',
            'video-metadata',
            'video-edit',
            'subtitle-edit',
            'pooled-video-feed',
            'videoLikers',
            'videoReposters',
          ]),
        );
      });

      test('nests post analytics under creator analytics', () {
        expect(
          _routeNamed(CreatorAnalyticsScreen.routeName).routes,
          [
            isA<GoRoute>()
                .having((route) => route.path, 'path', ':videoId')
                .having(
                  (route) => route.name,
                  'name',
                  PostAnalyticsDetailScreen.routeName,
                ),
          ],
        );
      });
    });

    group('navigators', () {
      test('the analytics routes cover the shell on the root navigator', () {
        expect(
          _routeNamed(CreatorAnalyticsScreen.routeName).parentNavigatorKey,
          same(NavigatorKeys.root),
        );
        expect(
          _routeNamed(PostAnalyticsDetailScreen.routeName).parentNavigatorKey,
          same(NavigatorKeys.root),
        );
      });

      test("every other route uses the router's own navigator", () {
        final others = _flatten(videoRoutes()).where(
          (route) =>
              route.name != CreatorAnalyticsScreen.routeName &&
              route.name != PostAnalyticsDetailScreen.routeName,
        );

        expect(others, hasLength(12));
        for (final route in others) {
          expect(route.parentNavigatorKey, isNull, reason: route.path);
        }
      });
    });

    group('locations', () {
      // Redirects, the route parser and page-context restoration still build
      // these locations from RoutePaths, so the typed routes must produce the
      // same URLs. The fullscreen feed has no RoutePaths builder, so its
      // location is spelled out from the value.
      final builders =
          <(String, String Function(String), String Function(String))>[
            (
              'detail',
              (value) => VideoDetailRouteData(id: value).location,
              RoutePaths.videoDetailForId,
            ),
            (
              'sound',
              (value) => SoundDetailRouteData(id: value).location,
              RoutePaths.soundDetailForId,
            ),
            (
              'metadata edit',
              (value) => VideoMetadataEditRouteData(videoId: value).location,
              RoutePaths.videoMetadataEditFor,
            ),
            (
              'subtitle edit',
              (value) => SubtitleEditorRouteData(videoId: value).location,
              RoutePaths.subtitleEditorFor,
            ),
            (
              'fullscreen feed',
              (value) =>
                  PooledFullscreenVideoFeedRouteData(video: value).location,
              (value) =>
                  '/pooled-video-feed?video=${Uri.encodeQueryComponent(value)}',
            ),
          ];
      for (final (label, typed, builder) in builders) {
        for (final value in _pathValues) {
          test('a $label location matches its builder for "$value"', () {
            expect(typed(value), equals(builder(value)));
          });
        }
      }

      // These pin the locations for the values callers pass: hex event ids,
      // hex and npub keys, and the app's own draft ids. The editor builder
      // splices the draft id in unencoded, so it agrees with the typed
      // location only for ids like these. The round trip below is what
      // proves the typed locations for every other value.
      test('a post-analytics location nests the event id under analytics', () {
        expect(
          const PostAnalyticsDetailRouteData(videoId: _hexId).location,
          equals('/creator-analytics/$_hexId'),
        );
      });

      test('an original-sound location ends in the key', () {
        for (final pubkey in [
          _authorHex,
          NostrKeyUtils.encodePubKey(_authorHex),
        ]) {
          expect(
            OriginalSoundDetailRouteData(pubkey: pubkey).location,
            equals('/original-sound/$pubkey'),
          );
        }
      });

      test('a draft editor location matches pathFor for a draft id', () {
        expect(
          const VideoEditorDraftRouteData(draftId: _draftId).location,
          equals(VideoEditorScreen.pathFor(draftId: _draftId)),
        );
        expect(
          const VideoEditorDraftRouteData(
            draftId: _draftId,
            from: VideoEditorScreen.libraryOrigin,
          ).location,
          equals(
            VideoEditorScreen.pathFor(draftId: _draftId, fromLibrary: true),
          ),
        );
      });

      // The four engagement callers named these routes and keyed the id
      // 'eventId'. The typed classes must reach the URLs they reached.
      for (final value in _pathValues) {
        test('an engagement location matches the named location for '
            '"$value"', () {
          final router = _videoRouter();

          expect(
            VideoLikersRouteData(eventId: value).location,
            equals(
              router.namedLocation(
                VideoEngagementListScreen.likersRouteName,
                pathParameters: {'eventId': value},
              ),
            ),
          );
          expect(
            VideoRepostersRouteData(eventId: value, a: _coordinate).location,
            equals(
              router.namedLocation(
                VideoEngagementListScreen.repostersRouteName,
                pathParameters: {'eventId': value},
                queryParameters: {'a': _coordinate},
              ),
            ),
          );
        });
      }

      test('a likers location carries the coordinate as an encoded ?a=', () {
        expect(
          const VideoLikersRouteData(eventId: _hexId, a: _coordinate).location,
          equals('/video/$_hexId/likers?a=34236%3A$_authorHex%3A$_dTag'),
        );
      });

      // What callers push for the no-argument forms: the bare path, with no
      // `?` for the absent `from` and `mode` query fields.
      test('the no-argument routes push their bare paths', () {
        expect(
          const CreatorAnalyticsRouteData().location,
          equals('/creator-analytics'),
        );
        expect(const VideoEditorRouteData().location, equals('/video-editor'));
        expect(
          const VideoMetadataRouteData().location,
          equals('/video-metadata'),
        );
      });

      // The public-recorder gate passes `/video-recorder` and anything that
      // starts `/video-recorder?`, and nothing else.
      test('the recorder keeps the locations the public gate passes', () {
        expect(
          const VideoRecorderRouteData().location,
          equals('/video-recorder'),
        );
        expect(
          const VideoRecorderRouteData(
            entryPoint: CreationEntryPoint.bottomNav,
          ).location,
          startsWith('/video-recorder?'),
        );
      });
    });

    group('query parameters keep their names', () {
      test('the recorder reads entry_point', () {
        final location = const VideoRecorderRouteData(
          entryPoint: CreationEntryPoint.bottomNav,
        ).location;

        expect(location, contains('entry_point=bottom_nav'));
        expect(
          location,
          equals(
            VideoRecorderScreen.pathForEntryPoint(CreationEntryPoint.bottomNav),
          ),
        );
      });

      test('the recorder reads challenge_recording', () {
        final location = const VideoRecorderRouteData(
          challengeRecording: _naddr,
        ).location;

        expect(location, contains('challenge_recording=$_naddr'));
        expect(
          location,
          equals(
            Uri(
              path: VideoRecorderScreen.path,
              queryParameters: {'challenge_recording': _naddr},
            ).toString(),
          ),
        );
      });

      test('the video detail reads author', () {
        const author =
            'e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3';
        final location = const VideoDetailRouteData(
          id: 'stable_id',
          author: author,
        ).location;

        expect(location, equals('/video/stable_id?author=$author'));
        expect(
          location,
          equals(VideoDetailScreen.pathForId('stable_id', author: author)),
        );
      });

      test('the editor reads from', () {
        final location = const VideoEditorRouteData(
          from: VideoEditorScreen.libraryOrigin,
        ).location;

        expect(location, contains('from=library'));
        expect(location, equals(VideoEditorScreen.pathFor(fromLibrary: true)));
      });

      test('the metadata screen reads mode', () {
        final location = VideoMetadataRouteData(
          mode: VideoRecorderMode.stopMotion.name,
        ).location;

        expect(location, contains('mode=stopMotion'));
        expect(
          location,
          equals(VideoMetadataScreen.pathForDraft(isStopMotion: true)),
        );
      });

      test('the fullscreen feed reads video', () {
        expect(
          const PooledFullscreenVideoFeedRouteData(video: _hexId).location,
          contains('video=$_hexId'),
        );
      });

      test('the engagement lists read a', () {
        expect(
          const VideoRepostersRouteData(
            eventId: _hexId,
            a: _coordinate,
          ).location,
          contains('?a='),
        );
      });
    });

    group('round trip through the route table', () {
      // A typed location must match its own route and hand back exactly the
      // value it was built from, whatever the value holds.
      for (final value in _pathValues) {
        test('"$value" survives every path parameter', () {
          final router = _videoRouter();

          void expectRoundTrip(String location, String name, String key) {
            final (:route, :state) = _resolve(router, location);
            expect(route.name, equals(name), reason: location);
            expect(state.pathParameters[key], equals(value), reason: location);
          }

          expectRoundTrip(
            PostAnalyticsDetailRouteData(videoId: value).location,
            PostAnalyticsDetailScreen.routeName,
            'videoId',
          );
          expectRoundTrip(
            VideoDetailRouteData(id: value).location,
            VideoDetailScreen.routeName,
            'id',
          );
          expectRoundTrip(
            SoundDetailRouteData(id: value).location,
            SoundDetailScreen.routeName,
            'id',
          );
          expectRoundTrip(
            OriginalSoundDetailRouteData(pubkey: value).location,
            OriginalSoundDetailScreen.routeName,
            'pubkey',
          );
          expectRoundTrip(
            VideoEditorDraftRouteData(draftId: value).location,
            VideoEditorScreen.draftRouteName,
            'draftId',
          );
          expectRoundTrip(
            VideoMetadataEditRouteData(videoId: value).location,
            VideoMetadataEditScreen.routeName,
            'videoId',
          );
          expectRoundTrip(
            SubtitleEditorRouteData(videoId: value).location,
            SubtitleEditorScreen.routeName,
            'videoId',
          );
          expectRoundTrip(
            VideoLikersRouteData(eventId: value).location,
            VideoEngagementListScreen.likersRouteName,
            'eventId',
          );
          expectRoundTrip(
            VideoRepostersRouteData(eventId: value).location,
            VideoEngagementListScreen.repostersRouteName,
            'eventId',
          );
        });
      }
    });

    group('recorder', () {
      testWidgets('opens with the fade-upwards transition', (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        );
        final (:route, :state) = _resolve(
          _videoRouter(),
          VideoRecorderScreen.path,
        );

        final page = route.pageBuilder!(context, state);

        expect(page, isA<CustomTransitionPage<void>>());
        expect(page.name, equals(VideoRecorderScreen.routeName));
        const child = SizedBox.shrink();
        final transition = (page as CustomTransitionPage<void>)
            .transitionsBuilder(
              context,
              kAlwaysCompleteAnimation,
              kAlwaysDismissedAnimation,
              child,
            );
        final fadeUpwards = const FadeUpwardsPageTransitionsBuilder()
            .buildTransitions<void>(
              null,
              context,
              kAlwaysCompleteAnimation,
              kAlwaysDismissedAnimation,
              child,
            );
        expect(transition.runtimeType, equals(fadeUpwards.runtimeType));
      });

      test('passes a typed sound selection to the recorder', () {
        final selection = RecorderSoundSelection(
          sound: AudioEvent(id: 'a' * 64, pubkey: 'b' * 64, createdAt: 1),
          ownerPubkey: 'c' * 64,
        );

        final recorder = _recorderAt(
          _videoRouter(),
          VideoRecorderScreen.path,
          extra: selection,
        );

        expect(recorder.initialSound, same(selection));
      });

      test('ignores unsupported extras without changing its defaults', () {
        final recorder = _recorderAt(
          _videoRouter(),
          VideoRecorderScreen.path,
          extra: {'sound': 'unsupported'},
        );

        expect(recorder.initialSound, isNull);
        expect(recorder.entryPoint, equals(CreationEntryPoint.direct));
        expect(recorder.autoRecord, isFalse);
      });

      test('a bare location opens directly, without auto-record', () {
        final recorder = _recorderAt(_videoRouter(), VideoRecorderScreen.path);

        expect(recorder.initialSound, isNull);
        expect(recorder.challengeRecordingId, isNull);
        expect(recorder.entryPoint, equals(CreationEntryPoint.direct));
        expect(recorder.autoRecord, isFalse);
      });

      test('reads the entry point from the query', () {
        final recorder = _recorderAt(
          _videoRouter(),
          const VideoRecorderRouteData(
            entryPoint: CreationEntryPoint.bottomNav,
          ).location,
        );

        expect(recorder.entryPoint, equals(CreationEntryPoint.bottomNav));
        expect(recorder.autoRecord, isFalse);
      });

      test('reads the auto-record flag from the query', () {
        final recorder = _recorderAt(
          _videoRouter(),
          VideoRecorderScreen.pathForEntryPoint(
            CreationEntryPoint.bottomNav,
            autoRecord: true,
          ),
        );

        expect(recorder.entryPoint, equals(CreationEntryPoint.bottomNav));
        expect(recorder.autoRecord, isTrue);
      });

      test('reads the challenge being recorded from the query', () {
        final recorder = _recorderAt(
          _videoRouter(),
          const VideoRecorderRouteData(challengeRecording: _naddr).location,
        );

        expect(recorder.challengeRecordingId, equals(_naddr));
      });
    });

    group('image release', () {
      test('releases cached images when the recorder closes', () {
        final (:route, :state) = _resolve(
          _videoRouter(),
          VideoRecorderScreen.path,
        );

        expect(
          (route.pageBuilder!(
            _FakeBuildContext(),
            state,
          ) as CustomTransitionPage<void>).child,
          isA<ReleaseCachedImagesOnDispose>().having(
            (scope) => scope.child,
            'child',
            isA<VideoRecorderRoute>(),
          ),
        );
      });

      for (final location in [
        const VideoEditorRouteData().location,
        const VideoEditorDraftRouteData(draftId: _draftId).location,
      ]) {
        test('$location releases cached images when the editor closes', () {
          expect(
            _build(_videoRouter(), location),
            isA<ReleaseCachedImagesOnDispose>().having(
              (scope) => scope.child,
              'child',
              isA<VideoEditorScreen>(),
            ),
          );
        });
      }
    });

    // A pasted link, a browser refresh or a restored session reaches a route
    // with no extra at all, so every route that reads one must still open its
    // screen from the URL alone (#3335).
    group('built from the URL alone', () {
      test('post analytics opens from the video id', () {
        expect(
          _build(
            _videoRouter(),
            const PostAnalyticsDetailRouteData(videoId: _hexId).location,
          ),
          isA<PostAnalyticsDetailScreen>()
              .having((screen) => screen.videoId, 'videoId', _hexId)
              .having((screen) => screen.performance, 'performance', isNull),
        );
      });

      test('a video opens from its id', () {
        expect(
          _build(
            _videoRouter(),
            const VideoDetailRouteData(id: _hexId).location,
          ),
          isA<VideoDetailScreen>()
              .having((screen) => screen.videoId, 'videoId', _hexId)
              .having((screen) => screen.initialVideo, 'initialVideo', isNull)
              .having(
                (screen) => screen.autoOpenComments,
                'autoOpenComments',
                isFalse,
              ),
        );
      });

      test('a video link that names its author holds the lookup to it', () {
        const author =
            'e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3';
        expect(
          _build(_videoRouter(), '/video/stable_id?author=$author'),
          isA<VideoDetailScreen>()
              .having((screen) => screen.videoId, 'videoId', 'stable_id')
              .having((screen) => screen.authorPubkey, 'authorPubkey', author),
        );
      });

      test('a sound loads from its id', () {
        expect(
          _build(
            _videoRouter(),
            const SoundDetailRouteData(id: _hexId).location,
          ),
          isA<SoundDetailLoader>().having(
            (loader) => loader.soundId,
            'soundId',
            _hexId,
          ),
        );
      });

      test('an original sound opens from the creator', () {
        expect(
          _build(
            _videoRouter(),
            const OriginalSoundDetailRouteData(pubkey: _authorHex).location,
          ),
          isA<OriginalSoundDetailScreen>()
              .having((screen) => screen.creatorPubkey, 'creator', _authorHex)
              .having((screen) => screen.sourceVideo, 'sourceVideo', isNull),
        );
      });

      test('the metadata editor opens from the video id', () {
        expect(
          _build(
            _videoRouter(),
            const VideoMetadataEditRouteData(videoId: _hexId).location,
          ),
          isA<VideoMetadataEditScreen>()
              .having((screen) => screen.videoId, 'videoId', _hexId)
              .having((screen) => screen.prefetched, 'prefetched', isNull),
        );
      });

      test('the subtitle editor opens from the video id', () {
        expect(
          _build(
            _videoRouter(),
            const SubtitleEditorRouteData(videoId: _hexId).location,
          ),
          isA<SubtitleEditorScreen>()
              .having((screen) => screen.videoId, 'videoId', _hexId)
              .having((screen) => screen.prefetched, 'prefetched', isNull),
        );
      });

      test('the fullscreen feed redirects to its video', () {
        expect(
          _redirect(
            _videoRouter(),
            const PooledFullscreenVideoFeedRouteData(video: _hexId).location,
          ),
          equals(VideoDetailScreen.pathForId(_hexId)),
        );
      });

      test('the fullscreen feed with no video redirects home', () {
        expect(
          _redirect(
            _videoRouter(),
            const PooledFullscreenVideoFeedRouteData().location,
          ),
          equals(VideoFeedPage.pathForIndex(0)),
        );
      });

      // The extra can vanish between the redirect and the build, so the
      // builder recovers the video too.
      test('the fullscreen feed builds its video', () {
        expect(
          _build(
            _videoRouter(),
            const PooledFullscreenVideoFeedRouteData(video: _hexId).location,
          ),
          isA<VideoDetailScreen>().having(
            (screen) => screen.videoId,
            'videoId',
            _hexId,
          ),
        );
      });
    });

    group('built with a warm extra', () {
      test('post analytics shows the performance it was handed', () {
        final performance = VideoPerformance.fromVideo(_video(_hexId));

        expect(
          _build(
            _videoRouter(),
            const PostAnalyticsDetailRouteData(videoId: _hexId).location,
            extra: performance,
          ),
          isA<PostAnalyticsDetailScreen>().having(
            (screen) => screen.performance,
            'performance',
            same(performance),
          ),
        );
      });

      test('a video reads its route extra', () {
        final video = _video(_hexId);

        expect(
          _build(
            _videoRouter(),
            const VideoDetailRouteData(id: _hexId).location,
            extra: VideoDetailRouteExtra(
              autoOpenComments: true,
              fallbackVideoIds: const ['fallback'],
              initialVideo: video,
              focusCommentId: 'comment',
            ),
          ),
          isA<VideoDetailScreen>()
              .having((screen) => screen.autoOpenComments, 'comments', isTrue)
              .having(
                (screen) => screen.fallbackVideoIds,
                'fallbackVideoIds',
                ['fallback'],
              )
              .having((screen) => screen.initialVideo, 'video', same(video))
              .having(
                (screen) => screen.focusCommentId,
                'focusCommentId',
                'comment',
              ),
        );
      });

      test('a video ignores a restored map', () {
        expect(
          _build(
            _videoRouter(),
            const VideoDetailRouteData(id: _hexId).location,
            extra: const {'autoOpenComments': true},
          ),
          isA<VideoDetailScreen>().having(
            (screen) => screen.autoOpenComments,
            'autoOpenComments',
            isFalse,
          ),
        );
      });

      test('a sound opens the audio it was handed', () {
        final sound = AudioEvent(id: _hexId, pubkey: _authorHex, createdAt: 1);

        expect(
          _build(
            _videoRouter(),
            const SoundDetailRouteData(id: _hexId).location,
            extra: sound,
          ),
          isA<SoundDetailScreen>()
              .having((screen) => screen.sound, 'sound', same(sound))
              .having((screen) => screen.sourceVideo, 'sourceVideo', isNull),
        );
      });

      test('an original sound reads the audio and its source video', () {
        final sound = AudioEvent(id: _hexId, pubkey: _authorHex, createdAt: 1);
        final video = _video(_hexId);

        expect(
          _build(
            _videoRouter(),
            const SoundDetailRouteData(id: _hexId).location,
            extra: {'sound': sound, 'sourceVideo': video},
          ),
          isA<SoundDetailScreen>()
              .having((screen) => screen.sound, 'sound', same(sound))
              .having((screen) => screen.sourceVideo, 'video', same(video)),
        );
      });

      test('an original-sound creator shows the video it was handed', () {
        final video = _video(_hexId);

        expect(
          _build(
            _videoRouter(),
            const OriginalSoundDetailRouteData(pubkey: _authorHex).location,
            extra: video,
          ),
          isA<OriginalSoundDetailScreen>().having(
            (screen) => screen.sourceVideo,
            'sourceVideo',
            same(video),
          ),
        );
      });

      test('the metadata editor starts from the video it was handed', () {
        final video = _video(_hexId);

        expect(
          _build(
            _videoRouter(),
            const VideoMetadataEditRouteData(videoId: _hexId).location,
            extra: video,
          ),
          isA<VideoMetadataEditScreen>().having(
            (screen) => screen.prefetched,
            'prefetched',
            same(video),
          ),
        );
      });

      test('the subtitle editor starts from the video it was handed', () {
        final video = _video(_hexId);

        expect(
          _build(
            _videoRouter(),
            const SubtitleEditorRouteData(videoId: _hexId).location,
            extra: video,
          ),
          isA<SubtitleEditorScreen>().having(
            (screen) => screen.prefetched,
            'prefetched',
            same(video),
          ),
        );
      });

      test('the fullscreen feed opens a profile feed it was handed', () {
        const args = ProfilePooledFullscreenVideoFeedArgs(
          userIdHex: _authorHex,
          initialIndex: 2,
        );
        final router = _videoRouter();
        final location = const PooledFullscreenVideoFeedRouteData(
          video: _hexId,
        ).location;

        expect(_redirect(router, location, extra: args), isNull);
        expect(
          _build(router, location, extra: args),
          isA<ProfileVideoFeedView>()
              .having((view) => view.userIdHex, 'userIdHex', _authorHex)
              .having((view) => view.videoIndex, 'videoIndex', 2),
        );
      });
    });

    group('editor and metadata', () {
      test('the editor reads its origin from the URL', () {
        VideoEditorScreen editorAt(String location) =>
            (_build(
                  _videoRouter(),
                  location,
                ) as ReleaseCachedImagesOnDispose).child
                as VideoEditorScreen;

        expect(
          editorAt(const VideoEditorRouteData().location).fromLibrary,
          isFalse,
        );
        expect(
          editorAt(
            const VideoEditorRouteData(
              from: VideoEditorScreen.libraryOrigin,
            ).location,
          ).fromLibrary,
          isTrue,
        );

        final draft = editorAt(
          const VideoEditorDraftRouteData(
            draftId: _draftId,
            from: VideoEditorScreen.libraryOrigin,
          ).location,
        );
        expect(draft.draftId, equals(_draftId));
        expect(draft.fromLibrary, isTrue);
      });

      // The typed field is the single source of the origin: built against a
      // state whose URL disagrees with it, the editor still follows the field.
      test('the editor routes take their origin from the typed field', () {
        final router = _videoRouter();
        GoRouterState stateAt(String location) =>
            _resolve(router, location).state;
        VideoEditorScreen editorFor(GoRouteData route, GoRouterState state) =>
            (route.build(
                  _FakeBuildContext(),
                  state,
                ) as ReleaseCachedImagesOnDispose).child
                as VideoEditorScreen;
        final bare = stateAt(const VideoEditorRouteData().location);
        final fromLibrary = stateAt(
          const VideoEditorRouteData(
            from: VideoEditorScreen.libraryOrigin,
          ).location,
        );
        final bareDraft = stateAt(
          const VideoEditorDraftRouteData(draftId: _draftId).location,
        );
        final draftFromLibrary = stateAt(
          const VideoEditorDraftRouteData(
            draftId: _draftId,
            from: VideoEditorScreen.libraryOrigin,
          ).location,
        );

        expect(
          editorFor(
            const VideoEditorRouteData(from: VideoEditorScreen.libraryOrigin),
            bare,
          ).fromLibrary,
          isTrue,
        );
        expect(
          editorFor(const VideoEditorRouteData(), fromLibrary).fromLibrary,
          isFalse,
        );
        // Only the library origin counts, as `from=library` did in the URL.
        expect(
          editorFor(
            const VideoEditorRouteData(from: 'recorder'),
            fromLibrary,
          ).fromLibrary,
          isFalse,
        );
        expect(
          editorFor(
            const VideoEditorDraftRouteData(
              draftId: _draftId,
              from: VideoEditorScreen.libraryOrigin,
            ),
            bareDraft,
          ).fromLibrary,
          isTrue,
        );
        expect(
          editorFor(
            const VideoEditorDraftRouteData(draftId: _draftId),
            draftFromLibrary,
          ).fromLibrary,
          isFalse,
        );
      });

      test('the metadata screen reads the draft mode from the URL', () {
        VideoMetadataScreen metadataAt(String location) =>
            _build(_videoRouter(), location) as VideoMetadataScreen;

        expect(
          metadataAt(const VideoMetadataRouteData().location).draftMode,
          isNull,
        );
        expect(
          metadataAt(
            VideoMetadataRouteData(
              mode: VideoRecorderMode.stopMotion.name,
            ).location,
          ).draftMode,
          equals(VideoRecorderMode.stopMotion),
        );
      });
    });

    group('engagement lists', () {
      // The path segment shares the detail route's identifier space, so a
      // shared link can carry a hex id, a NIP-19 reference or a coordinate.
      // The first-party API 404s on bech32, so the route decodes it.
      VideoEngagementListScreen build(String location) =>
          _build(_videoRouter(), location) as VideoEngagementListScreen;

      test('pass a hex event id straight through', () {
        final screen = build(
          const VideoLikersRouteData(eventId: _hexId).location,
        );

        expect(screen.eventId, equals(_hexId));
        expect(screen.addressableId, isNull);
        expect(screen.type, equals(VideoEngagementType.likers));
      });

      test('decode an nevent1 link to its hex event id', () {
        // Undecoded, this reached the API as bech32, which 404s — so the list
        // rendered empty for a video that has likers.
        expect(
          build(const VideoLikersRouteData(eventId: _nevent).location).eventId,
          equals(_hexId),
        );
      });

      test('resolve an naddr1 link to its d tag and coordinate', () {
        final screen = build(
          const VideoLikersRouteData(eventId: _naddr).location,
        );

        expect(screen.eventId, equals(_dTag));
        expect(screen.addressableId, equals(_coordinate));
      });

      test('resolve a raw coordinate the same way', () {
        final screen = build(
          const VideoLikersRouteData(eventId: _coordinate).location,
        );

        expect(screen.eventId, equals(_dTag));
        expect(screen.addressableId, equals(_coordinate));
      });

      test('keep an explicit ?a= over the decoded coordinate', () {
        const explicit = '34236:$_authorHex:other';

        expect(
          build(
            const VideoLikersRouteData(eventId: _naddr, a: explicit).location,
          ).addressableId,
          equals(explicit),
        );
      });

      test('ignore an empty ?a= and keep the decoded coordinate', () {
        // '' is not null, so `??` kept it: the naddr's own coordinate was
        // dropped and the reposters query fell back to an `#e` filter on a d
        // tag, which cannot match.
        final bare = const VideoLikersRouteData(eventId: _naddr).location;

        expect(
          build(
            const VideoLikersRouteData(eventId: _naddr, a: '').location,
          ).addressableId,
          equals(_coordinate),
        );
        expect(build('$bare?a').addressableId, equals(_coordinate));
      });

      test('forward ?a= for a plain hex link', () {
        expect(
          build(
            const VideoLikersRouteData(
              eventId: _hexId,
              a: _coordinate,
            ).location,
          ).addressableId,
          equals(_coordinate),
        );
      });

      test('build the reposters list for that type', () {
        final screen = build(
          const VideoRepostersRouteData(
            eventId: _nevent,
            a: _coordinate,
          ).location,
        );

        expect(screen.type, equals(VideoEngagementType.reposters));
        expect(screen.eventId, equals(_hexId));
        expect(screen.addressableId, equals(_coordinate));
      });

      group('reject an id they cannot decode', () {
        // RouteErrorScreen reads context.l10n, so these need a real localized
        // context rather than a fake one.
        Future<Widget> buildFor(WidgetTester tester, String eventId) async {
          late BuildContext captured;
          await tester.pumpWidget(
            buildLocalizedWidget(
              Builder(
                builder: (context) {
                  captured = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
          return _build(
            _videoRouter(),
            VideoLikersRouteData(eventId: eventId).location,
            context: captured,
          );
        }

        testWidgets('a whitespace-only segment', (tester) async {
          // `raw.isEmpty` let this through and the API was asked for
          // /api/videos/%20%20%20/likers, which answers nothing.
          expect(await buildFor(tester, '   '), isA<RouteErrorScreen>());
        });

        testWidgets('an nevent1 that does not decode', (tester) async {
          // A truncated or mistyped shared link. Forwarded raw, it 404s at the
          // API and misses at the relay, and the list renders empty.
          expect(
            await buildFor(tester, 'nevent1qvqsqxvr2tz'),
            isA<RouteErrorScreen>(),
          );
        });

        testWidgets('an naddr1 for a kind that is not a video', (tester) async {
          expect(
            await buildFor(
              tester,
              'naddr1qq9kjup3v3jrjazpd3khwq3qsxktkuz8tw9hzhpc6pevaymknj3827parpu'
              'eqyt7crqpa2zfh72sxpqqqp65wdhulxv',
            ),
            isA<RouteErrorScreen>(),
          );
        });
      });
    });

    group('the detail location an engagement screen falls back to', () {
      test('survives the round trip to the detail route', () {
        // The cold-entry back fallback builds its location from a coordinate
        // or a bare d tag, both arbitrary UTF-8 decoded from an untrusted
        // naddr1.
        const coordinate = '34236:$_authorHex:a?b/c#d';
        final location = const VideoDetailRouteData(id: coordinate).location;

        // Raw, the `?` ended the path at `…:a` and carried `b/c` into the
        // query and `d` into the fragment, so the location named a different
        // video before it ever reached the router.
        expect(Uri.parse(location).pathSegments, equals(['video', coordinate]));

        final screen = _build(_videoRouter(), location) as VideoDetailScreen;
        expect(screen.videoId, equals(coordinate));

        final aid = AId.fromString(screen.videoId);
        expect(aid, isNotNull);
        expect(aid!.kind, equals(34236));
        expect(aid.dTag, equals('a?b/c#d'));
      });
    });

    group('a sound link', () {
      test('survives the round trip to the sound route', () {
        const soundId = 'a?b/c#d';
        final location = RoutePaths.soundDetailForId(soundId);

        // Raw, the `?` ended the path at `a`, so the link named a different
        // sound before it ever reached the router.
        expect(Uri.parse(location).pathSegments, equals(['sound', soundId]));
        expect(
          _build(_videoRouter(), location),
          isA<SoundDetailLoader>().having(
            (loader) => loader.soundId,
            'soundId',
            soundId,
          ),
        );
      });
    });
  });
}
