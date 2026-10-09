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

/// Exact session slots needed to undo a switch; other accounts stay untouched.
class AccountSessionSnapshot {
  AccountSessionSnapshot._(this._values);

  static const List<String> _keys = [
    'current_user_pubkey_hex',
    kAuthenticationSourceKey,
    kLastUsedNpubKey,
    kSessionRecoveryAnchorKey,
  ];
  final Map<String, String?> _values;

  factory AccountSessionSnapshot.capture(SharedPreferences prefs) =>
      AccountSessionSnapshot._({
        for (final key in _keys) key: prefs.getString(key),
      });

  Future<void> restore(
    SharedPreferences prefs, {
    required void Function() ensureCurrent,
  }) async {
    for (final entry in _values.entries) {
      ensureCurrent();
      final value = entry.value;
      final restored = value == null
          ? await prefs.remove(entry.key)
          : await prefs.setString(entry.key, value);
      ensureCurrent();
      if (!restored) throw StateError('Could not restore the outgoing session');
    }
    await prefs.reload();
    ensureCurrent();
    if (_values.entries.any((entry) => prefs.get(entry.key) != entry.value)) {
      throw StateError('Outgoing session readback did not match');
    }
  }
}

/// Stores session metadata after account cleanup and legacy-row claiming.
class AccountSessionStore {
  const AccountSessionStore(this._preferences);

  final SharedPreferences _preferences;

  /// Records the activated signer and clears the previous sign-out marker.
  Future<void> recordAuthentication({
    required AuthenticationSource source,
    required String npub,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    final sourceWritten = await _preferences.setString(
      kAuthenticationSourceKey,
      source.code,
    );
    ensureCurrent?.call();
    if (!sourceWritten) {
      throw StateError('Could not persist authentication source');
    }
    final identityWritten = await _preferences.setString(
      kLastUsedNpubKey,
      npub,
    );
    ensureCurrent?.call();
    if (!identityWritten) {
      throw StateError('Could not persist restoration identity');
    }
    final anchorRemoved = await _preferences.remove(kSessionRecoveryAnchorKey);
    ensureCurrent?.call();
    if (!anchorRemoved) throw StateError('Could not clear the recovery anchor');
    await _preferences.reload();
    ensureCurrent?.call();
    if (_preferences.getString(kAuthenticationSourceKey) != source.code ||
        _preferences.getString(kLastUsedNpubKey) != npub ||
        _preferences.containsKey(kSessionRecoveryAnchorKey)) {
      throw StateError('Authentication metadata readback did not match');
    }
  }

  /// Records the user's explicit terms acceptance and age verification.
  Future<void> acceptTerms({void Function()? ensureCurrent}) async {
    Log.debug(
      'acceptTerms: marking terms accepted and age verified',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    ensureCurrent?.call();
    final acceptedAt = clock.now().toIso8601String();
    final accepted = await _preferences.setString(
      TermsAcceptanceKeys.termsAcceptedAt,
      acceptedAt,
    );
    ensureCurrent?.call();
    if (!accepted) throw StateError('Could not persist terms acceptance');
    final verified = await _preferences.setBool(
      TermsAcceptanceKeys.ageVerified16Plus,
      true,
    );
    ensureCurrent?.call();
    if (!verified) throw StateError('Could not persist age verification');
    await _preferences.reload();
    ensureCurrent?.call();
    if (_preferences.getString(TermsAcceptanceKeys.termsAcceptedAt) !=
            acceptedAt ||
        _preferences.getBool(TermsAcceptanceKeys.ageVerified16Plus) != true) {
      throw StateError('Terms acceptance readback did not match');
    }
  }
}
