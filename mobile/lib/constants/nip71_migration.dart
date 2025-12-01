// ABOUTME: Constants for NIP-71 compliant video kinds - OpenVine uses kind 34236 (addressable short videos)
// ABOUTME: Defines supported video event kinds per NIP-71 standard for short-form video content

/// NIP-71 compliant video event kinds
class NIP71VideoKinds {
  // NIP-71 Standard kinds for video events
  static const int shortVideo = 22; // Short videos (Vine-like content)
  static const int normalVideo = 21; // Normal videos (longer content)
  static const int addressableShortVideo = 34236; // Addressable short videos
  static const int addressableNormalVideo = 34235; // Addressable normal videos

  // Repost kinds
  static const int repost = 16; // NIP-18 generic reposts

  /// Get all NIP-71 video kinds that OpenVine subscribes to
  /// OpenVine only uses kind 34236 (addressable short videos)
  static List<int> getAllVideoKinds() {
    return [addressableShortVideo]; // Only kind 34236
  }

  /// Get primary kinds for new video events
  static List<int> getPrimaryVideoKinds() {
    return [addressableShortVideo]; // Only kind 34236
  }

  /// Check if a kind is a video event
  static bool isVideoKind(int kind) {
    return getAllVideoKinds().contains(kind);
  }

  /// Get the preferred addressable kind for new events
  static int getPreferredAddressableKind() {
    return addressableShortVideo; // Kind 34236 for addressable short videos
  }

  /// Get the preferred kind for new events (same as addressable)
  static int getPreferredKind() {
    return addressableShortVideo; // Kind 34236 - OpenVine only uses addressable
  }
}

/// NIP-71 video event configuration
class VideoEventConfig {
  /// Application uses NIP-71 kinds exclusively
  static const bool useNIP71Only = true;

  /// Implementation phase indicator
  static const String implementationPhase = "nip71_compliant";
}
