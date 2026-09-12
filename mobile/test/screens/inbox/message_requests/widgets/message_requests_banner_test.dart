// ABOUTME: Widget tests for MessageRequestsBanner.
// ABOUTME: Verifies count badge, tap callback, and visibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/message_requests_banner.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  group(MessageRequestsBanner, () {
    group('renders', () {
      testWidgets('renders "Message requests" text', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(requestCount: 5, onTap: () {}),
            ),
          ),
        );

        expect(find.text('Message requests'), findsOneWidget);
      });

      testWidgets('renders count badge with number', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(requestCount: 42, onTap: () {}),
            ),
          ),
        );

        expect(find.text('42'), findsOneWidget);
      });

      testWidgets('hides count badge when requestCount is 0', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(requestCount: 0, onTap: () {}),
            ),
          ),
        );

        expect(find.text('Message requests'), findsOneWidget);
        expect(find.text('0'), findsNothing);
      });

      testWidgets('renders "99+" when count exceeds 99', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(requestCount: 150, onTap: () {}),
            ),
          ),
        );

        expect(find.text('99+'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(
                requestCount: 3,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(MessageRequestsBanner));

        expect(tapped, isTrue);
      });
    });
  });
}
