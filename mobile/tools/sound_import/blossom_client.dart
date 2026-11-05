// ABOUTME: The two Blossom calls the importer needs: whether a server already
// ABOUTME: holds a blob, and uploading one with a BUD-02 authorization.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';

/// Thrown when a Blossom server answers something the importer cannot use.
class BlossomException implements Exception {
  const BlossomException(this.message);

  final String message;

  @override
  String toString() => 'BlossomException: $message';
}

/// Divine's own media hosts. Uploading to one of them needs the maintainer's
/// explicit go, which the command line asks for separately.
const productionBlossomHosts = {
  'media.divine.video',
  'blossom.divine.video',
  'cdn.divine.video',
};

/// A Blossom server at [server], such as `https://media.divine.video`.
class BlossomClient {
  BlossomClient({required String server, http.Client? client})
    : server = server.endsWith('/')
          ? server.substring(0, server.length - 1)
          : server,
      _client = client ?? http.Client();

  final String server;
  final http.Client _client;

  /// Whether the server holds the blob with [sha256].
  ///
  /// Throws a [BlossomException] for an answer other than found or not
  /// found.
  Future<bool> has(String sha256) async {
    final response = await _client.head(Uri.parse('$server/$sha256'));
    return switch (response.statusCode) {
      200 => true,
      404 => false,
      final status => throw BlossomException('HEAD $sha256 answered $status'),
    };
  }

  /// Uploads [file], whose hash is [sha256], authorized by the key
  /// [privateKeyHex] (BUD-02, kind 24242).
  ///
  /// Throws a [BlossomException] when the server refuses the upload or
  /// stores it under another hash.
  Future<void> upload(
    File file, {
    required String sha256,
    required String mimeType,
    required String privateKeyHex,
  }) async {
    final expiration =
        DateTime.now()
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch ~/
        1000;
    final authorization = Event(getPublicKey(privateKeyHex), 24242, [
      ['t', 'upload'],
      ['x', sha256],
      ['expiration', '$expiration'],
    ], 'Upload $sha256')..sign(privateKeyHex);

    final response = await _client.put(
      Uri.parse('$server/upload'),
      headers: {
        'Authorization':
            'Nostr ${base64Encode(utf8.encode(jsonEncode(authorization.toJson())))}',
        'Content-Type': mimeType,
        'X-SHA-256': sha256,
      },
      body: await file.readAsBytes(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BlossomException(
        'upload of $sha256 answered ${response.statusCode}: ${response.body}',
      );
    }
    final descriptor = jsonDecode(response.body);
    final stored = descriptor is Map<String, dynamic>
        ? descriptor['sha256']
        : null;
    if (stored != sha256) {
      throw BlossomException('server stored $sha256 as $stored');
    }
  }

  void close() => _client.close();
}
