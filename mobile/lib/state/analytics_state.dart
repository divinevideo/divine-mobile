// ABOUTME: Analytics state model for tracking analytics enabled state and last event
// ABOUTME: Used by Riverpod AnalyticsProvider to manage reactive analytics state

import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_state.freezed.dart';
part 'analytics_state.g.dart';

@freezed
sealed class AnalyticsState with _$AnalyticsState {
  const factory AnalyticsState({
    @Default(true) bool analyticsEnabled,
    @Default(false) bool isInitialized,
    @Default(false) bool isLoading,
    String? lastEvent,
    String? error,
  }) = _AnalyticsState;

  factory AnalyticsState.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsStateFromJson(json);

  const AnalyticsState._();

  /// Create initial state
  static final AnalyticsState initial = const AnalyticsState();
}
