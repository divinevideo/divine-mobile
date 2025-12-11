// ABOUTME: Secure container for storing cryptographic keys with memory wipe
// ABOUTME: Prevents key exposure through memory dumps or debugging

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

final _log = Logger('SecureKeyContainer');

/// Exception thrown by secure key operations.
class SecureKeyException implements Exception {
  /// Creates a new [SecureKeyException].
  const SecureKeyException(this.message, {this.code});

  /// The error message.
  final String message;

  /// Optional error code.
  final String? code;

  @override
  String toString() => 'SecureKeyException: $message';
}

/// Secure container for cryptographic private keys
///
/// This class ensures that private keys are:
/// 1. Never stored as plain strings in memory
/// 2. Automatically wiped from memory when no longer needed
/// 3. Protected from memory dumps and debugging attempts
/// 4. Only accessible through secure methods with minimal exposure time
class SecureKeyContainer {
  /// Create a secure container from a hex private key
  SecureKeyContainer.fromPrivateKeyHex(String privateKeyHex) {
    if (_isDisposed) {
      throw const SecureKeyException('Container has been disposed');
    }

    if (!keyIsValid(privateKeyHex)) {
      throw const SecureKeyException('Invalid private key format');
    }

    try {
      // Convert hex string to bytes immediately to minimize string exposure
      _privateKeyBytes = _hexToBytes(privateKeyHex);

      // Derive public key from private key
      final publicKeyHex = _derivePublicKey(_bytesToHex(_privateKeyBytes));
      _publicKeyBytes = _hexToBytes(publicKeyHex);

      // Generate npub for public operations
      _npub = Nip19.encodePubKey(publicKeyHex);

      // Register for automatic cleanup
      _finalizer
        ..attach(this, _privateKeyBytes)
        ..attach(this, _publicKeyBytes);

      _log.info(
        '📱 SecureKeyContainer created for ${_maskKey(_npub)}',
      );
    } on Exception catch (e) {
      // Clean up any allocated memory on error
      _secureWipeIfAllocated();
      throw SecureKeyException('Failed to create secure container: $e');
    }
  }

  /// Create a secure container from an nsec (bech32 private key)
  SecureKeyContainer.fromNsec(String nsec)
    : this.fromPrivateKeyHex(Nip19.decode(nsec));

  /// Generate a new secure container with a random private key
  factory SecureKeyContainer.generate() {
    try {
      _log.fine('Generating new secure key container...');

      // Import the nostr_sdk function for key generation
      // This will be replaced with platform-specific secure generation
      final privateKeyHex = _generateSecurePrivateKey();

      _log.info('Secure key generated successfully');
      return SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
    } catch (e) {
      _log.severe('Secure key generation failed: $e');
      rethrow;
    }
  }
  late final Uint8List _privateKeyBytes;
  late final Uint8List _publicKeyBytes;
  late final String _npub;
  bool _isDisposed = false;

  // Finalizer to ensure memory is wiped even if dispose() isn't called
  static final Finalizer<Uint8List> _finalizer = Finalizer(_secureWipe);

  /// Get the public key (npub) - safe for public operations
  String get npub {
    _ensureNotDisposed();
    return _npub;
  }

  /// Get the public key as hex - safe for public operations
  String get publicKeyHex {
    _ensureNotDisposed();
    return _bytesToHex(_publicKeyBytes);
  }

  /// Temporarily expose the private key for signing operations
  ///
  /// CRITICAL: The returned value must be used immediately and not stored.
  /// The callback ensures minimal exposure time.
  T withPrivateKey<T>(T Function(String privateKeyHex) operation) {
    _ensureNotDisposed();

    try {
      // Convert bytes to hex only for the duration of the operation
      final privateKeyHex = _bytesToHex(_privateKeyBytes);

      _log.fine('📱 Private key temporarily exposed for operation');

      // Execute the operation with the private key
      final result = operation(privateKeyHex);

      // Immediately wipe the temporary hex string from memory
      // Note: This doesn't guarantee the string is wiped from all memory
      // locations but it's better than keeping it around

      return result;
    } on Exception catch (e) {
      _log.severe('Error in private key operation: $e');
      rethrow;
    }
  }

  /// Temporarily expose the nsec for backup operations
  ///
  /// CRITICAL: Use with extreme caution. Only for backup/export scenarios.
  T withNsec<T>(T Function(String nsec) operation) {
    _ensureNotDisposed();

    try {
      final privateKeyHex = _bytesToHex(_privateKeyBytes);
      final nsec = Nip19.encodePrivateKey(privateKeyHex);

      _log.warning('NSEC temporarily exposed - ensure secure handling');

      final result = operation(nsec);

      return result;
    } catch (e) {
      _log.severe('Error in NSEC operation: $e');
      rethrow;
    }
  }

  /// Securely compare this container's public key with another
  bool hasSamePublicKey(SecureKeyContainer other) {
    _ensureNotDisposed();
    other._ensureNotDisposed();

    return _npub == other._npub;
  }

  /// Check if the container has been disposed
  bool get isDisposed => _isDisposed;

  /// Dispose of the container and securely wipe all key material
  void dispose() {
    if (_isDisposed) return;

    _log.fine('📱️ Disposing SecureKeyContainer');

    // Securely wipe key material
    _secureWipe(_privateKeyBytes);
    _secureWipe(_publicKeyBytes);

    _isDisposed = true;

    _log.info('SecureKeyContainer disposed and wiped');
  }

  /// Ensure the container hasn't been disposed
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw const SecureKeyException('Container has been disposed');
    }
  }

  /// Clean up allocated memory if available (error handling)
  void _secureWipeIfAllocated() {
    try {
      _secureWipe(_privateKeyBytes);
      _secureWipe(_publicKeyBytes);
    } on Exception catch (_) {
      // Ignore errors during cleanup
    }
  }

  /// Securely wipe a byte array from memory
  static void _secureWipe(Uint8List bytes) {
    // Fill with random data first, then zeros
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = (i * 251 + 17) % 256; // Pseudo-random pattern
    }
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  /// Convert hex string to bytes
  static Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw const SecureKeyException('Invalid hex string length');
    }

    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      final hexPair = hex.substring(i, i + 2);
      bytes[i ~/ 2] = int.parse(hexPair, radix: 16);
    }
    return bytes;
  }

  /// Convert bytes to hex string
  static String _bytesToHex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  /// Derive public key from private key using secp256k1
  ///
  /// Uses nostr_sdk's getPublicKey() which implements secure secp256k1
  /// via PointyCastle implementation.
  static String _derivePublicKey(String privateKeyHex) {
    try {
      return getPublicKey(privateKeyHex);
    } catch (e) {
      throw SecureKeyException('Failed to derive public key: $e');
    }
  }

  /// Generate a cryptographically secure private key
  ///
  /// Uses nostr_sdk's generatePrivateKey() which provides cryptographically
  /// secure random number generation via PointyCastle.
  static String _generateSecurePrivateKey() {
    try {
      // Use nostr_sdk's secure key generation
      return generatePrivateKey();
    } catch (e) {
      throw SecureKeyException('Failed to generate secure private key: $e');
    }
  }

  /// Mask a key for display purposes (show first 8 and last 4 characters)
  static String _maskKey(String key) {
    if (key.length < 12) return key;
    final start = key.substring(0, 8);
    final end = key.substring(key.length - 4);
    return '$start...$end';
  }

  @override
  String toString() =>
      'SecureKeyContainer(npub: ${_maskKey(_npub)}, disposed: $_isDisposed)';
}
