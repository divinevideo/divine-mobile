// ABOUTME: Cubit polling the featured Explore tab configuration.
// ABOUTME: Repository owns caching and eligibility; this owns cadence,
// ABOUTME: expiry and lookup status.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

part 'featured_tabs_state.dart';

/// Eligibility to see featured content reserved for verified adults.
///
/// Every value but [adult] keeps that content hidden.
enum FeaturedTabAudience {
  /// Auth or 18+ verification is still being checked.
  loading,

  /// The 18+ verification check failed.
  failed,

  /// Signed out, or signed in without 18+ verification.
  unverified,

  /// Signed in with 18+ verification.
  adult;

  bool get gatesAdultContent => this != adult;
}

/// Keeps the featured Explore tab in sync with its server configuration.
///
/// Polls at the server-supplied cadence and refetches on app foreground so a
/// backend kill switch takes effect without an app update. The repository
/// decides eligibility and staleness; this cubit decides when to ask, drops a
/// held tab as soon as the audience or its window rules it out, and tells a
/// failed lookup apart from a confirmed absence.
class FeaturedTabsCubit extends Cubit<FeaturedTabsState> {
  /// Creates the cubit over [repository].
  ///
  /// [audience] is read at each refresh so the decision follows verification
  /// and account changes.
  FeaturedTabsCubit({
    required FeaturedTabsRepository repository,
    required FeaturedTabAudience Function() audience,
    this.requiredFeaturedFeedId,
    DateTime Function()? now,
  }) : _repository = repository,
       _audience = audience,
       _now = now ?? DateTime.now,
       super(const FeaturedTabsState());

  final FeaturedTabsRepository _repository;
  final FeaturedTabAudience Function() _audience;
  final DateTime Function() _now;

  /// Feed required by a campaign destination, or null for normal Explore.
  final String? requiredFeaturedFeedId;

  Timer? _pollTimer;
  Timer? _expiryTimer;
  FeaturedTabAudience? _resolvedAudience;

  /// Sequence number of the newest started refresh.
  ///
  /// Request bookkeeping rather than UI state, like [_pollTimer] beside it:
  /// nothing renders from it, so it stays off the state object.
  int _refreshGeneration = 0;

  /// Fetches the configuration and reschedules the poll timer.
  ///
  /// Safe to call repeatedly. Refreshes overlap — the poll and expiry timers
  /// and the foreground and audience listeners — so a slower earlier request
  /// must not publish after a faster later one. Without that ordering the kill
  /// switch is defeatable: a request issued before the kill can land after the
  /// refresh that resolved the tab away and put it back on screen until the
  /// next poll. Only the newest generation, read for an unchanged audience,
  /// publishes its result.
  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_refreshGeneration;
    final audience = _audience();
    final previousTab = state.tab;
    final hadConfirmedAbsence =
        state.status == FeaturedTabsStatus.resolved &&
        state.tab == null &&
        _resolvedAudience == audience;
    if (!hadConfirmedAbsence) {
      emit(
        state.copyWith(
          status: FeaturedTabsStatus.loading,
          clearTab:
              (audience.gatesAdultContent &&
                  previousTab?.visibleToMinors == false) ||
              previousTab?.endsAt?.isAfter(_now()) == false,
        ),
      );
    }

    final snapshot = await _repository.refresh(
      gateAgeRestrictedContent: audience.gatesAdultContent,
      requiredFeaturedFeedId: requiredFeaturedFeedId,
    );
    if (isClosed ||
        generation != _refreshGeneration ||
        _audience() != audience) {
      return;
    }

    final tab = snapshot.tab;
    final status = switch ((tab, snapshot.hasResolvedCatalog, audience)) {
      (FeaturedTabConfig(), _, _) => FeaturedTabsStatus.resolved,
      (null, false, _) when hadConfirmedAbsence => FeaturedTabsStatus.resolved,
      (null, false, _) => FeaturedTabsStatus.failed,
      (null, true, FeaturedTabAudience.loading) => FeaturedTabsStatus.loading,
      (null, true, FeaturedTabAudience.failed) => FeaturedTabsStatus.failed,
      _ => FeaturedTabsStatus.resolved,
    };
    if (status == FeaturedTabsStatus.resolved) _resolvedAudience = audience;
    emit(
      FeaturedTabsState(
        status: status,
        tab: tab,
        pollInterval: snapshot.pollInterval,
      ),
    );
    _schedulePoll(snapshot.pollInterval);
    _scheduleExpiry(tab);
  }

  void _scheduleExpiry(FeaturedTabConfig? tab) {
    if (requiredFeaturedFeedId == null) return;
    _expiryTimer?.cancel();
    final endsAt = tab?.endsAt;
    if (endsAt == null) return;
    final remaining = endsAt.difference(_now());
    // Browser timers overflow for long windows; recheck daily, as announcement
    // expiry does.
    const maximumDelay = Duration(days: 1);
    _expiryTimer = Timer(
      remaining > maximumDelay ? maximumDelay : remaining,
      () {
        if (isClosed || state.tab != tab) return;
        if (_now().isBefore(endsAt)) {
          _scheduleExpiry(tab);
          return;
        }
        _resolvedAudience = _audience();
        emit(
          state.copyWith(
            status: FeaturedTabsStatus.resolved,
            clearTab: true,
          ),
        );
        runDetached(
          refresh(),
          'refresh featured campaign at expiry',
          logName: 'FeaturedTabsCubit',
          category: LogCategory.ui,
        );
      },
    );
  }

  void _schedulePoll(Duration interval) {
    _pollTimer?.cancel();
    if (interval <= Duration.zero) return;
    _pollTimer = Timer(interval, refresh);
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    return super.close();
  }
}
