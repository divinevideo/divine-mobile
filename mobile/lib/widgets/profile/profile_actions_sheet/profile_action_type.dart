// ABOUTME: Enum representing account and profile actions needing attention.
// ABOUTME: Computes their priority for the signed-in user's profile badge.

/// Account and profile actions that need the signed-in user's attention.
///
/// The [pending] factory returns the ordered list of actions that still
/// need attention. An account restriction always appears first, followed by
/// account recovery, profile completion, and the supporter invitation.
enum ProfileActionType {
  /// Divine has confirmed that this account is restricted.
  accountRestricted,

  /// The user has no email/password and should register to secure their
  /// identity.
  secureAccount,

  /// The user has not yet set a custom display name, bio, or picture.
  completeProfile,

  /// The user is not a supporter yet and is invited to become one.
  becomeSupporter;

  /// Returns the list of pending actions based on the current profile and
  /// auth state.
  ///
  /// [isOwnProfile] — whether we are looking at the logged-in user's profile.
  /// [isAccountEnforced] — whether Divine has confirmed an account restriction.
  /// [isAnonymous] — the user signed in with an auto-generated key (no email).
  /// [hasAnyProfileInfo] — the user has set at least one profile field
  ///   (name, display name, picture, bio, or NIP-05).
  /// [canBecomeSupporter] — the server confirmed this account has no active
  ///   supporter membership.
  static List<ProfileActionType> pending({
    required bool isOwnProfile,
    required bool isAccountEnforced,
    required bool isAnonymous,
    required bool hasAnyProfileInfo,
    required bool canBecomeSupporter,
  }) {
    if (!isOwnProfile) return const [];

    return [
      if (isAccountEnforced) accountRestricted,
      if (isAnonymous) secureAccount,
      if (!hasAnyProfileInfo) completeProfile,
      if (canBecomeSupporter) becomeSupporter,
    ];
  }
}
