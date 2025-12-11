// ABOUTME: Secure Nostr key management with hardware-backed persistence
// ABOUTME: Handles key generation, secure storage, import/export

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:nostr_key_manager/src/secure_key_storage.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('NostrKeyManager');

/// Simple key pair wrapper using nostr_sdk for key operations.
///
/// This is a convenience class that wraps a private/public key pair.
/// All key generation and derivation uses nostr_sdk's functions:
/// - generatePrivateKey() for key generation
/// - getPublicKey() for public key derivation
class Keychain {
  /// Creates a keychain from a private key.
  ///
  /// The public key is automatically derived using nostr_sdk's getPublicKey().
  Keychain(this.private) : public = getPublicKey(private);

  /// Generate a new key pair using nostr_sdk's secure key generation.
  ///
  /// Returns a new [Keychain] with a randomly generated private key.
  factory Keychain.generate() {
    final privateKey = generatePrivateKey();
    return Keychain(privateKey);
  }

  /// The private key in hex format (64 characters).
  final String private;

  /// The public key in hex format (64 characters), derived from [private].
  final String public;
}

/// Secure management of Nostr private keys with hardware-backed persistence.
///
/// This class provides secure key management with:
/// - Hardware-backed secure storage via [SecureKeyStorage]
/// - Key generation, import, and export
/// - Backup and restore functionality
/// - Legacy key migration from SharedPreferences
class NostrKeyManager {
  /// Creates a new [NostrKeyManager] instance.
  ///
  /// The key manager must be initialized by calling [initialize()] before use.
  NostrKeyManager() : _secureStorage = SecureKeyStorage();

  static const String _keyPairKey = 'nostr_keypair';
  static const String _keyVersionKey = 'nostr_key_version';
  static const String _backupHashKey = 'nostr_backup_hash';

  final SecureKeyStorage _secureStorage;
  Keychain? _keyPair;
  bool _isInitialized = false;
  String? _backupHash;
  bool _hasBackupCached = false;

  /// Whether the key manager has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether keys are currently loaded.
  bool get hasKeys => _keyPair != null;

  /// The public key if keys are loaded, null otherwise.
  String? get publicKey => _keyPair?.public;

  /// The private key if keys are loaded, null otherwise.
  String? get privateKey => _keyPair?.private;

  /// The key pair if keys are loaded, null otherwise.
  Keychain? get keyPair => _keyPair;

  /// Whether a backup key exists.
  bool get hasBackup => _hasBackupCached;

  /// Initialize key manager and load existing keys.
  ///
  /// This method must be called before using any other methods.
  /// It will:
  /// - Initialize the secure storage service
  /// - Load existing keys from secure storage if available
  /// - Migrate legacy keys from SharedPreferences if found
  /// - Load backup key status
  ///
  /// Throws [NostrKeyException] if initialization fails.
  Future<void> initialize() async {
    try {
      _log.fine(
        '🔧 Initializing Nostr key manager with secure storage...',
      );

      // Initialize secure storage service
      await _secureStorage.initialize();

      // Try to load existing keys from secure storage
      if (await _secureStorage.hasKeys()) {
        _log.fine(
          '📱 Loading existing Nostr keys from secure storage...',
        );

        final secureContainer = await _secureStorage.getKeyContainer();
        if (secureContainer != null) {
          // Convert from secure container to our Keychain format
          // Use withPrivateKey to safely access the private key
          secureContainer
            ..withPrivateKey((privateKeyHex) {
              _keyPair = Keychain(privateKeyHex);
            })
            ..dispose(); // Clean up secure memory

          _log.info('Keys loaded from secure storage');
        }
      } else {
        // Check for legacy keys in SharedPreferences for migration
        await _migrateLegacyKeys();
      }

      // Load backup hash (using SharedPreferences for non-sensitive metadata)
      final prefs = await SharedPreferences.getInstance();
      _backupHash = prefs.getString(_backupHashKey);

      // Check if backup key exists in secure storage
      _hasBackupCached = await _secureStorage.hasBackupKey();

      _isInitialized = true;

      if (hasKeys) {
        _log.info(
          'Key manager initialized with existing identity (secure storage)',
        );
      } else {
        _log.info('Key manager initialized, ready for key generation');
      }
    } on Exception catch (e) {
      _log.severe('Failed to initialize key manager: $e');
      rethrow;
    }
  }

  /// Generate new Nostr key pair.
  ///
  /// Generates a new key pair and stores it securely.
  /// Returns the generated [Keychain].
  ///
  /// Throws [NostrKeyException] if:
  /// - Key manager is not initialized
  /// - Key generation fails
  Future<Keychain> generateKeys() async {
    if (!_isInitialized) {
      throw const NostrKeyException('Key manager not initialized');
    }

    try {
      _log.fine(
        '📱 Generating new Nostr key pair with secure storage...',
      );

      // Generate and store keys securely
      final secureContainer = await _secureStorage.generateAndStoreKeys();

      // Keep a copy in memory for immediate use
      // Use withPrivateKey to safely access the private key
      secureContainer
        ..withPrivateKey((privateKeyHex) {
          _keyPair = Keychain(privateKeyHex);
        })
        ..dispose(); // Clean up secure container after extracting what we need

      _log
        ..info('New Nostr key pair generated and saved')
        ..finer('Public key: ${_keyPair!.public}');

      return _keyPair!;
    } on Exception catch (e) {
      _log.severe('Failed to generate keys: $e');
      throw NostrKeyException('Failed to generate new keys: $e');
    }
  }

  /// Import key pair from private key.
  ///
  /// Validates and imports a private key in hex format (64 characters).
  /// Returns the imported [Keychain].
  ///
  /// Throws [NostrKeyException] if:
  /// - Key manager is not initialized
  /// - Private key format is invalid
  /// - Import fails
  Future<Keychain> importPrivateKey(String privateKey) async {
    if (!_isInitialized) {
      throw const NostrKeyException('Key manager not initialized');
    }

    try {
      _log.fine(
        '📱 Importing Nostr private key to secure storage...',
      );

      // Validate private key format (64 character hex)
      if (!keyIsValid(privateKey)) {
        throw const NostrKeyException('Invalid private key format');
      }

      // Convert to nsec format for secure storage
      final nsec = Nip19.encodePrivateKey(privateKey);

      // Import and store in secure storage
      final secureContainer = await _secureStorage.importFromNsec(nsec);

      // Keep a copy in memory for immediate use
      _keyPair = Keychain(privateKey);

      // Clean up secure container
      secureContainer.dispose();

      _log
        ..info('Private key imported successfully')
        ..finer('Public key: ${_keyPair!.public}');

      return _keyPair!;
    } on Exception catch (e) {
      _log.severe('Failed to import private key: $e');
      throw NostrKeyException('Failed to import private key: $e');
    }
  }

  /// Import nsec (bech32-encoded private key).
  ///
  /// Validates and imports a private key in nsec format.
  /// Returns the imported [Keychain].
  ///
  /// Throws [NostrKeyException] if:
  /// - Key manager is not initialized
  /// - Nsec format is invalid
  /// - Import fails
  Future<Keychain> importFromNsec(String nsec) async {
    if (!_isInitialized) {
      throw const NostrKeyException('Key manager not initialized');
    }

    try {
      _log.fine(
        '📱 Importing Nostr nsec key to secure storage...',
      );

      // Validate nsec format
      if (!nsec.startsWith('nsec1')) {
        throw const NostrKeyException(
          'Invalid nsec format - must start with nsec1',
        );
      }

      // Decode nsec to hex private key for validation
      final privateKeyHex = Nip19.decode(nsec);
      if (!keyIsValid(privateKeyHex)) {
        throw const NostrKeyException(
          'Invalid private key derived from nsec',
        );
      }

      // Import and store in secure storage
      final secureContainer = await _secureStorage.importFromNsec(nsec);

      // Keep a copy in memory for immediate use
      _keyPair = Keychain(privateKeyHex);

      // Clean up secure container
      secureContainer.dispose();

      _log
        ..info('Nsec key imported successfully')
        ..finer('Public key: ${_keyPair!.public}');

      return _keyPair!;
    } on Exception catch (e) {
      _log.severe('Failed to import nsec: $e');
      throw NostrKeyException('Failed to import nsec: $e');
    }
  }

  /// Export private key for backup.
  ///
  /// Returns the private key in hex format.
  ///
  /// Throws [NostrKeyException] if no keys are available.
  String exportPrivateKey() {
    if (!hasKeys) {
      throw const NostrKeyException('No keys available for export');
    }

    _log.fine('📱 Exporting private key for backup');
    return _keyPair!.private;
  }

  /// Export private key as nsec (bech32 format).
  ///
  /// Returns the private key encoded as nsec.
  ///
  /// Throws [NostrKeyException] if no keys are available.
  String exportAsNsec() {
    if (!hasKeys) {
      throw const NostrKeyException('No keys available for export');
    }

    _log.fine('📱 Exporting private key as nsec');
    return Nip19.encodePrivateKey(_keyPair!.private);
  }

  /// Replace current key with new one, backing up the old key.
  ///
  /// Saves the current key as a backup and generates a new key pair.
  /// Returns a map containing information about the old key and backup time.
  ///
  /// Throws [NostrKeyException] if:
  /// - No keys are available
  /// - Backup or key generation fails
  Future<Map<String, dynamic>> replaceKeyWithBackup() async {
    if (!hasKeys) {
      throw const NostrKeyException('No keys available to backup');
    }

    _log.fine('📱 Replacing key with backup...');

    try {
      // Save current keys info for return
      final oldPrivateKey = _keyPair!.private;
      final oldPublicKey = _keyPair!.public;
      final backedUpAt = DateTime.now();

      // Save old key as backup
      await _secureStorage.saveBackupKey(oldPrivateKey);

      // Update backup cache
      _hasBackupCached = true;

      // Generate new keypair
      await generateKeys();

      _log.info('Key replaced successfully, old key backed up');

      return {
        'oldPrivateKey': oldPrivateKey,
        'oldPublicKey': oldPublicKey,
        'backedUpAt': backedUpAt,
      };
    } on Exception catch (e) {
      _log.severe('Failed to replace key: $e');
      throw NostrKeyException('Failed to replace key: $e');
    }
  }

  /// Restore backup key as active key.
  ///
  /// Swaps the current key (if any) with the backup key.
  /// If a current key exists, it becomes the new backup.
  ///
  /// Throws [NostrKeyException] if:
  /// - No backup is available
  /// - Restore operation fails
  Future<void> restoreFromBackup() async {
    if (!hasBackup) {
      throw const NostrKeyException('No backup available to restore');
    }

    _log.fine('📱 Restoring backup key as active key...');

    try {
      // Save current key as new backup (swap operation)
      String? currentPrivateKey;
      if (hasKeys) {
        currentPrivateKey = _keyPair!.private;
      }

      // Get backup key
      final backupContainer = await _secureStorage.getBackupKeyContainer();
      if (backupContainer == null) {
        throw const NostrKeyException('Backup key not found in storage');
      }

      // Extract private key from backup container and store/set as active
      String? backupPrivateKey;
      backupContainer.withPrivateKey((privateKeyHex) {
        backupPrivateKey = privateKeyHex;
        _keyPair = Keychain(privateKeyHex);
      });

      // Store the restored key as primary key
      await _secureStorage.importFromHex(backupPrivateKey!);

      // If there was a current key, save it as the new backup
      if (currentPrivateKey != null) {
        await _secureStorage.saveBackupKey(currentPrivateKey);
        _hasBackupCached = true;
      } else {
        // No current key, so clear backup
        _hasBackupCached = false;
      }

      backupContainer.dispose();

      _log.info('Backup key restored as active key');
    } on Exception catch (e) {
      _log.severe('Failed to restore backup: $e');
      throw NostrKeyException('Failed to restore backup: $e');
    }
  }

  /// Clear backup key without affecting active key.
  ///
  /// Throws [NostrKeyException] if the operation fails.
  Future<void> clearBackup() async {
    _log.fine('📱 Clearing backup key...');

    try {
      await _secureStorage.deleteBackupKey();
      _hasBackupCached = false;

      // Clear backup timestamp from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('backup_created_at');

      _log.info('Backup key cleared');
    } on Exception catch (e) {
      _log.severe('Failed to clear backup: $e');
      throw NostrKeyException('Failed to clear backup: $e');
    }
  }

  /// Create mnemonic backup phrase (using private key as entropy).
  ///
  /// **Deprecated**: This is a prototype implementation and should not be used
  /// in production. Use proper BIP39 mnemonic generation instead.
  ///
  /// Returns a list of 12 mnemonic words.
  ///
  /// Throws [NostrKeyException] if no keys are available.
  @Deprecated(
    'This is a prototype implementation. '
    'Use proper BIP39 mnemonic generation instead.',
  )
  Future<List<String>> createMnemonicBackup() async {
    if (!hasKeys) {
      throw const NostrKeyException('No keys available for backup');
    }

    try {
      _log.fine('📱 Creating mnemonic backup...');

      // Use private key as entropy source for mnemonic generation
      final privateKeyBytes = _hexToBytes(_keyPair!.private);

      // Simple word mapping (for prototype - use proper BIP39 in production)
      final wordList = _getSimpleWordList();
      final mnemonic = <String>[];

      // Convert private key bytes to mnemonic words (12 words)
      for (var i = 0; i < 12; i++) {
        final byteIndex = i % privateKeyBytes.length;
        final wordIndex = privateKeyBytes[byteIndex] % wordList.length;
        mnemonic.add(wordList[wordIndex]);
      }

      // Create backup hash for verification
      final mnemonicString = mnemonic.join(' ');
      final backupBytes = utf8.encode(mnemonicString + _keyPair!.private);
      _backupHash = sha256.convert(backupBytes).toString();

      // Save backup hash
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backupHashKey, _backupHash!);

      _log.info('Mnemonic backup created');
      return mnemonic;
    } on Exception catch (e) {
      _log.severe('Failed to create mnemonic backup: $e');
      throw NostrKeyException('Failed to create backup: $e');
    }
  }

  /// Restore from mnemonic backup.
  ///
  /// **Deprecated**: This is a prototype implementation and does not actually
  /// restore keys from mnemonic. Use proper BIP39 mnemonic restoration instead.
  ///
  /// Throws [NostrKeyException] if:
  /// - Key manager is not initialized
  /// - Mnemonic format is invalid
  @Deprecated(
    'This is a prototype implementation. '
    'Use proper BIP39 mnemonic restoration instead.',
  )
  Future<Keychain> restoreFromMnemonic(List<String> mnemonic) async {
    if (!_isInitialized) {
      throw const NostrKeyException('Key manager not initialized');
    }

    try {
      _log.fine('📱 Restoring from mnemonic backup...');

      if (mnemonic.length != 12) {
        throw const NostrKeyException(
          'Invalid mnemonic length (expected 12 words)',
        );
      }

      // Validate mnemonic words
      final wordList = _getSimpleWordList();
      for (final word in mnemonic) {
        if (!wordList.contains(word)) {
          throw NostrKeyException('Invalid mnemonic word: $word');
        }
      }

      // In a real implementation, this would derive the private key
      // from mnemonic. For prototype, we'll ask user to provide the
      // private key for verification.
      throw const NostrKeyException(
        'Mnemonic restoration requires private key for verification '
        'in prototype',
      );
    } on Exception catch (e) {
      _log.severe('Failed to restore from mnemonic: $e');
      rethrow;
    }
  }

  /// Verify backup integrity.
  ///
  /// **Deprecated**: This is a prototype implementation. Use proper BIP39
  /// mnemonic verification instead.
  ///
  /// Returns true if the mnemonic and private key match the stored backup hash.
  @Deprecated(
    'This is a prototype implementation. '
    'Use proper BIP39 mnemonic verification instead.',
  )
  Future<bool> verifyBackup(List<String> mnemonic, String privateKey) async {
    try {
      final mnemonicString = mnemonic.join(' ');
      final backupBytes = utf8.encode(mnemonicString + privateKey);
      final calculatedHash = sha256.convert(backupBytes).toString();

      return calculatedHash == _backupHash;
    } on Exception catch (e) {
      _log.severe('Backup verification failed: $e');
      return false;
    }
  }

  /// Clear all stored keys (logout).
  ///
  /// Removes all keys from secure storage and clears backup keys.
  /// Throws [NostrKeyException] if the operation fails.
  Future<void> clearKeys() async {
    try {
      _log.fine(
        '📱 Clearing stored Nostr keys from secure storage...',
      );

      // Clear from secure storage
      await _secureStorage.deleteKeys();

      // Clear backup key as well
      await _secureStorage.deleteBackupKey();

      // Clear legacy keys from SharedPreferences if they exist
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPairKey);
      await prefs.remove(_keyVersionKey);
      await prefs.remove(_backupHashKey);

      _keyPair = null;
      _backupHash = null;
      _hasBackupCached = false;

      _log.info('Nostr keys cleared successfully');
    } on Exception catch (e) {
      _log.severe('Failed to clear keys: $e');
      throw NostrKeyException('Failed to clear keys: $e');
    }
  }

  /// Get user identity summary.
  ///
  /// Returns a map containing identity information including:
  /// - hasIdentity: whether keys are loaded
  /// - publicKey: the public key if available
  /// - publicKeyShort: same as publicKey (for backward compatibility)
  /// - hasBackup: whether a backup exists
  /// - isInitialized: whether the key manager is initialized
  Map<String, dynamic> getIdentitySummary() {
    if (!hasKeys) {
      return {'hasIdentity': false};
    }

    return {
      'hasIdentity': true,
      'publicKey': publicKey,
      'publicKeyShort': publicKey,
      'hasBackup': hasBackup,
      'isInitialized': isInitialized,
    };
  }

  /// Migrate legacy keys from SharedPreferences to secure storage.
  Future<void> _migrateLegacyKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingKeyData = prefs.getString(_keyPairKey);

      if (existingKeyData != null) {
        _log.warning(
          '⚠️ Found legacy keys in SharedPreferences, '
          'migrating to secure storage...',
        );

        try {
          final keyData = jsonDecode(existingKeyData) as Map<String, dynamic>;
          final privateKey = keyData['private'] as String?;
          final publicKey = keyData['public'] as String?;

          if (privateKey != null &&
              publicKey != null &&
              keyIsValid(privateKey) &&
              keyIsValid(publicKey)) {
            // Convert to nsec and import to secure storage
            final nsec = Nip19.encodePrivateKey(privateKey);
            final secureContainer = await _secureStorage.importFromNsec(nsec);

            // Keep in memory
            _keyPair = Keychain(privateKey);

            // Clean up secure container
            secureContainer.dispose();

            // Remove legacy keys from SharedPreferences
            await prefs.remove(_keyPairKey);
            await prefs.remove(_keyVersionKey);

            _log.info('✅ Successfully migrated keys to secure storage');
          }
        } on Exception catch (e) {
          _log.severe('Failed to migrate legacy keys: $e');
          // Don't throw - allow user to regenerate if migration fails
        }
      }
    } on Exception catch (e) {
      _log.severe('Error checking for legacy keys: $e');
    }
  }

  /// Convert hex string to bytes.
  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  /// Get simple word list for mnemonic (prototype implementation).
  List<String> _getSimpleWordList() => [
    'abandon',
    'ability',
    'able',
    'about',
    'above',
    'absent',
    'absorb',
    'abstract',
    'absurd',
    'abuse',
    'access',
    'accident',
    'account',
    'accuse',
    'achieve',
    'acid',
    'acoustic',
    'acquire',
    'across',
    'action',
    'actor',
    'actress',
    'actual',
    'adapt',
    'add',
    'addict',
    'address',
    'adjust',
    'admit',
    'adult',
    'advance',
    'advice',
    'aerobic',
    'affair',
    'afford',
    'afraid',
    'again',
    'agent',
    'agree',
    'ahead',
    'aim',
    'air',
    'airport',
    'aisle',
    'alarm',
    'album',
    'alcohol',
    'alert',
    'alien',
    'all',
    'alley',
    'allow',
    'almost',
    'alone',
    'alpha',
    'already',
    'also',
    'alter',
    'always',
    'amateur',
    'amazing',
    'among',
    'amount',
    'amused',
    'analyst',
    'anchor',
    'ancient',
    'anger',
    'angle',
    'angry',
    'animal',
    'ankle',
    'announce',
    'annual',
    'another',
    'answer',
    'antenna',
    'antique',
    'anxiety',
    'any',
    'apart',
    'apology',
    'appear',
    'apple',
    'approve',
    'april',
    'area',
    'arena',
    'argue',
    'arm',
    'armed',
    'armor',
    'army',
    'around',
    'arrange',
    'arrest',
    'arrive',
    'arrow',
    'art',
    'artist',
    'artwork',
    'ask',
    'aspect',
    'assault',
    'asset',
    'assist',
    'assume',
    'asthma',
    'athlete',
    'atom',
    'attack',
    'attend',
    'attitude',
    'attract',
    'auction',
    'audit',
    'august',
    'aunt',
    'author',
    'auto',
    'autumn',
    'average',
    'avocado',
    'avoid',
    'awake',
    'aware',
    'away',
    'awesome',
    'awful',
    'awkward',
    'axis',
    'baby',
    'bachelor',
    'bacon',
    'badge',
    'bag',
    'balance',
    'balcony',
    'ball',
    'bamboo',
    'banana',
    'banner',
    'bar',
    'barely',
    'bargain',
    'barrel',
    'base',
    'basic',
    'basket',
    'battle',
    'beach',
    'bean',
    'beauty',
    'because',
    'become',
    'beef',
    'before',
    'begin',
    'behave',
    'behind',
    'believe',
    'below',
    'belt',
    'bench',
    'benefit',
    'best',
    'betray',
    'better',
    'between',
    'beyond',
    'bicycle',
    'bid',
    'bike',
    'bind',
    'biology',
    'bird',
    'birth',
    'bitter',
    'black',
    'blade',
    'blame',
    'blanket',
    'blast',
    'bleak',
    'bless',
    'blind',
    'blood',
    'blossom',
    'blow',
    'blue',
    'blur',
    'blush',
    'board',
    'boat',
    'body',
    'boil',
    'bomb',
    'bone',
    'bonus',
    'book',
    'boost',
    'border',
    'boring',
    'borrow',
    'boss',
    'bottom',
    'bounce',
    'box',
    'boy',
    'bracket',
    'brain',
    'brand',
    'brass',
    'brave',
    'bread',
    'breeze',
    'brick',
    'bridge',
    'brief',
    'bright',
    'bring',
    'brisk',
    'broccoli',
    'broken',
    'bronze',
    'broom',
    'brother',
    'brown',
    'brush',
    'bubble',
    'buddy',
    'budget',
    'buffalo',
    'build',
    'bulb',
    'bulk',
    'bullet',
    'bundle',
    'bunker',
    'burden',
    'burger',
    'burst',
    'bus',
    'business',
    'busy',
    'butter',
    'buyer',
    'buzz',
  ];
}

/// Exception thrown by key manager operations.
class NostrKeyException implements Exception {
  /// Creates a new [NostrKeyException] with the given message.
  const NostrKeyException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'NostrKeyException: $message';
}
