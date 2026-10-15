// ABOUTME: Native runner for real sound request and ready-reply DM transport.
// ABOUTME: Uses loopback relay sockets; no Docker or private services required.
@Tags(['service'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/sound_request_transport_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'sound request and ready reply survive real encrypted transport',
    (tester) async {
      await tester.runAsync(runSoundRequestTransportScenario);
    },
  );
}
