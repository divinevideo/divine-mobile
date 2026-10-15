// ABOUTME: Host runner for the real encrypted sound request transport scenario.
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/helpers/sound_request_transport_scenario.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'sound request and ready reply survive real encrypted transport',
    runSoundRequestTransportScenario,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
