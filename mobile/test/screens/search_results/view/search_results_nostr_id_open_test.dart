// ABOUTME: Widget tests that pasting a Nostr identifier in search opens it.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockHashtagRepository extends Mock implements HashtagRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

void main() {
  const hexId =
      'c218ed9ce99db3c216ca7c70f7a289a3da56fe0b9ba1492b3179db73c8e63a4d';
  const authorHex =
      '81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95';
  final npub = NostrKeyUtils.encodePubKey(authorHex);
  final note1 = Nip19.encodeNoteId(hexId);

  setUpAll(() {
    registerFallbackValue(defaultVideoSearchSort);
    registerFallbackValue(SearchCancellationToken('test-search'));
  });

  group('SearchResultsPage Nostr id auto-open', () {
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

      // Stub the four text-search sources so entering a query does not leave
      // the search BLoCs searching against unstubbed mocks.
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
        () => mockCuratedListRepository.searchAllLists(any()),
      ).thenAnswer((_) => Stream.value(const <CuratedList>[]));
      when(
        () => mockPeopleListsRepository.searchPublicLists(any()),
      ).thenAnswer((_) => Stream.value(const <PeopleListSearchResult>[]));
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
    });

    Widget createTestWidget({
      String initialLocation = SearchResultsPage.emptyPath,
    }) {
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: SearchResultsPage.emptyPath,
            builder: (_, _) => const SearchResultsPage(),
          ),
          GoRoute(
            path: SearchResultsPage.path,
            builder: (_, state) => SearchResultsPage(
              initialQuery: state.pathParameters['query'],
            ),
          ),
          GoRoute(
            path: OtherProfileScreen.pathWithNpub,
            builder: (_, state) => Scaffold(
              body: Text('profile:${state.pathParameters['npub']}'),
            ),
          ),
          GoRoute(
            path: '/video/:eventId',
            builder: (_, state) => Scaffold(
              body: Text('video:${state.pathParameters['eventId']}'),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockProfileRepository: mockProfileRepository,
        additionalOverrides: [
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          hashtagRepositoryProvider.overrideWithValue(mockHashtagRepository),
          curatedListRepositoryProvider.overrideWithValue(
            mockCuratedListRepository,
          ),
          peopleListsRepositoryProvider.overrideWithValue(
            mockPeopleListsRepository,
          ),
          curatedListThumbnailFilterProvider.overrideWith(
            (ref) =>
                (_) => false,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark(),
        ),
      );
    }

    testWidgets('pasting an npub opens that profile', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.enterText(find.byType(TextField), npub);
      await tester.pumpAndSettle();

      expect(find.text('profile:$npub'), findsOneWidget);
    });

    testWidgets('pasting a note1 opens that video', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.enterText(find.byType(TextField), note1);
      await tester.pumpAndSettle();

      expect(find.text('video:$note1'), findsOneWidget);
    });

    testWidgets(
      'pasting the event id of a video the viewer filters out opens it',
      (tester) async {
        when(
          () => mockVideosRepository.lookupVideoForRouteId(hexId),
        ).thenAnswer(
          (_) async => VideoRouteHiddenByFilter(
            VideoEvent(
              id: hexId,
              pubkey: authorHex,
              createdAt: 1700000000,
              content: '',
              timestamp: DateTime.utc(2023, 11, 14),
            ),
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.enterText(find.byType(TextField), hexId);
        await tester.pumpAndSettle();

        expect(find.text('video:$hexId'), findsOneWidget);
      },
    );

    testWidgets(
      'focusing an npub prefilled by a search link does not open it',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            initialLocation: SearchResultsPage.pathForQuery(
              npub,
              requestFocusOnMount: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Focusing moves the cursor, which notifies the controller without
        // the user having edited the query.
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        expect(find.text('profile:$npub'), findsNothing);
        expect(find.byType(SearchResultsPage), findsOneWidget);
      },
    );

    testWidgets('ordinary text stays in search', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.pumpAndSettle();

      expect(find.text('profile:$npub'), findsNothing);
      expect(find.byType(SearchResultsPage), findsOneWidget);
    });
  });
}
