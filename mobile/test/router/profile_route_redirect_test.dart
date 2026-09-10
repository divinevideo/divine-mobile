// ABOUTME: Guards that visiting another user's profile grid redirects to the
// ABOUTME: fullscreen viewer, which always carries Report/Block (#9013).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

/// Feed mode (ProfileVideoFeedView -> PooledFullscreenVideoFeedScreen) reads
/// a [VideoVolumeCubit] from the tree; this stands in for the real system
/// volume channel (mirrors profile_screen_router_test.dart).
class _FakeSystemVolumeListener implements SystemVolumeListener {
  @override
  void hideSystemUI() {}

  @override
  StreamSubscription<double> listen(void Function(double volume) onData) {
    return const Stream<double>.empty().listen(onData);
  }
}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {
  @override
  bool isBlocked(String pubkey) => false;

  @override
  bool canUnblock(String pubkey) => false;
}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

/// Feeds [routerLocationStreamProvider] from a test-owned [GoRouter] instead
/// of the app-wide `goRouterProvider`, mirroring the real provider's own
/// sync-buffered-controller implementation
/// (`lib/router/providers/router_location_provider.dart`) so the first
/// location is delivered whenever `pageContextProvider` subscribes, and every
/// later push/pop/replace is delivered too.
Stream<String> _locationStream(GoRouter router) {
  final controller = StreamController<String>(sync: true);
  void emit() {
    if (!controller.isClosed) {
      controller.add(router.routeInformationProvider.value.uri.toString());
    }
  }

  emit();
  router.routerDelegate.addListener(emit);
  return controller.stream;
}

void main() {
  const meHex = syntheticTestPubkey;
  final meNpub = NostrKeyUtils.encodePubKey(meHex);
  const otherHex = syntheticOtherTestPubkey;
  final otherNpub = NostrKeyUtils.encodePubKey(otherHex);

  late _MockVideosRepository videosRepository;
  late _MockVideoEventService videoEventService;
  late _MockContentBlocklistRepository blocklistRepository;
  late _MockProfileRepository profileRepository;
  late _MockIdentityClaimsRepository identityClaimsRepository;
  late _MockLikesRepository likesRepository;
  late _MockRepostsRepository repostsRepository;
  late _MockCommentsRepository commentsRepository;

  UserProfile profileFor(String pubkey) => UserProfile(
    pubkey: pubkey,
    displayName: 'User $pubkey',
    rawData: const {},
    createdAt: DateTime(2026),
    eventId: 'e' * 64,
  );

  VideoEvent videoFor(String id, String pubkey) => VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 1700000000,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  );

  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(const <List<String>>[]);
    registerFallbackValue(const <IdentityClaim>[]);
  });

  void arrangeProfileDependencies({bool emptyAuthorFeed = false}) {
    videosRepository = _MockVideosRepository();
    videoEventService = _MockVideoEventService();
    blocklistRepository = _MockContentBlocklistRepository();
    profileRepository = _MockProfileRepository();
    identityClaimsRepository = _MockIdentityClaimsRepository();
    likesRepository = _MockLikesRepository();
    repostsRepository = _MockRepostsRepository();
    commentsRepository = _MockCommentsRepository();

    // Every author's feed carries one video by default, so a feed-mode URL
    // (own or other's) has something for ProfileVideoFeedView to show. The
    // zero-video regression test below re-stubs this to an empty list to
    // exercise ProfileViewSwitcher's grid fallback.
    when(
      () => videosRepository.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenAnswer((invocation) async {
      final pubkey = invocation.namedArguments[#authorPubkey] as String;
      return AuthorFeedResult(
        authorPubkey: pubkey,
        videos: emptyAuthorFeed
            ? const []
            : [videoFor('$pubkey-video-0', pubkey)],
        hasMore: false,
      );
    });
    when(
      () => videosRepository.removedVideoIds,
    ).thenAnswer((_) => const Stream<String>.empty());

    when(
      () => videoEventService.authorVideos(any()),
    ).thenReturn(const <VideoEvent>[]);
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    when(() => videoEventService.shouldHideVideo(any())).thenReturn(false);
    when(
      () => videoEventService.isVideoEventKnownDeleted(any()),
    ).thenReturn(false);
    when(
      () => videoEventService.isVideoEventLocallyDeleted(any()),
    ).thenReturn(false);
    when(
      () => videoEventService.subscribeToUserVideos(any()),
    ).thenAnswer((_) async {});
    when(() => videoEventService.addListener(any())).thenReturn(null);
    when(() => videoEventService.removeListener(any())).thenReturn(null);
    when(
      () => videoEventService.addVideoUpdateListener(any()),
    ).thenReturn(() {});
    when(
      () => videoEventService.removedVideoIds,
    ).thenAnswer((_) => const Stream<String>.empty());

    when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);
    when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);
    when(
      () => blocklistRepository.shouldFilterFromFeeds(any()),
    ).thenReturn(false);
    when(
      () => blocklistRepository.currentState,
    ).thenReturn(ContentPolicyState.empty());
    when(
      () => blocklistRepository.stateStream,
    ).thenAnswer((_) => const Stream<ContentPolicyState>.empty());

    when(() => profileRepository.isVanished(any())).thenReturn(false);
    when(
      () => profileRepository.getCachedProfile(pubkey: any(named: 'pubkey')),
    ).thenAnswer((_) async => null);
    when(
      () => profileRepository.watchProfile(pubkey: any(named: 'pubkey')),
    ).thenAnswer((_) => const Stream<UserProfile?>.empty());
    when(
      () => profileRepository.watchProfileStats(pubkey: any(named: 'pubkey')),
    ).thenAnswer((_) => const Stream<ProfileStats?>.empty());
    when(
      () => profileRepository.fetchFreshProfile(pubkey: any(named: 'pubkey')),
    ).thenAnswer(
      (invocation) async =>
          profileFor(invocation.namedArguments[#pubkey] as String),
    );
    when(
      () => profileRepository.cachedIdentityTags(any()),
    ).thenAnswer((_) async => null);
    when(
      () => profileRepository.freshIdentityTags(
        pubkey: any(named: 'pubkey'),
        kind0Tags: any(named: 'kind0Tags'),
      ),
    ).thenAnswer((_) async => const <List<String>>[]);

    when(
      () => identityClaimsRepository.cachedVerifiedClaims(
        pubkey: any(named: 'pubkey'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => identityClaimsRepository.resolveClaims(
        pubkey: any(named: 'pubkey'),
        freshTags: any(named: 'freshTags'),
        cached: any(named: 'cached'),
        renderedClaims: any(named: 'renderedClaims'),
      ),
    ).thenAnswer((_) async => const <IdentityClaim>[]);

    when(
      likesRepository.watchLikedEventIds,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      repostsRepository.watchRepostedAddressableIds,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
  }

  List<Override> profileOverrides() => [
    videosRepositoryProvider.overrideWithValue(videosRepository),
    videoEventServiceProvider.overrideWithValue(videoEventService),
    contentBlocklistRepositoryProvider.overrideWithValue(blocklistRepository),
    identityClaimsRepositoryProvider.overrideWithValue(
      identityClaimsRepository,
    ),
    likesRepositoryProvider.overrideWithValue(likesRepository),
    repostsRepositoryProvider.overrideWithValue(repostsRepository),
    commentsRepositoryProvider.overrideWithValue(commentsRepository),
    isDmRestrictedProvider.overrideWith((ref) => false),
    isFeatureEnabledProvider(
      FeatureFlag.videoReplies,
    ).overrideWith((ref) => false),
    isFeatureEnabledProvider(
      FeatureFlag.profileMonetizationLinks,
    ).overrideWith((ref) => false),
    isFeatureEnabledProvider(
      FeatureFlag.curatedLists,
    ).overrideWith((ref) => false),
    isFeatureEnabledProvider(
      FeatureFlag.profileListFeatures,
    ).overrideWith((ref) => false),
  ];

  /// The routes every scenario below needs: the two shapes of the in-shell
  /// profile route (grid + feed mode), the off-shell fullscreen viewer the
  /// redirect targets, and a feed stand-in as the back-navigation landing
  /// spot (mirrors the `Scaffold(body: Text('feed'))` stand-in already used
  /// for the same purpose in profile_screen_router_test.dart).
  GoRouter buildRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    redirect: (_, state) => profileOwnerRedirectTarget(
      location: state.matchedLocation,
      currentPublicKeyHex: meHex,
    ),
    routes: [
      GoRoute(
        path: VideoFeedPage.pathForIndex(0),
        builder: (_, _) => const Scaffold(body: Text('feed')),
      ),
      GoRoute(
        path: ProfileScreenRouter.pathWithIndex,
        builder: (_, _) => const ProfileScreenRouter(),
      ),
      GoRoute(
        path: ProfileScreenRouter.pathWithNpub,
        builder: (_, _) => const ProfileScreenRouter(),
      ),
      GoRoute(
        path: OtherProfileScreen.pathWithNpub,
        // Mirrors profile_routes.dart's real wiring: the off-shell fullscreen
        // route resolves through OtherProfileScreenRouter, not
        // OtherProfileScreen directly, so its own own-profile/blocklist
        // guards are exercised too.
        builder: (_, state) =>
            OtherProfileScreenRouter(npub: state.pathParameters['npub']!),
      ),
    ],
  );

  GoRouter buildShellRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    redirect: (_, state) => profileOwnerRedirectTarget(
      location: state.matchedLocation,
      currentPublicKeyHex: meHex,
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => navigationShell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: VideoFeedPage.pathForIndex(0),
                builder: (_, _) => const Scaffold(body: Text('feed')),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: ProfileScreenRouter.path,
            routes: [
              GoRoute(
                path: ProfileScreenRouter.path,
                builder: (_, _) => const ProfileScreenRouter(),
              ),
              GoRoute(
                path: ProfileScreenRouter.pathWithNpub,
                builder: (_, _) => const ProfileScreenRouter(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: OtherProfileScreen.pathWithNpub,
        builder: (_, state) =>
            OtherProfileScreenRouter(npub: state.pathParameters['npub']!),
      ),
    ],
  );

  /// Pumps [router] (already at its initial location) with every provider
  /// this suite's screens need to build cleanly, and settles it with bounded
  /// pumps (never `pumpAndSettle`: `ProfileFeedCubit` owns a hard-timeout
  /// [Timer] that only some states cancel, so an unbounded settle can hang).
  Future<void> pumpRouter(
    WidgetTester tester,
    GoRouter router, {
    bool emptyAuthorFeed = false,
  }) async {
    arrangeProfileDependencies(emptyAuthorFeed: emptyAuthorFeed);
    addTearDown(router.dispose);

    final nostrClient = createMockNostrService();
    when(() => nostrClient.publicKey).thenReturn(meHex);

    final authService = createMockAuthService(
      authState: AuthState.authenticated,
      currentPublicKeyHex: meHex,
    );
    // ProfileHeaderWidget and OtherProfileView's messaging gate read these;
    // createMockAuthService() does not stub them (mirrors
    // other_profile_screen_test.dart's setUp).
    when(() => authService.isAnonymous).thenReturn(false);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    when(() => authService.isRpcUpgradeInProgress).thenReturn(false);

    final backgroundPublishBloc = _MockBackgroundPublishBloc();
    whenListen(
      backgroundPublishBloc,
      const Stream<BackgroundPublishState>.empty(),
      initialState: const BackgroundPublishState(),
    );
    final peopleListsBloc = _MockPeopleListsBloc();
    whenListen(
      peopleListsBloc,
      const Stream<PeopleListsState>.empty(),
      initialState: const PeopleListsState(),
    );

    await tester.pumpWidget(
      testProviderScope(
        mockAuthService: authService,
        mockNostrService: nostrClient,
        mockProfileRepository: profileRepository,
        additionalOverrides: [
          ...profileOverrides(),
          routerLocationStreamProvider.overrideWithValue(
            _locationStream(router),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => MultiBlocProvider(
            providers: [
              BlocProvider<BackgroundPublishBloc>.value(
                value: backgroundPublishBloc,
              ),
              BlocProvider<PeopleListsBloc>.value(value: peopleListsBloc),
              BlocProvider<VideoVolumeCubit>(
                create: (_) => VideoVolumeCubit(
                  sharedPreferences: createMockSharedPreferences(),
                  systemVolumeListener: _FakeSystemVolumeListener(),
                ),
              ),
            ],
            // The app shell supplies the Scaffold for in-shell profile
            // routes; this stand-in does the same (mirrors
            // profile_screen_router_test.dart's harness).
            child: Scaffold(body: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  group(
    'Other-user profile grid redirects to the fullscreen viewer (#9013)',
    () {
      test('both profile wrappers use one resolved identity', () {
        expect(
          profileOwnerRedirectTarget(
            location: ProfileScreenRouter.pathForNpub(otherNpub),
            currentPublicKeyHex: meHex,
          ),
          OtherProfileScreen.pathForNpub(otherNpub),
        );
        expect(
          profileOwnerRedirectTarget(
            location: OtherProfileScreen.pathForNpub(meNpub),
            currentPublicKeyHex: meHex,
          ),
          ProfileScreenRouter.pathForNpub(meNpub),
        );
        expect(
          profileOwnerRedirectTarget(
            location: ProfileScreenRouter.pathForNpub(otherNpub),
            currentPublicKeyHex: null,
          ),
          isNull,
        );
        expect(
          profileOwnerRedirectTarget(
            location: ProfileScreenRouter.pathForNpub('invalid'),
            currentPublicKeyHex: meHex,
          ),
          isNull,
        );
      });

      testWidgets(
        'other-user grid visit lands on the fullscreen viewer',
        (tester) async {
          await pumpRouter(
            tester,
            buildRouter(ProfileScreenRouter.pathForNpub(otherNpub)),
          );

          expect(find.byType(OtherProfileView), findsOneWidget);
          expect(find.byType(ProfileViewSwitcher), findsNothing);
        },
      );

      testWidgets('own grid visit stays on the tab wrapper', (tester) async {
        await pumpRouter(
          tester,
          buildRouter(ProfileScreenRouter.pathForNpub(meNpub)),
        );

        expect(find.byType(ProfileViewSwitcher), findsOneWidget);
        expect(find.byType(OtherProfileView), findsNothing);
      });

      testWidgets('own feed visit stays on the tab wrapper', (tester) async {
        await pumpRouter(
          tester,
          buildRouter(ProfileScreenRouter.pathForIndex(meNpub, 0)),
        );

        expect(find.byType(ProfileVideoFeedView), findsOneWidget);
        expect(find.byType(OtherProfileView), findsNothing);
      });

      testWidgets(
        'other-user feed visit also redirects to the fullscreen viewer',
        (tester) async {
          await pumpRouter(
            tester,
            buildRouter(ProfileScreenRouter.pathForIndex(otherNpub, 0)),
          );

          expect(find.byType(OtherProfileView), findsOneWidget);
          expect(find.byType(ProfileVideoFeedView), findsNothing);
          expect(find.byType(ProfileViewSwitcher), findsNothing);
        },
      );

      testWidgets(
        'other-user feed visit with zero videos redirects instead of '
        'falling back to the grid (#9013 regression)',
        (tester) async {
          // The bug this pins: ProfileViewSwitcher only shows
          // ProfileVideoFeedView when videoIndex != null AND videos is
          // non-empty; otherwise it falls back to ProfileGridView. A
          // grid-mode-only redirect guard missed this fallback, so a feed
          await pumpRouter(
            tester,
            buildRouter(ProfileScreenRouter.pathForIndex(otherNpub, 0)),
            emptyAuthorFeed: true,
          );

          expect(find.byType(OtherProfileView), findsOneWidget);
          // Not ProfileViewSwitcher: that widget is exclusively the
          // tab-wrapper's render path (own-profile-menu territory), so its
          // absence proves this landed on the fullscreen viewer instead of
          // leaking through the grid-fallback bug. OtherProfileView renders
          // its own ProfileGridView (with the real Report/Block menu via
          // isOwnProfile: false) — a different instance of the same widget
          // type, present here to confirm the zero-video cold-render
          // actually completed rather than erroring out.
          expect(find.byType(ProfileViewSwitcher), findsNothing);
          expect(find.byType(ProfileGridView), findsOneWidget);
        },
      );

      testWidgets(
        'cold shell visit has a working back button after redirect',
        (tester) async {
          final router = buildShellRouter(
            ProfileScreenRouter.pathForNpub(otherNpub),
          );
          await pumpRouter(tester, router);

          expect(find.byType(OtherProfileView), findsOneWidget);
          expect(router.canPop(), isFalse);

          await tester.tap(find.bySemanticsLabel('Back'));
          await tester.pump();
          await tester.pump();

          expect(find.text('feed'), findsOneWidget);
        },
      );

      testWidgets(
        'system back after the redirect returns to the feed, not a dead end',
        (tester) async {
          final router = buildRouter(VideoFeedPage.pathForIndex(0));
          await pumpRouter(tester, router);

          expect(find.text('feed'), findsOneWidget);

          // Deep-link-style push onto the other user's profile grid.
          unawaited(router.push(ProfileScreenRouter.pathForNpub(otherNpub)));
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.byType(OtherProfileView), findsOneWidget);

          router.pop();
          await tester.pump();
          await tester.pump();
          // The popped page's Navigator transition animation keeps it mounted
          // for its duration; settle it before asserting it is gone.
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(OtherProfileView), findsNothing);
          expect(find.text('feed'), findsOneWidget);
        },
      );
    },
  );
}
