import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/search_results/widgets/lists_section.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockListSearchBloc extends MockBloc<ListSearchEvent, ListSearchState>
    implements ListSearchBloc {}

// Full-length 64-char Nostr pubkey — never truncate.
const String _authorOne =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  group(ListsSection, () {
    late _MockListSearchBloc mockBloc;

    final now = DateTime(2024, 6, 15);
    final testList = CuratedList(
      id: 'cl1',
      name: 'Top Videos',
      pubkey: _authorOne,
      videoEventIds: const ['vid1'],
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      mockBloc = _MockListSearchBloc();
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 1000,
            child: BlocProvider<ListSearchBloc>.value(
              value: mockBloc,
              child: CustomScrollView(
                slivers: [ListsSection(showAll: showAll)],
              ),
            ),
          ),
        ),
      );
    }

    group('showAll: false (All tab preview)', () {
      testWidgets('hides entirely when success with empty results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ListSearchState(
            status: ListSearchStatus.success,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsNothing);
        expect(find.byType(SearchSectionEmptyState), findsNothing);
      });

      testWidgets('renders header and content when success with results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ListSearchState(
            status: ListSearchStatus.success,
            query: 'test',
            videoResults: [testList],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsOneWidget);
        expect(find.text('Lists'), findsOneWidget);
      });

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ListSearchState(
            status: ListSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SearchSectionErrorState), findsOneWidget);
      });
    });

    group('showAll: true (dedicated tab)', () {
      testWidgets(
        'renders $SearchSectionEmptyState when success with empty results',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ListSearchState(
              status: ListSearchStatus.success,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionEmptyState), findsOneWidget);
        },
      );

      testWidgets(
        'renders $SearchSectionErrorState on failure',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ListSearchState(
              status: ListSearchStatus.failure,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionErrorState), findsOneWidget);
        },
      );

      testWidgets(
        'renders a people result and navigates with the owner param',
        (tester) async {
          final goRouter = MockGoRouter();
          when(
            () => goRouter.push<Object?>(any()),
          ).thenAnswer((_) async => null);
          when(() => mockBloc.state).thenReturn(
            ListSearchState(
              status: ListSearchStatus.success,
              query: 'test',
              videoResults: [testList],
              peopleResults: [
                PeopleListSearchResult(
                  ownerPubkey: _authorOne,
                  list: UserList(
                    id: 'pl1',
                    name: 'Crew',
                    pubkeys: const [],
                    createdAt: now,
                    updatedAt: now,
                  ),
                ),
              ],
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [...getStandardTestOverrides()],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SizedBox(
                    width: 800,
                    height: 1000,
                    child: BlocProvider<ListSearchBloc>.value(
                      value: mockBloc,
                      child: MockGoRouterProvider(
                        goRouter: goRouter,
                        child: const CustomScrollView(
                          slivers: [ListsSection()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(DivineListThumbnail), findsNWidgets(2));
          expect(find.text('Crew'), findsOneWidget);

          await tester.tap(find.text('Crew'));

          verify(
            () => goRouter.push<Object?>('/people-lists/pl1?owner=$_authorOne'),
          ).called(1);
        },
      );
    });

    testWidgets('retry dispatches $ListSearchQueryChanged with current query', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(
        const ListSearchState(
          status: ListSearchStatus.failure,
          query: 'retry-test',
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(const ListSearchQueryChanged('retry-test')),
      ).called(1);
    });
  });
}
