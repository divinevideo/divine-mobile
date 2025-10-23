// ABOUTME: Stub for dart:html types on native platforms
// ABOUTME: Provides no-op implementations when compiling for iOS/Android

/// Stub class for html.Blob on native platforms
class Blob {
  Blob(List<dynamic> parts, String type);
}

/// Stub class for html.Url on native platforms
class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

/// Stub class for html.AnchorElement on native platforms
class AnchorElement {
  AnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
}
