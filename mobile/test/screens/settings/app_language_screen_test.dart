// ABOUTME: Widget tests for AppLanguageScreen locale picker
// ABOUTME: Verifies all locales render, tap interactions, and radio state

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';

import '../../helpers/scroll.dart';

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

void main() {
  group(AppLanguageScreen, () {
    late _MockLocaleCubit localeCubit;

    setUp(() {
      localeCubit = _MockLocaleCubit();
      when(() => localeCubit.state).thenReturn(const LocaleState());
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(scaffoldBackgroundColor: VineTheme.backgroundColor),
        home: BlocProvider<LocaleCubit>.value(
          value: localeCubit,
          child: const AppLanguageScreen(),
        ),
      );
    }

    Future<ListTile> findLocaleTile(
      WidgetTester tester,
      String nativeName,
    ) async {
      final tileFinder = find.widgetWithText(ListTile, nativeName);
      await scrollUntilTappable(
        tester,
        tileFinder,
        160,
        scrollable: find.byType(Scrollable),
      );
      return tester.widget<ListTile>(tileFinder);
    }

    testWidgets('renders Device default tile', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Use device language'), findsOneWidget);
    });

    testWidgets('tapping a locale tile calls setLocale with its code', (
      tester,
    ) async {
      when(() => localeCubit.setLocale(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await findLocaleTile(tester, 'Español');
      await tester.tap(find.widgetWithText(ListTile, 'Español'));
      await tester.pumpAndSettle();

      verify(() => localeCubit.setLocale('es')).called(1);
    });

    testWidgets('tapping Device default tile calls clearLocale', (
      tester,
    ) async {
      when(() => localeCubit.clearLocale()).thenAnswer((_) async {});

      when(
        () => localeCubit.state,
      ).thenReturn(const LocaleState(locale: Locale('es')));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use device language'));
      await tester.pumpAndSettle();

      verify(() => localeCubit.clearLocale()).called(1);
    });

    testWidgets('marks the current locale as selected', (tester) async {
      when(
        () => localeCubit.state,
      ).thenReturn(const LocaleState(locale: Locale('fr')));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final frenchTile = await findLocaleTile(tester, 'Français');
      expect(frenchTile.selected, isTrue);
      expect((frenchTile.trailing! as DivineIcon).icon, DivineIconName.check);
    });

    testWidgets('leaves a non-current locale unmarked', (tester) async {
      when(
        () => localeCubit.state,
      ).thenReturn(const LocaleState(locale: Locale('fr')));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Use Deutsch instead of English — English appears twice (device
      // default subtitle + locale list tile), making the finder ambiguous.
      final deutschTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Deutsch'),
      );
      expect(deutschTile.selected, isFalse);
      expect(deutschTile.trailing, isNull);
    });

    testWidgets('renders visible locale tiles from supportedLocales', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // ListView is lazy, and the full suite can run this file after tests
      // that change the global test viewport. Scroll to each sample locale so
      // this remains independent of the current viewport height.
      await findLocaleTile(tester, 'Deutsch');
      await findLocaleTile(tester, 'Español');
      await findLocaleTile(tester, 'Français');
    });
  });
}
