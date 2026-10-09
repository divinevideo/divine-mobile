// ABOUTME: States for MyProfileBloc - loading own profile for editing
// ABOUTME: Supports cache+fresh pattern with extracted divine.video username

part of 'my_profile_bloc.dart';

/// Error types for my profile loading operations.
enum MyProfileErrorType {
  /// Profile does not exist on relay or in cache.
  notFound,

  /// Network or relay error occurred.
  networkError,
}

/// Base class for all my profile states.
sealed class MyProfileState extends Equatable {
  const MyProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any profile loading has started.
final class MyProfileInitial extends MyProfileState {
  const MyProfileInitial();
}

/// Loading state - may contain cached profile while fetching fresh.
final class MyProfileLoading extends MyProfileState {
  const MyProfileLoading({
    this.profile,
    this.extractedUsername,
    this.externalNip05,
    this.verifiedClaims = const [],
  });

  /// Cached profile to display while loading fresh data.
  /// Null if no cached profile exists.
  final UserProfile? profile;

  /// Username extracted from cached profile's NIP-05, if available.
  final String? extractedUsername;

  /// External NIP-05 identifier from cached profile (e.g., `alice@example.com`).
  /// Null if the NIP-05 is a divine.video/openvine.co domain or not set.
  final String? externalNip05;

  /// Verifier-confirmed NIP-39 identity claims from the previously visible
  /// profile. Preserved during refresh so the row does not disappear while the
  /// verifier revalidates.
  final List<IdentityClaim> verifiedClaims;

  @override
  List<Object?> get props => [
    profile,
    extractedUsername,
    externalNip05,
    verifiedClaims,
  ];
}

/// Successfully loaded profile state.
final class MyProfileLoaded extends MyProfileState {
  const MyProfileLoaded({
    required this.profile,
    required this.isFresh,
    this.extractedUsername,
    this.externalNip05,
    this.verifiedClaims = const [],
  });

  /// The loaded user profile.
  final UserProfile profile;

  /// Whether this profile was freshly fetched from relay (true)
  /// or loaded from cache (false).
  final bool isFresh;

  /// Username extracted from the profile's NIP-05 identifier.
  ///
  /// Supports both new subdomain format (`_@username.divine.video`)
  /// and legacy formats (`username@divine.video`, `username@openvine.co`).
  /// Null if the NIP-05 is not from a recognized domain.
  final String? extractedUsername;

  /// External NIP-05 identifier (e.g., `alice@example.com`).
  /// Null if the NIP-05 is a divine.video/openvine.co domain or not set.
  final String? externalNip05;

  /// Verifier-confirmed NIP-39 identity claims for this profile. Carried over
  /// from the previous state while [VerifiedClaimsRequested] revalidates; kept
  /// at last-known-good when the verifier fails, rate-limits or can't check the
  /// platform, and cleared only by a confirmed negative resolve or the claim's
  /// removal.
  final List<IdentityClaim> verifiedClaims;

  /// Returns a copy of this state with the given fields replaced.
  MyProfileLoaded copyWith({List<IdentityClaim>? verifiedClaims}) =>
      MyProfileLoaded(
        profile: profile,
        isFresh: isFresh,
        extractedUsername: extractedUsername,
        externalNip05: externalNip05,
        verifiedClaims: verifiedClaims ?? this.verifiedClaims,
      );

  @override
  List<Object?> get props => [
    profile,
    isFresh,
    extractedUsername,
    externalNip05,
    verifiedClaims,
  ];
}

/// Profile updated via stream subscription.
///
/// Emitted by [MyProfileSubscriptionRequested] whenever the local DB
/// row changes. No `isFresh` flag — the stream always reflects the
/// latest DB state regardless of who wrote it.
final class MyProfileUpdated extends MyProfileState {
  const MyProfileUpdated({
    required this.profile,
    this.extractedUsername,
    this.externalNip05,
    this.verifiedClaims = const [],
  });

  /// The current user profile from the local database.
  final UserProfile profile;

  /// Username extracted from the profile's NIP-05 identifier.
  final String? extractedUsername;

  /// External NIP-05 identifier (e.g., `alice@example.com`).
  final String? externalNip05;

  /// Verifier-confirmed NIP-39 identity claims for this profile.
  final List<IdentityClaim> verifiedClaims;

  /// Returns a copy of this state with the given fields replaced.
  MyProfileUpdated copyWith({List<IdentityClaim>? verifiedClaims}) =>
      MyProfileUpdated(
        profile: profile,
        extractedUsername: extractedUsername,
        externalNip05: externalNip05,
        verifiedClaims: verifiedClaims ?? this.verifiedClaims,
      );

  @override
  List<Object?> get props => [
    profile,
    extractedUsername,
    externalNip05,
    verifiedClaims,
  ];
}

/// Error state when profile loading fails.
final class MyProfileError extends MyProfileState {
  const MyProfileError({required this.errorType});

  /// The type of error that occurred.
  final MyProfileErrorType errorType;

  @override
  List<Object?> get props => [errorType];
}
