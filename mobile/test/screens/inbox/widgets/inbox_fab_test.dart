import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/widgets/inbox_fab.dart';

void main() {
  group(InboxFab, () {
    group('renders', () {
      testWidgets('renders $DivineIcon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: InboxFab(onPressed: () {})),
          ),
        );

        expect(find.byType(DivineIcon), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var wasCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: InboxFab(onPressed: () => wasCalled = true)),
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();

        expect(wasCalled, isTrue);
      });
    });
  });
}
