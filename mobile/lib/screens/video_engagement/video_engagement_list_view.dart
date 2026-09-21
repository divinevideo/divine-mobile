// ABOUTME: Pure StatelessWidget View for the video engagement (likers/reposters) list.
// ABOUTME: Consumes VideoEngagementBloc via BlocBuilder — zero Riverpod dependency.
// ABOUTME: Provided and owned by VideoEngagementListScreen (the Page layer).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Inner View for the video engagement list screen.
///
/// Pure [StatelessWidget] — reads state exclusively from [VideoEngagementBloc]
/// via [BlocBuilder]/[context.select]. Has no Riverpod dependency.
///
/// See also: [VideoEngagementListScreen], which is the [ConsumerWidget] Page
/// that wires Riverpod dependencies into [VideoEngagementBloc] and provides
/// this view.
class VideoEngagementListView extends StatelessWidget {
  const VideoEngagementListView({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.select(
      (VideoEngagementBloc bloc) => bloc.state.type,
    );
    final title = switch (type) {
      VideoEngagementType.likers => context.l10n.videoEngagementLikersTitle,
      VideoEngagementType.reposters =>
        context.l10n.videoEngagementRepostersTitle,
    };

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        titleWidget: Text(
          title,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        showBackButton: true,
        // safePop: both routes that build this view are registered flat and
        // top-level, so a link or an account swap enters them on a one-entry
        // stack and a plain pop empties the router (#9359). The fallback is
        // the bloc's videoRouteId, not its eventId: for an naddr1 or
        // coordinate link the latter is a bare d tag, which the detail route
        // would resolve without the author the link carried.
        onBackPressed: () => context.safePop(
          fallback: RoutePaths.videoDetailForId(
            context.read<VideoEngagementBloc>().videoRouteId,
          ),
        ),
        backButtonSemanticLabel: context.l10n.commonBack,
      ),
      body: BlocBuilder<VideoEngagementBloc, VideoEngagementState>(
        builder: (context, state) {
          return switch (state.status) {
            VideoEngagementStatus.initial ||
            VideoEngagementStatus.loading => const Center(
              child: DivineCircularProgressIndicator(),
            ),
            VideoEngagementStatus.success when state.pubkeys.isEmpty =>
              _EngagementEmptyState(type: state.type),
            VideoEngagementStatus.success => _EngagementListBody(
              pubkeys: state.pubkeys,
              hasMore: state.hasMore,
              loadMoreStatus: state.loadMoreStatus,
            ),
            VideoEngagementStatus.failure => const _EngagementErrorBody(),
          };
        },
      ),
    );
  }
}

class _EngagementListBody extends StatelessWidget {
  const _EngagementListBody({
    required this.pubkeys,
    required this.hasMore,
    required this.loadMoreStatus,
  });

  /// How far from the end to ask for the next page, so it is already in
  /// flight by the time the user reaches the bottom.
  static const _loadMoreThreshold = 3;

  final List<String> pubkeys;
  final bool hasMore;
  final VideoEngagementLoadMoreStatus loadMoreStatus;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        context.read<VideoEngagementBloc>().add(
          const VideoEngagementLoadRequested(),
        );
      },
      child: ListView.builder(
        itemCount: pubkeys.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= pubkeys.length) {
            return _LoadMoreTrailer(status: loadMoreStatus);
          }

          if (hasMore &&
              loadMoreStatus == VideoEngagementLoadMoreStatus.idle &&
              index >= pubkeys.length - _loadMoreThreshold) {
            context.read<VideoEngagementBloc>().add(
              const VideoEngagementLoadMoreRequested(),
            );
          }

          final pubkey = pubkeys[index];
          return UserProfileTile(
            pubkey: pubkey,
            onTap: () => context.pushOtherProfile(pubkey),
            showFollowButton: false,
            index: index,
          );
        },
      ),
    );
  }
}

/// Row shown below the last liker while more pages remain.
class _LoadMoreTrailer extends StatelessWidget {
  const _LoadMoreTrailer({required this.status});

  final VideoEngagementLoadMoreStatus status;

  @override
  Widget build(BuildContext context) {
    // The list only auto-triggers from idle, so a failed page needs an
    // explicit way back — otherwise the remaining people are unreachable
    // short of pulling to refresh the whole list.
    if (status == VideoEngagementLoadMoreStatus.failure) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: DivineButton(
            label: context.l10n.commonRetry,
            type: DivineButtonType.link,
            size: DivineButtonSize.small,
            onPressed: () => context.read<VideoEngagementBloc>().add(
              const VideoEngagementLoadMoreRequested(retry: true),
            ),
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: DivineCircularProgressIndicator()),
    );
  }
}

class _EngagementEmptyState extends StatelessWidget {
  const _EngagementEmptyState({required this.type});

  final VideoEngagementType type;

  @override
  Widget build(BuildContext context) {
    final message = switch (type) {
      VideoEngagementType.likers => context.l10n.videoEngagementLikersEmpty,
      VideoEngagementType.reposters =>
        context.l10n.videoEngagementRepostersEmpty,
    };
    final icon = switch (type) {
      VideoEngagementType.likers => DivineIconName.heart,
      VideoEngagementType.reposters => DivineIconName.repeat,
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(icon: icon, size: 64, color: context.vineColors.mutedText),
          const SizedBox(height: 16),
          Text(
            message,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementErrorBody extends StatelessWidget {
  const _EngagementErrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 64,
            color: context.vineColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.videoEngagementLoadFailed,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<VideoEngagementBloc>().add(
              const VideoEngagementLoadRequested(),
            ),
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
