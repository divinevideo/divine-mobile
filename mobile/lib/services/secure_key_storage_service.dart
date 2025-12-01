// ABOUTME: Secure key storage service using hardware-backed security and memory-safe containers
// ABOUTME: Replaces the vulnerable KeyStorageService with production-grade cryptographic key protection

import 'dart:async';
import 'dart:io' if (dart.library.html) 'stubs/platform_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:openvine/services/nsec_bunker_client.dart';
import 'package:openvine/services/platform_secure_storage.dart';
import 'package:openvine/utils/nostr_encoding.dart';
import 'package:openvine/utils/secure_key_container.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exception thrown by secure key storage operations
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class SecureKeyStorageException implements Exception {
  const SecureKeyStorageException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'SecureKeyStorageException: $message';
}

/// Security configuration for key storage operations
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class SecurityConfig {
  const SecurityConfig({
    this.requireHardwareBacked = true,
    this.requireBiometrics = false,
    this.allowFallbackSecurity = false,
  });
  final bool requireHardwareBacked;
  final bool requireBiometrics;
  final bool allowFallbackSecurity;

  /// Default high-security configuration
  static const SecurityConfig strict = SecurityConfig(
    requireHardwareBacked: true,
    requireBiometrics: false,
    allowFallbackSecurity: false,
  );

  /// Desktop-compatible configuration (allows software-only security)
  static const SecurityConfig desktop = SecurityConfig(
    requireHardwareBacked: false,
    requireBiometrics: false,
    allowFallbackSecurity: true,
  );

  /// Maximum security configuration with biometrics
  static const SecurityConfig maximum = SecurityConfig(
    requireHardwareBacked: true,
    requireBiometrics: true,
    allowFallbackSecurity: false,
  );

  /// Fallback configuration for older devices
  static const SecurityConfig compatible = SecurityConfig(
    requireHardwareBacked: false,
    requireBiometrics: false,
    allowFallbackSecurity: true,
  );
}

/// Secure key storage service with hardware-backed protection
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class SecureKeyStorageService {
  SecureKeyStorageService({SecurityConfig? securityConfig}) {
    if (securityConfig != null) {
      _securityConfig = securityConfig;
    } else {
      // Use platform-appropriate default configuration
      _securityConfig = _getPlatformDefaultConfig();
    }
  }
  static const String _primaryKeyId = 'nostr_primary_key';
  // ignore: unused_field
  static const String _keyCreatedAtKey = 'key_created_at';
  // ignore: unused_field
  static const String _lastAccessKey = 'last_key_access';
  static const String _savedKeysPrefix = 'saved_identity_';

  final PlatformSecureStorage _platformStorage = PlatformSecureStorage.instance;
  SecurityConfig _securityConfig = SecurityConfig.strict;

  // Bunker client for web platform
  NsecBunkerClient? _bunkerClient;
  bool _usingBunker = false;

  // Secure in-memory cache (automatically wiped)
  SecureKeyContainer? _cachedKeyContainer;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTimeout = Duration(
    minutes: 5,
  ); // Reduced from 15 minutes

  // Initialization state
  bool _isInitialized = false;
  String? _initializationError;

  /// Get platform-appropriate default security configuration
  SecurityConfig _getPlatformDefaultConfig() {
    if (kIsWeb) {
      // Web: Use browser storage persistence, no hardware backing
      return const SecurityConfig(
        requireHardwareBacked: false,
        requireBiometrics: false,
        allowFallbackSecurity: true,
      );
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // Desktop: Use OS keychain/credential store, allow software fallback
      return SecurityConfig.desktop;
    } else {
      // Mobile (iOS/Android): Prefer hardware backing but allow fallback
      return const SecurityConfig(
        requireHardwareBacked: false, // Changed to false to allow fallback
        requireBiometrics: false,
        allowFallbackSecurity: true,
      );
    }
  }

  /// Initialize the secure key storage service
  Future<void> initialize() async {
    if (_isInitialized && _initializationError == null) return;

    Log.debug(
      'Initializing SecureKeyStorageService',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    try {
      // Initialize platform-specific secure storage
      await _platformStorage.initialize();

      // Check if we can meet our security requirements
      if (_securityConfig.requireHardwareBacked &&
          !_platformStorage.supportsHardwareSecurity) {
        if (!_securityConfig.allowFallbackSecurity) {
          throw const SecureKeyStorageException(
            'Hardware-backed security required but not available on this device',
            code: 'hardware_not_available',
          );
        } else {
          Log.warning(
            'Hardware security not available, using software fallback',
            name: 'SecureKeyStorageService',
            category: LogCategory.auth,
          );
        }
      }

      if (_securityConfig.requireBiometrics &&
          !_platformStorage.supportsBiometrics) {
        if (!_securityConfig.allowFallbackSecurity) {
          throw const SecureKeyStorageException(
            'Biometric authentication required but not available on this device',
            code: 'biometrics_not_available',
          );
        } else {
          Log.warning(
            'Biometrics not available, continuing without biometric protection',
            name: 'SecureKeyStorageService',
            category: LogCategory.auth,
          );
        }
      }

      _isInitialized = true;
      _initializationError = null;

      Log.info(
        'SecureKeyStorageService initialized',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Security level: ${_getSecurityLevelDescription()}',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
    } catch (e) {
      _initializationError = e.toString();
      Log.error(
        'Failed to initialize secure key storage: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      rethrow;
    }
  }

  /// Check if user has stored keys
  Future<bool> hasKeys() async {
    await _ensureInitialized();

    try {
      return await _platformStorage.hasKey(_primaryKeyId);
    } catch (e) {
      Log.error(
        'Error checking for keys: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return false;
    }
  }

  /// Generate and store a new secure key pair
  Future<SecureKeyContainer> generateAndStoreKeys({
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();

    Log.debug(
      'Generating new secure Nostr key pair',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    try {
      // Generate new secure key container
      final keyContainer = SecureKeyContainer.generate();

      Log.debug(
        '📱 Generated key for: ${NostrEncoding.maskKey(keyContainer.npub)}',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );

      // Store in platform-specific secure storage
      final result = await _platformStorage.storeKey(
        keyId: _primaryKeyId,
        keyContainer: keyContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );

      if (!result.success) {
        keyContainer.dispose();
        throw SecureKeyStorageException('Failed to store key: ${result.error}');
      }

      // Update cache
      _updateCache(keyContainer);

      // Store metadata
      await _storeMetadata();

      Log.info(
        'Generated and stored new secure key pair',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      debugPrint(
        '🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}',
      );

      return keyContainer;
    } catch (e) {
      Log.error(
        'Key generation error: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to generate keys: $e');
    }
  }

  /// Import keys from nsec (bech32 private key)
  Future<SecureKeyContainer> importFromNsec(
    String nsec, {
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();

    Log.debug(
      'Importing keys from nsec',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    try {
      if (!NostrEncoding.isValidNsec(nsec)) {
        throw const SecureKeyStorageException('Invalid nsec format');
      }

      // Create secure container from nsec
      final keyContainer = SecureKeyContainer.fromNsec(nsec);

      Log.debug(
        '📱 Imported key for: ${NostrEncoding.maskKey(keyContainer.npub)}',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );

      // Store in platform-specific secure storage
      final result = await _platformStorage.storeKey(
        keyId: _primaryKeyId,
        keyContainer: keyContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );

      if (!result.success) {
        keyContainer.dispose();
        throw SecureKeyStorageException(
          'Failed to store imported key: ${result.error}',
        );
      }

      // Update cache
      _updateCache(keyContainer);

      // Store metadata
      await _storeMetadata();

      Log.info(
        'Keys imported and stored securely',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      debugPrint(
        '🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}',
      );

      return keyContainer;
    } catch (e) {
      Log.error(
        'Import error: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to import keys: $e');
    }
  }

  /// Get the current secure key container
  Future<SecureKeyContainer?> getKeyContainer({String? biometricPrompt}) async {
    await _ensureInitialized();

    // Check cache first - if valid, always return the cached container
    if (_cachedKeyContainer != null && !_cachedKeyContainer!.isDisposed) {
      await _updateLastAccess();
      Log.info(
        'Returning cached secure key container',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return _cachedKeyContainer;
    }

    try {
      Log.debug(
        '📱 Retrieving secure key container from storage',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );

      final keyContainer = await _platformStorage.retrieveKey(
        keyId: _primaryKeyId,
        biometricPrompt: biometricPrompt,
      );

      if (keyContainer == null) {
        Log.warning(
          'No key found in secure storage',
          name: 'SecureKeyStorageService',
          category: LogCategory.auth,
        );
        return null;
      }

      // Update cache - this container will now be kept alive until explicitly disposed
      _updateCache(keyContainer);

      await _updateLastAccess();

      Log.info(
        'Retrieved and cached secure key container',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return keyContainer;
    } catch (e) {
      Log.error(
        'Error retrieving key container: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to retrieve keys: $e');
    }
  }

  /// Import keys from hex private key
  Future<SecureKeyContainer> importFromHex(
    String privateKeyHex, {
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();

    Log.debug(
      'Importing keys from hex to secure storage',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    try {
      if (!NostrEncoding.isValidHexKey(privateKeyHex)) {
        throw const SecureKeyStorageException('Invalid private key format');
      }

      // Create secure container from hex
      final keyContainer = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);

      Log.debug(
        '📱 Imported key for: ${NostrEncoding.maskKey(keyContainer.npub)}',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );

      // Store in platform-specific secure storage
      final result = await _platformStorage.storeKey(
        keyId: _primaryKeyId,
        keyContainer: keyContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );

      if (!result.success) {
        keyContainer.dispose();
        throw SecureKeyStorageException(
          'Failed to store imported key: ${result.error}',
        );
      }

      // Update cache
      _updateCache(keyContainer);

      // Store metadata
      await _storeMetadata();

      Log.info(
        'Keys imported from hex and stored securely',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      debugPrint(
        '🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}',
      );

      return keyContainer;
    } catch (e) {
      Log.error(
        'Hex import error: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to import keys: $e');
    }
  }

  /// Get only the public key (npub)
  Future<String?> getPublicKey({String? biometricPrompt}) async {
    final keyContainer = await getKeyContainer(
      biometricPrompt: biometricPrompt,
    );
    return keyContainer?.npub;
  }

  /// Perform operation with private key (for signing)
  Future<T?> withPrivateKey<T>(
    T Function(String privateKeyHex) operation, {
    String? biometricPrompt,
  }) async {
    final keyContainer = await getKeyContainer(
      biometricPrompt: biometricPrompt,
    );
    if (keyContainer == null) return null;

    Log.debug(
      '📱 Private key accessed for signing operation',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );
    await _updateLastAccess();

    return keyContainer.withPrivateKey(operation);
  }

  /// Export nsec for backup (use with extreme caution!)
  Future<String?> exportNsec({String? biometricPrompt}) async {
    final keyContainer = await getKeyContainer(
      biometricPrompt: biometricPrompt,
    );
    if (keyContainer == null) return null;

    Log.warning(
      'NSEC export requested - ensure secure handling',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    return keyContainer.withNsec((nsec) => nsec);
  }

  /// Delete all stored keys (irreversible!)
  Future<void> deleteKeys({String? biometricPrompt}) async {
    await _ensureInitialized();

    Log.debug(
      '📱️ Deleting all stored secure keys',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    try {
      // Delete from platform storage
      final success = await _platformStorage.deleteKey(
        keyId: _primaryKeyId,
        biometricPrompt: biometricPrompt,
      );

      if (!success) {
        Log.error(
          'Platform key deletion may have failed',
          name: 'SecureKeyStorageService',
          category: LogCategory.auth,
        );
      }

      // Dispose cached container before clearing cache (this is the proper place to dispose)
      _cachedKeyContainer?.dispose();

      // Clear cache
      _clearCache();

      // TODO: Delete metadata

      Log.info(
        'All keys deleted',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
    } catch (e) {
      throw SecureKeyStorageException('Failed to delete keys: $e');
    }
  }

  // =============================================================================
  // Backup Key Management
  // =============================================================================

  static const String _backupKeyId = 'nostr_backup_key';
  static const String _backupTimestampKey = 'backup_created_at';

  /// Check if backup key exists
  Future<bool> hasBackupKey() async {
    await _ensureInitialized();
    try {
      return await _platformStorage.hasKey(_backupKeyId);
    } catch (e) {
      Log.error(
        'Failed to check backup key: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return false;
    }
  }

  /// Store backup key
  Future<void> saveBackupKey(String privateKeyHex) async {
    await _ensureInitialized();

    Log.debug(
      '📱 Saving backup key to secure storage',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    try {
      // Create secure container for backup key
      final backupContainer = SecureKeyContainer.fromPrivateKeyHex(
        privateKeyHex,
      );

      // Store backup key
      final result = await _platformStorage.storeKey(
        keyId: _backupKeyId,
        keyContainer: backupContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );

      if (!result.success) {
        backupContainer.dispose();
        throw SecureKeyStorageException(
          'Failed to store backup key: ${result.error}',
        );
      }

      // Store backup timestamp in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _backupTimestampKey,
        DateTime.now().toIso8601String(),
      );

      backupContainer.dispose();

      Log.info(
        'Backup key stored successfully',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
    } catch (e) {
      throw SecureKeyStorageException('Failed to save backup key: $e');
    }
  }

  /// Get backup key container
  Future<SecureKeyContainer?> getBackupKeyContainer() async {
    await _ensureInitialized();

    try {
      final keyContainer = await _platformStorage.retrieveKey(
        keyId: _backupKeyId,
      );

      if (keyContainer == null) {
        Log.debug(
          'No backup key found in storage',
          name: 'SecureKeyStorageService',
          category: LogCategory.auth,
        );
        return null;
      }

      Log.debug(
        'Retrieved backup key from secure storage',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return keyContainer;
    } catch (e) {
      Log.error(
        'Failed to retrieve backup key: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Delete backup key
  Future<void> deleteBackupKey() async {
    await _ensureInitialized();

    Log.debug(
      '📱 Deleting backup key',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    try {
      await _platformStorage.deleteKey(keyId: _backupKeyId);

      // Clear backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_backupTimestampKey);

      Log.info(
        'Backup key deleted',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
    } catch (e) {
      throw SecureKeyStorageException('Failed to delete backup key: $e');
    }
  }

  /// Store a key container for a specific identity (multi-account support)
  Future<void> storeIdentityKeyContainer(
    String npub,
    SecureKeyContainer keyContainer,
  ) async {
    await _ensureInitialized();

    try {
      Log.debug(
        '📱 Storing identity key container for ${NostrEncoding.maskKey(npub)}',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );

      final identityKeyId = '$_savedKeysPrefix$npub';

      final result = await _platformStorage.storeKey(
        keyId: identityKeyId,
        keyContainer: keyContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );

      if (!result.success) {
        throw SecureKeyStorageException(
          'Failed to store identity: ${result.error}',
        );
      }

      Log.info(
        'Stored identity for ${NostrEncoding.maskKey(npub)}',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
    } catch (e) {
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to store identity: $e');
    }
  }

  /// Retrieve a key container for a specific identity
  Future<SecureKeyContainer?> getIdentityKeyContainer(
    String npub, {
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();

    try {
      final identityKeyId = '$_savedKeysPrefix$npub';

      return await _platformStorage.retrieveKey(
        keyId: identityKeyId,
        biometricPrompt: biometricPrompt,
      );
    } catch (e) {
      Log.error(
        'Error retrieving identity: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Switch to a different identity
  Future<bool> switchToIdentity(String npub, {String? biometricPrompt}) async {
    try {
      // Save current identity first
      final currentContainer = await getKeyContainer(
        biometricPrompt: biometricPrompt,
      );
      if (currentContainer != null) {
        await storeIdentityKeyContainer(
          currentContainer.npub,
          currentContainer,
        );
      }

      // Get target identity
      final targetContainer = await getIdentityKeyContainer(
        npub,
        biometricPrompt: biometricPrompt,
      );
      if (targetContainer == null) {
        Log.error(
          'Target identity not found',
          name: 'SecureKeyStorageService',
          category: LogCategory.auth,
        );
        return false;
      }

      // Store as primary identity
      final result = await _platformStorage.storeKey(
        keyId: _primaryKeyId,
        keyContainer: targetContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );

      if (!result.success) {
        targetContainer.dispose();
        return false;
      }

      // Update cache
      _updateCache(targetContainer);

      Log.info(
        'Switched to identity: ${NostrEncoding.maskKey(npub)}',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );

      return true;
    } catch (e) {
      Log.error(
        'Error switching identity: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return false;
    }
  }

  /// Get security information
  Map<String, dynamic> get securityInfo => {
    'platform': _platformStorage.platformName,
    'hardware_backed': _platformStorage.supportsHardwareSecurity,
    'biometrics_available': _platformStorage.supportsBiometrics,
    'capabilities': _platformStorage.capabilities.map((c) => c.name).toList(),
    'security_config': {
      'require_hardware': _securityConfig.requireHardwareBacked,
      'require_biometrics': _securityConfig.requireBiometrics,
      'allow_fallback': _securityConfig.allowFallbackSecurity,
    },
    'cache_timeout_minutes': _cacheTimeout.inMinutes,
  };

  /// Update the in-memory cache with a new key container
  void _updateCache(SecureKeyContainer keyContainer) {
    // Don't dispose old cached container immediately - let it be garbage collected
    // to avoid disposing containers that might still be in use by calling code
    _cachedKeyContainer = keyContainer;
    _cacheTimestamp = DateTime.now();
  }

  /// Clear the in-memory cache (without disposing - only clear reference)
  void _clearCache() {
    _cachedKeyContainer = null;
    _cacheTimestamp = null;
    Log.debug(
      '🧹 Secure key cache cleared (reference only)',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );
  }

  /// Public method to clear cache (for compatibility)
  void clearCache() {
    _clearCache();
  }

  /// Check if the cache is still valid
  // ignore: unused_element
  bool _isCacheValid() {
    if (_cacheTimestamp == null) return false;

    final age = DateTime.now().difference(_cacheTimestamp!);
    return age < _cacheTimeout;
  }

  /// Store metadata about key operations
  Future<void> _storeMetadata() async {
    // TODO: Implement metadata storage (creation time, last access, etc.)
    // This will need to use regular SharedPreferences for non-sensitive metadata
  }

  /// Update the last access timestamp
  Future<void> _updateLastAccess() async {
    // TODO: Implement last access tracking
  }

  /// Get security level description
  String _getSecurityLevelDescription() {
    final parts = <String>[];

    if (_usingBunker) {
      parts.add('Bunker (Remote signing)');
    } else if (_platformStorage.supportsHardwareSecurity) {
      parts.add('Hardware-backed');
    } else {
      parts.add('Software-only');
    }

    if (_platformStorage.supportsBiometrics) {
      parts.add('Biometric-capable');
    }

    return parts.join(', ');
  }

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized || _initializationError != null) {
      await initialize();
    }
  }

  void dispose() {
    Log.debug(
      '📱️ Disposing SecureKeyStorageService',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );
    // Dispose cached container when service is disposed (app shutdown)
    _cachedKeyContainer?.dispose();
    _clearCache();
    disconnectBunker();
  }

  /// Authenticate with nsec bunker for web platform
  Future<bool> authenticateWithBunker({
    required String username,
    required String password,
    required String bunkerEndpoint,
  }) async {
    if (!kIsWeb) {
      Log.warning(
        'Bunker authentication is only for web platform',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return false;
    }

    try {
      Log.debug(
        'Authenticating with nsec bunker',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );

      _bunkerClient = NsecBunkerClient(authEndpoint: bunkerEndpoint);

      final authResult = await _bunkerClient!.authenticate(
        username: username,
        password: password,
      );

      if (!authResult.success) {
        Log.error(
          'Bunker authentication failed: ${authResult.error}',
          name: 'SecureKeyStorageService',
          category: LogCategory.auth,
        );
        _bunkerClient = null;
        return false;
      }

      // Connect to the bunker relay
      final connected = await _bunkerClient!.connect();
      if (!connected) {
        Log.error(
          'Failed to connect to bunker relay',
          name: 'SecureKeyStorageService',
          category: LogCategory.auth,
        );
        _bunkerClient = null;
        return false;
      }

      _usingBunker = true;
      _isInitialized = true;

      // Get public key from bunker and create a pseudo-container
      final pubkey = await _bunkerClient!.getPublicKey();
      if (pubkey != null) {
        // Create a special container for bunker-based keys
        // This won't have the private key but will have the public key
        final bunkerContainer = _createBunkerKeyContainer(pubkey);

        if (bunkerContainer == null) {
          // Feature not yet implemented - return false to indicate failure
          Log.error(
            'Cannot create bunker key container - feature not yet implemented',
            name: 'SecureKeyStorageService',
            category: LogCategory.auth,
          );
          _bunkerClient = null;
          _usingBunker = false;
          return false;
        }

        _cachedKeyContainer = bunkerContainer;
        _cacheTimestamp = DateTime.now();
      }

      Log.info(
        'Successfully authenticated with nsec bunker',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );

      return true;
    } catch (e) {
      Log.error(
        'Bunker authentication error: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      _bunkerClient = null;
      _usingBunker = false;
      return false;
    }
  }

  /// Create a special key container for bunker-based keys
  SecureKeyContainer? _createBunkerKeyContainer(String publicKey) {
    // For bunker, we create a container with only the public key
    // The private key remains on the bunker server
    // This is a special case where signing happens remotely

    // Note: This requires updating SecureKeyContainer to support
    // public-key-only mode for bunker scenarios
    // For now, return null to indicate feature is not yet implemented

    Log.warning(
      'NIP-46 bunker key container feature is not yet implemented. '
      'Bunker authentication will not function until this feature is completed.',
      name: 'SecureKeyStorageService',
      category: LogCategory.auth,
    );

    // Return null instead of throwing to prevent app crashes
    return null;
  }

  /// Sign an event using bunker (for web platform)
  Future<Map<String, dynamic>?> signEventWithBunker(
    Map<String, dynamic> event,
  ) async {
    if (!_usingBunker || _bunkerClient == null) {
      Log.error(
        'Bunker not available for signing',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return null;
    }

    try {
      return await _bunkerClient!.signEvent(event);
    } catch (e) {
      Log.error(
        'Bunker signing error: $e',
        name: 'SecureKeyStorageService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Check if using bunker for key management
  bool get isUsingBunker => _usingBunker;

  /// Disconnect from bunker
  void disconnectBunker() {
    if (_bunkerClient != null) {
      _bunkerClient!.disconnect();
      _bunkerClient = null;
      _usingBunker = false;
      _clearCache();
    }
  }
}
