// ABOUTME: Who may answer an Add yours or replies sticker its owner restricted:
// ABOUTME: the owner, and for friends the people the owner follows.

import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart' show VideoStickerAudience;

/// Who may answer a sticker with [audience] that [owner] owns: the creator of
/// a replies sticker's video, or of the first video of an Add yours's chain.
class StickerAnswerers {
  const StickerAnswerers._(this.audience, this.owner, this._ownerFollows);

  /// Reads who [owner] follows when [audience] lets them answer, from the
  /// signed-in account's own list when [owner] is [viewer] and otherwise from
  /// their contact list on the relays.
  ///
  /// Throws what [FollowRepository.getOthersFollowing] throws when that list
  /// cannot be read.
  static Future<StickerAnswerers> read(
    FollowRepository followRepository, {
    required VideoStickerAudience audience,
    required String owner,
    String? viewer,
  }) async {
    final ownerHex = owner.toLowerCase();
    if (audience != VideoStickerAudience.following) {
      return StickerAnswerers._(audience, ownerHex, const {});
    }
    final follows = ownerHex == viewer?.toLowerCase()
        ? followRepository.followingPubkeys
        : (await followRepository.getOthersFollowing(ownerHex)).pubkeys;
    return StickerAnswerers._(audience, ownerHex, {
      for (final pubkey in follows) pubkey.toLowerCase(),
    });
  }

  /// Who may answer.
  final VideoStickerAudience audience;

  /// The hex public key of the sticker's owner.
  final String owner;

  final Set<String> _ownerFollows;

  /// Whether the account [pubkey] names may answer; nobody signed out may
  /// answer a restricted sticker.
  bool admits(String? pubkey) {
    if (!audience.isRestricted) return true;
    if (pubkey == null) return false;
    return audience.admits(
      pubkey.toLowerCase(),
      owner: owner,
      ownerFollows: _ownerFollows,
    );
  }
}
