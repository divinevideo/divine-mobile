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
import 'package:unified_logger/unified_logger.dart';

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

  /// Tamper detection and security events
  tamperDetection,
}

/// Security level of stored keys
enum SecurityLevel {
  /// Software-only security (encrypted but in software)
  software,

  /// Hardware-backed security (TEE, Secure Enclave)
  hardware,
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
  bool get isHardwareBacked => securityLevel == SecurityLevel.hardware;
}

/// Platform detection helpers that work safely on web
bool get _isIOS => !kIsWeb && Platform.isIOS;
bool get _isAndroid => !kIsWeb && Platform.isAndroid;
bool get _isMacOS => !kIsWeb && Platform.isMacOS;
bool get _isWindows => !kIsWeb && Platform.isWindows;
bool get _isLinux => !kIsWeb && Platform.isLinux;

/// Platform-specific secure storage service
class PlatformSecureStorage {
  PlatformSecureStorage._()
    : _platformOverride = null,
      _fallbackStorage = _defaultFallbackStorage,
      _legacyStorage = _defaultLegacyStorage;

  /// Creates an independent instance that exercises a platform's storage path.
  ///
  /// Native calls still use the real method channels. The process-wide
  /// singleton and Flutter's global platform selection remain unchanged.
  @visibleForTesting
  PlatformSecureStorage.forPlatform(
    TargetPlatform platform, {
    FlutterSecureStorage? fallbackStorage,
    FlutterSecureStorage? legacyStorage,
  }) : _platformOverride = platform,
       _fallbackStorage = fallbackStorage ?? _defaultFallbackStorage,
       _legacyStorage = legacyStorage ?? _defaultLegacyStorage;

  final TargetPlatform? _platformOverride;
  final FlutterSecureStorage _fallbackStorage;
  final FlutterSecureStorage _legacyStorage;

  bool get _isStorageIOS => _platformOverride == null
      ? _isIOS
      : _platformOverride == TargetPlatform.iOS;
  bool get _isStorageAndroid => _platformOverride == null
      ? _isAndroid
      : _platformOverride == TargetPlatform.android;
  bool get _isStorageMacOS => _platformOverride == null
      ? _isMacOS
      : _platformOverride == TargetPlatform.macOS;
  bool get _isStorageWindows => _platformOverride == null
      ? _isWindows
      : _platformOverride == TargetPlatform.windows;
  bool get _isStorageLinux => _platformOverride == null
      ? _isLinux
      : _platformOverride == TargetPlatform.linux;

  static const MethodChannel _channel = MethodChannel(
    'openvine.secure_storage',
  );

  static PlatformSecureStorage? _instance;

  /// Returns the singleton instance of [PlatformSecureStorage].
  // ignore: prefer_constructors_over_static_methods
  static PlatformSecureStorage get instance =>
      _instance ??= PlatformSecureStorage._();

  // Flutter secure storage fallback for platforms without native implementation
  static final FlutterSecureStorage _defaultFallbackStorage =
      FlutterSecureStorage(
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
  static final FlutterSecureStorage _defaultLegacyStorage =
      FlutterSecureStorage(
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
  bool _nativeAndroidInitialized = false;
  bool _nativeAndroidSetupMissing = false;
  bool _nativeBackendObserved = false;
  (Object, StackTrace)? _nativeInitializationFailure;

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
      } else if (_isStorageIOS) {
        await _initializeIOS();
      } else if (_isStorageAndroid) {
        await _initializeAndroid();
      } else if (_isStorageMacOS) {
        await _initializeMacOS();
      } else if (_isStorageWindows) {
        await _initializeWindows();
      } else if (_isStorageLinux) {
        await _initializeLinux();
      } else {
        throw const PlatformSecureStorageException(
          'Platform not supported for secure storage',
          platform: 'unsupported',
        );
      }

      _isInitialized = true;
      _log.info('Platform secure storage initialized for $_platformName');
      Log.debug(
        '📊 Capabilities: ${_capabilities.map((c) => c.name).join(', ')}',
        name: 'PlatformSecureStorage',
        category: LogCategory.auth,
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
    bool requireHardwareBacked = true,
  }) async {
    await _ensureInitialized();

    _log
      ..fine('📱 Storing key with ID: $keyId')
      ..fine(
        '⚙️ Hardware required: $requireHardwareBacked',
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

  /// Checks raw key presence without treating unreadable storage as empty.
  ///
  /// Any stored bytes count as present, including malformed key records. This
  /// operation does not decode, migrate, cache, or mutate them. Absence needs
  /// empty current and legacy reads for each selected fallback store, plus an
  /// explicit `false` from any initialized native backend. Read failures and
  /// uncertain native results are propagated.
  Future<bool> hasKeyStrict(String keyId) async {
    await _ensureInitialized();
    _throwIfNativeInitializationFailed();
    await _attestMissingNativeReads(keyId, null);

    if (_useFallbackStorage) {
      final currentValue = await _fallbackStorage.read(key: keyId);
      if (currentValue != null) return true;

      final legacyValue = await _legacyStorage.read(key: keyId);
      if (legacyValue != null) return true;
    }

    if (_useFallbackStorage && !_nativeAndroidInitialized) return false;

    return _readNativePresenceStrict(keyId);
  }

  Future<bool> _readNativePresenceStrict(String keyId) async {
    final result = await _channel.invokeMethod<Object?>('hasKey', {
      'keyId': keyId,
    });
    if (result is bool) return result;

    throw PlatformSecureStorageException(
      'Native key presence could not be verified',
      code: 'key_presence_unverified',
      platform: _platformName,
    );
  }

  Future<void> _attestMissingNativeReads(
    String keyId,
    void Function()? ensureCurrent,
  ) async {
    if (!_nativeAndroidSetupMissing || _nativeBackendObserved) return;

    for (final method in ['hasKey', 'retrieveKey']) {
      ensureCurrent?.call();
      var methodMissing = false;
      Object? failure;
      StackTrace? failureStack;
      try {
        await _channel.invokeMethod<Object?>(method, {'keyId': keyId});
      } on MissingPluginException {
        methodMissing = true;
      } on Object catch (error, stackTrace) {
        failure = error;
        failureStack = stackTrace;
      }
      // A retired caller cannot change backend proof after an awaited probe.
      ensureCurrent?.call();
      if (methodMissing) continue;

      _nativeBackendObserved = true;
      _nativeInitializationFailure = (
        failure ??
            const PlatformSecureStorageException(
              'Native key storage setup could not be verified',
              code: 'native_initialization_unverified',
            ),
        failureStack ?? StackTrace.current,
      );
      _throwIfNativeInitializationFailed();
    }
  }

  /// Removes only records whose private key proves [ownerPubkey] ownership.
  ///
  /// Current and legacy slots are inspected before any deletion. Malformed,
  /// contradictory, or unavailable records refuse the operation. Foreign
  /// records are preserved and compared again after deletion; matching records
  /// must be demonstrably absent. [ensureCurrent] guards every awaited IO.
  Future<void> deleteOwnedLoginRecordsStrict({
    required String primaryKeyId,
    required String identityKeyId,
    required String ownerPubkey,
    void Function()? ensureCurrent,
  }) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(ownerPubkey)) {
      throw const PlatformSecureStorageException(
        'A complete canonical owner public key is required',
        code: 'invalid_owner_pubkey',
      );
    }
    await _strictIO(_ensureInitialized, ensureCurrent);
    _throwIfNativeInitializationFailed();

    for (final keyId in {primaryKeyId, identityKeyId}) {
      await _attestMissingNativeReads(keyId, ensureCurrent);
    }

    final snapshots = <_StrictKeySnapshot>[];
    for (final keyId in {primaryKeyId, identityKeyId}) {
      if (_useFallbackStorage) {
        for (final storage in [_fallbackStorage, _legacyStorage]) {
          snapshots.add(
            await _readStrictSnapshot(keyId, storage, ensureCurrent),
          );
        }
      }
      if (!_useFallbackStorage || _nativeAndroidInitialized) {
        snapshots.add(await _readStrictSnapshot(keyId, null, ensureCurrent));
      }
    }

    for (final snapshot in snapshots) {
      if (snapshot.keyId == identityKeyId &&
          snapshot.ownerPubkey != null &&
          snapshot.ownerPubkey != ownerPubkey) {
        throw const PlatformSecureStorageException(
          'Saved key identity contradicts its account coordinate',
          code: 'key_record_unverified',
        );
      }
    }

    // Establish every record's ownership before the first destructive IO.
    for (final snapshot in snapshots) {
      await _requireUnchangedSnapshot(snapshot, ensureCurrent);
    }

    var removedOwnedRecord = false;
    for (final snapshot in snapshots) {
      if (snapshot.ownerPubkey != ownerPubkey) continue;
      final beforeDelete = await _readStrictSnapshot(
        snapshot.keyId,
        snapshot.storage,
        ensureCurrent,
      );
      // On platforms where current and legacy options share one backend, an
      // earlier proven deletion may already have removed this same record.
      if (removedOwnedRecord && beforeDelete.ownerPubkey == null) continue;
      if (!snapshot.matches(beforeDelete)) {
        throw const PlatformSecureStorageException(
          'A key record changed before removal',
          code: 'key_record_changed',
        );
      }
      final storage = snapshot.storage;
      if (storage != null) {
        await _strictIO(
          () => storage.delete(key: snapshot.keyId),
          ensureCurrent,
        );
      } else {
        final result = await _strictIO(
          () => _channel.invokeMethod<Object?>('deleteKey', {
            'keyId': snapshot.keyId,
          }),
          ensureCurrent,
        );
        if (result is! Map || result['success'] != true) {
          throw const PlatformSecureStorageException(
            'Native key deletion was not confirmed',
            code: 'key_deletion_unverified',
          );
        }
      }
      final after = await _readStrictSnapshot(
        snapshot.keyId,
        snapshot.storage,
        ensureCurrent,
      );
      if (after.ownerPubkey != null) {
        throw const PlatformSecureStorageException(
          'A deleted key record remains in storage',
          code: 'key_deletion_unverified',
        );
      }
      removedOwnedRecord = true;
    }

    // Verify matching keys stayed absent and foreign records stayed intact.
    for (final snapshot in snapshots) {
      final after = await _readStrictSnapshot(
        snapshot.keyId,
        snapshot.storage,
        ensureCurrent,
      );
      if (snapshot.ownerPubkey == ownerPubkey) {
        if (after.ownerPubkey != null) {
          throw const PlatformSecureStorageException(
            'Owned key removal could not be verified',
            code: 'key_deletion_unverified',
          );
        }
      } else if (!snapshot.matches(after)) {
        throw const PlatformSecureStorageException(
          'A foreign key record changed during removal',
          code: 'key_record_changed',
        );
      }
    }
  }

  Future<void> _requireUnchangedSnapshot(
    _StrictKeySnapshot snapshot,
    void Function()? ensureCurrent,
  ) async {
    final current = await _readStrictSnapshot(
      snapshot.keyId,
      snapshot.storage,
      ensureCurrent,
    );
    if (!snapshot.matches(current)) {
      throw const PlatformSecureStorageException(
        'A key record changed before removal',
        code: 'key_record_changed',
      );
    }
  }

  Future<_StrictKeySnapshot> _readStrictSnapshot(
    String keyId,
    FlutterSecureStorage? storage,
    void Function()? ensureCurrent,
  ) async {
    if (storage != null) {
      final raw = await _strictIO(
        () => storage.read(key: keyId),
        ensureCurrent,
      );
      return _StrictKeySnapshot(
        keyId: keyId,
        storage: storage,
        raw: raw,
        ownerPubkey: raw == null ? null : _ownerFromRawRecord(raw),
      );
    }

    final present = await _strictIO(
      () => _readNativePresenceStrict(keyId),
      ensureCurrent,
    );
    if (!present) return _StrictKeySnapshot(keyId: keyId);
    final result = await _strictIO(
      () => _channel.invokeMethod<Object?>('retrieveKey', {'keyId': keyId}),
      ensureCurrent,
    );
    if (result is! Map || result['success'] != true) {
      throw const PlatformSecureStorageException(
        'Native key ownership could not be read',
        code: 'key_record_unverified',
      );
    }
    final fields = <String, Object?>{
      'privateKeyHex': result['privateKeyHex'],
      'publicKeyHex': result['publicKeyHex'],
      'npub': result['npub'],
    };
    return _StrictKeySnapshot(
      keyId: keyId,
      nativeFields: fields,
      ownerPubkey: _ownerFromFields(fields),
    );
  }

  String _ownerFromRawRecord(String raw) {
    const keys = {'privateKeyHex', 'publicKeyHex', 'npub'};
    final fields = <String, Object?>{};
    for (final pair in raw.split('|')) {
      final parts = pair.split(':');
      if (parts.length != 2 ||
          !keys.contains(parts.first) ||
          fields.containsKey(parts.first)) {
        throw const PlatformSecureStorageException(
          'Stored key ownership could not be verified',
          code: 'key_record_unverified',
        );
      }
      fields[parts.first] = parts.last;
    }
    if (fields.length != keys.length) {
      throw const PlatformSecureStorageException(
        'Stored key ownership could not be verified',
        code: 'key_record_unverified',
      );
    }
    return _ownerFromFields(fields);
  }

  String _ownerFromFields(Map<String, Object?> fields) {
    final privateKey = fields['privateKeyHex'];
    if (privateKey is! String) {
      throw const PlatformSecureStorageException(
        'Stored key ownership could not be verified',
        code: 'key_record_unverified',
      );
    }
    SecureKeyContainer? container;
    try {
      container = SecureKeyContainer.fromPrivateKeyHex(privateKey);
      final pubkey = container.publicKeyHex;
      final storedPubkey = fields['publicKeyHex'];
      final storedNpub = fields['npub'];
      if ((storedPubkey != null && storedPubkey != pubkey) ||
          (storedNpub != null && storedNpub != container.npub)) {
        throw const PlatformSecureStorageException(
          'Stored key identity contradicts its private key',
          code: 'key_record_unverified',
        );
      }
      return pubkey;
    } on SecureKeyException {
      throw const PlatformSecureStorageException(
        'Stored key ownership could not be verified',
        code: 'key_record_unverified',
      );
    } finally {
      container?.dispose();
    }
  }

  Future<T> _strictIO<T>(
    Future<T> Function() operation,
    void Function()? ensureCurrent,
  ) async {
    ensureCurrent?.call();
    final result = await operation();
    ensureCurrent?.call();
    return result;
  }

  void _throwIfNativeInitializationFailed() {
    if (_nativeInitializationFailure case (final error, final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
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
      if (_isStorageIOS) {
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
      _nativeBackendObserved = true;

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
      if (e is! MissingPluginException) _nativeBackendObserved = true;
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
      _nativeAndroidInitialized = true;
    } on Object catch (e, stackTrace) {
      if (e is MissingPluginException) _nativeAndroidSetupMissing = true;
      // A missing method does not prove the whole native backend is absent.
      if (e is! MissingPluginException || _nativeBackendObserved) {
        _nativeInitializationFailure = (e, stackTrace);
      }
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

final class _StrictKeySnapshot {
  const _StrictKeySnapshot({
    required this.keyId,
    this.storage,
    this.raw,
    this.nativeFields,
    this.ownerPubkey,
  });

  final String keyId;
  final FlutterSecureStorage? storage;
  final String? raw;
  final Map<String, Object?>? nativeFields;
  final String? ownerPubkey;

  bool matches(_StrictKeySnapshot other) =>
      keyId == other.keyId &&
      identical(storage, other.storage) &&
      raw == other.raw &&
      mapEquals(nativeFields, other.nativeFields) &&
      ownerPubkey == other.ownerPubkey;
}
