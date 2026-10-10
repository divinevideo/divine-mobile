// ABOUTME: PROTOTYPE (#8076) — proves the four-tab screen renders and that
// ABOUTME: request content stays concealed until the user opens it.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tabs_prototype_screen.dart';

import '../../helpers/test_provider_overrides.dart';

void main() {
  group(DmInboxTabsPrototypeScreen, () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        testMaterialApp(home: const DmInboxTabsPrototypeScreen()),
      );
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('shows all four tabs', (tester) async {
        await pumpScreen(tester);

        expect(find.text('Inbox'), findsWidgets);
        expect(find.text('Official'), findsOneWidget);
        expect(find.text('Requests'), findsOneWidget);
        expect(find.text('Likely spam'), findsOneWidget);
      });

      testWidgets('opens on Inbox with consented conversations', (
        tester,
      ) async {
        await pumpScreen(tester);

        expect(find.text('Maya Okonkwo'), findsOneWidget);
        expect(find.text('crypto_signals_daily'), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('conceals request content until the row is opened', (
        tester,
      ) async {
        await pumpScreen(tester);
        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle();

        expect(find.text('Priya Raman'), findsOneWidget);
        expect(find.textContaining('Lisbon'), findsNothing);
        expect(find.text('Message hidden until you open it'), findsWidgets);

        await tester.tap(find.text('Priya Raman'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Lisbon'), findsOneWidget);
      });

      testWidgets('shows official messages unconcealed and unblockable', (
        tester,
      ) async {
        await pumpScreen(tester);
        await tester.tap(find.text('Official'));
        await tester.pumpAndSettle();

        expect(find.text('Divine Support'), findsOneWidget);
        expect(find.textContaining('report you filed'), findsOneWidget);
        expect(
          find.textContaining('cannot be blocked'),
          findsWidgets,
        );
        expect(find.text('Liz · Divine team'), findsOneWidget);
        expect(find.text('Reportable · blockable'), findsWidgets);
      });
    });
  });
}
