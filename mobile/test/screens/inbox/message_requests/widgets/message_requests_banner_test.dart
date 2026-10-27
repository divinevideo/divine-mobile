// ABOUTME: Widget tests for MessageRequestsBanner.
// ABOUTME: Verifies count badge, semantics label, taps, and visibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/message_requests_banner.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  group(MessageRequestsBanner, () {
    group('renders', () {
      testWidgets('renders "Message requests" text', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(unreadCount: 5, onTap: () {}),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.inboxMessageRequestsTitle), findsOneWidget);
      });

      testWidgets('renders count badge with number', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(unreadCount: 42, onTap: () {}),
            ),
          ),
        );

        expect(find.text('42'), findsOneWidget);
      });

      testWidgets('hides count badge when unreadCount is 0', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(unreadCount: 0, onTap: () {}),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.inboxMessageRequestsTitle), findsOneWidget);
        expect(find.text('0'), findsNothing);
      });

      testWidgets('renders "99+" when count exceeds 99', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(unreadCount: 150, onTap: () {}),
            ),
          ),
        );

        expect(find.text('99+'), findsOneWidget);
      });
    });

    group('semantics', () {
      testWidgets('announces the unread count once', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(unreadCount: 3, onTap: () {}),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          tester.getSemantics(find.byType(MessageRequestsBanner)).label,
          equals(l10n.inboxMessageRequestsUnreadSemanticLabel(3)),
        );
        // The visible title must not surface as a second node either.
        expect(
          find.semantics.byLabel(
            RegExp(RegExp.escape(l10n.inboxMessageRequestsTitle)),
          ),
          findsOne,
        );
      });

      testWidgets('announces only the title when no request is unread', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(unreadCount: 0, onTap: () {}),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          tester.getSemantics(find.byType(MessageRequestsBanner)).label,
          equals(l10n.inboxMessageRequestsTitle),
        );
      });

      testWidgets('announces the exact count when the badge caps at 99+', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(unreadCount: 150, onTap: () {}),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          tester.getSemantics(find.byType(MessageRequestsBanner)).label,
          equals(l10n.inboxMessageRequestsUnreadSemanticLabel(150)),
        );
      });

      testWidgets('exposes the banner as a button', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(unreadCount: 3, onTap: () {}),
            ),
          ),
        );

        // The children are excluded, so this flag is the only button role.
        expect(
          tester.getSemantics(find.byType(MessageRequestsBanner)),
          isSemantics(isButton: true),
        );
      });
    });

    group('interactions', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(
                unreadCount: 3,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(MessageRequestsBanner));

        expect(tapped, isTrue);
      });

      testWidgets('calls onTap when activated by a screen reader', (
        tester,
      ) async {
        var tapped = false;

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: MessageRequestsBanner(
                unreadCount: 3,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        tester.semantics.tap(
          find.semantics.byLabel(
            l10n.inboxMessageRequestsUnreadSemanticLabel(3),
          ),
        );

        expect(tapped, isTrue);
      });
    });
  });
}
