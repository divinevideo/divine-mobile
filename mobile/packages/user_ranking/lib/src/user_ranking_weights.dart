/// Product weights for local closeness scoring.
abstract final class UserRankingWeights {
  /// Maximum contribution from a fresh interaction.
  static const interactionMax = 100.0;

  /// Time for the interaction contribution to halve.
  static const interactionHalfLife = Duration(days: 14);

  /// Relationship contribution when both accounts follow each other.
  static const mutual = 40.0;

  /// Relationship contribution when only the viewer follows the account.
  static const youFollow = 20.0;

  /// Relationship contribution when only the account follows the viewer.
  static const followsYou = 10.0;

  /// Maximum contribution from a freshly posted video.
  static const postingMax = 10.0;

  /// Time for the posting contribution to halve.
  static const postingHalfLife = Duration(days: 7);

  /// Maximum contribution from the logarithmic video-count curve.
  static const videoCountMax = 5.0;

  /// Contribution from a verified NIP-05 identity.
  static const verifiedNip05 = 3.0;
}
