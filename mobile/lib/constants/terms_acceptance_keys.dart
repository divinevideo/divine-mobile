// ABOUTME: Storage keys for terms-of-service and age acceptance
// ABOUTME: Declared apart from AuthService so cleanup can reference them

/// Preference keys recording that this account accepted the terms and
/// attested to its age.
///
/// These live here rather than on `AuthService` because they are acceptance
/// state rather than authentication state — and because `AuthService` is a
/// frozen god-file whose line ceiling leaves no room for new declarations.
///
/// Both were previously written as bare literals at five call sites across two
/// files, including the account-switch sweep, with nothing tying the copies
/// together (#8314).
///
/// Not to be confused with [AgeVerificationService]'s own keys, which are
/// account-scoped and near-identically named: `age_verified` there is a
/// different value from `age_verified_16_plus` here.
abstract final class TermsAcceptanceKeys {
  /// Set when the account attests it is over the age threshold.
  static const String ageVerified16Plus = 'age_verified_16_plus';

  /// ISO-8601 timestamp of terms acceptance.
  static const String termsAcceptedAt = 'terms_accepted_at';

  /// Both keys, for callers clearing acceptance wholesale.
  static const List<String> all = [ageVerified16Plus, termsAcceptedAt];
}
