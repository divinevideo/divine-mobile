// ABOUTME: Service for managing age verification status across app sessions
// ABOUTME: Stores verification status per account in SharedPreferences

import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class AgeVerificationService {
  AgeVerificationService({
    required SharedPreferences preferences,
    bool Function()? isProtectedMinor,
    String? Function()? currentPubkeyHex,
    Future<void> Function()? onAdultMediaAccessRevoked,
    VoidCallback? onAdultContentVerificationChanged,
  }) : _preferences = preferences,
       _isProtectedMinor = isProtectedMinor ?? _notProtected,
       _currentPubkeyHex = currentPubkeyHex ?? _noPubkey,
       _onAdultMediaAccessRevoked = onAdultMediaAccessRevoked,
       _onAdultContentVerificationChanged = onAdultContentVerificationChanged;

  static bool _notProtected() => false;
  static String? _noPubkey() => null;

  final SharedPreferences _preferences;

  /// Whether the current account is a protected minor. When true, adult content
  /// is force-locked off and the self-attestation bypass is unavailable (#175).
  final bool Function() _isProtectedMinor;

  /// The active account's pubkey hex, or null when unauthenticated.
  /// Verification is scoped per account (#7816); a null pubkey resolves to
  /// unverified and makes writes a no-op.
  final String? Function() _currentPubkeyHex;

  final Future<void> Function()? _onAdultMediaAccessRevoked;
  final VoidCallback? _onAdultContentVerificationChanged;

  static const String _ageVerifiedKey = 'age_verified';
  static const String _verificationDateKey = 'age_verification_date';
  static const String _adultContentVerifiedKey = 'adult_content_verified';
  static const String _adultContentVerificationDateKey =
      'adult_content_verification_date';

  /// Legacy device-global keys, pre-#7816. Their account ownership cannot be
  /// recovered safely, so they are deleted during initialization.
  static const List<String> _globalBaseKeys = [
    _ageVerifiedKey,
    _verificationDateKey,
    _adultContentVerifiedKey,
    _adultContentVerificationDateKey,
  ];

  /// Every per-account preference key for [pubkeyHex].
  static List<String> accountKeys(String pubkeyHex) =>
      _globalBaseKeys.map((base) => '${base}_$pubkeyHex').toList();

  Future<void>? _initializeFuture;

  bool get isAgeVerified => _readBool(_ageVerifiedKey);

  DateTime? get verificationDate => _readDate(_verificationDateKey);

  bool get isAdultContentVerified =>
      !_isProtectedMinor() && _readBool(_adultContentVerifiedKey);

  DateTime? get adultContentVerificationDate =>
      _readDate(_adultContentVerificationDateKey);

  /// Completes after unsafe legacy device-global verification has been removed.
  Future<void> get initialized => _initializeFuture ??= _initialize();

  /// The scoped key for [base] under the active account, or null when no
  /// account is active.
  static String? _scopedKey(String base, String? pubkey) {
    if (pubkey == null || pubkey.isEmpty) return null;
    return '${base}_$pubkey';
  }

  bool _readBool(String base) {
    final key = _scopedKey(base, _currentPubkeyHex());
    return key != null && (_preferences.getBool(key) ?? false);
  }

  DateTime? _readDate(String base) {
    final key = _scopedKey(base, _currentPubkeyHex());
    final millis = key == null ? null : _preferences.getInt(key);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _initialize() async {
    for (final base in _globalBaseKeys) {
      await _preferences.remove(base);
    }
    _onAdultContentVerificationChanged?.call();
  }

  Future<void> initialize() => initialized;

  Future<bool> setAgeVerified(bool verified) async {
    try {
      final written = await _writeVerification(
        verified: verified,
        valueBase: _ageVerifiedKey,
        dateBase: _verificationDateKey,
      );
      if (!written) return false;

      Log.debug(
        'Age verification status updated: $verified',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.error(
        'Error saving age verification status: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  Future<bool> checkAgeVerification() async {
    await initialized;
    return isAgeVerified;
  }

  Future<bool> setAdultContentVerified(bool verified) async {
    if (verified && _isProtectedMinor()) {
      Log.warning(
        'Blocked adult-content verification for a protected minor',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      return false;
    }
    try {
      final written = await _writeVerification(
        verified: verified,
        valueBase: _adultContentVerifiedKey,
        dateBase: _adultContentVerificationDateKey,
      );
      if (!written) return false;
      _onAdultContentVerificationChanged?.call();
      if (!verified) {
        await _notifyAdultMediaAccessRevoked();
      }

      Log.debug(
        'Adult content verification status updated: $verified',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.error(
        'Error saving adult content verification status: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  Future<bool> checkAdultContentVerification() async {
    await initialized;
    return isAdultContentVerified;
  }

  Future<bool> _writeVerification({
    required bool verified,
    required String valueBase,
    required String dateBase,
  }) async {
    final pubkey = _currentPubkeyHex();
    final valueKey = _scopedKey(valueBase, pubkey);
    final dateKey = _scopedKey(dateBase, pubkey);
    if (valueKey == null || dateKey == null) {
      Log.warning(
        'No active account; skipping verification write',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      return false;
    }

    final previousValue = _preferences.getBool(valueKey);
    final previousDate = _preferences.getInt(dateKey);
    await _preferences.setBool(valueKey, verified);
    if (verified) {
      await _preferences.setInt(dateKey, DateTime.now().millisecondsSinceEpoch);
    } else {
      await _preferences.remove(dateKey);
    }

    if (_currentPubkeyHex() == pubkey) return true;

    await _restoreBool(valueKey, previousValue);
    await _restoreInt(dateKey, previousDate);
    return false;
  }

  Future<void> _restoreBool(String key, bool? value) => value == null
      ? _preferences.remove(key)
      : _preferences.setBool(key, value);

  Future<void> _restoreInt(String key, int? value) => value == null
      ? _preferences.remove(key)
      : _preferences.setInt(key, value);

  /// Check if user can view adult content, showing verification dialog if needed
  Future<bool> verifyAdultContentAccess(BuildContext context) async {
    // Protected minors can never unlock adult content; no dialog.
    if (_isProtectedMinor()) return false;
    // First check if already verified
    if (await checkAdultContentVerification()) {
      return true;
    }

    if (!context.mounted) return false;

    // Show verification dialog
    final pubkey = _currentPubkeyHex();
    if (pubkey == null || pubkey.isEmpty) return false;
    final verified = await AgeVerificationDialog.show(
      context,
      type: AgeVerificationType.adultContent,
    );

    if (verified && _currentPubkeyHex() == pubkey) {
      return setAdultContentVerified(true);
    }

    return false;
  }

  Future<void> _notifyAdultMediaAccessRevoked() async {
    final callback = _onAdultMediaAccessRevoked;
    if (callback == null) return;
    try {
      await callback();
    } catch (e) {
      Log.error(
        'Error clearing adult media access caches: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    }
  }
}
