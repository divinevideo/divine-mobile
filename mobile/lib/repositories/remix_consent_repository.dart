// ABOUTME: Answers whether a creator lets others remix their videos, read from
// ABOUTME: the account-wide block in their raw kind 0. Fails closed on doubt.

import 'dart:async';

import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// A creator's account-wide answer to "may others remix my videos?".
enum RemixConsent {
  /// The creator's kind 0 does not block remixing, or the creator has no
  /// kind 0.
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
/// rebuilds `rawData` from typed fields alone — so the check reads one
/// straight from the relays, except for an author already confirmed this
/// session to have no kind 0, and never trusts a cached projection, which
/// would silently answer "allowed" for a blocked account.
///
/// Only Divine writes the key, and a save that writes it must be accepted by
/// the app's default relay. So the check asks every connected relay and the
/// default relay at once, and settles on whichever answers first in full: one
/// silent third-party relay — the common case for classic Vine authors with
/// no kind 0 — does not hold up the answer until it times out. Only a read
/// that asked the default relay may settle on "allowed": other relays can
/// hold an older kind 0 that predates the block.
class RemixConsentRepository {
  /// Creates a repository that reads kind 0 through [profileRepository],
  /// trusting [defaultRelayUrl]'s full answer on its own.
  ///
  /// [connectedRelayUrls] names the relays the viewer is connected to when a
  /// check starts; the read of every connected relay only counts as asking
  /// the default relay when it is among them.
  ///
  /// Only signer-free reads are made, so a [ProfileReader] is enough.
  RemixConsentRepository({
    required ProfileReader profileRepository,
    required String defaultRelayUrl,
    required Iterable<String> Function() connectedRelayUrls,
  }) : _profileRepository = profileRepository,
       _defaultRelayUrl = defaultRelayUrl,
       _connectedRelayUrls = connectedRelayUrls;

  final ProfileReader _profileRepository;
  final String _defaultRelayUrl;
  final Iterable<String> Function() _connectedRelayUrls;

  /// Lowercase pubkeys of authors confirmed to have no kind 0 this session,
  /// so asking again for the same author makes no relay request.
  final Set<String> _confirmedWithoutKind0 = {};

  /// Whether the author of [authorPubkey] allows others to remix their videos.
  ///
  /// Asks every connected relay and the default relay together and answers
  /// as soon as either read settles it:
  ///
  /// * a kind 0 of the author holding `false` blocks at once, even from a
  ///   read that did not finish or did not ask the default relay;
  /// * a finished read that asked the default relay and found no kind 0, or
  ///   one that does not block, allows. An author who never published a
  ///   kind 0 cannot have blocked anything; a miss that settles the answer is
  ///   remembered for the session, and forgotten again if a `false` from the
  ///   author turns up.
  ///
  /// Returns [RemixConsent.unknown] when both reads end without settling it:
  /// they timed out, refused, threw an [Exception], returned another
  /// account's profile, or only relays other than the default one answered.
  ///
  /// Throws whatever [Error] a read throws first while the answer is still
  /// open — a programming fault, such as a kind 0 that does not parse, which
  /// the caller reports rather than mistakes for a relay failure. An [Error]
  /// after the answer is settled is logged.
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

    void consider(
      FreshProfileRead? read, {
      required bool askedDefaultRelay,
    }) {
      unsettledReads--;
      final profile = read?.profile;
      final isAuthors =
          profile != null && pubkeysEqual(profile.pubkey, authorPubkey);
      final settlesAllow = askedDefaultRelay && read != null && read.conclusive;
      if (isAuthors && !profile.allowsVideoReuse) {
        _confirmedWithoutKind0.remove(key);
        settle(RemixConsent.blocked);
      } else if (settlesAllow && profile == null) {
        // Only a miss that settles the answer is remembered: one arriving
        // after a `false` must not turn later checks into an allow.
        if (!decision.isCompleted) _confirmedWithoutKind0.add(key);
        settle(RemixConsent.allowed);
      } else if (settlesAllow && isAuthors) {
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

    void fail(Object error, StackTrace stackTrace) {
      unsettledReads--;
      if (!decision.isCompleted) {
        decision.completeError(error, stackTrace);
        return;
      }
      Log.error(
        'Remix consent read for ${pubkeyForLogs(authorPubkey)} failed after '
        'the answer was settled: $error',
        name: 'RemixConsentRepository',
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final connectedToDefaultRelay = _connectedRelayUrls().any(
      (url) => relayUrlsEquivalent(url, _defaultRelayUrl),
    );
    unawaited(
      _read(
        authorPubkey,
        () => _profileRepository.readRawProfileFromRelays(pubkey: authorPubkey),
      ).then(
        (read) => consider(read, askedDefaultRelay: connectedToDefaultRelay),
        onError: fail,
      ),
    );
    unawaited(
      _read(
        authorPubkey,
        () => _profileRepository.readRawProfileFromRelays(
          pubkey: authorPubkey,
          onlyRelayUrl: _defaultRelayUrl,
        ),
      ).then(
        (read) => consider(read, askedDefaultRelay: true),
        onError: fail,
      ),
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
