// ABOUTME: Enum representing account and profile actions needing attention.
// ABOUTME: Computes their priority for the signed-in user's profile badge.

/// Account and profile actions that need the signed-in user's attention.
///
/// The [pending] factory returns the ordered list of actions that still
/// need attention. An account restriction always appears first, followed by
/// email confirmation, account recovery, profile completion, and the
/// supporter invitation.
enum ProfileActionType {
  /// Divine has confirmed that this account is restricted.
  accountRestricted,

  /// The user signed in before confirming their email address.
  confirmEmail,

  /// The user has no email/password and should register to secure their
  /// identity.
  secureAccount,

  /// The user has not yet set a custom display name, bio, or picture.
  completeProfile,

  /// The account has no active supporter membership and is invited to join.
  becomeSupporter;

  /// Returns the list of pending actions based on the current profile, auth
  /// and membership state.
  ///
  /// [isOwnProfile] — whether we are looking at the logged-in user's profile.
  /// [isAccountEnforced] — whether Divine has confirmed an account restriction.
  /// [isEmailUnconfirmed] — the account's email still awaits confirmation.
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
    bool isEmailUnconfirmed = false,
  }) {
    if (!isOwnProfile) return const [];

    return [
      if (isAccountEnforced) accountRestricted,
      if (isEmailUnconfirmed) confirmEmail,
      if (isAnonymous) secureAccount,
      if (!hasAnyProfileInfo) completeProfile,
      if (canBecomeSupporter) becomeSupporter,
    ];
  }
}
