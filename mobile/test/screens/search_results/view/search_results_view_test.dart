import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';

class _MockSearchResultsFilterCubit extends MockCubit<SearchResultsFilter>
    implements SearchResultsFilterCubit {}

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

class _MockHashtagSearchBloc
    extends MockBloc<HashtagSearchEvent, HashtagSearchState>
    implements HashtagSearchBloc {}

class _MockListSearchBloc extends MockBloc<ListSearchEvent, ListSearchState>
    implements ListSearchBloc {}

void main() {
  group(SearchResultsView, () {
    late _MockSearchResultsFilterCubit mockFilterCubit;
    late _MockVideoSearchBloc mockVideoBloc;
    late _MockUserSearchBloc mockUserBloc;
    late _MockHashtagSearchBloc mockHashtagBloc;
    late _MockListSearchBloc mockListBloc;
    late TextEditingController controller;

    setUp(() {
      mockFilterCubit = _MockSearchResultsFilterCubit();
      mockVideoBloc = _MockVideoSearchBloc();
      mockUserBloc = _MockUserSearchBloc();
      mockHashtagBloc = _MockHashtagSearchBloc();
      mockListBloc = _MockListSearchBloc();
      controller = TextEditingController();

      // Default to a non-idle video state so the filter switch is exercised.
      // Individual idle-state tests override this to `initial`.
      when(() => mockVideoBloc.state).thenReturn(
        const VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'test',
        ),
      );
      when(() => mockUserBloc.state).thenReturn(const UserSearchState());
      when(() => mockHashtagBloc.state).thenReturn(const HashtagSearchState());
      when(() => mockListBloc.state).thenReturn(const ListSearchState());
    });

    tearDown(() {
      mockFilterCubit.close();
      mockVideoBloc.close();
      mockUserBloc.close();
      mockHashtagBloc.close();
      mockListBloc.close();
      controller.dispose();
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SearchResultsFilterCubit>.value(
              value: mockFilterCubit,
            ),
            BlocProvider<VideoSearchBloc>.value(value: mockVideoBloc),
            BlocProvider<UserSearchBloc>.value(value: mockUserBloc),
            BlocProvider<HashtagSearchBloc>.value(value: mockHashtagBloc),
            BlocProvider<ListSearchBloc>.value(value: mockListBloc),
          ],
          child: Scaffold(body: SearchResultsView(controller: controller)),
        ),
      );
    }

    // Each of these tests exercises filter routing only. Sections render
    // zero-extent content for the mocked BLoC states, so the finders use
    // `skipOffstage: false` to assert widget presence in the tree rather
    // than visible rendering.
    testWidgets('renders all sections when filter is all', (tester) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection, skipOffstage: false), findsOneWidget);
      expect(find.byType(ListsSection, skipOffstage: false), findsOneWidget);
      expect(find.byType(TagsSection, skipOffstage: false), findsOneWidget);
      expect(find.byType(VideosSection, skipOffstage: false), findsOneWidget);
    });

    testWidgets('renders only $PeopleSection when filter is people', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.people);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection, skipOffstage: false), findsOneWidget);
      expect(find.byType(TagsSection, skipOffstage: false), findsNothing);
      expect(find.byType(ListsSection, skipOffstage: false), findsNothing);
      expect(find.byType(VideosSection, skipOffstage: false), findsNothing);
    });

    testWidgets('renders only $TagsSection when filter is tags', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.tags);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection, skipOffstage: false), findsNothing);
      expect(find.byType(TagsSection, skipOffstage: false), findsOneWidget);
      expect(find.byType(ListsSection, skipOffstage: false), findsNothing);
      expect(find.byType(VideosSection, skipOffstage: false), findsNothing);
    });

    testWidgets('renders only $VideosSection when filter is videos', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.videos);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection, skipOffstage: false), findsNothing);
      expect(find.byType(TagsSection, skipOffstage: false), findsNothing);
      expect(find.byType(ListsSection, skipOffstage: false), findsNothing);
      expect(find.byType(VideosSection, skipOffstage: false), findsOneWidget);
    });

    testWidgets('renders only $ListsSection when filter is lists', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.lists);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection, skipOffstage: false), findsNothing);
      expect(find.byType(TagsSection, skipOffstage: false), findsNothing);
      expect(find.byType(ListsSection, skipOffstage: false), findsOneWidget);
      expect(find.byType(VideosSection, skipOffstage: false), findsNothing);
    });

    testWidgets('renders $ColoredBox with surface background', (tester) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == VineTheme.surfaceBackground,
        ),
        findsOneWidget,
      );
    });

    group('idle state', () {
      setUp(() {
        when(() => mockVideoBloc.state).thenReturn(const VideoSearchState());
      });

      testWidgets(
        'renders $SearchSectionInitialState when video search is idle',
        (tester) async {
          when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
          await tester.pumpWidget(buildSubject());

          expect(find.byType(SearchSectionInitialState), findsOneWidget);
          expect(find.text('Enter a search query'), findsOneWidget);
          expect(find.text('Discover something interesting'), findsOneWidget);
        },
      );

      testWidgets(
        'hides all sections when idle regardless of selected filter',
        (tester) async {
          when(
            () => mockFilterCubit.state,
          ).thenReturn(SearchResultsFilter.videos);
          await tester.pumpWidget(buildSubject());

          expect(find.byType(VideosSection), findsNothing);
          expect(find.byType(PeopleSection), findsNothing);
          expect(find.byType(TagsSection), findsNothing);
          expect(find.byType(ListsSection), findsNothing);
          expect(find.byType(SearchSectionInitialState), findsOneWidget);
        },
      );
    });

    // Regression coverage for #3802: when navigated from Explore on
    // partial input the route arg is non-empty but the BLoCs are still in
    // `initial` for ~300ms while the AppBar's synchronous initState
    // dispatch propagates through their debounceRestartable transformer.
    // The view must NOT render the empty-query idle placeholder during
    // that window — sections (with their own skeletons) should render
    // instead. The view reads the live controller text, so we seed the
    // controller (mirroring what [SearchResultsPage] does on mount) and
    // the gate stays closed.
    group('with non-empty search field text', () {
      setUp(() {
        when(() => mockVideoBloc.state).thenReturn(const VideoSearchState());
        when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      });

      testWidgets(
        'does NOT render $SearchSectionInitialState even when status is '
        'initial',
        (tester) async {
          controller.text = 'hello';
          await tester.pumpWidget(buildSubject());

          expect(find.byType(SearchSectionInitialState), findsNothing);
        },
      );

      testWidgets('renders the all-filter section list instead', (
        tester,
      ) async {
        controller.text = 'hello';
        await tester.pumpWidget(buildSubject());

        expect(find.byType(PeopleSection, skipOffstage: false), findsOneWidget);
        expect(find.byType(ListsSection, skipOffstage: false), findsOneWidget);
        expect(find.byType(TagsSection, skipOffstage: false), findsOneWidget);
        expect(find.byType(VideosSection, skipOffstage: false), findsOneWidget);
      });

      // Regression guard for the whitespace-only edge case reachable via
      // deep / universal links such as `/search-results/%20%20`. The
      // BLoCs would trim such a query down to `''` and stay in `initial`;
      // the view must keep showing the idle placeholder so we don't land
      // on indefinitely-loading section skeletons (a #3023-class bug).
      testWidgets(
        'shows the idle placeholder when search field is whitespace-only',
        (tester) async {
          controller.text = '   ';
          await tester.pumpWidget(buildSubject());

          expect(find.byType(SearchSectionInitialState), findsOneWidget);
        },
      );

      // Same regression guard for sub-min-length queries (e.g. a 1-char
      // deep link `/search-results/a`). The BLoC handlers gate on
      // `minSearchQueryLength` (2), so anything shorter never advances
      // out of `initial` and the view must surface the idle placeholder.
      testWidgets(
        'shows the idle placeholder when search field is shorter than '
        'minSearchQueryLength',
        (tester) async {
          controller.text = 'a';
          await tester.pumpWidget(buildSubject());

          expect(find.byType(SearchSectionInitialState), findsOneWidget);
        },
      );
    });

    // Regression coverage for PR #4290 review feedback: after landing on
    // /search-results/hello and the BLoCs returning to `initial` (which
    // happens whenever the user clears the field or shortens it below
    // [minSearchQueryLength]), the view must flip back to the idle
    // placeholder. The old gate keyed on the immutable route arg and
    // therefore stayed `false`, regressing the #3023 "infinite skeleton"
    // symptom in the post-mount edit path.
    group('field-edit transitions after mounting with a prefilled query', () {
      testWidgets(
        'shows idle placeholder when the cleared field meets a reset BLoC',
        (tester) async {
          // Simulate the resting state after the user has cleared the
          // field on a previously-prefilled mount: controller is empty
          // and the BLoCs have already reset to `initial`.
          controller.text = '';
          when(() => mockVideoBloc.state).thenReturn(const VideoSearchState());
          when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);

          await tester.pumpWidget(buildSubject());

          expect(find.byType(SearchSectionInitialState), findsOneWidget);
        },
      );

      testWidgets(
        'shows idle placeholder when a sub-min-length field meets a reset '
        'BLoC',
        (tester) async {
          controller.text = 'h';
          when(() => mockVideoBloc.state).thenReturn(const VideoSearchState());
          when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);

          await tester.pumpWidget(buildSubject());

          expect(find.byType(SearchSectionInitialState), findsOneWidget);
        },
      );

      testWidgets(
        'flips from sections to idle when text is cleared and the BLoC '
        'resets',
        (tester) async {
          // Start in the post-results state: prefilled `hello` with the
          // BLoC sitting on a successful result set.
          controller.text = 'hello';
          when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
          final stateController = StreamController<VideoSearchState>();
          addTearDown(stateController.close);
          whenListen(
            mockVideoBloc,
            stateController.stream,
            initialState: const VideoSearchState(
              status: VideoSearchStatus.success,
              query: 'hello',
            ),
          );

          await tester.pumpWidget(buildSubject());
          expect(find.byType(SearchSectionInitialState), findsNothing);

          // User clears the field; the BLoC's empty/short-query branch
          // emits `const VideoSearchState()` (status: initial, query: '').
          controller.clear();
          stateController.add(const VideoSearchState());
          await tester.pump();

          expect(find.byType(SearchSectionInitialState), findsOneWidget);
        },
      );
    });
  });
}
