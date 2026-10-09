// ABOUTME: BLoC for the current user's own profile
// ABOUTME: Supports one-shot load (editor) and stream subscription (profile screen)

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

part 'my_profile_event.dart';
part 'my_profile_state.dart';

/// BLoC for the current user's own profile.
class MyProfileBloc extends Bloc<MyProfileEvent, MyProfileState> {
  MyProfileBloc({
    required ProfileReader profileRepository,
    required this.pubkey,
    IdentityClaimsRepository? identityClaimsRepository,
  }) : _profileRepository = profileRepository,
       _identityClaimsRepository = identityClaimsRepository,
       super(const MyProfileInitial()) {
    on<MyProfileLoadRequested>(_onLoadRequested);
    on<MyProfileSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<MyProfileFetchRequested>(_onFetchRequested);
    on<MyProfileRefreshRequested>(
      _onRefreshRequested,
      transformer: sequential(),
    );
    on<VerifiedClaimsRequested>(
      _onVerifiedClaimsRequested,
      transformer: restartable(),
    );
  }

  final ProfileReader _profileRepository;
  final IdentityClaimsRepository? _identityClaimsRepository;

  /// The pubkey of the current user.
  final String pubkey;

  Future<void> _onLoadRequested(
    MyProfileLoadRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    // 1. Get cached profile and emit immediately
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
      MyProfileLoading(
        profile: cachedProfile,
        extractedUsername: cachedProfile?.divineUsername,
        externalNip05: cachedProfile?.externalNip05,
        verifiedClaims: currentClaims,
      ),
    );

    // 2. Fetch fresh profile from relay
    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );
      if (isClosed) return;

      final latestClaims = _claimsFromState(state);
      if (freshProfile != null) {
        emit(
          MyProfileLoaded(
            profile: freshProfile,
            isFresh: true,
            extractedUsername: freshProfile.divineUsername,
            externalNip05: freshProfile.externalNip05,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else if (cachedProfile != null) {
        emit(
          MyProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            extractedUsername: cachedProfile.divineUsername,
            externalNip05: cachedProfile.externalNip05,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          MyProfileError(
            errorType: _missingProfileErrorType(),
          ),
        );
      }
    } on Exception {
      if (isClosed) return;
      if (cachedProfile != null) {
        emit(
          MyProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            extractedUsername: cachedProfile.divineUsername,
            externalNip05: cachedProfile.externalNip05,
            verifiedClaims: _claimsFromState(state),
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(const MyProfileError(errorType: MyProfileErrorType.networkError));
      }
    }
  }

  Future<void> _onSubscriptionRequested(
    MyProfileSubscriptionRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    // Pre-seed with cached profile so the real display name is shown
    // immediately rather than a generated fallback while the Drift watch
    // stream fires its first event. Mirrors the same pattern used in
    // _onLoadRequested.
    final cachedProfile = await _profileRepository.getCachedProfile(
      pubkey: pubkey,
    );
    if (isClosed) return;
    emit(
      MyProfileLoading(
        profile: cachedProfile,
        extractedUsername: cachedProfile?.divineUsername,
        externalNip05: cachedProfile?.externalNip05,
        verifiedClaims: _claimsFromState(state),
      ),
    );

    await emit.forEach<UserProfile?>(
      _profileRepository.watchProfile(pubkey: pubkey),
      onData: (profile) {
        if (isClosed) return state;
        if (profile != null) {
          add(const VerifiedClaimsRequested());
          // Carry claims through the stream tick so chips do not blank
          // while the verifier revalidates (#3936).
          return MyProfileUpdated(
            profile: profile,
            extractedUsername: profile.divineUsername,
            externalNip05: profile.externalNip05,
            verifiedClaims: _claimsFromState(state),
          );
        }
        final currentProfile = _profileFromState(state);
        if (currentProfile == null) return const MyProfileLoading();
        return MyProfileLoading(
          profile: currentProfile,
          extractedUsername: currentProfile.divineUsername,
          externalNip05: currentProfile.externalNip05,
          verifiedClaims: _claimsFromState(state),
        );
      },
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state;
      },
    );
  }

  Future<void> _onFetchRequested(
    MyProfileFetchRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    try {
      await _profileRepository.fetchFreshProfile(pubkey: pubkey);
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  Future<void> _onRefreshRequested(
    MyProfileRefreshRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    final currentProfile = _profileFromState(state);
    emit(
      _loadingStateFor(currentProfile, verifiedClaims: _claimsFromState(state)),
    );

    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );
      if (isClosed) return;

      final latestClaims = _claimsFromState(state);
      if (freshProfile != null) {
        emit(
          _loadedStateFor(
            freshProfile,
            isFresh: true,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else if (_profileFromState(state) case final latestProfile?) {
        emit(
          _loadedStateFor(
            latestProfile,
            isFresh: false,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(MyProfileError(errorType: _missingProfileErrorType()));
      }
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      if (isClosed) return;
      final latestClaims = _claimsFromState(state);
      if (_profileFromState(state) case final latestProfile?) {
        emit(
          _loadedStateFor(
            latestProfile,
            isFresh: false,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(const MyProfileError(errorType: MyProfileErrorType.networkError));
      }
    } finally {
      final completer = event.completer;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _onVerifiedClaimsRequested(
    VerifiedClaimsRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    final repo = _identityClaimsRepository;
    if (repo == null) return;

    final current = state;
    final UserProfile profile;
    if (current is MyProfileLoaded) {
      profile = current.profile;
    } else if (current is MyProfileUpdated) {
      profile = current.profile;
    } else {
      return;
    }

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

    // The repository owns the skip-or-verify (stale-while-revalidate) decision;
    // the bloc just renders whatever it resolves to (#3936). The
    // currently-rendered claims ride along so an inconclusive outcome
    // (rate-limited, or the platform couldn't be checked) cannot clear visible
    // chips.
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
    Emitter<MyProfileState> emit,
    String profilePubkey,
    List<IdentityClaim> claims, {
    required bool authoritative,
  }) {
    final latest = state;
    if (latest is MyProfileLoaded && latest.profile.pubkey == profilePubkey) {
      final next = authoritative
          ? claims
          : _withRenderedPreserved(claims, latest.verifiedClaims);
      emit(latest.copyWith(verifiedClaims: next));
    } else if (latest is MyProfileUpdated &&
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

  MyProfileErrorType _missingProfileErrorType() =>
      _profileRepository.isConfirmedMissing(pubkey)
      ? MyProfileErrorType.notFound
      : MyProfileErrorType.networkError;

  UserProfile? _profileFromState(MyProfileState state) {
    final profile = switch (state) {
      MyProfileLoaded(:final profile) => profile,
      MyProfileUpdated(:final profile) => profile,
      MyProfileLoading(:final profile) => profile,
      _ => null,
    };
    return profile?.pubkey == pubkey ? profile : null;
  }

  List<IdentityClaim> _claimsFromState(MyProfileState state) {
    // A null Loading profile just means no cached profile row yet — the
    // carried claims are still this bloc's own-[pubkey] claims, so they
    // must survive the guard.
    final claims = switch (state) {
      MyProfileLoaded(:final profile, :final verifiedClaims) =>
        profile.pubkey == pubkey ? verifiedClaims : const <IdentityClaim>[],
      MyProfileUpdated(:final profile, :final verifiedClaims) =>
        profile.pubkey == pubkey ? verifiedClaims : const <IdentityClaim>[],
      MyProfileLoading(:final profile, :final verifiedClaims) =>
        profile == null || profile.pubkey == pubkey
            ? verifiedClaims
            : const <IdentityClaim>[],
      _ => const <IdentityClaim>[],
    };
    return claims;
  }

  MyProfileLoading _loadingStateFor(
    UserProfile? profile, {
    List<IdentityClaim> verifiedClaims = const [],
  }) => MyProfileLoading(
    profile: profile,
    extractedUsername: profile?.divineUsername,
    externalNip05: profile?.externalNip05,
    verifiedClaims: verifiedClaims,
  );

  MyProfileLoaded _loadedStateFor(
    UserProfile profile, {
    required bool isFresh,
    List<IdentityClaim> verifiedClaims = const [],
  }) => MyProfileLoaded(
    profile: profile,
    isFresh: isFresh,
    extractedUsername: profile.divineUsername,
    externalNip05: profile.externalNip05,
    verifiedClaims: verifiedClaims,
  );
}
