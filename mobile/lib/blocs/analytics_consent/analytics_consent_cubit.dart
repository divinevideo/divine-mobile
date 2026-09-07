// ABOUTME: Cubit backing the analytics consent toggle in PrivacySettingsScreen.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/analytics_consent/analytics_consent_state.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/analytics_service.dart';

/// Cubit backing the `_AnalyticsConsentToggle` tile in
/// `PrivacySettingsScreen`.
///
/// Owns the single user-facing call site for
/// [AnalyticsService.setAnalyticsEnabled] (#7982). Withdrawal side effects —
/// clearing the queued first-party events and the campaign values, rotating
/// the anonymous identity — belong to the service and are not repeated here.
class AnalyticsConsentCubit extends Cubit<AnalyticsConsentState>
    with CloseGuardedEmit<AnalyticsConsentState> {
  AnalyticsConsentCubit({required AnalyticsService service})
    : _service = service,
      super(const AnalyticsConsentState());

  final AnalyticsService _service;

  /// Reads the persisted preference into the tile.
  ///
  /// `analyticsEnabled` reports the pre-load default until the service has
  /// read SharedPreferences, so a stored opt-out would otherwise render as
  /// consent. `initialize()` is idempotent, so awaiting it here joins the run
  /// the provider already started instead of starting a second one.
  Future<void> load() async {
    await _service.initialize();
    emitIfOpen(
      state.copyWith(
        status: AnalyticsConsentStatus.ready,
        isEnabled: _service.analyticsEnabled,
      ),
    );
  }

  /// Records the user's consent decision and persists it.
  ///
  /// The tile renders what the service reports afterwards, never the value the
  /// switch was moved to: a write the platform rejected leaves consent where it
  /// was, and echoing the requested value would tell the person their choice
  /// had been saved when it had not.
  Future<void> setEnabled(bool value) async {
    emitIfOpen(
      state.copyWith(saveStatus: AnalyticsConsentSaveStatus.saving),
    );
    final persisted = await _service.setAnalyticsEnabled(value);
    emitIfOpen(
      state.copyWith(
        isEnabled: _service.analyticsEnabled,
        saveStatus: persisted
            ? AnalyticsConsentSaveStatus.idle
            : AnalyticsConsentSaveStatus.failure,
      ),
    );
  }
}
