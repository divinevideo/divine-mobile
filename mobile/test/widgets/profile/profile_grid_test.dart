import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_saved_grid.dart';
import 'package:openvine/widgets/profile/profile_tab_kind.dart';
import 'package:openvine/widgets/profile/profile_videos_grid_skeleton.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockBookmarksRepository extends Mock implements BookmarksRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {
  @override
  bool isBlocked(String pubkey) => false;

  @override
  bool canUnblock(String pubkey) => false;
}

/// In-memory [CacheDao] whose writes can be parked, so a test can hold a tab
/// BLoC in the post-emit snapshot write the way a real disk write does.
class _GatedCacheDao implements CacheDao {
  final Map<String, String> _store = {};

  Completer<void>? writeGate;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    await writeGate?.future;
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

class _MockProfileFeedCubit extends MockBloc<ProfileFeedEvent, ProfileFeedState>
    implements ProfileFeedCubit {}

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

class _MockCuratedListService extends Mock implements CuratedListService {
  _MockCuratedListService() {
    when(() => isCurrentSession).thenReturn(true);
    when(() => isInitialized).thenReturn(true);
    when(() => initializationError).thenReturn(null);
    when(() => hasLoadedSubscriptionIds).thenReturn(true);
    when(() => subscribedLists).thenReturn(const <CuratedList>[]);
    when(() => subscribedListIds).thenReturn(const <String>{});
  }
}

/// Serves a mock service without running the real relay-backed build.
class _FakeCuratedListsState extends CuratedListsState {
  _FakeCuratedListsState(this._service);

  CuratedListService _service;

  @override
  CuratedListService? get service => _service;

  @override
  Future<List<CuratedList>> build() async => _service.lists;

  void replace(CuratedListService service) {
    _service = service;
    state = AsyncData(service.lists);
  }
}

/// Keeps hydration mounted while tests exercise stale refresh completions.
CuratedList _ownedRefreshList(String ownerPubkey) => CuratedList(
  id: 'refresh-safety-list',
  pubkey: ownerPubkey,
  name: 'Refresh safety list',
  videoEventIds: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

VideoEvent _fallbackVideoEvent() {
  final now = DateTime(2024);
  return VideoEvent(
    id: 'fallback-video',
    pubkey: '0' * 64,
    createdAt: now.millisecondsSinceEpoch ~/ 1000,
    content: '',
    timestamp: now,
    title: 'Fallback Video',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
  );
}

void main() {
  const userIdHex =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group(ProfileGridView, () {
    late _MockLikesRepository likesRepository;
    late _MockRepostsRepository repostsRepository;
    late _MockVideosRepository videosRepository;
    late _MockCommentsRepository commentsRepository;
    late _MockContentBlocklistRepository blocklistRepository;
    late _MockProfileFeedCubit profileFeedCubit;
    late _MockMyProfileBloc myProfileBloc;
    late MockNostrClient nostrClient;
    late _GatedCacheDao cacheDao;

    setUpAll(() {
      registerFallbackValue(const MyProfileLoadRequested());
      registerFallbackValue(const ProfileFeedStarted());
      registerFallbackValue(_fallbackVideoEvent());
    });

    setUp(() async {
      cacheDao = _GatedCacheDao();
      await CacheSync.init(dao: cacheDao);
      likesRepository = _MockLikesRepository();
      repostsRepository = _MockRepostsRepository();
      videosRepository = _MockVideosRepository();
      commentsRepository = _MockCommentsRepository();
      blocklistRepository = _MockContentBlocklistRepository();
      profileFeedCubit = _MockProfileFeedCubit();
      myProfileBloc = _MockMyProfileBloc();
      nostrClient = createMockNostrService();

      when(() => nostrClient.publicKey).thenReturn(userIdHex);
      when(
        likesRepository.watchLikedEventIds,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        repostsRepository.watchRepostedAddressableIds,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      when(
        () => blocklistRepository.stateStream,
      ).thenAnswer((_) => const Stream<ContentPolicyState>.empty());
      when(
        () => blocklistRepository.currentState,
      ).thenReturn(ContentPolicyState.empty());
      when(
        () => videosRepository.removedVideoIds,
      ).thenAnswer((_) => const Stream<String>.empty());
      when(
        () => videosRepository.isVideoKnownDeleted(any()),
      ).thenReturn(false);
      when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);
      when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);
      whenListen(
        profileFeedCubit,
        const Stream<ProfileFeedState>.empty(),
        initialState: const ProfileFeedState(status: ProfileFeedStatus.ready),
      );
      final profile = UserProfile(
        pubkey: userIdHex,
        displayName: 'Visible Profile',
        rawData: const {},
        createdAt: DateTime(2024),
        eventId:
            'profile1234567890123456789012345678901234567890123456789012345',
      );
      whenListen(
        myProfileBloc,
        const Stream<MyProfileState>.empty(),
        initialState: MyProfileUpdated(profile: profile),
      );
      when(
        () => myProfileBloc.state,
      ).thenReturn(MyProfileUpdated(profile: profile));
      when(() => myProfileBloc.pubkey).thenReturn(userIdHex);
      when(() => myProfileBloc.add(any())).thenAnswer((invocation) {
        final event = invocation.positionalArguments.first;
        if (event is MyProfileRefreshRequested) {
          event.completer?.complete();
        }
      });
      // A MockBloc never runs a handler, so stand in for the one thing the
      // refresh waits on: the completer the real handler fires in its finally.
      when(() => profileFeedCubit.add(any())).thenAnswer((invocation) {
        final event = invocation.positionalArguments.first;
        if (event is ProfileFeedRefreshRequested) {
          event.completer?.complete();
        }
      });
    });

    Widget buildSubject({
      required bool isOwnProfile,
      bool isLoadingVideos = false,
      MockAuthService? mockAuthService,
      CuratedListService? curatedListService,
      BookmarksRepository? bookmarksRepository,
      Locale? locale,
      List<VideoEvent> videos = const [],
      ScrollController? scrollController,
      List<Override> additionalOverrides = const [],
      String viewedUserHex = userIdHex,
    }) {
      final grid = MultiBlocProvider(
        providers: [
          BlocProvider<MyProfileBloc>.value(value: myProfileBloc),
          BlocProvider<ProfileFeedCubit>.value(value: profileFeedCubit),
        ],
        child: ProfileGridView(
          key: const ValueKey('profile-grid'),
          userIdHex: viewedUserHex,
          isOwnProfile: isOwnProfile,
          videos: videos,
          isLoadingVideos: isLoadingVideos,
          scrollController: scrollController,
        ),
      );

      return testMaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          // testMaterialApp takes no locale, so override it here rather than
          // widen a helper every other profile test shares.
          body: locale == null
              ? grid
              : Builder(
                  builder: (context) => Localizations.override(
                    context: context,
                    locale: locale,
                    child: grid,
                  ),
                ),
        ),
        mockNostrService: nostrClient,
        mockAuthService: mockAuthService,
        additionalOverrides: [
          likesRepositoryProvider.overrideWithValue(likesRepository),
          repostsRepositoryProvider.overrideWithValue(repostsRepository),
          videosRepositoryProvider.overrideWithValue(videosRepository),
          commentsRepositoryProvider.overrideWithValue(commentsRepository),
          contentBlocklistRepositoryProvider.overrideWithValue(
            blocklistRepository,
          ),
          isFeatureEnabledProvider(
            FeatureFlag.videoReplies,
          ).overrideWith((_) => false),
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWith((_) => false),
          if (curatedListService != null)
            curatedListsStateProvider.overrideWith(
              () => _FakeCuratedListsState(curatedListService),
            ),
          if (bookmarksRepository != null)
            bookmarksRepositoryProvider.overrideWithValue(bookmarksRepository),
          ...additionalOverrides,
        ],
      );
    }

    Widget buildSubjectWithContainer(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<MyProfileBloc>.value(value: myProfileBloc),
                BlocProvider<ProfileFeedCubit>.value(value: profileFeedCubit),
              ],
              child: const ProfileGridView(
                key: ValueKey('profile-grid'),
                userIdHex: userIdHex,
                isOwnProfile: false,
                videos: [],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'recreates tab state when own-profile status changes in place',
      (tester) async {
        await tester.pumpWidget(buildSubject(isOwnProfile: false));
        await tester.pump();

        expect(
          find.bySemanticsIdentifier(SemanticIds.profileVideosTab),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileCollabsTab),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileListsTab),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileCommentsTab),
          findsOneWidget,
        );

        await tester.pumpWidget(buildSubject(isOwnProfile: true));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileVideosTab),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileCollabsTab),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileLikedTab),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileRepostsTab),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileListsTab),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileCommentsTab),
          findsOneWidget,
        );
      },
    );

    // ProfileTabBar's own test builds its ProfileTab records by hand, so it
    // cannot see _tabPresentationFor -- the only place a tab kind is mapped to
    // context.l10n. Without these, reverting one of those labels to its
    // SemanticIds anchor reintroduces #6951 with the whole
    // test/widgets/profile suite still green.
    //
    // Both locales are pumped through ProfileGridView on purpose: English
    // alone cannot tell l10n apart from a hardcoded English literal, which is
    // the other way this mapping regresses. The second locale must differ
    // from English on every one of the six values -- de shares Videos,
    // Collabs and Reposts verbatim, so it would leave half the strip
    // unguarded. ja differs on all six.
    for (final locale in [const Locale('en'), const Locale('ja')]) {
      testWidgets(
        'tabs announce their localized name in ${locale.languageCode}, '
        'not the test anchor',
        (tester) async {
          final handle = tester.ensureSemantics();

          await tester.pumpWidget(
            buildSubject(isOwnProfile: true, locale: locale),
          );
          await tester.pump();

          final l10n = lookupAppLocalizations(locale);
          final expectations = <String, String>{
            SemanticIds.profileVideosTab: l10n.profileVideosLabel,
            SemanticIds.profileCollabsTab: l10n.profileCollabsLabel,
            SemanticIds.profileLikedTab: l10n.profileLikedLabel,
            SemanticIds.profileRepostsTab: l10n.profileRepostsLabel,
            SemanticIds.profileListsTab: l10n.profileListsLabel,
            SemanticIds.profileCommentsTab: l10n.profileCommentsLabel,
          };

          for (final entry in expectations.entries) {
            // Merged data, not SemanticsNode.label: Material puts "Tab N of M"
            // on the node's own config and merges the icon's label up.
            final label = tester
                .getSemantics(find.bySemanticsIdentifier(entry.key))
                .getSemanticsData()
                .label;
            expect(label, contains(entry.value));
            expect(label, isNot(contains(entry.key)));
          }

          handle.dispose();
        },
      );
    }

    testWidgets(
      'does not restore another viewer identity tab index after auth change',
      (tester) async {
        const viewerA =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const viewerB =
            '2222222222222222222222222222222222222222222222222222222222222222';
        var currentViewer = viewerA;
        final authService = createMockAuthService(
          authState: AuthState.authenticated,
        );
        when(
          () => authService.currentPublicKeyHex,
        ).thenAnswer((_) => currentViewer);
        when(() => authService.isAnonymous).thenReturn(false);
        when(() => authService.hasExpiredOAuthSession).thenReturn(false);
        when(() => authService.isRpcUpgradeInProgress).thenReturn(false);

        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(
              mockAuthService: authService,
              mockNostrService: nostrClient,
            ),
            likesRepositoryProvider.overrideWithValue(likesRepository),
            repostsRepositoryProvider.overrideWithValue(repostsRepository),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            commentsRepositoryProvider.overrideWithValue(commentsRepository),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
            isFeatureEnabledProvider(
              FeatureFlag.videoReplies,
            ).overrideWith((_) => false),
            isFeatureEnabledProvider(
              FeatureFlag.curatedLists,
            ).overrideWith((_) => false),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildSubjectWithContainer(container));
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier(SemanticIds.profileRepostsTab),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildSubjectWithContainer(container));
        await tester.pump();
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);

        currentViewer = viewerB;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildSubjectWithContainer(container));
        await tester.pump();

        expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 0);
      },
    );

    testWidgets(
      'videos tab shows the skeleton grid while the cold feed load is in '
      'flight (no separate loading view)',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(isOwnProfile: false, isLoadingVideos: true),
        );
        await tester.pump();

        expect(find.byType(ProfileVideosGridSkeleton), findsOneWidget);
      },
    );

    testWidgets(
      'pull-to-refresh completes after a viewed tab settled empty',
      (tester) async {
        final curatedListService = _MockCuratedListService();
        when(() => curatedListService.lists).thenReturn(const []);
        when(() => curatedListService.myLists).thenReturn(const []);
        when(
          () => curatedListService.fetchUserListsFromRelays(
            force: any(named: 'force'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildSubject(
            isOwnProfile: true,
            curatedListService: curatedListService,
          ),
        );
        await tester.pump();

        // View Lists so it joins the set of tabs a refresh re-syncs, and let
        // it settle on the empty list collection.
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        tabBar.controller!.animateTo(
          profileTabKinds(isOwnProfile: true).indexOf(ProfileTabKind.lists),
        );
        await tester.pumpAndSettle();

        final refreshIndicator = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        var refreshed = false;
        unawaited(refreshIndicator.onRefresh().then((_) => refreshed = true));
        await tester.pumpAndSettle();

        // The spinner runs until this future resolves, so a tab that reports
        // no state change leaves the user stuck on it forever.
        expect(refreshed, isTrue);
      },
    );

    testWidgets(
      "pull-to-refresh completes when the next pull lands during a tab's "
      'snapshot write',
      (tester) async {
        when(
          likesRepository.getOrderedLikedEventIds,
        ).thenAnswer((_) async => const <String>[]);
        when(
          likesRepository.syncUserReactions,
        ).thenAnswer((_) async => const LikesSyncResult.empty());

        await tester.pumpWidget(buildSubject(isOwnProfile: true));
        await tester.pump();

        // View Liked so it joins the set of tabs a refresh re-syncs, and let
        // it settle on the empty liked list.
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        tabBar.controller!.animateTo(
          profileTabKinds(isOwnProfile: true).indexOf(ProfileTabKind.liked),
        );
        await tester.pumpAndSettle();

        final refreshIndicator = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );

        // Park the first refresh in the tab's post-emit snapshot write. The
        // grid already looks settled here, so nothing on screen tells the user
        // to hold off on the next pull.
        cacheDao.writeGate = Completer<void>();
        var firstRefreshed = false;
        var secondRefreshed = false;
        unawaited(
          refreshIndicator.onRefresh().then((_) => firstRefreshed = true),
        );
        await tester.pumpAndSettle();
        expect(firstRefreshed, isFalse);

        // A pull landing in that window used to be discarded by the tab BLoC,
        // so its refresh had nothing left to wait for.
        unawaited(
          refreshIndicator.onRefresh().then((_) => secondRefreshed = true),
        );
        await tester.pumpAndSettle();

        cacheDao.writeGate!.complete();
        await tester.pumpAndSettle();

        expect(firstRefreshed, isTrue);
        expect(secondRefreshed, isTrue);
      },
    );

    testWidgets('pull-to-refresh refreshes profile metadata and feed', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isOwnProfile: true));
      await tester.pump();

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();

      verify(
        () => myProfileBloc.add(any(that: isA<MyProfileRefreshRequested>())),
      ).called(1);
      verify(
        () => profileFeedCubit.add(const ProfileFeedRefreshRequested()),
      ).called(1);
    });

    testWidgets('pull-to-refresh re-queries relays for the lists tab', (
      tester,
    ) async {
      final curatedListService = _MockCuratedListService();
      when(() => curatedListService.lists).thenReturn(const []);
      when(() => curatedListService.myLists).thenReturn(const []);
      when(
        () => curatedListService.fetchUserListsFromRelays(
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: true,
          curatedListService: curatedListService,
        ),
      );
      await tester.pump();

      // The tab is lazy: it only participates in refresh once viewed.
      await tester.tap(find.bySemanticsIdentifier(SemanticIds.profileListsTab));
      await tester.pumpAndSettle();

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();

      // Forced, or the service returns without querying because it already
      // synced once this session.
      verify(
        () => curatedListService.fetchUserListsFromRelays(force: true),
      ).called(1);
    });

    for (final initiallyFound in [true, false]) {
      testWidgets(
        'lists refresh retries ${initiallyFound ? 'changed thumbnail metadata' : 'missing thumbnails'}',
        (tester) async {
          const eventId =
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
          final list = CuratedList(
            id: 'refresh-list',
            pubkey: userIdHex,
            name: 'Refresh list',
            videoEventIds: const [eventId],
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          );
          final service = _MockCuratedListService();
          when(() => service.lists).thenReturn([list]);
          when(() => service.myLists).thenReturn([list]);
          when(
            () => service.fetchUserListsFromRelays(
              force: any(named: 'force'),
            ),
          ).thenAnswer((_) async {});
          var requests = 0;
          var found = initiallyFound;
          var thumbnail = 'https://example.com/first.jpg';
          final client = MockClient((_) async {
            requests++;
            return found
                ? http.Response(
                    jsonEncode({
                      'id': eventId,
                      'pubkey': userIdHex,
                      'kind': 34236,
                      'thumbnail': thumbnail,
                    }),
                    200,
                  )
                : http.Response('', 404);
          });
          final repository = CuratedListRepository(
            nostrClient: nostrClient,
            funnelcakeApiClient: FunnelcakeApiClient(
              baseUrl: 'https://example.com',
              httpClient: client,
            ),
          );
          addTearDown(() async {
            await repository.dispose();
            client.close();
          });
          await tester.pumpWidget(
            buildSubject(
              isOwnProfile: true,
              curatedListService: service,
              additionalOverrides: [
                curatedListRepositoryProvider.overrideWithValue(repository),
              ],
            ),
          );
          await tester.tap(
            find.bySemanticsIdentifier(SemanticIds.profileListsTab),
          );
          await tester.pumpAndSettle();
          expect(requests, 1);
          found = true;
          thumbnail = 'https://example.com/refreshed.jpg';
          await tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
          await tester.pumpAndSettle();
          expect(requests, 2);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ProfileGridView)),
          );
          expect(
            container
                .read(myListsWithThumbnailsProvider)
                .value
                ?.single
                .thumbnailUrls,
            [thumbnail],
          );
        },
      );
    }

    testWidgets('old lists refresh does not invalidate a replacement service', (
      tester,
    ) async {
      final original = _MockCuratedListService();
      final replacement = _MockCuratedListService();
      for (final service in [original, replacement]) {
        when(() => service.lists).thenReturn([_ownedRefreshList(userIdHex)]);
        when(() => service.myLists).thenReturn([_ownedRefreshList(userIdHex)]);
      }
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      when(
        () => original.fetchUserListsFromRelays(
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) => release.future);
      late _FakeCuratedListsState notifier;
      var thumbnailPasses = 0;
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: true,
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(
              () => notifier = _FakeCuratedListsState(original),
            ),
            myListsWithThumbnailsProvider.overrideWith((_) async {
              thumbnailPasses++;
              return const [];
            }),
          ],
        ),
      );
      await tester.tap(
        find.bySemanticsIdentifier(SemanticIds.profileListsTab),
      );
      await tester.pumpAndSettle();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      notifier.replace(replacement);
      await tester.pump();
      final passesBeforeCompletion = thumbnailPasses;
      expect(passesBeforeCompletion, 2);
      release.complete();
      await refresh;
      await tester.pumpAndSettle();
      expect(thumbnailPasses, passesBeforeCompletion);
    });

    testWidgets(
      'unmounted lists refresh completes without restarting hydration',
      (
        tester,
      ) async {
        final service = _MockCuratedListService();
        when(() => service.lists).thenReturn(const []);
        when(() => service.myLists).thenReturn(const []);
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        when(
          () => service.fetchUserListsFromRelays(force: any(named: 'force')),
        ).thenAnswer((_) => release.future);
        await tester.pumpWidget(
          buildSubject(isOwnProfile: true, curatedListService: service),
        );
        await tester.tap(
          find.bySemanticsIdentifier(SemanticIds.profileListsTab),
        );
        await tester.pumpAndSettle();
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpWidget(const SizedBox());
        release.complete();
        await refresh;
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'old refresh does not restart hydration after client replacement',
      (
        tester,
      ) async {
        final service = _MockCuratedListService();
        when(() => service.lists).thenReturn([_ownedRefreshList(userIdHex)]);
        when(() => service.myLists).thenReturn([_ownedRefreshList(userIdHex)]);
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        when(
          () => service.fetchUserListsFromRelays(force: any(named: 'force')),
        ).thenAnswer((_) => release.future);
        var thumbnailPasses = 0;
        final overrides = [
          myListsWithThumbnailsProvider.overrideWith((_) async {
            thumbnailPasses++;
            return const [];
          }),
        ];
        await tester.pumpWidget(
          buildSubject(
            isOwnProfile: true,
            curatedListService: service,
            additionalOverrides: overrides,
          ),
        );
        await tester.tap(
          find.bySemanticsIdentifier(SemanticIds.profileListsTab),
        );
        await tester.pumpAndSettle();
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        nostrClient = createMockNostrService();
        when(() => nostrClient.publicKey).thenReturn('b' * 64);
        await tester.pumpWidget(
          buildSubject(
            isOwnProfile: true,
            curatedListService: service,
            additionalOverrides: overrides,
          ),
        );
        await tester.pumpAndSettle();
        final passesBeforeCompletion = thumbnailPasses;
        expect(passesBeforeCompletion, 2);
        release.complete();
        await refresh;
        await tester.pumpAndSettle();
        expect(thumbnailPasses, passesBeforeCompletion);
      },
    );

    testWidgets(
      'failed lists sync retries thumbnails and preserves its error',
      (
        tester,
      ) async {
        final service = _MockCuratedListService();
        when(() => service.lists).thenReturn([_ownedRefreshList(userIdHex)]);
        when(() => service.myLists).thenReturn([_ownedRefreshList(userIdHex)]);
        when(
          () => service.fetchUserListsFromRelays(force: any(named: 'force')),
        ).thenAnswer((_) async => throw StateError('sync failed'));
        var thumbnailPasses = 0;
        await tester.pumpWidget(
          buildSubject(
            isOwnProfile: true,
            curatedListService: service,
            additionalOverrides: [
              myListsWithThumbnailsProvider.overrideWith((_) async {
                thumbnailPasses++;
                return const [];
              }),
            ],
          ),
        );
        await tester.tap(
          find.bySemanticsIdentifier(SemanticIds.profileListsTab),
        );
        await tester.pumpAndSettle();
        expect(thumbnailPasses, 1);
        await expectLater(
          tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh(),
          throwsStateError,
        );
        await tester.pumpAndSettle();
        expect(thumbnailPasses, 2);
      },
    );

    testWidgets(
      'old refresh cannot revive after A to B to A reuses its objects',
      (
        tester,
      ) async {
        final service = _MockCuratedListService();
        when(() => service.lists).thenReturn([_ownedRefreshList(userIdHex)]);
        when(() => service.myLists).thenReturn([_ownedRefreshList(userIdHex)]);
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        when(
          () => service.fetchUserListsFromRelays(force: any(named: 'force')),
        ).thenAnswer((_) => release.future);
        var thumbnailPasses = 0;
        final overrides = [
          myListsWithThumbnailsProvider.overrideWith((_) async {
            thumbnailPasses++;
            return const [];
          }),
        ];
        Widget subject() => buildSubject(
          isOwnProfile: true,
          curatedListService: service,
          additionalOverrides: overrides,
        );
        await tester.pumpWidget(subject());
        await tester.tap(
          find.bySemanticsIdentifier(SemanticIds.profileListsTab),
        );
        await tester.pumpAndSettle();
        expect(thumbnailPasses, 1);
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pump();
        expect(thumbnailPasses, 2);
        when(() => nostrClient.publicKey).thenReturn('b' * 64);
        await tester.pumpWidget(subject());
        await tester.pumpAndSettle();
        when(() => nostrClient.publicKey).thenReturn(userIdHex);
        await tester.pumpWidget(subject());
        await tester.pumpAndSettle();
        expect(thumbnailPasses, 2);
        release.complete();
        await refresh;
        await tester.pumpAndSettle();
        expect(thumbnailPasses, 2);
      },
    );

    testWidgets('pull gesture triggers profile metadata and feed refresh', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isOwnProfile: true));
      await tester.pump();

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, 500),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => myProfileBloc.add(any(that: isA<MyProfileRefreshRequested>())),
      ).called(1);
      verify(
        () => profileFeedCubit.add(const ProfileFeedRefreshRequested()),
      ).called(1);
    });

    // Bookmarks tab. Flat rather than a nested group on purpose: nesting
    // would turn this file's own setUp into one these tests inherit from a
    // distance (#8399). Each test calls [stubBookmarks] itself instead, so the
    // stubs it depends on are visible where it runs.
    late _MockBookmarksRepository bookmarksRepository;
    late StreamController<List<BookmarkItem>> bookmarkChanges;

    /// What the repository currently holds, oldest-first as NIP-51 keeps it.
    late List<BookmarkItem> heldBookmarks;

    VideoEvent savedVideo(String id) => VideoEvent(
      id: id,
      pubkey: '0' * 64,
      createdAt: DateTime(2024).millisecondsSinceEpoch ~/ 1000,
      content: '',
      timestamp: DateTime(2024),
      title: 'Saved $id',
      videoUrl: 'https://example.com/$id.mp4',
    );

    void stubBookmarks({List<BookmarkItem> held = const []}) {
      bookmarksRepository = _MockBookmarksRepository();
      bookmarkChanges = StreamController<List<BookmarkItem>>.broadcast();
      addTearDown(bookmarkChanges.close);
      heldBookmarks = held;
      when(
        bookmarksRepository.watchGlobalBookmarks,
      ).thenAnswer((_) => bookmarkChanges.stream);
      when(
        bookmarksRepository.syncGlobalBookmarks,
      ).thenAnswer((_) async => true);
      when(
        () => bookmarksRepository.globalBookmarks,
      ).thenAnswer((_) => heldBookmarks);
      when(
        () => videosRepository.getVideosByIds(
          any(),
          cacheResults: any(named: 'cacheResults'),
        ),
      ).thenAnswer(
        (invocation) async =>
            (invocation.positionalArguments.first as List<String>)
                .map(savedVideo)
                .toList(),
      );
    }

    Future<void> openBookmarksTab(WidgetTester tester) async {
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: true,
          bookmarksRepository: bookmarksRepository,
        ),
      );
      await tester.pump();
      await tester.tap(
        find.bySemanticsIdentifier(SemanticIds.profileBookmarksTab),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Bookmarks tab renders the saved grid with its empty state', (
      tester,
    ) async {
      stubBookmarks();
      final l10n = lookupAppLocalizations(const Locale('en'));
      await openBookmarksTab(tester);

      expect(find.byType(ProfileSavedGrid), findsOneWidget);
      // The same empty state the standalone saved-videos screen shows.
      expect(find.text(l10n.profileNoSavedVideosTitle), findsOneWidget);
      expect(find.text(l10n.profileSavedOwnEmpty), findsOneWidget);
    });

    testWidgets('Bookmarks tab announces a localized name, not its anchor', (
      tester,
    ) async {
      stubBookmarks();
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: true,
          bookmarksRepository: bookmarksRepository,
          locale: const Locale('de'),
        ),
      );
      await tester.pump();

      final label = tester
          .getSemantics(
            find.bySemanticsIdentifier(SemanticIds.profileBookmarksTab),
          )
          .getSemanticsData()
          .label;
      final de = lookupAppLocalizations(const Locale('de'));
      expect(label, contains(de.shareMenuBookmarks));
      expect(label, isNot(contains(SemanticIds.profileBookmarksTab)));

      handle.dispose();
    });

    testWidgets('Bookmarks tab does not read bookmarks until it is viewed', (
      tester,
    ) async {
      stubBookmarks();
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: true,
          bookmarksRepository: bookmarksRepository,
        ),
      );
      await tester.pumpAndSettle();

      verifyNever(bookmarksRepository.syncGlobalBookmarks);

      await tester.tap(
        find.bySemanticsIdentifier(SemanticIds.profileBookmarksTab),
      );
      await tester.pumpAndSettle();

      verify(bookmarksRepository.syncGlobalBookmarks).called(1);
    });

    testWidgets('Bookmarks tab shows a save made while it is already open', (
      tester,
    ) async {
      stubBookmarks(
        held: const [BookmarkItem(type: 'e', id: 'video-1')],
      );
      await openBookmarksTab(tester);
      expect(
        find.bySemanticsIdentifier(SemanticIds.savedVideoThumbnail(0)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(SemanticIds.savedVideoThumbnail(1)),
        findsNothing,
      );

      // The share sheet publishes through the same repository, which
      // announces the new list; nothing here asks for a refresh.
      bookmarkChanges.add(const [
        BookmarkItem(type: 'e', id: 'video-1'),
        BookmarkItem(type: 'e', id: 'video-2'),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier(SemanticIds.savedVideoThumbnail(1)),
        findsOneWidget,
      );
      verify(bookmarksRepository.syncGlobalBookmarks).called(1);
    });

    testWidgets(
      'Bookmarks tab is re-read by pull-to-refresh once it was viewed',
      (
        tester,
      ) async {
        stubBookmarks();
        await openBookmarksTab(tester);

        final refreshIndicator = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        // Driven by pumps, not runAsync: the tab blocs were created in the
        // test's fake-async zone, so under the real event loop the
        // completers this waits on would never fire.
        var refreshed = false;
        unawaited(refreshIndicator.onRefresh().then((_) => refreshed = true));
        await tester.pumpAndSettle();

        // The spinner runs until this future resolves, so the tab has to
        // complete the completer it was handed.
        expect(refreshed, isTrue);
        // Once for the first view, once for the pull.
        verify(bookmarksRepository.syncGlobalBookmarks).called(2);
      },
    );

    testWidgets("another user's profile has no Bookmarks tab", (
      tester,
    ) async {
      stubBookmarks();
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          bookmarksRepository: bookmarksRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier(SemanticIds.profileBookmarksTab),
        findsNothing,
      );
      expect(find.byType(Tab), findsNWidgets(5));
      // The viewer's own list is not opened while looking at someone else.
      verifyNever(bookmarksRepository.watchGlobalBookmarks);
    });

    List<VideoEvent> videos(int count) => [
      for (var i = 0; i < count; i++)
        VideoEvent(
          id: i.toRadixString(16).padLeft(64, '0'),
          pubkey: userIdHex,
          createdAt: 1704067200 - i,
          content: '',
          timestamp: DateTime.utc(2024),
          videoUrl: 'https://example.com/$i.mp4',
          thumbnailUrl: 'https://example.com/$i.jpg',
        ),
    ];

    Future<void> scrollAllTheWayUp(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.drag(
          find.byType(NestedScrollView),
          const Offset(0, -800),
        );
        await tester.pumpAndSettle();
      }
    }

    testWidgets("stops once a short tab's last row reaches the bottom", (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(3),
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      await scrollAllTheWayUp(tester);

      final lastRowBottom = tester
          .getBottomLeft(
            find.bySemanticsIdentifier(SemanticIds.videoThumbnail(2)),
          )
          .dy;
      final screenBottom = tester
          .getBottomLeft(find.byType(NestedScrollView))
          .dy;
      expect(lastRowBottom, moreOrLessEquals(screenBottom, epsilon: 1));
      expect(
        scrollController.offset,
        lessThan(scrollController.position.maxScrollExtent),
      );
    });

    testWidgets("a fling stops at the short tab's last row too", (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(3),
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      // The drag stops short of the limit, so the fling has to cover the rest.
      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, -60),
        1500,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .getBottomLeft(
              find.bySemanticsIdentifier(SemanticIds.videoThumbnail(2)),
            )
            .dy,
        moreOrLessEquals(
          tester.getBottomLeft(find.byType(NestedScrollView)).dy,
          epsilon: 1,
        ),
      );
    });

    testWidgets('starts at the top when the profile changes in place', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(30),
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();
      await scrollAllTheWayUp(tester);
      expect(scrollController.offset, greaterThan(0));

      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(30),
          scrollController: scrollController,
          viewedUserHex: 'b' * 64,
        ),
      );
      await tester.pumpAndSettle();

      expect(scrollController.offset, equals(0));
    });

    testWidgets('flings toward the end under a status bar without errors', (
      tester,
    ) async {
      const statusBar = 47.0;
      final topInset = FakeViewPadding(
        top: statusBar * tester.view.devicePixelRatio,
      );
      tester.view
        ..padding = topInset
        ..viewPadding = topInset;
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(30),
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, -300),
        1000,
      );
      // The pinned tab bar's inset grows as the header leaves, so the scroll
      // range changes frame by frame while the fling runs.
      for (var frame = 0; frame < 120; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      expect(scrollController.offset, greaterThan(0));
    });

    testWidgets('keeps an empty tab and its message on screen', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      await scrollAllTheWayUp(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final screenBottom = tester
          .getBottomLeft(find.byType(NestedScrollView))
          .dy;
      expect(
        tester.getBottomLeft(find.text(l10n.profileNoVideosTitle)).dy,
        lessThan(screenBottom),
      );
      expect(
        scrollController.offset,
        lessThan(scrollController.position.maxScrollExtent),
      );
    });

    testWidgets('leaves an empty tab one row and the safe area of room', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      const bottomSafeArea = 34.0;
      tester.view.viewPadding = FakeViewPadding(
        bottom: bottomSafeArea * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      await scrollAllTheWayUp(tester);

      final screen = tester.getRect(find.byType(NestedScrollView));
      final rowHeight = (screen.width - 2 * 4) / 3;
      final tabsBottom = tester.getBottomLeft(find.byType(TabBar)).dy;
      expect(
        screen.bottom - tabsBottom,
        greaterThanOrEqualTo(rowHeight + bottomSafeArea),
      );
    });

    testWidgets('still scrolls the header fully away on a long tab', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(30),
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      await scrollAllTheWayUp(tester);

      expect(
        scrollController.offset,
        equals(scrollController.position.maxScrollExtent),
      );
    });

    testWidgets('brings the header down on a switch to a shorter tab', (
      tester,
    ) async {
      when(
        likesRepository.getOrderedLikedEventIds,
      ).thenAnswer((_) async => const <String>[]);
      when(
        likesRepository.syncUserReactions,
      ).thenAnswer((_) async => const LikesSyncResult.empty());
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(30),
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();
      await scrollAllTheWayUp(tester);
      final collapsedOffset = scrollController.offset;
      expect(collapsedOffset, greaterThan(0));

      await tester.tap(find.bySemanticsIdentifier(SemanticIds.profileLikedTab));
      await tester.pumpAndSettle();

      expect(scrollController.offset, lessThan(collapsedOffset));
    });

    testWidgets('waits for a loading tab before bringing the header down', (
      tester,
    ) async {
      final likes = Completer<LikesSyncResult>();
      addTearDown(() {
        if (!likes.isCompleted) likes.complete(const LikesSyncResult.empty());
      });
      when(
        likesRepository.getOrderedLikedEventIds,
      ).thenAnswer((_) async => const <String>[]);
      when(likesRepository.syncUserReactions).thenAnswer((_) => likes.future);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(30),
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();
      await scrollAllTheWayUp(tester);
      final collapsedOffset = scrollController.offset;

      await tester.tap(find.bySemanticsIdentifier(SemanticIds.profileLikedTab));
      // The loading indicator never settles, so pump past the tab switch.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(scrollController.offset, equals(collapsedOffset));

      likes.complete(const LikesSyncResult.empty());
      await tester.pumpAndSettle();
      expect(scrollController.offset, lessThan(collapsedOffset));
    });

    testWidgets('flings back down from under a status bar without errors', (
      tester,
    ) async {
      const statusBar = 47.0;
      final topInset = FakeViewPadding(
        top: statusBar * tester.view.devicePixelRatio,
      );
      tester.view
        ..padding = topInset
        ..viewPadding = topInset;
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          videos: videos(9),
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();
      await scrollAllTheWayUp(tester);

      await tester.fling(find.byType(TabBar), const Offset(0, 200), 3000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
