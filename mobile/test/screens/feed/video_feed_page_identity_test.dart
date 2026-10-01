import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _VideosRepository extends Mock implements VideosRepository {}

class _CuratedListRepository extends Mock implements CuratedListRepository {}

class _PeopleListsRepository extends Mock implements PeopleListsRepository {}

class _Nostr extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _PagePreferencesGate extends InMemorySharedPreferencesStore {
  _PagePreferencesGate(this.key, String value)
    : super.withData({'flutter.$key': value});
  final String key;
  final started = Completer<void>();
  final release = Completer<void>();
  final repaired = Completer<void>();
  bool _blocked = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${this.key}' && value == 'forYou' && !_blocked) {
      _blocked = true;
      started.complete();
      await release.future;
    }
    final result = await super.setValue(valueType, key, value);
    if (_blocked &&
        key == 'flutter.${this.key}' &&
        value != 'forYou' &&
        !repaired.isCompleted) {
      repaired.complete();
    }
    return result;
  }
}

class _CacheDao implements CacheDao {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deletePrefix(String prefix) async {}
  @override
  Future<int> totalPayloadBytes() async => 0;
  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

void main() {
  setUp(() {
    final originalPreferencesPlatform = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance = originalPreferencesPlatform;
    });
  });

  group('VideoFeedPage account and flag identity', () {
    testWidgets(
      'Home flag flip closes old feed, hides people sources, preserves and restores saved selection',
      (tester) async {
        await CacheSync.init(dao: _CacheDao());
        final viewer = 'a' * 64;
        final owner = 'b' * 64;
        final member = 'c' * 64;
        final source = VideoFeedSource.peopleList(
          listId: 'crew',
          listName: 'Flag Crew',
          listOwnerPubkey: owner,
        );
        final selectionKey = 'selected_feed_mode_$viewer';
        SharedPreferences.setMockInitialValues({
          selectionKey: FeedModePreferenceStore.storageValueFor(source),
        });
        final prefs = await SharedPreferences.getInstance();
        final people = _PeopleListsRepository();
        final videos = _VideosRepository();
        final curated = _CuratedListRepository();
        final copies = [
          PeopleListSearchResult(
            ownerPubkey: owner,
            list: UserList(
              id: 'crew',
              name: 'Flag Crew',
              pubkeys: [member],
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
        ];
        final stream =
            StreamController<List<PeopleListSearchResult>>.broadcast();
        addTearDown(stream.close);
        when(() => people.readFollowedLists(viewerPubkey: viewer))
            .thenAnswer((_) async => copies);
        when(() => people.watchFollowedLists(viewerPubkey: viewer))
            .thenAnswer((_) => stream.stream);
        when(
          () => people.isFollowingList(
            viewerPubkey: viewer,
            ownerPubkey: owner,
            listId: 'crew',
          ),
        ).thenAnswer((_) async => true);
        when(
          () => people.syncFollowedLists(
            viewerPubkey: any(named: 'viewerPubkey'),
            isCancelled: any(named: 'isCancelled'),
          ),
        ).thenAnswer((_) async {});
        when(curated.getSubscribedLists).thenReturn([]);
        when(() => curated.subscriptionSnapshots).thenAnswer(
          (_) => const Stream<CuratedListSubscriptionSnapshot>.empty(),
        );
        when(
          () => videos.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
            until: any(named: 'until'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        await tester.pumpWidget(
          testMaterialApp(
            home: const Scaffold(body: VideoFeedPage()),
            mockSharedPreferences: prefs,
            mockAuthService: createMockAuthService(
              authState: AuthState.authenticated,
              currentPublicKeyHex: viewer,
            ),
            mockProfileRepository: createMockProfileRepository(),
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(videos),
              curatedListRepositoryProvider.overrideWithValue(curated),
              peopleListsRepositoryProvider.overrideWithValue(people),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final original = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VideoFeedPage)),
        );
        expect(original.state.source, source);
        expect(find.text('Flag Crew'), findsOneWidget);
        expect(stream.hasListener, isTrue);
        await tester.tap(find.text('Flag Crew'));
        await tester.pumpAndSettle();
        expect(find.text('Flag Crew'), findsNWidgets(2));
        Navigator.of(tester.element(find.byType(VideoFeedView))).pop();
        await tester.pumpAndSettle();
        await container
            .read(featureFlagServiceProvider)
            .setFlag(FeatureFlag.curatedLists, false);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final gated = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        expect(identical(gated, original), isFalse);
        expect(original.isClosed, isTrue);
        expect(stream.hasListener, isFalse);
        expect(gated.state.source.type, VideoFeedSourceType.forYou);
        expect(gated.state.followedPeopleLists, isEmpty);
        expect(find.text('Flag Crew'), findsNothing);
        expect(find.text('For You'), findsOneWidget);
        await tester.tap(find.text('For You'));
        await tester.pumpAndSettle();
        expect(find.text('Flag Crew'), findsNothing);
        Navigator.of(tester.element(find.byType(VideoFeedView))).pop();
        await tester.pumpAndSettle();
        expect(
          prefs.getString(selectionKey),
          FeedModePreferenceStore.storageValueFor(source),
        );
        await container
            .read(featureFlagServiceProvider)
            .setFlag(FeatureFlag.curatedLists, true);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final restored = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        expect(identical(gated, restored), isFalse);
        expect(gated.isClosed, isTrue);
        expect(restored.state.source, source);
        expect(restored.state.followedPeopleLists, copies);
        expect(find.text('Flag Crew'), findsOneWidget);
        expect(stream.hasListener, isTrue);
        expect(
          prefs.getString(selectionKey),
          FeedModePreferenceStore.storageValueFor(source),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(restored.isClosed, isTrue);
        expect(stream.hasListener, isFalse);
      },
    );

    testWidgets(
      'Home is rebuilt for another account while people lists are off',
      (tester) async {
        await CacheSync.init(dao: _CacheDao());
        final firstViewer = 'a' * 64;
        final secondViewer = 'd' * 64;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final videos = _VideosRepository();
        final curated = _CuratedListRepository();
        final authStates = StreamController<AuthState>.broadcast();
        addTearDown(authStates.close);
        final auth = createMockAuthService(
          authState: AuthState.authenticated,
          currentPublicKeyHex: firstViewer,
        );
        when(() => auth.authStateStream).thenAnswer((_) => authStates.stream);
        when(curated.getSubscribedLists).thenReturn([]);
        when(
          () => curated.subscriptionSnapshots,
        ).thenAnswer(
          (_) => const Stream<CuratedListSubscriptionSnapshot>.empty(),
        );
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        await tester.pumpWidget(
          testMaterialApp(
            home: const Scaffold(body: VideoFeedPage()),
            mockSharedPreferences: prefs,
            mockAuthService: auth,
            mockProfileRepository: createMockProfileRepository(),
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(videos),
              curatedListRepositoryProvider.overrideWithValue(curated),
              isFeatureEnabledProvider(
                FeatureFlag.curatedLists,
              ).overrideWithValue(false),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final original = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();

        when(() => auth.currentPublicKeyHex).thenReturn(secondViewer);
        authStates
          ..add(AuthState.checking)
          ..add(AuthState.authenticated);
        await tester.runAsync(pumpEventQueue);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();

        final switched = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        expect(identical(switched, original), isFalse);
        expect(original.isClosed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'curated repository replacement closes old Home and restores from the new snapshot',
      (tester) async {
        await CacheSync.init(dao: _CacheDao());
        final viewer = 'a' * 64;
        final author = 'b' * 64;
        final originalList = CuratedList(
          id: 'crew',
          pubkey: author,
          name: 'Original Crew',
          videoEventIds: [author],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final source = VideoFeedSource.subscribedList(
          listId: originalList.authorScopedId,
          listName: originalList.name,
        );
        final key = 'selected_feed_mode_$viewer';
        SharedPreferences.setMockInitialValues({
          key: FeedModePreferenceStore.storageValueFor(source),
        });
        final prefs = await SharedPreferences.getInstance();
        final videos = _VideosRepository();
        final originalRepository = _CuratedListRepository();
        final replacementRepository = _CuratedListRepository();
        final originalSnapshots =
            StreamController<CuratedListSubscriptionSnapshot>.broadcast();
        final replacementSnapshots =
            StreamController<CuratedListSubscriptionSnapshot>.broadcast();
        addTearDown(originalSnapshots.close);
        addTearDown(replacementSnapshots.close);
        final initialSnapshot = CuratedListSubscriptionSnapshot(
          lists: [originalList],
          isComplete: true,
        );
        final emptySnapshot = CuratedListSubscriptionSnapshot(
          lists: const [],
          isComplete: true,
        );
        for (final (repository, snapshot, stream) in [
          (originalRepository, initialSnapshot, originalSnapshots.stream),
          (replacementRepository, emptySnapshot, replacementSnapshots.stream),
        ]) {
          when(repository.getSubscribedLists).thenReturn(snapshot.lists);
          when(() => repository.subscriptionSnapshot).thenReturn(snapshot);
          when(() => repository.subscriptionSnapshots)
              .thenAnswer((_) => stream);
          when(() => repository.hasCompleteSubscriptionSnapshot)
              .thenReturn(true);
        }
        when(
          () => originalRepository.getListById(originalList.authorScopedId),
        ).thenReturn(originalList);
        when(
          () => replacementRepository.getListById(originalList.authorScopedId),
        ).thenReturn(null);
        when(
          () => originalRepository.getOrderedVideoIds(
            originalList.authorScopedId,
          ),
        ).thenReturn([author]);
        when(() => videos.getVideosForList(any())).thenAnswer((_) async => []);
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        await tester.pumpWidget(
          testMaterialApp(
            home: ProviderScope(
              overrides: [
                curatedListRepositoryProvider.overrideWithValue(
                  originalRepository,
                ),
              ],
              child: const Scaffold(body: VideoFeedPage()),
            ),
            mockSharedPreferences: prefs,
            mockAuthService: createMockAuthService(
              authState: AuthState.authenticated,
              currentPublicKeyHex: viewer,
            ),
            mockProfileRepository: createMockProfileRepository(),
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(videos),
              isFeatureEnabledProvider(FeatureFlag.curatedLists)
                  .overrideWithValue(false),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final original = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VideoFeedPage)),
        );
        expect(original.state.source, source);
        expect(original.state.status, VideoFeedStatus.success);
        expect(originalSnapshots.hasListener, isTrue);
        expect(find.text('Original Crew'), findsOneWidget);
        container.updateOverrides([
          curatedListRepositoryProvider.overrideWithValue(
            replacementRepository,
          ),
        ]);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final replaced = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        expect(identical(replaced, original), isFalse);
        expect(original.isClosed, isTrue);
        expect(originalSnapshots.hasListener, isFalse);
        expect(replacementSnapshots.hasListener, isTrue);
        expect(replaced.state.source, const VideoFeedSource.forYou());
        expect(replaced.state.status, VideoFeedStatus.success);
        expect(replaced.state.subscribedLists, isEmpty);
        expect(find.text('Original Crew'), findsNothing);
        expect(prefs.getString(key), 'forYou');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(replaced.isClosed, isTrue);
        expect(replacementSnapshots.hasListener, isFalse);
      },
    );
    for (final remount in [false, true]) {
      testWidgets(
        remount
            ? 'actual same-account Page remount retains accepted selection'
            : 'actual Home retains account coordinator across replacement during an old provisional write',
        (tester) async {
          await CacheSync.init(dao: _CacheDao());
          final viewer = 'a' * 64;
          final author = 'b' * 64;
          final list = CuratedList(
            id: 'crew',
            pubkey: author,
            name: 'Persistent Crew',
            videoEventIds: [author],
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          );
          final source = VideoFeedSource.subscribedList(
            listId: list.authorScopedId,
            listName: list.name,
          );
          final key = 'selected_feed_mode_$viewer';
          SharedPreferences.setMockInitialValues({});
          final gate = _PagePreferencesGate(
            key,
            FeedModePreferenceStore.storageValueFor(source),
          );
          SharedPreferencesStorePlatform.instance = gate;
          final prefs = await SharedPreferences.getInstance();
          addTearDown(() {
            if (!gate.release.isCompleted) gate.release.complete();
            SharedPreferences.setMockInitialValues({});
          });
          final originalRepository = CuratedListRepository(
            nostrClient: _Nostr(),
            funnelcakeApiClient: _Api(),
          );
          final replacementRepository = CuratedListRepository(
            nostrClient: _Nostr(),
            funnelcakeApiClient: _Api(),
          );
          originalRepository.setSubscribedLists([list]);
          replacementRepository.setSubscribedLists([list]);
          addTearDown(originalRepository.dispose);
          addTearDown(replacementRepository.dispose);
          final videos = _VideosRepository();
          when(() => videos.getVideosForList(any()))
              .thenAnswer((_) async => []);
          when(
            () => videos.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
          final homeMounted = ValueNotifier(true);
          addTearDown(homeMounted.dispose);
          await tester.pumpWidget(
            testMaterialApp(
              home: ProviderScope(
                overrides: [
                  curatedListRepositoryProvider.overrideWithValue(
                    originalRepository,
                  ),
                ],
                child: ValueListenableBuilder<bool>(
                  valueListenable: homeMounted,
                  builder: (_, mounted, _) => mounted
                      ? const Scaffold(body: VideoFeedPage())
                      : const SizedBox.shrink(),
                ),
              ),
              mockSharedPreferences: prefs,
              mockAuthService: createMockAuthService(
                authState: AuthState.authenticated,
                currentPublicKeyHex: viewer,
              ),
              mockProfileRepository: createMockProfileRepository(),
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(videos),
                isFeatureEnabledProvider(FeatureFlag.curatedLists)
                    .overrideWithValue(false),
              ],
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(pumpEventQueue);
          await tester.pump();
          final originalElement = tester.element(find.byType(VideoFeedView));
          final original = originalElement.read<VideoFeedBloc>();
          final coordinator = originalElement
              .read<FeedModePersistenceCoordinator>();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(VideoFeedPage)),
          );
          expect(original.state.source, source);
          expect(original.state.status, VideoFeedStatus.success);
          originalRepository.setSubscribedLists([]);
          await tester.runAsync(
            () => gate.started.future.timeout(const Duration(seconds: 5)),
          );
          expect(prefs.getString(key), 'forYou');
          if (remount) {
            homeMounted.value = false;
            await tester.pump();
            await tester.runAsync(pumpEventQueue);
          }
          container.updateOverrides([
            curatedListRepositoryProvider.overrideWithValue(
              replacementRepository,
            ),
          ]);
          if (remount) {
            homeMounted.value = true;
            await tester.pump();
          }
          await tester.pumpAndSettle();
          await tester.runAsync(pumpEventQueue);
          await tester.pump();
          final replacementElement = tester.element(find.byType(VideoFeedView));
          final replacement = replacementElement.read<VideoFeedBloc>();
          expect(identical(replacement, original), isFalse);
          expect(
            identical(
              replacementElement.read<FeedModePersistenceCoordinator>(),
              coordinator,
            ),
            isTrue,
          );
          expect(replacement.state.source, source);
          expect(replacement.state.status, VideoFeedStatus.success);
          await tester.runAsync(() async {
            gate.release.complete();
            await gate.repaired.future.timeout(const Duration(seconds: 5));
            await prefs.reload();
          });
          await tester.runAsync(pumpEventQueue);
          await tester.pumpAndSettle();
          expect(original.isClosed, isTrue);
          expect(replacement.state.source, source);
          expect(
            prefs.getString(key),
            FeedModePreferenceStore.storageValueFor(source),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(pumpEventQueue);
          await tester.pump();
          expect(replacement.isClosed, isTrue);
          expect(
            () => FeedModePreferenceStore(
              sharedPreferences: prefs,
              userPubkey: viewer,
              followRepository: createMockFollowRepository(),
              curatedListRepository: replacementRepository,
              persistenceCoordinator: coordinator,
            ),
            throwsStateError,
          );
        },
      );
    }
  });
}
