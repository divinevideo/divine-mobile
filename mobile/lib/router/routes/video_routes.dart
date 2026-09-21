// ABOUTME: Video routes (recorder, detail, sounds, editor, metadata, subtitle, fullscreen, engagement)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent, VideoEvent;
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/pooled_fullscreen_feed_route.dart';
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
import 'package:videos_repository/videos_repository.dart';

List<RouteBase> videoRoutes() {
  return [
    GoRoute(
      path: VideoRecorderScreen.path,
      name: VideoRecorderScreen.routeName,
      // The recorder is a modal creation mode, not the next screen in a
      // flow — open it with the fade-upwards transition.
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        child: VideoRecorderRoute(
          entryPoint: CreationEntryPoint.fromName(
            state.uri.queryParameters['entry_point'],
          ),
          autoRecord: VideoRecorderScreen.autoRecordFromQueryParameters(
            state.uri.queryParameters,
          ),
        ),
      ),
    ),
    GoRoute(
      path: CreatorAnalyticsScreen.path,
      name: CreatorAnalyticsScreen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const CreatorAnalyticsScreen(),
      routes: [
        GoRoute(
          path: PostAnalyticsDetailScreen.subpath,
          name: PostAnalyticsDetailScreen.routeName,
          parentNavigatorKey: NavigatorKeys.root,
          builder: (ctx, st) => PostAnalyticsDetailScreen(
            videoId: st.pathParameters['videoId'] ?? '',
            performance: extraAs<VideoPerformance>(st.extra),
          ),
        ),
      ],
    ),
    // Video detail route (for deep links)
    GoRoute(
      path: VideoDetailScreen.path,
      name: VideoDetailScreen.routeName,
      builder: (ctx, st) {
        final videoId = st.pathParameters['id'];
        if (videoId == null || videoId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
        }
        final extra = st.extra;
        final routeExtra = extra is VideoDetailRouteExtra ? extra : null;
        return VideoDetailScreen(
          videoId: videoId,
          autoOpenComments: routeExtra?.autoOpenComments ?? false,
          fallbackVideoIds: routeExtra?.fallbackVideoIds ?? const [],
          initialVideo: routeExtra?.initialVideo,
          dmReplyContext: routeExtra?.dmReplyContext,
        );
      },
    ),
    // Sound detail route (for audio reuse feature)
    GoRoute(
      path: SoundDetailScreen.path,
      name: SoundDetailScreen.routeName,
      builder: (ctx, st) {
        final soundId = st.pathParameters['id'];
        if (soundId == null || soundId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidSoundId);
        }
        // Extra can be an AudioEvent directly or a Map with both
        // sound and sourceVideo (for original sounds).
        final extra = st.extra;
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
        // Wrap in a loader that fetches the sound by ID
        return SoundDetailLoader(soundId: soundId);
      },
    ),
    // Original sound detail route (for videos without shared audio)
    GoRoute(
      path: OriginalSoundDetailScreen.path,
      name: OriginalSoundDetailScreen.routeName,
      builder: (ctx, st) {
        final pubkey = st.pathParameters['pubkey'];
        final video = extraAs<VideoEvent>(st.extra);
        if (pubkey == null || pubkey.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routerInvalidCreator);
        }
        return OriginalSoundDetailScreen(
          creatorPubkey: pubkey,
          sourceVideo: video,
        );
      },
    ),
    // Video editor route
    GoRoute(
      path: VideoEditorScreen.path,
      name: VideoEditorScreen.routeName,
      builder: (_, st) => VideoEditorScreen(
        fromLibrary: VideoEditorScreen.fromLibraryForRoute(st.uri),
      ),
    ),
    GoRoute(
      path: VideoEditorScreen.draftPathWithId,
      name: VideoEditorScreen.draftRouteName,
      builder: (_, st) {
        // The draft ID is optional if the user wants to continue editing
        // the draft.
        final draftId = st.pathParameters['draftId'];

        return VideoEditorScreen(
          draftId: draftId == null || draftId.isEmpty ? null : draftId,
          fromLibrary: VideoEditorScreen.fromLibraryForRoute(st.uri),
        );
      },
    ),
    GoRoute(
      path: VideoMetadataScreen.path,
      name: VideoMetadataScreen.routeName,
      builder: (_, st) => VideoMetadataScreen(
        draftMode: VideoMetadataScreen.draftModeFromName(
          st.uri.queryParameters[VideoMetadataScreen.draftModeQueryParameter],
        ),
      ),
    ),
    GoRoute(
      path: '${VideoMetadataEditScreen.path}/:videoId',
      name: VideoMetadataEditScreen.routeName,
      builder: (ctx, st) {
        final videoId = st.pathParameters['videoId'];
        if (videoId == null || videoId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
        }
        final prefetched = extraAs<VideoEvent>(st.extra);
        return VideoMetadataEditScreen(
          videoId: videoId,
          prefetched: prefetched,
        );
      },
    ),
    GoRoute(
      path: '${SubtitleEditorScreen.path}/:videoId',
      name: SubtitleEditorScreen.routeName,
      builder: (ctx, st) {
        final videoId = st.pathParameters['videoId'];
        if (videoId == null || videoId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
        }
        final prefetched = extraAs<VideoEvent>(st.extra);
        return SubtitleEditorScreen(videoId: videoId, prefetched: prefetched);
      },
    ),
    // Fullscreen video feed.
    GoRoute(
      path: PooledFullscreenVideoFeedScreen.path,
      name: PooledFullscreenVideoFeedScreen.routeName,
      redirect: (context, state) => fullscreenFeedRedirect(
        state.extra,
        fallbackVideoId:
            state.uri.queryParameters[PooledFullscreenVideoFeedScreen
                .videoQueryParameter],
      ),
      builder: buildPooledFullscreenFeed,
    ),
    // Engagement lists: who liked / reposted this video.
    // Reached from feed action buttons and grouped notification avatar stacks.
    GoRoute(
      path: '/video/:eventId/likers',
      name: VideoEngagementListScreen.likersRouteName,
      builder: (ctx, st) =>
          buildVideoEngagementList(ctx, st, VideoEngagementType.likers),
    ),
    GoRoute(
      path: '/video/:eventId/reposters',
      name: VideoEngagementListScreen.repostersRouteName,
      builder: (ctx, st) =>
          buildVideoEngagementList(ctx, st, VideoEngagementType.reposters),
    ),
  ];
}

/// Builds an engagement list for whichever `/video/:eventId` form the link
/// carried.
///
/// The path segment shares the detail route's identifier space, so a shared
/// link can arrive as a hex event id, a NIP-19 `note1` / `nevent1` / `naddr1`,
/// or a raw coordinate. The first-party API resolves a hex id or a d tag and
/// 404s on bech32, so an undecoded reference silently renders an empty list
/// instead of the video's likers (#9359 follow-up). Decoding here keeps the
/// sub-routes consistent with the detail route, which already resolves
/// through the same [VideoRouteRef].
@visibleForTesting
Widget buildVideoEngagementList(
  BuildContext ctx,
  GoRouterState st,
  VideoEngagementType type,
) {
  final ref = VideoRouteRef.parse(st.pathParameters['eventId'] ?? '');
  final lookupId = ref?.lookupId;
  if (lookupId == null) {
    // `parse` returns null for a blank segment — including one that is only
    // whitespace, which the old `raw.isEmpty` guard let past — and for a
    // NIP-19 reference that does not decode. Forwarding the raw segment
    // instead sent bech32 to an API that 404s on it and a d tag to an `#e`
    // filter that cannot match, and the screen rendered "No likes yet" for
    // a video that has likers: the exact failure this route's decoding
    // exists to remove, with no error state to explain it.
    return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
  }
  // An naddr carries the coordinate the liker query wants; an explicit `?a=`
  // from an in-app push still wins. A bare or empty `?a=` in an external
  // link is not explicit: `queryParameters['a']` is then '' rather than
  // null, so `??` kept it, and the decoded coordinate was lost. For
  // reposters that leaves a relay `#e` filter on a d tag and nothing else,
  // so the list renders empty — without the `?a=` the same link worked.
  final explicitCoordinate = st.uri.queryParameters['a'];
  return VideoEngagementListScreen(
    eventId: lookupId,
    type: type,
    addressableId: explicitCoordinate == null || explicitCoordinate.isEmpty
        ? ref?.addressableId
        : explicitCoordinate,
  );
}
