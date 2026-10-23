import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's appearance choice on the current device.
class AppearanceRepository {
  AppearanceRepository(
    this._preferences, {
    AccountPreferenceStore? accountPreferences,
  }) : _accountPreferences = accountPreferences;
  final AccountPreferenceStore? _accountPreferences;
  Stream<void>? get changes => _accountPreferences?.changes;

  static const preferenceKey = 'appearance_mode_preference';

  final SharedPreferences _preferences;

  Future<AppearanceMode> load() async {
    final storedValue = (_accountPreferences == null
        ? _preferences.getString(preferenceKey)
        : _accountPreferences.read(preferenceKey));
    return AppearanceMode.values.firstWhere(
      (mode) => mode.name == storedValue,
      orElse: () => defaultAppearanceMode,
    );
  }

  Future<void> save(AppearanceMode mode) async {
    if (_accountPreferences != null) {
      await _accountPreferences.write(preferenceKey, mode.name);
      return;
    }
    final saved = await _preferences.setString(preferenceKey, mode.name);
    if (!saved) {
      throw StateError('Unable to persist appearance preference');
    }
  }
}
