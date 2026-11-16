// ABOUTME: Helper utilities for real integration tests without over-mocking
// ABOUTME: Provides real Nostr relay connections and minimal platform channel mocking

import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/nostr_service_factory.dart';

/// Setup real integration test environment with minimal mocking
/// Only mocks platform channels that can't be tested, uses real Nostr connections
class RealIntegrationTestHelper {
  static bool _isSetup = false;

  /// Setup test environment with platform channel mocks and real Nostr
  static Future<void> setupTestEnvironment() async {
    if (_isSetup) return;

    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock platform channels that can't run in test environment
    _setupPlatformChannelMocks();

    _isSetup = true;
  }

  /// Create a real NostrService with embedded relay
  static Future<NostrClient> createRealNostrService() async {
    await setupTestEnvironment();

    // Generate a test key container
    final keyContainer = await SecureKeyContainer.generate();

    final nostrService = NostrServiceFactory.create(
      signer: LocalNostrIdentity(keyContainer: keyContainer),
    );
    await nostrService.initialize();

    // NostrClient handles relay connections internally

    return nostrService;
  }

  /// Setup minimal platform channel mocks (only what's needed, not business logic)
  static void _setupPlatformChannelMocks() {
    // Mock SharedPreferences
    const MethodChannel prefsChannel = MethodChannel(
      'plugins.flutter.io/shared_preferences',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAll':
              return <String, dynamic>{};
            case 'setString':
            case 'setStringList':
            case 'setBool':
            case 'setInt':
            case 'setDouble':
            case 'remove':
            case 'clear':
              return true;
            default:
              return null;
          }
        });

    // Replaced at the platform, not on its method channel: on Linux,
    // connectivity_plus asks NetworkManager over D-Bus instead, and on a CI
    // runner without it the failed listen lands in the test's zone (#11107).
    ConnectivityPlatform.instance = _AlwaysOnlineConnectivity();

    // Mock secure storage
    const MethodChannel secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (
          MethodCall methodCall,
        ) async {
          switch (methodCall.method) {
            case 'readAll':
              return <String, String>{};
            default:
              return null;
          }
        });

    // Mock path_provider
    const MethodChannel pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (
          MethodCall methodCall,
        ) async {
          switch (methodCall.method) {
            case 'getApplicationDocumentsDirectory':
              return '/tmp/test_documents';
            case 'getTemporaryDirectory':
              return '/tmp';
            case 'getApplicationSupportDirectory':
              return '/tmp/test_support';
            default:
              return null;
          }
        });
  }

  /// Clean up after tests
  static Future<void> cleanup() async {
    // Reset static state if needed
    _isSetup = false;
  }
}

/// Always online, and never asks the host. Like the Linux and method-channel
/// implementations, it reports the current state when its listener count goes
/// from zero to one; a listener that joins later hears only changes.
class _AlwaysOnlineConnectivity extends ConnectivityPlatform {
  static const List<ConnectivityResult> _online = [ConnectivityResult.wifi];

  late final StreamController<List<ConnectivityResult>> _reports =
      StreamController.broadcast(onListen: () => _reports.add(_online));

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _online;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _reports.stream;
}
