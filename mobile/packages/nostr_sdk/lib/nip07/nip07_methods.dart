// ABOUTME: Defines NIP-07 method name constants for web browser extension signing.
// ABOUTME: Used for communication with window.nostr browser extension API.

class NIP07Methods {
  static const String getPublicKey = "getPublicKey";

  static const String signEvent = "signEvent";

  static const String getRelays = "getRelays";

  static const String nip04Encrypt = "nip04.encrypt";

  static const String nip04Decrypt = "nip04.decrypt";

  static const String lightning = "lightning";
}
