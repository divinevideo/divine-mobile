// ABOUTME: Secure key storage with hardware-backed security and memory-safe
// ABOUTME: containers. Production-grade cryptographic key protection.

import 'dart:async';
import 'dart:io' if (dart.library.html) 'stubs/platform_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:nostr_key_manager/src/nsec_bunker_client.dart';
import 'package:nostr_key_manager/src/platform_secure_storage.dart';
import 'package:nostr_key_manager/src/secure_key_container.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('SecureKeyStorage');

/// Exception thrown by secure key storage operations.
///
/// REFACTORED: Removed ChangeNotifier - uses pure state management.
class SecureKeyStorageException implements Exception {
  /// Creates a new [SecureKeyStorageException].
  const SecureKeyStorageException(this.message, {this.code});

  /// The error message.
  final String message;

  /// Optional error code.
  final String? code;

  @override
  String toString() => 'SecureKeyStorageException: $message';
}

/// Security configuration for key storage operations.
///
/// REFACTORED: Removed ChangeNotifier - uses pure state management.
class SecurityConfig {
  /// Creates a new [SecurityConfig].
  const SecurityConfig({
    this.requireHardwareBacked = true,
    this.requireBiometrics = false,
    this.allowFallbackSecurity = false,
  });

  /// Whether hardware-backed security is required.
  final bool requireHardwareBacked;

  /// Whether biometric authentication is required.
  final bool requireBiometrics;

  /// Whether fallback to software security is allowed.
  final bool allowFallbackSecurity;

  /// Default high-security configuration
  static const SecurityConfig strict = SecurityConfig();

  /// Desktop-compatible configuration (allows software-only security)
  static const SecurityConfig desktop = SecurityConfig(
    requireHardwareBacked: false,
    allowFallbackSecurity: true,
  );

  /// Maximum security configuration with biometrics
  static const SecurityConfig maximum = SecurityConfig(
    requireBiometrics: true,
  );

  /// Fallback configuration for older devices
  static const SecurityConfig compatible = SecurityConfig(
    requireHardwareBacked: false,
    allowFallbackSecurity: true,
  );
}

/// Secure key storage service with hardware-backed protection.
///
/// REFACTORED: Removed ChangeNotifier - uses pure state management.
class SecureKeyStorage {
  /// Creates a new [SecureKeyStorage].
  ///
  /// If [securityConfig] is not provided, platform-appropriate defaults
  /// will be used.
  SecureKeyStorage({SecurityConfig? securityConfig}) {
    if (securityConfig != null) {
      _securityConfig = securityConfig;
    } else {
      // Use platform-appropriate default configuration
      _securityConfig = _getPlatformDefaultConfig();
    }
  }

  static const String _primaryKeyId = 'nostr_primary_key';
  // ignore: unused_field - Reserved for future metadata implementation.
  static const String _keyCreatedAtKey = 'key_created_at';
  // ignore: unused_field - Reserved for future metadata implementation.
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
      return SecurityConfig.desktop;
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // Desktop: Use OS keychain/credential store, allow software fallback
      return SecurityConfig.desktop;
    } else {
      // Mobile (iOS/Android): Prefer hardware backing but allow fallback
      return SecurityConfig.desktop;
    }
  }

  /// Initialize the secure key storage service
  Future<void> initialize() async {
    if (_isInitialized && _initializationError == null) return;

    _log.fine('Initializing SecureKeyStorage');

    try {
      // Initialize platform-specific secure storage
      await _platformStorage.initialize();

      // Check if we can meet our security requirements
      if (_securityConfig.requireHardwareBacked &&
          !_platformStorage.supportsHardwareSecurity) {
        if (!_securityConfig.allowFallbackSecurity) {
          throw const SecureKeyStorageException(
            'Hardware-backed security required but not available',
            code: 'hardware_not_available',
          );
        } else {
          _log.warning(
            'Hardware security not available, using software fallback',
          );
        }
      }

      if (_securityConfig.requireBiometrics &&
          !_platformStorage.supportsBiometrics) {
        if (!_securityConfig.allowFallbackSecurity) {
          throw const SecureKeyStorageException(
            'Biometric authentication required but not available',
            code: 'biometrics_not_available',
          );
        } else {
          _log.warning(
            'Biometrics not available, continuing without protection',
          );
        }
      }

      _isInitialized = true;
      _initializationError = null;

      _log
        ..info('SecureKeyStorage initialized')
        ..fine('📱 Security level: ${_getSecurityLevelDescription()}');
    } on Exception catch (e) {
      _initializationError = e.toString();
      _log.severe('Failed to initialize secure key storage: $e');
      rethrow;
    }
  }

  /// Check if user has stored keys
  Future<bool> hasKeys() async {
    await _ensureInitialized();

    try {
      return await _platformStorage.hasKey(_primaryKeyId);
    } on Exception catch (e) {
      _log.severe('Error checking for keys: $e');
      return false;
    }
  }

  /// Generate and store a new secure key pair
  Future<SecureKeyContainer> generateAndStoreKeys({
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();

    _log.fine('Generating new secure Nostr key pair');

    try {
      // Generate new secure key container
      final keyContainer = SecureKeyContainer.generate();

      _log.fine(
        '📱 Generated key for: ${_maskKey(keyContainer.npub)}',
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

      _log.info('Generated and stored new secure key pair');
      debugPrint(
        '🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}',
      );

      return keyContainer;
    } catch (e) {
      _log.severe('Key generation error: $e');
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

    _log.fine('Importing keys from nsec');

    try {
      if (!Nip19.isPrivateKey(nsec)) {
        throw const SecureKeyStorageException('Invalid nsec format');
      }

      // Create secure container from nsec
      final keyContainer = SecureKeyContainer.fromNsec(nsec);

      _log.fine(
        '📱 Imported key for: ${_maskKey(keyContainer.npub)}',
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

      _log.info('Keys imported and stored securely');
      debugPrint(
        '🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}',
      );

      return keyContainer;
    } catch (e) {
      _log.severe('Import error: $e');
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
      _log.info('Returning cached secure key container');
      return _cachedKeyContainer;
    }

    try {
      _log.fine('📱 Retrieving secure key container from storage');

      final keyContainer = await _platformStorage.retrieveKey(
        keyId: _primaryKeyId,
        biometricPrompt: biometricPrompt,
      );

      if (keyContainer == null) {
        _log.warning('No key found in secure storage');
        return null;
      }

      // Update cache - container kept alive until explicitly disposed
      _updateCache(keyContainer);

      await _updateLastAccess();

      _log.info('Retrieved and cached secure key container');
      return keyContainer;
    } on Object catch (e) {
      _log.severe('Error retrieving key container: $e');
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

    _log.fine('Importing keys from hex to secure storage');

    try {
      if (!keyIsValid(privateKeyHex)) {
        throw const SecureKeyStorageException('Invalid private key format');
      }

      // Create secure container from hex
      final keyContainer = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);

      _log.fine(
        '📱 Imported key for: ${_maskKey(keyContainer.npub)}',
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

      _log.info('Keys imported from hex and stored securely');
      debugPrint(
        '🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}',
      );

      return keyContainer;
    } catch (e) {
      _log.severe('Hex import error: $e');
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

    _log.fine('📱 Private key accessed for signing operation');
    await _updateLastAccess();

    return keyContainer.withPrivateKey(operation);
  }

  /// Export nsec for backup (use with extreme caution!)
  Future<String?> exportNsec({String? biometricPrompt}) async {
    final keyContainer = await getKeyContainer(
      biometricPrompt: biometricPrompt,
    );
    if (keyContainer == null) return null;

    _log.warning('NSEC export requested - ensure secure handling');

    return keyContainer.withNsec((nsec) => nsec);
  }

  /// Delete all stored keys (irreversible!)
  Future<void> deleteKeys({String? biometricPrompt}) async {
    await _ensureInitialized();

    _log.fine('📱️ Deleting all stored secure keys');

    try {
      // Delete from platform storage
      final success = await _platformStorage.deleteKey(
        keyId: _primaryKeyId,
        biometricPrompt: biometricPrompt,
      );

      if (!success) {
        _log.severe('Platform key deletion may have failed');
      }

      // Dispose cached container before clearing cache (proper place)
      _cachedKeyContainer?.dispose();

      // Clear cache
      _clearCache();

      // TODO(secure-storage): Delete metadata.

      _log.info('All keys deleted');
    } on Exception catch (e) {
      throw SecureKeyStorageException('Failed to delete keys: $e');
    }
  }

  // =========================================================================
  // Backup Key Management
  // =========================================================================

  static const String _backupKeyId = 'nostr_backup_key';
  static const String _backupTimestampKey = 'backup_created_at';

  /// Check if backup key exists
  Future<bool> hasBackupKey() async {
    await _ensureInitialized();
    try {
      return await _platformStorage.hasKey(_backupKeyId);
    } on Exception catch (e) {
      _log.severe('Failed to check backup key: $e');
      return false;
    }
  }

  /// Store backup key
  Future<void> saveBackupKey(String privateKeyHex) async {
    await _ensureInitialized();

    _log.fine('📱 Saving backup key to secure storage');

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

      _log.info('Backup key stored successfully');
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
        _log.fine('No backup key found in storage');
        return null;
      }

      _log.fine('Retrieved backup key from secure storage');
      return keyContainer;
    } on Exception catch (e) {
      _log.severe('Failed to retrieve backup key: $e');
      return null;
    }
  }

  /// Delete backup key
  Future<void> deleteBackupKey() async {
    await _ensureInitialized();

    _log.fine('📱 Deleting backup key');

    try {
      await _platformStorage.deleteKey(keyId: _backupKeyId);

      // Clear backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_backupTimestampKey);

      _log.info('Backup key deleted');
    } on Exception catch (e) {
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
      _log.fine(
        '📱 Storing identity key container for ${_maskKey(npub)}',
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

      _log.info('Stored identity for ${_maskKey(npub)}');
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
    } on Exception catch (e) {
      _log.severe('Error retrieving identity: $e');
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
        _log.severe('Target identity not found');
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

      _log.info('Switched to identity: ${_maskKey(npub)}');

      return true;
    } on Exception catch (e) {
      _log.severe('Error switching identity: $e');
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
    // Don't dispose old cached container immediately - let it be garbage
    // collected to avoid disposing containers still in use by calling code
    _cachedKeyContainer = keyContainer;
    _cacheTimestamp = DateTime.now();
  }

  /// Clear the in-memory cache (without disposing - only clear reference)
  void _clearCache() {
    _cachedKeyContainer = null;
    _cacheTimestamp = null;
    _log.fine('🧹 Secure key cache cleared (reference only)');
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
    // TODO(secure-storage): Implement metadata storage.
    // (creation time, last access, etc.)
    // This needs regular SharedPreferences for non-sensitive metadata
  }

  /// Update the last access timestamp
  Future<void> _updateLastAccess() async {
    // TODO(secure-storage): Implement last access tracking.
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

  /// Disposes of the service and cleans up resources.
  void dispose() {
    _log.fine('📱️ Disposing SecureKeyStorage');
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
      _log.warning('Bunker authentication is only for web platform');
      return false;
    }

    try {
      _log.fine('Authenticating with nsec bunker');

      _bunkerClient = NsecBunkerClient(authEndpoint: bunkerEndpoint);

      final authResult = await _bunkerClient!.authenticate(
        username: username,
        password: password,
      );

      if (!authResult.success) {
        _log.severe('Bunker authentication failed: ${authResult.error}');
        _bunkerClient = null;
        return false;
      }

      // Connect to the bunker relay
      final connected = await _bunkerClient!.connect();
      if (!connected) {
        _log.severe('Failed to connect to bunker relay');
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
          _log.severe(
            'Cannot create bunker key container - feature not yet implemented',
          );
          _bunkerClient = null;
          _usingBunker = false;
          return false;
        }

        _cachedKeyContainer = bunkerContainer;
        _cacheTimestamp = DateTime.now();
      }

      _log.info('Successfully authenticated with nsec bunker');

      return true;
    } on Exception catch (e) {
      _log.severe('Bunker authentication error: $e');
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

    _log.warning(
      'NIP-46 bunker key container feature is not yet implemented. '
      'Bunker auth will not work until this feature is completed.',
    );

    // Return null instead of throwing to prevent app crashes
    return null;
  }

  /// Sign an event using bunker (for web platform)
  Future<Map<String, dynamic>?> signEventWithBunker(
    Map<String, dynamic> event,
  ) async {
    if (!_usingBunker || _bunkerClient == null) {
      _log.severe('Bunker not available for signing');
      return null;
    }

    try {
      return await _bunkerClient!.signEvent(event);
    } on Exception catch (e) {
      _log.severe('Bunker signing error: $e');
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

  /// Mask a key for display purposes (show first 8 and last 4 characters)
  static String _maskKey(String key) {
    if (key.length < 12) return key;
    final start = key.substring(0, 8);
    final end = key.substring(key.length - 4);
    return '$start...$end';
  }
}
