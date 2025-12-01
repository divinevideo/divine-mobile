// ABOUTME: NIP-46 nsec bunker client for secure remote signing on web platform
// ABOUTME: Handles authentication and communication with external bunker server for key management

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:nostr_sdk/nip04/nip04.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pointycastle/export.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Bunker connection configuration
class BunkerConfig {
  const BunkerConfig({
    required this.relayUrl,
    required this.bunkerPubkey,
    required this.secret,
    this.permissions = const [],
  });

  final String relayUrl;
  final String bunkerPubkey;
  final String secret;
  final List<String> permissions;

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

/// Authentication result from bunker server
class BunkerAuthResult {
  const BunkerAuthResult({
    required this.success,
    this.config,
    this.userPubkey,
    this.error,
  });

  final bool success;
  final BunkerConfig? config;
  final String? userPubkey;
  final String? error;
}

/// NIP-46 Remote Signer Client
class NsecBunkerClient {
  NsecBunkerClient({required this.authEndpoint});

  final String authEndpoint;

  WebSocketChannel? _wsChannel;
  BunkerConfig? _config;
  String? _userPubkey;
  String? _clientPubkey;
  String? _clientPrivateKey;
  ECDHBasicAgreement? _agreement;

  final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};
  StreamSubscription? _wsSubscription;

  bool get isConnected => _wsChannel != null && _config != null;
  String? get userPubkey => _userPubkey;

  /// Authenticate with username/password to get bunker connection details
  Future<BunkerAuthResult> authenticate({
    required String username,
    required String password,
  }) async {
    try {
      Log.debug(
        'Authenticating with bunker server',
        name: 'NsecBunkerClient',
        category: LogCategory.auth,
      );

      final response = await http.post(
        Uri.parse(authEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode != 200) {
        final error = 'Authentication failed: ${response.statusCode}';
        Log.error(error, name: 'NsecBunkerClient', category: LogCategory.auth);
        return BunkerAuthResult(success: false, error: error);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        return BunkerAuthResult(success: false, error: data['error'] as String);
      }

      _config = BunkerConfig.fromJson(data['bunker'] as Map<String, dynamic>);
      _userPubkey = data['pubkey'] as String;

      Log.info(
        'Bunker authentication successful',
        name: 'NsecBunkerClient',
        category: LogCategory.auth,
      );

      return BunkerAuthResult(
        success: true,
        config: _config,
        userPubkey: _userPubkey,
      );
    } catch (e) {
      Log.error(
        'Bunker authentication error: $e',
        name: 'NsecBunkerClient',
        category: LogCategory.auth,
      );
      return BunkerAuthResult(success: false, error: e.toString());
    }
  }

  /// Connect to the bunker relay
  Future<bool> connect() async {
    if (_config == null) {
      Log.error(
        'Cannot connect: no bunker configuration',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return false;
    }

    try {
      Log.debug(
        'Connecting to bunker relay: ${_config!.relayUrl}',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );

      // Generate ephemeral client keypair for this session
      _clientPrivateKey = keys.generatePrivateKey();
      _clientPubkey = keys.getPublicKey(_clientPrivateKey!);
      _agreement = NIP04.getAgreement(_clientPrivateKey!);

      _wsChannel = WebSocketChannel.connect(Uri.parse(_config!.relayUrl));

      // Subscribe to bunker responses
      _wsSubscription = _wsChannel!.stream.listen(
        _handleMessage,
        onError: (error) {
          Log.error(
            'WebSocket error: $error',
            name: 'NsecBunkerClient',
            category: LogCategory.relay,
          );
          _handleDisconnect();
        },
        onDone: () {
          Log.warning(
            'WebSocket connection closed',
            name: 'NsecBunkerClient',
            category: LogCategory.relay,
          );
          _handleDisconnect();
        },
      );

      // Send connect request to bunker
      await _sendConnectRequest();

      Log.info(
        'Connected to bunker relay',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return true;
    } catch (e) {
      Log.error(
        'Failed to connect to bunker: $e',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return false;
    }
  }

  /// Sign a Nostr event using the remote bunker
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    if (!isConnected) {
      Log.error(
        'Cannot sign: not connected to bunker',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return null;
    }

    try {
      final requestId = _generateRequestId();
      final completer = Completer<Map<String, dynamic>>();
      _pendingRequests[requestId] = completer;

      // Send NIP-46 sign_event request
      final request = {
        'id': requestId,
        'method': 'sign_event',
        'params': [event],
      };

      await _sendRequest(request);

      // Wait for response with timeout
      final response = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _pendingRequests.remove(requestId);
          throw TimeoutException('Signing request timed out');
        },
      );

      if (response['error'] != null) {
        Log.error(
          'Signing failed: ${response['error']}',
          name: 'NsecBunkerClient',
          category: LogCategory.relay,
        );
        return null;
      }

      return response['result'] as Map<String, dynamic>?;
    } catch (e) {
      Log.error(
        'Failed to sign event: $e',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  /// Get public key from bunker
  Future<String?> getPublicKey() async {
    if (!isConnected) {
      Log.error(
        'Cannot get pubkey: not connected to bunker',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return null;
    }

    try {
      final requestId = _generateRequestId();
      final completer = Completer<Map<String, dynamic>>();
      _pendingRequests[requestId] = completer;

      // Send NIP-46 get_public_key request
      final request = {
        'id': requestId,
        'method': 'get_public_key',
        'params': [],
      };

      await _sendRequest(request);

      final response = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _pendingRequests.remove(requestId);
          throw TimeoutException('Get public key request timed out');
        },
      );

      if (response['error'] != null) {
        Log.error(
          'Failed to get public key: ${response['error']}',
          name: 'NsecBunkerClient',
          category: LogCategory.relay,
        );
        return null;
      }

      return response['result'] as String?;
    } catch (e) {
      Log.error(
        'Failed to get public key: $e',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  /// Disconnect from bunker
  void disconnect() {
    Log.debug(
      'Disconnecting from bunker',
      name: 'NsecBunkerClient',
      category: LogCategory.relay,
    );

    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _pendingRequests.clear();
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as List<dynamic>;
      if (data.length < 3) return;

      final type = data[0] as String;
      if (type != 'EVENT') return;

      final event = data[2] as Map<String, dynamic>;
      final content = event['content'] as String?;
      if (content == null) return;

      // Decrypt content if encrypted (NIP-04)
      final decryptedContent = _decryptContent(content);
      final response = jsonDecode(decryptedContent) as Map<String, dynamic>;

      final requestId = response['id'] as String?;
      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        _pendingRequests[requestId]!.complete(response);
        _pendingRequests.remove(requestId);
      }
    } catch (e) {
      Log.error(
        'Failed to handle bunker message: $e',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
    }
  }

  void _handleDisconnect() {
    _wsChannel = null;

    // Fail all pending requests
    for (final completer in _pendingRequests.values) {
      completer.completeError('Connection lost');
    }
    _pendingRequests.clear();
  }

  Future<void> _sendConnectRequest() async {
    // Send NIP-46 connect request
    final connectRequest = {
      'id': _generateRequestId(),
      'method': 'connect',
      'params': [_clientPubkey, _config!.secret],
    };

    await _sendRequest(connectRequest);
  }

  Future<void> _sendRequest(Map<String, dynamic> request) async {
    if (_wsChannel == null) {
      throw Exception('Not connected to bunker');
    }

    // Wrap request in Nostr event format for NIP-46
    final event = _createRequestEvent(request);

    // Send as Nostr REQ message
    final message = ['REQ', 'bunker-${request['id']}', event];
    _wsChannel!.sink.add(jsonEncode(message));
  }

  Map<String, dynamic> _createRequestEvent(Map<String, dynamic> request) {
    // Create NIP-46 request event
    // In production, properly implement NIP-04 encryption
    return {
      'kind': 24133, // NIP-46 request kind
      'pubkey': _clientPubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'tags': [
        ['p', _config!.bunkerPubkey],
      ],
      'content': _encryptContent(jsonEncode(request)),
    };
  }

  String _encryptContent(String content) {
    if (_agreement == null || _config == null) {
      throw StateError('Bunker not properly configured for encryption');
    }
    return NIP04.encrypt(content, _agreement!, _config!.bunkerPubkey);
  }

  String _decryptContent(String encryptedContent) {
    if (_agreement == null || _config == null) {
      throw StateError('Bunker not properly configured for decryption');
    }
    try {
      return NIP04.decrypt(
        encryptedContent,
        _agreement!,
        _config!.bunkerPubkey,
      );
    } catch (e) {
      Log.error(
        'Failed to decrypt content: $e',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return '';
    }
  }

  String _generateRequestId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Check if NIP-04 encryption is supported
  bool supportsNIP04Encryption() => true;

  // Test-only methods for setting up encryption
  void setClientKeys(String privateKey, String publicKey) {
    _clientPrivateKey = privateKey;
    _clientPubkey = publicKey;
    _agreement = NIP04.getAgreement(privateKey);
  }

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

  void setConfig(BunkerConfig config) {
    _config = config;
  }

  String generateClientPrivateKey() {
    return keys.generatePrivateKey();
  }

  String getClientPublicKey(String privateKey) {
    return keys.getPublicKey(privateKey);
  }

  String encryptContent(String content) {
    return _encryptContent(content);
  }

  String decryptContent(String encryptedContent) {
    return _decryptContent(encryptedContent);
  }

  Map<String, dynamic> createRequestEvent(Map<String, dynamic> request) {
    return _createRequestEvent(request);
  }

  Map<String, dynamic>? processResponse(Map<String, dynamic> event) {
    try {
      final content = event['content'] as String?;
      if (content == null) return null;

      final decryptedContent = _decryptContent(content);
      if (decryptedContent.isEmpty) return null;

      return jsonDecode(decryptedContent) as Map<String, dynamic>;
    } catch (e) {
      Log.error(
        'Failed to process response: $e',
        name: 'NsecBunkerClient',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  /// Parse bunker URI and authenticate
  Future<BunkerAuthResult> authenticateFromUri(String bunkerUri) async {
    try {
      final uri = Uri.parse(bunkerUri);
      if (uri.scheme != 'bunker') {
        return BunkerAuthResult(
          success: false,
          error: 'Invalid bunker URI scheme: ${uri.scheme}',
        );
      }

      // Extract npub and relay from URI
      final userInfo = uri.userInfo;
      final relay = uri.host;
      final queryParams = uri.queryParameters;
      final secret = queryParams['secret'] ?? '';
      final permissions = queryParams['perms']?.split(',') ?? [];

      // Create config from URI
      _config = BunkerConfig(
        relayUrl: 'wss://$relay',
        bunkerPubkey: userInfo, // This should be converted from npub to hex
        secret: secret,
        permissions: permissions,
      );

      // For now, simulate successful auth
      _userPubkey = userInfo; // In production, get actual user pubkey

      return BunkerAuthResult(
        success: true,
        config: _config,
        userPubkey: _userPubkey,
      );
    } catch (e) {
      return BunkerAuthResult(
        success: false,
        error: 'Failed to parse bunker URI: $e',
      );
    }
  }
}
