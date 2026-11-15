// ABOUTME: Answers whether a creator lets others remix their videos, read from
// ABOUTME: the account-wide block in their raw kind 0. Fails closed on doubt.

import 'dart:async';

import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
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
/// straight from the relays and never trusts a cached projection, which would
/// silently answer "allowed" for a blocked account.
///
/// Only Divine writes the key, and it publishes every kind 0 to the app's
/// default relay. So the check asks every connected relay and the default
/// relay at once, and settles on whichever answers first in full: one silent
/// third-party relay — the common case for classic Vine authors with no
/// kind 0 — no longer holds up the answer until it times out.
class RemixConsentRepository {
  /// Creates a repository that reads kind 0 through [profileRepository],
  /// trusting [defaultRelayUrl]'s full answer on its own.
  ///
  /// Only signer-free reads are made, so a [ProfileReader] is enough.
  RemixConsentRepository({
    required ProfileReader profileRepository,
    required String defaultRelayUrl,
  }) : _profileRepository = profileRepository,
       _defaultRelayUrl = defaultRelayUrl;

  final ProfileReader _profileRepository;
  final String _defaultRelayUrl;

  /// Lowercase pubkeys of authors confirmed to have no kind 0 this session,
  /// so asking again for the same author makes no relay request.
  final Set<String> _confirmedWithoutKind0 = {};

  /// Whether the author of [authorPubkey] allows others to remix their videos.
  ///
  /// Asks every connected relay and the default relay together and answers
  /// as soon as either read settles it:
  ///
  /// * a kind 0 of the author holding `false` blocks at once, even from a
  ///   read that did not finish;
  /// * a finished read finding no kind 0, or one that does not block, allows.
  ///   An author who never published a kind 0 cannot have blocked anything;
  ///   that miss is remembered for the session.
  ///
  /// Returns [RemixConsent.unknown] when both reads end without settling it:
  /// they timed out, refused, threw, or returned another account's profile.
  Future<RemixConsent> consentFor(String authorPubkey) {
    final key = authorPubkey.toLowerCase();
    if (_confirmedWithoutKind0.contains(key)) {
      return Future.value(RemixConsent.allowed);
    }

    final decision = Completer<RemixConsent>();
    var unsettledReads = 2;

    void settle(RemixConsent consent) {
      if (!decision.isCompleted) decision.complete(consent);
    }

    void consider(FreshProfileRead? read) {
      unsettledReads--;
      final profile = read?.profile;
      final isAuthors =
          profile != null && pubkeysEqual(profile.pubkey, authorPubkey);
      if (isAuthors && !profile.allowsVideoReuse) {
        settle(RemixConsent.blocked);
      } else if (read != null && read.conclusive && profile == null) {
        _confirmedWithoutKind0.add(key);
        settle(RemixConsent.allowed);
      } else if (read != null && read.conclusive && isAuthors) {
        settle(RemixConsent.allowed);
      }
      if (unsettledReads == 0 && !decision.isCompleted) {
        Log.info(
          'No conclusive raw kind 0 for ${pubkeyForLogs(authorPubkey)}; '
          'remix consent unknown',
          name: 'RemixConsentRepository',
          category: LogCategory.relay,
        );
        settle(RemixConsent.unknown);
      }
    }

    unawaited(
      _read(
        authorPubkey,
        () => _profileRepository.readRawProfileFromRelays(pubkey: authorPubkey),
      ).then(consider),
    );
    unawaited(
      _read(
        authorPubkey,
        () => _profileRepository.readRawProfileFromRelays(
          pubkey: authorPubkey,
          onlyRelayUrl: _defaultRelayUrl,
        ),
      ).then(consider),
    );
    return decision.future;
  }

  /// Runs [read], answering `null` when it throws.
  Future<FreshProfileRead?> _read(
    String authorPubkey,
    Future<FreshProfileRead> Function() read,
  ) async {
    try {
      return await read();
    } on Exception catch (e) {
      Log.warning(
        'Remix consent read failed for ${pubkeyForLogs(authorPubkey)}: $e',
        name: 'RemixConsentRepository',
        category: LogCategory.relay,
      );
      return null;
    }
  }
}
