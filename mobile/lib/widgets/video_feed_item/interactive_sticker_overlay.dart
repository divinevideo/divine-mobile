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
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/sticker_responses_filter_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_replies_curation_provider.dart';
import 'package:openvine/router/routes/interactive_sticker_routes.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/open_video_responses_feed.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_editor/social_sticker/interactive_sticker_card.dart';
import 'package:unified_logger/unified_logger.dart';

/// The question, Add yours or replies [region] on [video], opening what a
/// tap on it opens while [isActive].
///
/// An Add yours or replies sticker reads who joined or replied as soon as
/// the feed builds its video, the ones it loads ahead included, so they are
/// in by the time the viewer swipes to it, and keeps showing them while the
/// video is not the one playing, as under the comments. [onInteraction] is
/// called when the viewer taps it, so the feed does not move on under them.
///
/// An Add yours or replies sticker only some may answer is in no frame: it
/// shows once that is read, to whoever may answer and to everyone else once
/// someone did, and only they may join an Add yours.
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
    if (region.kind == VideoStickerKind.question && !isActive) {
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
                _answer(
                  context,
                  isSignedIn: viewer != null,
                  isDmRestricted: ref.read(isDmRestrictedProvider),
                );
              },
      );
    }
    final repository = ref.watch(videoResponsesRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    // Rebuilt when the viewer's blocks, mutes or content filters change, so
    // the responses are read again under the new policy.
    final filter = ref.watch(stickerResponsesFilterProvider);
    return BlocProvider(
      // Another account has its own blocks, may answer or not, and the
      // creator has their own view.
      key: ValueKey((
        repository,
        followRepository,
        filter,
        viewer,
        region,
        video.id,
      )),
      create: (_) {
        final cubit = StickerResponsesCubit(
          repository: repository,
          filter: filter,
          followRepository: followRepository,
          video: video,
          region: region,
          viewer: viewer,
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
        isActive: isActive,
        isSignedIn: viewer != null,
        isCreator: isCreator,
        onInteraction: onInteraction,
      ),
    );
  }

  void _answer(
    BuildContext context, {
    required bool isSignedIn,
    required bool isDmRestricted,
  }) {
    if (!isSignedIn) {
      _showSnackbar(context, context.l10n.videoStickerQuestionSignIn);
      return;
    }
    // A protected minor messages Divine alone, so an answer could never be
    // sent.
    if (isDmRestricted) {
      _showSnackbar(context, context.l10n.videoStickerQuestionUnavailable);
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
/// read; nobody until then, or when it could not be read. It takes taps only
/// while [isActive].
class _ResponsesSticker extends ConsumerWidget {
  const _ResponsesSticker({
    required this.region,
    required this.video,
    required this.data,
    required this.isActive,
    required this.isSignedIn,
    required this.isCreator,
    required this.onInteraction,
  });

  final VideoStickerRegion region;
  final VideoEvent video;
  final SocialStickerData data;
  final bool isActive;
  final bool isSignedIn;
  final bool isCreator;
  final VoidCallback? onInteraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cubit = context.watch<StickerResponsesCubit>();
    final state = cubit.state;
    final address = video.addressableId;
    if (region.kind == VideoStickerKind.replies && address != null) {
      final provider = videoRepliesCurationProvider((
        pubkey: video.pubkey,
        address: address,
      ));
      final curation = ref.watch(provider).value;
      if (state.status == StickerResponsesStatus.loaded &&
          curation != null &&
          curation != state.curation) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || cubit.isClosed || cubit.state != state) {
            return;
          }
          final latest = ref.read(provider).value;
          if (latest == null || latest == state.curation) return;
          runDetached(
            cubit.load(knownCuration: latest),
            'refresh replies after a curation edit',
            logName: 'InteractiveStickerOverlay',
            category: LogCategory.ui,
          );
        });
      }
    }
    if ((data.isLeftOutOfFrames || state.audience.isRestricted) &&
        !state.isShown) {
      return const SizedBox.shrink();
    }
    final responses = state.status == StickerResponsesStatus.loaded
        ? StickerResponses(
            count: state.total,
            countIsAtLeast: state.totalIsAtLeast,
            latest: [
              for (final video in state.videos.take(maxStickerAvatars))
                StickerResponsePreview(
                  // Funnelcake sends the author along; a video read from the
                  // relays carries none, so its profile is read.
                  avatarUrl:
                      video.authorAvatar ??
                      ref
                          .watch(fetchUserProfileProvider(video.pubkey))
                          .value
                          ?.picture,
                  thumbnailUrl: video.thumbnailUrl,
                  // The warnings the viewer's settings call for, as the
                  // feed this opens shows them.
                  isBlurred: video.shouldShowWarning,
                ),
            ],
          )
        : null;
    final isAddYours = region.kind == VideoStickerKind.prompt;
    // Ignored rather than built without its buttons, which would build the
    // card anew and start its thumbnails over.
    return IgnorePointer(
      ignoring: !isActive,
      child: InteractiveStickerCopy(
        data: data,
        responses: responses,
        // Once the chain it joins is known, and by whoever may answer.
        onJoin: isAddYours && state.chainRoot != null && state.canAnswer
            ? () {
                onInteraction?.call();
                _join(context, ref, state);
              }
            : null,
        // Anyone who may not join is invited to watch the series instead.
        watchOnly: isAddYours && !state.canAnswer,
        onOpenResponses: () {
          onInteraction?.call();
          _open(context, ref, state);
        },
      ),
    );
  }

  /// Opens the camera to answer the Add yours with the resolved audience.
  void _join(BuildContext context, WidgetRef ref, StickerResponsesState state) {
    if (!isSignedIn) {
      _showSnackbar(context, context.l10n.videoStickerAddYoursSignIn);
      return;
    }
    final hashtag = region.promptHashtag;
    if (hashtag == null) return;
    final notifier = ref.read(addYoursContextProvider.notifier)
      ..set(
        AddYoursContext(
          chainRoot: state.chainRoot!,
          prompt: data.prompt ?? '',
          hashtag: hashtag,
          audience: state.audience,
        ),
      );
    runDetached(
      context
          .pushWithVideoPause<void>(
            const VideoRecorderRouteData(
              entryPoint: CreationEntryPoint.addYours,
            ).location,
          )
          .whenComplete(notifier.clear),
      'open the camera to add yours',
      logName: 'InteractiveStickerOverlay',
      category: LogCategory.ui,
    );
  }

  /// Opens who joined or replied: the creator manages their replies, anyone
  /// else watches them. A series only its creator adds to opens in the order
  /// it was posted, at the part the sticker is on.
  void _open(BuildContext context, WidgetRef ref, StickerResponsesState state) {
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
    final series = state.series;
    final at = series.indexWhere(
      (part) =>
          part.id == video.id ||
          (address != null && part.addressableId == address),
    );
    runDetached(
      openVideoResponsesFeed(
        context,
        feedRepository: ref.read(feedRepositoryProvider),
        videos: series.isEmpty ? state.videos : series,
        index: at < 0 ? 0 : at,
        // The replies, or the answers under the prompt they answer.
        title: region.kind == VideoStickerKind.replies
            ? context.l10n.videoStickerRepliesManageTitle
            : data.prompt ?? context.l10n.videoEditorSocialStickerAddYours,
        sourceDetail: region.kind == VideoStickerKind.replies
            ? 'video_replies'
            : 'add_yours',
        isAddYoursSeries: region.kind == VideoStickerKind.prompt,
      ),
      'watch who joined or replied',
      logName: 'InteractiveStickerOverlay',
      category: LogCategory.ui,
    );
  }
}
