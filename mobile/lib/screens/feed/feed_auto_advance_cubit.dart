import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feed-scoped runtime state for the Auto playback mode.
///
/// Owned per feed surface (home feed page / fullscreen feed) and provided
/// down the tree via `BlocProvider` so the completion listener, the rail
/// control, and the screen's orchestration logic all observe the same state.
class FeedAutoAdvanceState extends Equatable {
  const FeedAutoAdvanceState({
    this.enabled = false,
    this.suppressed = false,
    this.pendingPaginationAdvance = false,
  });

  /// Whether the user has turned Auto on for this feed.
  final bool enabled;

  /// Whether Auto is temporarily suppressed by a non-swipe interaction
  /// (e.g. opening a comment sheet). Cleared on the next manual swipe, or
  /// on the tap that resumes playback.
  final bool suppressed;

  /// Whether an auto-advance is queued waiting for the next pagination page
  /// to land. Cleared once the advance executes or Auto is disabled.
  final bool pendingPaginationAdvance;

  /// True when Auto should actually drive the feed forward right now.
  bool get isEffectivelyActive => enabled && !suppressed;

  FeedAutoAdvanceState copyWith({
    bool? enabled,
    bool? suppressed,
    bool? pendingPaginationAdvance,
  }) {
    return FeedAutoAdvanceState(
      enabled: enabled ?? this.enabled,
      suppressed: suppressed ?? this.suppressed,
      pendingPaginationAdvance:
          pendingPaginationAdvance ?? this.pendingPaginationAdvance,
    );
  }

  @override
  List<Object?> get props => [enabled, suppressed, pendingPaginationAdvance];
}

/// Feed-scoped Cubit that owns the Auto playback toggle and transient flags.
class FeedAutoAdvanceCubit extends Cubit<FeedAutoAdvanceState> {
  FeedAutoAdvanceCubit() : super(const FeedAutoAdvanceState());

  /// Sets the Auto toggle directly. Disabling also clears suppression and
  /// any queued pagination advance.
  void setEnabled({required bool enabled}) {
    if (state.enabled == enabled) return;

    if (!enabled) {
      emit(const FeedAutoAdvanceState());
      return;
    }

    emit(state.copyWith(enabled: true, suppressed: false));
  }

  /// Flips the Auto toggle.
  ///
  /// Always moves `enabled`, including while Auto is suppressed. The pill is
  /// the only caller, and on the paused-video overlay suppressed-and-enabled
  /// is its normal state — the tap that reveals the overlay is the one that
  /// suppresses. A resume-instead-of-disable branch there would leave the
  /// control reporting "on" after a press on "Disable auto advance".
  /// Suppression is lifted by [resumeAfterSwipe] instead — on a manual
  /// swipe, or on the tap that resumes playback.
  void toggle() => setEnabled(enabled: !state.enabled);

  /// Temporarily suppress Auto for a non-swipe interaction.
  void suppressForInteraction() {
    if (!state.enabled || state.suppressed) return;

    emit(state.copyWith(suppressed: true, pendingPaginationAdvance: false));
  }

  /// Resume Auto after an interaction that must not leave it latched off.
  ///
  /// Called on a manual swipe, and on the tap that resumes playback after a
  /// pause — both say the viewer wants to keep watching. The name predates
  /// that second caller.
  void resumeAfterSwipe() {
    if (!state.enabled || !state.suppressed) return;

    emit(state.copyWith(suppressed: false, pendingPaginationAdvance: false));
  }

  /// Mark that the feed needs to advance once the next page lands.
  void markPendingPaginationAdvance() {
    if (state.pendingPaginationAdvance) return;
    emit(state.copyWith(pendingPaginationAdvance: true));
  }

  /// Clear the queued pagination advance (typically after it fires).
  void clearPendingPaginationAdvance() {
    if (!state.pendingPaginationAdvance) return;
    emit(state.copyWith(pendingPaginationAdvance: false));
  }
}
