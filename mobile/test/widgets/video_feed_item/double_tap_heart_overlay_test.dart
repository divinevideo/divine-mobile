// ABOUTME: Tests for DoubleTapHeartOverlay animation widget.
// ABOUTME: Verifies trigger starts animation, resets after completion,
// ABOUTME: handles rapid triggers, positions heart at tap point, and renders
// ABOUTME: heart icon.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_heart_overlay.dart';

void main() {
  group(DoubleTapHeartOverlay, () {
    late ValueNotifier<HeartTrigger?> trigger;
    var triggerId = 0;

    setUp(() {
      trigger = ValueNotifier<HeartTrigger?>(null);
      triggerId = 0;
    });

    tearDown(() {
      trigger.dispose();
    });

    void fire(Offset offset) {
      trigger.value = (offset: offset, id: ++triggerId);
    }

    Widget buildWidget({ValueNotifier<HeartTrigger?>? customTrigger}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: DoubleTapHeartOverlay(trigger: customTrigger ?? trigger),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders nothing before trigger', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('renders heart icon after trigger', (tester) async {
      await tester.pumpWidget(buildWidget());

      fire(const Offset(100, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DivineIcon), findsOneWidget);
    });

    testWidgets('heart disappears after animation completes', (tester) async {
      await tester.pumpWidget(buildWidget());

      fire(const Offset(100, 200));
      await tester.pump();
      // Advance past the full 1000ms animation
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('positions heart centered on tap offset', (tester) async {
      await tester.pumpWidget(buildWidget());

      fire(const Offset(160, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final positioned = tester.widget<Positioned>(
        find.byType(Positioned).last,
      );
      // Heart is 120px, so offset by half (60) from tap point
      expect(positioned.left, equals(100)); // 160 - 60
      expect(positioned.top, equals(240)); // 300 - 60
    });

    testWidgets('rapid triggers restart animation without crash', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      // Fire multiple rapid triggers at different positions
      fire(const Offset(50, 50));
      await tester.pump(const Duration(milliseconds: 100));
      fire(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 100));
      fire(const Offset(150, 150));
      await tester.pump(const Duration(milliseconds: 100));

      // Should still show heart (animation restarted)
      expect(find.byType(DivineIcon), findsOneWidget);

      // Last position should be used
      final positioned = tester.widget<Positioned>(
        find.byType(Positioned).last,
      );
      expect(positioned.left, equals(90)); // 150 - 60
      expect(positioned.top, equals(90)); // 150 - 60

      // Let it complete
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('is wrapped in IgnorePointer', (tester) async {
      await tester.pumpWidget(buildWidget());

      final overlay = find.byType(DoubleTapHeartOverlay);
      expect(overlay, findsOneWidget);

      expect(
        find.descendant(of: overlay, matching: find.byType(IgnorePointer)),
        findsOneWidget,
      );
    });

    testWidgets('respects trigger swap via didUpdateWidget', (tester) async {
      await tester.pumpWidget(buildWidget());

      final newTrigger = ValueNotifier<HeartTrigger?>(null);
      addTearDown(newTrigger.dispose);
      var newTriggerId = 0;

      // Swap to new trigger
      await tester.pumpWidget(buildWidget(customTrigger: newTrigger));

      // Old trigger should not animate
      fire(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DivineIcon), findsNothing);

      // New trigger should animate
      newTrigger.value = (offset: const Offset(100, 100), id: ++newTriggerId);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DivineIcon), findsOneWidget);
    });
  });
}
