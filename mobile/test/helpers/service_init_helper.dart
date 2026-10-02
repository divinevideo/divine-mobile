// ABOUTME: Service initialization helper for tests - handles proper setup without platform dependencies
// ABOUTME: Mocks the SharedPreferences, connectivity and secure-storage channels that services read in tests

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

import 'shared_channel_override.dart';

/// Helper class for initializing services in test environment
class ServiceInitHelper {
  static const _preferencesChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  static const _connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );

  /// Initialize test environment with platform channel mocks.
  ///
  /// Must be called from a running test, `setUp`, or `setUpAll`: every mock it
  /// installs is removed again with [addTearDown]. From a `setUpAll` that
  /// cleanup runs once, after the group's last test.
  static void initializeTestEnvironment() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock SharedPreferences for tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_preferencesChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getAll') {
            return <String, Object>{};
          }
          return null;
        });

    // Mock connectivity plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_connectivityChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'check') {
            // Always connected. connectivity_plus reads the reply as a list.
            return <String>['wifi'];
          }
          return null;
        });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(_preferencesChannel, null)
        ..setMockMethodCallHandler(_connectivityChannel, null);
    });

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
