// ABOUTME: TDD tests for PageControllerSyncMixin
// ABOUTME: Verifies PageController sync behavior in URL-driven router screens

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';

void main() {
  group('PageControllerSyncMixin', () {
    testWidgets('SPEC: should sync controller when URL index changes', (
      tester,
    ) async {
      final mixin = TestPageControllerSyncMixin();
      final controller = PageController();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageView.builder(
              controller: controller,
              itemCount: 10,
              itemBuilder: (context, index) => Text('Page $index'),
            ),
          ),
        ),
      );

      // Initially at index 0
      expect(controller.page?.round(), 0);

      // Sync to index 5
      mixin.syncPageController(
        controller: controller,
        targetIndex: 5,
        itemCount: 10,
      );

      await tester.pumpAndSettle();

      // Should have jumped to index 5
      expect(controller.page?.round(), 5);

      controller.dispose();
    });

    testWidgets('SPEC: should not sync if controller already at target index', (
      tester,
    ) async {
      final mixin = TestPageControllerSyncMixin();
      final controller = _SpyPageController(initialPage: 3);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageView.builder(
              controller: controller,
              itemCount: 10,
              itemBuilder: (context, index) => Text('Page $index'),
            ),
          ),
        ),
      );

      final initialPage = controller.page?.round();
      expect(initialPage, 3);

      // Try to sync to same index
      mixin.syncPageController(
        controller: controller,
        targetIndex: 3,
        itemCount: 10,
      );

      await tester.pumpAndSettle();

      // Should still be at same index, and without a jump: jumping to the
      // page already shown moves nothing, so only the call count can see a
      // sync that should not have happened (#8617).
      expect(controller.page?.round(), initialPage);
      expect(controller.jumps, 0);

      controller.dispose();
    });

    testWidgets('SPEC: should clamp target index to valid range', (
      tester,
    ) async {
      final mixin = TestPageControllerSyncMixin();
      final controller = PageController();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageView.builder(
              controller: controller,
              itemCount: 5,
              itemBuilder: (context, index) => Text('Page $index'),
            ),
          ),
        ),
      );

      // Try to sync to index beyond range
      mixin.syncPageController(
        controller: controller,
        targetIndex: 100,
        itemCount: 5,
      );

      await tester.pumpAndSettle();

      // Should clamp to last valid index (4)
      expect(controller.page?.round(), 4);

      controller.dispose();
    });

    testWidgets('SPEC: should clamp negative target index to 0', (
      tester,
    ) async {
      final mixin = TestPageControllerSyncMixin();
      final controller = PageController(initialPage: 2);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageView.builder(
              controller: controller,
              itemCount: 5,
              itemBuilder: (context, index) => Text('Page $index'),
            ),
          ),
        ),
      );

      // Try to sync to negative index
      mixin.syncPageController(
        controller: controller,
        targetIndex: -5,
        itemCount: 5,
      );

      await tester.pumpAndSettle();

      // Should clamp to 0
      expect(controller.page?.round(), 0);

      controller.dispose();
    });

    testWidgets('SPEC: should handle controller without clients gracefully', (
      tester,
    ) async {
      final mixin = TestPageControllerSyncMixin();
      final controller = PageController();

      // Controller not attached to any widget yet (no clients)
      expect(controller.hasClients, false);

      // Should not throw when syncing
      expect(
        () => mixin.syncPageController(
          controller: controller,
          targetIndex: 5,
          itemCount: 10,
        ),
        returnsNormally,
      );

      controller.dispose();
    });

    testWidgets('SPEC: should track last synced index', (tester) async {
      final mixin = TestPageControllerSyncMixin();
      final controller = PageController();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageView.builder(
              controller: controller,
              itemCount: 10,
              itemBuilder: (context, index) => Text('Page $index'),
            ),
          ),
        ),
      );

      // Sync to index 3
      mixin.syncPageController(
        controller: controller,
        targetIndex: 3,
        itemCount: 10,
      );

      await tester.pumpAndSettle();

      // Last synced index should be tracked
      expect(mixin.lastSyncedIndex, 3);

      // Sync to index 7
      mixin.syncPageController(
        controller: controller,
        targetIndex: 7,
        itemCount: 10,
      );

      await tester.pumpAndSettle();

      // Last synced index should update
      expect(mixin.lastSyncedIndex, 7);

      controller.dispose();
    });

    testWidgets('SPEC: shouldSync returns true when URL index changes', (
      tester,
    ) async {
      final mixin = TestPageControllerSyncMixin();

      // First sync
      expect(mixin.shouldSync(urlIndex: 5, lastUrlIndex: null), true);

      // URL changed
      expect(mixin.shouldSync(urlIndex: 7, lastUrlIndex: 5), true);

      // URL unchanged
      expect(mixin.shouldSync(urlIndex: 5, lastUrlIndex: 5), false);
    });

    testWidgets(
      'SPEC: shouldSync returns true when controller position mismatches',
      (tester) async {
        final mixin = TestPageControllerSyncMixin();
        final controller = PageController();

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PageView.builder(
                controller: controller,
                itemCount: 10,
                itemBuilder: (context, index) => Text('Page $index'),
              ),
            ),
          ),
        );

        // Controller at 0, URL at 5 - should sync
        expect(
          mixin.shouldSync(
            urlIndex: 5,
            lastUrlIndex: 5,
            controller: controller,
            targetIndex: 5,
          ),
          true,
        );

        // Move controller to index 5
        controller.jumpToPage(5);
        await tester.pumpAndSettle();

        // Controller at 5, URL at 5 - should not sync
        expect(
          mixin.shouldSync(
            urlIndex: 5,
            lastUrlIndex: 5,
            controller: controller,
            targetIndex: 5,
          ),
          false,
        );

        controller.dispose();
      },
    );
  });
}

/// Counts jumps, because a jump to the page already shown is invisible in
/// [PageController.page].
class _SpyPageController extends PageController {
  _SpyPageController({super.initialPage});

  int jumps = 0;

  @override
  void jumpToPage(int page) {
    jumps++;
    super.jumpToPage(page);
  }
}

/// Test helper class that mixes in [PageControllerSyncMixin].
class TestPageControllerSyncMixin with PageControllerSyncMixin {
  @override
  bool get mounted => true; // Always mounted for testing
}
