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
    testGoldens('Live discovery screen states', (tester) async {
      await tester.pumpWidgetBuilder(
        SizedBox(
          width: 430,
          height: 900,
          child: LiveGoldenFixtures.buildDiscoveryCards(),
        ),
        wrapper: LiveGoldenFixtures.wrap,
        surfaceSize: const Size(430, 900),
      );
      await tester.pump();
      await tester.pump();

      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'live_discovery_screen_states');
    });

    testGoldens('Live discovery screen devices', (tester) async {
      await tester.pumpWidget(
        await LiveGoldenFixtures.buildDiscoveryPage(
          rooms: const [LiveGoldenFixtures.room],
          sessions: [LiveGoldenFixtures.liveSession],
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      await multiScreenGolden(
        tester,
        'live_discovery_screen_devices',
        devices: const [
          Device(
            name: 'android_phone',
            size: Size(412, 869),
            devicePixelRatio: 2.5,
          ),
          Device.iphone11,
        ],
      );
    });
  });
}
