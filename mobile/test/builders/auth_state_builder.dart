// ABOUTME: Test data builder for creating authentication data instances
// ABOUTME: Supports various auth scenarios including logged in, logged out, and error states

import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// Test data class for authentication information
class AuthData {
  const AuthData({
    required this.isAuthenticated,
    this.privateKey,
    this.publicKey,
    this.nsec,
    this.npub,
    this.lastAuthenticated,
    this.metadata = const {},
  });

  final bool isAuthenticated;
  final String? privateKey;
  final String? publicKey;
  final String? nsec;
  final String? npub;
  final DateTime? lastAuthenticated;
  final Map<String, dynamic> metadata;
}

/// Builder class for creating test AuthData instances
class AuthStateBuilder {
  AuthStateBuilder({
    this.isAuthenticated = false,
    this.privateKey,
    this.publicKey,
    this.nsec,
    this.npub,
    this.lastAuthenticated,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};
  bool isAuthenticated;
  String? privateKey;
  String? publicKey;
  String? nsec;
  String? npub;
  DateTime? lastAuthenticated;
  Map<String, dynamic> metadata;

  /// Build the AuthData instance
  AuthData build() => AuthData(
    isAuthenticated: isAuthenticated,
    privateKey: privateKey,
    publicKey: publicKey,
    nsec: nsec,
    npub: npub,
    lastAuthenticated: lastAuthenticated,
    metadata: metadata,
  );

  /// Create an authenticated state with generated keys
  AuthStateBuilder authenticated() {
    final keyPair = Keychain.generate();
    isAuthenticated = true;
    privateKey = keyPair.private;
    publicKey = keyPair.public;
    nsec = Nip19.encodePrivateKey(keyPair.private);
    npub = NostrKeyUtils.encodePubKey(keyPair.public);
    lastAuthenticated = DateTime.now();
    return this;
  }

  /// Create an unauthenticated state
  AuthStateBuilder unauthenticated() {
    isAuthenticated = false;
    privateKey = null;
    publicKey = null;
    nsec = null;
    npub = null;
    lastAuthenticated = null;
    return this;
  }

  /// Create a state with specific keys
  AuthStateBuilder withKeys({
    required String privateKey,
    required String publicKey,
  }) {
    this.privateKey = privateKey;
    this.publicKey = publicKey;
    nsec = Nip19.encodePrivateKey(privateKey);
    npub = NostrKeyUtils.encodePubKey(publicKey);
    isAuthenticated = true;
    lastAuthenticated = DateTime.now();
    return this;
  }

  /// Create an expired auth state
  AuthStateBuilder expired() {
    isAuthenticated = true;
    lastAuthenticated = DateTime.now().subtract(const Duration(days: 30));
    return this;
  }

  /// Add custom metadata
  AuthStateBuilder withMetadata(Map<String, dynamic> newMetadata) {
    metadata = newMetadata;
    return this;
  }

  /// Create multiple auth states for testing different scenarios
  static Map<String, AuthData> buildScenarios() => {
    'authenticated': AuthStateBuilder().authenticated().build(),
    'unauthenticated': AuthStateBuilder().unauthenticated().build(),
    'expired': AuthStateBuilder().authenticated().expired().build(),
  };
}
