// ABOUTME: Immutable state for repository-backed crossposting settings
// ABOUTME: Tracks platform settings, pending actions, errors, and OAuth outcomes

part of 'crossposting_settings_cubit.dart';

enum CrosspostingSettingsStatus { initial, loading, loaded, failure }

/// An operation that prevents overlapping reads and user mutations.
enum CrosspostingPlatformAction {
  refreshing,
  connecting,
  disconnecting,
  savingMode,
}

/// Transient error category surfaced by the settings UI.
enum CrosspostingSettingsError { generic, notConnected, callbackTimeout }

/// Transient result of a completed OAuth browser round trip.
enum CrosspostingOAuthOutcome { connected, denied, failed }

class CrosspostingSettingsState extends Equatable {
  CrosspostingSettingsState({
    this.status = CrosspostingSettingsStatus.initial,
    List<CrosspostingPlatformSettings> entries = const [],
    this.pendingAction,
    this.pendingPlatform,
    this.error,
    this.errorAttempt = 0,
    this.outcome,
    this.outcomePlatform,
    this.outcomeAttempt = 0,
  }) : entries = List.unmodifiable(entries);

  final CrosspostingSettingsStatus status;
  final List<CrosspostingPlatformSettings> entries;
  final CrosspostingPlatformAction? pendingAction;
  final CrosspostingPlatform? pendingPlatform;

  /// Paired with [errorAttempt] so repeated identical errors remain observable.
  final CrosspostingSettingsError? error;
  final int errorAttempt;

  /// Paired with [outcomeAttempt] so repeated outcomes remain observable.
  final CrosspostingOAuthOutcome? outcome;
  final CrosspostingPlatform? outcomePlatform;
  final int outcomeAttempt;

  /// Whether any mutation currently owns the global operation gate.
  bool get hasPendingAction => pendingAction != null;

  /// Whether there are platforms and none of them is connected yet.
  bool get allPlatformsDisconnected =>
      entries.isNotEmpty && entries.every((entry) => !entry.isConnected);

  /// The platform the benefit card pitches, or `null` when it is hidden.
  CrosspostingPlatform? get benefitCardPlatform =>
      allPlatformsDisconnected ? entries.first.platform : null;

  /// The first connected platform that could switch to automatic crossposting
  /// but has not, or `null` when the automatic-mode card is hidden.
  CrosspostingPlatform? get automaticModeCardPlatform {
    for (final entry in entries) {
      if (entry.isConnected &&
          entry.supportsAutomatic &&
          entry.mode != CrosspostingMode.automatic) {
        return entry.platform;
      }
    }
    return null;
  }

  CrosspostingSettingsState copyWith({
    CrosspostingSettingsStatus? status,
    List<CrosspostingPlatformSettings>? entries,
    CrosspostingPlatformAction? pendingAction,
    CrosspostingPlatform? pendingPlatform,
    CrosspostingSettingsError? error,
    int? errorAttempt,
    CrosspostingOAuthOutcome? outcome,
    CrosspostingPlatform? outcomePlatform,
    int? outcomeAttempt,
    bool clearPending = false,
    bool clearError = false,
    bool clearOutcome = false,
  }) {
    return CrosspostingSettingsState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      pendingAction: clearPending
          ? null
          : (pendingAction ?? this.pendingAction),
      pendingPlatform: clearPending
          ? null
          : (pendingPlatform ?? this.pendingPlatform),
      error: clearError ? null : (error ?? this.error),
      errorAttempt: errorAttempt ?? this.errorAttempt,
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
      outcomePlatform: clearOutcome
          ? null
          : (outcomePlatform ?? this.outcomePlatform),
      outcomeAttempt: outcomeAttempt ?? this.outcomeAttempt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    entries,
    pendingAction,
    pendingPlatform,
    error,
    errorAttempt,
    outcome,
    outcomePlatform,
    outcomeAttempt,
  ];
}
