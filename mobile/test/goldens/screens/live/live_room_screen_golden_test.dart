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
    testGoldens('Live room screen host', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        await LiveGoldenFixtures.buildRoomPage(
          currentUserPubkey: 'host-pubkey',
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'live_room_screen_host');
    });

    testGoldens('Live room screen audience', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        await LiveGoldenFixtures.buildRoomPage(
          currentUserPubkey: 'audience-pubkey',
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'live_room_screen_audience');
    });
  });
}
