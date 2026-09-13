// ABOUTME: Read-only view of [ProfileRepository] — the members that need
// ABOUTME: neither a signer nor a relay-ready client.

import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

/// The subset of [ProfileRepository] that reads profile data without ever
/// signing or publishing.
///
/// This exists to make a **security boundary compile-time enforceable**.
/// `profileRepositoryProvider` withholds the repository until the
/// signer-backed `NostrClient` has rebuilt for the active identity, which
/// prevents a publish from being signed by the wrong key (#1048). But that
/// same gate was also withholding purely local Drift reads, so the signed-in
/// user's own name and avatar were replaced by a generated placeholder for
/// the whole relay-connect window (#6423).
///
/// `profileReadRepositoryProvider` therefore hands over a [ProfileReader] as
/// soon as the identity is known. Because the type cannot express
/// `saveProfileEvent`, `claimUsername` or
/// `drivePendingSave`, a consumer of the loose provider cannot publish even
/// by accident — the ungated phase carries a pubkey but no client, so signing
/// there is unsafe while Drift reads are not.
///
/// Every member below is signer-free: each either reads Drift directly or
/// performs a network read without signing. Fresh profile reads may fall back
/// to relays, but none requires relay readiness.
///
/// **Do not widen this interface without re-checking that invariant.** The
/// write-intent members (`cacheProfile`, `deleteCachedProfile`,
/// `enqueuePendingSave`, `clearPendingSave`, `resetInterruptedPendingSave`)
/// are deliberately absent too — they do not sign, but a caller reaching for
/// them through the read handle is a design smell worth catching in review.
/// `mobile/scripts/check_profile_read_write_split.sh` guards the indirect
/// route a type cannot see.
abstract interface class ProfileReader {
  /// Returns the cached profile from local storage (SQLite) only.
  ///
  /// Returns `null` if no cached profile exists for the given pubkey.
  Future<UserProfile?> getCachedProfile({required String pubkey});

  /// Returns the cached profiles for [pubkeys] in a single Drift query.
  ///
  /// The batch counterpart to [getCachedProfile]: same local-storage-only
  /// semantics — one `WHERE pubkey IN (...)` read, no relay, no REST — so it
  /// satisfies the signer-free, relay-optional invariant this interface
  /// guards. Pubkeys without a cached profile, or profiles filtered by the
  /// repository's block policy, are absent from the result, which is not
  /// order-aligned with [pubkeys].
  Future<List<UserProfile>> getCachedProfiles({required List<String> pubkeys});

  /// Watches the cached profile for [pubkey], emitting on every cache write.
  Stream<UserProfile?> watchProfile({required String pubkey});

  /// Watches the follower/following/video counts for [pubkey].
  ///
  /// Emits `null` if no stats exist, and an empty stream when no stats DAO
  /// was injected.
  Stream<ProfileStats?> watchProfileStats({required String pubkey});

  /// Fetches the freshest profile for [pubkey] and caches it locally.
  ///
  /// Reads only — the relay query and the funnelcake REST fallback are both
  /// unauthenticated. A `null` result can mean either authoritative absence
  /// or an indeterminate relay/API result; use [isConfirmedMissing] to
  /// distinguish them.
  Future<UserProfile?> fetchFreshProfile({
    required String pubkey,
    bool requireRawKind0,
    List<Duration> rawKind0RetryDelays,
  });

  /// Whether the latest fetch positively established that [pubkey] has no
  /// published profile.
  ///
  /// Empty or failed relay queries are not authoritative absence. This is
  /// true only for sources that explicitly report a missing Kind 0 profile.
  bool isConfirmedMissing(String pubkey);

  /// Resolves many profiles at once, preferring the Drift cache.
  ///
  /// Partial results are returned rather than throwing.
  /// Set [ignoreBlockFilter] only for a surface that manages blocked accounts.
  Future<Map<String, UserProfile>> fetchBatchProfiles({
    required List<String> pubkeys,
    bool ignoreBlockFilter,
  });

  /// Looks up the active Divine username owned by [pubkeyHex].
  ///
  /// This is a public, unauthenticated name-server read. It returns unknown
  /// rather than throwing when ownership cannot be determined.
  Future<DivineUsernameLookup> lookupUsernameByPubkey({
    required String pubkeyHex,
  });

  /// Returns the cached NIP-39 `i` tag list for [pubkey] from local storage.
  ///
  /// Does NOT hit the network. Returns `null` when nothing is cached.
  Future<List<List<String>>?> cachedIdentityTags(String pubkey);

  /// Fetches the freshest NIP-39 identity-claims source for [pubkey].
  ///
  /// Never throws — relay failures fall through the consult order.
  Future<List<List<String>>> freshIdentityTags({
    required String pubkey,
    required List<List<String>> kind0Tags,
  });
}
