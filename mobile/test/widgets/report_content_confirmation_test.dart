// ABOUTME: Tests for the report sheet's post-submission confirmation state.
// ABOUTME: Pins the safety-link semantics so the URL is announced once.

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/report_content_confirmation.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Widget buildSubject({bool moderationDmFailed = false}) => MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ReportConfirmationBody(moderationDmFailed: moderationDmFailed),
    ),
  );

  group(ReportConfirmationBody, () {
    testWidgets('renders the thank-you copy', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportReceivedThankYou), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsNothing);
    });

    testWidgets('surfaces the delayed-DM notice when the DM failed', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(moderationDmFailed: true));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('safety link is a button that announces its label once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final link = tester.getSemantics(
        find.textContaining(l10n.reportSafetyUrl),
      );

      // A `label:` on the Semantics annotation is prepended to the child
      // Text's own label rather than replacing it, so a redundant one makes
      // a screen reader read the URL twice.
      expect(link.label, '${l10n.reportLearnMoreAt} ${l10n.reportSafetyUrl}');
      expect(link.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(link.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });
  });
}
