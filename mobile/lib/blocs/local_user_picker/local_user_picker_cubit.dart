// ABOUTME: Owns local mutual-picker loading, ranking, and retained snapshots.
// ABOUTME: Keeps first-visible positions stable across progressive sources and refreshes.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/follow_list_ranking.dart';
import 'package:openvine/blocs/local_user_picker/local_user_picker_state.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:profile_repository/profile_repository.dart';

export 'local_user_picker_state.dart';

/// Local data for one owner/follow-source picker flow.
///
/// A replacement may inherit a snapshot only within that same flow. All data
/// dependencies are freshly injected; only the subscription handle is mutable.
class LocalUserPickerCubit extends Cubit<LocalUserPickerState>
    with CloseGuardedEmit<LocalUserPickerState> {
  LocalUserPickerCubit({
    required FollowRepository followRepository,
    required ProfileRepository? profileRepository,
    required UserRankingSignalsLoader? rankingSignalsLoader,
    required bool Function(String) isBlocked,
    String? excludedPubkey,
    LocalUserPickerState? initialState,
  }) : _followRepository = followRepository,
       _profileRepository = profileRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       _isBlocked = isBlocked,
       _excludedPubkey = excludedPubkey,
       super(
         _eligibleSnapshot(
           initialState ?? LocalUserPickerState(),
           followRepository,
           rankingSignalsLoader,
           isBlocked,
           excludedPubkey,
         ),
       );

  final FollowRepository _followRepository;
  final ProfileRepository? _profileRepository;
  final UserRankingSignalsLoader? _rankingSignalsLoader;
  final bool Function(String) _isBlocked;
  final String? _excludedPubkey;
  StreamSubscription<List<String>>? _followersSubscription;

  static LocalUserPickerState _eligibleSnapshot(
    LocalUserPickerState snapshot,
    FollowRepository followRepository,
    UserRankingSignalsLoader? loader,
    bool Function(String) isBlocked,
    String? excludedPubkey,
  ) {
    final following = followRepository.followingPubkeys.toSet();
    final retained = snapshot.profiles
        .where(
          (profile) =>
              following.contains(profile.pubkey) &&
              (loader?.isEligible(profile.pubkey) ?? true) &&
              !isBlocked(profile.pubkey) &&
              (excludedPubkey == null ||
                  !pubkeysEqual(profile.pubkey, excludedPubkey)),
        )
        .toList();
    final keys = retained.map((p) => p.pubkey).toSet();
    return snapshot.copyWith(
      profiles: retained,
      rankingSignals: {
        for (final entry in snapshot.rankingSignals.entries)
          if (keys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  bool _isEligible(String pubkey) =>
      (_rankingSignalsLoader?.isEligible(pubkey) ?? true) &&
      !_isBlocked(pubkey) &&
      (_excludedPubkey == null || !pubkeysEqual(pubkey, _excludedPubkey));

  void queryChanged(String query) => emit(state.copyWith(query: query));

  /// The UI supplies localized text, never a captured BuildContext callback.
  void identityChanged({
    required Set<String> vanishedPubkeys,
    required String deletedAccountLabel,
  }) => emit(
    state.copyWith(
      vanishedPubkeys: vanishedPubkeys,
      deletedAccountLabel: deletedAccountLabel,
    ),
  );

  void _reportError(Object error, StackTrace stackTrace) => runDetached(
    Future<void>.error(error, stackTrace),
    'load user picker ranking',
    logName: 'UserPickerSheet',
    category: LogCategory.ui,
  );

  /// Loads local candidates before observing progressive mutual confirmation.
  /// The repository owns its source strategy, including all-source failure.
  Future<void> started() async {
    final profileRepository = _profileRepository;
    final loader = _rankingSignalsLoader;
    if (isClosed || profileRepository == null || loader == null) return;
    final revision = state.loadRevision + 1;
    emit(state.copyWith(loadRevision: revision));
    bool isCurrent() => !isClosed && state.loadRevision == revision;
    await _followersSubscription?.cancel();
    if (!isCurrent()) return;
    final followingPubkeys = List<String>.of(
      _followRepository.followingPubkeys,
    );
    final signals = await loadFollowListRankingSignals(
      pubkeys: followingPubkeys,
      loader: loader,
      logName: 'UserPickerSheet',
      onError: (error, stackTrace) {
        if (isCurrent()) _reportError(error, stackTrace);
      },
    );
    if (!isCurrent()) return;
    final List<UserProfile> candidates;
    try {
      final cached = await profileRepository.getCachedProfiles(
        pubkeys: followingPubkeys,
      );
      if (!isCurrent()) return;
      final currentFollowing = _followRepository.followingPubkeys.toSet();
      final byKey = {
        for (final profile in state.profiles) profile.pubkey: profile,
        for (final profile in cached) profile.pubkey: profile,
      };
      candidates = byKey.values
          .where(
            (profile) =>
                currentFollowing.contains(profile.pubkey) &&
                signals.containsKey(profile.pubkey) &&
                _isEligible(profile.pubkey),
          )
          .toList();
    } catch (error, stackTrace) {
      if (!isCurrent()) return;
      _reportError(error, stackTrace);
      final currentFollowing = _followRepository.followingPubkeys.toSet();
      emitIfOpen(
        state.copyWith(
          rankingSignals: signals,
          profiles: state.profiles
              .where(
                (profile) =>
                    currentFollowing.contains(profile.pubkey) &&
                    signals.containsKey(profile.pubkey) &&
                    _isEligible(profile.pubkey),
              )
              .toList(),
          loaded: true,
        ),
      );
      loader.refreshInBackground(
        state.profiles.map((profile) => profile.pubkey).toList(),
      );
      return;
    }
    if (!isCurrent()) return;
    emitIfOpen(state.copyWith(rankingSignals: signals));
    if (candidates.isEmpty) {
      emitIfOpen(state.copyWith(profiles: const [], loaded: true));
      loader.refreshInBackground(const []);
      return;
    }

    void showProfiles(List<UserProfile> profiles) {
      if (!isCurrent()) return;
      final currentFollowing = _followRepository.followingPubkeys.toSet();
      final ranked = rankFollowListSnapshot(
        pubkeys: profiles.map((profile) => profile.pubkey).toList(),
        signals: signals,
        names: {
          for (final profile in profiles)
            profile.pubkey: state.renderedName(profile),
        },
        isEligible: (key) => currentFollowing.contains(key) && _isEligible(key),
        isSmartOrderReady: state.orderReady,
        previousSmartOrder: state.order,
        now: DateTime.now(),
      );
      final byKey = {for (final profile in profiles) profile.pubkey: profile};
      final first = !state.loaded;
      emitIfOpen(
        state.copyWith(
          order: [
            ...state.order,
            ...ranked.smartOrder.where((key) => !state.order.contains(key)),
          ],
          orderReady: true,
          profiles: [for (final key in ranked.smartOrder) byKey[key]!],
          loaded: true,
        ),
      );
      if (first) loader.refreshInBackground(ranked.smartOrder);
    }

    _followersSubscription = _followRepository.streamMyFollowers().listen(
      (followers) {
        if (!isCurrent()) return;
        final followerSet = followers.toSet();
        final mutuals = candidates
            .where((profile) => followerSet.contains(profile.pubkey))
            .toList();
        if (mutuals.isEmpty && !state.loaded) return;
        showProfiles(mutuals);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!isCurrent()) return;
        _reportError(error, stackTrace);
        showProfiles(candidates);
      },
      onDone: () {
        if (!isCurrent() || state.loaded) return;
        emitIfOpen(state.copyWith(loaded: true));
        loader.refreshInBackground(const []);
      },
    );
  }

  @override
  Future<void> close() {
    unawaited(_followersSubscription?.cancel());
    return super.close();
  }
}
