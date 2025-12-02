// ABOUTME: Hash utility functions for cryptographic operations
// ABOUTME: Provides SHA-256 hashing for file verification and Blossom protocol

import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

class HashUtil {
  /// Calculate SHA-256 hash of bytes and return as hex string
  static String sha256Hash(List<int> bytes) {
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Calculate SHA-256 hash of string and return as hex string
  static String sha256String(String source) {
    final bytes = const Utf8Encoder().convert(source);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }
}
