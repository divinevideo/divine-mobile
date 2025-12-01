// ABOUTME: Service for managing age verification status across app sessions
// ABOUTME: Stores verification status using SharedPreferences for persistence

import 'package:flutter/material.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgeVerificationService {
  static const String _ageVerifiedKey = 'age_verified';
  static const String _verificationDateKey = 'age_verification_date';
  static const String _adultContentVerifiedKey = 'adult_content_verified';
  static const String _adultContentVerificationDateKey =
      'adult_content_verification_date';

  bool? _isAgeVerified;
  DateTime? _verificationDate;
  bool? _isAdultContentVerified;
  DateTime? _adultContentVerificationDate;

  bool get isAgeVerified => _isAgeVerified ?? false;
  DateTime? get verificationDate => _verificationDate;
  bool get isAdultContentVerified => _isAdultContentVerified ?? false;
  DateTime? get adultContentVerificationDate => _adultContentVerificationDate;

  Future<void> initialize() async {
    await _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAgeVerified = prefs.getBool(_ageVerifiedKey);
      _isAdultContentVerified = prefs.getBool(_adultContentVerifiedKey);

      final dateMillis = prefs.getInt(_verificationDateKey);
      if (dateMillis != null) {
        _verificationDate = DateTime.fromMillisecondsSinceEpoch(dateMillis);
      }

      final adultDateMillis = prefs.getInt(_adultContentVerificationDateKey);
      if (adultDateMillis != null) {
        _adultContentVerificationDate = DateTime.fromMillisecondsSinceEpoch(
          adultDateMillis,
        );
      }
    } catch (e) {
      Log.error(
        'Error loading age verification status: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> setAgeVerified(bool verified) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_ageVerifiedKey, verified);

      if (verified) {
        final now = DateTime.now();
        await prefs.setInt(_verificationDateKey, now.millisecondsSinceEpoch);
        _verificationDate = now;
      } else {
        await prefs.remove(_verificationDateKey);
        _verificationDate = null;
      }

      _isAgeVerified = verified;

      Log.debug(
        'Age verification status updated: $verified',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
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
    if (_isAgeVerified == null) {
      await _loadVerificationStatus();
    }
    return isAgeVerified;
  }

  Future<void> setAdultContentVerified(bool verified) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_adultContentVerifiedKey, verified);

      if (verified) {
        final now = DateTime.now();
        await prefs.setInt(
          _adultContentVerificationDateKey,
          now.millisecondsSinceEpoch,
        );
        _adultContentVerificationDate = now;
      } else {
        await prefs.remove(_adultContentVerificationDateKey);
        _adultContentVerificationDate = null;
      }

      _isAdultContentVerified = verified;

      Log.debug(
        'Adult content verification status updated: $verified',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
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
    if (_isAdultContentVerified == null) {
      await _loadVerificationStatus();
    }
    return isAdultContentVerified;
  }

  /// Check if user can view adult content, showing verification dialog if needed
  Future<bool> verifyAdultContentAccess(BuildContext context) async {
    // First check if already verified
    if (await checkAdultContentVerification()) {
      return true;
    }

    if (!context.mounted) return false;

    // Show verification dialog
    final verified = await AgeVerificationDialog.show(
      context,
      type: AgeVerificationType.adultContent,
    );

    if (verified) {
      await setAdultContentVerified(true);
      return true;
    }

    return false;
  }

  Future<void> clearVerificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ageVerifiedKey);
      await prefs.remove(_verificationDateKey);
      await prefs.remove(_adultContentVerifiedKey);
      await prefs.remove(_adultContentVerificationDateKey);

      _isAgeVerified = null;
      _verificationDate = null;
      _isAdultContentVerified = null;
      _adultContentVerificationDate = null;

      Log.debug(
        'Age verification status cleared',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error clearing age verification status: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    }
  }
}
