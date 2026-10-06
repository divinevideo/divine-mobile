import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'live_golden_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('Go live screen default', (tester) async {
    await tester.pumpWidget(await LiveGoldenFixtures.buildGoLivePage());
    await tester.pump();
    await tester.pump();

    await screenMatchesGolden(tester, 'go_live_screen_default');
  });
}
