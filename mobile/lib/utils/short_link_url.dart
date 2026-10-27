// ABOUTME: Recognizes only canonical public short-link hosts and complete alias paths.
String? shortLinkCodeFor(Uri uri) {
  if (uri.scheme != 'https' ||
      !{'divine.video', 'www.divine.video'}.contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  return RegExp(r'^/l/([A-Za-z0-9]{8})$').firstMatch(uri.path)?.group(1);
}
