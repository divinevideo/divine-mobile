// ABOUTME: Cubit backing the profile bell — subscribe to a creator's posts.
// ABOUTME: Optimistic toggle that reverts when the list publish fails.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/notify_bell/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

part 'notify_bell_state.dart';

/// Drives the bell on a creator's profile.
///
/// One cubit per (viewer, creator) pair. Reads the viewer's `d=notify`
/// subscription list and toggles this creator in or out of it.
///
/// The repository serializes concurrent publishes, so this cubit does not
/// need its own guard against rapid taps — but it does flip state
/// optimistically and revert on failure, so the bell tracks the finger
/// rather than the relay round-trip.
class NotifyBellCubit extends Cubit<NotifyBellState> {
  NotifyBellCubit({
    required NotifySubscriptionsRepository repository,
    required String viewerPubkey,
    required String creatorPubkey,
  }) : _repository = repository,
       _viewerPubkey = viewerPubkey,
       _creatorPubkey = creatorPubkey,
       super(const NotifyBellState());

  final NotifySubscriptionsRepository _repository;
  final String _viewerPubkey;
  final String _creatorPubkey;

  StreamSubscription<Set<String>>? _subscription;

  /// Loads the current subscription state and tracks later changes.
  ///
  /// Watching (rather than a one-shot read) keeps two bells for the same
  /// creator in sync — e.g. the profile bell and a bell reached from a
  /// different route — and picks up an unfollow teardown published while
  /// this bell is mounted.
  ///
  /// The stream stays silent until the list has actually been read, so the
  /// bell holds [NotifyBellStatus.initial] — and stays untappable — while the
  /// relays are unreachable. Tapping an unverified "off" would publish a
  /// replacement list containing only this creator.
  Future<void> load() async {
    _subscription ??= _repository
        .watchSubscriptions(ownerPubkey: _viewerPubkey)
        .listen(_onSubscriptionsChanged);
    await _retryOutstandingTeardown();
  }

  /// Republishes an unfollow teardown whose earlier publish failed.
  ///
  /// The bell is follow-gated, so once the viewer unfollows there is no bell
  /// left to retry from. Every bell mount therefore drains whatever removal
  /// is still outstanding for this viewer, whichever creator it belonged to.
  Future<void> _retryOutstandingTeardown() async {
    try {
      await _repository.reconcile(ownerPubkey: _viewerPubkey);
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(
        Reportable(error, context: NotifyBellReportableSites.reconcile),
        stackTrace,
      );
    }
  }

  void _onSubscriptionsChanged(Set<String> creators) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: NotifyBellStatus.ready,
        isSubscribed: creators.contains(_creatorPubkey),
      ),
    );
  }

  /// Flips the bell, publishing the updated list.
  ///
  /// Reverts and emits [NotifyBellStatus.failure] when the publish fails, so
  /// the bell never claims a subscription the relays never received.
  Future<void> toggle() async {
    if (!state.isInteractive) return;

    final wasSubscribed = state.isSubscribed;
    emit(
      state.copyWith(
        status: NotifyBellStatus.ready,
        isSubscribed: !wasSubscribed,
      ),
    );

    try {
      final result = wasSubscribed
          ? await _repository.unsubscribe(
              ownerPubkey: _viewerPubkey,
              creatorPubkey: _creatorPubkey,
            )
          : await _repository.subscribe(
              ownerPubkey: _viewerPubkey,
              creatorPubkey: _creatorPubkey,
            );
      if (isClosed) return;

      if (result.status == PeopleListPublishStatus.failed) {
        emit(
          state.copyWith(
            status: NotifyBellStatus.failure,
            isSubscribed: wasSubscribed,
          ),
        );
      }
      // submitted and noop both leave the optimistic state standing: the
      // stream emission from the repository confirms it, and a noop means
      // the desired state already held.
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(
        Reportable(error, context: NotifyBellReportableSites.toggle),
        stackTrace,
      );
      emit(
        state.copyWith(
          status: NotifyBellStatus.failure,
          isSubscribed: wasSubscribed,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
