// ABOUTME: State for AnalyticsConsentCubit — the analytics consent preference.

import 'package:equatable/equatable.dart';

/// Load lifecycle of the analytics consent tile.
///
/// The stored preference only reaches `AnalyticsService` once it has read
/// SharedPreferences, so the tile stays [loading] until then rather than
/// showing the pre-load default as if it were the user's answer.
enum AnalyticsConsentStatus { loading, ready }

/// State for `AnalyticsConsentCubit`.
class AnalyticsConsentState extends Equatable {
  const AnalyticsConsentState({
    this.status = AnalyticsConsentStatus.loading,
    this.isEnabled = false,
  });

  final AnalyticsConsentStatus status;
  final bool isEnabled;

  AnalyticsConsentState copyWith({
    AnalyticsConsentStatus? status,
    bool? isEnabled,
  }) {
    return AnalyticsConsentState(
      status: status ?? this.status,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  List<Object?> get props => [status, isEnabled];
}
