// ABOUTME: Unified web authentication service supporting NIP-07 and nsec bunker
// ABOUTME: Provides seamless authentication for web users with multiple Nostr login methods

import 'dart:async';
import 'package:openvine/services/nip07_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart' show NsecBunkerClient;
import 'package:openvine/utils/unified_logger.dart';

/// Available authentication methods for web
enum WebAuthMethod {
  nip07, // Browser extension
  bunker, // nsec bunker
  none, // No authentication
}

/// Web authentication result
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class WebAuthResult {
  const WebAuthResult({
    required this.success,
    this.method,
    this.publicKey,
    this.errorMessage,
    this.errorCode,
  });

  factory WebAuthResult.success(WebAuthMethod method, String publicKey) =>
      WebAuthResult(success: true, method: method, publicKey: publicKey);

  factory WebAuthResult.failure(String message, {String? code}) =>
      WebAuthResult(success: false, errorMessage: message, errorCode: code);
  final bool success;
  final WebAuthMethod? method;
  final String? publicKey;
  final String? errorMessage;
  final String? errorCode;
}

/// Event signing interface for web authentication
abstract class WebSigner {
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event);
  void dispose();
}

/// NIP-07 signer implementation
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class Nip07Signer implements WebSigner {
  Nip07Signer(this._service);
  final Nip07Service _service;

  @override
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    final result = await _service.signEvent(event);
    return result.success ? result.signedEvent : null;
  }

  @override
  void dispose() {
    _service.disconnect();
  }
}

/// Bunker signer implementation
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class BunkerSigner implements WebSigner {
  BunkerSigner();

  @override
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    // Legacy implementation - kept for backward compatibility
    Log.warning(
      'Bunker signing temporarily unavailable',
      name: 'WebAuthService',
      category: LogCategory.system,
    );
    return null;
  }

  @override
  void dispose() {
    // No-op for legacy implementation
  }
}

/// Actual bunker signer implementation
class BunkerSignerImpl implements WebSigner {
  final NsecBunkerClient _client;

  BunkerSignerImpl(this._client);

  @override
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    if (!_client.isConnected) {
      Log.error(
        'Cannot sign: bunker not connected',
        name: 'BunkerSigner',
        category: LogCategory.auth,
      );
      return null;
    }

    try {
      return await _client.signEvent(event);
    } catch (e) {
      Log.error(
        'Bunker signing error: $e',
        name: 'BunkerSigner',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  @override
  void dispose() {
    _client.disconnect();
  }
}

/// Unified web authentication service
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class WebAuthService {
  factory WebAuthService() => _instance;
  WebAuthService._internal();
  static final WebAuthService _instance = WebAuthService._internal();

  // Service instances
  final Nip07Service _nip07Service = Nip07Service();
  NsecBunkerClient? _bunkerClient; // Injected or created as needed

  // Current authentication state
  WebAuthMethod _currentMethod = WebAuthMethod.none;
  String? _currentPublicKey;
  WebSigner? _currentSigner;
  bool _isAuthenticated = false;

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated && _currentPublicKey != null;

  /// Get current authentication method
  WebAuthMethod get currentMethod => _currentMethod;

  /// Get current user's public key
  String? get publicKey => _currentPublicKey;

  /// Get current signer for event signing
  WebSigner? get signer => _currentSigner;

  /// Check if NIP-07 is available
  bool get isNip07Available => _nip07Service.isAvailable;

  /// Get available authentication methods
  List<WebAuthMethod> get availableMethods {
    final methods = <WebAuthMethod>[];

    if (_nip07Service.isAvailable) {
      methods.add(WebAuthMethod.nip07);
    }

    // Bunker is available when client is set
    if (_bunkerClient != null) {
      methods.add(WebAuthMethod.bunker);
    }

    return methods;
  }

  /// Get user-friendly method names
  String getMethodDisplayName(WebAuthMethod method) {
    switch (method) {
      case WebAuthMethod.nip07:
        return _nip07Service.extensionName;
      case WebAuthMethod.bunker:
        return 'nsec bunker';
      case WebAuthMethod.none:
        return 'None';
    }
  }

  /// Authenticate using NIP-07 browser extension
  Future<WebAuthResult> authenticateWithNip07() async {
    if (!_nip07Service.isAvailable) {
      return WebAuthResult.failure(
        'No NIP-07 extension found',
        code: 'EXTENSION_NOT_FOUND',
      );
    }

    try {
      Log.debug(
        '📱 Starting NIP-07 authentication...',
        name: 'WebAuthService',
        category: LogCategory.system,
      );

      final result = await _nip07Service.connect();
      if (!result.success) {
        return WebAuthResult.failure(
          result.errorMessage ?? 'NIP-07 authentication failed',
          code: result.errorCode,
        );
      }

      // Set up authentication state
      _currentMethod = WebAuthMethod.nip07;
      _currentPublicKey = result.publicKey;
      _currentSigner = Nip07Signer(_nip07Service);
      _isAuthenticated = true;

      Log.info(
        'NIP-07 authentication successful',
        name: 'WebAuthService',
        category: LogCategory.system,
      );

      return WebAuthResult.success(WebAuthMethod.nip07, result.publicKey!);
    } catch (e) {
      Log.error(
        'NIP-07 authentication error: $e',
        name: 'WebAuthService',
        category: LogCategory.system,
      );
      return WebAuthResult.failure(
        'Unexpected NIP-07 error: $e',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Authenticate using nsec bunker
  Future<WebAuthResult> authenticateWithBunker(String bunkerUri) async {
    if (_bunkerClient == null) {
      Log.warning(
        'Bunker authentication temporarily unavailable',
        name: 'WebAuthService',
        category: LogCategory.system,
      );
      return WebAuthResult.failure(
        'Bunker authentication is temporarily unavailable',
        code: 'TEMPORARILY_UNAVAILABLE',
      );
    }
    return authenticateWithBunkerEnabled(bunkerUri);
  }

  /// Authenticate with bunker when enabled (for testing)
  Future<WebAuthResult> authenticateWithBunkerEnabled(String bunkerUri) async {
    try {
      Log.debug(
        'Starting bunker authentication with URI',
        name: 'WebAuthService',
        category: LogCategory.auth,
      );

      // Disconnect any existing auth
      await disconnect();

      if (_bunkerClient == null) {
        return WebAuthResult.failure(
          'Bunker client not configured',
          code: 'CLIENT_NOT_CONFIGURED',
        );
      }

      // Parse and authenticate with bunker URI
      final authResult = await _bunkerClient!.authenticateFromUri(bunkerUri);
      if (!authResult.success) {
        return WebAuthResult.failure(
          authResult.error ?? 'Bunker authentication failed',
          code: 'AUTH_FAILED',
        );
      }

      // Connect to bunker relay
      final connected = await _bunkerClient!.connect();
      if (!connected) {
        return WebAuthResult.failure(
          'Failed to connect to bunker relay',
          code: 'CONNECTION_FAILED',
        );
      }

      // Set up authentication state
      _currentMethod = WebAuthMethod.bunker;
      _currentPublicKey = authResult.userPubkey;
      _currentSigner = BunkerSignerImpl(_bunkerClient!);
      _isAuthenticated = true;

      Log.info(
        'Bunker authentication successful',
        name: 'WebAuthService',
        category: LogCategory.auth,
      );

      return WebAuthResult.success(
        WebAuthMethod.bunker,
        authResult.userPubkey!,
      );
    } catch (e) {
      Log.error(
        'Bunker authentication error: $e',
        name: 'WebAuthService',
        category: LogCategory.auth,
      );
      return WebAuthResult.failure(
        'Unexpected bunker error: $e',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Sign an event using the current authentication method
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    if (!isAuthenticated || _currentSigner == null) {
      Log.error(
        'Cannot sign event: not authenticated',
        name: 'WebAuthService',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      return await _currentSigner!.signEvent(event);
    } catch (e) {
      Log.error(
        'Event signing failed: $e',
        name: 'WebAuthService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Disconnect and clear authentication
  Future<void> disconnect() async {
    Log.debug(
      '📱 Disconnecting web authentication...',
      name: 'WebAuthService',
      category: LogCategory.system,
    );

    _currentSigner?.dispose();
    _currentSigner = null;
    _currentPublicKey = null;
    _currentMethod = WebAuthMethod.none;
    _isAuthenticated = false;

    // Disconnect services
    _nip07Service.disconnect();
    _bunkerClient?.disconnect();

    Log.info(
      'Web authentication disconnected',
      name: 'WebAuthService',
      category: LogCategory.system,
    );
  }

  /// Check for existing session on startup
  Future<void> checkExistingSession() async {
    // For NIP-07, we can try to connect silently if extension remembers the permission
    if (_nip07Service.isAvailable) {
      try {
        // Some extensions remember permissions, so we can try a quick connect
        final result = await _nip07Service.connect();
        if (result.success) {
          _currentMethod = WebAuthMethod.nip07;
          _currentPublicKey = result.publicKey;
          _currentSigner = Nip07Signer(_nip07Service);
          _isAuthenticated = true;

          Log.info(
            'Restored NIP-07 session',
            name: 'WebAuthService',
            category: LogCategory.system,
          );

          return;
        }
      } catch (e) {
        // Silent failure, user will need to authenticate manually
        Log.info(
          'No existing NIP-07 session found',
          name: 'WebAuthService',
          category: LogCategory.system,
        );
      }
    }

    // For bunker, we would need to store the URI securely and reconnect
    // This is more complex and should be implemented based on security requirements
    Log.info(
      'No existing web session found',
      name: 'WebAuthService',
      category: LogCategory.system,
    );
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() => {
    'isAuthenticated': isAuthenticated,
    'currentMethod': _currentMethod.name,
    'publicKey': _currentPublicKey,
    'isNip07Available': isNip07Available,
    'availableMethods': availableMethods.map((m) => m.name).toList(),
    'nip07Info': _nip07Service.getDebugInfo(),
    'bunkerInfo': {'status': 'temporarily_disabled'},
  };

  void dispose() {
    disconnect();
  }

  // Test support methods
  void setBunkerClient(NsecBunkerClient client) {
    _bunkerClient = client;
  }

  void setAuthenticatedWithBunker(String pubkey) {
    _currentMethod = WebAuthMethod.bunker;
    _currentPublicKey = pubkey;
    _currentSigner = BunkerSignerImpl(_bunkerClient!);
    _isAuthenticated = true;
  }

  void setAuthenticatedWithNip07(String pubkey) {
    _currentMethod = WebAuthMethod.nip07;
    _currentPublicKey = pubkey;
    _currentSigner = Nip07Signer(_nip07Service);
    _isAuthenticated = true;
  }

  Map<String, dynamic>? parseBunkerUri(String uri) {
    try {
      final parsed = Uri.parse(uri);
      if (parsed.scheme != 'bunker') {
        return null;
      }

      final pubkey = parsed.userInfo;
      final relay = parsed.host;
      final queryParams = parsed.queryParameters;
      final secret = queryParams['secret'];
      final permissions = queryParams['perms']?.split(',') ?? [];

      return {
        'pubkey': pubkey,
        'relay': relay,
        'secret': secret,
        'permissions': permissions,
      };
    } catch (e) {
      return null;
    }
  }
}
