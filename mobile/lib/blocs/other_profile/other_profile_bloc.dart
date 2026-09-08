// ABOUTME: BLoC for viewing another user's profile
// ABOUTME: Implements cache+fresh pattern and block/unblock actions

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

part 'other_profile_event.dart';
part 'other_profile_state.dart';

/// BLoC for managing the state of viewing another user's profile.
///
/// Implements the cache+fresh pattern:
/// 1. On [OtherProfileLoadRequested], emit cached profile immediately (if available)
/// 2. Fetch fresh profile from relay
/// 3. Emit fresh profile when received
///
/// Also handles block/unblock actions via [OtherProfileBlockRequested]
/// and [OtherProfileUnblockRequested].
///
/// The [pubkey] is provided at construction time since this BLoC is scoped
/// to a single profile screen instance.
class OtherProfileBloc extends Bloc<OtherProfileEvent, OtherProfileState> {
  OtherProfileBloc({
    required ProfileRepository profileRepository,
    required this.pubkey,
    required ContentBlocklistRepository contentBlocklistRepository,
    required String currentUserPubkey,
    required FollowRepository followRepository,
    bool requireRawKind0 = false,
    IdentityClaimsRepository? identityClaimsRepository,
    List<Duration> rawKind0RetryDelays = _defaultRawKind0RetryDelays,
  }) : _profileRepository = profileRepository,
       _blocklistRepository = contentBlocklistRepository,
       _currentUserPubkey = currentUserPubkey,
       _followRepository = followRepository,
       _requireRawKind0 = requireRawKind0,
       _identityClaimsRepository = identityClaimsRepository,
       _rawKind0RetryDelays = rawKind0RetryDelays,
       super(const OtherProfileInitial()) {
    on<OtherProfileLoadRequested>(_onLoadRequested);
    on<OtherProfileRefreshRequested>(_onRefreshRequested);
    on<OtherProfileBlockRequested>(_onBlockRequested);
    on<OtherProfileUnblockRequested>(_onUnblockRequested);
    on<VerifiedClaimsRequested>(
      _onVerifiedClaimsRequested,
      transformer: restartable(),
    );
  }

  final ProfileRepository _profileRepository;
  final ContentBlocklistRepository _blocklistRepository;
  final String _currentUserPubkey;
  final FollowRepository _followRepository;
  final bool _requireRawKind0;
  final IdentityClaimsRepository? _identityClaimsRepository;

  /// Repository-owned raw Kind 0 retry delays. Injectable so tests don't wait
  /// on real relay backoff.
  final List<Duration> _rawKind0RetryDelays;

  static const _defaultRawKind0RetryDelays = [
    Duration(milliseconds: 600),
    Duration(milliseconds: 1200),
    Duration(milliseconds: 2400),
  ];

  /// The pubkey of the profile being viewed.
  final String pubkey;

  /// Whether the viewer can stop hiding the viewed profile.
  ///
  /// Includes both Divine blocks and mutes imported from another Nostr
  /// client, so either source reaches the existing Unblock action.
  bool get isBlocked => _blocklistRepository.canUnblock(pubkey);

  /// Whether the current user is following the viewed profile.
  ///
  /// A blocked account reports false. That matches `MyFollowingBloc`, which
  /// every other follow surface reads and which already filters blocked
  /// pubkeys, and it matches the kind 3 we publish (#6903). The profile ⋯
  /// sheet gates its `Unfollow <name>` row on this, so without the check it
  /// offers to unfollow an account the rest of the app says is not followed.
  ///
  /// This reads the repository's block predicate rather than [isBlocked]:
  /// a mute imported from another client severs nothing, so `MyFollowingBloc`
  /// still lists the account and `blockedPubkeysForAccount` still publishes
  /// the follow. Widening it here would hide the `Unfollow` row for an
  /// account the viewer does follow -- the same disagreement this getter
  /// exists to prevent, with the sign flipped.
  bool get isFollowing =>
      !_blocklistRepository.isBlocked(pubkey) &&
      _followRepository.isFollowing(pubkey);

  Future<void> _onLoadRequested(
    OtherProfileLoadRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    // Known-deleted accounts short-circuit before the cache read: the durable
    // vanish marker is hydrated at startup, so a cold start on a deleted
    // profile resolves without touching the network.
    if (_profileRepository.isVanished(pubkey)) {
      emit(const OtherProfileError(errorType: OtherProfileErrorType.notFound));
      return;
    }

    // 1. Get cached profile from repository
    final cachedProfile = await _profileRepository.getCachedProfile(
      pubkey: pubkey,
    );
    if (isClosed) return;
    // Carry claims through the reload so chips do not vanish and re-pop
    // while the verifier revalidates (#3936). Read AFTER the await so an
    // authoritative claims resolve landing during the cache read is not
    // clobbered by a stale capture.
    final currentClaims = _claimsFromState(state);
    emit(
      OtherProfileLoading(
        profile: cachedProfile,
        verifiedClaims: currentClaims,
      ),
    );

    try {
      final freshProfile = await _fetchFreshProfile();
      if (isClosed) return;
      final latestClaims = _claimsFromState(state);
      if (freshProfile != null) {
        emit(
          OtherProfileLoaded(
            profile: freshProfile,
            isFresh: true,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else if (_profileRepository.isVanished(pubkey)) {
        // The fetch discovered a deletion and evicted the cache. A null result
        // here is not the same as a network miss, so the stale-cache fallback
        // below must not run.
        emit(
          const OtherProfileError(errorType: OtherProfileErrorType.notFound),
        );
      } else if (cachedProfile != null) {
        emit(
          OtherProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          const OtherProfileError(errorType: OtherProfileErrorType.notFound),
        );
      }
    } catch (e) {
      if (isClosed) return;
      if (cachedProfile != null && !_profileRepository.isVanished(pubkey)) {
        emit(
          OtherProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            verifiedClaims: _claimsFromState(state),
          ),
        );
        add(const VerifiedClaimsRequested());
      } else if (_profileRepository.isVanished(pubkey)) {
        emit(
          const OtherProfileError(errorType: OtherProfileErrorType.notFound),
        );
      } else {
        emit(
          const OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
          ),
        );
      }
    }
  }

  Future<void> _onRefreshRequested(
    OtherProfileRefreshRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    if (_profileRepository.isVanished(pubkey)) {
      emit(const OtherProfileError(errorType: OtherProfileErrorType.notFound));
      return;
    }

    final currentProfile = switch (state) {
      OtherProfileInitial() => null,
      OtherProfileLoading(:final profile) => profile,
      OtherProfileLoaded(:final profile) => profile,
      OtherProfileError(:final profile) => profile,
    };
    // Carry claims through the refresh so chips do not vanish and re-pop
    // after the round-trip (#3936).
    final currentClaims = _claimsFromState(state);
    emit(
      OtherProfileLoading(
        profile: currentProfile,
        verifiedClaims: currentClaims,
      ),
    );

    try {
      final freshProfile = await _fetchFreshProfile();
      if (isClosed) return;
      if (freshProfile != null) {
        emit(
          OtherProfileLoaded(
            profile: freshProfile,
            isFresh: true,
            verifiedClaims: currentClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          OtherProfileError(
            errorType: OtherProfileErrorType.notFound,
            // Deliberately drops the stale profile when the refresh discovered
            // a deletion. other_profile_screen extracts `profile` out of the
            // error state and renders it, so carrying it here would keep the
            // deleted account on screen through every pull-to-refresh.
            profile: _profileRepository.isVanished(pubkey)
                ? null
                : currentProfile,
          ),
        );
      }
    } catch (e) {
      if (isClosed) return;
      if (currentProfile != null) {
        emit(
          OtherProfileLoaded(
            profile: currentProfile,
            isFresh: false,
            verifiedClaims: currentClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          const OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
          ),
        );
      }
    }
  }

  Future<UserProfile?> _fetchFreshProfile() {
    if (!_requireRawKind0) {
      return _profileRepository.fetchFreshProfile(pubkey: pubkey);
    }
    return _profileRepository.fetchFreshProfile(
      pubkey: pubkey,
      requireRawKind0: true,
      rawKind0RetryDelays: _rawKind0RetryDelays,
    );
  }

  Future<void> _onVerifiedClaimsRequested(
    VerifiedClaimsRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    final repo = _identityClaimsRepository;
    if (repo == null) return;

    final current = state;
    if (current is! OtherProfileLoaded) return;
    final profile = current.profile;

    // Instant path (#3936): cached claims source ∩ persisted verdict
    // snapshot renders chips without any network round-trip.
    CachedVerifiedClaims? cached;
    try {
      final cachedTags = await _profileRepository.cachedIdentityTags(
        profile.pubkey,
      );
      if (isClosed) return;
      cached = await repo.cachedVerifiedClaims(
        pubkey: profile.pubkey,
        tags: cachedTags ?? profile.rawTags,
      );
      if (isClosed) return;
      if (cached != null) {
        _emitClaims(emit, profile.pubkey, cached.claims, authoritative: false);
      }
    } on Exception catch (e, stackTrace) {
      // Cache read failure — degrade straight to the network path.
      addError(e, stackTrace);
    }

    // Refresh the claims source: kind 10011 wins, kind-0 tags fall back.
    List<List<String>> freshTags;
    try {
      freshTags = await _profileRepository.freshIdentityTags(
        pubkey: profile.pubkey,
        kind0Tags: profile.rawTags,
      );
    } on Exception catch (e, stackTrace) {
      // Degraded claims source (cache I/O failure). Resolving against the
      // kind-0 fallback could authoritatively clear chips for a profile
      // whose claims live in kind 10011, so keep last-known-good and let
      // the next revalidation tick retry.
      addError(e, stackTrace);
      return;
    }
    if (isClosed) return;

    // The repository owns the skip-or-verify (stale-while-revalidate)
    // decision; the bloc just renders whatever it resolves to (#3936). The
    // currently-rendered claims ride along so a rate-limited (inconclusive)
    // outcome cannot clear visible chips.
    try {
      final claims = await repo.resolveClaims(
        pubkey: profile.pubkey,
        freshTags: freshTags,
        cached: cached,
        renderedClaims: _claimsFromState(state),
      );
      if (isClosed) return;
      _emitClaims(emit, profile.pubkey, claims, authoritative: true);
    } on Exception catch (e, stackTrace) {
      // Verifier failures are expected (network/4xx/5xx/timeout). Per
      // .claude/rules/error_handling.md they are NOT Reportable. Keep the
      // last-known-good claims instead of erasing rendered chips.
      addError(e, stackTrace);
    }
  }

  /// Emits [claims] onto the latest state when it still shows
  /// [profilePubkey]'s profile. State may have changed mid-await, so the
  /// check runs at emit time.
  ///
  /// A non-[authoritative] emit (the instant cache path) may only add
  /// chips: it is unioned with the rendered set, so a reduced or empty
  /// snapshot intersection never clears claims the verifier has not
  /// negatively confirmed. Only the authoritative resolve path replaces
  /// the rendered set outright.
  void _emitClaims(
    Emitter<OtherProfileState> emit,
    String profilePubkey,
    List<IdentityClaim> claims, {
    required bool authoritative,
  }) {
    final latest = state;
    if (latest is OtherProfileLoaded &&
        latest.profile.pubkey == profilePubkey) {
      final next = authoritative
          ? claims
          : _withRenderedPreserved(claims, latest.verifiedClaims);
      emit(latest.copyWith(verifiedClaims: next));
    }
  }

  /// Rendered-first union keyed on case-insensitive `platform:identity`:
  /// order-stable (no chip reorder churn across revalidation ticks, and
  /// the steady-state result is deep-equal to [rendered] so the emit is
  /// Equatable-suppressed) and dedup-safe across casing or proof drift.
  List<IdentityClaim> _withRenderedPreserved(
    List<IdentityClaim> incoming,
    List<IdentityClaim> rendered,
  ) {
    if (rendered.isEmpty) return incoming;
    final renderedKeys = {for (final claim in rendered) _identityKeyOf(claim)};
    return [
      ...rendered,
      ...incoming.where(
        (claim) => !renderedKeys.contains(_identityKeyOf(claim)),
      ),
    ];
  }

  String _identityKeyOf(IdentityClaim claim) =>
      '${claim.platform.toLowerCase()}:${claim.identity.toLowerCase()}';

  List<IdentityClaim> _claimsFromState(OtherProfileState state) {
    return switch (state) {
      OtherProfileLoaded(:final verifiedClaims) => verifiedClaims,
      OtherProfileLoading(:final verifiedClaims) => verifiedClaims,
      _ => const [],
    };
  }

  Future<void> _onBlockRequested(
    OtherProfileBlockRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    // Severing the follow is not this bloc's job: FollowRepository drops
    // blocked accounts from the kind 3 it publishes, and the app-level
    // reconciler triggers that republish (#6903). Doing it here as well
    // would drop the follow locally the moment the user blocks, and only
    // two of the four block entry points would behave that way.
    await _blocklistRepository.blockUser(pubkey, ourPubkey: _currentUserPubkey);
  }

  Future<void> _onUnblockRequested(
    OtherProfileUnblockRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    await _blocklistRepository.unblockUser(pubkey);
  }
}
