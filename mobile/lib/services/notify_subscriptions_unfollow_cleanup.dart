// ABOUTME: Keeps app-managed new-post subscriptions aligned with follows.
// ABOUTME: Cleans up committed unfollows from every entry point.

import 'dart:async';

import 'package:follow_repository/follow_repository.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Removes new-post subscriptions for creators the viewer no longer follows.
///
/// The service listens to committed follow removals rather than the
/// optimistic [FollowRepository.followingStream]. It also reconciles once
/// after the follow list is loaded, when a relay confirmed it, covering
/// unfollows made on another device while this app was closed.
class NotifySubscriptionsUnfollowCleanup {
  NotifySubscriptionsUnfollowCleanup({
    required FollowRepository followRepository,
    required NotifySubscriptionsRepository notifySubscriptionsRepository,
    required String ownerPubkey,
  }) : _followRepository = followRepository,
       _notifySubscriptionsRepository = notifySubscriptionsRepository,
       _ownerPubkey = ownerPubkey;

  static const _logName = 'NotifySubscriptionsUnfollowCleanup';

  final FollowRepository _followRepository;
  final NotifySubscriptionsRepository _notifySubscriptionsRepository;
  final String _ownerPubkey;

  StreamSubscription<String>? _unfollowSubscription;
  bool _started = false;

  /// Starts cleanup and reconciles subscriptions with the current follow set.
  Future<void> start() async {
    if (_started || _ownerPubkey.isEmpty) return;
    _started = true;

    _unfollowSubscription = _followRepository.confirmedUnfollowStream.listen(
      _onConfirmedUnfollow,
    );

    try {
      await _followRepository.initialized;
      // A failed relay read leaves only local caches, which may be empty or
      // stale; diffing against them would delete live subscriptions.
      if (!_followRepository.isFollowingConfirmedByRelay) {
        Log.info(
          'Skipping new-post subscription reconcile: follow list not '
          'confirmed by a relay',
          name: _logName,
          category: LogCategory.relay,
        );
        return;
      }
      final follows = _followRepository.followingPubkeys.toSet();
      final subscriptions = await _notifySubscriptionsRepository
          .readSubscriptions(ownerPubkey: _ownerPubkey);
      for (final creatorPubkey in subscriptions.difference(follows)) {
        await _removeSubscription(creatorPubkey);
      }
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Could not reconcile new-post subscriptions with follows: $error',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onConfirmedUnfollow(String creatorPubkey) {
    unawaited(_removeSubscription(creatorPubkey));
  }

  Future<void> _removeSubscription(String creatorPubkey) async {
    try {
      final result = await _notifySubscriptionsRepository.unsubscribe(
        ownerPubkey: _ownerPubkey,
        creatorPubkey: creatorPubkey,
      );
      if (result.status == PeopleListPublishStatus.failed) {
        Log.warning(
          'Could not publish a new-post subscription removal; it is retained '
          'for retry.',
          name: _logName,
          category: LogCategory.relay,
        );
      }
    } on Object catch (error, stackTrace) {
      Log.error(
        'Could not remove a new-post subscription: $error',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stops listening for changes.
  Future<void> dispose() async {
    await _unfollowSubscription?.cancel();
    _unfollowSubscription = null;
  }
}
