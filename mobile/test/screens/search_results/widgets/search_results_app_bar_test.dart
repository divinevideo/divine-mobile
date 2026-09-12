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
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_pill.dart';
import 'package:openvine/screens/search_results/widgets/search_results_app_bar.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockSearchResultsFilterCubit extends MockCubit<SearchResultsFilter>
    implements SearchResultsFilterCubit {}

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

class _MockHashtagSearchBloc
    extends MockBloc<HashtagSearchEvent, HashtagSearchState>
    implements HashtagSearchBloc {}

class _MockListSearchBloc extends MockBloc<ListSearchEvent, ListSearchState>
    implements ListSearchBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const VideoSearchQueryChanged(''));
    registerFallbackValue(const UserSearchQueryChanged(''));
    registerFallbackValue(const HashtagSearchQueryChanged(''));
    registerFallbackValue(const ListSearchQueryChanged(''));
  });

  group(SearchResultsAppBar, () {
    late _MockSearchResultsFilterCubit mockFilterCubit;
    late _MockUserSearchBloc mockUserSearchBloc;
    late _MockVideoSearchBloc mockVideoSearchBloc;
    late _MockHashtagSearchBloc mockHashtagSearchBloc;
    late _MockListSearchBloc mockListSearchBloc;

    setUp(() {
      mockFilterCubit = _MockSearchResultsFilterCubit();
      mockUserSearchBloc = _MockUserSearchBloc();
      mockVideoSearchBloc = _MockVideoSearchBloc();
      mockHashtagSearchBloc = _MockHashtagSearchBloc();
      mockListSearchBloc = _MockListSearchBloc();

      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      when(() => mockUserSearchBloc.state).thenReturn(const UserSearchState());
      when(
        () => mockVideoSearchBloc.state,
      ).thenReturn(const VideoSearchState());
      when(
        () => mockHashtagSearchBloc.state,
      ).thenReturn(const HashtagSearchState());
      when(() => mockListSearchBloc.state).thenReturn(const ListSearchState());
    });

    Widget createTestWidget({
      String initialQuery = 'test',
      bool requestFocusOnMount = false,
    }) {
      final controller = TextEditingController(text: initialQuery);
      addTearDown(controller.dispose);
      return testMaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SearchResultsFilterCubit>.value(
              value: mockFilterCubit,
            ),
            BlocProvider<UserSearchBloc>.value(value: mockUserSearchBloc),
            BlocProvider<VideoSearchBloc>.value(value: mockVideoSearchBloc),
            BlocProvider<HashtagSearchBloc>.value(value: mockHashtagSearchBloc),
            BlocProvider<ListSearchBloc>.value(value: mockListSearchBloc),
          ],
          child: Scaffold(
            body: SearchResultsAppBar(
              controller: controller,
              initialQuery: initialQuery,
              requestFocusOnMount: requestFocusOnMount,
            ),
          ),
        ),
        mockAuthService: createMockAuthService(),
      );
    }

    testWidgets('renders $SearchFilterPill', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(SearchFilterPill), findsOneWidget);
    });

    testWidgets('renders search bar with initial query', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('anchors the field and the back button for UI tests', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(
        find.bySemanticsIdentifier(SemanticIds.searchField),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(SemanticIds.searchBackButton),
        findsOneWidget,
      );
    });

    testWidgets(
      'keeps keyboard dismissed for a prefilled query by default',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));

        expect(textField.focusNode?.hasFocus, isFalse);
      },
    );

    testWidgets(
      'requests focus for a prefilled query when the route opts in',
      (tester) async {
        await tester.pumpWidget(createTestWidget(requestFocusOnMount: true));
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));

        expect(textField.focusNode?.hasFocus, isTrue);
      },
    );

    testWidgets('still focuses the empty query state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialQuery: ''),
      );
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));

      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets(
      'dispatches *QueryChanged synchronously when initialQuery is non-empty',
      (tester) async {
        await tester.pumpWidget(createTestWidget(initialQuery: 'hello'));
        // One pump — synchronous initState dispatch, no debounce elapsed yet.
        await tester.pump();

        verify(
          () => mockVideoSearchBloc.add(const VideoSearchQueryChanged('hello')),
        ).called(1);
        verify(
          () => mockUserSearchBloc.add(const UserSearchQueryChanged('hello')),
        ).called(1);
        verify(
          () => mockHashtagSearchBloc.add(
            const HashtagSearchQueryChanged('hello'),
          ),
        ).called(1);
        verify(
          () => mockListSearchBloc.add(const ListSearchQueryChanged('hello')),
        ).called(1);
      },
    );

    testWidgets(
      'does NOT dispatch *QueryChanged synchronously when initialQuery is empty',
      (tester) async {
        await tester.pumpWidget(createTestWidget(initialQuery: ''));
        await tester.pump();

        verifyNever(() => mockVideoSearchBloc.add(any()));
        verifyNever(() => mockUserSearchBloc.add(any()));
        verifyNever(() => mockHashtagSearchBloc.add(any()));
        verifyNever(() => mockListSearchBloc.add(any()));
      },
    );

    testWidgets(
      'does not double-dispatch the prefilled query: the listener is attached '
      'after the controller seed so it never fires for the initial value',
      (tester) async {
        await tester.pumpWidget(createTestWidget(initialQuery: 'hello'));
        // Pump a small window to catch any spurious follow-up dispatch the
        // listener might produce from the parent's pre-seeded controller
        // text — there should be none.
        await tester.pump(const Duration(milliseconds: 350));

        verify(
          () => mockVideoSearchBloc.add(const VideoSearchQueryChanged('hello')),
        ).called(1);
        verify(
          () => mockUserSearchBloc.add(const UserSearchQueryChanged('hello')),
        ).called(1);
        verify(
          () => mockHashtagSearchBloc.add(
            const HashtagSearchQueryChanged('hello'),
          ),
        ).called(1);
        verify(
          () => mockListSearchBloc.add(const ListSearchQueryChanged('hello')),
        ).called(1);
      },
    );

    testWidgets(
      'dispatches *QueryChanged immediately when the user types (no UI '
      "debounce stacked on top of the BLoCs' own debounceRestartable)",
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<SearchResultsFilterCubit>.value(
                  value: mockFilterCubit,
                ),
                BlocProvider<UserSearchBloc>.value(value: mockUserSearchBloc),
                BlocProvider<VideoSearchBloc>.value(value: mockVideoSearchBloc),
                BlocProvider<HashtagSearchBloc>.value(
                  value: mockHashtagSearchBloc,
                ),
                BlocProvider<ListSearchBloc>.value(value: mockListSearchBloc),
              ],
              child: Scaffold(
                body: SearchResultsAppBar(
                  controller: controller,
                  initialQuery: '',
                ),
              ),
            ),
            mockAuthService: createMockAuthService(),
          ),
        );
        await tester.pump();

        // Sanity: empty initialQuery means no synchronous initial dispatch.
        verifyNever(() => mockVideoSearchBloc.add(any()));

        controller.text = 'ab';
        // No pump duration — the dispatch must happen on the same frame
        // the controller fires its listener.
        await tester.pump();

        verify(
          () => mockVideoSearchBloc.add(const VideoSearchQueryChanged('ab')),
        ).called(1);
        verify(
          () => mockUserSearchBloc.add(const UserSearchQueryChanged('ab')),
        ).called(1);
        verify(
          () =>
              mockHashtagSearchBloc.add(const HashtagSearchQueryChanged('ab')),
        ).called(1);
        verify(
          () => mockListSearchBloc.add(const ListSearchQueryChanged('ab')),
        ).called(1);
      },
    );

    testWidgets(
      'dispatches *QueryChanged immediately when the user clears a prefilled '
      'query (so BLoCs reset to initial without a 600ms UI+BLoC stack)',
      (tester) async {
        final controller = TextEditingController(text: 'hello');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<SearchResultsFilterCubit>.value(
                  value: mockFilterCubit,
                ),
                BlocProvider<UserSearchBloc>.value(value: mockUserSearchBloc),
                BlocProvider<VideoSearchBloc>.value(value: mockVideoSearchBloc),
                BlocProvider<HashtagSearchBloc>.value(
                  value: mockHashtagSearchBloc,
                ),
                BlocProvider<ListSearchBloc>.value(value: mockListSearchBloc),
              ],
              child: Scaffold(
                body: SearchResultsAppBar(
                  controller: controller,
                  initialQuery: 'hello',
                ),
              ),
            ),
            mockAuthService: createMockAuthService(),
          ),
        );
        await tester.pump();

        // The synchronous initState dispatch fired once.
        verify(
          () => mockVideoSearchBloc.add(const VideoSearchQueryChanged('hello')),
        ).called(1);

        controller.clear();
        // No pump duration — the empty-string dispatch must land on the
        // same frame as the controller's clear.
        await tester.pump();

        verify(
          () => mockVideoSearchBloc.add(const VideoSearchQueryChanged('')),
        ).called(1);
        verify(
          () => mockUserSearchBloc.add(const UserSearchQueryChanged('')),
        ).called(1);
        verify(
          () => mockHashtagSearchBloc.add(const HashtagSearchQueryChanged('')),
        ).called(1);
        verify(
          () => mockListSearchBloc.add(const ListSearchQueryChanged('')),
        ).called(1);
      },
    );

    Widget createBackButtonSubject(MockGoRouter goRouter) {
      final controller = TextEditingController(text: 'test');
      addTearDown(controller.dispose);
      return testMaterialApp(
        home: MockGoRouterProvider(
          goRouter: goRouter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<SearchResultsFilterCubit>.value(
                value: mockFilterCubit,
              ),
              BlocProvider<UserSearchBloc>.value(value: mockUserSearchBloc),
              BlocProvider<VideoSearchBloc>.value(value: mockVideoSearchBloc),
              BlocProvider<HashtagSearchBloc>.value(
                value: mockHashtagSearchBloc,
              ),
              BlocProvider<ListSearchBloc>.value(value: mockListSearchBloc),
            ],
            child: Scaffold(
              body: SearchResultsAppBar(
                controller: controller,
                initialQuery: 'test',
              ),
            ),
          ),
        ),
        mockAuthService: createMockAuthService(),
      );
    }

    // Scope to the back button by its icon so the finder stays unambiguous if
    // a DivineIconButton is later added to DivineSearchBar/SearchFilterPill.
    final backButtonFinder = find.byWidgetPredicate(
      (widget) =>
          widget is DivineIconButton && widget.icon == DivineIconName.caretLeft,
    );

    testWidgets('back button pops when there is a route to pop', (
      tester,
    ) async {
      final goRouter = MockGoRouter();
      when(goRouter.canPop).thenReturn(true);
      when(() => goRouter.pop<Object?>()).thenReturn(null);

      await tester.pumpWidget(createBackButtonSubject(goRouter));
      await tester.pump();

      await tester.tap(backButtonFinder);
      await tester.pump();

      verify(() => goRouter.pop<Object?>()).called(1);
      verifyNever(() => goRouter.go(any()));
    });

    testWidgets(
      'back button falls back to Explore when the back stack is empty '
      '(reached via context.go or a cold-start deep link)',
      (tester) async {
        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(false);
        when(() => goRouter.go(any())).thenReturn(null);

        await tester.pumpWidget(createBackButtonSubject(goRouter));
        await tester.pump();

        await tester.tap(backButtonFinder);
        await tester.pump();

        verify(() => goRouter.go(ExploreScreen.path)).called(1);
        verifyNever(() => goRouter.pop<Object?>());
      },
    );
  });
}
