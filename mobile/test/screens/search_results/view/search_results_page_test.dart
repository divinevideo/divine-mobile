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
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';
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
    }) {
      return testMaterialApp(
        home: const SearchResultsPage(),
        mockProfileRepository: mockProfileRepository,
        additionalOverrides: [
          videosRepositoryOverride ??
              videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          hashtagRepositoryProvider.overrideWithValue(mockHashtagRepository),
          curatedListRepositoryProvider.overrideWithValue(
            mockCuratedListRepository,
          ),
          peopleListsRepositoryProvider.overrideWithValue(
            mockPeopleListsRepository,
          ),
          ?profileRepositoryOverride,
        ],
      );
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
