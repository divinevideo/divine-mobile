import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/search_results/widgets/lists_section.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';

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

      // Note: rendering PeopleListSearchCard in a test viewport triggers a
      // pre-existing layout bug in `UserAvatar(size: double.infinity)` inside
      // its AspectRatio collage. That is owned by the card widget, not this
      // section. We cover the behavior at two layers instead:
      //   - BLoC: `list_search_bloc_test.dart` verifies peopleResults are
      //     populated correctly from the repository.
      //   - Integration: `_PeopleListCard.onTap` is a compile-time no-op in
      //     `lists_section.dart` (see the comment "Intentionally disabled
      //     until public people-list routes include owner pubkey"), so the
      //     non-navigation guarantee is enforced structurally, not at runtime.
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
