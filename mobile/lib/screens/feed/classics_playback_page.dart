// ABOUTME: Wires a selected classic to its own adaptive fullscreen session.
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
    super.key,
  });

  final VideoEvent anchor;
  final PooledFullscreenVideoFeedScreen screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(videosRepositoryProvider);
    final analytics = ref.watch(analyticsServiceProvider);
    final viewer = ref.watch(nostrSessionProvider.select((s) => s.pubkey));
    bool isAdaptiveAllowed() =>
        ref.context.mounted && ref.read(adaptiveClassicsEnabledProvider);
    return BlocProvider(
      key: ValueKey((viewer, repository, analytics, anchor.id)),
      create: (_) => ClassicsFeedCubit(
        session: ClassicFeedSession(
          initialVideos: [anchor],
          loadPage: (request) {
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
        ),
      ),
      child: _ClassicsPlaybackView(anchor: anchor, screen: screen),
    );
  }
}

class _ClassicsPlaybackView extends StatelessWidget {
  const _ClassicsPlaybackView({required this.anchor, required this.screen});

  final VideoEvent anchor;
  final PooledFullscreenVideoFeedScreen screen;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ClassicsFeedCubit>();
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
      onActiveVideoChanged: cubit.activateVideo,
      onPageChanged: screen.onPageChanged,
    );
  }
}
