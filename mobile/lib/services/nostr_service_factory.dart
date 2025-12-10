// ABOUTME: Factory for creating platform-appropriate NostrService implementations
// ABOUTME: Handles conditional service creation for web vs mobile platforms

import 'package:flutter/foundation.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';

// Conditional imports for platform-specific implementations
import 'nostr_service_factory_mobile.dart'
    if (dart.library.html) 'nostr_service_factory_web.dart';

/// Factory class for creating platform-appropriate NostrService implementations
class NostrServiceFactory {
  /// Create the appropriate NostrService for the current platform
  static INostrService create(
    NostrKeyManager keyManager, {
    void Function()? onInitialized,
  }) {
    // Use platform-specific factory function
    UnifiedLogger.info(
      'Creating platform-appropriate NostrService',
      name: 'NostrServiceFactory',
    );
    return createEmbeddedRelayService(keyManager, onInitialized: onInitialized);
  }

  /// Initialize the created service with appropriate parameters
  static Future<void> initialize(INostrService service) async {
    // P2P disabled for release - not ready for production
    // Initialize with P2P disabled on all platforms
    await (service as dynamic).initialize(enableP2P: false);
  }

  /// Check if P2P features are available on current platform and service
  static bool isP2PAvailable(INostrService service) {
    // P2P is available on mobile platforms with NostrService
    return !kIsWeb;
  }
}
