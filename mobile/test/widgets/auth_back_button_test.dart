// ABOUTME: Tests for AuthBackButton widget
// ABOUTME: Verifies icon rendering and custom onPressed callback

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';

import '../helpers/go_router.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group(AuthBackButton, () {
    group('renders', () {
      testWidgets('displays $RoundedIconButton', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const Scaffold(body: AuthBackButton(onPressed: _noop)),
          ),
        );

        expect(find.byType(RoundedIconButton), findsOneWidget);
      });

      testWidgets('displays chevron_left icon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const Scaffold(body: AuthBackButton(onPressed: _noop)),
          ),
        );

        expect(_divineIcon(DivineIconName.caretLeft), findsOneWidget);
      });

      testWidgets('uses vineGreenLight color for icon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const Scaffold(body: AuthBackButton(onPressed: _noop)),
          ),
        );

        final icon = tester.widget<DivineIcon>(
          _divineIcon(DivineIconName.caretLeft),
        );
        expect(icon.color, equals(VineTheme.vineGreenLight));
      });
    });

    group('interactions', () {
      testWidgets('calls custom onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: Scaffold(
              body: AuthBackButton(onPressed: () => tapped = true),
            ),
          ),
        );

        await tester.tap(find.byType(RoundedIconButton));
        expect(tapped, isTrue);
      });

      testWidgets('does not call GoRouter.pop when there is nothing to pop', (
        tester,
      ) async {
        final mockGoRouter = MockGoRouter();
        when(mockGoRouter.canPop).thenReturn(false);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: const Scaffold(body: AuthBackButton()),
            ),
          ),
        );

        await tester.tap(find.byType(RoundedIconButton));
        await tester.pump();

        expect(tester.takeException(), isNull);
        verify(mockGoRouter.canPop).called(1);
        verifyNever(() => mockGoRouter.pop<dynamic>(any()));
      });
    });
  });
}

void _noop() {}
