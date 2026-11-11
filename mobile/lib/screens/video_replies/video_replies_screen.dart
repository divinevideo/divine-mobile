// ABOUTME: Full-screen list of the video replies to one of the creator's videos,
// ABOUTME: where they pin one to the front, hide single ones, and watch them.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show UserProfile, VideoEvent;
import 'package:openvine/blocs/video_replies/video_replies_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/sticker_responses_filter_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/open_video_responses_feed.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:video_responses_repository/video_responses_repository.dart'
    show RepliesCuration;

/// The video replies to the creator's video [videoId], published at
/// [videoAddress], as they manage them.
class VideoRepliesScreen extends ConsumerWidget {
  const VideoRepliesScreen({
    required this.videoId,
    required this.videoAddress,
    super.key,
  });

  /// The route's name.
  static const routeName = 'video-replies';

  /// The route's path.
  static const String path = RoutePaths.videoReplies;

  final String videoId;
  final String videoAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(videoResponsesRepositoryProvider);
    // Rebuilt when the creator's content settings change.
    final warnings = ref.watch(repliesWarningsProvider);
    return BlocProvider(
      // Another account saves its curation as itself.
      key: ValueKey((repository, warnings, videoId, videoAddress)),
      create: (_) {
        final cubit = VideoRepliesCubit(
          repository: repository,
          warnings: warnings,
          videoId: videoId,
          videoAddress: videoAddress,
          creatorPubkey: videoAddress.split(':').elementAtOrNull(1) ?? '',
        );
        runDetached(
          cubit.load(),
          'load the video replies to manage',
          logName: 'VideoRepliesScreen',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: const VideoRepliesView(),
    );
  }
}

/// The replies, or why there are none to show.
class VideoRepliesView extends StatelessWidget {
  @visibleForTesting
  const VideoRepliesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select(
      (VideoRepliesCubit cubit) => cubit.state.status,
    );
    return BlocListener<VideoRepliesCubit, VideoRepliesState>(
      listenWhen: (previous, current) =>
          previous.saveStatus != current.saveStatus &&
          current.saveStatus == VideoRepliesSaveStatus.failed,
      listener: (context, state) =>
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            DivineSnackbarContainer.snackBar(
              l10n.videoStickerRepliesSaveFailed,
            ),
          ),
      child: Scaffold(
        backgroundColor: context.vineColors.background,
        appBar: DiVineAppBar(
          title: l10n.videoStickerRepliesManageTitle,
          showBackButton: true,
          onBackPressed: () => context.safePop(
            fallback: VideoDetailRouteData(
              id: context.read<VideoRepliesCubit>().videoId,
            ).location,
          ),
        ),
        body: switch (status) {
          VideoRepliesStatus.loading => const Center(
            child: DivineCircularProgressIndicator(),
          ),
          VideoRepliesStatus.failure => _Message(
            text: l10n.videoStickerRepliesLoadFailed,
            onRetry: () => runDetached(
              context.read<VideoRepliesCubit>().load(),
              'load the video replies to manage again',
              logName: 'VideoRepliesScreen',
              category: LogCategory.ui,
            ),
          ),
          VideoRepliesStatus.loaded => const _ReplyList(),
        },
      ),
    );
  }
}

/// A line of text in the middle, with a button to try again.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;
    return Center(
      child: Padding(
        padding: const .all(32),
        child: Column(
          mainAxisSize: .min,
          spacing: 16,
          children: [
            Text(
              text,
              textAlign: .center,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            if (onRetry != null)
              DivineButton(
                label: context.l10n.videoStickerRepliesRetry,
                type: .secondary,
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

/// Every reply, the hidden ones too, each with its pin and hide buttons.
class _ReplyList extends StatelessWidget {
  const _ReplyList();

  @override
  Widget build(BuildContext context) {
    final replies = context.select(
      (VideoRepliesCubit cubit) => cubit.state.replies,
    );
    if (replies.isEmpty) {
      return _Message(text: context.l10n.videoStickerRepliesEmpty);
    }
    return ListView.separated(
      padding: const .all(16),
      itemCount: replies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ReplyTile(reply: replies[index]),
    );
  }
}

/// One reply: its thumbnail, who posted it, whether it is pinned or hidden,
/// and the buttons that change that. A tap watches the replies from it, but
/// never one the creator's content settings would hide.
class _ReplyTile extends ConsumerWidget {
  const _ReplyTile({required this.reply});

  final VideoEvent reply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    // By address when it has one, so a pin or a hide outlives an edit.
    final key = RepliesCuration.keyOf(reply);
    final (isPinned, isHidden) = context.select(
      (VideoRepliesCubit cubit) => (
        cubit.state.curation.pinnedId == key,
        // Also when the creator blocked its author.
        cubit.state.curation.hides(reply),
      ),
    );
    final cubit = context.read<VideoRepliesCubit>();
    // Funnelcake sends the author along; a reply read from the relays
    // carries none, so its profile is read.
    final name =
        reply.authorName ??
        ref
            .watch(fetchUserProfileProvider(reply.pubkey))
            .value
            ?.bestDisplayName ??
        UserProfile.generatedNameFor(reply.pubkey);
    // A pinned reply whose author the creator blocked is not shown either.
    final status = isHidden
        ? l10n.videoStickerRepliesHidden
        : isPinned
        ? l10n.videoStickerRepliesPinned
        : null;
    // Listed, blurred, so the creator can hide it, but not played: some of
    // what the settings hide is locked to hide for the account.
    final hiddenBySettings = ref.watch(repliesHiddenBySettingsProvider);
    final watchable = !hiddenBySettings(reply);
    return Semantics(
      button: watchable,
      label: watchable
          ? l10n.videoStickerRepliesWatchSemanticLabel(name)
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Read again: a label or a setting may have changed since the tile
          // was drawn.
          final hiddenBySettings = ref.read(repliesHiddenBySettingsProvider);
          if (hiddenBySettings(reply)) return;
          final shown = [
            for (final video in cubit.state.shown)
              if (!hiddenBySettings(video)) video,
          ];
          final videos = shown.any((video) => video.id == reply.id)
              ? shown
              : [reply];
          runDetached(
            openVideoResponsesFeed(
              context,
              feedRepository: ref.read(feedRepositoryProvider),
              videos: videos,
              index: videos.indexWhere((video) => video.id == reply.id),
              title: l10n.videoStickerRepliesManageTitle,
              sourceDetail: 'video_replies',
            ),
            'watch the video replies',
            logName: 'VideoRepliesScreen',
            category: LogCategory.ui,
          );
        },
        child: Row(
          spacing: 12,
          children: [
            _Thumbnail(reply: reply, dimmed: isHidden),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: 4,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: VineTheme.titleSmallFont(color: colors.primaryText),
                  ),
                  if (status != null)
                    Text(
                      status,
                      style: VineTheme.bodySmallFont(
                        color: colors.secondaryText,
                      ),
                    ),
                ],
              ),
            ),
            DivineButton(
              label: isPinned
                  ? l10n.videoStickerRepliesUnpin
                  : l10n.videoStickerRepliesPin,
              type: .secondary,
              size: .small,
              onPressed: () => runDetached(
                cubit.pinToggled(key),
                'pin a video reply',
                logName: 'VideoRepliesScreen',
                category: LogCategory.ui,
              ),
            ),
            DivineButton(
              label: isHidden
                  ? l10n.videoStickerRepliesShow
                  : l10n.videoStickerRepliesHide,
              type: .tertiary,
              size: .small,
              onPressed: () => runDetached(
                cubit.hideToggled(key),
                'hide a video reply',
                logName: 'VideoRepliesScreen',
                category: LogCategory.ui,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reply's thumbnail, blurred when the creator's settings warn about it, and
/// faded while it is hidden.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.reply, required this.dimmed});

  final VideoEvent reply;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final url = reply.thumbnailUrl;
    final placeholder = ColoredBox(color: context.vineColors.surfaceContainer);
    Widget picture = url == null
        ? placeholder
        : VineCachedImage(
            imageUrl: url,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    // The warnings the creator's settings call for: the page lists every
    // reply, so one their settings would hide is blurred here instead.
    if (reply.shouldShowWarning) {
      picture = ImageFiltered(
        imageFilter: .blur(sigmaX: 12, sigmaY: 12),
        child: picture,
      );
    }
    return ExcludeSemantics(
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 56, height: 75, child: picture),
        ),
      ),
    );
  }
}
