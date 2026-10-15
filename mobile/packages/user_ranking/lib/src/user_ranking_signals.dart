import 'package:meta/meta.dart';

/// Locally available relationship and activity signals for one account.
@immutable
final class UserRankingSignals {
  /// Creates a signal snapshot; omitted signals make no score contribution.
  const UserRankingSignals({
    required this.pubkey,
    this.lastInteractionAt,
    this.youFollow = false,
    this.followsYou,
    this.hasVerifiedNip05 = false,
    this.videoCount,
    this.lastPostedAt,
  });

  /// The account's full public key.
  final String pubkey;

  /// The newest accepted one-to-one message involving this account.
  final DateTime? lastInteractionAt;

  /// Whether the viewer follows this account.
  final bool youFollow;

  /// Whether this account follows the viewer, or null before this is known.
  final bool? followsYou;

  /// Whether the cached NIP-05 identity has been verified.
  final bool hasVerifiedNip05;

  /// The cached video count, or null when unavailable.
  final int? videoCount;

  /// The newest cached video timestamp, or null when unavailable.
  final DateTime? lastPostedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRankingSignals &&
          pubkey == other.pubkey &&
          lastInteractionAt == other.lastInteractionAt &&
          youFollow == other.youFollow &&
          followsYou == other.followsYou &&
          hasVerifiedNip05 == other.hasVerifiedNip05 &&
          videoCount == other.videoCount &&
          lastPostedAt == other.lastPostedAt;

  @override
  int get hashCode => Object.hash(
    pubkey,
    lastInteractionAt,
    youFollow,
    followsYou,
    hasVerifiedNip05,
    videoCount,
    lastPostedAt,
  );
}
