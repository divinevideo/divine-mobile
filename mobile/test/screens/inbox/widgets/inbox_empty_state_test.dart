import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/widgets/inbox_empty_state.dart';

void main() {
  group(InboxEmptyState, () {
    group('renders', () {
      testWidgets('renders "No messages yet" text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: InboxEmptyState()),
          ),
        );

        expect(find.text('No messages yet'), findsOneWidget);
      });

      testWidgets('renders encouraging subtext', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: InboxEmptyState()),
          ),
        );

        expect(find.text("That + button won't bite."), findsOneWidget);
      });
    });
  });
}
