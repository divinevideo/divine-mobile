// ABOUTME: Recognizes only canonical public short-link hosts and complete alias paths.
import 'package:openvine/utils/nostr_key_utils.dart';

final _shortLinkIdentifier = RegExp(r'^[A-Za-z0-9._~-]{1,1024}$');

String? shortLinkCodeFor(Uri uri) {
  if (uri.scheme != 'https' ||
      !{'divine.video', 'www.divine.video'}.contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  return RegExp(r'^/l/([A-Za-z0-9]{8})$').firstMatch(uri.path)?.group(1);
}

/// The one query a short-link destination may carry: the author of a video
/// link, so a shortened share keeps naming the account it came from (#10929).
///
/// The short-link gateway must accept exactly this shape; until it does, a
/// share carrying it falls back to the full link.
final _videoAuthorQuery = RegExp(r'\?author=[0-9a-f]{64}$');

bool isShortLinkDestination(String raw) {
  if (raw.length > 2048) return false;
  final authorQuery = _videoAuthorQuery.firstMatch(raw);
  final base = authorQuery == null ? raw : raw.substring(0, authorQuery.start);
  if (!base.startsWith('https://divine.video/') ||
      RegExp(r'[\\%?#\s\x00-\x1f\x7f]').hasMatch(base)) {
    return false;
  }
  final uri = Uri.tryParse(base);
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.toString() != base ||
      uri.pathSegments.length != 2) {
    return false;
  }
  final kind = uri.pathSegments[0];
  final id = uri.pathSegments[1];
  if (!_shortLinkIdentifier.hasMatch(id) || id == '.' || id == '..') {
    return false;
  }
  if (kind == 'video') return true;
  if (kind != 'profile' || authorQuery != null) return false;
  if (RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(id)) return true;
  return id.toLowerCase().startsWith('npub1') &&
      NostrKeyUtils.isValidKey(NostrKeyUtils.decode(id));
}
