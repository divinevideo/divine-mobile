// ABOUTME: Service initialization helper for tests - handles proper setup without platform dependencies
// ABOUTME: Provides mock services that work in test environment without SharedPreferences or platform channels

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/nostr_service_factory.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

import 'shared_channel_override.dart';
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

  /// Create a real NostrService with mocked platform dependencies for testing
  static Future<ServiceBundle> createServiceBundle() async {
    initializeTestEnvironment();

    try {
      // Generate a test key container for testing
      final keyContainer = await SecureKeyContainer.generate();

      final nostrService = NostrServiceFactory.create(
        signer: LocalNostrIdentity(keyContainer: keyContainer),
      );
      final subscriptionManager = SubscriptionManager(nostrService);
      final videoEventService = VideoEventService(
        nostrService,
        crashReporter: const SilentCrashReporter(),
      );

      return ServiceBundle(
        keyContainer: keyContainer,
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
      crashReporter: const SilentCrashReporter(),
    );

    return ServiceBundle(
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
    bundle.keyContainer?.dispose();
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
    required this.nostrService,
    required this.subscriptionManager,
    required this.videoEventService,
    this.keyContainer,
  });

  final SecureKeyContainer? keyContainer;
  final NostrClient nostrService;
  final SubscriptionManager subscriptionManager;
  final VideoEventService videoEventService;
}
