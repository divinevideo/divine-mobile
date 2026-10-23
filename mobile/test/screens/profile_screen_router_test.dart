// ABOUTME: Tests for router-driven ProfileScreen implementation
// ABOUTME: Verifies URL ↔ playback synchronization for profile feeds

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {
  @override
  bool isBlocked(String pubkey) => false;

  @override
  bool canUnblock(String pubkey) => false;
}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockDivineVideoDraft extends Mock implements DivineVideoDraft {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _FakeSystemVolumeListener implements SystemVolumeListener {
  @override
  void hideSystemUI() {}

  @override
  StreamSubscription<double> listen(void Function(double volume) onData) {
    return const Stream<double>.empty().listen(onData);
  }
}

/// In-memory [CacheDao] so the [ProfileFeedCubit]'s [CacheSync] reads/writes
/// stay isolated per test under the merged `--optimization` isolate.
class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> _store = {};

  @override
  Future<CacheEntry?> readEntry(String key) async {
    final payload = _store[key];
    return payload == null
        ? null
        : CacheEntry(payload: payload, isStale: false);
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    _store[key] = payload;
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      _store.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      _store.values.fold<int>(0, (sum, v) => sum + v.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

const _npub = 'npub1424242424242424242424242424242424242424242424242424qamrcaj';

/// The hex [_npub] decodes to. The profile route carries the npub while the
/// feed carries hex, and [ProfileFeedCubit] drops live updates whose pubkey
/// does not match the profile's, so the two must describe one identity.
const _authorPubkeyHex =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// A second real identity, for the "not yours" case.
final String _otherNpub = NostrKeyUtils.encodePubKey(syntheticOtherTestPubkey);

void main() {
  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  VideoEvent video(String id) => VideoEvent(
    id: id,
    pubkey: _authorPubkeyHex,
    createdAt: nowUnix,
    content: 'Profile video $id',
    timestamp: now,
    title: id,
    videoUrl: 'https://example.com/$id.mp4',
  );

  final mockVideos = [
    video('profile-video-0'),
    video('profile-video-1'),
    video('profile-video-2'),
  ];

  group('profile routes', () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;
    late _MockBackgroundPublishBloc backgroundPublishBloc;
    late _MockPeopleListsBloc peopleListsBloc;
    late StreamController<BackgroundPublishState> backgroundPublishStates;

    setUpAll(() {
      registerFallbackValue(_FakeVideoEvent());
    });

    Future<void> stubProfileDependencies() async {
      await CacheSync.init(dao: _InMemoryCacheDao());

      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();
      backgroundPublishBloc = _MockBackgroundPublishBloc();
      peopleListsBloc = _MockPeopleListsBloc();
      backgroundPublishStates = StreamController<BackgroundPublishState>();
      addTearDown(backgroundPublishStates.close);

      whenListen(
        backgroundPublishBloc,
        backgroundPublishStates.stream,
        initialState: const BackgroundPublishState(),
      );
      whenListen(
        peopleListsBloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(),
      );

      when(
        () => videosRepository.getAuthorFeed(
          authorPubkey: any(named: 'authorPubkey'),
          offset: any(named: 'offset'),
          relaySeed: any(named: 'relaySeed'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer(
        (_) async => AuthorFeedResult(
          authorPubkey: _authorPubkeyHex,
          videos: mockVideos,
          hasMore: false,
        ),
      );

      when(
        () => videosRepository.removedVideoIds,
      ).thenAnswer((_) => const Stream<String>.empty());

      when(
        () => videoEventService.authorVideos(any()),
      ).thenReturn(const <VideoEvent>[]);
      when(
        () => videoEventService.filterVideoList(any(), includeFeedShape: false),
      ).thenAnswer((i) => i.positionalArguments.first as List<VideoEvent>);
      when(() => videoEventService.shouldHideVideo(any())).thenReturn(false);
      when(
        () => videoEventService.isVideoEventKnownDeleted(any()),
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
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);
      when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);
      when(
        () => blocklistRepository.currentState,
      ).thenReturn(ContentPolicyState.empty());
      when(
        () => blocklistRepository.stateStream,
      ).thenAnswer((_) => const Stream<ContentPolicyState>.empty());
    }

    /// Pumps [ProfileScreenRouter] at [location]. With [navigation], the
    /// screen resolves its navigator to that mock instead of the real router.
    Future<void> pumpProfileRoute(
      WidgetTester tester, {
      required String location,
      required String path,
      MockGoRouter? navigation,
      UserProfile? sharedProfile,
      Nip05VerificationStatus verificationStatus =
          Nip05VerificationStatus.verified,
    }) async {
      const profile = ProfileScreenRouter();
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: path,
            builder: (_, _) => navigation == null
                ? profile
                : MockGoRouterProvider(goRouter: navigation, child: profile),
          ),
        ],
      );
      addTearDown(router.dispose);

      final authService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: _authorPubkeyHex,
      );
      // ProfileHeaderWidget reads these directly; createMockAuthService()
      // does not stub them, and unstubbed Mock getters return null, which
      // throws building the header (mirrors other_profile_screen_test.dart's
      // setUp and profile_route_redirect_test.dart's pumpRouter).
      when(() => authService.isAnonymous).thenReturn(false);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
      when(() => authService.isRpcUpgradeInProgress).thenReturn(false);

      final profileRepository = createMockProfileRepository();
      when(() => profileRepository.getCachedProfile(pubkey: _authorPubkeyHex))
          .thenAnswer((_) async => sharedProfile);

      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: authService,
          mockProfileRepository: profileRepository,
          additionalOverrides: [
            if (sharedProfile?.nip05 case final String claim)
              nip05ClaimVerificationProvider(
                Nip05Claim(pubkey: _authorPubkeyHex, nip05: claim),
              ).overrideWith((ref) async => verificationStatus),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
            routerLocationStreamProvider.overrideWithValue(
              Stream.value(location),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
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
              // routes; this stand-in does the same.
              child: Scaffold(body: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await pumpEventQueue();
      });
      await tester.pump();
      await tester.pump();
    }

    Future<FullscreenFeedBloc> pumpProfileAt(
      WidgetTester tester,
      int index,
    ) async {
      await pumpProfileRoute(
        tester,
        location: ProfileScreenRouter.pathForIndex(_npub, index),
        path: ProfileScreenRouter.pathWithIndex,
      );
      final content = tester.element(find.byType(FullscreenFeedContent));
      return content.read<FullscreenFeedBloc>();
    }

    group('Share profile URL', () {
      setUp(stubProfileDependencies);

      for (final (nip05, status, expectedUrl) in [
        (
          '_@alice.divine.video',
          Nip05VerificationStatus.verified,
          'https://alice.divine.video',
        ),
        (
          'alice@divine.video',
          Nip05VerificationStatus.verified,
          'https://alice.divine.video',
        ),
        (
          'alice@openvine.co',
          Nip05VerificationStatus.verified,
          'https://alice.divine.video',
        ),
        (null, Nip05VerificationStatus.none, null),
        ('alice@example.com', Nip05VerificationStatus.verified, null),
        ('_@alice.divine.video', Nip05VerificationStatus.failed, null),
        ('_@alice.divine.video', Nip05VerificationStatus.error, null),
      ]) {
        testWidgets('shares the correct URL for $nip05 with $status', (
          tester,
        ) async {
          final shareCalls = <Map<Object?, Object?>>[];
          const channel = MethodChannel('dev.fluttercommunity.plus/share');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              shareCalls.add(call.arguments as Map<Object?, Object?>);
              return 'com.apple.UIKit.activity.CopyToPasteboard';
            },
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              null,
            );
          });
          await pumpProfileRoute(
            tester,
            location: ProfileScreenRouter.pathForNpub(_npub),
            path: ProfileScreenRouter.pathWithNpub,
            sharedProfile: UserProfile(
              pubkey: _authorPubkeyHex,
              nip05: nip05,
              displayName: 'Alice',
              rawData: const {},
              createdAt: DateTime(2026),
              eventId: 'c' * 64,
            ),
            verificationStatus: status,
          );
          final l10n = lookupAppLocalizations(const Locale('en'));
          await tester.tap(find.bySemanticsLabel(l10n.profileShareLabel));
          await tester.pump();
          await tester.pump();

          expect(shareCalls, hasLength(1));
          expect(
            shareCalls.single['text'],
            l10n.profileShareText(
              'Alice',
              expectedUrl ?? 'https://divine.video/profile/$_npub',
            ),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 3));
        });
      }
    });

    group('Library button', () {
      setUp(stubProfileDependencies);

      testWidgets('opens the clips route', (tester) async {
        final navigation = MockGoRouter();
        when(() => navigation.push<void>(any())).thenAnswer((_) async {});

        await pumpProfileRoute(
          tester,
          location: ProfileScreenRouter.pathForNpub(_npub),
          path: ProfileScreenRouter.pathWithNpub,
          navigation: navigation,
        );
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.profileMyLibraryLabel));
        await tester.pump();

        verify(() => navigation.push<void>(LibraryScreen.draftsPath)).called(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets('logs a rejected clips navigation instead of leaking it', (
        tester,
      ) async {
        await LogCaptureService().clearAllLogs();
        addTearDown(LogCaptureService().clearAllLogs);
        final navigation = MockGoRouter();
        when(
          () => navigation.push<void>(any()),
        ).thenAnswer((_) => Future<void>.error(Exception('push-failed')));

        await pumpProfileRoute(
          tester,
          location: ProfileScreenRouter.pathForNpub(_npub),
          path: ProfileScreenRouter.pathWithNpub,
          navigation: navigation,
        );
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.profileMyLibraryLabel));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final logs = LogCaptureService()
            .getRecentLogs()
            .where((entry) => entry.message.contains('open profile clips'))
            .toList();
        expect(logs, hasLength(1));
        final log = logs.single;
        expect(log.name, equals('ProfileScreenRouter'));
        expect(log.level, equals(LogLevel.error));
        expect(log.message, contains('push-failed'));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      });
    });

    // The URL is the source of truth for which profile video plays, through
    // URL -> ProfileScreenRouter -> ProfileViewSwitcher -> ProfileVideoFeedView
    // -> PooledFullscreenVideoFeedScreen. Assert the video the fullscreen feed
    // actually shows, so a dropped index anywhere in that chain fails (#7160).
    group('profile feed URL opens the matching page', () {
      setUp(stubProfileDependencies);

      testWidgets('index 0 in the URL opens the first video', (tester) async {
        final bloc = await pumpProfileAt(tester, 0);

        expect(bloc.state.currentVideo?.id, mockVideos[0].id);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets('index 1 in the URL opens the second video', (tester) async {
        final bloc = await pumpProfileAt(tester, 1);

        expect(bloc.state.currentVideo?.id, mockVideos[1].id);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets('successful background publish refreshes the profile feed', (
        tester,
      ) async {
        await pumpProfileAt(tester, 0);
        clearInteractions(videosRepository);

        backgroundPublishStates.add(
          const BackgroundPublishState(
            recentlyPublished: [PublishedVideo(draftId: 'published-draft')],
          ),
        );
        await tester.pump();
        await tester.pump();

        verify(
          () => videosRepository.getAuthorFeed(
            authorPubkey: _authorPubkeyHex,
            relaySeed: any(named: 'relaySeed'),
            skipCache: true,
          ),
        ).called(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets(
        'failed background publish does not refresh the profile feed',
        (
          tester,
        ) async {
          final draft = _MockDivineVideoDraft();
          when(() => draft.id).thenReturn('failed-draft');
          await pumpProfileAt(tester, 0);
          clearInteractions(videosRepository);

          backgroundPublishStates.add(
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: draft,
                  result: const PublishError(PublishErrorKind.generic),
                  progress: 1,
                ),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          verifyNever(
            () => videosRepository.getAuthorFeed(
              authorPubkey: any(named: 'authorPubkey'),
              relaySeed: any(named: 'relaySeed'),
              skipCache: true,
            ),
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 3));
        },
      );

      testWidgets(
        'vanished background upload does not refresh the profile feed',
        (
          tester,
        ) async {
          final draft = _MockDivineVideoDraft();
          when(() => draft.id).thenReturn('vanished-draft');
          await pumpProfileAt(tester, 0);

          backgroundPublishStates.add(
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(draft: draft, result: null, progress: 0.5),
              ],
            ),
          );
          await tester.pump();
          clearInteractions(videosRepository);

          // The upload leaves the collection with no success result, exactly as
          // BackgroundPublishVanished emits it. recentlyPublished stays empty, so
          // this is not a publish and must not refresh the grid.
          backgroundPublishStates.add(const BackgroundPublishState());
          await tester.pump();
          await tester.pump();

          verifyNever(
            () => videosRepository.getAuthorFeed(
              authorPubkey: any(named: 'authorPubkey'),
              relaySeed: any(named: 'relaySeed'),
              skipCache: true,
            ),
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 3));
        },
      );
    });
  });

  // A divine:///profile/<npub> or https://divine.video/profile/<npub> deep
  // link lands on this route with a one-entry stack. When that account has
  // blocked or muted the viewer the screen swaps to BlockedUserScreen, whose
  // app-bar back used to be a raw context.pop — GoError, dead caret.
  group('$BlockedUserScreen back affordance', () {
    testWidgets('back lands on the feed when there is nothing to pop', (
      tester,
    ) async {
      final blocklistRepository = _MockContentBlocklistRepository();
      when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(true);
      when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);

      final profilePath = ProfileScreenRouter.pathForNpub(_npub);
      final router = GoRouter(
        initialLocation: profilePath,
        routes: [
          GoRoute(
            path: VideoFeedPage.pathForIndex(0),
            builder: (_, _) => const Scaffold(body: Text('feed')),
          ),
          GoRoute(
            path: ProfileScreenRouter.pathWithNpub,
            builder: (_, _) => const ProfileScreenRouter(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: _authorPubkeyHex,
          ),
          additionalOverrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
            routerLocationStreamProvider.overrideWithValue(
              Stream.value(profilePath),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BlockedUserScreen), findsOneWidget);
      // Precondition: cold entry really does leave a one-entry stack, so a
      // raw context.pop() here would throw GoError.
      expect(router.canPop(), isFalse);

      await tester.tap(find.byType(DivineAppBarIconButton));
      await tester.pumpAndSettle();

      expect(find.text('feed'), findsOneWidget);
    });
  });

  // Grid detection does not need the profile body dependencies above.
  group('own-profile grid detection', () {
    late _MockContentBlocklistRepository blocklistRepository;

    setUp(() {
      blocklistRepository = _MockContentBlocklistRepository();
      // The scaffold decision is made in ProfileScreenRouter.build, before and
      // independently of the profile body. Reporting the subject as blocking
      // the viewer stops the body at BlockedUserScreen, so these tests need
      // none of the videos/profile provider stack the body would otherwise
      // build — without touching the branch under test.
      when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(true);
      when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);
    });

    /// Pumps the grid route (no video index) for [segment], signed in as
    /// [_authorPubkeyHex].
    Future<void> pumpGridRoute(
      WidgetTester tester,
      String segment, {
      bool settle = true,
    }) async {
      final location = ProfileScreenRouter.pathForNpub(segment);
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: ProfileScreenRouter.pathWithNpub,
            builder: (_, _) => const ProfileScreenRouter(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: _authorPubkeyHex,
          ),
          additionalOverrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
            routerLocationStreamProvider.overrideWithValue(
              Stream.value(location),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    // `/profile/<hex>` is a documented deep-link form, and the app only ever
    // emits npub — so the hex form arrives from shared links and is never
    // dogfooded. Before #6655 the screen compared the raw segment against the
    // signed-in npub, and rendered your own profile without its scaffold.
    testWidgets('a bare-hex link to your own profile is yours', (tester) async {
      await pumpGridRoute(tester, _authorPubkeyHex);

      expect(find.byType(BlockedUserScreen), findsOneWidget);
      expect(find.byType(ProfileScaffold), findsOneWidget);
    });

    testWidgets('an npub link to your own profile is yours', (tester) async {
      await pumpGridRoute(tester, _npub);

      expect(find.byType(BlockedUserScreen), findsOneWidget);
      expect(find.byType(ProfileScaffold), findsOneWidget);
    });

    testWidgets("another user's profile fails closed until redirected", (
      tester,
    ) async {
      // A real, decodable identity: a malformed segment would pass this by
      // failing to normalize rather than by being compared and rejected.
      await pumpGridRoute(tester, _otherNpub, settle: false);

      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(find.byType(ProfileScaffold), findsNothing);
    });

    // A one-character slip in a shared link names nobody. Read as another
    // user, it left the route waiting for a redirect that never came.
    testWidgets('a misspelled npub link reports an invalid profile', (
      tester,
    ) async {
      await pumpGridRoute(tester, syntheticMisspelledNpub, settle: false);

      expect(
        find.text(lookupAppLocalizations(const Locale('en')).profileInvalidId),
        findsOneWidget,
      );
      expect(find.byType(DivineCircularProgressIndicator), findsNothing);
    });
  });
}
