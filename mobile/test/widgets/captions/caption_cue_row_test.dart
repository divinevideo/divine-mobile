// ABOUTME: Widget tests for the shared caption cue editing row.
// ABOUTME: Covers focus notification and external text resync.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/captions/caption_cue_row.dart';

void main() {
  group(CaptionCueRow, () {
    Widget pump({
      required String text,
      VoidCallback? onFocused,
      ValueChanged<String>? onTextChanged,
    }) => MaterialApp(
      home: Scaffold(
        body: CaptionCueRow(
          text: text,
          start: Duration.zero,
          end: const Duration(seconds: 1),
          totalDuration: const Duration(seconds: 6),
          textFieldLabel: 'Line',
          removeSemanticLabel: 'Remove line',
          onTimingChanged: (_, _) {},
          onTextChanged: onTextChanged ?? (_) {},
          onRemoved: () {},
          onFocused: onFocused,
        ),
      ),
    );

    testWidgets('notifies when the text field takes focus', (tester) async {
      var focused = 0;
      await tester.pumpWidget(pump(text: 'hello', onFocused: () => focused++));

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(focused, 1);
    });

    testWidgets('resyncs text changed by the owning editor', (tester) async {
      await tester.pumpWidget(pump(text: 'before'));
      expect(find.text('before'), findsOneWidget);

      await tester.pumpWidget(pump(text: 'after'));

      expect(find.text('before'), findsNothing);
      expect(find.text('after'), findsOneWidget);
    });
  });
}
