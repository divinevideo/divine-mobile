// ABOUTME: Platform-specific secure storage using hardware security modules
// ABOUTME: Provides iOS Secure Enclave and Android Keystore integration

import 'dart:async';
// Platform detection with web compatibility
import 'dart:io'
    if (dart.library.html) 'stubs/platform_stub.dart'
    show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';

import 'package:nostr_key_manager/src/secure_key_container.dart';

final _log = Logger('PlatformSecureStorage');

/// Exception thrown by platform secure storage operations.
class PlatformSecureStorageException implements Exception {
  /// Creates a new [PlatformSecureStorageException].
  const PlatformSecureStorageException(
    this.message, {
    this.code,
    this.platform,
  });

  /// The error message.
  final String message;

  /// Optional error code.
  final String? code;

  /// Optional platform identifier.
  final String? platform;

  @override
  String toString() => 'PlatformSecureStorageException[$platform]: $message';
}

/// Platform-specific secure storage capabilities
enum SecureStorageCapability {
  /// Basic keychain/keystore storage
  basicSecureStorage,

  /// Hardware-backed security (Secure Enclave, TEE)
  hardwareBackedSecurity,

  /// Biometric authentication integration
  biometricAuthentication,

  /// Tamper detection and security events
  tamperDetection,
}

/// Security level of stored keys
enum SecurityLevel {
  /// Software-only security (encrypted but in software)
  software,

  /// Hardware-backed security (TEE, Secure Enclave)
  hardware,

  /// Hardware with biometric protection
  hardwareWithBiometrics,
}

/// Result of a secure storage operation.
class SecureStorageResult {
  /// Creates a new [SecureStorageResult].
  const SecureStorageResult({
    required this.success,
    this.error,
    this.securityLevel,
    this.metadata,
  });

  /// Whether the operation was successful.
  final bool success;

  /// Error message if the operation failed.
  final String? error;

  /// The security level achieved for the operation.
  final SecurityLevel? securityLevel;

  /// Additional metadata about the operation.
  final Map<String, dynamic>? metadata;

  /// Whether the storage is hardware-backed.
  bool get isHardwareBacked =>
      securityLevel == SecurityLevel.hardware ||
      securityLevel == SecurityLevel.hardwareWithBiometrics;
}

/// Platform detection helpers that work safely on web
bool get _isIOS => !kIsWeb && Platform.isIOS;
bool get _isAndroid => !kIsWeb && Platform.isAndroid;
bool get _isMacOS => !kIsWeb && Platform.isMacOS;
bool get _isWindows => !kIsWeb && Platform.isWindows;
bool get _isLinux => !kIsWeb && Platform.isLinux;

/// Platform-specific secure storage service
class PlatformSecureStorage {
  PlatformSecureStorage._();
  static const MethodChannel _channel = MethodChannel(
    'openvine.secure_storage',
  );

  static PlatformSecureStorage? _instance;

  /// Returns the singleton instance of [PlatformSecureStorage].
  // ignore: prefer_constructors_over_static_methods
  static PlatformSecureStorage get instance =>
      _instance ??= PlatformSecureStorage._();

  // Flutter secure storage fallback for platforms without native implementation
  static final FlutterSecureStorage _fallbackStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
      // Don't use data protection keychain on macOS in debug mode
      useDataProtectionKeyChain:
          defaultTargetPlatform != TargetPlatform.macOS || !kDebugMode,
    ),
  );

  // Legacy storage with old accessibility settings for migration
  static final FlutterSecureStorage _legacyStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      // Don't use data protection keychain on macOS in debug mode
      useDataProtectionKeyChain:
          defaultTargetPlatform != TargetPlatform.macOS || !kDebugMode,
    ),
  );

  bool _isInitialized = false;
  Set<SecureStorageCapability> _capabilities = {};
  String? _platformName;
  bool _useFallbackStorage = false;

  /// Initialize platform-specific secure storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    _log.fine('Initializing platform-specific secure storage');

    try {
      // Check platform capabilities
      await _detectCapabilities();

      // Initialize platform-specific storage
      if (kIsWeb) {
        await _initializeWeb();
      } else if (_isIOS) {
        await _initializeIOS();
      } else if (_isAndroid) {
        await _initializeAndroid();
      } else if (_isMacOS) {
        await _initializeMacOS();
      } else if (_isWindows) {
        await _initializeWindows();
      } else if (_isLinux) {
        await _initializeLinux();
      } else {
        throw const PlatformSecureStorageException(
          'Platform not supported for secure storage',
          platform: 'unsupported',
        );
      }

      _isInitialized = true;
      _log.info('Platform secure storage initialized for $_platformName');
      debugPrint(
        '📊 Capabilities: ${_capabilities.map((c) => c.name).join(', ')}',
      );
    } catch (e) {
      _log.severe('Failed to initialize platform secure storage: $e');
      rethrow;
    }
  }

  /// Store a secure key container in platform-specific secure storage
  Future<SecureStorageResult> storeKey({
    required String keyId,
    required SecureKeyContainer keyContainer,
    bool requireBiometrics = false,
    bool requireHardwareBacked = true,
  }) async {
    await _ensureInitialized();

    _log
      ..fine('📱 Storing key with ID: $keyId')
      ..fine(
        '⚙️ Requirements - Hardware: $requireHardwareBacked, '
        'Biometrics: $requireBiometrics',
      );

    try {
      // Check if we can meet the security requirements
      if (requireHardwareBacked &&
          !_capabilities.contains(
            SecureStorageCapability.hardwareBackedSecurity,
          )) {
        throw const PlatformSecureStorageException(
          'Hardware-backed security required but not available',
          code: 'hardware_not_available',
        );
      }

      if (requireBiometrics &&
          !_capabilities.contains(
            SecureStorageCapability.biometricAuthentication,
          )) {
        throw const PlatformSecureStorageException(
          'Biometric authentication required but not available',
          code: 'biometrics_not_available',
        );
      }

      // Store the key using platform-specific implementation or fallback
      return await keyContainer.withPrivateKey<Future<SecureStorageResult>>((
        privateKeyHex,
      ) async {
        if (_useFallbackStorage) {
          // Use flutter_secure_storage fallback
          try {
            final keyData = {
              'privateKeyHex': privateKeyHex,
              'publicKeyHex': keyContainer.publicKeyHex,
              'npub': keyContainer.npub,
            };

            await _fallbackStorage.write(
              key: keyId,
              value: keyData.entries
                  .map((e) => '${e.key}:${e.value}')
                  .join('|'),
            );

            return const SecureStorageResult(
              success: true,
              securityLevel: SecurityLevel.software,
            );
          } on Object catch (e) {
            // Handle duplicate item error (-25299) from keychain
            // accessibility migration. This occurs when an existing item
            // was stored with first_unlock_this_device and we're now
            // trying to store with first_unlock
            if (e is PlatformException &&
                (e.code.contains('-25299') ||
                    (e.message?.contains('already exists') ?? false))) {
              _log.warning(
                'Keychain duplicate item detected (-25299) - '
                'attempting migration from old accessibility',
              );

              try {
                // CRITICAL: Read from legacy storage (old accessibility)
                final legacyData = await _legacyStorage.read(key: keyId);

                if (legacyData == null) {
                  // Can't read from legacy - this is a real problem
                  return const SecureStorageResult(
                    success: false,
                    error:
                        'Keychain item exists but cannot be read '
                        'with old or new accessibility. '
                        'Manual migration required.',
                  );
                }

                _log.info(
                  'Successfully read existing key from legacy storage - '
                  'preserving data during migration',
                );

                // Delete the old item using legacy storage
                await _legacyStorage.delete(key: keyId);

                // Re-store the EXISTING data with new accessibility
                // This preserves the user's original key!
                await _fallbackStorage.write(key: keyId, value: legacyData);

                _log.info(
                  '✅ Successfully migrated keychain item '
                  'from first_unlock_this_device to first_unlock '
                  '(data preserved)',
                );

                return const SecureStorageResult(
                  success: true,
                  securityLevel: SecurityLevel.software,
                );
              } on Exception catch (retryError) {
                return SecureStorageResult(
                  success: false,
                  error: 'Failed to migrate keychain item: $retryError',
                );
              }
            }

            return SecureStorageResult(
              success: false,
              error: 'Fallback storage failed: $e',
            );
          }
        }

        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'storeKey',
          {
            'keyId': keyId,
            'privateKeyHex': privateKeyHex,
            'publicKeyHex': keyContainer.publicKeyHex,
            'npub': keyContainer.npub,
            'requireBiometrics': requireBiometrics,
            'requireHardwareBacked': requireHardwareBacked,
          },
        );

        if (result == null) {
          throw const PlatformSecureStorageException(
            'Platform returned null result',
          );
        }

        return SecureStorageResult(
          success: result['success'] as bool,
          error: result['error'] as String?,
          securityLevel: _parseSecurityLevel(
            result['securityLevel'] as String?,
          ),
          metadata: result['metadata'] as Map<String, dynamic>?,
        );
      });
    } on Object catch (e) {
      _log.severe('Failed to store key: $e');
      if (e is PlatformSecureStorageException) rethrow;
      throw PlatformSecureStorageException(
        'Storage operation failed: $e',
        platform: _platformName,
      );
    }
  }

  /// Retrieve a secure key container from platform-specific secure storage
  Future<SecureKeyContainer?> retrieveKey({
    required String keyId,
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();

    _log.fine('📱 Retrieving key with ID: $keyId');

    try {
      if (_useFallbackStorage) {
        // Try new storage first
        var keyDataString = await _fallbackStorage.read(key: keyId);
        var fromLegacy = false;

        // If not found, try legacy storage
        if (keyDataString == null) {
          keyDataString = await _legacyStorage.read(key: keyId);
          fromLegacy = true;
        }

        if (keyDataString == null) {
          _log.warning('Key not found in fallback or legacy storage');
          return null;
        }

        // Parse stored key data
        final keyData = <String, String>{};
        for (final pair in keyDataString.split('|')) {
          final parts = pair.split(':');
          if (parts.length == 2) {
            keyData[parts[0]] = parts[1];
          }
        }

        final privateKeyHex = keyData['privateKeyHex'];
        if (privateKeyHex == null) {
          _log.severe('Invalid key data in storage');
          return null;
        }

        if (fromLegacy) {
          _log.info(
            'Key retrieved from LEGACY storage - '
            'will be migrated on next write',
          );
        } else {
          _log.info('Key retrieved successfully from storage');
        }

        return SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      }

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'retrieveKey',
        {
          'keyId': keyId,
          'biometricPrompt':
              biometricPrompt ??
              'Authenticate to access your Nostr identity key',
        },
      );

      if (result == null) {
        _log.warning('Key not found or access denied');
        return null;
      }

      final success = result['success'] as bool;
      if (!success) {
        final error = result['error'] as String?;
        _log.severe('Key retrieval failed: $error');
        return null;
      }

      final privateKeyHex = result['privateKeyHex'] as String?;
      if (privateKeyHex == null) {
        throw const PlatformSecureStorageException(
          'Platform returned null private key',
        );
      }

      _log.info('Key retrieved successfully');
      return SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
    } on Object catch (e) {
      _log.severe('Failed to retrieve key: $e');
      if (e is PlatformSecureStorageException) rethrow;
      throw PlatformSecureStorageException(
        'Retrieval operation failed: $e',
        platform: _platformName,
      );
    }
  }

  /// Delete a key from platform-specific secure storage
  Future<bool> deleteKey({
    required String keyId,
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();

    _log.fine('📱️ Deleting key with ID: $keyId');

    try {
      if (_useFallbackStorage) {
        // Use flutter_secure_storage fallback
        try {
          await _fallbackStorage.delete(key: keyId);
          _log.info('Key deleted successfully from fallback storage');
          return true;
        } on Exception catch (e) {
          _log.severe('Key deletion failed in fallback storage: $e');
          return false;
        }
      }

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'deleteKey',
        {
          'keyId': keyId,
          'biometricPrompt':
              biometricPrompt ??
              'Authenticate to delete your Nostr identity key',
        },
      );

      final success = result?['success'] as bool? ?? false;
      if (!success) {
        final error = result?['error'] as String?;
        _log.severe('Key deletion failed: $error');
      } else {
        _log.info('Key deleted successfully');
      }

      return success;
    } on Exception catch (e) {
      _log.severe('Failed to delete key: $e');
      return false;
    }
  }

  /// Check if a key exists in secure storage
  Future<bool> hasKey(String keyId) async {
    await _ensureInitialized();

    try {
      if (_useFallbackStorage) {
        // Check new storage first
        final newValue = await _fallbackStorage.read(key: keyId);
        if (newValue != null) {
          return true;
        }

        // Also check legacy storage (for keys that need migration)
        final legacyValue = await _legacyStorage.read(key: keyId);
        return legacyValue != null;
      }

      final result = await _channel.invokeMethod<bool>('hasKey', {
        'keyId': keyId,
      });
      return result ?? false;
    } on Exception catch (e) {
      _log.severe('Failed to check key existence: $e');
      return false;
    }
  }

  /// Get available platform capabilities
  Set<SecureStorageCapability> get capabilities =>
      Set.unmodifiable(_capabilities);

  /// Get current platform name
  String? get platformName => _platformName;

  /// Check if platform supports hardware-backed security
  bool get supportsHardwareSecurity =>
      _capabilities.contains(SecureStorageCapability.hardwareBackedSecurity);

  /// Check if platform supports biometric authentication
  bool get supportsBiometrics =>
      _capabilities.contains(SecureStorageCapability.biometricAuthentication);

  /// Detect platform capabilities
  Future<void> _detectCapabilities() async {
    try {
      // On web, use basic capabilities
      if (kIsWeb) {
        _platformName = 'Web';
        _capabilities = {SecureStorageCapability.basicSecureStorage};
        return;
      }

      // For iOS, use flutter_secure_storage directly (no custom MethodChannel)
      if (_isIOS) {
        _log.fine(
          '📱 iOS detected - using flutter_secure_storage for keychain access',
        );
        _useFallbackStorage = true;
        _platformName = 'iOS';
        _capabilities = {SecureStorageCapability.basicSecureStorage};
        return;
      }

      // For other platforms, try the custom MethodChannel
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCapabilities',
      );

      if (result != null) {
        _platformName = result['platform'] as String?;
        final caps = result['capabilities'] as List<dynamic>? ?? [];

        _capabilities = caps
            .cast<String>()
            .map(_parseCapability)
            .where((cap) => cap != null)
            .cast<SecureStorageCapability>()
            .toSet();
      }
    } on Object catch (e) {
      _log.severe('Failed to detect capabilities, using fallback: $e');

      // If it's a MissingPluginException, enable fallback storage
      if (e is MissingPluginException) {
        _useFallbackStorage = true;
      }

      // Set platform name based on detection
      if (kIsWeb) {
        _platformName = 'Web';
      } else {
        _platformName = Platform.operatingSystem;
      }

      _capabilities = {SecureStorageCapability.basicSecureStorage};
    }
  }

  /// Initialize iOS-specific secure storage
  Future<void> _initializeIOS() async {
    _log.fine(
      '🔧 Initializing iOS Keychain via flutter_secure_storage',
    );

    try {
      // For iOS, always use flutter_secure_storage with keychain
      _log.info(
        'Using flutter_secure_storage for iOS (native keychain access)',
      );

      // Enable fallback storage for iOS (no custom native implementation)
      _useFallbackStorage = true;

      // Set capabilities for iOS - flutter_secure_storage uses iOS Keychain
      _capabilities = {
        SecureStorageCapability.basicSecureStorage,
        // Note: flutter_secure_storage uses iOS Keychain
        // which is hardware-backed on devices with Secure Enclave
      };
      _platformName = 'iOS';

      _log.info('iOS secure storage initialized using flutter_secure_storage');
    } on Exception catch (e) {
      throw PlatformSecureStorageException(
        'iOS initialization failed: $e',
        platform: 'iOS',
      );
    }
  }

  /// Initialize Android-specific secure storage
  Future<void> _initializeAndroid() async {
    _log.fine('🤖 Initializing Android Keystore integration');

    try {
      final result = await _channel.invokeMethod<bool>('initializeAndroid');
      if (result != true) {
        throw const PlatformSecureStorageException(
          'Failed to initialize Android secure storage',
          platform: 'Android',
        );
      }
    } on Object catch (e) {
      // If native Android Keystore plugin is not available, use fallback
      // (same pattern as macOS - see _initializeMacOS)
      _log.warning(
        'Android native plugin not available, '
        'using flutter_secure_storage fallback: $e',
      );

      // Enable fallback storage for Android
      _useFallbackStorage = true;

      // Set basic capabilities for Android with fallback storage
      _capabilities = {
        SecureStorageCapability.basicSecureStorage,
        // Note: Using software-based storage without native Keystore plugin
      };
      _platformName = 'Android (fallback)';

      _log.info('Android using flutter_secure_storage fallback');
    }
  }

  /// Initialize macOS-specific secure storage (using Keychain)
  Future<void> _initializeMacOS() async {
    _log.fine('📱️ Initializing macOS Keychain integration');

    try {
      // For macOS, use flutter_secure_storage (no native implementation)
      _log.warning(
        'macOS uses software-based Keychain storage (no hardware backing)',
      );

      // Enable fallback storage for macOS
      _useFallbackStorage = true;

      // Set basic capabilities for macOS
      _capabilities = {
        SecureStorageCapability.basicSecureStorage,
        // Note: No hardware-backed security or biometrics for macOS desktop app
      };
      _platformName = 'macOS';

      _log.info('Platform secure storage initialized for $_platformName');
    } on Exception catch (e) {
      throw PlatformSecureStorageException(
        'macOS initialization failed: $e',
        platform: 'macOS',
      );
    }
  }

  /// Initialize Windows-specific secure storage
  Future<void> _initializeWindows() async {
    _log.fine('🪟 Initializing Windows Credential Store integration');

    try {
      // For Windows, use software-only approach with Windows Credential Store
      _log.warning(
        'Windows uses software-based Credential Store (no hardware backing)',
      );

      // Enable fallback storage for Windows
      _useFallbackStorage = true;

      _capabilities = {SecureStorageCapability.basicSecureStorage};
      _platformName = 'Windows';
    } on Exception catch (e) {
      throw PlatformSecureStorageException(
        'Windows initialization failed: $e',
        platform: 'Windows',
      );
    }
  }

  /// Initialize Linux-specific secure storage
  Future<void> _initializeLinux() async {
    _log.fine('🔧 Initializing Linux Secret Service integration');

    try {
      // For Linux, use software-only approach with Secret Service
      _log.warning(
        'Linux uses software-based Secret Service (no hardware backing)',
      );

      // Enable fallback storage for Linux
      _useFallbackStorage = true;

      _capabilities = {SecureStorageCapability.basicSecureStorage};
      _platformName = 'Linux';
    } on Exception catch (e) {
      throw PlatformSecureStorageException(
        'Linux initialization failed: $e',
        platform: 'Linux',
      );
    }
  }

  /// Initialize web-specific secure storage
  Future<void> _initializeWeb() async {
    _log.fine('🔧 Initializing Web browser storage integration');

    try {
      // For web, use browser storage - IndexedDB for session persistence
      _log.warning(
        'Web uses browser storage (IndexedDB) - no hardware backing',
      );

      // Always use fallback storage for web platform
      _useFallbackStorage = true;

      _capabilities = {
        SecureStorageCapability.basicSecureStorage,
        // Note: No hardware-backed security or biometrics in web browsers
      };
      _platformName = 'Web';
    } on Exception catch (e) {
      throw PlatformSecureStorageException(
        'Web initialization failed: $e',
        platform: 'Web',
      );
    }
  }

  /// Parse capability string to enum
  SecureStorageCapability? _parseCapability(String capability) {
    switch (capability.toLowerCase()) {
      case 'basic_secure_storage':
        return SecureStorageCapability.basicSecureStorage;
      case 'hardware_backed_security':
        return SecureStorageCapability.hardwareBackedSecurity;
      case 'biometric_authentication':
        return SecureStorageCapability.biometricAuthentication;
      case 'tamper_detection':
        return SecureStorageCapability.tamperDetection;
      default:
        return null;
    }
  }

  /// Parse security level string to enum
  SecurityLevel? _parseSecurityLevel(String? level) {
    if (level == null) return null;

    switch (level.toLowerCase()) {
      case 'software':
        return SecurityLevel.software;
      case 'hardware':
        return SecurityLevel.hardware;
      case 'hardware_with_biometrics':
        return SecurityLevel.hardwareWithBiometrics;
      default:
        return null;
    }
  }

  /// Ensure platform storage is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
