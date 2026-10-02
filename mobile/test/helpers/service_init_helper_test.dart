// ABOUTME: Regression test for ServiceInitHelper's platform-channel mocks
// ABOUTME: Connectivity must answer with a list, and both mocks must be cleared after the suite

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'service_init_helper.dart';

const _preferencesChannel = MethodChannel(
  'plugins.flutter.io/shared_preferences',
);
const _connectivityChannel = MethodChannel(
  'dev.fluttercommunity.plus/connectivity',
);

void main() {
  group(ServiceInitHelper, () {
    group('initializeTestEnvironment', () {
      setUpAll(() {
        // Other suites leave handlers on these channels. Clear them first so
        // only the helper's own mocks can answer the tests below.
        TestWidgetsFlutterBinding.ensureInitialized();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(_preferencesChannel, null)
          ..setMockMethodCallHandler(_connectivityChannel, null);
        ServiceInitHelper.initializeTestEnvironment();
      });

      test('answers connectivity checks with wifi', () async {
        final results = await Connectivity().checkConnectivity();

        expect(results, equals([ConnectivityResult.wifi]));
      });

      // Also proves the mock was installed, so the cleanup check below cannot
      // pass just because no handler ever existed.
      test('answers preference reads with an empty store', () async {
        final stored = await _preferencesChannel
            .invokeMapMethod<String, Object>('getAll');

        expect(stored, equals(<String, Object>{}));
      });
    });

    // The helper's cleanup is registered from the inner group's setUpAll, so it
    // runs when that group ends, before these.
    tearDownAll(() async {
      await expectLater(
        _connectivityChannel.invokeMethod<Object>('check'),
        throwsA(isA<MissingPluginException>()),
        reason: 'the connectivity mock outlived the group',
      );
    });

    tearDownAll(() async {
      await expectLater(
        _preferencesChannel.invokeMethod<Object>('getAll'),
        throwsA(isA<MissingPluginException>()),
        reason: 'the SharedPreferences mock outlived the group',
      );
    });
  });
}
