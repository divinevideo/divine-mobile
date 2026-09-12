// ABOUTME: BLoC for managing interactions on a single video
// ABOUTME: Handles like/repost status and counts per video item

import 'dart:async';
import 'dart:math' as math;

import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart' show NIP71VideoKinds;
import 'package:openvine/blocs/video_interactions/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_interactions_event.dart';
part 'video_interactions_state.dart';

/// BLoC for managing interactions on a single video.
///
/// This bloc is created per-VideoFeedItem and manages:
/// - Like status (from LikesRepository)
/// - Like count (seeded feed payload; for addressable videos floored up to the
///   archival + relay-resolved Nostr count so a stale/zero seed can be raised
///   but never lowered, #6022)
/// - Repost status (from RepostsRepository)
/// - Repost count (from seeded feed payload, or relay fallback when unseeded)
/// - Comment count (from seeded feed payload, or relay fallback when unseeded)
///
/// The bloc subscribes to the repository's liked/reposted IDs streams to stay
/// in sync when interactions change from other sources (e.g., profile grids).
class VideoInteractionsBloc
    extends Bloc<VideoInteractionsEvent, VideoInteractionsState> {
  VideoInteractionsBloc({
    required String eventId,
    required String authorPubkey,
    required LikesRepository likesRepository,
    required CommentsRepository commentsRepository,
    required RepostsRepository repostsRepository,
    String? addressableId,
    int? initialLikeCount,
    int? archivedLikeCount,
    int? initialCommentCount,
    int? initialRepostCount,
    bool includeVideoReplies = false,
  }) : _eventId = eventId,
       _authorPubkey = authorPubkey,
       _likesRepository = likesRepository,
       _commentsRepository = commentsRepository,
       _repostsRepository = repostsRepository,
       _addressableId = addressableId,
       _archivedLikeCount = archivedLikeCount,
       _includeVideoReplies = includeVideoReplies,
       super(
         VideoInteractionsState(
           likeCount: initialLikeCount,
           repostCount: initialRepostCount,
           commentCount: initialCommentCount,
         ),
       ) {
    on<VideoInteractionsFetchRequested>(_onFetchRequested);
    // Toggle handlers fire-and-forget the publish (see _onLikeToggled),
    // so they return in microseconds and do not benefit from a
    // droppable transformer. Rapid double-taps on the same video are
    // intentionally allowed to flip-flip — end state is correct via
    // the repository's per-event-id guards
    // (AlreadyLikedException / AlreadyRepostedException) which
    // surface as no-op settle events here. Different videos already
    // use different bloc instances, so cross-video parallelism is
    // unaffected.
    on<VideoInteractionsLikeToggled>(_onLikeToggled);
    on<VideoInteractionsRepostToggled>(_onRepostToggled);
    on<_VideoInteractionsLikeSettled>(_onLikeSettled);
    on<_VideoInteractionsRepostSettled>(_onRepostSettled);
    on<VideoInteractionsSubscriptionRequested>(_onSubscriptionRequested);
    on<VideoInteractionsCommentCountUpdated>(_onCommentCountUpdated);
  }

  final String _eventId;
  int _likeToggleRevision = 0;
  final String _authorPubkey;
  final LikesRepository _likesRepository;
  final CommentsRepository _commentsRepository;
  final RepostsRepository _repostsRepository;
  final bool _includeVideoReplies;

  /// Addressable ID for repost operations (format: `kind:pubkey:d-tag`).
  /// Null if the video doesn't have a d-tag (non-addressable event).
  final String? _addressableId;

  /// Archival (classic Vine) like count baseline, kept separate from the
  /// live Nostr count so the addressable like floor (#6022) can raise only
  /// the Nostr portion without letting the archival number mask newly
  /// resolved Nostr likes. Null when there is no archival baseline.
  final int? _archivedLikeCount;

  /// Subscribe to liked/reposted IDs changes and update status reactively.
  Future<void> _onSubscriptionRequested(
    VideoInteractionsSubscriptionRequested event,
    Emitter<VideoInteractionsState> emit,
  ) {
    // Track the latest snapshot from both like streams so either one
    // ticking recomputes membership from BOTH — a like recorded against a
    // pre-edit event id for this coordinate only shows up in the
    // addressable-id stream, and watchLikedEventIds ticks on every
    // like/unlike anywhere in the app (not just this video), so treating
    // the two streams independently would let a same-coordinate-only hit
    // get silently overwritten back to unliked the next time anything
    // else is liked/unliked (#6020).
    var likedEventIds = const <String>[];
    var likedAddressableIds = const <String>{};
    bool resolveIsLiked() =>
        likedEventIds.contains(_eventId) ||
        (_addressableId != null &&
            likedAddressableIds.contains(_addressableId));

    final subscriptions = [
      emit.forEach<List<String>>(
        _likesRepository.watchLikedEventIds(),
        onData: (ids) {
          likedEventIds = ids;
          final isLiked = resolveIsLiked();
          // Load-bearing: when [_onLikeToggled] has already emitted its
          // optimistic state, state.isLiked matches and we no-op here.
          // This guarantees a single bloc emit per tap and avoids the
          // double-count race that would otherwise happen if both
          // handlers adjusted likeCount.
          if (isLiked == state.isLiked) return state;

          // Sync like status only — count is owned by _onLikeToggled.
          // This stream conveys membership of the liked set, not an
          // authoritative count snapshot, so external flips update
          // isLiked here without rewriting likeCount.
          return state.copyWith(isLiked: isLiked);
        },
      ),
      if (_addressableId != null)
        emit.forEach<Set<String>>(
          _likesRepository.watchLikedAddressableIds(),
          onData: (ids) {
            likedAddressableIds = ids;
            final isLiked = resolveIsLiked();
            if (isLiked == state.isLiked) return state;
            return state.copyWith(isLiked: isLiked);
          },
        ),
      if (_addressableId != null)
        emit.forEach<Set<String>>(
          _repostsRepository.watchRepostedAddressableIds(),
          onData: (repostedIds) {
            final isReposted = repostedIds.contains(_addressableId);
            // Load-bearing for the same reason as the likes branch: the
            // repost toggle handler emits optimistically before awaiting,
            // and this early-return absorbs the follow-up stream tick.
            if (isReposted == state.isReposted) return state;

            return state.copyWith(isReposted: isReposted);
          },
        ),
    ];

    return subscriptions.wait;
  }

  /// Handle request to fetch initial state.
  Future<void> _onFetchRequested(
    VideoInteractionsFetchRequested event,
    Emitter<VideoInteractionsState> emit,
  ) async {
    // Don't re-fetch if already loaded
    if (state.status == VideoInteractionsStatus.success) return;
    if (state.status == VideoInteractionsStatus.loading) return;

    // Snapshot the interactive fields. Fetch and toggle handlers run
    // concurrently (default transformer). If a tap lands while we await
    // the relay round-trips below, state.* drifts from the snapshot and
    // the fetched values are stale relative to the user's intent — pass
    // null to copyWith for any drifted field so the optimistic flip
    // survives.
    final preFetchIsLiked = state.isLiked;
    final preFetchLikeCount = state.likeCount;
    final preFetchIsReposted = state.isReposted;
    final preFetchRepostCount = state.repostCount;
    final preFetchCommentCount = state.commentCount;

    emit(state.copyWith(status: VideoInteractionsStatus.loading));

    try {
      // Check if liked (fast - from local cache). Falls back to the
      // addressable coordinate when the event id misses, so a like
      // recorded against a pre-edit version of this video still resolves
      // (#6020).
      final isLiked = await _likesRepository.isLikedResolvingCoordinate(
        eventId: _eventId,
        addressableId: _addressableId,
      );

      // Check if reposted (fast - from local cache) if addressable
      final isReposted =
          _addressableId != null &&
          await _repostsRepository.isReposted(_addressableId);

      // Fetch counts in parallel
      // Query repost count by addressable ID when available (NIP-18 specifies
      // that generic reposts of addressable events use the `a` tag).
      // Fall back to event ID for non-addressable videos.
      final repostCountFuture = _addressableId != null
          ? _repostsRepository.getRepostCount(_addressableId)
          : _repostsRepository.getRepostCountByEventId(_eventId);

      // Fetch a fallback like count for blocs that were not seeded from the
      // feed payload. Addressable videos resolve the same filtered liker set as
      // the "Liked by" list; non-addressable videos still use relay COUNT,
      // whose results can include unrelated historical reactions.
      final likeCountFuture = _likesRepository.getLikeCount(
        _eventId,
        addressableId: _addressableId,
      );

      final results = await Future.wait([
        likeCountFuture,
        _commentsRepository.getCommentsCount(
          _eventId,
          rootAddressableId: _addressableId,
          includeVideoReplies: _includeVideoReplies,
        ),
        repostCountFuture,
      ]);

      final fetchedLikeCount = results[0];
      final fetchedCommentCount = results[1];
      final fetchedRepostCount = results[2];

      // #6022: floor the Nostr like count against the addressable relay
      // resolve so a stale/zero funnelcake seed can be raised by the cleaner
      // distinct-liker count, but never lowered. Addressable-only — the
      // non-addressable getLikeCount is a raw, unfiltered tally that must not
      // raise the count. originalLikes (archival) is kept out of the floor so
      // it can't mask newly resolved Nostr likes.
      final likeCount = _addressableId != null && fetchedLikeCount != null
          ? math.max(
              preFetchLikeCount ?? 0,
              (_archivedLikeCount ?? 0) + fetchedLikeCount,
            )
          : preFetchLikeCount ?? fetchedLikeCount;
      final commentCount = preFetchCommentCount ?? fetchedCommentCount;
      final repostCount = preFetchRepostCount ?? fetchedRepostCount;

      emit(
        state.copyWith(
          status: VideoInteractionsStatus.success,
          isLiked: state.isLiked == preFetchIsLiked ? isLiked : null,
          likeCount: state.likeCount == preFetchLikeCount ? likeCount : null,
          isReposted: state.isReposted == preFetchIsReposted
              ? isReposted
              : null,
          repostCount: state.repostCount == preFetchRepostCount
              ? repostCount
              : null,
          commentCount: state.commentCount == preFetchCommentCount
              ? commentCount
              : null,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'VideoInteractionsBloc: Failed to fetch for $_eventId - $e',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );
      addError(e, stackTrace);

      // Still mark as success if we have partial data
      // The UI can handle null counts gracefully
      emit(state.copyWith(status: VideoInteractionsStatus.success));
    }
  }

  /// Handle like toggle request.
  ///
  /// Emits the optimistic state (flipped [isLiked] + adjusted [likeCount])
  /// and returns immediately — the publish itself runs fire-and-forget via
  /// [_publishLike]. The handler intentionally does not await the publish
  /// so that a slow network on this video never blocks taps on subsequent
  /// videos (different videos use different bloc instances; this just keeps
  /// each instance's event queue free of long-running work).
  ///
  /// When the publish settles, [_publishLike] dispatches a
  /// [_VideoInteractionsLikeSettled] event and reconciliation happens in
  /// [_onLikeSettled] with a fresh [Emitter].
  Future<void> _onLikeToggled(
    VideoInteractionsLikeToggled event,
    Emitter<VideoInteractionsState> emit,
  ) async {
    final revision = ++_likeToggleRevision;
    final wasLiked = state.isLiked;
    final wasCount = state.likeCount;
    final optimisticLiked = !wasLiked;

    emit(
      state.copyWith(
        isLiked: optimisticLiked,
        // copyWith treats null as "no change", so when the count hasn't
        // been fetched yet we leave it null (don't synthesize a 0).
        likeCount: _adjustCount(wasCount, increment: optimisticLiked),
      ),
    );

    unawaited(
      _publishLike(
        optimisticLiked: optimisticLiked,
        wasLiked: wasLiked,
        wasCount: wasCount,
        revision: revision,
      ),
    );
  }

  Future<void> _publishLike({
    required bool optimisticLiked,
    required bool wasLiked,
    required int? wasCount,
    required int revision,
  }) async {
    _LikeSettleOutcome outcome;
    try {
      // Pass addressable ID and target kind for proper a-tag tagging
      final isNowLiked = await _likesRepository.toggleLike(
        eventId: _eventId,
        authorPubkey: _authorPubkey,
        addressableId: _addressableId,
        targetKind: _addressableId != null
            ? NIP71VideoKinds.addressableShortVideo
            : null,
      );
      outcome = isNowLiked == optimisticLiked
          ? const _LikeSettleConfirmed()
          : _LikeSettleOutOfBand(actualIsLiked: isNowLiked);
    } on AlreadyLikedException {
      outcome = const _LikeSettleAlready();
    } on NotLikedException {
      outcome = const _LikeSettleNotLiked();
    } on LikeAccountRestrictedException {
      outcome = _LikeSettleRestricted(wasLiked: wasLiked);
    } catch (e, stackTrace) {
      Log.error(
        'VideoInteractionsBloc: Like toggle failed for $_eventId - $e',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );
      // Guarded for symmetry with the sibling add() below: _publishLike
      // runs fire-and-forget via unawaited() and post-close addError
      // throws StateError.
      if (!isClosed) {
        addError(
          Reportable(e, context: VideoInteractionsReportableSites.publishLike),
          stackTrace,
        );
      }
      outcome = _LikeSettleFailed(wasLiked: wasLiked);
    }

    if (isClosed) return;
    add(
      _VideoInteractionsLikeSettled(
        outcome: outcome,
        wasCount: wasCount,
        revision: revision,
      ),
    );
  }

  void _onLikeSettled(
    _VideoInteractionsLikeSettled event,
    Emitter<VideoInteractionsState> emit,
  ) {
    if (event.revision != _likeToggleRevision) return;
    switch (event.outcome) {
      case _LikeSettleConfirmed():
        // Optimistic emit already matches the publish result; no-op.
        return;
      case _LikeSettleOutOfBand(:final actualIsLiked):
        // Another device flipped it mid-tap. Reconcile from the pre-tap
        // baseline so the count doesn't double-adjust.
        emit(
          state.copyWith(
            isLiked: actualIsLiked,
            likeCount: _adjustCount(event.wasCount, increment: actualIsLiked),
          ),
        );
      case _LikeSettleAlready():
        emit(state.copyWith(isLiked: true, likeCount: event.wasCount));
      case _LikeSettleNotLiked():
        emit(state.copyWith(isLiked: false, likeCount: event.wasCount));
      case _LikeSettleFailed(:final wasLiked):
        emit(state.copyWith(isLiked: wasLiked, likeCount: event.wasCount));
      case _LikeSettleRestricted(:final wasLiked):
        emit(
          state.copyWith(
            isLiked: wasLiked,
            likeCount: event.wasCount,
            accountRestrictionRevision: state.accountRestrictionRevision + 1,
          ),
        );
    }
  }

  /// Adjusts a possibly-null count by +1/-1 with a zero floor.
  ///
  /// Returns null when [count] is null so callers can pass the result to
  /// [VideoInteractionsState.copyWith] without overwriting an unset count.
  static int? _adjustCount(int? count, {required bool increment}) {
    if (count == null) return null;
    final raw = increment ? count + 1 : count - 1;
    return raw < 0 ? 0 : raw;
  }

  /// Handle repost toggle request.
  ///
  /// Mirrors [_onLikeToggled]: emits the optimistic state and returns
  /// immediately, scheduling the publish via [_publishRepost]. When the
  /// publish settles, [_publishRepost] dispatches a
  /// [_VideoInteractionsRepostSettled] event for reconciliation in
  /// [_onRepostSettled].
  Future<void> _onRepostToggled(
    VideoInteractionsRepostToggled event,
    Emitter<VideoInteractionsState> emit,
  ) async {
    // Cannot repost non-addressable events (missing d-tag).
    final addressableId = _addressableId;
    if (addressableId == null) {
      Log.warning(
        'VideoInteractionsBloc: Cannot repost - no addressable ID for '
        '$_eventId',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );
      return;
    }

    final wasReposted = state.isReposted;
    final wasCount = state.repostCount;
    final optimisticReposted = !wasReposted;

    emit(
      state.copyWith(
        isReposted: optimisticReposted,
        repostCount: _adjustCount(wasCount, increment: optimisticReposted),
      ),
    );

    unawaited(
      _publishRepost(
        addressableId: addressableId,
        optimisticReposted: optimisticReposted,
        wasReposted: wasReposted,
        wasCount: wasCount,
      ),
    );
  }

  Future<void> _publishRepost({
    required String addressableId,
    required bool optimisticReposted,
    required bool wasReposted,
    required int? wasCount,
  }) async {
    _RepostSettleOutcome outcome;
    try {
      final isNowReposted = await _repostsRepository.toggleRepost(
        addressableId: addressableId,
        originalAuthorPubkey: _authorPubkey,
        eventId: _eventId,
      );
      outcome = isNowReposted == optimisticReposted
          ? const _RepostSettleConfirmed()
          : _RepostSettleOutOfBand(actualIsReposted: isNowReposted);
    } on AlreadyRepostedException {
      outcome = const _RepostSettleAlready();
    } on NotRepostedException {
      outcome = const _RepostSettleNotReposted();
    } catch (e, stackTrace) {
      Log.error(
        'VideoInteractionsBloc: Repost toggle failed for $_eventId - $e',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );
      // Guarded for symmetry with the sibling add() below: _publishRepost
      // runs fire-and-forget via unawaited() and post-close addError
      // throws StateError.
      if (!isClosed) {
        addError(
          Reportable(
            e,
            context: VideoInteractionsReportableSites.publishRepost,
          ),
          stackTrace,
        );
      }
      outcome = _RepostSettleFailed(wasReposted: wasReposted);
    }

    if (isClosed) return;
    add(_VideoInteractionsRepostSettled(outcome: outcome, wasCount: wasCount));
  }

  void _onRepostSettled(
    _VideoInteractionsRepostSettled event,
    Emitter<VideoInteractionsState> emit,
  ) {
    switch (event.outcome) {
      case _RepostSettleConfirmed():
        return;
      case _RepostSettleOutOfBand(:final actualIsReposted):
        emit(
          state.copyWith(
            isReposted: actualIsReposted,
            repostCount: _adjustCount(
              event.wasCount,
              increment: actualIsReposted,
            ),
          ),
        );
      case _RepostSettleAlready():
        emit(state.copyWith(isReposted: true, repostCount: event.wasCount));
      case _RepostSettleNotReposted():
        emit(state.copyWith(isReposted: false, repostCount: event.wasCount));
      case _RepostSettleFailed(:final wasReposted):
        emit(
          state.copyWith(isReposted: wasReposted, repostCount: event.wasCount),
        );
    }
  }

  void _onCommentCountUpdated(
    VideoInteractionsCommentCountUpdated event,
    Emitter<VideoInteractionsState> emit,
  ) {
    // Only update the BLoC's own display state. Repository cache coherence is
    // handled automatically by CommentsRepository.loadComments(), which updates
    // _commentCountCache with the authoritative count on every full load.
    emit(state.copyWith(commentCount: event.commentCount));
  }
}
