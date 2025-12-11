// ABOUTME: Riverpod provider for NostrClient lifecycle management
// ABOUTME: Creates/disposes NostrClient based on authentication state changes

import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nostr_client_provider.g.dart';

/// Provider to allow overriding AuthService in tests
@Riverpod(keepAlive: true)
AuthService? authServiceOverride(Ref ref) => null;

/// Provider that manages NostrClient lifecycle based on auth state
///
/// Returns null when:
/// - User is not authenticated
/// - User is in authenticating/checking state
/// - No key container is available
///
/// Creates a new NostrClient when:
/// - User becomes authenticated with a valid key container
///
/// Disposes the old client when:
/// - User signs out
/// - Auth state changes to unauthenticated
@Riverpod(keepAlive: true)
NostrClient? nostrClient(Ref ref) {
  // Use override if available (for testing), otherwise use real auth service
  final authServiceOverrideValue = ref.watch(authServiceOverrideProvider);
  final AuthService authService;
  if (authServiceOverrideValue != null) {
    authService = authServiceOverrideValue;
  } else {
    authService = ref.watch(authServiceProvider);
  }

  // Only create client when fully authenticated
  if (!authService.isAuthenticated ||
      authService.authState != AuthState.authenticated) {
    return null;
  }

  // Need key container to create signer
  final keyContainer = authService.currentKeyContainer;
  if (keyContainer == null) {
    return null;
  }

  // Create signer from key container
  final signer = AuthServiceSigner(keyContainer);

  // Create NostrClient config
  final config = NostrClientConfig(
    signer: signer,
    publicKey: keyContainer.publicKeyHex,
  );

  // Create relay manager config (in-memory for now, persistence will be added)
  const defaultRelayUrl = 'wss://relay.divine.video';
  final relayManagerConfig = RelayManagerConfig(
    defaultRelayUrl: defaultRelayUrl,
    storage: InMemoryRelayStorage(),
  );

  // Create and return the client
  final client = NostrClient(
    config: config,
    relayManagerConfig: relayManagerConfig,
  );

  // Set up disposal when provider is invalidated
  ref.onDispose(() async {
    await client.dispose();
  });

  return client;
}
