// ABOUTME: Manages app environment (poc/staging/production/local) with persistence
// ABOUTME: Handles developer mode unlock and environment switching

import 'package:flutter/foundation.dart';
import 'package:nostr_client/nostr_client.dart'
    show SharedPreferencesRelayStorage;
import 'package:openvine/models/environment_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app environment configuration
class EnvironmentService extends ChangeNotifier {
  static const _keyDeveloperMode = 'developer_mode_enabled';
  static const _keyEnvironment = 'app_environment';

  // Initialization is asynchronous, and null represents the valid
  // pre-initialize state guarded by _ensureInitialized.
  // ignore: use_late_for_private_fields_and_variables
  SharedPreferences? _prefs;
  bool _developerModeEnabled = false;
  EnvironmentConfig _currentConfig = EnvironmentConfig.production;
  bool _initialized = false;

  /// Whether developer mode has been unlocked
  bool get isDeveloperModeEnabled => _developerModeEnabled;

  /// Current environment configuration
  EnvironmentConfig get currentConfig => _currentConfig;

  /// Whether service has been initialized
  bool get isInitialized => _initialized;

  /// Initialize the service and load persisted state
  Future<void> initialize({SharedPreferences? sharedPreferences}) async {
    if (_initialized) return;

    _prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    _developerModeEnabled = _prefs!.getBool(_keyDeveloperMode) ?? false;

    final envString = _prefs!.getString(_keyEnvironment);
    final environment = _parseEnvironment(envString);

    _currentConfig = EnvironmentConfig(environment: environment);

    _initialized = true;
    notifyListeners();
  }

  /// Enable developer mode (called after 7 taps on version)
  Future<void> enableDeveloperMode() async {
    _ensureInitialized();
    _developerModeEnabled = true;
    await _prefs!.setBool(_keyDeveloperMode, true);
    notifyListeners();
  }

  /// Disable developer mode (hides the developer options entry point).
  ///
  /// Reversible via [enableDeveloperMode] (7 taps on the version label).
  Future<void> disableDeveloperMode() async {
    _ensureInitialized();
    _developerModeEnabled = false;
    await _prefs!.setBool(_keyDeveloperMode, false);
    notifyListeners();
  }

  /// Set the app environment
  Future<void> setEnvironment(AppEnvironment environment) async {
    _ensureInitialized();

    _currentConfig = EnvironmentConfig(environment: environment);

    await _prefs!.setString(_keyEnvironment, environment.name);

    // Clear persisted relay state so new environment starts fresh with its
    // default and does not inherit user-removal intent from another relay set.
    await _prefs!.remove(SharedPreferencesRelayStorage.defaultKey);
    await _prefs!.remove(SharedPreferencesRelayStorage.defaultRemovedRelaysKey);

    notifyListeners();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('EnvironmentService must be initialized first');
    }
  }

  AppEnvironment _parseEnvironment(String? value) {
    if (value == null) return buildTimeDefaultEnvironment;
    return AppEnvironment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => buildTimeDefaultEnvironment,
    );
  }
}
