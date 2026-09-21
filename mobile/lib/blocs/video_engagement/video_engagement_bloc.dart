// ABOUTME: BLoC for fetching the list of users who liked or reposted a video.
// ABOUTME: Backs engagement list screens opened from feed buttons/notifications.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_engagement_event.dart';
part 'video_engagement_state.dart';

/// BLoC for the "who liked / reposted this video" engagement list.
///
/// Reads the relevant fetch method on [LikesRepository] /
/// [RepostsRepository] based on [type], and emits the resulting pubkey
/// list to the UI.
///
/// After fetching pubkeys, calls [ProfileRepository.fetchBatchProfiles] with a
/// 2-second timeout to pre-warm the local Drift cache before the UI renders.
/// This holds the loading state for up to 2 seconds so [UserProfileTile]
/// widgets can display real names on first paint instead of the generated
/// fallback placeholder. On timeout or error the list is still emitted as
/// success — per-tile [userProfileReactiveProvider] fetches serve as fallback.
class VideoEngagementBloc
    extends Bloc<VideoEngagementEvent, VideoEngagementState> {
  VideoEngagementBloc({
    required this.eventId,
    required this.type,
    required LikesRepository likesRepository,
    required RepostsRepository repostsRepository,
    required ProfileRepository? profileRepository,
    this.addressableId,
  }) : _likesRepository = likesRepository,
       _repostsRepository = repostsRepository,
       _profileRepository = profileRepository,
       super(VideoEngagementState(type: type)) {
    on<VideoEngagementLoadRequested>(
      _onLoadRequested,
      transformer: droppable(),
    );
    on<VideoEngagementLoadMoreRequested>(
      _onLoadMoreRequested,
      transformer: droppable(),
    );
  }

  /// Identifier the engagement query addresses the video by.
  ///
  /// Usually the hex event id. For an addressable reference that names no
  /// single version — an `naddr1` or a raw coordinate — this is the `d` tag,
  /// which the first-party API resolves the same way.
  final String eventId;

  /// Optional `kind:pubkey:d-tag` for addressable video events (Kind 30000+).
  final String? addressableId;

  /// Whether to load likers or reposters.
  final VideoEngagementType type;

  /// The `/video/:id` reference that names this list's video most precisely.
  ///
  /// A hex [eventId] names one exact event and is returned as is. Otherwise
  /// [eventId] is a `d` tag, which the detail route resolves without an
  /// author, so the coordinate in [addressableId] is preferred when the link
  /// carried one: a same-d-tag video from another creator must not answer
  /// for this one.
  String get videoRouteId {
    if (NostrHexUtils.isValidEventId(eventId)) return eventId;
    final coordinate = addressableId;
    if (coordinate != null && coordinate.isNotEmpty) return coordinate;
    return eventId;
  }

  final LikesRepository _likesRepository;
  final RepostsRepository _repostsRepository;

  /// Nullable because [profileRepositoryProvider] legitimately returns `null`
  /// before authentication. When non-null, profiles for the returned pubkeys
  /// are batch-fetched into the local cache before the success state is emitted.
  final ProfileRepository? _profileRepository;

  static const _profilePrefetchTimeout = Duration(seconds: 2);

  Future<void> _onLoadRequested(
    VideoEngagementLoadRequested event,
    Emitter<VideoEngagementState> emit,
  ) async {
    emit(state.copyWith(status: VideoEngagementStatus.loading));
    try {
      Log.info(
        'Loading video engagement list: type=${type.name}, '
        'eventId=$eventId, addressableId=${addressableId ?? '(none)'}',
        name: 'VideoEngagementBloc',
        category: LogCategory.video,
      );
      final page = await _fetchPage();
      await _prewarmProfiles(page.pubkeys);

      emit(
        state.copyWith(
          status: VideoEngagementStatus.success,
          pubkeys: page.pubkeys,
          loadMoreStatus: VideoEngagementLoadMoreStatus.idle,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: VideoEngagementStatus.failure));
    }
  }

  /// Appends the next page to the list already on screen.
  ///
  /// The list is capped at [FunnelcakeApiClient.maxVideoLikersLimit] per
  /// request, so a video with thousands of likers needs this to reach past
  /// the first page (#9358).
  Future<void> _onLoadMoreRequested(
    VideoEngagementLoadMoreRequested event,
    Emitter<VideoEngagementState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null) return;
    // Only an explicit retry restarts after a failure: the view dispatches
    // freely from its item builder, so auto-resuming would re-fire on the
    // rebuild the failure itself causes. Concurrency needs no guard —
    // this handler is droppable and the view dispatches only from idle.
    if (state.loadMoreStatus == VideoEngagementLoadMoreStatus.failure &&
        !event.retry) {
      return;
    }

    emit(
      state.copyWith(
        loadMoreStatus: VideoEngagementLoadMoreStatus.inProgress,
      ),
    );
    try {
      final page = await _fetchPage(cursor: cursor);

      // `seen.add` answers false for a pubkey already shown, so this dedupes
      // both against earlier pages and within this one. The survivors are
      // also the only profiles still worth warming.
      final seen = state.pubkeys.toSet();
      final added = page.pubkeys.where(seen.add).toList();
      await _prewarmProfiles(added);

      emit(
        state.copyWith(
          pubkeys: [...state.pubkeys, ...added],
          loadMoreStatus: VideoEngagementLoadMoreStatus.idle,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      // Keep the loaded pubkeys and the cursor so a retry can continue.
      emit(
        state.copyWith(
          loadMoreStatus: VideoEngagementLoadMoreStatus.failure,
        ),
      );
    }
  }

  /// Pre-warms the profile cache so [UserProfileTile] widgets render real
  /// names on first paint.
  ///
  /// Awaits the batch fetch bounded to [_profilePrefetchTimeout], so the
  /// caller's loading state is held for up to that duration. On timeout or
  /// error the list still appears — the per-tile
  /// `userProfileReactiveProvider` fetch acts as fallback.
  Future<void> _prewarmProfiles(List<String> pubkeys) async {
    if (pubkeys.isEmpty) return;
    await _profileRepository
        ?.fetchBatchProfiles(pubkeys: pubkeys)
        .timeout(_profilePrefetchTimeout)
        .catchError((_) => <String, UserProfile>{});
  }

  /// One page of the engagement list.
  ///
  /// Reposters carry no cursor: they are served from relays in a single
  /// page, so [VideoEngagementState.hasMore] stays false for that type.
  Future<({List<String> pubkeys, String? nextCursor})> _fetchPage({
    String? cursor,
  }) async {
    switch (type) {
      case VideoEngagementType.likers:
        final page = await _likesRepository.fetchEventLikers(
          eventId: eventId,
          addressableId: addressableId,
          cursor: cursor,
        );
        return (pubkeys: page.pubkeys, nextCursor: page.nextCursor);
      case VideoEngagementType.reposters:
        final pubkeys = await _repostsRepository.fetchEventReposters(
          eventId: eventId,
          addressableId: addressableId,
        );
        return (pubkeys: pubkeys, nextCursor: null);
    }
  }
}
