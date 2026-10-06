import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';

import 'live_golden_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  group('live screen goldens', () {
    testGoldens('Go live screen default', (tester) async {
      await tester.pumpWidget(await LiveGoldenFixtures.buildGoLivePage());
      await tester.pump();
      await tester.pump();

      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'go_live_screen_default');
    });
  });
}
