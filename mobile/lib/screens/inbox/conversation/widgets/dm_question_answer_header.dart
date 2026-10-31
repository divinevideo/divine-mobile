// ABOUTME: Above a private answer to a question sticker: the question it answers,
// ABOUTME: and for the video's creator the button that answers it with a video.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show DmMessage, NIP71VideoKinds;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/detached_future.dart';
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

  /// What a video answering [message] replies to: the creator's video, with
  /// the question and the answer, its citation line left out, on its reply
  /// sticker. `null` when [message] names no video of [creatorPubkey]'s.
  static VideoReplyContext? replyContextFor(
    DmMessage message, {
    required String? creatorPubkey,
  }) {
    final question = message.answeredQuestion;
    final videoId = message.answeredVideoId;
    final video = message.sharedVideoRef;
    if (question == null ||
        videoId == null ||
        video == null ||
        creatorPubkey == null ||
        video.authorPubkey?.toLowerCase() != creatorPubkey.toLowerCase()) {
      return null;
    }
    final answer = message.content
        .split('\n')
        .where((line) => !line.trim().startsWith('nostr:'))
        .join('\n')
        .trim();
    return VideoReplyContext(
      rootEventId: videoId,
      rootEventKind: NIP71VideoKinds.addressableShortVideo,
      rootAuthorPubkey: creatorPubkey.toLowerCase(),
      rootAddressableId: video.isAddressable ? video.coordinateOrId : null,
      replyToName: question,
      replyToText: answer.isEmpty ? null : answer,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final question = message.answeredQuestion ?? '';
    final replyContext = isSent
        ? null
        : replyContextFor(message, creatorPubkey: viewerPubkey);
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
