// ABOUTME: Widget tests for TimelineDropIndicatorLine.
// ABOUTME: Verifies positioning and line thickness.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_drop_indicator_line.dart';

void main() {
  group(TimelineDropIndicatorLine, () {
    testWidgets('renders positioned one-pixel line', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(children: [TimelineDropIndicatorLine(lineY: 24)]),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.top, equals(23.5));
      expect(positioned.left, equals(0));
      expect(positioned.right, equals(0));

      final sizeBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizeBox.height, equals(1));
    });
  });
}
