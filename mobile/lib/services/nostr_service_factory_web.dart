// ABOUTME: Web-specific factory for creating NostrClientServiceAdapter
// ABOUTME: Returns adapter wrapping NostrClient for INostrService compatibility

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/nostr_client_service_adapter.dart';
import 'package:openvine/services/nostr_key_manager_signer.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/relay_statistics_service.dart';

/// Create NostrClientServiceAdapter instance for web platform
///
/// Uses NostrClient internally with NostrKeyManagerSigner for signing
INostrService createEmbeddedRelayService(
  NostrKeyManager keyManager, {
  void Function()? onInitialized,
  RelayStatisticsService? statisticsService,
}) {
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
  final client = NostrClient(
    config: config,
    relayManagerConfig: relayManagerConfig,
  );

  // Wrap in adapter for INostrService compatibility
  return NostrClientServiceAdapter(
    client: client,
    keyManager: keyManager,
    onInitialized: onInitialized,
  );
}
