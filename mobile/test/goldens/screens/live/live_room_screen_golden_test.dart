import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'live_golden_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('Live room screen host', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      await LiveGoldenFixtures.buildRoomPage(currentUserPubkey: 'host-pubkey'),
    );
    await tester.pump();
    await tester.pump();

    await screenMatchesGolden(tester, 'live_room_screen_host');
    await tester.binding.setSurfaceSize(null);
  });

  testGoldens('Live room screen audience', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      await LiveGoldenFixtures.buildRoomPage(
        currentUserPubkey: 'audience-pubkey',
      ),
    );
    await tester.pump();
    await tester.pump();

    await screenMatchesGolden(tester, 'live_room_screen_audience');
    await tester.binding.setSurfaceSize(null);
  });
}
