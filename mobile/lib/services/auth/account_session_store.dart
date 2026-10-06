// ABOUTME: Persists account-session markers and explicit terms acceptance.
// ABOUTME: Keeps preference writes separate from authentication orchestration.

import 'package:clock/clock.dart';
import 'package:openvine/constants/terms_acceptance_keys.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// The identity selected for restoration on the next launch.
const kLastUsedNpubKey = 'last_used_npub';

/// The signed-out identity used to confirm a later account switch.
const kSessionRecoveryAnchorKey = 'session_recovery_anchor_npub';

/// Stores session metadata after account cleanup and legacy-row claiming.
class AccountSessionStore {
  const AccountSessionStore(this._preferences);

  final SharedPreferences _preferences;

  /// Records the activated signer and clears the previous sign-out marker.
  Future<void> recordAuthentication({
    required AuthenticationSource source,
    required String npub,
  }) async {
    await _preferences.setString(kAuthenticationSourceKey, source.code);
    await _preferences.setString(kLastUsedNpubKey, npub);
    await _preferences.remove(kSessionRecoveryAnchorKey);
  }

  /// Records the user's explicit terms acceptance and age verification.
  Future<void> acceptTerms() async {
    Log.debug(
      'acceptTerms: marking terms accepted and age verified',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    await _preferences.setString(
      TermsAcceptanceKeys.termsAcceptedAt,
      clock.now().toIso8601String(),
    );
    await _preferences.setBool(TermsAcceptanceKeys.ageVerified16Plus, true);
  }
}
