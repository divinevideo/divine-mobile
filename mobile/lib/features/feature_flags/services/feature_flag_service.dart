// ABOUTME: Core feature flag service managing flag state and persistence
import 'package:flutter/foundation.dart'; // ABOUTME: Handles initialization, flag management, and state notifications with SharedPreferences
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/models/feature_flag_state.dart';
import 'package:openvine/features/feature_flags/models/flag_metadata.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service managing feature flag state with change notifications for Riverpod reactivity
class FeatureFlagService extends ChangeNotifier {
  FeatureFlagService(
    this._prefs,
    this._buildConfig, {
    bool Function()? canOverrideInternalFlags,
  }) : _canOverrideInternalFlags = canOverrideInternalFlags ?? _denyInternal {
    _initializeWithDefaults();
  }

  final SharedPreferences _prefs;
  final BuildConfiguration _buildConfig;
  final bool Function() _canOverrideInternalFlags;
  late FeatureFlagState _currentState;

  bool _defaultValue(FeatureFlag flag) =>
      isAvailable(flag) && _buildConfig.getDefault(flag);

  bool isAvailable(FeatureFlag flag) =>
      flag != FeatureFlag.minorConsentInAppRecording ||
      _buildConfig.consentDeliveryVerified;

  static bool _denyInternal() => false;

  /// Initialize with build defaults (called in constructor)
  void _initializeWithDefaults() {
    final flags = <FeatureFlag, bool>{};
    for (final flag in FeatureFlag.values) {
      flags[flag] = _defaultValue(flag);
    }
    _currentState = FeatureFlagState(flags);
  }

  /// Initialize the service by loading persisted flag values
  ///
  /// A persisted override for an internal flag is ignored, not deleted, while
  /// internal access is off — so the user's choice is honoured again if the
  /// flag is later promoted back to [FeatureFlagAudience.user] or internal
  /// access is restored.
  Future<void> initialize() async {
    final flags = <FeatureFlag, bool>{};

    for (final flag in FeatureFlag.values) {
      final savedValue = _prefs.getBool(_getPreferenceKey(flag));

      flags[flag] = _canUsePersistedOverride(flag, savedValue)
          ? savedValue!
          : _defaultValue(flag);
    }

    _currentState = FeatureFlagState(flags);
    notifyListeners();
  }

  /// Check if a feature flag is enabled
  bool isEnabled(FeatureFlag flag) {
    return isAvailable(flag) && _currentState.isEnabled(flag);
  }

  /// Set a feature flag value and persist it
  ///
  /// Internal flags are read-only without internal access: the flag resolves
  /// back to its build default and nothing is written or removed.
  Future<void> setFlag(FeatureFlag flag, bool value) async {
    if (!_canOverrideFlag(flag)) {
      _currentState = _currentState.copyWith(
        flag,
        _defaultValue(flag),
      );
      notifyListeners();
      return;
    }

    final key = _getPreferenceKey(flag);

    try {
      await _prefs.setBool(key, value);

      _currentState = _currentState.copyWith(flag, value);
      notifyListeners();
    } catch (e) {
      // Handle storage errors gracefully - log and continue
      Log.warning(
        'Failed to persist feature flag $flag: $e',
        name: 'FeatureFlagService',
        category: LogCategory.system,
      );
      // Still update in-memory state even if persistence fails
      _currentState = _currentState.copyWith(flag, value);
      notifyListeners();
    }
  }

  /// Reset a flag to its build default value
  Future<void> resetFlag(FeatureFlag flag) async {
    final key = _getPreferenceKey(flag);

    try {
      await _prefs.remove(key);

      final defaultValue = _defaultValue(flag);
      _currentState = _currentState.copyWith(flag, defaultValue);
      notifyListeners();
    } catch (e) {
      // Handle storage errors gracefully - log and continue
      Log.warning(
        'Failed to reset feature flag $flag: $e',
        name: 'FeatureFlagService',
        category: LogCategory.system,
      );
      // Still update in-memory state even if persistence fails
      final defaultValue = _defaultValue(flag);
      _currentState = _currentState.copyWith(flag, defaultValue);
      notifyListeners();
    }
  }

  /// Reset all flags to their build default values
  Future<void> resetAllFlags() async {
    final flags = <FeatureFlag, bool>{};

    for (final flag in FeatureFlag.values) {
      if (_canOverrideFlag(flag)) {
        final key = _getPreferenceKey(flag);
        try {
          await _prefs.remove(key);
        } catch (e) {
          // Handle storage errors gracefully - log and continue
          Log.warning(
            'Failed to reset feature flag $flag: $e',
            name: 'FeatureFlagService',
            category: LogCategory.system,
          );
        }
      }
      flags[flag] = _defaultValue(flag);
    }

    _currentState = FeatureFlagState(flags);
    notifyListeners();
  }

  /// Check if a flag has a user override (is different from build default)
  ///
  /// Always false for an internal flag without internal access: any persisted
  /// value is retained on disk but not applied.
  bool hasUserOverride(FeatureFlag flag) {
    if (!_canOverrideFlag(flag)) return false;

    final key = _getPreferenceKey(flag);
    return _prefs.containsKey(key);
  }

  /// Get comprehensive metadata for a flag
  FlagMetadata getFlagMetadata(FeatureFlag flag) {
    return FlagMetadata(
      flag: flag,
      isEnabled: isEnabled(flag),
      hasUserOverride: hasUserOverride(flag),
      buildDefault: _defaultValue(flag),
    );
  }

  /// Get the current state of all flags
  FeatureFlagState get currentState => _currentState;

  /// Generate preference key for a flag
  String _getPreferenceKey(FeatureFlag flag) {
    return 'ff_${flag.name}';
  }

  bool _canUsePersistedOverride(FeatureFlag flag, bool? savedValue) {
    if (savedValue == null) return false;
    return _canOverrideFlag(flag);
  }

  bool _canOverrideFlag(FeatureFlag flag) {
    return isAvailable(flag) &&
        (!flag.isInternal || _canOverrideInternalFlags());
  }
}
