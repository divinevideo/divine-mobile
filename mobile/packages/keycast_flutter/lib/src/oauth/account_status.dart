// ABOUTME: Parsed GET /api/user/account response from Keycast, including the
// ABOUTME: durable approved-minor flag (verified_minor, keycast#263).

/// Account status returned by Keycast's `GET /api/user/account`.
///
/// [verifiedMinor] is the durable approved-minor (13-15) flag, which Keycast
/// sends on every reply; [verifiedMinorReported] says whether this one carried
/// it. [verifiedMinorAt] is set only when the account was flagged.
class KeycastAccountStatus {
  const KeycastAccountStatus({
    required this.email,
    required this.emailVerified,
    required this.publicKey,
    required this.verifiedMinor,
    this.verifiedMinorReported = true,
    this.accountStatus,
    this.suspendedReason,
    this.verifiedMinorAt,
  });

  factory KeycastAccountStatus.fromJson(Map<String, dynamic> json) {
    final verifiedMinorAtRaw = json['verified_minor_at'] as String?;
    final verifiedMinor = json['verified_minor'] as bool?;
    return KeycastAccountStatus(
      email: json['email'] as String? ?? '',
      emailVerified: json['email_verified'] as bool? ?? false,
      publicKey: json['public_key'] as String? ?? '',
      accountStatus: json['account_status'] as String?,
      suspendedReason: json['suspended_reason'] as String?,
      verifiedMinor: verifiedMinor ?? false,
      verifiedMinorReported: verifiedMinor != null,
      verifiedMinorAt: verifiedMinorAtRaw == null
          ? null
          : DateTime.tryParse(verifiedMinorAtRaw),
    );
  }

  final String email;
  final bool emailVerified;
  final String publicKey;

  /// Present only when the account is not active (suspended/banned/etc.).
  final String? accountStatus;

  /// Keycast's internal reason for a non-active status. **Deliberately not
  /// consumed anywhere, and not safe to render to the user.**
  ///
  /// This is operational metadata, not reviewed or localised user copy. The
  /// account-level policy deliberately derives copy from the enforcement state
  /// and its effects rather than from any stored reason field.
  ///
  /// It is also not the enforcement authority: divine-mobile reads account
  /// status from Funnelcake, not from here. Parsed only so this model matches
  /// the whole `GET /api/user/account` payload.
  ///
  /// #8304 records that account-level notices do not expose a stored reason.
  /// Any separately approved content-level explanation will use a closed
  /// category with reviewed copy, not this field.
  final String? suspendedReason;

  /// Durable approved-minor (13-15) flag. Independent of [accountStatus] —
  /// an approved minor is active, so this can be true on a normal account.
  ///
  /// Reads `false` when the reply did not carry the flag; check
  /// [verifiedMinorReported] before treating `false` as a confirmed answer.
  final bool verifiedMinor;

  /// Whether the reply carried an explicit boolean `verified_minor`.
  final bool verifiedMinorReported;
  final DateTime? verifiedMinorAt;
}
