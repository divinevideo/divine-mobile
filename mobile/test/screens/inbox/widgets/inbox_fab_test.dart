import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/widgets/inbox_fab.dart';

import '../../../helpers/accessibility_guidelines.dart';

void main() {
  group(InboxFab, () {
    group('renders', () {
      testWidgets('renders $DivineIcon', (tester) async {
        await _pumpFab(tester);

        expect(find.byType(DivineIcon), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var wasCalled = false;

        await _pumpFab(tester, onPressed: () => wasCalled = true);

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();

        expect(wasCalled, isTrue);
      });
    });

    group('accessibility', () {
      const locale = Locale('de');
      final title = lookupAppLocalizations(locale).newMessageTitle;

      testWidgets('is a button named after the New message sheet', (
        tester,
      ) async {
        // A hardcoded English label could not pass this: the German title
        // must differ from the English one for the check to prove anything.
        expect(
          title,
          isNot(
            equals(lookupAppLocalizations(const Locale('en')).newMessageTitle),
          ),
        );

        final semantics = tester.ensureSemantics();
        try {
          await _pumpFab(tester, locale: locale);

          expect(
            tester.getSemantics(find.bySemanticsLabel(title)),
            isSemantics(label: title, isButton: true, hasTapAction: true),
          );
        } finally {
          semantics.dispose();
        }
      });

      testWidgets('keeps the plus icon out of the screen reader tree', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await _pumpFab(tester, locale: locale);

          expect(
            tester.getSemantics(find.bySemanticsLabel(title)),
            isSemantics(isImage: false),
          );
        } finally {
          semantics.dispose();
        }
      });

      testWidgets('activates through the accessibility tap action', (
        tester,
      ) async {
        var wasCalled = false;

        final semantics = tester.ensureSemantics();
        try {
          await _pumpFab(
            tester,
            locale: locale,
            onPressed: () => wasCalled = true,
          );

          tester.semantics.tap(find.semantics.byLabel(title));
          await tester.pump();

          expect(wasCalled, isTrue);
        } finally {
          semantics.dispose();
        }
      });

      testWidgets('meets the labeled tap target guideline', (tester) async {
        await _pumpFab(tester, locale: locale);

        await expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: divineSemanticsGuidelines,
        );
      });
    });
  });
}

Future<void> _pumpFab(
  WidgetTester tester, {
  Locale? locale,
  VoidCallback? onPressed,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: InboxFab(onPressed: onPressed ?? () {})),
      ),
    ),
  );
}
