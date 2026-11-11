// ABOUTME: Video routes (recorder, detail, sounds, editor, metadata, subtitle, fullscreen, engagement)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent, VideoEvent;
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/pooled_fullscreen_feed_route.dart';
import 'package:openvine/router/recorder_sound_selection.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/router/widgets/sound_detail_loader.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/widgets/release_cached_images_on_dispose.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_routes.g.dart';

List<RouteBase> videoRoutes() => $appRoutes;

/// The recorder, a modal creation mode rather than the next screen in a
/// flow, so it opens with the fade-upwards transition.
@TypedGoRoute<VideoRecorderRouteData>(
  path: VideoRecorderScreen.path,
  name: VideoRecorderScreen.routeName,
)
class VideoRecorderRouteData extends GoRouteData with $VideoRecorderRouteData {
  const VideoRecorderRouteData({
    @TypedQueryParameter(
      name: VideoRecorderScreen.challengeRecordingQueryParameter,
    )
    this.challengeRecording,
    @TypedQueryParameter(name: VideoRecorderScreen.entryPointQueryParameter)
    this.entryPoint,
    this.$extra,
  });

  /// The id of the challenge this take is recorded for.
  final String? challengeRecording;

  /// A [CreationEntryPoint] name; anything else opens as
  /// [CreationEntryPoint.direct].
  final String? entryPoint;

  /// The [RecorderSoundSelection] to record over, read through [extraAs];
  /// absent after a deep link.
  final Object? $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadeUpwardsPage(
        state: state,
        child: ReleaseCachedImagesOnDispose(
          child: VideoRecorderRoute(
            initialSound: extraAs<RecorderSoundSelection>($extra),
            challengeRecordingId: challengeRecording,
            entryPoint: CreationEntryPoint.fromName(entryPoint),
            // Read from the URI, not a field: the screen owns the key and its
            // parsing, and pathForEntryPoint is the only location that sets it.
            autoRecord: VideoRecorderScreen.autoRecordFromQueryParameters(
              state.uri.queryParameters,
            ),
          ),
        ),
      );
}

@TypedGoRoute<CreatorAnalyticsRouteData>(
  path: CreatorAnalyticsScreen.path,
  name: CreatorAnalyticsScreen.routeName,
  routes: [
    TypedGoRoute<PostAnalyticsDetailRouteData>(
      path: PostAnalyticsDetailScreen.subpath,
      name: PostAnalyticsDetailScreen.routeName,
    ),
  ],
)
class CreatorAnalyticsRouteData extends GoRouteData
    with $CreatorAnalyticsRouteData {
  const CreatorAnalyticsRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const CreatorAnalyticsScreen();
}

/// One post's analytics, pushed from the creator's analytics list.
class PostAnalyticsDetailRouteData extends GoRouteData
    with $PostAnalyticsDetailRouteData {
  const PostAnalyticsDetailRouteData({required this.videoId, this.$extra});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  final String videoId;

  /// The tapped post's [VideoPerformance], read through [extraAs]; absent
  /// after a deep link, when the screen refetches it.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PostAnalyticsDetailScreen(
        videoId: videoId,
        performance: extraAs<VideoPerformance>($extra),
      );
}

/// A video by hex id, `nevent1`, `naddr1` or coordinate; the screen
/// resolves the reference.
@TypedGoRoute<VideoDetailRouteData>(
  path: VideoDetailScreen.path,
  name: VideoDetailScreen.routeName,
)
class VideoDetailRouteData extends GoRouteData with $VideoDetailRouteData {
  const VideoDetailRouteData({required this.id, this.$extra});

  final String id;

  /// A [VideoDetailRouteExtra] warm start, read through [extraAs]; absent
  /// after a deep link.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (id.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidVideoId);
    }
    final routeExtra = extraAs<VideoDetailRouteExtra>($extra);
    return VideoDetailScreen(
      videoId: id,
      autoOpenComments: routeExtra?.autoOpenComments ?? false,
      fallbackVideoIds: routeExtra?.fallbackVideoIds ?? const [],
      initialVideo: routeExtra?.initialVideo,
      dmReplyContext: routeExtra?.dmReplyContext,
      focusCommentId: routeExtra?.focusCommentId,
    );
  }
}

/// A sound, for reusing its audio.
@TypedGoRoute<SoundDetailRouteData>(
  path: SoundDetailScreen.path,
  name: SoundDetailScreen.routeName,
)
class SoundDetailRouteData extends GoRouteData with $SoundDetailRouteData {
  const SoundDetailRouteData({required this.id, this.$extra});

  final String id;

  /// The [AudioEvent], or for an original sound a map with `sound` and
  /// `sourceVideo`; absent after a deep link, when the sound loads by [id].
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (id.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidSoundId);
    }
    final extra = $extra;
    AudioEvent? sound;
    VideoEvent? sourceVideo;
    if (extra is AudioEvent) {
      sound = extra;
    } else if (extra is Map) {
      sound = extraAs<AudioEvent>(extra['sound']);
      sourceVideo = extraAs<VideoEvent>(extra['sourceVideo']);
    }
    if (sound != null) {
      return SoundDetailScreen(sound: sound, sourceVideo: sourceVideo);
    }
    return SoundDetailLoader(soundId: id);
  }
}

/// A creator's original sound, for videos without shared audio.
@TypedGoRoute<OriginalSoundDetailRouteData>(
  path: OriginalSoundDetailScreen.path,
  name: OriginalSoundDetailScreen.routeName,
)
class OriginalSoundDetailRouteData extends GoRouteData
    with $OriginalSoundDetailRouteData {
  const OriginalSoundDetailRouteData({required this.pubkey, this.$extra});

  final String pubkey;

  /// The [VideoEvent] the sound came from, read through [extraAs]; absent
  /// after a deep link.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (pubkey.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routerInvalidCreator);
    }
    return OriginalSoundDetailScreen(
      creatorPubkey: pubkey,
      sourceVideo: extraAs<VideoEvent>($extra),
    );
  }
}

@TypedGoRoute<VideoEditorRouteData>(
  path: VideoEditorScreen.path,
  name: VideoEditorScreen.routeName,
)
class VideoEditorRouteData extends GoRouteData with $VideoEditorRouteData {
  const VideoEditorRouteData({
    @TypedQueryParameter(name: VideoEditorScreen.originQueryParameter)
    this.from,
  });

  /// [VideoEditorScreen.libraryOrigin] when the Library opened the editor.
  final String? from;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ReleaseCachedImagesOnDispose(
        child: VideoEditorScreen(
          fromLibrary: VideoEditorScreen.fromLibraryForRoute(state.uri),
        ),
      );
}

/// The editor reopened on a saved draft.
@TypedGoRoute<VideoEditorDraftRouteData>(
  path: VideoEditorScreen.draftPathWithId,
  name: VideoEditorScreen.draftRouteName,
)
class VideoEditorDraftRouteData extends GoRouteData
    with $VideoEditorDraftRouteData {
  const VideoEditorDraftRouteData({
    required this.draftId,
    @TypedQueryParameter(name: VideoEditorScreen.originQueryParameter)
    this.from,
  });

  final String draftId;

  /// See [VideoEditorRouteData.from].
  final String? from;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ReleaseCachedImagesOnDispose(
        child: VideoEditorScreen(
          draftId: draftId.isEmpty ? null : draftId,
          fromLibrary: VideoEditorScreen.fromLibraryForRoute(state.uri),
        ),
      );
}

@TypedGoRoute<VideoMetadataRouteData>(
  path: VideoMetadataScreen.path,
  name: VideoMetadataScreen.routeName,
)
class VideoMetadataRouteData extends GoRouteData with $VideoMetadataRouteData {
  const VideoMetadataRouteData({
    @TypedQueryParameter(name: VideoMetadataScreen.draftModeQueryParameter)
    this.mode,
  });

  /// The draft editor's recorder mode, as read by
  /// [VideoMetadataScreen.draftModeFromName]; absent for a recorder flow.
  final String? mode;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      VideoMetadataScreen(
        draftMode: VideoMetadataScreen.draftModeFromName(mode),
      );
}

/// The metadata editor for one of the viewer's published videos.
@TypedGoRoute<VideoMetadataEditRouteData>(
  path: VideoMetadataEditScreen.pathWithId,
  name: VideoMetadataEditScreen.routeName,
)
class VideoMetadataEditRouteData extends GoRouteData
    with $VideoMetadataEditRouteData {
  const VideoMetadataEditRouteData({required this.videoId, this.$extra});

  final String videoId;

  /// The [VideoEvent] to start from, read through [extraAs]; absent after a
  /// deep link, when the screen resolves [videoId].
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (videoId.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidVideoId);
    }
    return VideoMetadataEditScreen(
      videoId: videoId,
      prefetched: extraAs<VideoEvent>($extra),
    );
  }
}

/// The subtitle editor for one of the viewer's published videos.
@TypedGoRoute<SubtitleEditorRouteData>(
  path: SubtitleEditorScreen.pathWithId,
  name: SubtitleEditorScreen.routeName,
)
class SubtitleEditorRouteData extends GoRouteData
    with $SubtitleEditorRouteData {
  const SubtitleEditorRouteData({required this.videoId, this.$extra});

  final String videoId;

  /// See [VideoMetadataEditRouteData.$extra].
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (videoId.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidVideoId);
    }
    return SubtitleEditorScreen(
      videoId: videoId,
      prefetched: extraAs<VideoEvent>($extra),
    );
  }
}

/// The fullscreen video feed. Its feed travels in `extra` only, so without
/// one the route falls back to the [video] the URL names.
@TypedGoRoute<PooledFullscreenVideoFeedRouteData>(
  path: PooledFullscreenVideoFeedScreen.path,
  name: PooledFullscreenVideoFeedScreen.routeName,
)
class PooledFullscreenVideoFeedRouteData extends GoRouteData
    with $PooledFullscreenVideoFeedRouteData {
  const PooledFullscreenVideoFeedRouteData({
    @TypedQueryParameter(
      name: PooledFullscreenVideoFeedScreen.videoQueryParameter,
    )
    this.video,
    this.$extra,
  });

  /// The selected video's id, which outlives a lost [$extra].
  final String? video;

  /// The [PooledFullscreenVideoFeedArgs] or
  /// [ProfilePooledFullscreenVideoFeedArgs] carrying the feed.
  final Object? $extra;

  @override
  String? redirect(BuildContext context, GoRouterState state) =>
      fullscreenFeedRedirect($extra, fallbackVideoId: video);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      buildPooledFullscreenFeed(context, state);
}

/// Who liked a video. Reached from feed action buttons and grouped
/// notification avatar stacks.
@TypedGoRoute<VideoLikersRouteData>(
  path: VideoEngagementListScreen.likersPath,
  name: VideoEngagementListScreen.likersRouteName,
)
class VideoLikersRouteData extends GoRouteData with $VideoLikersRouteData {
  const VideoLikersRouteData({
    required this.eventId,
    @TypedQueryParameter(
      name: VideoEngagementListScreen.coordinateQueryParameter,
    )
    this.a,
  });

  /// The video in any form the detail route accepts.
  final String eventId;

  /// The video's `kind:pubkey:d-tag` coordinate, named after the `a` tag.
  final String? a;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      _buildEngagementList(
        context,
        eventId: eventId,
        coordinate: a,
        type: VideoEngagementType.likers,
      );
}

/// Who reposted a video, reached the same ways as [VideoLikersRouteData].
@TypedGoRoute<VideoRepostersRouteData>(
  path: VideoEngagementListScreen.repostersPath,
  name: VideoEngagementListScreen.repostersRouteName,
)
class VideoRepostersRouteData extends GoRouteData
    with $VideoRepostersRouteData {
  const VideoRepostersRouteData({
    required this.eventId,
    @TypedQueryParameter(
      name: VideoEngagementListScreen.coordinateQueryParameter,
    )
    this.a,
  });

  /// See [VideoLikersRouteData.eventId].
  final String eventId;

  /// See [VideoLikersRouteData.a].
  final String? a;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      _buildEngagementList(
        context,
        eventId: eventId,
        coordinate: a,
        type: VideoEngagementType.reposters,
      );
}

/// Builds an engagement list for whichever form of the video [eventId]
/// carries.
///
/// The path segment shares the detail route's identifier space, so a shared
/// link can arrive as a hex event id, a NIP-19 `note1` / `nevent1` /
/// `naddr1`, or a raw coordinate. The first-party API resolves a hex id or a
/// d tag and 404s on bech32, so an undecoded reference silently renders an
/// empty list instead of the video's likers (#9359 follow-up).
///
/// The detail route passes its segment through untouched, and
/// `VideosRepository.lookupVideoForRouteId` resolves it to a concrete
/// VideoEvent. These screens query by identifier and have no resolver of
/// their own, so the decode happens here — which also means they never learn
/// the event id behind an addressable reference, and the relay `#e` arm stays
/// unusable for one.
Widget _buildEngagementList(
  BuildContext context, {
  required String eventId,
  required String? coordinate,
  required VideoEngagementType type,
}) {
  final ref = VideoRouteRef.parse(eventId);
  final lookupId = ref?.lookupId;
  if (lookupId == null) {
    // `parse` returns null for a blank segment, whitespace included, for a
    // NIP-19 reference that does not decode, and for a video coordinate whose
    // author is not a hex pubkey. Forwarding the raw segment sent bech32 to an
    // API that 404s on it and a d tag to an `#e` filter that cannot match, and
    // the screen rendered "No likes yet" for a video that has likers, with no
    // error state to explain it.
    return RouteErrorScreen(message: context.l10n.routeInvalidVideoId);
  }
  // An naddr carries the coordinate the liker query wants; an explicit `?a=`
  // from an in-app push still wins. A bare or empty `?a=` in an external link
  // is not explicit: it reads as '' rather than null, and keeping it lost the
  // decoded coordinate, leaving the reposters query an `#e` filter on a d tag.
  return VideoEngagementListScreen(
    eventId: lookupId,
    type: type,
    addressableId: coordinate == null || coordinate.isEmpty
        ? ref?.addressableId
        : coordinate,
  );
}
