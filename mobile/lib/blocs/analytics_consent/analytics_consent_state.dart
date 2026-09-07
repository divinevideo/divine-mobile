// ABOUTME: State for AnalyticsConsentCubit — the analytics consent preference.

import 'package:equatable/equatable.dart';

/// Load lifecycle of the analytics consent tile.
///
/// The stored preference only reaches `AnalyticsService` once it has read
/// SharedPreferences, so the tile stays [loading] until then rather than
/// showing the pre-load default as if it were the user's answer.
enum AnalyticsConsentStatus { loading, ready }

/// Outcome of the most recent write.
///
/// A consent switch is a promise about the next launch, so a write that did
/// not reach storage cannot render as success. [failure] drives that message;
/// it is not a load state, so the tile stays interactive and the person can
/// try again.
enum AnalyticsConsentSaveStatus { idle, saving, failure }

/// State for `AnalyticsConsentCubit`.
class AnalyticsConsentState extends Equatable {
  const AnalyticsConsentState({
    this.status = AnalyticsConsentStatus.loading,
    this.saveStatus = AnalyticsConsentSaveStatus.idle,
    this.isEnabled = false,
  });

  final AnalyticsConsentStatus status;
  final AnalyticsConsentSaveStatus saveStatus;

  /// The decision actually in force, read back from the service rather than
  /// echoed from the switch, so a rejected write cannot render as accepted.
  final bool isEnabled;

  AnalyticsConsentState copyWith({
    AnalyticsConsentStatus? status,
    AnalyticsConsentSaveStatus? saveStatus,
    bool? isEnabled,
  }) {
    return AnalyticsConsentState(
      status: status ?? this.status,
      saveStatus: saveStatus ?? this.saveStatus,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  List<Object?> get props => [status, saveStatus, isEnabled];
}
