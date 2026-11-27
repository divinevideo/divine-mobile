// ABOUTME: Non-blocking protected-minor (13-15) state derived from Keycast's
// ABOUTME: verified_minor flag. Distinct from the blocking minor-review gate.

import 'package:keycast_flutter/keycast_flutter.dart';

enum ProtectedMinorStatusKind {
  unknown,
  notProtected,
  protected,
}

/// Client-side "protected minor" state for an approved 13-15 account.
///
/// This is deliberately separate from [AccountRestrictionStatus] /
/// `MinorAccountReviewStatus`, which drive the *blocking* under-review gate.
/// A protected minor may use the app; the content-lock and DM-restriction
/// protections (#175/#176) consume this state.
class ProtectedMinorStatus {
  const ProtectedMinorStatus({
    required this.kind,
    this.verifiedMinorAt,
  });

  factory ProtectedMinorStatus.unknown() =>
      const ProtectedMinorStatus(kind: ProtectedMinorStatusKind.unknown);

  factory ProtectedMinorStatus.notProtected() =>
      const ProtectedMinorStatus(kind: ProtectedMinorStatusKind.notProtected);

  factory ProtectedMinorStatus.protected({DateTime? verifiedMinorAt}) =>
      ProtectedMinorStatus(
        kind: ProtectedMinorStatusKind.protected,
        verifiedMinorAt: verifiedMinorAt,
      );

  /// Maps an explicit Keycast verdict to protected-minor state. Missing or
  /// unavailable verdicts stay unknown so enforcement retains its fallback.
  factory ProtectedMinorStatus.fromKeycast(KeycastAccountStatus? status) {
    if (status == null || !status.verifiedMinorReported) {
      return ProtectedMinorStatus.unknown();
    }
    if (!status.verifiedMinor) {
      return ProtectedMinorStatus.notProtected();
    }
    return ProtectedMinorStatus.protected(
      verifiedMinorAt: status.verifiedMinorAt,
    );
  }

  final ProtectedMinorStatusKind kind;
  final DateTime? verifiedMinorAt;

  /// An explicit Keycast answer that the account is not a protected minor.
  bool get isConfirmedNotProtected =>
      kind == ProtectedMinorStatusKind.notProtected;

  bool get isProtectedMinor => kind == ProtectedMinorStatusKind.protected;
  bool get isKnown => kind != ProtectedMinorStatusKind.unknown;
}
