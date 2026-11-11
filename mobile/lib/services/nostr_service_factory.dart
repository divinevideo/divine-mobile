// ABOUTME: Factory for creating NostrClient instances
// ABOUTME: Handles platform-appropriate client creation with proper configuration

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Factory class for creating NostrClient instances
class NostrServiceFactory {
  /// Create a NostrClient for the current platform.
  ///
  /// [signer] is the single source of truth for the current user's public
  /// key and all signing operations. Pass `authService.currentIdentity`.
  /// When null (pre-auth, or after sign-out) an [UnauthenticatedSigner]
  /// fills the slot: it reports an empty public key, so the client's
  /// `hasKeys` stays false, and it throws from every signing entry point
  /// rather than returning null. The caller is expected to replace the
  /// whole client once an identity resolves — see `NostrService`, which
  /// deliberately never initializes relays on a keyless client.
  ///
  /// Takes [environmentConfig] to determine the relay URL to use.
  /// If not provided, falls back to [AppConstants.defaultRelayUrl].
  ///
  /// Takes [dbClient] for local event caching with optimistic updates.
  ///
  /// Note: User relays (NIP-65) should be added separately via
  /// [NostrClient.addRelays] and awaited BEFORE calling [initialize]
  /// to avoid race conditions.
  static NostrClient create({
    NostrSigner? signer,
    RelayStatisticsService? statisticsService,
    EnvironmentConfig? environmentConfig,
    AppDbClient? dbClient,
  }) {
    final divineRelayUrl =
        environmentConfig?.relayUrl ?? AppConstants.defaultRelayUrl;

    UnifiedLogger.info(
      'Creating NostrClient via factory with Divine relay: $divineRelayUrl',
      name: 'NostrServiceFactory',
    );

    final effectiveSigner = signer ?? const UnauthenticatedSigner();

    final config = NostrClientConfig(
      signer: effectiveSigner,
      // Verify inbound relay-event signatures off the main isolate (#5863).
      // Web has no Isolate.spawn. It checks signatures with the browser's
      // native BigInt (web/nostr_crypto.js) rather than Dart's software
      // BigInt, which costs ~89 ms per event on the main thread, and verifies
      // inline as before if that script did not load.
      eventVerifyWorkerSpawner: kIsWeb
          ? NativeEventVerifyWorker.spawn
          : EventVerifyIsolate.spawn,
    );

    // In non-production environments, lock relays to the environment host so a
    // user's NIP-65 list (which may carry production relays) cannot pull the
    // client onto a different environment's relays. Production is unrestricted.
    final isProduction = environmentConfig?.isProduction ?? true;
    final relayHost = Uri.tryParse(divineRelayUrl)?.host;
    final allowedRelayHost =
        (isProduction || relayHost == null || relayHost.isEmpty)
        ? null
        : relayHost;

    // Create relay manager config with persistent storage.
    final relayManagerConfig = RelayManagerConfig(
      defaultRelayUrl: divineRelayUrl,
      storage: SharedPreferencesRelayStorage(),
      allowedRelayHost: allowedRelayHost,
    );

    // Create the NostrClient
    final client = NostrClient(
      config: config,
      relayManagerConfig: relayManagerConfig,
      dbClient: dbClient,
    );

    return client;
  }

  /// Initialize the created client
  static Future<void> initialize(NostrClient client) async {
    await client.initialize();
  }
}
