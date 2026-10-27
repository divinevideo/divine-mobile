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

bool isShortLinkDestination(String raw) {
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
  if (!_shortLinkIdentifier.hasMatch(id) || id == '.' || id == '..') {
    return false;
  }
  if (kind == 'video') return true;
  if (kind != 'profile') return false;
  if (RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(id)) return true;
  return id.toLowerCase().startsWith('npub1') &&
      NostrKeyUtils.isValidKey(NostrKeyUtils.decode(id));
}
