import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_sheet.dart';

class _MockSearchResultsFilterCubit extends MockCubit<SearchResultsFilter>
    implements SearchResultsFilterCubit {}

void main() {
  group(SearchFilterSheet, () {
    late _MockSearchResultsFilterCubit mockCubit;

    setUpAll(() {
      registerFallbackValue(SearchResultsFilter.all);
    });

    setUp(() {
      mockCubit = _MockSearchResultsFilterCubit();
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
    });

    tearDown(() {
      mockCubit.close();
    });

    Widget buildSubject({required Widget child}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<SearchResultsFilterCubit>.value(
            value: mockCubit,
            child: child,
          ),
        ),
      );
    }

    testWidgets('shows all filter options', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SearchFilterSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
    });

    testWidgets('shows checkmark on current filter', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.people);

      await tester.pumpWidget(
        buildSubject(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SearchFilterSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The checkmark icon should be present for the selected option.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon && widget.icon == DivineIconName.check,
        ),
        findsOneWidget,
      );
    });

    testWidgets('calls filterChanged when option is selected', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SearchFilterSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();

      verify(
        () => mockCubit.filterChanged(SearchResultsFilter.people),
      ).called(1);
    });

    testWidgets('does not call filterChanged when dismissed', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SearchFilterSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dismiss by tapping the barrier.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      verifyNever(() => mockCubit.filterChanged(any()));
    });
  });
}
