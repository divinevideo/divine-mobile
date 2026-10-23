import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/apps_routes.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/router/routes/settings_routes.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/router/widgets/followers_screen_router.dart';
import 'package:openvine/router/widgets/following_screen_router.dart';
import 'package:openvine/router/widgets/other_profile_screen_router.dart';
import 'package:openvine/router/widgets/sound_detail_loader.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/release_cached_images_on_dispose.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required this.pathParameters,
    this.extra,
    String location = '/',
  }) : uri = Uri.parse(location),
       matchedLocation = location,
       fullPath = location,
       pageKey = ValueKey<String>(location);

  @override
  final Object? extra;

  @override
  final String? fullPath;

  @override
  final String matchedLocation;

  @override
  final Map<String, String> pathParameters;

  @override
  final ValueKey<String> pageKey;

  @override
  final Uri uri;
}

void main() {
  group('restored route extras', () {
    testWidgets('profile route accepts restored object maps', (tester) async {
      final route = _routeNamed(profileRoutes(), OtherProfileScreen.routeName);
      late OtherProfileScreenRouter screen;

      await _buildWithContext(tester, (context) {
        screen = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/profile/npub1test',
            pathParameters: const {'npub': 'npub1test'},
            extra: const <Object?, Object?>{
              'displayName': 'Ada',
              'avatarUrl': 42,
            },
          ),
        ) as OtherProfileScreenRouter;
      });

      expect(screen.npub, 'npub1test');
      expect(screen.displayNameHint, 'Ada');
      expect(screen.avatarUrlHint, isNull);
    });

    testWidgets('sound route accepts restored object maps', (tester) async {
      final sound = AudioEvent(
        id: 'sound-1',
        pubkey: 'pubkey',
        createdAt: 1700000000,
      );
      final route = _routeNamed(videoRoutes(), SoundDetailScreen.routeName);
      late SoundDetailScreen screen;

      await _buildWithContext(tester, (context) {
        screen = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/sound/sound-1',
            pathParameters: const {'id': 'sound-1'},
            extra: <Object?, Object?>{'sound': sound},
          ),
        ) as SoundDetailScreen;
      });

      expect(screen.sound, same(sound));
    });

    testWidgets('sound route falls back when extra is missing or decoded', (
      tester,
    ) async {
      final route = _routeNamed(videoRoutes(), SoundDetailScreen.routeName);
      late Widget missingExtra;
      late Widget decodedExtra;

      await _buildWithContext(tester, (context) {
        missingExtra = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/sound/sound-1',
            pathParameters: const {'id': 'sound-1'},
          ),
        );
        decodedExtra = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/sound/sound-1',
            pathParameters: const {'id': 'sound-1'},
            extra: const <Object?, Object?>{
              'sound': <Object?, Object?>{'id': 'sound-1'},
            },
          ),
        );
      });

      expect(missingExtra, isA<SoundDetailLoader>());
      expect(decodedExtra, isA<SoundDetailLoader>());
    });

    testWidgets('video editor routes read the origin from the URL, not extra', (
      tester,
    ) async {
      final routes = videoRoutes();
      final editorRoute = _routeNamed(routes, VideoEditorScreen.routeName);
      final draftRoute = _routeNamed(routes, VideoEditorScreen.draftRouteName);
      late VideoEditorScreen fromLibrary;
      late VideoEditorScreen fromRecorder;
      late VideoEditorScreen legacyExtra;
      late VideoEditorScreen draft;

      await _buildWithContext(tester, (context) {
        fromLibrary = editorRoute
            .builder!(
              context,
              _FakeGoRouterState(
                location: VideoEditorScreen.pathFor(fromLibrary: true),
                pathParameters: const {},
              ),
            )
            .editorScreen;
        fromRecorder = editorRoute
            .builder!(
              context,
              _FakeGoRouterState(
                location: VideoEditorScreen.pathFor(),
                pathParameters: const {},
              ),
            )
            .editorScreen;
        // The map extra this route used to read is no longer consulted, so a
        // restored session cannot resurrect a half-migrated origin (#3335).
        legacyExtra = editorRoute
            .builder!(
              context,
              _FakeGoRouterState(
                location: VideoEditorScreen.path,
                pathParameters: const {},
                extra: const <Object?, Object?>{'fromLibrary': true},
              ),
            )
            .editorScreen;
        draft = draftRoute
            .builder!(
              context,
              _FakeGoRouterState(
                location: VideoEditorScreen.pathFor(
                  draftId: 'draft-1',
                  fromLibrary: true,
                ),
                pathParameters: const {'draftId': 'draft-1'},
              ),
            )
            .editorScreen;
      });

      expect(fromLibrary.fromLibrary, isTrue);
      expect(fromRecorder.fromLibrary, isFalse);
      expect(legacyExtra.fromLibrary, isFalse);
      expect(draft.draftId, 'draft-1');
      expect(draft.fromLibrary, isTrue);
    });

    test('video editor locations round-trip the origin through the URL', () {
      expect(VideoEditorScreen.pathFor(), VideoEditorScreen.path);
      expect(
        VideoEditorScreen.pathFor(fromLibrary: true),
        '${VideoEditorScreen.path}?from=library',
      );
      expect(
        VideoEditorScreen.pathFor(draftId: 'draft-1', fromLibrary: true),
        '${VideoEditorScreen.path}/draft-1?from=library',
      );
      expect(
        VideoEditorScreen.fromLibraryForRoute(
          Uri.parse(VideoEditorScreen.pathFor(fromLibrary: true)),
        ),
        isTrue,
      );
    });

    testWidgets('video metadata route restores draft recorder modes', (
      tester,
    ) async {
      final route = _routeNamed(videoRoutes(), VideoMetadataScreen.routeName);
      late VideoMetadataScreen capture;
      late VideoMetadataScreen stopMotion;
      late VideoMetadataScreen unsupported;

      await _buildWithContext(tester, (context) {
        capture = route.builder!(
          context,
          _FakeGoRouterState(
            location: VideoMetadataScreen.pathForDraft(
              isStopMotion: false,
            ),
            pathParameters: const {},
          ),
        ) as VideoMetadataScreen;
        stopMotion = route.builder!(
          context,
          _FakeGoRouterState(
            location: VideoMetadataScreen.pathForDraft(
              isStopMotion: true,
            ),
            pathParameters: const {},
          ),
        ) as VideoMetadataScreen;
        unsupported = route.builder!(
          context,
          _FakeGoRouterState(
            location: '${VideoMetadataScreen.path}?mode=upload',
            pathParameters: const {},
          ),
        ) as VideoMetadataScreen;
      });

      expect(capture.draftMode, VideoRecorderMode.capture);
      expect(stopMotion.draftMode, VideoRecorderMode.stopMotion);
      expect(unsupported.draftMode, isNull);
    });

    testWidgets('video edit routes tolerate decoded maps and no extra', (
      tester,
    ) async {
      final routes = videoRoutes();
      final metadataRoute = _routeNamed(
        routes,
        VideoMetadataEditScreen.routeName,
      );
      final subtitleRoute = _routeNamed(routes, SubtitleEditorScreen.routeName);
      late VideoMetadataEditScreen metadata;
      late SubtitleEditorScreen subtitle;
      late VideoMetadataEditScreen metadataNoExtra;
      late SubtitleEditorScreen subtitleNoExtra;

      await _buildWithContext(tester, (context) {
        metadata = metadataRoute.builder!(
          context,
          _FakeGoRouterState(
            location: '/video-edit/video-1',
            pathParameters: const {'videoId': 'video-1'},
            extra: const <Object?, Object?>{'id': 'video-1'},
          ),
        ) as VideoMetadataEditScreen;
        subtitle = subtitleRoute.builder!(
          context,
          _FakeGoRouterState(
            location: '/subtitle-edit/video-1',
            pathParameters: const {'videoId': 'video-1'},
            extra: const <Object?, Object?>{'id': 'video-1'},
          ),
        ) as SubtitleEditorScreen;
        metadataNoExtra = metadataRoute.builder!(
          context,
          _FakeGoRouterState(
            location: '/video-edit/video-1',
            pathParameters: const {'videoId': 'video-1'},
          ),
        ) as VideoMetadataEditScreen;
        subtitleNoExtra = subtitleRoute.builder!(
          context,
          _FakeGoRouterState(
            location: '/subtitle-edit/video-1',
            pathParameters: const {'videoId': 'video-1'},
          ),
        ) as SubtitleEditorScreen;
      });

      expect(metadata.videoId, 'video-1');
      expect(metadata.prefetched, isNull);
      expect(subtitle.videoId, 'video-1');
      expect(subtitle.prefetched, isNull);
      expect(metadataNoExtra.prefetched, isNull);
      expect(subtitleNoExtra.prefetched, isNull);
    });
  });

  // A pasted link, a browser refresh or a restored session reaches a route
  // with no extra at all, so every builder that reads extra must still open
  // its screen from the URL alone (#3335).
  group('routes entered by URL with no extra', () {
    const eventId =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const pubkeyHex =
        '2222222222222222222222222222222222222222222222222222222222222222';
    const conversationId =
        '3333333333333333333333333333333333333333333333333333333333333333';

    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    List<RouteBase> withRef(List<RouteBase> Function(Ref ref) routes) =>
        container.read(Provider<List<RouteBase>>(routes));

    Future<Widget> buildFromUrl(
      WidgetTester tester,
      List<RouteBase> routes,
      String name, {
      required String location,
      Map<String, String> pathParameters = const {},
    }) async {
      final route = _routeNamed(routes, name);
      late Widget screen;

      await _buildWithContext(tester, (context) {
        screen = route.builder!(
          context,
          _FakeGoRouterState(
            location: location,
            pathParameters: pathParameters,
          ),
        );
      });

      expect(
        screen,
        isNot(isA<RouteErrorScreen>()),
        reason: '$name must not dead-end when extra is absent',
      );
      return screen;
    }

    testWidgets('builds $AppDetailScreen from the slug alone', (tester) async {
      const slug = 'sample-app';
      final screen = await buildFromUrl(
        tester,
        withRef(appsRoutes),
        AppDetailScreen.routeName,
        location: AppDetailScreen.pathForSlug(slug),
        pathParameters: const {'slug': slug},
      );

      expect(
        screen,
        isA<AppDetailScreen>()
            .having((s) => s.slug, 'slug', slug)
            .having((s) => s.initialEntry, 'initialEntry', isNull),
      );
    });

    testWidgets('builds $ConversationPage from the id alone', (tester) async {
      final screen = await buildFromUrl(
        tester,
        messagingRoutes(),
        ConversationPage.routeName,
        location: ConversationPage.pathForId(conversationId),
        pathParameters: const {'id': conversationId},
      );

      expect(
        screen,
        isA<ConversationPage>()
            .having((s) => s.conversationId, 'conversationId', conversationId)
            .having((s) => s.participantPubkeys, 'participantPubkeys', isEmpty)
            .having((s) => s.subject, 'subject', isNull),
      );
    });

    testWidgets('builds $RequestPreviewPage from the id alone', (
      tester,
    ) async {
      final screen = await buildFromUrl(
        tester,
        messagingRoutes(),
        RequestPreviewPage.routeName,
        location: '${RoutePaths.messageRequests}/$conversationId',
        pathParameters: const {'id': conversationId},
      );

      expect(
        screen,
        isA<RequestPreviewPage>()
            .having((s) => s.conversationId, 'conversationId', conversationId)
            .having((s) => s.participantPubkeys, 'participantPubkeys', isEmpty)
            .having((s) => s.subject, 'subject', isNull),
      );
    });

    testWidgets('builds $CuratedListFeedScreen from the list id alone', (
      tester,
    ) async {
      const listId = 'weekend-picks';
      final screen = await buildFromUrl(
        tester,
        listsRoutes(),
        CuratedListFeedScreen.routeName,
        location: CuratedListFeedScreen.pathForId(listId),
        pathParameters: const {'listId': listId},
      );

      expect(
        screen,
        isA<CuratedListFeedScreen>()
            .having((s) => s.listId, 'listId', listId)
            .having(
              (s) => s.listName,
              'listName',
              lookupAppLocalizations(const Locale('en')).routeDefaultListName,
            )
            .having((s) => s.videoIds, 'videoIds', isNull)
            .having((s) => s.authorPubkey, 'authorPubkey', isNull),
      );
    });

    testWidgets('builds $VideoDetailScreen from the id alone', (tester) async {
      final screen = await buildFromUrl(
        tester,
        videoRoutes(),
        VideoDetailScreen.routeName,
        location: VideoDetailScreen.pathForId(eventId),
        pathParameters: const {'id': eventId},
      );

      expect(
        screen,
        isA<VideoDetailScreen>()
            .having((s) => s.videoId, 'videoId', eventId)
            .having((s) => s.initialVideo, 'initialVideo', isNull)
            .having((s) => s.autoOpenComments, 'autoOpenComments', isFalse)
            .having((s) => s.fallbackVideoIds, 'fallbackVideoIds', isEmpty)
            .having((s) => s.dmReplyContext, 'dmReplyContext', isNull),
      );
    });

    testWidgets('builds $OriginalSoundDetailScreen from the pubkey alone', (
      tester,
    ) async {
      final screen = await buildFromUrl(
        tester,
        videoRoutes(),
        OriginalSoundDetailScreen.routeName,
        location: OriginalSoundDetailScreen.pathForPubkey(pubkeyHex),
        pathParameters: const {'pubkey': pubkeyHex},
      );

      expect(
        screen,
        isA<OriginalSoundDetailScreen>()
            .having((s) => s.creatorPubkey, 'creatorPubkey', pubkeyHex)
            .having((s) => s.sourceVideo, 'sourceVideo', isNull),
      );
    });

    testWidgets('builds $PostAnalyticsDetailScreen from the video id alone', (
      tester,
    ) async {
      final screen = await buildFromUrl(
        tester,
        videoRoutes(),
        PostAnalyticsDetailScreen.routeName,
        location: PostAnalyticsDetailScreen.pathForId(eventId),
        pathParameters: const {'videoId': eventId},
      );

      expect(
        screen,
        isA<PostAnalyticsDetailScreen>()
            .having((s) => s.videoId, 'videoId', eventId)
            .having((s) => s.performance, 'performance', isNull),
      );
    });

    testWidgets('builds $OtherProfileScreenRouter from the npub alone', (
      tester,
    ) async {
      final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
      final screen = await buildFromUrl(
        tester,
        profileRoutes(),
        OtherProfileScreen.routeName,
        location: OtherProfileScreen.pathForNpub(npub),
        pathParameters: {'npub': npub},
      );

      expect(
        screen,
        isA<OtherProfileScreenRouter>()
            .having((s) => s.npub, 'npub', npub)
            .having((s) => s.displayNameHint, 'displayNameHint', isNull)
            .having((s) => s.avatarUrlHint, 'avatarUrlHint', isNull),
      );
    });

    testWidgets('builds $FollowersScreenRouter from the pubkey alone', (
      tester,
    ) async {
      final screen = await buildFromUrl(
        tester,
        profileRoutes(),
        FollowersScreenRouter.routeName,
        location: FollowersScreenRouter.pathForPubkey(pubkeyHex),
        pathParameters: const {'pubkey': pubkeyHex},
      );

      expect(
        screen,
        isA<FollowersScreenRouter>()
            .having((s) => s.pubkey, 'pubkey', pubkeyHex)
            .having((s) => s.displayName, 'displayName', isNull),
      );
    });

    testWidgets('builds $FollowingScreenRouter from the pubkey alone', (
      tester,
    ) async {
      final screen = await buildFromUrl(
        tester,
        profileRoutes(),
        FollowingScreenRouter.routeName,
        location: FollowingScreenRouter.pathForPubkey(pubkeyHex),
        pathParameters: const {'pubkey': pubkeyHex},
      );

      expect(
        screen,
        isA<FollowingScreenRouter>()
            .having((s) => s.pubkey, 'pubkey', pubkeyHex)
            .having((s) => s.displayName, 'displayName', isNull),
      );
    });

    testWidgets('builds $AccountStatusScreen without the publish hint', (
      tester,
    ) async {
      final screen = await buildFromUrl(
        tester,
        withRef(settingsRoutes),
        AccountStatusScreen.routeName,
        location: AccountStatusScreen.path,
      );

      expect(
        screen,
        isA<AccountStatusScreen>().having(
          (s) => s.publishRestrictionConfirmed,
          'publishRestrictionConfirmed',
          isFalse,
        ),
      );
    });

    testWidgets(
      'redirects $PooledFullscreenVideoFeedScreen to its video, else home',
      (tester) async {
        final route = _routeNamed(
          videoRoutes(),
          PooledFullscreenVideoFeedScreen.routeName,
        );
        late Object? withVideo;
        late Object? withoutVideo;

        await _buildWithContext(tester, (context) {
          withVideo = route.redirect!(
            context,
            _FakeGoRouterState(
              location: PooledFullscreenVideoFeedScreen.pathForVideoId(
                eventId,
              ),
              pathParameters: const {},
            ),
          );
          withoutVideo = route.redirect!(
            context,
            _FakeGoRouterState(
              location: PooledFullscreenVideoFeedScreen.path,
              pathParameters: const {},
            ),
          );
        });

        expect(withVideo, VideoDetailScreen.pathForId(eventId));
        expect(withoutVideo, VideoFeedPage.pathForIndex(0));
      },
    );
  });
}

Future<void> _buildWithContext(
  WidgetTester tester,
  void Function(BuildContext context) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

/// The route called [name], searched at every depth of [routes].
GoRoute _routeNamed(List<RouteBase> routes, String name) {
  Iterable<RouteBase> flatten(List<RouteBase> level) =>
      level.expand((route) => [route, ...flatten(route.routes)]);
  return flatten(
    routes,
  ).whereType<GoRoute>().singleWhere((route) => route.name == name);
}

extension on Widget {
  /// The editor a video editor route mounts inside its image-release scope.
  VideoEditorScreen get editorScreen =>
      (this as ReleaseCachedImagesOnDispose).child as VideoEditorScreen;
}
