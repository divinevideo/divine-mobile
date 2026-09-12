// ABOUTME: Widget tests for OtherProfileView integration behavior.
// ABOUTME: Verifies screen-level provider reactivity for profile affordances.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/official_accounts_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockOtherProfileBloc
    extends MockBloc<OtherProfileEvent, OtherProfileState>
    implements OtherProfileBloc {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {
  @override
  bool isBlocked(String pubkey) => false;

  @override
  bool canUnblock(String pubkey) => false;
}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _MockOfficials extends Mock implements OfficialAccountsService {}

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

void main() {
  const targetPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const viewerPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late _MockOtherProfileBloc otherProfileBloc;
  late _MockPeopleListsBloc peopleListsBloc;
  late _MockContentBlocklistRepository blocklistRepository;
  late _MockLikesRepository likesRepository;
  late _MockRepostsRepository repostsRepository;
  late _MockCommentsRepository commentsRepository;
  late _MockVideosRepository videosRepository;
  late _MockVideoEventService videoEventService;
  late _MockOfficials officials;
  late MockFollowRepository followRepository;
  late MockNostrClient nostrClient;
  late MockAuthService authService;

  UserProfile profile() => UserProfile(
    pubkey: targetPubkey,
    displayName: 'Target User',
    rawData: const {},
    createdAt: DateTime(2026),
    eventId: 'c' * 64,
  );

  AuthorFeedResult emptyAuthorFeed() => const AuthorFeedResult(
    authorPubkey: targetPubkey,
    totalCount: 0,
    hasMore: false,
  );

  setUpAll(() {
    registerFallbackValue(const OtherProfileLoadRequested());
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(const <List<String>>[]);
    registerFallbackValue(const <IdentityClaim>[]);
  });

  setUp(() {
    otherProfileBloc = _MockOtherProfileBloc();
    peopleListsBloc = _MockPeopleListsBloc();
    blocklistRepository = _MockContentBlocklistRepository();
    likesRepository = _MockLikesRepository();
    repostsRepository = _MockRepostsRepository();
    commentsRepository = _MockCommentsRepository();
    videosRepository = _MockVideosRepository();
    videoEventService = _MockVideoEventService();
    officials = _MockOfficials();
    followRepository = createMockFollowRepository(
      followingPubkeys: const [targetPubkey],
    );
    nostrClient = createMockNostrService();
    authService = createMockAuthService();

    final loadedState = OtherProfileLoaded(profile: profile(), isFresh: true);
    whenListen(
      otherProfileBloc,
      const Stream<OtherProfileState>.empty(),
      initialState: loadedState,
    );
    when(() => otherProfileBloc.state).thenReturn(loadedState);
    when(() => otherProfileBloc.pubkey).thenReturn(targetPubkey);
    when(() => otherProfileBloc.isBlocked).thenReturn(false);
    when(() => otherProfileBloc.isFollowing).thenReturn(true);
    whenListen(
      peopleListsBloc,
      const Stream<PeopleListsState>.empty(),
      initialState: const PeopleListsState(),
    );
    when(() => peopleListsBloc.state).thenReturn(const PeopleListsState());

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

    when(
      likesRepository.watchLikedEventIds,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      repostsRepository.watchRepostedAddressableIds,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(
      () => videosRepository.removedVideoIds,
    ).thenAnswer((_) => const Stream<String>.empty());
    when(() => videosRepository.isVideoKnownDeleted(any())).thenReturn(false);

    when(
      () => videoEventService.authorVideos(any()),
    ).thenReturn(const <VideoEvent>[]);
    when(
      () => videoEventService.removedVideoIds,
    ).thenAnswer((_) => const Stream<String>.empty());
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    // ProfileFeedCubit._restoreFromCache filters tombstones through this, but
    // only when the shared cache already holds videos for this author. Under
    // the merged `very_good --optimization` isolate that depends on which test
    // files ran first, so leaving it unstubbed fails only on some orderings.
    when(
      () => videoEventService.isVideoEventLocallyDeleted(any()),
    ).thenReturn(false);
    when(
      () => videoEventService.isVideoEventKnownDeleted(any()),
    ).thenReturn(false);
    when(() => videoEventService.addListener(any())).thenReturn(null);
    when(() => videoEventService.removeListener(any())).thenReturn(null);
    when(
      () => videoEventService.addVideoUpdateListener(any()),
    ).thenReturn(() {});
    when(
      () => videoEventService.subscribeToUserVideos(any()),
    ).thenAnswer((_) async {});
    when(
      () => videosRepository.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenAnswer((_) async => emptyAuthorFeed());

    when(
      () => officials.isApprovedMinorDmRecipientSync(any()),
    ).thenReturn(false);
    when(() => nostrClient.publicKey).thenReturn(viewerPubkey);
    when(() => authService.currentPublicKeyHex).thenReturn(viewerPubkey);
    when(() => authService.authState).thenReturn(AuthState.authenticated);
    when(() => authService.isAuthenticated).thenReturn(true);
    when(() => authService.isAnonymous).thenReturn(false);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    when(() => authService.isRpcUpgradeInProgress).thenReturn(false);
  });

  Widget buildSubject({
    required ProviderContainer container,
    String? displayNameHint,
    String? avatarUrlHint,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<OtherProfileBloc>.value(value: otherProfileBloc),
            BlocProvider<PeopleListsBloc>.value(value: peopleListsBloc),
          ],
          child: OtherProfileView(
            pubkey: targetPubkey,
            displayNameHint: displayNameHint,
            avatarUrlHint: avatarUrlHint,
          ),
        ),
      ),
    );
  }

  ProviderContainer createContainer(
    StateProvider<bool> restrictedProvider, {
    bool isVanished = false,
  }) {
    return ProviderContainer(
      overrides: [
        ...getStandardTestOverrides(
          mockAuthService: authService,
          mockNostrService: nostrClient,
          mockFollowRepository: followRepository,
        ),
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
        likesRepositoryProvider.overrideWithValue(likesRepository),
        repostsRepositoryProvider.overrideWithValue(repostsRepository),
        commentsRepositoryProvider.overrideWithValue(commentsRepository),
        videosRepositoryProvider.overrideWithValue(videosRepository),
        videoEventServiceProvider.overrideWithValue(videoEventService),
        officialAccountsServiceProvider.overrideWithValue(officials),
        isDmRestrictedProvider.overrideWith(
          (ref) => ref.watch(restrictedProvider),
        ),
        userProfileStatsReactiveProvider(
          targetPubkey,
        ).overrideWith((ref) => const Stream<ProfileStats?>.empty()),
        fetchUserProfileProvider(
          targetPubkey,
        ).overrideWith((ref) async => profile()),
        isFeatureEnabledProvider(
          FeatureFlag.videoReplies,
        ).overrideWith((ref) => false),
        isFeatureEnabledProvider(
          FeatureFlag.profileMonetizationLinks,
        ).overrideWith((ref) => false),
        isFeatureEnabledProvider(
          FeatureFlag.curatedLists,
        ).overrideWith((ref) => false),
        // Element-level, since the standard overrides already claim the
        // family and Riverpod rejects a second family override.
        if (isVanished)
          profileVanishedProvider(targetPubkey).overrideWith((ref) => true),
      ],
    );
  }

  group('renders', () {
    testWidgets('names a deleted account instead of its route hints', (
      tester,
    ) async {
      // The hints outlive the cache: whoever navigated here supplies them, and
      // the classic-viner slider supplies the archived Vine name and avatar. So
      // evicting the profile row is not enough to stop the deleted account
      // rendering under its own identity.
      final container = createContainer(
        StateProvider<bool>((ref) => false),
        isVanished: true,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildSubject(
          container: container,
          displayNameHint: 'Archived Viner',
          avatarUrlHint: 'https://example.com/archived.jpg',
        ),
      );
      await tester.pump();
      // Second frame: the vanish stream resolves after the first build.
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileDeletedAccountName), findsWidgets);
      expect(find.text('Archived Viner'), findsNothing);
      expect(find.text('Target User'), findsNothing);
    });

    testWidgets('renders the profile when the account has not vanished', (
      tester,
    ) async {
      // Pins the gate: the deleted-account treatment must not leak into the
      // ordinary path.
      final container = createContainer(StateProvider<bool>((ref) => false));
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildSubject(container: container, displayNameHint: 'Archived Viner'),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text('Target User'), findsWidgets);
      expect(find.text(l10n.profileDeletedAccountName), findsNothing);
    });
  });

  group('interactions', () {
    testWidgets(
      'updates Message visibility when DM restriction flips while mounted',
      (tester) async {
        final restrictedProvider = StateProvider<bool>((ref) => true);
        final container = createContainer(restrictedProvider);
        addTearDown(container.dispose);

        await tester.pumpWidget(buildSubject(container: container));
        await tester.pump();

        expect(find.text('Message'), findsNothing);

        container.read(restrictedProvider.notifier).state = false;
        await tester.pump();

        expect(find.text('Message'), findsOneWidget);

        container.read(restrictedProvider.notifier).state = true;
        await tester.pump();

        expect(find.text('Message'), findsNothing);
      },
    );

    testWidgets(
      're-fetches raw Kind 0 when the monetization flag flips while mounted',
      (tester) async {
        // Regression: the flag both gates the Tip/Support button AND gates
        // OtherProfileBloc.requireRawKind0 (relay Kind 0, which carries the
        // monetization links, vs the REST projection that strips them). A
        // keyless BlocProvider captured the first flag value forever, so
        // enabling the flag on an already-mounted profile never re-fetched the
        // raw Kind 0 and the button never appeared.
        const targetNpub =
            'npub1424242424242424242424242424242424242424242424242424qamrcaj';
        final flag = StateProvider<bool>((ref) => false);
        final identityClaims = _MockIdentityClaimsRepository();
        final profileRepo = MockProfileRepository();
        when(
          () => profileRepo.getCachedProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) async => null);
        // Not a deleted account — the bloc short-circuits the whole load when
        // this is true.
        when(() => profileRepo.isVanished(any())).thenReturn(false);
        when(
          () => profileRepo.watchProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) => const Stream<UserProfile?>.empty());
        when(
          () => profileRepo.fetchFreshProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) async => profile());
        when(
          () => profileRepo.fetchFreshProfile(
            pubkey: any(named: 'pubkey'),
            requireRawKind0: any(named: 'requireRawKind0'),
            rawKind0RetryDelays: any(named: 'rawKind0RetryDelays'),
          ),
        ).thenAnswer((_) async => profile());
        // The load also drives the identity-claims flow; stub it to resolve to
        // no claims so it completes without a MissingStub TypeError.
        when(
          () => profileRepo.cachedIdentityTags(any()),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepo.freshIdentityTags(
            pubkey: any(named: 'pubkey'),
            kind0Tags: any(named: 'kind0Tags'),
          ),
        ).thenAnswer((_) async => const <List<String>>[]);
        when(
          () => identityClaims.cachedVerifiedClaims(
            pubkey: any(named: 'pubkey'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => identityClaims.resolveClaims(
            pubkey: any(named: 'pubkey'),
            freshTags: any(named: 'freshTags'),
            cached: any(named: 'cached'),
            renderedClaims: any(named: 'renderedClaims'),
          ),
        ).thenAnswer((_) async => const <IdentityClaim>[]);

        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(
              mockAuthService: authService,
              mockNostrService: nostrClient,
              mockFollowRepository: followRepository,
              mockProfileRepository: profileRepo,
            ),
            identityClaimsRepositoryProvider.overrideWithValue(identityClaims),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
            likesRepositoryProvider.overrideWithValue(likesRepository),
            repostsRepositoryProvider.overrideWithValue(repostsRepository),
            commentsRepositoryProvider.overrideWithValue(commentsRepository),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            officialAccountsServiceProvider.overrideWithValue(officials),
            isDmRestrictedProvider.overrideWith((ref) => false),
            userProfileStatsReactiveProvider(
              targetPubkey,
            ).overrideWith((ref) => const Stream<ProfileStats?>.empty()),
            fetchUserProfileProvider(
              targetPubkey,
            ).overrideWith((ref) async => profile()),
            isFeatureEnabledProvider(
              FeatureFlag.videoReplies,
            ).overrideWith((ref) => false),
            isFeatureEnabledProvider(
              FeatureFlag.curatedLists,
            ).overrideWith((ref) => false),
            isFeatureEnabledProvider(
              FeatureFlag.profileMonetizationLinks,
            ).overrideWith((ref) => ref.watch(flag)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: BlocProvider<PeopleListsBloc>.value(
                value: peopleListsBloc,
                child: const OtherProfileScreen(npub: targetNpub),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Flag OFF: bloc fetched with requireRawKind0 false, never true.
        verifyNever(
          () => profileRepo.fetchFreshProfile(
            pubkey: targetPubkey,
            requireRawKind0: true,
            rawKind0RetryDelays: any(named: 'rawKind0RetryDelays'),
          ),
        );

        container.read(flag.notifier).state = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Flipping the flag must recreate the bloc and re-fetch the raw Kind 0.
        verify(
          () => profileRepo.fetchFreshProfile(
            pubkey: targetPubkey,
            requireRawKind0: true,
            rawKind0RetryDelays: any(named: 'rawKind0RetryDelays'),
          ),
        ).called(1);
      },
    );
  });

  group('navigation', () {
    testWidgets('Message routes to the canonical conversation id', (
      tester,
    ) async {
      // Regression: this screen pushed `pathForId(widget.pubkey)` — the raw peer
      // pubkey — while every other entry point and `DmRepository.sendMessage`
      // use the sha256 of the sorted participants. Both are 64-char hex, so
      // nothing caught the mismatch: the thread's id matched no stored row, so
      // history never rendered and messages sent from it never appeared.
      final restrictedProvider = StateProvider<bool>((ref) => false);
      final container = createContainer(restrictedProvider);
      addTearDown(container.dispose);

      String? pushedId;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider<OtherProfileBloc>.value(value: otherProfileBloc),
                BlocProvider<PeopleListsBloc>.value(value: peopleListsBloc),
              ],
              child: const OtherProfileView(pubkey: targetPubkey),
            ),
          ),
          GoRoute(
            path: '/inbox/conversation/:id',
            builder: (_, state) {
              pushedId = state.pathParameters['id'];
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.profileMessageLabel));
      await tester.pumpAndSettle();

      expect(
        pushedId,
        DmRepository.computeConversationId([viewerPubkey, targetPubkey]),
      );
      expect(pushedId, isNot(targetPubkey));
    });
  });
}
