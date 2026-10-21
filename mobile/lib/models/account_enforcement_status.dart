// ABOUTME: Client-side account enforcement state derived from Funnelcake's relay-backed status.
// ABOUTME: Carries no moderation internals: a status and, at most, a closed category.

import 'package:openvine/services/account_status_api_client.dart';

enum AccountEnforcementKind {
  /// There is no signed-in account whose status can be checked.
  signedOut,

  /// Funnelcake successfully reported that the account is active.
  noRestrictionReported,

  /// Reversible: content is hidden, not deleted.
  suspended,

  /// Content has been removed from Divine-operated surfaces.
  banned,

  /// Relay publishing confirmed a restriction whose exact state is unknown.
  ///
  /// This is not used for unknown status API values, which remain indeterminate
  /// because a future value is not necessarily a restriction.
  unknownRestriction;

  bool get isEnforced =>
      this == AccountEnforcementKind.suspended ||
      this == AccountEnforcementKind.banned ||
      this == AccountEnforcementKind.unknownRestriction;
}

/// Why an account is enforced, from a closed set with reviewed copy for each.
///
/// This is not a moderation reason. Each value selects copy the client owns,
/// so nothing stored by a moderator or a rule ever reaches the screen
/// (support-trust-safety#200 R-7).
enum AccountEnforcementCategory {
  /// The account was closed by an age review: a suspected minor who was
  /// denied, or whose parent-consent window ran out (support-trust-safety#260).
  ageReview,
}

/// Enforcement state for the authenticated account, as reported by
/// Funnelcake's self-authenticated status endpoint.
///
/// Deliberately carries no free-text reason or moderation metadata, for two
/// reasons that are worth keeping apart because only the first survives a
/// change of backend:
///
/// 1. Stored moderation reasons are internal operational metadata, not
///    reviewed or localised user copy. Account-level notices describe the
///    state and its effects without rendering that metadata
///    (support-trust-safety#200 R-7).
/// 2. Funnelcake's self-status API happens not to return one today, and asserts
///    that in its own suite. This is why the omission is currently free.
///
/// Reason (2) arrived with the move from Keycast to Funnelcake and reads like
/// the whole story; it is not. Copy is chosen from [kind] and, where set, the
/// closed [category]. See #8304 for the account-level policy decision and
/// `account_status_api_client_test.dart` for the client-side guard.
class AccountEnforcementStatus {
  const AccountEnforcementStatus({required this.kind, this.category});

  factory AccountEnforcementStatus.fromFunnelcake(
    FunnelcakeAccountStatusResponse response,
  ) {
    final kind = switch (response.status) {
      FunnelcakeAccountStatus.active =>
        AccountEnforcementKind.noRestrictionReported,
      FunnelcakeAccountStatus.suspended => AccountEnforcementKind.suspended,
      FunnelcakeAccountStatus.banned => AccountEnforcementKind.banned,
    };
    final category = switch (response.category) {
      FunnelcakeEnforcementCategory.ageReview =>
        AccountEnforcementCategory.ageReview,
      null => null,
    };
    return AccountEnforcementStatus(kind: kind, category: category);
  }

  final AccountEnforcementKind kind;

  /// Null when Funnelcake names no category, including every response from a
  /// Funnelcake that predates the field.
  final AccountEnforcementCategory? category;

  bool get isEnforced => kind.isEnforced;

  /// Whether the account was closed by age review. A suspension in that
  /// category is an open case, which the review screens handle instead.
  ///
  /// A switch over every category, so a new one has to be decided here
  /// before it compiles rather than falling through to the generic ban.
  bool get isAgeReviewClosure => switch (category) {
    AccountEnforcementCategory.ageReview =>
      kind == AccountEnforcementKind.banned,
    null => false,
  };
}
