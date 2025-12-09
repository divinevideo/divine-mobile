// ABOUTME: Test setup for handling platform channels and mock services
// ABOUTME: Mock implementations for plugins unavailable in tests

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set up test environment with necessary mocks and platform channel handlers
void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  SharedPreferences.setMockInitialValues({});

  // Set up mock method channels for plugins that aren't available in tests
  _setupSecureStorageMock();
  _setupPlatformChannelMocks();
}

void _setupSecureStorageMock() {
  // Mock flutter_secure_storage
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  // Simple in-memory storage for testing
  final testStorage = <String, String>{};

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (
        MethodCall methodCall,
      ) async {
        final args = methodCall.arguments as Map<dynamic, dynamic>? ?? {};
        switch (methodCall.method) {
          case 'read':
            final key = args['key'] as String?;
            return testStorage[key];
          case 'write':
            final key = args['key'] as String?;
            final value = args['value'] as String?;
            if (key != null && value != null) {
              testStorage[key] = value;
            }
            return null;
          case 'delete':
            final key = args['key'] as String?;
            testStorage.remove(key);
            return null;
          case 'deleteAll':
            testStorage.clear();
            return null;
          case 'readAll':
            return testStorage;
          case 'containsKey':
            final key = args['key'] as String?;
            return testStorage.containsKey(key);
          case 'getCapabilities':
            // Return basic capabilities for testing
            return {'basicSecureStorage': true};
          default:
            return null;
        }
      });

  // Mock the secure storage capability check channel
  const capabilityChannel = MethodChannel(
    'openvine.secure_storage',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(capabilityChannel, (
        MethodCall methodCall,
      ) async {
        switch (methodCall.method) {
          case 'getCapabilities':
            return {
              'hasHardwareSecurity': false,
              'hasBiometrics': false,
              'hasKeychain': true,
            };
          default:
            return null;
        }
      });
}

void _setupPlatformChannelMocks() {
  // Mock other platform channels that might be needed

  // Mock device info
  const deviceInfoChannel = MethodChannel(
    'plugins.flutter.io/device_info',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(deviceInfoChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'getDeviceInfo') {
          return {
            'model': 'Test Device',
            'manufacturer': 'Test Manufacturer',
            'brand': 'Test Brand',
            'version': {'release': '11', 'sdkInt': 30},
          };
        }
        return null;
      });

  // Mock path provider
  const pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (
        MethodCall methodCall,
      ) async {
        switch (methodCall.method) {
          case 'getTemporaryDirectory':
            return '/tmp';
          case 'getApplicationDocumentsDirectory':
            return '/tmp/documents';
          case 'getApplicationSupportDirectory':
            return '/tmp/support';
          default:
            return null;
        }
      });
}
