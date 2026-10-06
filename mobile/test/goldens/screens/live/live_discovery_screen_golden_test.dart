import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'live_golden_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('Live discovery screen states', (tester) async {
    await tester.pumpWidgetBuilder(
      SizedBox(
        width: 430,
        height: 900,
        child: LiveGoldenFixtures.buildDiscoveryCards(),
      ),
      wrapper: materialAppWrapper(theme: ThemeData.dark()),
      surfaceSize: const Size(430, 900),
    );
    await tester.pump();
    await tester.pump();

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

    await multiScreenGolden(
      tester,
      'live_discovery_screen_devices',
      devices: const [
        Device(name: 'android_phone', size: Size(412, 892)),
        Device.iphone11,
      ],
    );
  });
}
