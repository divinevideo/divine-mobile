// ABOUTME: JavaScript interop for NIP-07 browser extension support (Alby, nos2x, etc.)
// ABOUTME: Provides type-safe Dart interface to window.nostr object for web authentication

import 'package:flutter/foundation.dart';

// Extension type definitions for NIP-07 JavaScript interop

/// Check if NIP-07 extension is available
NostrExtension? get _nostr {
  if (kIsWeb) {
    return null; // Will be overridden by web-specific implementation
  }
  return null;
}

/// Public getter that safely checks for extension availability
NostrExtension? get nostr => kIsWeb ? _nostr : null;

/// Check if any NIP-07 extension is available
bool get isNip07Available => kIsWeb && _nostr != null;

/// The main NIP-07 interface that browser extensions implement
class NostrExtension {
  const NostrExtension();

  /// Get the user's public key (hex format)
  Future<String> getPublicKey() async {
    throw UnsupportedError('NIP-07 only available on web');
  }

  /// Sign a Nostr event
  Future<Map<String, dynamic>> signEvent(Map<String, dynamic> event) async {
    throw UnsupportedError('NIP-07 only available on web');
  }

  /// Get the user's relays (optional NIP-07 extension)
  Future<Map<String, dynamic>>? getRelays() {
    throw UnsupportedError('NIP-07 only available on web');
  }

  /// NIP-04 encryption (optional)
  NIP04? get nip04 => null;
}

/// NIP-04 encryption interface (optional extension feature)
class NIP04 {
  const NIP04();

  Future<String> encrypt(String pubkey, String plaintext) async {
    throw UnsupportedError('NIP-04 only available on web');
  }

  Future<String> decrypt(String pubkey, String ciphertext) async {
    throw UnsupportedError('NIP-04 only available on web');
  }
}

/// Nostr event structure for cross-platform use
class NostrEvent {
  NostrEvent({
    this.id,
    required this.pubkey,
    required this.created_at, // ignore: non_constant_identifier_names
    required this.kind,
    required this.tags,
    required this.content,
    this.sig,
  });

  /// Factory to create a new NostrEvent
  factory NostrEvent.create({
    String? id,
    required String pubkey, // ignore: non_constant_identifier_names
    required int created_at, // ignore: non_constant_identifier_names
    required int kind,
    required List<List<String>> tags,
    required String content,
    String? sig,
  }) {
    return NostrEvent(
      id: id,
      pubkey: pubkey,
      created_at: created_at,
      kind: kind,
      tags: tags,
      content: content,
      sig: sig,
    );
  }

  String? id;
  String pubkey;
  int created_at; // ignore: non_constant_identifier_names
  int kind;
  List<List<String>> tags;
  String content;
  String? sig;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'pubkey': pubkey,
      'created_at': created_at,
      'kind': kind,
      'tags': tags,
      'content': content,
      if (sig != null) 'sig': sig,
    };
  }
}

/// Convert Dart Map to NostrEvent
NostrEvent dartEventToJs(Map<String, dynamic> dartEvent) {
  final tags =
      (dartEvent['tags'] as List<dynamic>?)
          ?.map(
            (tag) =>
                (tag as List<dynamic>).map((item) => item.toString()).toList(),
          )
          .toList() ??
      <List<String>>[];

  return NostrEvent.create(
    id: dartEvent['id'] as String?,
    pubkey: (dartEvent['pubkey'] ?? '').toString(),
    created_at:
        dartEvent['created_at'] ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
    kind: dartEvent['kind'] ?? 1,
    tags: tags,
    content: (dartEvent['content'] ?? '').toString(),
    sig: dartEvent['sig'] as String?,
  );
}

/// Convert NostrEvent to Dart Map
Map<String, dynamic> jsEventToDart(NostrEvent event) {
  return {
    'id': event.id,
    'pubkey': event.pubkey,
    'created_at': event.created_at,
    'kind': event.kind,
    'tags': event.tags,
    'content': event.content,
    'sig': event.sig,
  };
}

/// Enhanced error handling for NIP-07 operations
class Nip07Exception implements Exception {
  const Nip07Exception(this.message, {this.code, this.originalError});
  final String message;
  final String? code;
  final dynamic originalError;

  @override
  String toString() =>
      'NIP-07 Error: $message${code != null ? ' ($code)' : ''}';
}

/// Helper function to safely call NIP-07 methods with error handling
Future<T> safeNip07Call<T>(
  Future<T> Function() operation,
  String operationName,
) async {
  try {
    return await operation();
  } catch (e) {
    // Handle common NIP-07 errors
    if (e.toString().contains('User rejected')) {
      throw Nip07Exception(
        'User rejected $operationName request',
        code: 'USER_REJECTED',
        originalError: e,
      );
    } else if (e.toString().contains('Not implemented')) {
      throw Nip07Exception(
        '$operationName not supported by this extension',
        code: 'NOT_IMPLEMENTED',
        originalError: e,
      );
    } else {
      throw Nip07Exception(
        'Failed to $operationName: $e',
        code: 'UNKNOWN_ERROR',
        originalError: e,
      );
    }
  }
}
