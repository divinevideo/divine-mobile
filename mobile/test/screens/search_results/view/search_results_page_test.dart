import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:videos_repository/videos_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockHashtagRepository extends Mock implements HashtagRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

final _profileRepositoryAvailable = StateProvider<bool>((ref) => false);
final _videosRepositorySelection = StateProvider<int>((ref) => 0);
final _curatedRepositorySelection = StateProvider<int>((ref) => 0);
final _profileReadinessSelection = StateProvider<int>((ref) => 0);

void main() {
  setUpAll(() {
    registerFallbackValue(defaultVideoSearchSort);
    registerFallbackValue(SearchCancellationToken('test-search'));
  });

  group(SearchResultsPage, () {
    late MockProfileRepository mockProfileRepository;
    late _MockVideosRepository mockVideosRepository;
    late _MockHashtagRepository mockHashtagRepository;
    late _MockCuratedListRepository mockCuratedListRepository;
    late _MockPeopleListsRepository mockPeopleListsRepository;

    setUp(() {
      mockProfileRepository = createMockProfileRepository();
      mockVideosRepository = _MockVideosRepository();
      mockHashtagRepository = _MockHashtagRepository();
      mockCuratedListRepository = _MockCuratedListRepository();
      mockPeopleListsRepository = _MockPeopleListsRepository();
    });

    Widget createTestWidget({
      Override? profileRepositoryOverride,
      Override? videosRepositoryOverride,
      Override? curatedRepositoryOverride,
      Override? listThumbnailPolicyOverride,
      List<Override> flagOverrides = const [],
      AuthService? authService,
    }) {
      return testMaterialApp(
        home: const SearchResultsPage(),
        mockAuthService: authService,
        mockProfileRepository: profileRepositoryOverride == null
            ? mockProfileRepository
            : null,
        additionalOverrides: [
          videosRepositoryOverride ??
              videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          hashtagRepositoryProvider.overrideWithValue(mockHashtagRepository),
          curatedRepositoryOverride ??
              curatedListRepositoryProvider.overrideWithValue(
                mockCuratedListRepository,
              ),
          peopleListsRepositoryProvider.overrideWithValue(
            mockPeopleListsRepository,
          ),
          ?profileRepositoryOverride,
          listThumbnailPolicyOverride ??
              curatedListThumbnailFilterProvider.overrideWith(
                (ref) =>
                    (_) => false,
              ),
          ...flagOverrides,
        ],
      );
    }

    testWidgets(
      'policy and readiness replacements preserve typed query and category',
      (
        tester,
      ) async {
        final replacement = _MockCuratedListRepository();
        final replacementProfile = createMockProfileRepository();
        final pending = StreamController<List<CuratedList>>.broadcast();
        addTearDown(pending.close);
        final now = DateTime.utc(2026);
        final row = CuratedList(
          id: 'dance',
          name: 'Dance',
          pubkey: 'a' * 64,
          videoEventIds: ['b' * 64],
          thumbnailUrls: const ['https://example.com/visible.jpg'],
          createdAt: now,
          updatedAt: now,
        );
        when(() => mockCuratedListRepository.searchAllLists(any()))
            .thenAnswer((_) => Stream.value([row]));
        when(() => replacement.searchAllLists(any()))
            .thenAnswer((_) => pending.stream);
        when(
          () => mockVideosRepository.searchVideos(
            query: any(named: 'query'),
            sort: any(named: 'sort'),
          ),
        ).thenAnswer((_) => Stream.value(const <VideoEvent>[]));
        when(
          () => mockHashtagRepository.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => const <String>[]);
        for (final profile in [mockProfileRepository, replacementProfile]) {
          when(
            () => profile.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
              cancellationToken: any(named: 'cancellationToken'),
            ),
          ).thenAnswer((_) => const Stream<ProgressiveSearchResult>.empty());
        }
        await tester.pumpWidget(
          createTestWidget(
            profileRepositoryOverride: profileRepositoryProvider.overrideWith(
              (ref) => switch (ref.watch(_profileReadinessSelection)) {
                0 => mockProfileRepository,
                1 => null,
                _ => replacementProfile,
              },
            ),
            curatedRepositoryOverride: curatedListRepositoryProvider
                .overrideWith(
                  (ref) => ref.watch(_curatedRepositorySelection) == 0
                      ? mockCuratedListRepository
                      : replacement,
                ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'dance');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(() async {});
        await tester.pump();
        final oldBloc = BlocProvider.of<ListSearchBloc>(
          tester.element(find.byType(SearchResultsView)),
        );
        final oldResults = [
          oldBloc,
          BlocProvider.of<VideoSearchBloc>(
            tester.element(find.byType(SearchResultsView)),
          ),
          BlocProvider.of<UserSearchBloc>(
            tester.element(find.byType(SearchResultsView)),
          ),
          BlocProvider.of<HashtagSearchBloc>(
            tester.element(find.byType(SearchResultsView)),
          ),
        ];
        expect(
          oldBloc.state.videoResults.single.thumbnailUrls,
          row.thumbnailUrls,
        );
        final category = BlocProvider.of<SearchResultsFilterCubit>(
          tester.element(find.byType(SearchResultsView)),
        );
        category.filterChanged(SearchResultsFilter.lists);
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SearchResultsPage)),
        );
        container.read(_curatedRepositorySelection.notifier).state = 1;
        await tester.pump();
        final newBloc = BlocProvider.of<ListSearchBloc>(
          tester.element(find.byType(SearchResultsView)),
        );
        for (final result in oldResults) {
          expect(result.isClosed, isTrue);
        }
        final nextResults = [
          newBloc,
          BlocProvider.of<VideoSearchBloc>(
            tester.element(find.byType(SearchResultsView)),
          ),
          BlocProvider.of<UserSearchBloc>(
            tester.element(find.byType(SearchResultsView)),
          ),
          BlocProvider.of<HashtagSearchBloc>(
            tester.element(find.byType(SearchResultsView)),
          ),
        ];
        expect(
          BlocProvider.of<SearchResultsFilterCubit>(
            tester.element(find.byType(SearchResultsView)),
          ),
          same(category),
        );
        expect(category.state, SearchResultsFilter.lists);
        expect(newBloc.state.videoResults, isEmpty);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'dance',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(() async {});
        await tester.pump();
        verify(() => replacement.searchAllLists('dance')).called(1);
        expect(newBloc.state.query, 'dance');
        expect(newBloc.state.videoResults, isEmpty);
        pending.add([row.copyWith(thumbnailUrls: const [])]);
        await tester.pump();
        expect(newBloc.state.videoResults.single.thumbnailUrls, isEmpty);

        container.read(_profileReadinessSelection.notifier).state = 1;
        await tester.pump();
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
        for (final result in nextResults) {
          expect(result.isClosed, isTrue);
        }
        expect(category.isClosed, isFalse);
        expect(category.state, SearchResultsFilter.lists);

        container.read(_profileReadinessSelection.notifier).state = 2;
        await tester.pump();
        final readyBloc = BlocProvider.of<ListSearchBloc>(
          tester.element(find.byType(SearchResultsView)),
        );
        expect(readyBloc, isNot(same(newBloc)));
        expect(readyBloc.state.videoResults, isEmpty);
        expect(
          BlocProvider.of<SearchResultsFilterCubit>(
            tester.element(find.byType(SearchResultsView)),
          ),
          same(category),
        );
        expect(category.state, SearchResultsFilter.lists);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'dance',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(() async {});
        await tester.pump();
        verify(() => replacement.searchAllLists('dance')).called(1);
        expect(readyBloc.state.query, 'dance');
        expect(readyBloc.state.videoResults, isEmpty);
        pending.add([row.copyWith(thumbnailUrls: const [])]);
        await tester.pump();
        expect(readyBloc.state.videoResults.single.thumbnailUrls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
        expect(category.isClosed, isTrue);
        expect(readyBloc.isClosed, isTrue);
      },
    );

    testWidgets(
      'current list policy refreshes search without replacing the repository',
      (tester) async {
        final original = StreamController<List<CuratedList>>.broadcast();
        addTearDown(original.close);
        final pending = StreamController<List<CuratedList>>.broadcast();
        addTearDown(pending.close);
        final row = CuratedList(
          id: 'dance',
          name: 'Dance',
          pubkey: 'a' * 64,
          videoEventIds: ['b' * 64],
          thumbnailUrls: const ['https://example.com/visible.jpg'],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        var policyChanged = false;
        when(() => mockCuratedListRepository.searchAllLists(any())).thenAnswer(
          (_) => policyChanged ? pending.stream : original.stream,
        );
        when(
          () => mockVideosRepository.searchVideos(
            query: any(named: 'query'),
            sort: any(named: 'sort'),
          ),
        ).thenAnswer((_) => Stream.value(const <VideoEvent>[]));
        when(
          () => mockHashtagRepository.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => const <String>[]);
        when(
          () => mockProfileRepository.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
            boostPubkeys: any(named: 'boostPubkeys'),
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer((_) => const Stream<ProgressiveSearchResult>.empty());
        await tester.pumpWidget(
          createTestWidget(
            listThumbnailPolicyOverride: curatedListThumbnailFilterProvider
                .overrideWith((ref) {
                  final generation = ref.watch(blocklistVersionProvider);
                  return (_) => generation != 0;
                }),
          ),
        );
        await tester.enterText(find.byType(TextField), 'dance');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(() async {});
        await tester.pump();
        var context = tester.element(find.byType(SearchResultsView));
        original.add([row]);
        await tester.pump();
        final oldBloc = BlocProvider.of<ListSearchBloc>(context);
        final oldVideoBloc = BlocProvider.of<VideoSearchBloc>(context);
        await tester.showKeyboard(find.byType(TextField));
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(editable.widget.focusNode.hasFocus, isTrue);
        final category = BlocProvider.of<SearchResultsFilterCubit>(context);
        category.filterChanged(SearchResultsFilter.lists);
        await tester.pump();
        expect(
          oldBloc.state.videoResults.single.thumbnailUrls,
          row.thumbnailUrls,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SearchResultsPage)),
        );
        policyChanged = true;
        container.read(blocklistVersionProvider.notifier).increment();
        await tester.pump();
        context = tester.element(find.byType(SearchResultsView));
        final current = BlocProvider.of<ListSearchBloc>(context);
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(editable),
        );
        expect(editable.widget.focusNode.hasFocus, isTrue);
        expect(BlocProvider.of<VideoSearchBloc>(context), same(oldVideoBloc));
        expect(current, isNot(same(oldBloc)));
        expect(oldBloc.isClosed, isTrue);
        expect(
          container.read(curatedListRepositoryProvider),
          same(mockCuratedListRepository),
        );
        expect(current.state.videoResults, isEmpty);
        original.add([row]);
        await tester.pump();
        expect(current.state.videoResults, isEmpty);
        expect(
          BlocProvider.of<SearchResultsFilterCubit>(context),
          same(category),
        );
        expect(category.state, SearchResultsFilter.lists);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'dance',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(() async {});
        await tester.pump();
        verify(() => mockCuratedListRepository.searchAllLists('dance'))
            .called(2);
        pending.add([row.copyWith(thumbnailUrls: const [])]);
        await tester.pump();
        expect(current.state.videoResults.single.thumbnailUrls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
        expect(current.isClosed, isTrue);
      },
    );

    for (final master in [false, true]) {
      for (final profile in [false, true]) {
        testWidgets(
          'review regression people list search flags master=$master profile=$profile',
          (tester) async {
            when(() => mockCuratedListRepository.searchAllLists(any()))
                .thenAnswer((_) => Stream.value(const <CuratedList>[]));
            when(
              () => mockPeopleListsRepository.searchPublicLists(any()),
            ).thenAnswer((_) => Stream.value(const <PeopleListSearchResult>[]));
            await tester.pumpWidget(
              createTestWidget(
                flagOverrides: [
                  isFeatureEnabledProvider(FeatureFlag.curatedLists)
                      .overrideWith((ref) => master),
                  isFeatureEnabledProvider(FeatureFlag.profileListFeatures)
                      .overrideWith((ref) => profile),
                ],
              ),
            );
            final bloc = BlocProvider.of<ListSearchBloc>(
              tester.element(find.byType(SearchResultsView)),
            );
            bloc.add(const ListSearchQueryChanged('crew'));
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump();
            if (master && profile) {
              verify(() => mockPeopleListsRepository.searchPublicLists('crew'))
                  .called(1);
            } else {
              verifyNever(
                () => mockPeopleListsRepository.searchPublicLists(any()),
              );
            }
            verify(() => mockCuratedListRepository.searchAllLists('crew'))
                .called(1);
          },
        );
      }
    }

    testWidgets('shows a waiting state while the profile repository is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          profileRepositoryOverride: profileRepositoryProvider
              .overrideWithValue(
                null,
              ),
        ),
      );

      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows search when the profile repository becomes available', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          profileRepositoryOverride: profileRepositoryProvider.overrideWith((
            ref,
          ) {
            final isAvailable = ref.watch(_profileRepositoryAvailable);
            return isAvailable ? mockProfileRepository : null;
          }),
        ),
      );

      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchResultsPage)),
      );
      container.read(_profileRepositoryAvailable.notifier).state = true;
      await tester.pump();

      expect(find.byType(DivineCircularProgressIndicator), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('recreates search blocs when a repository identity changes', (
      tester,
    ) async {
      final replacementVideosRepository = _MockVideosRepository();
      await tester.pumpWidget(
        createTestWidget(
          videosRepositoryOverride: videosRepositoryProvider.overrideWith((
            ref,
          ) {
            final selection = ref.watch(_videosRepositorySelection);
            return selection == 0
                ? mockVideosRepository
                : replacementVideosRepository;
          }),
        ),
      );

      final contextBefore = tester.element(find.byType(SearchResultsView));
      final blocBefore = BlocProvider.of<VideoSearchBloc>(contextBefore);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchResultsPage)),
      );
      container.read(_videosRepositorySelection.notifier).state = 1;
      await tester.pump();

      final contextAfter = tester.element(find.byType(SearchResultsView));
      final blocAfter = BlocProvider.of<VideoSearchBloc>(contextAfter);
      expect(blocAfter, isNot(same(blocBefore)));
      expect(blocBefore.isClosed, isTrue);
    });

    testWidgets('recreates the list search bloc when the viewer changes', (
      tester,
    ) async {
      // The list search keeps the viewer's own lists past the Divine author
      // check, so the viewer is a dependency like the repositories are.
      final authStates = StreamController<AuthState>.broadcast();
      addTearDown(authStates.close);
      final authService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: 'a' * 64,
      );
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => authStates.stream);
      await tester.pumpWidget(createTestWidget(authService: authService));

      final blocBefore = BlocProvider.of<ListSearchBloc>(
        tester.element(find.byType(SearchResultsView)),
      );

      when(() => authService.currentPublicKeyHex).thenReturn('b' * 64);
      authStates.add(AuthState.authenticating);
      await tester.pump();
      authStates.add(AuthState.authenticated);
      await tester.pump();

      final blocAfter = BlocProvider.of<ListSearchBloc>(
        tester.element(find.byType(SearchResultsView)),
      );
      expect(blocAfter, isNot(same(blocBefore)));
      expect(blocBefore.isClosed, isTrue);
    });

    testWidgets('re-runs active searches when the blocklist changes', (
      tester,
    ) async {
      when(
        () => mockVideosRepository.searchVideos(
          query: any(named: 'query'),
          sort: any(named: 'sort'),
        ),
      ).thenAnswer((_) => Stream.value(const <VideoEvent>[]));
      when(
        () => mockProfileRepository.searchUsersProgressive(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sortBy: any(named: 'sortBy'),
          hasVideos: any(named: 'hasVideos'),
          boostPubkeys: any(named: 'boostPubkeys'),
          cancellationToken: any(named: 'cancellationToken'),
        ),
      ).thenAnswer((_) => const Stream<ProgressiveSearchResult>.empty());
      when(
        () => mockHashtagRepository.searchHashtags(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const <String>[]);
      when(
        () => mockCuratedListRepository.searchAllLists(any()),
      ).thenAnswer((_) => Stream.value(const <CuratedList>[]));
      when(
        () => mockPeopleListsRepository.searchPublicLists(any()),
      ).thenAnswer((_) => Stream.value(const <PeopleListSearchResult>[]));

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'andy');
      // Advance past the search debounce window so the blocs fire.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      verify(
        () => mockVideosRepository.searchVideos(
          query: 'andy',
          sort: any(named: 'sort'),
        ),
      ).called(1);

      // A block/unblock anywhere in the app bumps the blocklist version.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchResultsPage)),
      );
      container.read(blocklistVersionProvider.notifier).increment();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // The still-open searches re-ran through the (block-filtering)
      // repository paths.
      verify(
        () => mockVideosRepository.searchVideos(
          query: 'andy',
          sort: any(named: 'sort'),
        ),
      ).called(1);
      verify(
        () => mockHashtagRepository.searchHashtags(
          query: 'andy',
          limit: any(named: 'limit'),
        ),
      ).called(greaterThanOrEqualTo(2));

      // Dispose and drain pending debounce timers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('shows the empty-query idle placeholder in default mode', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // No query has been entered yet, so the page renders the shared
      // idle placeholder instead of the individual result sections.
      expect(find.byType(SearchSectionInitialState), findsOneWidget);
      expect(find.byType(PeopleSection, skipOffstage: false), findsNothing);
      expect(find.byType(TagsSection, skipOffstage: false), findsNothing);
      expect(find.byType(ListsSection, skipOffstage: false), findsNothing);
      expect(find.byType(VideosSection, skipOffstage: false), findsNothing);

      // Filter pill defaults to "All".
      expect(
        find.descendant(
          of: find.byType(SearchFilterPill),
          matching: find.text('All'),
        ),
        findsOneWidget,
      );

      // Dispose the page and advance past debounce windows owned by the
      // search blocs so no pending timers leak across tests.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
