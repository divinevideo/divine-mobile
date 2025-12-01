// ABOUTME: NIP-98 HTTP Authentication service for signing HTTP requests with Nostr events
// ABOUTME: Creates and signs authentication events per NIP-98 specification for backend API calls

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Exception thrown by NIP-98 authentication operations
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class Nip98AuthException implements Exception {
  const Nip98AuthException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'Nip98AuthException: $message';
}

/// HTTP method types supported by NIP-98
enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  delete('DELETE'),
  patch('PATCH');

  const HttpMethod(this.value);
  final String value;
}

/// NIP-98 authentication token containing the signed event
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class Nip98Token {
  const Nip98Token({
    required this.token,
    required this.signedEvent,
    required this.createdAt,
    required this.expiresAt,
  });
  final String token;
  final Event signedEvent;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Check if the token is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get the authorization header value
  String get authorizationHeader => 'Nostr $token';

  @override
  String toString() => 'Nip98Token(expires: ${expiresAt.toIso8601String()})';
}

/// Service for creating NIP-98 HTTP authentication tokens
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class Nip98AuthService {
  Nip98AuthService({required AuthService authService})
    : _authService = authService {
    // Start periodic cache cleanup
    _cleanupTimer = Timer.periodic(
      _cacheCleanupInterval,
      (_) => _cleanupExpiredTokens(),
    );
  }
  final AuthService _authService;

  // Token cache to avoid repeated signing for identical requests
  final Map<String, Nip98Token> _tokenCache = {};
  static const Duration _tokenValidityDuration = Duration(minutes: 10);
  static const Duration _cacheCleanupInterval = Duration(minutes: 15);

  Timer? _cleanupTimer;

  /// Create a NIP-98 authentication token for an HTTP request
  Future<Nip98Token?> createAuthToken({
    required String url,
    required HttpMethod method,
    String? payload,
  }) async {
    if (!_authService.isAuthenticated) {
      Log.error(
        'Cannot create NIP-98 token - user not authenticated',
        name: 'Nip98AuthService',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      // Create cache key for this request
      final cacheKey = _createCacheKey(url, method, payload);

      // Check cache first
      final cachedToken = _tokenCache[cacheKey];
      if (cachedToken != null && !cachedToken.isExpired) {
        Log.debug(
          'Using cached NIP-98 token',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return cachedToken;
      }

      Log.debug(
        '📱 Creating new NIP-98 auth token for ${method.value} $url',
        name: 'Nip98AuthService',
        category: LogCategory.system,
      );

      // Parse URL to extract components
      final uri = Uri.parse(url);
      final normalizedUrl = '${uri.scheme}://${uri.host}${uri.path}';

      // Create the authentication event
      final authEvent = await _createAuthEvent(
        url: normalizedUrl,
        method: method,
        payload: payload,
      );

      if (authEvent == null) {
        throw const Nip98AuthException('Failed to create authentication event');
      }

      // Encode the event as base64 for the token
      final eventJson = jsonEncode(authEvent.toJson());
      final token = base64Encode(utf8.encode(eventJson));

      final now = DateTime.now();
      final nip98Token = Nip98Token(
        token: token,
        signedEvent: authEvent,
        createdAt: now,
        expiresAt: now.add(_tokenValidityDuration),
      );

      // Cache the token
      _tokenCache[cacheKey] = nip98Token;

      Log.info(
        'Created NIP-98 token (expires: ${nip98Token.expiresAt})',
        name: 'Nip98AuthService',
        category: LogCategory.system,
      );
      Log.debug(
        '📱 Event ID: ${authEvent.id}',
        name: 'Nip98AuthService',
        category: LogCategory.system,
      );

      return nip98Token;
    } catch (e) {
      Log.error(
        'Failed to create NIP-98 token: $e',
        name: 'Nip98AuthService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Create a signed authentication event per NIP-98
  Future<Event?> _createAuthEvent({
    required String url,
    required HttpMethod method,
    String? payload,
  }) async {
    try {
      final now = DateTime.now();
      final timestamp = (now.millisecondsSinceEpoch / 1000).round();

      // Create tags according to NIP-98
      final tags = <List<String>>[
        ['u', url], // URL tag
        ['method', method.value], // HTTP method tag
        ['created_at', timestamp.toString()], // Creation timestamp
      ];

      // Add payload hash if payload exists
      if (payload != null && payload.isNotEmpty) {
        final payloadBytes = utf8.encode(payload);
        final payloadHash = sha256.convert(payloadBytes);
        tags.add(['payload', payloadHash.toString()]);
      }

      // Create the event
      final authEvent = await _authService.createAndSignEvent(
        kind: 27235, // NIP-98 HTTP Auth event kind
        content: '', // Content is empty for auth events
        tags: tags,
      );

      if (authEvent == null) {
        Log.error(
          'Failed to sign authentication event',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return null;
      }

      // Validate the event
      if (!_validateAuthEvent(authEvent, url, method)) {
        Log.error(
          'Authentication event validation failed',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return null;
      }

      return authEvent;
    } catch (e) {
      Log.error(
        'Error creating auth event: $e',
        name: 'Nip98AuthService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Validate that an authentication event is properly formatted
  bool _validateAuthEvent(Event event, String url, HttpMethod method) {
    try {
      // Check event kind
      if (event.kind != 27235) {
        Log.error(
          'Invalid event kind: ${event.kind}',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return false;
      }

      // Check for required tags
      final tags = event.tags;

      final urlTag = tags.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'u',
        orElse: () => <String>[],
      );
      if (urlTag.isEmpty || urlTag[1] != url) {
        Log.error(
          'Missing or invalid URL tag',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return false;
      }

      final methodTag = tags.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'method',
        orElse: () => <String>[],
      );
      if (methodTag.isEmpty || methodTag[1] != method.value) {
        Log.error(
          'Missing or invalid method tag',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return false;
      }

      final createdAtTag = tags.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'created_at',
        orElse: () => <String>[],
      );
      if (createdAtTag.isEmpty) {
        Log.error(
          'Missing created_at tag',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return false;
      }

      // Check timestamp is recent (within 1 hour)
      final tagTimestamp = int.tryParse(createdAtTag[1]);
      if (tagTimestamp == null) {
        Log.error(
          'Invalid timestamp format',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return false;
      }

      final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      final timeDiff = (now - tagTimestamp).abs();
      if (timeDiff > 3600) {
        // 1 hour
        Log.error(
          'Timestamp too old: ${timeDiff}s',
          name: 'Nip98AuthService',
          category: LogCategory.system,
        );
        return false;
      }

      return true;
    } catch (e) {
      Log.error(
        'Auth event validation error: $e',
        name: 'Nip98AuthService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Create a cache key for request deduplication
  String _createCacheKey(String url, HttpMethod method, String? payload) {
    final components = [url, method.value, payload ?? ''];
    final combined = components.join('|');
    final hash = sha256.convert(utf8.encode(combined));
    return hash.toString();
  }

  /// Clean up expired tokens from cache
  void _cleanupExpiredTokens() {
    final expiredKeys = _tokenCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _tokenCache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      Log.debug(
        '🧹 Cleaned up ${expiredKeys.length} expired NIP-98 tokens',
        name: 'Nip98AuthService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear all cached tokens
  void clearTokenCache() {
    _tokenCache.clear();
    Log.debug(
      '🧹 Cleared all NIP-98 token cache',
      name: 'Nip98AuthService',
      category: LogCategory.system,
    );
  }

  /// Get cache statistics
  Map<String, dynamic> get cacheStats {
    final validTokens = _tokenCache.values
        .where((token) => !token.isExpired)
        .length;
    final expiredTokens = _tokenCache.values
        .where((token) => token.isExpired)
        .length;

    return {
      'total_cached': _tokenCache.length,
      'valid_tokens': validTokens,
      'expired_tokens': expiredTokens,
      'is_authenticated': _authService.isAuthenticated,
      'cleanup_interval_minutes': _cacheCleanupInterval.inMinutes,
      'token_validity_minutes': _tokenValidityDuration.inMinutes,
    };
  }

  /// Check if we can create auth tokens (user is authenticated)
  bool get canCreateTokens => _authService.isAuthenticated;

  /// Get current user's public key for auth
  String? get currentUserPubkey => _authService.currentNpub;

  void dispose() {
    Log.debug(
      '📱️ Disposing Nip98AuthService',
      name: 'Nip98AuthService',
      category: LogCategory.system,
    );

    _cleanupTimer?.cancel();
    _tokenCache.clear();
  }
}
