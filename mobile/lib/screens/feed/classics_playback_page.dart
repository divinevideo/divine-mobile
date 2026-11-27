// ABOUTME: Wires a selected classic to its own fullscreen queue.
// ABOUTME: Leaves the launching grid and Home Classics session independent.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/classics_feed/classics_feed_cubit.dart';
import 'package:openvine/config/adaptive_classics.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:videos_repository/videos_repository.dart';

/// Dependency boundary for a route-scoped, selected-classic feed.
class ClassicsPlaybackPage extends ConsumerWidget {
  const ClassicsPlaybackPage({
    required this.anchor,
    required this.screen,
    required this.adaptive,
    super.key,
  });

  final VideoEvent anchor;
  final PooledFullscreenVideoFeedScreen screen;

  /// Whether the route was eligible for adaptation when the clip opened.
  final bool adaptive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(videosRepositoryProvider);
    final analytics = ref.watch(analyticsServiceProvider);
    final viewer = ref.watch(nostrSessionProvider.select((s) => s.pubkey));
    bool isAdaptiveAllowed() =>
        adaptive &&
        ref.context.mounted &&
        ref.read(adaptiveClassicsEnabledProvider);
    return BlocProvider(
      key: ValueKey((viewer, repository, analytics, anchor.id)),
      create: (_) {
        late final ClassicFeedSession session;
        session = ClassicFeedSession(
          initialVideos: [anchor],
          loadPage: (request) {
            // Once the account stops being eligible the queue continues on
            // the archive, without a viewer or ranking context.
            if (session.personalizationRevoked || !isAdaptiveAllowed()) {
              return repository.getClassicVideos(
                limit: request.limit,
                cursor: request.cursor,
                archiveOnly: true,
              );
            }
            final contextId = analytics.privacyGeneration;
            final allowed = analytics.initializedAnalyticsConsent;
            return repository.getClassicRecommendations(
              request: request,
              userPubkey: allowed ? viewer : null,
              isCurrent: () =>
                  isAdaptiveAllowed() &&
                  contextId == analytics.privacyGeneration &&
                  allowed == analytics.initializedAnalyticsConsent,
            );
          },
          canPersonalize: () =>
              isAdaptiveAllowed() && analytics.initializedAnalyticsConsent,
          feedback: analytics.recommendationFeedback,
          privacyChanges: analytics.privacyChanges,
          removedVideoIds: repository.removedVideoIds,
          filter: repository.applyContentPreferences,
        );
        // A queue re-created after eligibility ended starts on the archive.
        if (!isAdaptiveAllowed()) session.revokePersonalization();
        return ClassicsFeedCubit(session: session);
      },
      child: _ClassicsPlaybackView(
        anchor: anchor,
        screen: screen,
        adaptive: adaptive,
      ),
    );
  }
}

class _ClassicsPlaybackView extends ConsumerWidget {
  const _ClassicsPlaybackView({
    required this.anchor,
    required this.screen,
    required this.adaptive,
  });

  final VideoEvent anchor;
  final PooledFullscreenVideoFeedScreen screen;
  final bool adaptive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cubit = context.read<ClassicsFeedCubit>();
    // The route keeps playing through a change of eligibility; only the
    // queue's remaining pages change source.
    if (adaptive) {
      ref.listen<bool>(adaptiveClassicsEnabledProvider, (_, allowed) {
        if (!allowed) cubit.revokePersonalization();
      });
    }
    return PooledFullscreenVideoFeedScreen(
      source: const ClassicVinesViewSource(),
      feedRepository: StreamFeedRepository(
        videos: cubit.videos,
        hasMore: cubit.hasMore,
        onLoadMore: cubit.loadMore,
      ),
      initialIndex: 0,
      initialVideoId: anchor.id,
      initialStableId: anchor.feedDedupKey,
      contextTitle: screen.contextTitle,
      sponsorName: screen.sponsorName,
      trafficSource: screen.trafficSource,
      sourceDetail: screen.sourceDetail,
      autoOpenComments: screen.autoOpenComments,
      focusCommentId: screen.focusCommentId,
      dmReplyContext: screen.dmReplyContext,
      onBack: screen.onBack,
      onActiveVideoChanged: (video) {
        cubit.activateVideo(video);
        screen.onActiveVideoChanged?.call(video);
      },
      onPageChanged: screen.onPageChanged,
      isAddYoursSeries: screen.isAddYoursSeries,
    );
  }
}
