// ABOUTME: IdentityClaimsRepository — composes VerifierClient with NIP-39
// ABOUTME: i tag parsing, a verified-claims cache (#3936) and the kind-10011
// ABOUTME: write path that links and unlinks accounts.

import 'dart:convert';
import 'dart:math';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Filter;
import 'package:profile_repository/src/identity_event_selection.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:verifier_client/verifier_client.dart';

/// Signs an event on behalf of the current user.
///
/// Returns null when the signer refuses or is unavailable. Mirrors the
/// `AuthService.createAndSignEvent` shape the app wires in.
///
/// [createdAt] overrides the signer's own clock. Replaceable kinds need it:
/// the event has to supersede the one it replaces, and a device that
/// publishes twice inside the same second would otherwise sign a tie that
/// NIP-01 can resolve against it.
typedef IdentityEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
      int? createdAt,
    });

/// The claims already on the identity event could not be read, so a write
/// would have replaced them with an incomplete set.
///
/// Recoverable and worth retrying: it means the relays did not answer, not
/// that anything is wrong with the claim being written.
class IdentityClaimReadException implements Exception {
  /// Creates an [IdentityClaimReadException].
  const IdentityClaimReadException(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'IdentityClaimReadException: $message';
}

/// The identity event could not be published to any relay.
class IdentityClaimPublishException implements Exception {
  /// Creates an [IdentityClaimPublishException].
  const IdentityClaimPublishException(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'IdentityClaimPublishException: $message';
}

/// Every claim on a profile's identity event, with the verifier's verdict.
///
/// Unlike the rendering paths, this keeps unverified claims: the surface that
/// manages links has to show the one that stopped verifying.
class IdentityClaimStatus {
  /// Creates an [IdentityClaimStatus].
  const IdentityClaimStatus({
    required this.claims,
    required this.verifiedKeys,
    required this.verifierReachable,
  });

  /// Every claim on the identity event, in tag order.
  final List<IdentityClaim> claims;

  /// Lowercased `platform:identity` keys the verifier confirmed.
  final Set<String> verifiedKeys;

  /// False when the verifier could not be reached, so [verifiedKeys] is empty
  /// for lack of an answer rather than for lack of verified claims. UI should
  /// say "could not check" rather than "not verified".
  final bool verifierReachable;

  /// Whether [claim] carries a positive verdict.
  bool isVerified(IdentityClaim claim) => verifiedKeys.contains(
    '${claim.platform.toLowerCase()}:${claim.identity.toLowerCase()}',
  );
}

/// Verified claims read from the persistent snapshot cache.
class CachedVerifiedClaims {
  /// Creates a [CachedVerifiedClaims].
  const CachedVerifiedClaims({required this.claims, required this.isFresh});

  /// The subset of the profile's current claims that the snapshot has a
  /// positive verdict for (full-tuple match including proof).
  final List<IdentityClaim> claims;

  /// Whether the snapshot is within the verifier's 24h verified TTL
  /// (anchored on the verifier's own `checked_at`).
  final bool isFresh;
}

class _VerificationOutcome {
  const _VerificationOutcome({
    required this.verified,
    required this.rateLimited,
    this.confirmedNegativeKeys = const {},
  });

  final List<IdentityClaim> verified;
  final bool rateLimited;

  /// Lowercased `platform:identity` keys the verifier explicitly judged
  /// negative with a non-rate-limited result. Honored even inside a
  /// rate-limited batch, where they must still drop their claim.
  final Set<String> confirmedNegativeKeys;
}

class _PublishedIdentityTags {
  const _PublishedIdentityTags({
    required this.tags,
    required this.createdAt,
    required this.id,
  });

  final List<List<String>> tags;
  final int createdAt;
  final String id;
}

class _IdentityEventBase {
  const _IdentityEventBase({
    required this.tags,
    required this.content,
    this.source,
  });

  final List<List<String>> tags;
  final String content;

  /// Coordinates of the kind-10011 event these tags were read off.
  ///
  /// Null on every other branch — the kind-0 fallback, the snapshot, and the
  /// empty base — where no identity event came back to supersede.
  final _IdentitySource? source;
}

/// Coordinates of the identity event a set of tags came from, ordered by
/// [compareIdentityEvents].
typedef _IdentitySource = ({int createdAt, String id});

/// Wall-clock seconds, the unit Nostr `created_at` is expressed in.
int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// Composes [VerifierClient] with NIP-39 `i` tag parsing off identity
/// events (kind 10011, with kind-0 tags as the legacy fallback) and a
/// persistent verified-claims cache.
class IdentityClaimsRepository {
  /// Creates an [IdentityClaimsRepository] backed by [verifierClient].
  ///
  /// [identityVerificationsDao] enables the persistent verdict cache;
  /// when null, [cachedVerifiedClaims] returns null and [resolveClaims]
  /// skips persistence on its verify path.
  ///
  /// [nostrClient] and [signEvent] enable the write path ([publishClaim] /
  /// [removeClaim]); without both, those methods throw [StateError]. Read-only
  /// consumers — every profile that only renders someone else's chips — keep
  /// constructing this without them. [identityEventsDao] lets a completed
  /// write refresh the local `i` tag cache so the new link renders without
  /// waiting on a relay reread.
  IdentityClaimsRepository({
    required VerifierClient verifierClient,
    IdentityVerificationsDao? identityVerificationsDao,
    NostrClient? nostrClient,
    IdentityEventSigner? signEvent,
    IdentityEventsDao? identityEventsDao,
  }) : _verifierClient = verifierClient,
       _verificationsDao = identityVerificationsDao,
       _nostrClient = nostrClient,
       _signEvent = signEvent,
       _identityEventsDao = identityEventsDao;

  /// Event kind carrying NIP-39 identity claims since the 2026-02 spec
  /// revision. Kind-0 `i` tags are the legacy source for profiles that
  /// predate it, and are carried forward on the first write.
  static const int identityEventKind = 10011;

  /// NIP-98 HTTP auth event kind, used to prove ownership when asking the
  /// verifier to drop a cached OAuth verification.
  static const int _nip98EventKind = 27235;

  /// Client-side freshness window for verified verdicts, anchored on the
  /// verifier's `checked_at`. Mirrors the service's KV TTL for verified
  /// results (divine-identify-verification-service/src/utils/cache.ts:4).
  static const Duration verifiedTtl = Duration(hours: 24);

  /// Prefix of the verifier's rate-limit rejection message
  /// (divine-identify-verification-service/src/routes/verify.ts:59-81). The
  /// verifier returns rate-limit rejections as HTTP-200 `verified: false`
  /// bodies it never caches server-side, so a batch containing this prefix
  /// must not write new verdicts to the local snapshot — otherwise a
  /// rate-limit burst could overwrite real verdicts. (Per-claim confirmed
  /// negatives inside such a batch are conclusive and are still pruned.)
  ///
  /// [VerificationResult.error] is documented as a free-form, non-stable
  /// string, so this is a best-effort prefix match; a stable server-side
  /// rate-limit flag would remove the fragility entirely.
  static const String rateLimitErrorPrefix = 'Rate limit exceeded';

  final VerifierClient _verifierClient;
  final IdentityVerificationsDao? _verificationsDao;
  final NostrClient? _nostrClient;
  final IdentityEventSigner? _signEvent;
  final IdentityEventsDao? _identityEventsDao;

  /// Tags this instance last published per pubkey.
  ///
  /// A relay confirms a write before it necessarily serves it back, so two
  /// links added in quick succession would each read a base that predates the
  /// other and publish it away. What this device published is the one thing
  /// it can be sure of, so it is merged over a read that has not caught up.
  final Map<String, _PublishedIdentityTags> _lastPublishedTags = {};

  /// Claim keys this instance last unlinked per pubkey.
  ///
  /// The mirror image of [_lastPublishedTags]: without it, merging a stale
  /// read back in would resurrect the claim that was just removed.
  final Map<String, Set<String>> _lastRemovedKeys = {};

  /// Parses NIP-39 identity claims out of the given identity-event tag
  /// list (kind 10011, or kind 0 for pre-migration profiles).
  ///
  /// Filters to `['i', '<platform>:<identity>', '<proof>']` shape and the
  /// verifier's request contract, skips malformed entries, dedupes
  /// case-insensitively on `<platform>:<identity>` (preferring the first
  /// valid occurrence — matches verifier UI behaviour at
  /// `divine-identify-verification-service/src/index.ts:1784`), caps valid
  /// claims at [VerifierClient.maxBatchSize] (10) so a single batch suffices.
  static List<IdentityClaim> parseClaims(
    String pubkey,
    List<List<String>> tags,
  ) {
    final seen = <String>{};
    final claims = <IdentityClaim>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag[0] != 'i') continue;
      if (tag.length < 3) continue;
      final claimKey = tag[1];
      final colon = claimKey.indexOf(':');
      if (colon <= 0 || colon == claimKey.length - 1) continue;
      final platform = claimKey.substring(0, colon);
      final identity = claimKey.substring(colon + 1);
      final claim = IdentityClaim(
        pubkey: pubkey,
        platform: platform,
        identity: identity,
        proof: tag[2],
      );
      if (!claim.isServerValid) continue;
      final dedupeKey = '$platform:$identity'.toLowerCase();
      if (!seen.add(dedupeKey)) continue;
      claims.add(claim);
      if (claims.length >= VerifierClient.maxBatchSize) break;
    }
    return claims;
  }

  /// Returns the persisted verified subset of the claims in [tags], with a
  /// freshness flag — without hitting the network.
  ///
  /// Matching is a full-tuple intersection: platform and identity compare
  /// case-insensitively, proof compares exactly. A rotated proof therefore
  /// misses the snapshot and re-verifies instead of serving a stale
  /// verdict; removed claims are filtered out by the intersection.
  ///
  /// Returns null when no snapshot exists for [pubkey], the stored row is
  /// corrupt, or no DAO is wired.
  Future<CachedVerifiedClaims?> cachedVerifiedClaims({
    required String pubkey,
    required List<List<String>> tags,
  }) async {
    final dao = _verificationsDao;
    if (dao == null) return null;
    final row = await dao.getVerification(pubkey);
    if (row == null) return null;
    final snapshot = _decodeSnapshot(row.verifiedClaimsJson);
    if (snapshot == null) return null;

    final claims = parseClaims(pubkey, tags);
    final verified = claims
        .where((c) => snapshot.contains(_tupleOf(c)))
        .toList();
    final isFresh = _nowSeconds() < row.checkedAtFloor + verifiedTtl.inSeconds;
    return CachedVerifiedClaims(claims: verified, isFresh: isFresh);
  }

  /// Resolves the claims to render for [pubkey] from the freshest claim
  /// source [freshTags], reusing the instant-path snapshot [cached] already
  /// read via [cachedVerifiedClaims].
  ///
  /// This owns the stale-while-revalidate decision (kept here, not in the
  /// blocs, per architecture.md's repository-owns-source-selection rule):
  /// when [cached] is fresh and already covers every current claim, the
  /// verifier is skipped and the parsed fresh claims are returned as-is.
  /// Otherwise the claims are re-verified against the service, which also
  /// refreshes the persistent snapshot. The source tags are parsed exactly
  /// once regardless of which branch is taken.
  ///
  /// [renderedClaims] is the caller's currently-rendered last-known-good
  /// claim set. A rate-limited verifier outcome is inconclusive (the
  /// service never caches it server-side), so it must not clear chips the
  /// user can already see: any rendered or snapshot-cached claim still
  /// present in [freshTags] is preserved, matched per `platform:identity`
  /// case-insensitively (proof-agnostic, so a proof rotation coinciding
  /// with a rate-limit window keeps the chip). Only a per-claim confirmed
  /// negative verdict from a non-rate-limited result, or the claim's
  /// removal from the source tags, drops a claim from the result.
  ///
  /// Throws [VerifierClientException] subtypes on the verify path — callers
  /// should catch and keep the last-known-good claims rather than clearing
  /// them.
  Future<List<IdentityClaim>> resolveClaims({
    required String pubkey,
    required List<List<String>> freshTags,
    required CachedVerifiedClaims? cached,
    List<IdentityClaim> renderedClaims = const [],
  }) async {
    final freshClaims = parseClaims(pubkey, freshTags);
    if (cached != null && cached.isFresh) {
      final verifiedSet = cached.claims.toSet();
      if (freshClaims.every(verifiedSet.contains)) {
        return freshClaims;
      }
    }
    final outcome = await _verifyClaims(pubkey: pubkey, claims: freshClaims);
    if (outcome.rateLimited) {
      return _preserveKnownGoodClaims(
        freshClaims: freshClaims,
        knownGoodClaims: [...?cached?.claims, ...renderedClaims],
        outcome: outcome,
      );
    }
    return outcome.verified;
  }

  /// Reads [pubkey]'s claims together with the verifier's verdict on each.
  ///
  /// A verifier that cannot be reached is not a failure here: the links are
  /// the user's own data and stay visible, flagged as unchecked through
  /// [IdentityClaimStatus.verifierReachable]. Only the relay read can throw.
  ///
  /// Throws [StateError] if the repository was built without write
  /// dependencies.
  Future<IdentityClaimStatus> claimsWithVerdicts(String pubkey) async {
    final tags = await _currentIdentityTags(pubkey, forWrite: false);
    final claims = parseClaims(pubkey, tags);
    try {
      final verified = await resolveClaims(
        pubkey: pubkey,
        freshTags: tags,
        cached: await cachedVerifiedClaims(pubkey: pubkey, tags: tags),
      );
      return IdentityClaimStatus(
        claims: claims,
        verifiedKeys: {for (final claim in verified) _identityKeyOf(claim)},
        verifierReachable: true,
      );
    } on VerifierClientException {
      return IdentityClaimStatus(
        claims: claims,
        verifiedKeys: const {},
        verifierReachable: false,
      );
    }
  }

  /// Asks the verifier to check one claim, before it exists on any event.
  ///
  /// Deliberately does not touch the verdict snapshot: the claim is not on
  /// the identity event yet, and caching a verdict for a link that is never
  /// published would leave a snapshot entry nothing can ever match.
  ///
  /// Throws [VerifierClientException] subtypes.
  Future<VerificationResult> verifyClaim(IdentityClaim claim) {
    return _verifierClient.verifySingle(claim);
  }

  /// Lists the platforms the verifier currently accepts claims for.
  ///
  /// Platforms the service reports as unsupported are dropped: offering one
  /// leads to a link that can never verify.
  ///
  /// Throws [VerifierClientException] subtypes.
  Future<List<VerifierPlatform>> supportedPlatforms() async {
    final platforms = await _verifierClient.fetchPlatforms();
    return platforms.where((platform) => platform.supported).toList();
  }

  /// Starts [platform]'s OAuth flow and returns the URL to open in a browser.
  ///
  /// See `VerifierClient.resolveOAuthLaunchUri` for the contract, including
  /// which return URLs the service accepts. A null result means this
  /// deployment has no credentials for the platform and the caller has to
  /// fall back to the proof post.
  Future<Uri?> resolveOAuthLaunchUri({
    required String platform,
    required String pubkey,
    required String returnUrl,
    String? handle,
  }) {
    return _verifierClient.resolveOAuthLaunchUri(
      platform: platform,
      pubkey: pubkey,
      returnUrl: returnUrl,
      handle: handle,
    );
  }

  /// Links [claim] by writing it into the signer's kind-10011 identity event,
  /// and returns the `i` tags the published event carries.
  ///
  /// Any existing claim for the same `platform:identity` is replaced — that
  /// is how a re-link with a fresh proof updates in place. Every other tag on
  /// the event is carried through untouched, including claims for platforms
  /// this app does not know about: the event is the user's, and a client that
  /// cannot render a tag has no business dropping it. A profile whose claims
  /// still live in kind-0 tags has them carried into this first kind-10011
  /// write, matching what the verifier's web UI does.
  ///
  /// This publishes what it is told to. Confirming the claim with the
  /// verifier first is the caller's job — an unverified `i` tag is valid
  /// NIP-39 and simply renders unverified.
  ///
  /// Throws:
  ///
  /// * [StateError] if the repository was built without write dependencies.
  /// * [IdentityClaimPublishException] if the event cannot be signed, or no
  ///   relay confirms it.
  Future<List<List<String>>> publishClaim(IdentityClaim claim) async {
    final base = await _currentIdentityEventBase(claim.pubkey, forWrite: true);
    final key = _identityKeyOf(claim);
    // Linking again undoes an earlier unlink from this session.
    _lastRemovedKeys[claim.pubkey]?.remove(key);
    return _publishIdentityEvent(
      claim.pubkey,
      content: base.content,
      after: base.source,
      tags: [
        for (final tag in base.tags)
          if (_tagIdentityKeyOrNull(tag) != key) tag,
        ['i', '${claim.platform}:${claim.identity}', claim.proof],
      ],
    );
  }

  /// Unlinks the claim matching [claim]'s `platform:identity` and returns the
  /// `i` tags left on the event.
  ///
  /// Proof-agnostic, so a claim whose proof was rotated elsewhere is still
  /// removed. When the claim is not on the event, nothing is published and
  /// the current tags are returned unchanged — re-publishing an identical
  /// event would only churn relays.
  ///
  /// An OAuth-linked claim also asks the verifier to drop its cached OAuth
  /// verification, so re-linking asks the provider again instead of passing
  /// on a 24-hour-old login. That call is best-effort: the tag is already
  /// gone, which is what the user asked for, and a verifier that refuses the
  /// revoke must not turn a completed unlink into an error.
  ///
  /// Throws the same exceptions as [publishClaim].
  Future<List<List<String>>> removeClaim(IdentityClaim claim) async {
    final base = await _currentIdentityEventBase(claim.pubkey, forWrite: true);
    final key = _identityKeyOf(claim);
    final next = [
      for (final tag in base.tags)
        if (_tagIdentityKeyOrNull(tag) != key) tag,
    ];
    if (next.length == base.tags.length) return identityTagsOf(base.tags);
    final published = await _publishIdentityEvent(
      claim.pubkey,
      content: base.content,
      after: base.source,
      tags: next,
    );
    (_lastRemovedKeys[claim.pubkey] ??= <String>{}).add(key);
    await _revokeOAuthLink(claim);
    return published;
  }

  /// Drops the verifier's cached OAuth verification for [claim].
  ///
  /// No-op unless the claim was actually OAuth-linked. Never throws.
  Future<void> _revokeOAuthLink(IdentityClaim claim) async {
    if (claim.proof != IdentityClaim.oauthProof) return;
    if (!VerifierPlatform.oauthPlatforms.contains(claim.platform)) return;

    try {
      final url = _verifierClient.oauthRevokeUrl;
      final event = await _writeDeps().sign(
        kind: _nip98EventKind,
        content: '',
        tags: [
          ['u', url],
          ['method', 'POST'],
        ],
      );
      if (event == null) return;
      await _verifierClient.revokeOAuth(
        platform: claim.platform,
        identity: claim.identity,
        pubkey: claim.pubkey,
        nip98Event: event.toJson(),
      );
    } on Object catch (e) {
      Log.warning(
        'Verifier OAuth revoke failed for ${claim.platform}: $e',
        name: 'IdentityClaimsRepository',
      );
    }
  }

  /// Reads the `i` tags currently on [pubkey]'s identity event.
  ///
  /// Uncached on purpose: the event is about to be replaced wholesale, and a
  /// stale read would silently drop a claim linked on another device.
  ///
  /// [forWrite] decides what an unanswered read means. The query cannot say
  /// whether an empty result is "no claims yet" or "no relay answered", and
  /// the two need opposite handling:
  ///
  /// * Writing replaces the whole event, so publishing over an unanswered read
  ///   would silently unlink everything else, and would make a removal a no-op
  ///   that still reports success. There the local snapshot is treated as
  ///   evidence the read was incomplete, and the write is refused.
  /// * Reading has nothing to lose by showing the last known good set, and
  ///   everything to lose by blanking the screen — a list that empties itself
  ///   on a relay hiccup reads as "my links are gone".
  ///
  /// The kind-0 fallback needs the same suspicion as an empty read rather than
  /// less: it answers for every profile, so reaching it is not evidence the
  /// kind-10011 read worked. On the write path it goes through the same
  /// lagging-read merge as the identity event, and the same refusal when the
  /// local snapshot knows claims it does not carry.
  ///
  /// A kind-10011 event coming back is not evidence either, only a better
  /// starting point: the one that comes back can still be an older revision
  /// than this device has already mirrored, which
  /// [_refuseIfSnapshotIsNewer] catches.
  Future<List<List<String>>> _currentIdentityTags(
    String pubkey, {
    required bool forWrite,
  }) async {
    final base = await _currentIdentityEventBase(pubkey, forWrite: forWrite);
    return identityTagsOf(base.tags);
  }

  Future<_IdentityEventBase> _currentIdentityEventBase(
    String pubkey, {
    required bool forWrite,
  }) async {
    final client = _writeDeps().client;
    // An OAuth link sends the app to the browser and back, and the relay pool
    // does not survive that round trip. Reading against a pool that has not
    // reconnected yet returns nothing, which on the write path is refused as
    // an incomplete read — so the first attempt after returning would always
    // fail and the second would work. Reconnect first, exactly as the publish
    // path already does before sending.
    if (client.connectedRelays.isEmpty) {
      await client.retryDisconnectedRelays();
    }
    // With no relay connected, "the query returned nothing" carries no
    // information at all — and a write acts on it by replacing the whole
    // event. Refusing here is the only check that does not depend on local
    // evidence being present, which is what makes it the one that holds on a
    // device that has never completed a read.
    if (forWrite && client.connectedRelays.isEmpty) {
      throw const IdentityClaimReadException(
        'No relay is connected, so the current links cannot be read',
      );
    }
    final identityRead = await _newestEventOfKind(
      client,
      pubkey,
      identityEventKind,
    );
    final identityEvent = identityRead.event;
    if (identityEvent != null) {
      final tags = _mergeWithLastPublished(
        pubkey,
        identityEvent.tags,
        identityEventCreatedAt: identityEvent.createdAt,
        identityEventId: identityEvent.id,
      );
      // The merge drops its record once the relay catches up, so an entry
      // that survives it is strictly newer than what came back — and the
      // merged tags carry at least what it published, so stamping the
      // snapshot with its coordinates never claims more than the row holds.
      final pending = _lastPublishedTags[pubkey];
      final source = (
        createdAt: pending?.createdAt ?? identityEvent.createdAt,
        id: pending?.id ?? identityEvent.id,
      );
      Log.info(
        'Identity event for ${pubkeyForLogs(pubkey)} carries '
        '${identityTagsOf(tags).length} claim tag(s)',
        name: 'IdentityClaimsRepository',
      );
      if (forWrite) await _refuseIfSnapshotIsNewer(pubkey, source);
      await _cacheIdentityTags(pubkey, identityTagsOf(tags), source: source);
      return _IdentityEventBase(
        tags: tags,
        content: identityEvent.content,
        source: source,
      );
    }

    // An inconclusive kind-10011 read is not evidence that the profile has no
    // identity event, and the kind-0 fallback cannot tell the difference:
    // every profile has a kind-0, so it answers either way and would report
    // "no claims" for a profile whose claims simply did not arrive. Prefer the
    // last-known-good snapshot instead of rendering an empty set (#6154).
    //
    // ProfileRepository._fetchIdentityEvent answers the partial-read question
    // the other way for display, on purpose — see the note there.
    if (!identityRead.conclusive) {
      final cachedRow = await _cachedIdentityRow(pubkey);
      final cached = _decodeSnapshotRow(cachedRow, pubkey);
      if (cached != null && cached.isNotEmpty) {
        // Only a kind-10011-sourced snapshot is evidence that the unsettled
        // read was lagging. A kind-0-sourced row is what the fallback itself
        // wrote (profile_repository.dart caches kind-0 tags with sourceKind 0),
        // so refusing on it would block a legitimate first link for a
        // pre-migration profile every time one relay failed to settle.
        if (forWrite && cachedRow?.sourceKind == identityEventKind) {
          throw const IdentityClaimReadException(
            'The identity event read did not settle, but this profile is '
            'known to have claims — refusing to publish over them',
          );
        }
        if (!forWrite) {
          Log.warning(
            'Inconclusive kind-$identityEventKind read for '
            '${pubkeyForLogs(pubkey)}; serving the snapshot with '
            '${cached.length} claim tag(s) rather than the kind-0 fallback',
            name: 'IdentityClaimsRepository',
          );
          return _IdentityEventBase(tags: cached, content: '');
        }
        // Write path, kind-0-sourced snapshot. Deliberately falls through to a
        // fresh kind-0 read rather than publishing on the snapshot, so
        // _refuseIfLocalEvidenceIsAhead still gets to compare the publish base
        // against what this device already knows.
        Log.warning(
          'Inconclusive kind-$identityEventKind read for '
          '${pubkeyForLogs(pubkey)} with a kind-0-sourced snapshot; reading '
          'kind-0 fresh so the publish base stays checkable',
          name: 'IdentityClaimsRepository',
        );
      } else {
        // No snapshot to prefer, so the kind-0 fallback below is all there is.
        // Say so plainly: a later empty result is not evidence of no claims.
        Log.warning(
          'Inconclusive kind-$identityEventKind read for '
          '${pubkeyForLogs(pubkey)} and no snapshot to fall back on; '
          'continuing to kind-0, which cannot distinguish "no claims" from '
          '"claims did not arrive"',
          name: 'IdentityClaimsRepository',
        );
      }
    }

    // Only the event: kind-0 does not get the same suspicion as kind 10011.
    // Every profile has a kind-0 and every relay carries it, so an unsettled
    // kind-0 read is not the "one relay holds it and did not answer" shape
    // this block exists for — and the write path's own guard
    // (_refuseIfLocalEvidenceIsAhead) already compares this base against the
    // snapshot before anything is published.
    final legacyEvent = (await _newestEventOfKind(client, pubkey, 0)).event;
    if (legacyEvent != null) {
      final tags = _mergeWithLastPublished(
        pubkey,
        identityTagsOf(legacyEvent.tags),
      );
      Log.info(
        'No kind-$identityEventKind event for ${pubkeyForLogs(pubkey)}; kind-0 '
        'carries '
        '${tags.length} claim tag(s)',
        name: 'IdentityClaimsRepository',
      );
      if (forWrite) await _refuseIfLocalEvidenceIsAhead(pubkey, tags);
      return _IdentityEventBase(tags: tags, content: '');
    }

    final cached = await _cachedIdentityTags(pubkey);
    Log.warning(
      'No identity event returned for ${pubkeyForLogs(pubkey)}; snapshot has '
      '${cached?.length ?? 0} claim tag(s)',
      name: 'IdentityClaimsRepository',
    );
    if (cached == null || cached.isEmpty) {
      // The identity snapshot can be absent on a device that has never
      // completed a read. The verdict snapshot is written by a different code
      // path, so it is a second, independent witness that this profile does
      // have claims worth not overwriting.
      if (forWrite && await _hasVerdictSnapshot(pubkey)) {
        throw const IdentityClaimReadException(
          'Relays returned no identity event, but verified claims are on '
          'record for this profile — refusing to publish over them',
        );
      }
      return const _IdentityEventBase(tags: [], content: '');
    }
    if (forWrite) {
      throw const IdentityClaimReadException(
        'Relays returned no identity event, but this profile is known to have '
        'claims — refusing to publish over them',
      );
    }
    return _IdentityEventBase(tags: cached, content: '');
  }

  /// Refuses a write whose relay read is behind what this device already knows.
  ///
  /// Reaching the kind-0 fallback says nothing about whether the kind-10011
  /// read succeeded: every profile has a kind-0 metadata event, so that query
  /// answers even when the identity event does not come back — including right
  /// after the OAuth browser round trip, when the pool has reconnected but has
  /// not caught up. Publishing on it would replace the identity event with a
  /// set that predates the claims this device has already seen, which is the
  /// same silent unlink the empty-read branch refuses, reached through the one
  /// branch that used to skip every guard.
  ///
  /// A claim unlinked in this session is not evidence of a lagging read, so
  /// [_lastRemovedKeys] is excluded rather than counted as missing.
  Future<void> _refuseIfLocalEvidenceIsAhead(
    String pubkey,
    List<List<String>> tags,
  ) async {
    final present = {for (final tag in tags) _tagIdentityKey(tag)};
    final removed = _lastRemovedKeys[pubkey] ?? const <String>{};
    final snapshot = identityTagsOf(
      await _cachedIdentityTags(pubkey) ?? const [],
    );
    final missing = snapshot
        .map(_tagIdentityKey)
        .where((key) => !present.contains(key) && !removed.contains(key))
        .length;
    if (missing > 0) {
      throw IdentityClaimReadException(
        'No kind-$identityEventKind event came back and the kind-0 fallback '
        'is missing $missing claim(s) this device has already seen — '
        'refusing to publish over them',
      );
    }
    if (tags.isEmpty && await _hasVerdictSnapshot(pubkey)) {
      throw const IdentityClaimReadException(
        'Only a kind-0 event with no claims came back, but verified claims '
        'are on record for this profile — refusing to publish over them',
      );
    }
  }

  /// Refuses a write whose kind-10011 read is an older revision than the one
  /// this device has already mirrored.
  ///
  /// Kind 10011 is replaceable, so the only thing that can legitimately drop a
  /// claim is a *newer* event: unlinking on another device replaces the event
  /// and moves `created_at` forward. An older event coming back is a relay
  /// that has not caught up — after an app restart, or on a session where
  /// [_lastPublishedTags] cannot vouch for the claim — and publishing on it
  /// would replace the current event with a set that predates what this
  /// device has already seen. That is the same silent unlink the empty-read
  /// and kind-0 branches refuse, reached through the branch that used to
  /// trust the read outright (#7081).
  ///
  /// Only a strictly older read is refused, so a remote unlink is never
  /// blocked: its event is newer and goes through on the first attempt. A
  /// snapshot written before the source columns existed has nothing to
  /// compare against and is skipped rather than guessed at; the next read
  /// stamps it.
  Future<void> _refuseIfSnapshotIsNewer(
    String pubkey,
    _IdentitySource source,
  ) async {
    final cached = await _cachedIdentitySource(pubkey);
    if (cached == null || !_isBehind(source, cached)) return;
    throw IdentityClaimReadException(
      'The kind-$identityEventKind event that came back (created_at '
      '${source.createdAt}) is an older revision than the one this device '
      'has already seen (created_at ${cached.createdAt}) — refusing to '
      'publish over it',
    );
  }

  /// Whether [source] is superseded by [other] under NIP-01 ordering.
  static bool _isBehind(_IdentitySource source, _IdentitySource other) =>
      compareIdentityEvents(
        createdAt: source.createdAt,
        id: source.id,
        otherCreatedAt: other.createdAt,
        otherId: other.id,
      ) <
      0;

  /// Whether the verdict snapshot has ever recorded a verified claim here.
  Future<bool> _hasVerdictSnapshot(String pubkey) async {
    final dao = _verificationsDao;
    if (dao == null) return false;
    try {
      final row = await dao.getVerification(pubkey);
      if (row == null) return false;
      return _decodeSnapshot(row.verifiedClaimsJson)?.isNotEmpty ?? false;
    } on Object catch (e) {
      Log.warning(
        'Verdict snapshot read failed for ${pubkeyForLogs(pubkey)}: $e',
        name: 'IdentityClaimsRepository',
      );
      return false;
    }
  }

  /// Last known `i` tags from the local snapshot, or null when there is none
  /// or it cannot be read.
  ///
  /// Any source kind counts: a kind-0 row still proves the profile had claims,
  /// which is all this is asked for.
  Future<List<List<String>>?> _cachedIdentityTags(String pubkey) async =>
      _decodeSnapshotRow(await _cachedIdentityRow(pubkey), pubkey);

  /// Decodes [row]'s `i` tags, or null when absent or unreadable.
  ///
  /// Split out so a caller that already needs the row (to check its source
  /// kind) does not read the same row from the DAO twice.
  List<List<String>>? _decodeSnapshotRow(IdentityEventRow? row, String pubkey) {
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.tagsJson) as List<dynamic>;
      return [
        for (final tag in decoded)
          (tag as List<dynamic>).map((value) => value as String).toList(),
      ];
    } on Object catch (e) {
      Log.warning(
        'Identity-tags snapshot is unreadable for ${pubkeyForLogs(pubkey)}: $e',
        name: 'IdentityClaimsRepository',
      );
      return null;
    }
  }

  /// Coordinates of the identity event the local snapshot was built from, or
  /// null when there is no row, it cannot be read, or it carries none —
  /// a kind-0 fallback row, or a row written before those columns existed.
  Future<_IdentitySource?> _cachedIdentitySource(String pubkey) async {
    final row = await _cachedIdentityRow(pubkey);
    final createdAt = row?.sourceCreatedAt;
    final id = row?.sourceEventId;
    if (createdAt == null || id == null) return null;
    return (createdAt: createdAt, id: id);
  }

  Future<IdentityEventRow?> _cachedIdentityRow(String pubkey) async {
    final dao = _identityEventsDao;
    if (dao == null) return null;
    try {
      return await dao.getEvent(pubkey);
    } on Object catch (e) {
      Log.warning(
        'Identity-tags snapshot read failed for ${pubkeyForLogs(pubkey)}: $e',
        name: 'IdentityClaimsRepository',
      );
      return null;
    }
  }

  /// Reads the newest event of [kind] for [pubkey], reporting whether the
  /// read was conclusive.
  ///
  /// `queryEventsDetailed` with `requireAllRelaysSettled`, not `queryEvents`:
  /// the latter drops `timedOut` and `noRelays`, so a fan-out that settled on
  /// whichever relay answered first returns `[]` and is indistinguishable from
  /// "this profile has no identity event". Divine's identity events live on
  /// `relay.divine.video`; a general-purpose relay in the pool answering
  /// `EOSE` with nothing would end the read before the one relay that holds
  /// the event ever replied, and the claims would vanish from the profile with
  /// no error and no log (#6154).
  Future<({Event? event, bool conclusive})> _newestEventOfKind(
    NostrClient client,
    String pubkey,
    int kind,
  ) async {
    final result = await client.queryEventsDetailed(
      [
        Filter(kinds: [kind], authors: [pubkey], limit: 5),
      ],
      useCache: false,
      requireAllRelaysSettled: true,
    );
    final event = newestIdentityEvent(
      result.events.where((e) => e.kind == kind).toList(),
    );
    return (event: event, conclusive: !result.timedOut && !result.noRelays);
  }

  /// Signs and publishes a kind-10011 event carrying [tags].
  ///
  /// [after] is the event this one replaces. Kind 10011 is replaceable, so the
  /// new event has to supersede it under NIP-01 ordering — and `created_at` is
  /// in whole seconds, so a second write inside the same second would
  /// otherwise sign a tie, which NIP-01 breaks by lowest id and therefore
  /// resolves against this event half the time. A relay that keeps the older
  /// one drops the write silently; a relay that keeps the newer one leaves
  /// the snapshot mirroring an event this device now reads as stale, which
  /// [_refuseIfSnapshotIsNewer] then refuses forever. Dating the event one
  /// second past what it replaces removes the tie instead of picking a side
  /// (#7081).
  Future<List<List<String>>> _publishIdentityEvent(
    String pubkey, {
    required List<List<String>> tags,
    required String content,
    required _IdentitySource? after,
  }) async {
    final deps = _writeDeps();
    // The base is the newest event that came back; when none did, the
    // snapshot still carries the newest coordinates this device has seen.
    final replaced = after ?? await _cachedIdentitySource(pubkey);
    final event = await deps.sign(
      kind: identityEventKind,
      content: content,
      tags: tags,
      createdAt: replaced == null
          ? null
          : max(_nowSeconds(), replaced.createdAt + 1),
    );
    if (event == null) {
      throw const IdentityClaimPublishException(
        'Could not sign the identity event',
      );
    }

    final outcome = await deps.client.publishEventAwaitOk(event);
    if (outcome.failed) {
      throw IdentityClaimPublishException(
        'No relay confirmed the identity event: ${outcome.summary}',
      );
    }

    final identityTags = identityTagsOf(tags);
    await _cacheIdentityTags(
      pubkey,
      identityTags,
      source: (createdAt: event.createdAt, id: event.id),
    );
    _lastPublishedTags[pubkey] = _PublishedIdentityTags(
      tags: identityTags,
      createdAt: event.createdAt,
      id: event.id,
    );
    return identityTags;
  }

  /// Adds back any claim this device published that [relayTags] does not carry
  /// yet, so a relay that has not caught up cannot make the next write drop it.
  List<List<String>> _mergeWithLastPublished(
    String pubkey,
    List<List<String>> relayTags, {
    int? identityEventCreatedAt,
    String? identityEventId,
  }) {
    final published = _lastPublishedTags[pubkey];
    if (published == null) return relayTags;
    if (_isAtLeastAsNewAsLastPublished(
      published,
      identityEventCreatedAt: identityEventCreatedAt,
      identityEventId: identityEventId,
    )) {
      _lastPublishedTags.remove(pubkey);
      _lastRemovedKeys.remove(pubkey);
      return relayTags;
    }

    final removed = _lastRemovedKeys[pubkey] ?? const <String>{};
    final kept = [
      for (final tag in relayTags)
        if (!removed.contains(_tagIdentityKeyOrNull(tag))) tag,
    ];
    final present = {
      for (final tag in identityTagsOf(kept)) _tagIdentityKey(tag),
    };
    final missing = [
      for (final tag in published.tags)
        if (!present.contains(_tagIdentityKey(tag))) tag,
    ];
    if (missing.isEmpty && kept.length == relayTags.length) return relayTags;

    Log.warning(
      'Relay read for ${pubkeyForLogs(pubkey)} lags this device: re-adding '
      '${missing.length} '
      'published claim(s), dropping ${relayTags.length - kept.length} removed',
      name: 'IdentityClaimsRepository',
    );
    return [...kept, ...missing];
  }

  static bool _isAtLeastAsNewAsLastPublished(
    _PublishedIdentityTags published, {
    required int? identityEventCreatedAt,
    required String? identityEventId,
  }) {
    if (identityEventCreatedAt == null || identityEventId == null) return false;
    return !_isBehind(
      (createdAt: identityEventCreatedAt, id: identityEventId),
      (createdAt: published.createdAt, id: published.id),
    );
  }

  /// Mirrors the published tags into the local identity cache so the new
  /// link renders immediately.
  ///
  /// Skipped when [source] is an older revision than the event the row
  /// already mirrors: the snapshot only ever moves forward, so a relay read
  /// that is behind cannot quietly erase the evidence
  /// [_refuseIfSnapshotIsNewer] checks the next write against.
  ///
  /// Best-effort otherwise: a storage failure must not turn a landed publish
  /// into a thrown one.
  Future<void> _cacheIdentityTags(
    String pubkey,
    List<List<String>> tags, {
    required _IdentitySource source,
  }) async {
    final cached = await _cachedIdentitySource(pubkey);
    if (cached != null && _isBehind(source, cached)) {
      Log.warning(
        'Identity snapshot for ${pubkeyForLogs(pubkey)} mirrors a newer event '
        '(created_at '
        '${cached.createdAt}) than the one just read (created_at '
        '${source.createdAt}); keeping the snapshot',
        name: 'IdentityClaimsRepository',
      );
      return;
    }
    try {
      await _identityEventsDao?.upsertEvent(
        pubkey: pubkey,
        tagsJson: jsonEncode(tags),
        sourceKind: identityEventKind,
        sourceCreatedAt: source.createdAt,
        sourceEventId: source.id,
      );
    } on Object catch (e) {
      Log.warning(
        'Identity-tags cache write after publish failed for '
        '${pubkeyForLogs(pubkey)}: $e',
        name: 'IdentityClaimsRepository',
      );
    }
  }

  ({NostrClient client, IdentityEventSigner sign}) _writeDeps() {
    final client = _nostrClient;
    final sign = _signEvent;
    if (client == null || sign == null) {
      throw StateError(
        'IdentityClaimsRepository was built without a NostrClient and signer, '
        'so it cannot write identity claims',
      );
    }
    return (client: client, sign: sign);
  }

  /// Normalized `platform:identity` key of a raw `i` tag.
  static String _tagIdentityKey(List<String> tag) => tag[1].toLowerCase();

  /// Normalized `platform:identity` key when [tag] is a raw `i` tag.
  static String? _tagIdentityKeyOrNull(List<String> tag) =>
      tag.length >= 3 && tag[0] == 'i' ? _tagIdentityKey(tag) : null;

  /// Asks the verifier to re-check [claims] and returns only the verified
  /// ones, preserving input order.
  ///
  /// On success the persistent snapshot for [pubkey] is updated: verified
  /// tuples are stored with the batch's minimum `checked_at`; a
  /// zero-verified response deletes the snapshot. Only positive verdicts
  /// are ever persisted — and when any result carries the verifier's
  /// rate-limit error (see [rateLimitErrorPrefix]) no new verdicts are
  /// written, so a rate-limit burst cannot overwrite real verdicts. The
  /// one exception: entries whose own result is a confirmed negative are
  /// pruned from the snapshot even in a rate-limited batch, so a negated
  /// claim cannot keep resurrecting from cache.
  ///
  /// Throws [VerifierClientException] subtypes.
  Future<_VerificationOutcome> _verifyClaims({
    required String pubkey,
    required List<IdentityClaim> claims,
  }) async {
    if (claims.isEmpty) {
      return const _VerificationOutcome(verified: [], rateLimited: false);
    }
    final results = await _verifierClient.verifyBatch(claims);
    final verifiedKeys = <String>{
      for (final r in results)
        if (r.verified)
          '${r.platform.toLowerCase()}:${r.identity.toLowerCase()}',
    };
    final confirmedNegativeKeys = <String>{
      for (final r in results)
        if (!r.verified && !_isRateLimitResult(r))
          '${r.platform.toLowerCase()}:${r.identity.toLowerCase()}',
    };
    final verified = claims
        .where((c) => verifiedKeys.contains(_identityKeyOf(c)))
        .toList();
    final rateLimited = results.any(_isRateLimitResult);
    await _persistOutcome(
      pubkey: pubkey,
      results: results,
      verified: verified,
      rateLimited: rateLimited,
      confirmedNegativeKeys: confirmedNegativeKeys,
    );
    return _VerificationOutcome(
      verified: verified,
      rateLimited: rateLimited,
      confirmedNegativeKeys: confirmedNegativeKeys,
    );
  }

  /// Preservation for a rate-limited (inconclusive) batch: a fresh claim
  /// survives when its own result verified it, or when it was known-good
  /// (snapshot or rendered) and its own result was not a confirmed
  /// negative. Matching is per `platform:identity`, case-insensitive and
  /// proof-agnostic — the verifier judges identities, not proof strings,
  /// so a rotated proof must not silently drop a chip while the verdict
  /// is inconclusive.
  List<IdentityClaim> _preserveKnownGoodClaims({
    required List<IdentityClaim> freshClaims,
    required List<IdentityClaim> knownGoodClaims,
    required _VerificationOutcome outcome,
  }) {
    final knownGoodKeys = {
      for (final claim in knownGoodClaims) _identityKeyOf(claim),
    };
    final verifiedKeys = {
      for (final claim in outcome.verified) _identityKeyOf(claim),
    };
    return [
      for (final claim in freshClaims)
        if (verifiedKeys.contains(_identityKeyOf(claim)) ||
            (knownGoodKeys.contains(_identityKeyOf(claim)) &&
                !outcome.confirmedNegativeKeys.contains(_identityKeyOf(claim))))
          claim,
    ];
  }

  Future<void> _persistOutcome({
    required String pubkey,
    required List<VerificationResult> results,
    required List<IdentityClaim> verified,
    required bool rateLimited,
    required Set<String> confirmedNegativeKeys,
  }) async {
    final dao = _verificationsDao;
    if (dao == null) return;

    if (rateLimited) {
      // A rate-limited batch persists no new verdicts, but any per-claim
      // confirmed negative inside it is conclusive — prune those tuples
      // so a negated claim cannot resurrect from the snapshot through
      // the instant path or the fresh-and-covering skip.
      await _pruneConfirmedNegatives(dao, pubkey, confirmedNegativeKeys);
      return;
    }

    if (verified.isEmpty) {
      await dao.deleteVerification(pubkey);
      return;
    }

    final checkedAtFloor = results
        .where((r) => r.verified)
        .map((r) => r.checkedAt)
        .reduce(min);
    await dao.upsertVerification(
      pubkey: pubkey,
      verifiedClaimsJson: jsonEncode([
        for (final c in verified)
          {'platform': c.platform, 'identity': c.identity, 'proof': c.proof},
      ]),
      checkedAtFloor: checkedAtFloor,
    );
  }

  /// Removes snapshot entries whose `platform:identity` key received a
  /// confirmed (non-rate-limited) negative verdict. Rows that are missing
  /// or malformed are left alone — the read path already treats them as
  /// no-snapshot.
  Future<void> _pruneConfirmedNegatives(
    IdentityVerificationsDao dao,
    String pubkey,
    Set<String> confirmedNegativeKeys,
  ) async {
    if (confirmedNegativeKeys.isEmpty) return;
    final row = await dao.getVerification(pubkey);
    if (row == null) return;
    final List<Map<String, dynamic>> kept;
    try {
      final entries = (jsonDecode(row.verifiedClaimsJson) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      kept = [
        for (final entry in entries)
          if (!confirmedNegativeKeys.contains(
            '${(entry['platform'] as String).toLowerCase()}'
            ':${(entry['identity'] as String).toLowerCase()}',
          ))
            entry,
      ];
      if (kept.length == entries.length) return;
    } on Object {
      return;
    }
    if (kept.isEmpty) {
      await dao.deleteVerification(pubkey);
    } else {
      await dao.upsertVerification(
        pubkey: pubkey,
        verifiedClaimsJson: jsonEncode(kept),
        checkedAtFloor: row.checkedAtFloor,
      );
    }
  }

  static bool _isRateLimitResult(VerificationResult result) =>
      !result.verified &&
      (result.error?.startsWith(rateLimitErrorPrefix) ?? false);

  /// Normalized comparison tuple for snapshot matching.
  static (String, String, String) _tupleOf(IdentityClaim claim) =>
      (claim.platform.toLowerCase(), claim.identity.toLowerCase(), claim.proof);

  /// Normalized `platform:identity` key — the granularity the verifier
  /// judges at (proofs are evidence, not identity).
  static String _identityKeyOf(IdentityClaim claim) =>
      '${claim.platform.toLowerCase()}:${claim.identity.toLowerCase()}';

  /// Decodes a stored snapshot into comparison tuples; null when malformed
  /// or wrong-shaped.
  ///
  /// Catches [Object] (not just [Exception]): a valid-JSON-but-wrong-shape
  /// row throws a [TypeError] (an [Error]) on the casts, which must still
  /// uphold the null-when-malformed contract rather than escaping to a
  /// reportable crash.
  static Set<(String, String, String)>? _decodeSnapshot(String json) {
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return {
        for (final entry in decoded.cast<Map<String, dynamic>>())
          (
            (entry['platform'] as String).toLowerCase(),
            (entry['identity'] as String).toLowerCase(),
            entry['proof'] as String,
          ),
      };
    } on Object {
      return null;
    }
  }
}
