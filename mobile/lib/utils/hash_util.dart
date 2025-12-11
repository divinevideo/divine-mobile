// ABOUTME: Hash utility functions for cryptographic operations
// ABOUTME: Provides SHA-256 hashing for file verification and Blossom protocol

import 'dart:convert';
import 'dart:io';
import 'package:convert/convert.dart';
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

  /// Calculate SHA-256 hash of a file using streaming to avoid memory issues
  /// Returns both the hash and file size without loading entire file into memory
  static Future<({String hash, int size})> sha256File(File file) async {
    final output = AccumulatorSink<crypto.Digest>();
    final input = crypto.sha256.startChunkedConversion(output);
    int totalBytes = 0;

    await for (final chunk in file.openRead()) {
      input.add(chunk);
      totalBytes += chunk.length;
    }

    input.close();
    final hash = output.events.single.toString();
    return (hash: hash, size: totalBytes);
  }
}
