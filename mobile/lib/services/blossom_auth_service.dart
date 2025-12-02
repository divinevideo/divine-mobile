// ABOUTME: Blossom BUD-01 authentication service for age-restricted content
// ABOUTME: Creates kind 24242 signed events for authenticating GET requests to Blossom servers

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Exception thrown by Blossom authentication operations
class BlossomAuthException implements Exception {
  const BlossomAuthException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'BlossomAuthException: $message';
}

/// Service for creating Blossom BUD-01 authentication headers
/// Uses kind 24242 events with `t: get` and `x: sha256hash` tags
class BlossomAuthService {
  BlossomAuthService({required AuthService authService})
    : _authService = authService {
    // Start periodic cache cleanup
    _cleanupTimer = Timer.periodic(
      _cacheCleanupInterval,
      (_) => _cleanupExpiredCache(),
    );
  }

  final AuthService _authService;

  // Token cache to avoid repeated signing for identical blob requests
  final Map<String, _CachedAuthHeader> _cache = {};
  static const Duration _tokenValidityDuration = Duration(hours: 1);
  static const Duration _cacheCleanupInterval = Duration(minutes: 15);

  Timer? _cleanupTimer;

  /// Create a Blossom BUD-01 authentication header for GET requests
  /// Returns "Nostr <base64-encoded-event>" header value
  Future<String?> createGetAuthHeader({
    required String sha256Hash,
    String? serverUrl,
  }) async {
    if (!_authService.isAuthenticated) {
      Log.error(
        'Cannot create Blossom auth header - user not authenticated',
        name: 'BlossomAuthService',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      // Create preview of hash for logging (handle short test hashes)
      final hashPreview = sha256Hash.length > 8
          ? '${sha256Hash.substring(0, 8)}...'
          : sha256Hash;

      // Create cache key
      final cacheKey = _createCacheKey(sha256Hash, serverUrl);

      // Check cache first
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired) {
        Log.debug(
          'Using cached Blossom auth header for hash: $hashPreview',
          name: 'BlossomAuthService',
          category: LogCategory.system,
        );
        return cached.header;
      }

      Log.debug(
        '📱 Creating Blossom auth header for blob: $hashPreview',
        name: 'BlossomAuthService',
        category: LogCategory.system,
      );

      // Calculate expiration (1 hour from now)
      final now = DateTime.now();
      final expirationTimestamp =
          (now.millisecondsSinceEpoch / 1000).round() + 3600;

      // Create tags for Blossom BUD-01
      final tags = <List<String>>[
        ['t', 'get'], // Action type
        ['x', sha256Hash], // Blob hash
        ['expiration', expirationTimestamp.toString()], // Token expiration
      ];

      // Add server tag if provided (optional per BUD-01 spec)
      if (serverUrl != null && serverUrl.isNotEmpty) {
        tags.add(['server', serverUrl]);
      }

      // Create and sign the event
      final authEvent = await _authService.createAndSignEvent(
        kind: 24242, // Blossom BUD-01 auth event kind
        content: 'Get blob from Blossom server',
        tags: tags,
      );

      if (authEvent == null) {
        throw const BlossomAuthException(
          'Failed to create authentication event',
        );
      }

      // Encode the event as base64 for the header
      final eventJson = jsonEncode(authEvent.toJson());
      final token = base64Encode(utf8.encode(eventJson));
      final header = 'Nostr $token';

      // Cache the header
      _cache[cacheKey] = _CachedAuthHeader(
        header: header,
        createdAt: now,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          expirationTimestamp * 1000,
        ),
      );

      Log.info(
        'Created Blossom auth header for $hashPreview (expires: ${_cache[cacheKey]!.expiresAt})',
        name: 'BlossomAuthService',
        category: LogCategory.system,
      );
      Log.debug(
        '📱 Event ID: ${authEvent.id}',
        name: 'BlossomAuthService',
        category: LogCategory.system,
      );

      return header;
    } catch (e) {
      Log.error(
        'Failed to create Blossom auth header: $e',
        name: 'BlossomAuthService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Create a cache key for blob authentication
  String _createCacheKey(String sha256Hash, String? serverUrl) {
    final components = [sha256Hash, serverUrl ?? ''];
    final combined = components.join('|');
    final hash = sha256.convert(utf8.encode(combined));
    return hash.toString();
  }

  /// Clean up expired cache entries
  void _cleanupExpiredCache() {
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      Log.debug(
        '🧹 Cleaned up ${expiredKeys.length} expired Blossom auth headers',
        name: 'BlossomAuthService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear all cached auth headers
  void clearCache() {
    _cache.clear();
    Log.debug(
      '🧹 Cleared all Blossom auth cache',
      name: 'BlossomAuthService',
      category: LogCategory.system,
    );
  }

  /// Get cache statistics
  Map<String, dynamic> get cacheStats {
    final validHeaders = _cache.values
        .where((entry) => !entry.isExpired)
        .length;
    final expiredHeaders = _cache.values
        .where((entry) => entry.isExpired)
        .length;

    return {
      'total_cached': _cache.length,
      'valid_headers': validHeaders,
      'expired_headers': expiredHeaders,
      'is_authenticated': _authService.isAuthenticated,
      'cleanup_interval_minutes': _cacheCleanupInterval.inMinutes,
      'token_validity_hours': _tokenValidityDuration.inHours,
    };
  }

  /// Check if we can create auth headers (user is authenticated)
  bool get canCreateHeaders => _authService.isAuthenticated;

  /// Get current user's public key for auth
  String? get currentUserPubkey => _authService.currentNpub;

  void dispose() {
    Log.debug(
      '📱 Disposing BlossomAuthService',
      name: 'BlossomAuthService',
      category: LogCategory.system,
    );

    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

/// Cached authentication header with expiration
class _CachedAuthHeader {
  const _CachedAuthHeader({
    required this.header,
    required this.createdAt,
    required this.expiresAt,
  });

  final String header;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Check if the cached header is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
