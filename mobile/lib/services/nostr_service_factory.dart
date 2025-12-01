// ABOUTME: Factory for creating platform-appropriate NostrService implementations
// ABOUTME: Handles conditional service creation for web vs mobile platforms

import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';

// Conditional imports for platform-specific implementations
import 'nostr_service_factory_mobile.dart'
    if (dart.library.html) 'nostr_service_factory_web.dart';

/// Factory class for creating platform-appropriate NostrService implementations
class NostrServiceFactory {
  /// Create the appropriate NostrService for the current platform
  static INostrService create(NostrKeyManager keyManager, {void Function()? onInitialized}) {
    // Use platform-specific factory function
    UnifiedLogger.info('Creating platform-appropriate NostrService',
        name: 'NostrServiceFactory');
    return createDirectRelayService(keyManager, onInitialized: onInitialized);
  }

  /// Initialize the created service with appropriate parameters
  static Future<void> initialize(INostrService service) async {
    await (service as dynamic).initialize();
  }
}
