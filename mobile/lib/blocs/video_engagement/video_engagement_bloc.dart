// ABOUTME: BLoC for fetching the list of users who liked or reposted a video.
// ABOUTME: Backs engagement list screens opened from feed buttons/notifications.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_engagement_event.dart';
part 'video_engagement_state.dart';

/// BLoC for the "who liked / reposted this video" engagement list.
///
/// Reads the relevant fetch method on [LikesRepository] /
/// [RepostsRepository] based on [type], and emits the resulting pubkey
/// list to the UI.
///
/// A link that names the video by coordinate (an `naddr1`, a raw coordinate,
/// or a `d` tag with `?a=`) is first resolved to that author's event through
/// [VideosRepository.lookupVideoForRouteId], and the lists are queried by
/// that event id. The first-party API resolves a bare `d` tag to the newest
/// video any account posted under it, and answers 404 for a 64-hex one
/// (#10929).
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
    required VideosRepository videosRepository,
    required ProfileRepository? profileRepository,
    this.addressableId,
  }) : _likesRepository = likesRepository,
       _repostsRepository = repostsRepository,
       _videosRepository = videosRepository,
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

  /// Identifier the route addresses the video by.
  ///
  /// Usually the hex event id. For an addressable reference that names no
  /// single version — an `naddr1` or a raw coordinate — this is the `d` tag.
  /// A Divine upload's `d` tag is the file's sha256, so it is 64-character
  /// hex too and cannot be told from an event id by its shape.
  final String eventId;

  /// Optional `kind:pubkey:d-tag` for addressable video events (Kind 30000+).
  final String? addressableId;

  /// Whether to load likers or reposters.
  final VideoEngagementType type;

  /// The `/video/:id` reference that names this list's video most precisely.
  ///
  /// An [eventId] that names one exact event is returned as is. When it is
  /// only a `d` tag, which the detail route resolves without an author, the
  /// coordinate in [addressableId] is preferred when the link carried one: a
  /// same-d-tag video from another creator must not answer for this one.
  String get videoRouteId {
    final coordinate = addressableId;
    if (_eventIdIsDTag && coordinate != null && coordinate.isNotEmpty) {
      return coordinate;
    }
    return eventId;
  }

  /// Whether [eventId] is a `d` tag rather than an event id.
  ///
  /// True when it cannot be an event id at all, or when it equals the `d` tag
  /// of [addressableId]: a 64-hex Divine `d` tag passes every event-id check.
  bool get _eventIdIsDTag {
    if (!NostrHexUtils.isValidEventId(eventId)) return true;
    final dTag = _authorCoordinate?.stableId;
    return dTag != null && dTag.toLowerCase() == eventId.toLowerCase();
  }

  /// [addressableId] decoded, when it is a video coordinate naming an author.
  ///
  /// Only such a coordinate may be resolved: the route lookup treats any
  /// other string as a bare `d` tag, which is the unscoped lookup this bloc
  /// resolves to avoid.
  VideoRouteRef? get _authorCoordinate {
    final coordinate = addressableId;
    if (coordinate == null || coordinate.isEmpty) return null;
    final ref = VideoRouteRef.parse(coordinate);
    return ref?.addressablePubkey == null ? null : ref;
  }

  final LikesRepository _likesRepository;
  final RepostsRepository _repostsRepository;
  final VideosRepository _videosRepository;

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
      final resolvedEventId = await _resolveEventId();
      final page = await _fetchPage(queryEventId: resolvedEventId ?? eventId);
      if (!page.isComplete && page.pubkeys.isEmpty) {
        // A relay read that stopped before finishing and found nobody says
        // nothing about who liked or reposted, so it is not "nobody" (#10846).
        Log.warning(
          'Video engagement read did not finish and found nobody: '
          'type=${type.name}, eventId=$eventId',
          name: 'VideoEngagementBloc',
          category: LogCategory.video,
        );
        emit(state.copyWith(status: VideoEngagementStatus.failure));
        return;
      }
      await _prewarmProfiles(page.pubkeys);

      emit(
        state.copyWith(
          status: VideoEngagementStatus.success,
          pubkeys: page.pubkeys,
          loadMoreStatus: VideoEngagementLoadMoreStatus.idle,
          nextCursor: page.nextCursor,
          isComplete: page.isComplete,
          resolvedEventId: resolvedEventId,
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
      final page = await _fetchPage(
        cursor: cursor,
        queryEventId: state.resolvedEventId ?? eventId,
      );

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

  /// The event id of the video the link's coordinate names, or null when the
  /// link named an exact event or the coordinate could not be resolved.
  ///
  /// A failed or empty lookup falls back to querying by [eventId] and
  /// [addressableId] as the link gave them.
  Future<String?> _resolveEventId() async {
    final coordinate = _authorCoordinate;
    if (coordinate == null || !_eventIdIsDTag) return null;
    final routeId = coordinate.addressableId!;
    try {
      final lookup = await _videosRepository.lookupVideoForRouteId(routeId);
      final resolved = switch (lookup) {
        VideoRouteFound(:final video) => video.id,
        VideoRouteHiddenByFilter(:final video) => video.id,
        VideoRouteMissing() => null,
      };
      if (resolved == null) {
        Log.info(
          'No video found for engagement coordinate $routeId; '
          'querying by d tag $eventId',
          name: 'VideoEngagementBloc',
          category: LogCategory.video,
        );
      }
      return resolved;
    } on FunnelcakeException catch (e) {
      _logUnresolved(routeId, e);
      return null;
    } on RelayReadUnavailableException catch (e) {
      _logUnresolved(routeId, e);
      return null;
    } on TimeoutException catch (e) {
      _logUnresolved(routeId, e);
      return null;
    }
  }

  /// Logs a coordinate lookup that could not reach any source; the caller
  /// then queries by [eventId] as the link gave it.
  void _logUnresolved(String routeId, Exception error) {
    Log.warning(
      'Could not resolve engagement coordinate $routeId ($error); '
      'querying by d tag $eventId',
      name: 'VideoEngagementBloc',
      category: LogCategory.video,
    );
  }

  /// One page of the engagement list.
  ///
  /// Reposters carry no cursor: they are served from relays in a single
  /// page holding at most the newest 500 reposts, so
  /// [VideoEngagementState.hasMore] stays false for that type.
  Future<({List<String> pubkeys, String? nextCursor, bool isComplete})>
  _fetchPage({required String queryEventId, String? cursor}) async {
    switch (type) {
      case VideoEngagementType.likers:
        final page = await _likesRepository.fetchEventLikers(
          eventId: queryEventId,
          addressableId: addressableId,
          cursor: cursor,
        );
        return (
          pubkeys: page.pubkeys,
          nextCursor: page.nextCursor,
          isComplete: page.isComplete,
        );
      case VideoEngagementType.reposters:
        final page = await _repostsRepository.fetchEventReposters(
          eventId: queryEventId,
          addressableId: addressableId,
        );
        return (
          pubkeys: page.pubkeys,
          nextCursor: null,
          isComplete: page.isComplete,
        );
    }
  }
}
