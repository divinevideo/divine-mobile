// ABOUTME: Factory for creating NostrClient instances
// ABOUTME: Handles platform-appropriate client creation with proper configuration

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/nostr_key_manager_signer.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Factory class for creating NostrClient instances
class NostrServiceFactory {
  /// Create a NostrClient for the current platform
  static NostrClient create(
    NostrKeyManager keyManager, {
    RelayStatisticsService? statisticsService,
  }) {
    UnifiedLogger.info(
      'Creating NostrClient via factory',
      name: 'NostrServiceFactory',
    );

    // Create signer from key manager
    final signer = NostrKeyManagerSigner(keyManager);

    // Create NostrClient config
    final config = NostrClientConfig(
      signer: signer,
      publicKey: keyManager.publicKey ?? '',
    );

    // Create relay manager config
    final relayManagerConfig = RelayManagerConfig(
      defaultRelayUrl: AppConstants.defaultRelayUrl,
      storage: InMemoryRelayStorage(),
    );

    // Create the NostrClient
    return NostrClient(config: config, relayManagerConfig: relayManagerConfig);
  }

  /// Initialize the created client
  static Future<void> initialize(NostrClient client) async {
    await client.initialize();
  }
}
