// ABOUTME: States for OtherProfileBloc - viewing another user's profile
// ABOUTME: Supports cache+fresh pattern with optional profile in loading/error states

part of 'other_profile_bloc.dart';

/// Error types for profile fetching operations.
enum OtherProfileErrorType {
  /// Profile does not exist on relay or in cache.
  notFound,

  /// Network or relay error occurred.
  networkError,
}

/// Base class for all other profile states.
sealed class OtherProfileState extends Equatable {
  const OtherProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any profile loading has started.
final class OtherProfileInitial extends OtherProfileState {
  const OtherProfileInitial();
}

/// Loading state - may contain cached profile while fetching fresh.
final class OtherProfileLoading extends OtherProfileState {
  const OtherProfileLoading({this.profile, this.verifiedClaims = const []});

  /// Cached profile to display while loading fresh data.
  /// Null if no cached profile exists.
  final UserProfile? profile;

  /// Claims carried over from the previous state so chips do not vanish
  /// during a refresh (#3936).
  final List<IdentityClaim> verifiedClaims;

  @override
  List<Object?> get props => [profile, verifiedClaims];
}

/// Successfully loaded profile state.
final class OtherProfileLoaded extends OtherProfileState {
  const OtherProfileLoaded({
    required this.profile,
    required this.isFresh,
    this.verifiedClaims = const [],
  });

  /// The loaded user profile.
  final UserProfile profile;

  /// Whether this profile was freshly fetched from relay (true)
  /// or loaded from cache (false).
  final bool isFresh;

  /// Verifier-confirmed NIP-39 identity claims for this profile. Carried over
  /// from the previous state while [VerifiedClaimsRequested] revalidates; kept
  /// at last-known-good when the verifier fails, rate-limits or can't check the
  /// platform, and cleared only by a confirmed negative resolve or the claim's
  /// removal.
  final List<IdentityClaim> verifiedClaims;

  /// Returns a copy of this state with the given fields replaced.
  OtherProfileLoaded copyWith({List<IdentityClaim>? verifiedClaims}) =>
      OtherProfileLoaded(
        profile: profile,
        isFresh: isFresh,
        verifiedClaims: verifiedClaims ?? this.verifiedClaims,
      );

  @override
  List<Object?> get props => [profile, isFresh, verifiedClaims];
}

/// Error state - may still contain cached profile to display.
final class OtherProfileError extends OtherProfileState {
  const OtherProfileError({required this.errorType, this.profile});

  /// The type of error that occurred.
  final OtherProfileErrorType errorType;

  /// Cached profile to display despite the error.
  /// Null if no cached profile exists.
  final UserProfile? profile;

  @override
  List<Object?> get props => [errorType, profile];
}
