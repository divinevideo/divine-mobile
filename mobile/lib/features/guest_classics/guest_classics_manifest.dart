// ABOUTME: Reads short-lived, public guest Classics manifests in preference order.
// ABOUTME: Only the manifest service selects the clips eligible to play.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

typedef GuestClassic = ({String id, Uri url, String attribution});

class GuestClassicsManifest {
  const GuestClassicsManifest._(this.expiresAt, this.clips);

  final DateTime expiresAt;
  final List<GuestClassic> clips;

  static final _hexId = RegExp(r'^[a-f0-9]{64}$');

  static GuestClassicsManifest? parse(Object? data, {required DateTime now}) {
    if (data
        case {
          'schema_version': 1,
          'revision': final String revision,
          'expires_at': final String expiry,
          'items': final List<Object?> items,
        }
        when revision.isNotEmpty && items.length <= 10) {
      final expiresAt = DateTime.tryParse(expiry);
      if (expiresAt == null ||
          !expiresAt.isUtc ||
          !expiresAt.isAfter(now) ||
          expiresAt.difference(now) > const Duration(hours: 1)) {
        return null;
      }
      final clips = <GuestClassic>[];
      final seenHashes = <String>{};
      final seenIds = <String>{};
      for (final item in items) {
        if (item
            case {
              'event_id': final String id,
              'sha256': final String hash,
              'video_url': final String url,
              'attribution': final String attribution,
              'original_loops': final int loops,
            }
            when _hexId.hasMatch(id) &&
                _hexId.hasMatch(hash) &&
                loops > 0 &&
                attribution.trim().isNotEmpty) {
          final uri = Uri.tryParse(url);
          if (uri != null &&
              uri.isScheme('https') &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty &&
              seenHashes.add(hash) &&
              seenIds.add(id)) {
            clips.add((id: id, url: uri, attribution: attribution));
            continue;
          }
        }
        return null;
      }
      return GuestClassicsManifest._(expiresAt, clips);
    }
    return null;
  }
}

/// A missing locale may fall back. An invalid/withdrawn manifest or service
/// error returns the viewer to the regular welcome experience.
Future<GuestClassicsManifest?> fetchGuestClassics({
  required Uri base,
  required http.Client client,
  required Iterable<String> languages,
  required DateTime Function() now,
  bool muted = true,
}) async {
  final safeLanguage = RegExp(r'^[a-z]{2,3}$');
  final locales = languages
      .where(safeLanguage.hasMatch)
      .where((l) => l != 'und')
      .toSet();
  for (final locale in [...locales, 'und']) {
    final path = 'v1/$locale/${muted ? 'muted' : 'audible'}.json';
    final request = http.Request('GET', base.resolve(path))
      ..headers['Cache-Control'] = 'no-cache';
    final response = await client.send(request);
    if (response.statusCode != 200) {
      await response.stream.listen((_) {}).cancel();
      if (response.statusCode == 404) continue;
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 65536) return null;
      bytes.add(chunk);
    }
    GuestClassicsManifest? manifest;
    try {
      manifest = GuestClassicsManifest.parse(
        jsonDecode(utf8.decode(bytes.takeBytes())),
        now: now(),
      );
    } on FormatException {
      return null;
    }
    if (manifest == null || manifest.clips.isNotEmpty) return manifest;
  }
  return null;
}
