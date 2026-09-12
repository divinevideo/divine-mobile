import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_shutter_flash.dart';

void main() {
  Widget build(int shutterTick) => MaterialApp(
    home: Scaffold(
      body: VideoRecorderShutterFlash(shutterTick: shutterTick),
    ),
  );

  double flashAlpha(WidgetTester tester) {
    final boxes = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(VideoRecorderShutterFlash),
        matching: find.byType(ColoredBox),
      ),
    );
    return boxes.isEmpty ? 0 : boxes.single.color.a;
  }

  group(VideoRecorderShutterFlash, () {
    testWidgets('is invisible until a capture happens', (tester) async {
      await tester.pumpWidget(build(0));

      expect(flashAlpha(tester), 0);
    });

    testWidgets('blinks when the capture count increases, then fades out', (
      tester,
    ) async {
      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pump();

      expect(flashAlpha(tester), greaterThan(0.5));

      await tester.pumpAndSettle();
      expect(flashAlpha(tester), 0);
    });

    testWidgets('does not blink when the count stays the same', (tester) async {
      await tester.pumpWidget(build(2));
      await tester.pumpWidget(build(2));
      await tester.pump();

      expect(flashAlpha(tester), 0);
    });
  });
}
