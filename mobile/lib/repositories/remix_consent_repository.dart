// ABOUTME: Answers whether a creator lets others remix their videos, read from
// ABOUTME: the account-wide block in their fresh kind 0. Fails closed on doubt.

import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// A creator's account-wide answer to "may others remix my videos?".
enum RemixConsent {
  /// The creator's kind 0 does not block remixing.
  allowed,

  /// The creator set [divineAllowVideoReuseKey] to `false`.
  blocked,

  /// The creator's kind 0 could not be read, so nobody knows. Callers must
  /// refuse the remix and offer a retry.
  unknown,
}

/// Reads a creator's account-wide remix block.
///
/// The block lives under [divineAllowVideoReuseKey] in the creator's kind 0.
/// Only a relay-fetched raw kind 0 carries custom keys — a REST-built profile
/// rebuilds `rawData` from typed fields alone — so the check always reads one
/// fresh and never trusts a cached projection, which would silently answer
/// "allowed" for a blocked account.
class RemixConsentRepository {
  /// Creates a repository that reads kind 0 through [profileRepository].
  ///
  /// Only signer-free reads are made, so a [ProfileReader] is enough.
  RemixConsentRepository({required ProfileReader profileRepository})
    : _profileRepository = profileRepository;

  final ProfileReader _profileRepository;

  /// Whether the author of [authorPubkey] allows others to remix their videos.
  ///
  /// Returns [RemixConsent.unknown] when the fresh kind 0 read throws, finds
  /// no raw kind 0, or returns another account's profile.
  Future<RemixConsent> consentFor(String authorPubkey) async {
    final UserProfile? profile;
    try {
      profile = await _profileRepository.fetchFreshProfile(
        pubkey: authorPubkey,
        requireRawKind0: true,
      );
    } on Exception catch (e) {
      Log.warning(
        'Remix consent read failed for ${pubkeyForLogs(authorPubkey)}: $e',
        name: 'RemixConsentRepository',
        category: LogCategory.relay,
      );
      return RemixConsent.unknown;
    }

    if (profile == null || profile.pubkey != authorPubkey) {
      Log.info(
        'No raw kind 0 for ${pubkeyForLogs(authorPubkey)}; '
        'remix consent unknown',
        name: 'RemixConsentRepository',
        category: LogCategory.relay,
      );
      return RemixConsent.unknown;
    }
    return profile.allowsVideoReuse
        ? RemixConsent.allowed
        : RemixConsent.blocked;
  }
}
