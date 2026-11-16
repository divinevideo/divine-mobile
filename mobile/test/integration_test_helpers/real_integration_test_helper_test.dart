// ABOUTME: Tests that RealIntegrationTestHelper keeps the e2e run off the
// ABOUTME: host's connectivity service, which Linux CI runners lack (#11107)

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/helpers/real_integration_test_helper.dart';
import '../test_setup.dart';

const _prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');

class _NetworkManagerMissing implements Exception {
  const _NetworkManagerMissing();
}

/// Answers the way connectivity_plus does on a Linux host with no
/// NetworkManager: the check throws, and the change stream's listen fails
/// asynchronously in whichever zone listened first rather than on the stream.
class _NoNetworkManagerConnectivity extends ConnectivityPlatform {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      throw const _NetworkManagerMissing();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      StreamController<List<ConnectivityResult>>.broadcast(
        onListen: () async {
          await null;
          throw const _NetworkManagerMissing();
        },
      ).stream;
}

void main() {
  group(RealIntegrationTestHelper, () {
    group('setupTestEnvironment', () {
      late ConnectivityPlatform originalConnectivity;

      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();
        originalConnectivity = ConnectivityPlatform.instance;
        ConnectivityPlatform.instance = _NoNetworkManagerConnectivity();
      });

      tearDown(() async {
        ConnectivityPlatform.instance = originalConnectivity;
        await RealIntegrationTestHelper.cleanup();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_prefsChannel, null);
        restoreSharedChannelDefaults();
      });

      test('answers a connectivity check without the host service', () async {
        await RealIntegrationTestHelper.setupTestEnvironment();

        expect(
          await Connectivity().checkConnectivity(),
          equals([ConnectivityResult.wifi]),
        );
      });

      test('reports connectivity to a listener without an uncaught error '
          'in its zone', () async {
        await RealIntegrationTestHelper.setupTestEnvironment();
        final reports = <List<ConnectivityResult>>[];
        final uncaught = <Object>[];
        late StreamSubscription<List<ConnectivityResult>> subscription;

        runZonedGuarded(
          () => subscription = Connectivity().onConnectivityChanged.listen(
            reports.add,
          ),
          (error, _) => uncaught.add(error),
        );
        await pumpEventQueue();
        await subscription.cancel();

        expect(uncaught, isEmpty);
        expect(
          reports,
          equals([
            [ConnectivityResult.wifi],
          ]),
        );
      });
    });
  });
}
