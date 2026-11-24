// ABOUTME: State for FeaturedTabsCubit: the resolved featured tab, if any.
// ABOUTME: Absence hides the tab; a campaign link shows its lookup status.

part of 'featured_tabs_cubit.dart';

/// Lifecycle of the featured-tab configuration fetch.
enum FeaturedTabsStatus {
  /// No fetch has completed yet.
  initial,

  /// A fetch or verification check is in progress.
  loading,

  /// [FeaturedTabsState.tab] is authoritative: a usable catalog decided it,
  /// now or on an earlier refresh, or its window has ended.
  resolved,

  /// The catalog or verification could not be loaded.
  failed,
}

/// The featured tab the Explore screen should render, if any.
class FeaturedTabsState extends Equatable {
  /// Creates a featured tabs state.
  const FeaturedTabsState({
    this.status = FeaturedTabsStatus.initial,
    this.tab,
    this.resolvedFor,
    this.pollInterval = FeaturedTabsResponse.defaultPollInterval,
  });

  /// Fetch lifecycle.
  final FeaturedTabsStatus status;

  /// The eligible tab, or `null` when nothing should render.
  final FeaturedTabConfig? tab;

  /// Audience whose catalog lookup established the last resolved answer.
  final FeaturedTabAudience? resolvedFor;

  /// Server-supplied refresh cadence.
  final Duration pollInterval;

  /// Returns a copy with the given overrides.
  FeaturedTabsState copyWith({
    FeaturedTabsStatus? status,
    FeaturedTabConfig? tab,
    bool clearTab = false,
    FeaturedTabAudience? resolvedFor,
    Duration? pollInterval,
  }) {
    return FeaturedTabsState(
      status: status ?? this.status,
      tab: clearTab ? null : tab ?? this.tab,
      pollInterval: pollInterval ?? this.pollInterval,
      resolvedFor: resolvedFor ?? this.resolvedFor,
    );
  }

  @override
  List<Object?> get props => [status, tab, pollInterval, resolvedFor];
}
