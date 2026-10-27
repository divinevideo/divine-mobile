// ABOUTME: Resolves public Divine short links through a bounded first-party lookup.
// ABOUTME: Validates the complete mapping before passing its destination to deep-link parsing.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/short_link_url.dart';

class ShortLinkResolutionException implements Exception {
  const ShortLinkResolutionException();
}

class ShortLinkResolver {
  ShortLinkResolver({
    required http.Client client,
    this.timeout = const Duration(seconds: 2),
  }) : _client = client;

  final http.Client _client;
  final Duration timeout;
  static final _identifier = RegExp(r'^[A-Za-z0-9._~-]{1,1024}$');

  Future<DeepLink> resolve(Uri shortUrl) async {
    final code = shortLinkCodeFor(shortUrl);
    if (code == null) throw const ShortLinkResolutionException();
    try {
      return await _lookup(code).timeout(timeout);
    } on ShortLinkResolutionException {
      rethrow;
    } on Exception {
      throw const ShortLinkResolutionException();
    }
  }

  Future<DeepLink> _lookup(String code) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final request = http.Request(
        'GET',
        Uri.https('divine.video', '/api/links/$code'),
      )..followRedirects = false;
      final response = await _client.send(request);
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 4096) {
          throw const ShortLinkResolutionException();
        }
        bytes.addAll(chunk);
      }
      if (attempt == 0 &&
          (response.statusCode == 404 || response.statusCode >= 500)) {
        continue;
      }
      if (response.statusCode != 200) {
        throw const ShortLinkResolutionException();
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['code'] != code ||
          decoded['short_url'] != 'https://divine.video/l/$code' ||
          decoded['url'] is! String ||
          !_validDestination(decoded['url'] as String)) {
        throw const ShortLinkResolutionException();
      }
      return DeepLinkService.parseDeepLink(decoded['url'] as String);
    }
    throw const ShortLinkResolutionException();
  }

  static bool _validDestination(String raw) {
    if (raw.length > 2048 ||
        !raw.startsWith('https://divine.video/') ||
        RegExp(r'[\\%?#\s\x00-\x1f\x7f]').hasMatch(raw)) {
      return false;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.toString() != raw ||
        uri.pathSegments.length != 2) {
      return false;
    }
    final kind = uri.pathSegments[0];
    final id = uri.pathSegments[1];
    if (!_identifier.hasMatch(id) || id == '.' || id == '..') return false;
    if (kind == 'video') return true;
    if (kind != 'profile') return false;
    if (RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(id)) return true;
    return id.toLowerCase().startsWith('npub1') &&
        NostrKeyUtils.isValidKey(NostrKeyUtils.decode(id));
  }
}
