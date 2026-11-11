// ABOUTME: Above a private answer to a question sticker: the question it answers,
// ABOUTME: and for the video's creator the button that answers it with a video.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show
        DmMessage,
        DmSharedVideoRef,
        VideoEvent,
        VideoStickerKind,
        VideoStickerRegion;
import 'package:openvine/blocs/question_answer/question_answer_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/screens/inbox/dm_display_text.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// The question [message] answers, quoted above it.
///
/// The video's creator, [viewerPubkey] when the video is theirs, can answer
/// it with a video: a reply to that video whose reply sticker shows the
/// question and the answer, but not who wrote it.
class DmQuestionAnswerHeader extends ConsumerWidget {
  const DmQuestionAnswerHeader({
    required this.message,
    required this.isSent,
    required this.viewerPubkey,
    super.key,
  });

  final DmMessage message;

  /// Whether the viewer sent the answer.
  final bool isSent;

  /// The signed-in account's hex pubkey.
  final String? viewerPubkey;

  /// The question [message] says it answers, as shown above it and on the
  /// reply sticker of a video answering it.
  ///
  /// The sender writes it, so it is cut to the longest question a sticker
  /// holds and cleared of broken characters that would crash text layout.
  static String? questionOf(DmMessage message) {
    final question = message.answeredQuestion;
    return question == null
        ? null
        : _bounded(question, VideoStickerRegion.maxLabelLength);
  }

  static String _bounded(String text, int maxCodeUnits) =>
      StringUtils.sanitizeUtf16(sliceDmDisplayText(text, maxCodeUnits).text);

  /// What a video answering [message] replies to: [citedVideo], the video
  /// [message] cites, read from the relays, with the question and the
  /// answer, its citation line left out, on its reply sticker.
  ///
  /// The citation alone names the video: the id the sender put beside the
  /// question is not checked against it, so a reply never lands on another
  /// video. The question is the one on [citedVideo]'s own question sticker,
  /// not the text the sender wrote, since the answer video shows it to
  /// everyone. `null` when [citedVideo] is not the cited video, it is not
  /// [creatorPubkey]'s, or it asks no question.
  static VideoReplyContext? replyContextFor(
    DmMessage message, {
    required VideoEvent citedVideo,
    required String? creatorPubkey,
  }) {
    final asked = citedVideo.stickerRegions
        .where((region) => region.kind == VideoStickerKind.question)
        .firstOrNull
        ?.label;
    final citation = message.sharedVideoRef;
    final creator = creatorPubkey?.toLowerCase();
    if (questionOf(message) == null ||
        asked == null ||
        citation == null ||
        creator == null ||
        citedVideo.pubkey.toLowerCase() != creator ||
        !_cites(citation, citedVideo)) {
      return null;
    }
    final answer = _bounded(
      message.content
          .split('\n')
          .where((line) => !line.trim().startsWith('nostr:'))
          .join('\n')
          .trim(),
      QuestionAnswerCubit.maxAnswerLength,
    );
    // Named as the video names itself, as a comment on it is: the sender's
    // citation may spell the address differently, or cite one version only.
    return VideoReplyContext(
      rootEventId: citedVideo.id,
      rootEventKind: citedVideo.referenceKind,
      rootAuthorPubkey: creator,
      rootAddressableId: citedVideo.addressableId,
      replyToName: _bounded(asked, VideoStickerRegion.maxLabelLength),
      replyToText: answer.isEmpty ? null : answer,
    );
  }

  /// Whether [citation] names [video]: by its address, or by its event id.
  static bool _cites(DmSharedVideoRef citation, VideoEvent video) {
    if (!citation.isAddressable) {
      return citation.coordinateOrId.toLowerCase() == video.id.toLowerCase();
    }
    final author = citation.coordinateOrId.split(':')[1].toLowerCase();
    return author == video.pubkey.toLowerCase() &&
        citation.dTag != null &&
        citation.dTag == video.addressableDTag;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citation = message.sharedVideoRef;
    final viewer = viewerPubkey?.toLowerCase();
    final target = isSent || citation == null || viewer == null
        ? null
        : resolveDmVideoTarget(content: '', sharedVideoRef: citation);
    // Only the video's creator answers with a video, so only they read it.
    if (target == null || target.authorPubkey?.toLowerCase() != viewer) {
      return _QuestionAnswerLabel(message: message, isSent: isSent);
    }
    // Re-keyed on the repository, which is rebuilt when the viewer's
    // preferences change.
    final videosRepository = ref.watch(videosRepositoryProvider);
    return BlocProvider(
      key: ValueKey(videosRepository),
      create: (_) => VideoLinkPreviewCubit(
        videoStableId: target.stableId,
        videosRepository: videosRepository,
        authorPubkey: target.authorPubkey,
        videoKind: target.videoKind,
      ),
      child: BlocBuilder<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        builder: (context, state) => _QuestionAnswerLabel(
          message: message,
          isSent: isSent,
          replyContext: switch (state) {
            VideoLinkPreviewResolved(:final video) => replyContextFor(
              message,
              citedVideo: video,
              creatorPubkey: viewer,
            ),
            _ => null,
          },
        ),
      ),
    );
  }
}

/// The question [message] answers, and the button answering it with a video
/// replying as [replyContext] says, when there is one.
class _QuestionAnswerLabel extends ConsumerWidget {
  const _QuestionAnswerLabel({
    required this.message,
    required this.isSent,
    this.replyContext,
  });

  final DmMessage message;
  final bool isSent;
  final VideoReplyContext? replyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final question = DmQuestionAnswerHeader.questionOf(message) ?? '';
    final replyContext = this.replyContext;
    return Padding(
      padding: const .fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: isSent ? .end : .start,
        spacing: 8,
        children: [
          Text(
            isSent
                ? l10n.dmQuestionAnswerSentLabel(question)
                : l10n.dmQuestionAnswerReceivedLabel(question),
            style: VineTheme.bodySmallFont(color: colors.secondaryText),
          ),
          if (replyContext != null)
            DivineButton(
              label: l10n.dmQuestionAnswerWithVideo,
              type: .secondary,
              size: .small,
              onPressed: () => _answerWithVideo(context, ref, replyContext),
            ),
        ],
      ),
    );
  }

  void _answerWithVideo(
    BuildContext context,
    WidgetRef ref,
    VideoReplyContext replyContext,
  ) {
    final notifier = ref.read(videoReplyContextProvider.notifier)
      ..set(replyContext);
    runDetached(
      context
          .push(
            VideoRecorderScreen.pathForEntryPoint(
              CreationEntryPoint.videoReply,
            ),
          )
          .whenComplete(notifier.clear),
      'answer a question with a video',
      logName: 'DmQuestionAnswerHeader',
      category: LogCategory.ui,
    );
  }
}
