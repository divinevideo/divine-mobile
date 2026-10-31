// ABOUTME: A question, Add yours or replies sticker on the playing video, drawn
// ABOUTME: over its frames with who joined or replied, and what a tap opens.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/blocs/sticker_responses/sticker_responses_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/add_yours_context.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/add_yours_context_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/routes/interactive_sticker_routes.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/open_video_responses_feed.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_editor/social_sticker/interactive_sticker_card.dart';
import 'package:unified_logger/unified_logger.dart';

/// The question, Add yours or replies [region] on [video], as the frames
/// show it until [isActive], and from then on with who joined or replied,
/// opening what a tap on it opens.
///
/// Only the active video reads who joined or replied, so the videos the feed
/// loads ahead ask for nothing. [onInteraction] is called when the viewer
/// taps it, so the feed does not move on under them.
class InteractiveStickerOverlay extends ConsumerWidget {
  const InteractiveStickerOverlay({
    required this.region,
    required this.video,
    required this.data,
    required this.isActive,
    this.onInteraction,
    super.key,
  });

  final VideoStickerRegion region;
  final VideoEvent video;

  /// The sticker as the region publishes it.
  final SocialStickerData data;

  final bool isActive;
  final VoidCallback? onInteraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isActive) {
      return IgnorePointer(child: InteractiveStickerCopy(data: data));
    }
    final viewer = ref.watch(nostrSessionProvider).pubkey;
    final isCreator = viewer != null && viewer == video.pubkey.toLowerCase();
    if (region.kind == VideoStickerKind.question) {
      return InteractiveStickerCopy(
        data: data,
        // The creator does not answer their own question.
        onAnswer: isCreator
            ? null
            : () {
                onInteraction?.call();
                _answer(context, isSignedIn: viewer != null);
              },
      );
    }
    final repository = ref.watch(videoResponsesRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    return BlocProvider(
      // Another account has its own blocks, and the creator their own view.
      key: ValueKey((repository, blocklistRepository, region, video.id)),
      create: (_) {
        final cubit = StickerResponsesCubit(
          repository: repository,
          blocklistRepository: blocklistRepository,
          video: video,
          region: region,
        );
        runDetached(
          cubit.load(),
          'load who joined or replied for a sticker',
          logName: 'InteractiveStickerOverlay',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: _ResponsesSticker(
        region: region,
        video: video,
        data: data,
        isSignedIn: viewer != null,
        isCreator: isCreator,
        onInteraction: onInteraction,
      ),
    );
  }

  void _answer(BuildContext context, {required bool isSignedIn}) {
    if (!isSignedIn) {
      _showSnackbar(context, context.l10n.videoStickerQuestionSignIn);
      return;
    }
    final location = QuestionAnswerRouteData(
      pubkey: video.pubkey,
      videoId: video.id,
      dTag: video.vineId,
      question: data.prompt,
    ).location;
    runDetached(
      context.pushWithVideoPause<void>(location),
      'open the answer to a question sticker',
      logName: 'InteractiveStickerOverlay',
      category: LogCategory.ui,
    );
  }
}

void _showSnackbar(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(DivineSnackbarContainer.snackBar(message));

/// An Add yours or replies sticker with who joined or replied once that is
/// read; nobody until then, or when it could not be read.
class _ResponsesSticker extends ConsumerWidget {
  const _ResponsesSticker({
    required this.region,
    required this.video,
    required this.data,
    required this.isSignedIn,
    required this.isCreator,
    required this.onInteraction,
  });

  final VideoStickerRegion region;
  final VideoEvent video;
  final SocialStickerData data;
  final bool isSignedIn;
  final bool isCreator;
  final VoidCallback? onInteraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.watch<StickerResponsesCubit>().state;
    final responses = state.status == StickerResponsesStatus.loaded
        ? StickerResponses(
            count: state.total,
            latest: [
              for (final video in state.videos.take(maxStickerAvatars))
                StickerResponsePreview(
                  avatarUrl: video.authorAvatar,
                  thumbnailUrl: video.thumbnailUrl,
                  isBlurred: video.hasContentWarning,
                ),
            ],
          )
        : null;
    final isAddYours = region.kind == VideoStickerKind.prompt;
    return InteractiveStickerCopy(
      data: data,
      responses: responses,
      onJoin: isAddYours
          ? () {
              onInteraction?.call();
              _join(context, ref);
            }
          : null,
      onOpenResponses: () {
        onInteraction?.call();
        _open(context, ref, state.videos);
      },
    );
  }

  /// Opens the camera to answer the Add yours, joining its chain.
  void _join(BuildContext context, WidgetRef ref) {
    if (!isSignedIn) {
      _showSnackbar(context, context.l10n.videoStickerAddYoursSignIn);
      return;
    }
    final chainRoot = region.promptChainRoot(video.addressableId ?? '');
    final hashtag = region.promptHashtag;
    if (chainRoot == null || chainRoot.isEmpty || hashtag == null) return;
    final notifier = ref.read(addYoursContextProvider.notifier)
      ..set(
        AddYoursContext(
          chainRoot: chainRoot,
          prompt: data.prompt ?? '',
          hashtag: hashtag,
        ),
      );
    runDetached(
      context
          .pushWithVideoPause<void>(
            VideoRecorderScreen.pathForEntryPoint(CreationEntryPoint.addYours),
          )
          .whenComplete(notifier.clear),
      'open the camera to add yours',
      logName: 'InteractiveStickerOverlay',
      category: LogCategory.ui,
    );
  }

  /// Opens who joined or replied: the creator manages their replies, anyone
  /// else watches them.
  void _open(BuildContext context, WidgetRef ref, List<VideoEvent> videos) {
    final address = video.addressableId;
    if (region.kind == VideoStickerKind.replies && isCreator) {
      if (address == null) return;
      runDetached(
        context.pushWithVideoPause<void>(
          VideoRepliesRouteData(videoId: video.id, address: address).location,
        ),
        'open the video replies to manage',
        logName: 'InteractiveStickerOverlay',
        category: LogCategory.ui,
      );
      return;
    }
    runDetached(
      openVideoResponsesFeed(
        context,
        feedRepository: ref.read(feedRepositoryProvider),
        videos: videos,
        sourceDetail: region.kind == VideoStickerKind.replies
            ? 'video_replies'
            : 'add_yours',
      ),
      'watch who joined or replied',
      logName: 'InteractiveStickerOverlay',
      category: LogCategory.ui,
    );
  }
}
