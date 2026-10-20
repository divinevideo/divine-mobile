import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'live_golden_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  group('live screen goldens', () {
    testGoldens('Live room detail screen live', (tester) async {
      await tester.pumpWidgetBuilder(
        SizedBox(
          width: 430,
          child: LiveGoldenFixtures.buildDetailView(
            room: LiveGoldenFixtures.room,
            session: LiveGoldenFixtures.liveSession,
          ),
        ),
        wrapper: LiveGoldenFixtures.wrap,
      );
      await tester.pump();

      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'live_room_detail_screen_live');
    });

    testGoldens('Live room detail screen replay ready', (tester) async {
      await tester.pumpWidgetBuilder(
        SizedBox(
          width: 430,
          child: LiveGoldenFixtures.buildDetailView(
            room: LiveGoldenFixtures.room,
            session: LiveGoldenFixtures.endedSession,
            recording: LiveGoldenFixtures.replayReadyRecording,
          ),
        ),
        wrapper: LiveGoldenFixtures.wrap,
      );
      await tester.pump();

      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'live_room_detail_screen_replay_ready');
    });

    testGoldens('Live room detail screen replay processing', (tester) async {
      await tester.pumpWidgetBuilder(
        SizedBox(
          width: 430,
          child: LiveGoldenFixtures.buildDetailView(
            room: LiveGoldenFixtures.room,
            session: LiveGoldenFixtures.endedSession,
            recording: LiveGoldenFixtures.replayProcessingRecording,
          ),
        ),
        wrapper: LiveGoldenFixtures.wrap,
      );
      await tester.pump();

      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      await screenMatchesGolden(
        tester,
        'live_room_detail_screen_replay_processing',
      );
    });
  });
}
