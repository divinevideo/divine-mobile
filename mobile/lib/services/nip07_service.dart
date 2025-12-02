// ABOUTME: Service for NIP-07 browser extension authentication (Alby, nos2x, Nostore)
// ABOUTME: Provides clean Dart interface for one-click Nostr login via browser extensions

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:openvine/services/nip07_interop.dart' as nip07;
import 'package:openvine/utils/unified_logger.dart';

/// Authentication result from NIP-07 extension
class Nip07AuthResult {
  const Nip07AuthResult({
    required this.success,
    this.publicKey,
    this.errorMessage,
    this.errorCode,
  });

  factory Nip07AuthResult.success(String publicKey) =>
      Nip07AuthResult(success: true, publicKey: publicKey);

  factory Nip07AuthResult.failure(String message, {String? code}) =>
      Nip07AuthResult(success: false, errorMessage: message, errorCode: code);
  final bool success;
  final String? publicKey;
  final String? errorMessage;
  final String? errorCode;
}

/// Event signing result from NIP-07 extension
class Nip07SignResult {
  const Nip07SignResult({
    required this.success,
    this.signedEvent,
    this.errorMessage,
    this.errorCode,
  });

  factory Nip07SignResult.success(Map<String, dynamic> event) =>
      Nip07SignResult(success: true, signedEvent: event);

  factory Nip07SignResult.failure(String message, {String? code}) =>
      Nip07SignResult(success: false, errorMessage: message, errorCode: code);
  final bool success;
  final Map<String, dynamic>? signedEvent;
  final String? errorMessage;
  final String? errorCode;
}

/// Service for managing NIP-07 browser extension interactions
class Nip07Service {
  factory Nip07Service() => _instance;
  Nip07Service._internal();
  static final Nip07Service _instance = Nip07Service._internal();

  String? _currentPublicKey;
  bool _isConnected = false;
  Map<String, dynamic>? _userRelays;

  /// Check if NIP-07 extension is available
  bool get isAvailable {
    // Only available on web platform
    if (!kIsWeb) return false;
    return nip07.isNip07Available;
  }

  /// Check if user is currently connected via NIP-07
  bool get isConnected => _isConnected && _currentPublicKey != null;

  /// Get current user's public key
  String? get publicKey => _currentPublicKey;

  /// Get user's relay configuration (if available)
  Map<String, dynamic>? get userRelays => _userRelays;

  /// Detect available extension name for UI display
  String get extensionName {
    if (!isAvailable) return 'None';

    // Try to detect specific extensions based on available features
    try {
      final ext = nip07.nostr!;

      // Check for Alby-specific features
      if (ext.nip04 != null) {
        return 'Alby or compatible extension';
      }

      return 'Nostr extension';
    } catch (e) {
      return 'Unknown extension';
    }
  }

  /// Attempt to connect and authenticate with NIP-07 extension
  Future<Nip07AuthResult> connect() async {
    if (!isAvailable) {
      return Nip07AuthResult.failure(
        'No NIP-07 extension found. Please install Alby, nos2x, or another compatible extension.',
        code: 'EXTENSION_NOT_FOUND',
      );
    }

    try {
      Log.debug(
        '📱 Attempting NIP-07 authentication...',
        name: 'Nip07Service',
        category: LogCategory.system,
      );

      // Request public key from extension
      final pubkey = await nip07.safeNip07Call(() async {
        return await nip07.nostr!.getPublicKey();
      }, 'get public key');

      // Validate the public key format
      if (pubkey.isEmpty || pubkey.length != 64) {
        return Nip07AuthResult.failure(
          'Invalid public key received from extension',
          code: 'INVALID_PUBKEY',
        );
      }

      _currentPublicKey = pubkey;
      _isConnected = true;

      // Try to get user's relays (optional feature)
      // TODO: Fix tear-off issue with getRelays extension method
      // Currently disabled due to dart:js_interop limitation with external extension type tear-offs
      try {
        // if (nip07.nostr!.getRelays != null) {
        //   final jsRelays = await nip07.nostr!.getRelays!().toDart;
        //   _userRelays = jsRelays.dartify() as Map<String, dynamic>?;
        // }
        Log.debug(
          'Retrieved ${_userRelays?.length ?? 0} relays from extension (disabled)',
          name: 'Nip07Service',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.warning(
          'Extension does not support getRelays: $e',
          name: 'Nip07Service',
          category: LogCategory.system,
        );
        // Not a critical error, continue without relays
      }

      Log.info(
        'NIP-07 authentication successful',
        name: 'Nip07Service',
        category: LogCategory.system,
      );
      Log.verbose(
        'Public key: $pubkey',
        name: 'Nip07Service',
        category: LogCategory.system,
      );

      return Nip07AuthResult.success(pubkey);
    } on nip07.Nip07Exception catch (e) {
      Log.error(
        'NIP-07 authentication failed: ${e.message}',
        name: 'Nip07Service',
        category: LogCategory.system,
      );
      return Nip07AuthResult.failure(e.message, code: e.code);
    } catch (e) {
      Log.error(
        'Unexpected NIP-07 error: $e',
        name: 'Nip07Service',
        category: LogCategory.system,
      );
      return Nip07AuthResult.failure(
        'Unexpected error during authentication: $e',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Sign a Nostr event using the browser extension
  Future<Nip07SignResult> signEvent(Map<String, dynamic> unsignedEvent) async {
    if (!isConnected) {
      return Nip07SignResult.failure(
        'Not connected to NIP-07 extension',
        code: 'NOT_CONNECTED',
      );
    }

    try {
      Log.verbose(
        'Signing event with NIP-07 extension...',
        name: 'Nip07Service',
        category: LogCategory.system,
      );

      // Convert Dart event to JavaScript format
      final jsEvent = nip07.dartEventToJs(unsignedEvent);

      // Sign the event
      final signedJsEvent = await nip07.safeNip07Call(
        () => nip07.nostr!.signEvent(jsEvent.toMap()),
        'sign event',
      );

      // Convert back to Dart format
      final signedEvent = signedJsEvent;

      // Validate the signed event
      if (signedEvent['sig'] == null || signedEvent['id'] == null) {
        return Nip07SignResult.failure(
          'Extension returned incomplete signed event',
          code: 'INCOMPLETE_SIGNATURE',
        );
      }

      Log.info(
        'Event signed successfully',
        name: 'Nip07Service',
        category: LogCategory.system,
      );
      debugPrint('📋 Event ID: ${signedEvent['id']}');

      return Nip07SignResult.success(signedEvent);
    } on nip07.Nip07Exception catch (e) {
      Log.error(
        'Event signing failed: ${e.message}',
        name: 'Nip07Service',
        category: LogCategory.system,
      );
      return Nip07SignResult.failure(e.message, code: e.code);
    } catch (e) {
      Log.error(
        'Unexpected signing error: $e',
        name: 'Nip07Service',
        category: LogCategory.system,
      );
      return Nip07SignResult.failure(
        'Unexpected error during event signing: $e',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Encrypt a message using NIP-04 (if extension supports it)
  Future<String?> encryptMessage(String recipientPubkey, String message) async {
    if (!isConnected || nip07.nostr?.nip04 == null) {
      return null;
    }

    try {
      final encrypted = await nip07.nostr!.nip04!.encrypt(
        recipientPubkey,
        message,
      );
      return encrypted;
    } catch (e) {
      Log.error(
        'NIP-04 encryption failed: $e',
        name: 'Nip07Service',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Decrypt a message using NIP-04 (if extension supports it)
  Future<String?> decryptMessage(
    String senderPubkey,
    String encryptedMessage,
  ) async {
    if (!isConnected || nip07.nostr?.nip04 == null) {
      return null;
    }

    try {
      final decrypted = await nip07.nostr!.nip04!.decrypt(
        senderPubkey,
        encryptedMessage,
      );
      return decrypted;
    } catch (e) {
      Log.error(
        'NIP-04 decryption failed: $e',
        name: 'Nip07Service',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Disconnect from the extension
  void disconnect() {
    _currentPublicKey = null;
    _isConnected = false;
    _userRelays = null;

    Log.info(
      '📱 Disconnected from NIP-07 extension',
      name: 'Nip07Service',
      category: LogCategory.system,
    );
  }

  /// Get connection status for debugging
  Map<String, dynamic> getDebugInfo() => {
    'isAvailable': isAvailable,
    'isConnected': isConnected,
    'publicKey': _currentPublicKey,
    'extensionName': extensionName,
    'hasRelays': _userRelays != null,
    'relayCount': _userRelays?.length ?? 0,
    'hasNip04': nip07.nostr?.nip04 != null,
  };
}
