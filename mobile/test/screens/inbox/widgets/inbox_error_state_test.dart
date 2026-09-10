// ABOUTME: Widget tests for InboxErrorState.
// ABOUTME: Verifies error copy renders and the retry button fires onRetry.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/widgets/inbox_error_state.dart';

void main() {
  group(InboxErrorState, () {
    Widget buildSubject({required VoidCallback onRetry}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: InboxErrorState(onRetry: onRetry)),
      );
    }

    testWidgets('renders error title and subtitle', (tester) async {
      await tester.pumpWidget(buildSubject(onRetry: () {}));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.inboxLoadErrorTitle), findsOneWidget);
      expect(find.text(l10n.inboxLoadErrorSubtitle), findsOneWidget);
    });

    testWidgets('calls onRetry when retry button is tapped', (tester) async {
      var retried = false;
      await tester.pumpWidget(buildSubject(onRetry: () => retried = true));

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
