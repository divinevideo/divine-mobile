// ABOUTME: Service initialization helper for tests - handles proper setup without platform dependencies
// ABOUTME: Mocks the SharedPreferences, connectivity and secure-storage channels that services read in tests

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

import 'shared_channel_override.dart';

/// Helper class for initializing services in test environment
class ServiceInitHelper {
  /// Initialize test environment with platform channel mocks
  static void initializeTestEnvironment() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock SharedPreferences for tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAll') {
              return <String, Object>{}; // Return empty preferences
            }
            return null;
          },
        );

    // Mock connectivity plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'check') {
              return 'wifi'; // Always return connected
            }
            return null;
          },
        );

    // Mock flutter_secure_storage plugin — shared channel, so route through the
    // sanctioned override: the heal-and-blame tearDown leaves it in place for the
    // caller's scope and auto-restores the canonical handler afterwards (#5738).
    overrideSharedChannel(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        // Simple in-memory store for test data
        switch (methodCall.method) {
          case 'read':
            return null; // No stored data by default
          case 'write':
          case 'containsKey':
            return false; // Keys don't exist by default
          case 'delete':
          case 'deleteAll':
            return null; // Delete operations succeed silently
          case 'readAll':
            return <String, String>{}; // Return empty map
          default:
            return null;
        }
      },
    );

    // Initialize logging for tests
    Log.setLogLevel(LogLevel.error); // Reduce noise in tests
  }
}
