// ABOUTME: Widget tests for TimelineOverlayStrip.
// ABOUTME: Verifies empty rendering and tap callback propagation.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';

void main() {
  group(TimelineOverlayStrip, () {
    testWidgets('renders empty when there are no items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TimelineOverlayStrip(
              items: [],
              rowCount: 1,
              totalWidth: 600,
              pixelsPerSecond: 80,
              totalDuration: Duration(seconds: 10),
              clipEdgesMs: [0, 10000],
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Layer 1'), findsNothing);
    });

    testWidgets('calls onItemTapped for tapped item', (tester) async {
      TimelineOverlayItem? tapped;
      const item = TimelineOverlayItem(
        id: 'layer-1',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: Duration(seconds: 2),
        label: 'Layer 1',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TimelineOverlayStrip(
              items: const [item],
              rowCount: 1,
              totalWidth: 600,
              pixelsPerSecond: 100,
              totalDuration: const Duration(seconds: 10),
              clipEdgesMs: const [0, 10000],
              color: Colors.blue,
              onItemTapped: (value) => tapped = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Layer 1'));
      await tester.pump();

      expect(tapped, equals(item));
    });
  });
}
