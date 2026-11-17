// ABOUTME: Cubit polling the featured Explore tab configuration.
// ABOUTME: Repository owns caching and gating; this owns cadence and lifecycle.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

part 'featured_tabs_state.dart';

/// Keeps the featured Explore tab in sync with its server configuration.
///
/// Polls at the server-supplied cadence and refetches on app foreground so a
/// backend kill switch takes effect without an app update. Eligibility and
/// cache staleness are the repository's job — this cubit only decides *when*
/// to ask and republishes the answer.
class FeaturedTabsCubit extends Cubit<FeaturedTabsState> {
  /// Creates the cubit over [repository].
  ///
  /// [gateAgeRestrictedContent] is read at each refresh rather than captured
  /// once, so an age-up or account switch is reflected on the next poll.
  FeaturedTabsCubit({
    required FeaturedTabsRepository repository,
    required bool Function() gateAgeRestrictedContent,
    this.requiredFeaturedFeedId,
  }) : _repository = repository,
       _gateAgeRestrictedContent = gateAgeRestrictedContent,
       super(const FeaturedTabsState());

  final FeaturedTabsRepository _repository;
  final bool Function() _gateAgeRestrictedContent;

  /// Feed required by a campaign destination, or null for normal Explore.
  final String? requiredFeaturedFeedId;

  Timer? _pollTimer;

  /// Sequence number of the newest started refresh.
  ///
  /// Request bookkeeping rather than UI state, like [_pollTimer] beside it:
  /// nothing renders from it, so it stays off the state object.
  int _refreshGeneration = 0;

  /// Fetches the configuration and reschedules the poll timer.
  ///
  /// Safe to call repeatedly; the UI calls it on mount and on app foreground.
  ///
  /// Three callers can overlap — the poll timer, the foreground listener, and
  /// the minor-status listener — so a slower earlier request must not publish
  /// after a faster later one. Without that ordering the kill switch is
  /// defeatable: a request issued before the kill can land after the refresh
  /// that resolved the tab away and put it back on screen until the next poll.
  /// Only the newest generation may emit.
  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_refreshGeneration;
    emit(state.copyWith(status: FeaturedTabsStatus.loading));

    final snapshot = await _repository.refresh(
      gateAgeRestrictedContent: _gateAgeRestrictedContent(),
      requiredFeaturedFeedId: requiredFeaturedFeedId,
    );
    if (isClosed || generation != _refreshGeneration) return;

    emit(
      FeaturedTabsState(
        status: FeaturedTabsStatus.resolved,
        tab: snapshot.tab,
        pollInterval: snapshot.pollInterval,
      ),
    );
    _schedulePoll(snapshot.pollInterval);
  }

  void _schedulePoll(Duration interval) {
    _pollTimer?.cancel();
    if (interval <= Duration.zero) return;
    _pollTimer = Timer(interval, refresh);
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _pollTimer = null;
    return super.close();
  }
}
