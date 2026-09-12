import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_pill.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockSearchResultsFilterCubit extends MockCubit<SearchResultsFilter>
    implements SearchResultsFilterCubit {}

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

void main() {
  group(SearchFilterPill, () {
    late _MockSearchResultsFilterCubit mockCubit;
    late _MockVideoSearchBloc mockVideoSearchBloc;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      mockCubit = _MockSearchResultsFilterCubit();
      mockVideoSearchBloc = _MockVideoSearchBloc();
      when(
        () => mockVideoSearchBloc.state,
      ).thenReturn(const VideoSearchState());
    });

    tearDown(() {
      mockCubit.close();
      mockVideoSearchBloc.close();
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<SearchResultsFilterCubit>.value(value: mockCubit),
              BlocProvider<VideoSearchBloc>.value(value: mockVideoSearchBloc),
            ],
            child: const SearchFilterPill(),
          ),
        ),
      );
    }

    testWidgets('renders "All" label when filter is all', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('anchors the pill for UI tests', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(
        find.bySemanticsIdentifier(SemanticIds.searchFilterPill),
        findsOneWidget,
      );
    });

    testWidgets('renders "People" label when filter is people', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.people);
      await tester.pumpWidget(buildSubject());

      expect(find.text('People'), findsOneWidget);
    });

    testWidgets('renders "Tags" label when filter is tags', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.tags);
      await tester.pumpWidget(buildSubject());

      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('renders "Videos" label when filter is videos', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.videos);
      await tester.pumpWidget(buildSubject());

      expect(find.text('Videos'), findsOneWidget);
    });

    testWidgets('does not render caret down icon for non-video filters', (
      tester,
    ) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('renders selected video sort label when filter is videos', (
      tester,
    ) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.videos);
      when(
        () => mockVideoSearchBloc.state,
      ).thenReturn(const VideoSearchState(sort: VideoSearchSort.recent));

      await tester.pumpWidget(buildSubject());

      expect(find.text('Videos'), findsOneWidget);
      expect(find.text(l10n.searchVideosSortRecent), findsOneWidget);
    });

    testWidgets('dispatches $VideoSearchSortChanged after selecting sort', (
      tester,
    ) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.videos);
      when(
        () => mockVideoSearchBloc.state,
      ).thenReturn(const VideoSearchState());

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text(l10n.searchVideosSortTrending));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.searchVideosSortRecent));
      await tester.pumpAndSettle();

      verify(
        () => mockVideoSearchBloc.add(
          const VideoSearchSortChanged(VideoSearchSort.recent),
        ),
      ).called(1);
    });

    testWidgets('opens bottom sheet on tap', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(SearchFilterPill));
      await tester.pumpAndSettle();

      // The VineBottomSheetSelectionMenu shows option labels.
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
    });

    testWidgets('has correct semantics', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Filter: All' &&
              w.properties.button == true,
        ),
        findsOneWidget,
      );
    });
  });
}
