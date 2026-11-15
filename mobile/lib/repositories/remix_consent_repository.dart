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
///
/// Only Divine writes the key, and it publishes every kind 0 to the app's
/// default relay. So when one silent third-party relay leaves the wider read
/// inconclusive — the common case for classic Vine authors with no kind 0 —
/// a full answer from the default relay alone settles it.
class RemixConsentRepository {
  /// Creates a repository that reads kind 0 through [profileRepository], and
  /// falls back to [defaultRelayUrl] alone when the wider read is
  /// inconclusive.
  ///
  /// Only signer-free reads are made, so a [ProfileReader] is enough.
  RemixConsentRepository({
    required ProfileReader profileRepository,
    required String defaultRelayUrl,
  }) : _profileRepository = profileRepository,
       _defaultRelayUrl = defaultRelayUrl;

  final ProfileReader _profileRepository;
  final String _defaultRelayUrl;

  /// Whether the author of [authorPubkey] allows others to remix their videos.
  ///
  /// An author who confirmably never published a kind 0 cannot have blocked
  /// anything, so that is [RemixConsent.allowed]. A miss is confirmed by a
  /// read every relay answered, or failing that by the default relay alone.
  /// Returns [RemixConsent.unknown] when the reads throw, neither is
  /// conclusive, or they return another account's profile.
  Future<RemixConsent> consentFor(String authorPubkey) async {
    final FreshProfileRead read;
    try {
      read = await _profileRepository.readFreshProfile(
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

    if (read.conclusive || read.profile != null) {
      return _consentFrom(read, authorPubkey);
    }

    final FreshProfileRead defaultRelayRead;
    try {
      defaultRelayRead = await _profileRepository.readRawProfileFromRelay(
        pubkey: authorPubkey,
        relayUrl: _defaultRelayUrl,
      );
    } on Exception catch (e) {
      Log.warning(
        'Remix consent read from $_defaultRelayUrl failed for '
        '${pubkeyForLogs(authorPubkey)}: $e',
        name: 'RemixConsentRepository',
        category: LogCategory.relay,
      );
      return RemixConsent.unknown;
    }
    return _consentFrom(defaultRelayRead, authorPubkey);
  }

  RemixConsent _consentFrom(FreshProfileRead read, String authorPubkey) {
    final profile = read.profile;
    if (profile == null && read.conclusive) return RemixConsent.allowed;
    if (profile == null || profile.pubkey != authorPubkey) {
      Log.info(
        'No conclusive raw kind 0 for ${pubkeyForLogs(authorPubkey)}; '
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
