/// Helpers for extracting and rebuilding canonical Divine blob URLs.
library;

/// Returns the 64-character hex blob hash from a Divine media URL, or `null`
/// when [url] does not point to a Divine blob.
String? extractCanonicalDivineBlobHash(String url) {
  try {
    final uri = Uri.parse(url);
    if (!uri.host.toLowerCase().contains('divine.video')) return null;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;

    final hash = segments.first;
    final isHexHash =
        hash.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(hash);
    return isHexHash ? hash : null;
  } on FormatException {
    return null;
  }
}

/// Whether [url] points directly at a Divine blob rather than a derivative.
bool isDivineBlobRawUrl(String url) {
  if (extractCanonicalDivineBlobHash(url) == null) return false;

  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.pathSegments.where((segment) => segment.isNotEmpty).length == 1;
}

/// Builds the canonical HLS master URL for a Divine blob [hash].
String canonicalDivineBlobHlsUrl(String hash) =>
    'https://media.divine.video/$hash/hls/master.m3u8';

/// Builds the canonical raw blob URL for a Divine blob [hash].
String canonicalDivineBlobRawUrl(String hash) =>
    'https://media.divine.video/$hash';

/// Returns the input [sources] de-duplicated while preserving their order
/// and skipping null/empty entries.
List<String> orderedUniqueSources(Iterable<String?> sources) {
  final ordered = <String>[];
  final seen = <String>{};

  for (final source in sources) {
    if (source == null || source.isEmpty) continue;
    if (seen.add(source)) ordered.add(source);
  }

  return ordered;
}

/// The original-only canary accepts only known public Divine blob hosts.
/// Queries, user info, fragments, alternate ports and derivative paths are
/// excluded so a signed or authenticated URL cannot lose its access context.
String? b2OriginalPlaybackUrl(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      !const {
        'media.divine.video',
        'cdn.divine.video',
        'blossom.divine.video',
      }.contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port != 443 ||
      !RegExp(r'^/[a-fA-F0-9]{64}$').hasMatch(uri.path) ||
      url.contains('%')) {
    return null;
  }
  return 'https://media-b2.divine.video${uri.path.toLowerCase()}';
}

/// Whether this is an exact original URL on the dedicated canary host.
bool isB2OriginalPlaybackSource(String source) {
  final uri = Uri.tryParse(source);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'media-b2.divine.video' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      RegExp(r'^/[a-f0-9]{64}$').hasMatch(uri.path);
}
