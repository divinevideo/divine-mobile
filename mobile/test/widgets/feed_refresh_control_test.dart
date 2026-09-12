// ABOUTME: Tests reusable feed pull-to-refresh wrappers for empty/error states
// ABOUTME: Verifies feed refresh remains available without scrollable content

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';

void main() {
  Widget buildSubject(Widget child) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group(RefreshableFeedStateView, () {
    testWidgets('keeps standalone feed state refreshable', (tester) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        buildSubject(
          RefreshableFeedStateView(
            onRefresh: () async {
              refreshCount++;
            },
            child: const Text('No videos available'),
          ),
        ),
      );

      expect(find.text('No videos available'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();

      expect(refreshCount, 1);
    });

    testWidgets('refreshes from top-edge pointer scroll down', (tester) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        buildSubject(
          RefreshableFeedStateView(
            onRefresh: () async {
              refreshCount++;
            },
            child: const Text('No videos available'),
          ),
        ),
      );

      await tester.pump();

      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      pointer.hover(tester.getCenter(find.byType(Scrollable)));

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
    });

    testWidgets('can run one automatic empty-state refresh', (tester) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        buildSubject(
          RefreshableFeedStateView(
            autoRefresh: true,
            onRefresh: () async {
              refreshCount++;
            },
            child: const Text('No videos available'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(refreshCount, 1);

      await tester.pumpWidget(
        buildSubject(
          RefreshableFeedStateView(
            autoRefresh: true,
            onRefresh: () async {
              refreshCount++;
            },
            child: const Text('No videos available'),
          ),
        ),
      );
      await tester.pump();

      expect(refreshCount, 1);
    });
  });
}
