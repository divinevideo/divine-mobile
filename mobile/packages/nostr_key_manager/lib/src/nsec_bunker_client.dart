// ABOUTME: NIP-46 nsec bunker client for secure remote signing
// ABOUTME: Handles authentication and communication with bunker server
// ABOUTME: Uses nostr_sdk's NostrRemoteSigner for NIP-46 communication

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip46/nostr_remote_signer.dart';
import 'package:nostr_sdk/nip46/nostr_remote_signer_info.dart';
import 'package:nostr_sdk/relay/relay_mode.dart';

final _log = Logger('NsecBunkerClient');

/// Bunker connection configuration.
class BunkerConfig {
  /// Creates a new bunker configuration.
  ///
  /// [relayUrl] is the WebSocket URL of the bunker relay.
  /// [bunkerPubkey] is the public key of the bunker server.
  /// [secret] is the optional secret for authentication.
  /// [permissions] is the list of requested permissions.
  const BunkerConfig({
    required this.relayUrl,
    required this.bunkerPubkey,
    required this.secret,
    this.permissions = const [],
  });

  /// The WebSocket URL of the bunker relay.
  final String relayUrl;

  /// The public key of the bunker server.
  final String bunkerPubkey;

  /// The optional secret for authentication.
  final String secret;

  /// The list of requested permissions.
  final List<String> permissions;

  /// Creates a [BunkerConfig] from JSON.
  // ignore: sort_constructors_first
  factory BunkerConfig.fromJson(Map<String, dynamic> json) {
    return BunkerConfig(
      relayUrl: json['relay_url'] as String,
      bunkerPubkey: json['bunker_pubkey'] as String,
      secret: json['secret'] as String,
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

/// Authentication result from bunker server.
class BunkerAuthResult {
  /// Creates a new authentication result.
  ///
  /// [success] indicates whether authentication was successful.
  /// [config] contains the bunker configuration if successful.
  /// [userPubkey] is the user's public key if available.
  /// [error] contains an error message if authentication failed.
  const BunkerAuthResult({
    required this.success,
    this.config,
    this.userPubkey,
    this.error,
  });

  /// Whether authentication was successful.
  final bool success;

  /// The bunker configuration if authentication was successful.
  final BunkerConfig? config;

  /// The user's public key if available.
  final String? userPubkey;

  /// An error message if authentication failed.
  final String? error;
}

/// NIP-46 Remote Signer Client.
///
/// Uses nostr_sdk's NostrRemoteSigner for NIP-46 communication.
class NsecBunkerClient {
  /// Creates a new bunker client.
  ///
  /// [authEndpoint] is the HTTP endpoint for authentication.
  NsecBunkerClient({required this.authEndpoint});

  /// The HTTP endpoint for authentication.
  final String authEndpoint;

  BunkerConfig? _config;
  String? _userPubkey;
  NostrRemoteSigner? _remoteSigner;
  NostrRemoteSignerInfo? _signerInfo;

  /// Whether the client is connected to the bunker.
  bool get isConnected => _remoteSigner != null && _config != null;

  /// The user's public key if available.
  String? get userPubkey => _userPubkey;

  /// Authenticate with username/password to get bunker connection details.
  ///
  /// Returns a [BunkerAuthResult] indicating success or failure.
  Future<BunkerAuthResult> authenticate({
    required String username,
    required String password,
  }) async {
    try {
      _log.fine('Authenticating with bunker server');

      final response = await http.post(
        Uri.parse(authEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode != 200) {
        final error = 'Authentication failed: ${response.statusCode}';
        _log.severe(error);
        return BunkerAuthResult(success: false, error: error);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        return BunkerAuthResult(success: false, error: data['error'] as String);
      }

      _config = BunkerConfig.fromJson(data['bunker'] as Map<String, dynamic>);
      _userPubkey = data['pubkey'] as String;

      _log.info('Bunker authentication successful');

      return BunkerAuthResult(
        success: true,
        config: _config,
        userPubkey: _userPubkey,
      );
    } on Exception catch (e) {
      _log.severe('Bunker authentication error: $e');
      return BunkerAuthResult(success: false, error: e.toString());
    }
  }

  /// Connect to the bunker relay.
  ///
  /// Returns true if connection was successful, false otherwise.
  Future<bool> connect() async {
    if (_config == null) {
      _log.severe('Cannot connect: no bunker configuration');
      return false;
    }

    try {
      _log.fine('Connecting to bunker relay: ${_config!.relayUrl}');

      // Generate ephemeral client keypair for this session (nsec format)
      final clientPrivateKey = keys.generatePrivateKey();
      final clientNsec = Nip19.encodePrivateKey(clientPrivateKey);

      // Create NostrRemoteSignerInfo from bunker config
      _signerInfo = NostrRemoteSignerInfo(
        remoteSignerPubkey: _config!.bunkerPubkey,
        relays: [_config!.relayUrl],
        optionalSecret: _config!.secret,
        nsec: clientNsec,
        userPubkey: _userPubkey,
      );

      // Create and connect NostrRemoteSigner
      _remoteSigner = NostrRemoteSigner(RelayMode.BASE_MODE, _signerInfo!);
      await _remoteSigner!.connect();

      _log.info('Connected to bunker relay');
      return true;
    } on Exception catch (e) {
      _log.severe('Failed to connect to bunker: $e');
      _remoteSigner = null;
      return false;
    }
  }

  /// Sign a Nostr event using the remote bunker.
  ///
  /// Returns the signed event as a map, or null if signing failed.
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    if (!isConnected || _remoteSigner == null) {
      _log.severe('Cannot sign: not connected to bunker');
      return null;
    }

    try {
      // Convert Map to Event object
      final eventObj = Event.fromJson(event);

      // Sign using NostrRemoteSigner
      final signedEvent = await _remoteSigner!.signEvent(eventObj);

      if (signedEvent == null) {
        _log.severe('Signing failed: remote signer returned null');
        return null;
      }

      return signedEvent.toJson();
    } on Exception catch (e) {
      _log.severe('Failed to sign event: $e');
      return null;
    }
  }

  /// Get public key from bunker.
  ///
  /// Returns the user's public key, or null if not available.
  Future<String?> getPublicKey() async {
    if (!isConnected || _remoteSigner == null) {
      _log.severe('Cannot get pubkey: not connected to bunker');
      return null;
    }

    try {
      // Use pullPubkey to get the public key from remote signer
      final pubkey = await _remoteSigner!.pullPubkey();

      if (pubkey != null) {
        _userPubkey = pubkey;
        if (_signerInfo != null) {
          _signerInfo!.userPubkey = pubkey;
        }
      }

      return pubkey;
    } on Exception catch (e) {
      _log.severe('Failed to get public key: $e');
      return null;
    }
  }

  /// Disconnect from bunker.
  void disconnect() {
    _log.fine('Disconnecting from bunker');

    _remoteSigner?.close();
    _remoteSigner = null;
    _signerInfo = null;
  }

  /// Test-only method for setting up bunker public key.
  ///
  /// This method is only intended for testing purposes.
  void setBunkerPublicKey(String publicKey) {
    if (_config == null) {
      _config = BunkerConfig(
        relayUrl: 'wss://test.relay',
        bunkerPubkey: publicKey,
        secret: 'test',
      );
    } else {
      _config = BunkerConfig(
        relayUrl: _config!.relayUrl,
        bunkerPubkey: publicKey,
        secret: _config!.secret,
        permissions: _config!.permissions,
      );
    }
  }

  /// Test-only getter for bunker configuration.
  ///
  /// This getter is only intended for testing purposes.
  BunkerConfig? get config => _config;

  /// Test-only setter for bunker configuration.
  ///
  /// This setter is only intended for testing purposes.
  set config(BunkerConfig config) {
    _config = config;
  }

  /// Parse bunker URI and authenticate.
  ///
  /// Parses a bunker URI and attempts to authenticate with the bunker server.
  /// Returns a [BunkerAuthResult] indicating success or failure.
  Future<BunkerAuthResult> authenticateFromUri(String bunkerUri) async {
    try {
      // Use nostr_sdk's NostrRemoteSignerInfo to parse bunker URI
      final signerInfo = NostrRemoteSignerInfo.parseBunkerUrl(bunkerUri);

      if (signerInfo == null) {
        return const BunkerAuthResult(
          success: false,
          error: 'Failed to parse bunker URI',
        );
      }

      // Convert to BunkerConfig format
      if (signerInfo.relays.isEmpty) {
        return const BunkerAuthResult(
          success: false,
          error: 'No relays found in bunker URI',
        );
      }

      _config = BunkerConfig(
        relayUrl: signerInfo.relays.first,
        bunkerPubkey: signerInfo.remoteSignerPubkey,
        secret: signerInfo.optionalSecret ?? '',
      );

      _userPubkey = signerInfo.userPubkey;
      _signerInfo = signerInfo;

      return BunkerAuthResult(
        success: true,
        config: _config,
        userPubkey: _userPubkey,
      );
    } on Exception catch (e) {
      return BunkerAuthResult(
        success: false,
        error: 'Failed to parse bunker URI: $e',
      );
    }
  }
}
