// ABOUTME: Service initialization helper for tests - handles proper setup without platform dependencies
// ABOUTME: Provides mock services that work in test environment without SharedPreferences or platform channels

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// TODO: Re-enable these imports when provider references are restored
// import 'package:openvine/providers/app_providers.dart';
// import 'package:openvine/providers/video_events_providers.dart';
// import 'package:openvine/providers/home_feed_provider.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'test_nostr_service.dart';

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

    // Mock flutter_secure_storage plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
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

  /// Create a real NostrService with mocked platform dependencies for testing
  static Future<ServiceBundle> createServiceBundle() async {
    initializeTestEnvironment();

    try {
      final keyManager = NostrKeyManager();
      await keyManager.initialize();

      // Generate keys if needed
      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }

      final nostrService = NostrService(keyManager);
      final subscriptionManager = SubscriptionManager(nostrService);
      final videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );

      return ServiceBundle(
        keyManager: keyManager,
        nostrService: nostrService,
        subscriptionManager: subscriptionManager,
        videoEventService: videoEventService,
      );
    } catch (e) {
      // If real service creation fails, fall back to test services
      return createTestServiceBundle();
    }
  }

  /// Create test service bundle using TestNostrService (no platform dependencies)
  static ServiceBundle createTestServiceBundle() {
    initializeTestEnvironment();

    final testNostrService = TestNostrService();
    testNostrService.setCurrentUserPubkey('test-pubkey-123');

    final subscriptionManager = SubscriptionManager(testNostrService);
    final videoEventService = VideoEventService(
      testNostrService,
      subscriptionManager: subscriptionManager,
    );

    return ServiceBundle(
      keyManager: null, // Not needed for test service
      nostrService: testNostrService,
      subscriptionManager: subscriptionManager,
      videoEventService: videoEventService,
    );
  }

  /// Clean up all services in a bundle
  static void disposeServiceBundle(ServiceBundle bundle) {
    bundle.videoEventService.dispose();
    bundle.subscriptionManager.dispose();
    bundle.nostrService.dispose();
    // NostrKeyManager doesn't have dispose method - handles cleanup automatically
  }

  /// Create Riverpod provider overrides for test environment
  static List createProviderOverrides() {
    // Create an empty list with proper type inference by starting with a typed list
    // This ensures the list has the correct Override type
    const List overrides = [];
    return overrides;
  }

  /// Create a test-ready ProviderContainer with proper overrides
  static ProviderContainer createTestContainer({List? additionalOverrides}) {
    final baseOverrides = createProviderOverrides();
    final extraOverrides = additionalOverrides ?? [];

    // Combine lists and cast to the expected type
    final List<dynamic> allOverrides = [...baseOverrides, ...extraOverrides];
    return ProviderContainer(overrides: allOverrides.cast());
  }
}

/// Bundle of commonly used services for tests
class ServiceBundle {
  ServiceBundle({
    this.keyManager,
    required this.nostrService,
    required this.subscriptionManager,
    required this.videoEventService,
  });

  final NostrKeyManager? keyManager;
  final dynamic nostrService; // Can be NostrService or TestNostrService
  final SubscriptionManager subscriptionManager;
  final VideoEventService videoEventService;
}
