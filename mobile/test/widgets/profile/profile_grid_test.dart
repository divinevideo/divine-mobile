import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_tab_kind.dart';
import 'package:openvine/widgets/profile/profile_videos_grid_skeleton.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

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

class _MockCuratedListService extends Mock implements CuratedListService {}

/// Serves a mock service without running the real relay-backed build.
class _FakeCuratedListsState extends CuratedListsState {
  _FakeCuratedListsState(this._service);

  final CuratedListService _service;

  @override
  CuratedListService? get service => _service;

  @override
  Future<List<CuratedList>> build() async => _service.lists;
}

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
      Locale? locale,
    }) {
      final grid = MultiBlocProvider(
        providers: [
          BlocProvider<MyProfileBloc>.value(value: myProfileBloc),
          BlocProvider<ProfileFeedCubit>.value(value: profileFeedCubit),
        ],
        child: ProfileGridView(
          key: const ValueKey('profile-grid'),
          userIdHex: userIdHex,
          isOwnProfile: isOwnProfile,
          videos: const [],
          isLoadingVideos: isLoadingVideos,
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
  });
}
