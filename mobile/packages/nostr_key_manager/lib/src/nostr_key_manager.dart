// ABOUTME: Secure Nostr key management with hardware-backed persistence and backup
// ABOUTME: Handles key generation, secure storage using platform security, import/export, and security

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nostr_encoding.dart';
import 'secure_key_storage_service.dart';

final _log = Logger('NostrKeyManager');

// Simple KeyPair class to replace Keychain
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class Keychain {
  Keychain(this.private) : public = getPublicKey(private);
  final String private;
  final String public;

  static Keychain generate() {
    final privateKey = generatePrivateKey();
    return Keychain(privateKey);
  }
}

/// Secure management of Nostr private keys with hardware-backed persistence
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
/// SECURITY: Now uses SecureKeyStorageService for hardware-backed key storage
class NostrKeyManager {
  static const String _keyPairKey = 'nostr_keypair';
  static const String _keyVersionKey = 'nostr_key_version';
  static const String _backupHashKey = 'nostr_backup_hash';

  final SecureKeyStorageService _secureStorage;
  Keychain? _keyPair;
  bool _isInitialized = false;
  String? _backupHash;
  bool _hasBackupCached = false;

  NostrKeyManager() : _secureStorage = SecureKeyStorageService();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get hasKeys => _keyPair != null;
  String? get publicKey => _keyPair?.public;
  String? get privateKey => _keyPair?.private;
  Keychain? get keyPair => _keyPair;
  bool get hasBackup => _hasBackupCached;

  /// Initialize key manager and load existing keys
  Future<void> initialize() async {
    try {
      _log.fine('🔧 Initializing Nostr key manager with secure storage...');

      // Initialize secure storage service
      await _secureStorage.initialize();

      // Try to load existing keys from secure storage
      if (await _secureStorage.hasKeys()) {
        _log.fine('📱 Loading existing Nostr keys from secure storage...');

        final secureContainer = await _secureStorage.getKeyContainer();
        if (secureContainer != null) {
          // Convert from secure container to our Keychain format
          // Use withPrivateKey to safely access the private key
          secureContainer.withPrivateKey((privateKeyHex) {
            _keyPair = Keychain(privateKeyHex);
          });
          secureContainer.dispose(); // Clean up secure memory

          _log.info('Keys loaded from secure storage');
        }
      } else {
        // Check for legacy keys in SharedPreferences for migration
        await _migrateLegacyKeys();
      }

      // Load backup hash (still using SharedPreferences for non-sensitive metadata)
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
    } catch (e) {
      _log.severe('Failed to initialize key manager: $e');
      rethrow;
    }
  }

  /// Generate new Nostr key pair
  Future<Keychain> generateKeys() async {
    if (!_isInitialized) {
      throw const NostrKeyException('Key manager not initialized');
    }

    try {
      _log.fine('📱 Generating new Nostr key pair with secure storage...');

      // Generate and store keys securely
      final secureContainer = await _secureStorage.generateAndStoreKeys();

      // Keep a copy in memory for immediate use
      // Use withPrivateKey to safely access the private key
      secureContainer.withPrivateKey((privateKeyHex) {
        _keyPair = Keychain(privateKeyHex);
      });

      // Clean up secure container after extracting what we need
      secureContainer.dispose();

      _log.info('New Nostr key pair generated and saved');
      _log.finer('Public key: ${_keyPair!.public}');

      return _keyPair!;
    } catch (e) {
      _log.severe('Failed to generate keys: $e');
      throw NostrKeyException('Failed to generate new keys: $e');
    }
  }

  /// Import key pair from private key
  Future<Keychain> importPrivateKey(String privateKey) async {
    if (!_isInitialized) {
      throw const NostrKeyException('Key manager not initialized');
    }

    try {
      _log.fine('📱 Importing Nostr private key to secure storage...');

      // Validate private key format (64 character hex)
      if (!_isValidPrivateKey(privateKey)) {
        throw const NostrKeyException('Invalid private key format');
      }

      // Convert to nsec format for secure storage
      final nsec = _hexToNsec(privateKey);

      // Import and store in secure storage
      final secureContainer = await _secureStorage.importFromNsec(nsec);

      // Keep a copy in memory for immediate use
      _keyPair = Keychain(privateKey);

      // Clean up secure container
      secureContainer.dispose();

      _log.info('Private key imported successfully');
      _log.finer('Public key: ${_keyPair!.public}');

      return _keyPair!;
    } catch (e) {
      _log.severe('Failed to import private key: $e');
      throw NostrKeyException('Failed to import private key: $e');
    }
  }

  /// Import nsec (bech32-encoded private key)
  Future<Keychain> importFromNsec(String nsec) async {
    if (!_isInitialized) {
      throw const NostrKeyException('Key manager not initialized');
    }

    try {
      _log.fine('📱 Importing Nostr nsec key to secure storage...');

      // Validate nsec format
      if (!nsec.startsWith('nsec1')) {
        throw const NostrKeyException(
          'Invalid nsec format - must start with nsec1',
        );
      }

      // Decode nsec to hex private key for validation
      final privateKeyHex = NostrEncoding.decodePrivateKey(nsec);
      if (!_isValidPrivateKey(privateKeyHex)) {
        throw const NostrKeyException('Invalid private key derived from nsec');
      }

      // Import and store in secure storage
      final secureContainer = await _secureStorage.importFromNsec(nsec);

      // Keep a copy in memory for immediate use
      _keyPair = Keychain(privateKeyHex);

      // Clean up secure container
      secureContainer.dispose();

      _log.info('Nsec key imported successfully');
      _log.finer('Public key: ${_keyPair!.public}');

      return _keyPair!;
    } catch (e) {
      _log.severe('Failed to import nsec: $e');
      throw NostrKeyException('Failed to import nsec: $e');
    }
  }

  /// Export private key for backup
  String exportPrivateKey() {
    if (!hasKeys) {
      throw const NostrKeyException('No keys available for export');
    }

    _log.fine('📱 Exporting private key for backup');
    return _keyPair!.private;
  }

  /// Export private key as nsec (bech32 format)
  String exportAsNsec() {
    if (!hasKeys) {
      throw const NostrKeyException('No keys available for export');
    }

    _log.fine('📱 Exporting private key as nsec');
    return NostrEncoding.encodePrivateKey(_keyPair!.private);
  }

  /// Replace current key with new one, backing up the old key
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
    } catch (e) {
      _log.severe('Failed to replace key: $e');
      throw NostrKeyException('Failed to replace key: $e');
    }
  }

  /// Restore backup key as active key
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
    } catch (e) {
      _log.severe('Failed to restore backup: $e');
      throw NostrKeyException('Failed to restore backup: $e');
    }
  }

  /// Clear backup key without affecting active key
  Future<void> clearBackup() async {
    _log.fine('📱 Clearing backup key...');

    try {
      await _secureStorage.deleteBackupKey();
      _hasBackupCached = false;

      // Clear backup timestamp from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('backup_created_at');

      _log.info('Backup key cleared');
    } catch (e) {
      _log.severe('Failed to clear backup: $e');
      throw NostrKeyException('Failed to clear backup: $e');
    }
  }

  /// Create mnemonic backup phrase (using private key as entropy)
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
    } catch (e) {
      _log.severe('Failed to create mnemonic backup: $e');
      throw NostrKeyException('Failed to create backup: $e');
    }
  }

  /// Restore from mnemonic backup
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

      // In a real implementation, this would derive the private key from mnemonic
      // For prototype, we'll ask user to provide the private key for verification
      throw const NostrKeyException(
        'Mnemonic restoration requires private key for verification in prototype',
      );
    } catch (e) {
      _log.severe('Failed to restore from mnemonic: $e');
      rethrow;
    }
  }

  /// Verify backup integrity
  Future<bool> verifyBackup(List<String> mnemonic, String privateKey) async {
    try {
      final mnemonicString = mnemonic.join(' ');
      final backupBytes = utf8.encode(mnemonicString + privateKey);
      final calculatedHash = sha256.convert(backupBytes).toString();

      return calculatedHash == _backupHash;
    } catch (e) {
      _log.severe('Backup verification failed: $e');
      return false;
    }
  }

  /// Clear all stored keys (logout)
  Future<void> clearKeys() async {
    try {
      _log.fine('📱 Clearing stored Nostr keys from secure storage...');

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
    } catch (e) {
      _log.severe('Failed to clear keys: $e');
      throw NostrKeyException('Failed to clear keys: $e');
    }
  }

  /// Migrate legacy keys from SharedPreferences to secure storage
  Future<void> _migrateLegacyKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingKeyData = prefs.getString(_keyPairKey);

      if (existingKeyData != null) {
        _log.warning(
          '⚠️ Found legacy keys in SharedPreferences, migrating to secure storage...',
        );

        try {
          final keyData = jsonDecode(existingKeyData) as Map<String, dynamic>;
          final privateKey = keyData['private'] as String?;
          final publicKey = keyData['public'] as String?;

          if (privateKey != null &&
              publicKey != null &&
              _isValidPrivateKey(privateKey) &&
              _isValidPublicKey(publicKey)) {
            // Convert to nsec and import to secure storage
            final nsec = _hexToNsec(privateKey);
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
        } catch (e) {
          _log.severe('Failed to migrate legacy keys: $e');
          // Don't throw - allow user to regenerate if migration fails
        }
      }
    } catch (e) {
      _log.severe('Error checking for legacy keys: $e');
    }
  }

  /// Convert hex private key to nsec (bech32) format
  String _hexToNsec(String hexPrivateKey) {
    // Use NostrEncoding utility for proper bech32 encoding
    return NostrEncoding.encodePrivateKey(hexPrivateKey);
  }

  /// Validate private key format
  bool _isValidPrivateKey(String privateKey) =>
      RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(privateKey);

  /// Validate public key format
  bool _isValidPublicKey(String publicKey) =>
      RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(publicKey);

  /// Convert hex string to bytes
  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  /// Get simple word list for mnemonic (prototype implementation)
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

  /// Get user identity summary
  Map<String, dynamic> getIdentitySummary() {
    if (!hasKeys) {
      return {'hasIdentity': false};
    }

    return {
      'hasIdentity': true,
      'publicKey': publicKey,
      'publicKeyShort': publicKey!,
      'hasBackup': hasBackup,
      'isInitialized': isInitialized,
    };
  }
}

/// Exception thrown by key manager operations
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class NostrKeyException implements Exception {
  const NostrKeyException(this.message);
  final String message;

  @override
  String toString() => 'NostrKeyException: $message';
}
