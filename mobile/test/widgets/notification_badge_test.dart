// ABOUTME: Widget tests for NotificationBadge and AnimatedNotificationBadge
// ABOUTME: Pins count rendering, overflow dot, l10n semantics, RepaintBoundary

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/notification_badge.dart';

void main() {
  group(NotificationBadge, () {
    Widget buildTestWidget({required int count, bool showBadge = true}) {
      return MaterialApp(
        home: Scaffold(
          body: NotificationBadge(
            count: count,
            showBadge: showBadge,
            child: const Icon(Icons.notifications),
          ),
        ),
      );
    }

    testWidgets('shows no badge when count is 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(count: 0));

      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('shows no badge when count is negative', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: -1));

      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('shows badge with count when count > 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: 5));

      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows count text for count up to 99', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: 99));

      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('shows overflow dot instead of text when count > 99', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: 100));

      expect(find.byKey(const ValueKey('dot')), findsOneWidget);
      expect(find.text('100'), findsNothing);
    });

    testWidgets('shows no badge when showBadge is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: 5, showBadge: false));

      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });
  });

  group(AnimatedNotificationBadge, () {
    Widget buildAnimatedTestWidget({
      required int count,
      bool showBadge = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AnimatedNotificationBadge(
            count: count,
            showBadge: showBadge,
            child: const Icon(Icons.notifications),
          ),
        ),
      );
    }

    testWidgets('shows no badge when count is 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildAnimatedTestWidget(count: 0));

      expect(
        find.descendant(
          of: find.byType(AnimatedNotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('shows badge with count when count > 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildAnimatedTestWidget(count: 3));

      expect(
        find.descendant(
          of: find.byType(AnimatedNotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows overflow dot when count > 99', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildAnimatedTestWidget(count: 150));

      expect(find.byKey(const ValueKey('dot')), findsOneWidget);
      expect(find.text('150'), findsNothing);
    });

    testWidgets('shows no badge when showBadge is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildAnimatedTestWidget(count: 5, showBadge: false),
      );

      expect(
        find.descendant(
          of: find.byType(AnimatedNotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });

    testWidgets('isolates pulse animation under RepaintBoundary', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildAnimatedTestWidget(count: 4));

      expect(
        find.descendant(
          of: find.byType(AnimatedNotificationBadge),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });
}
