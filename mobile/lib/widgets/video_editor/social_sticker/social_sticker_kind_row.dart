// ABOUTME: The rows of social and interactive stickers in the sticker sheet,
// ABOUTME: each shown with a sample of what it looks like; a tap pops its kind.

import 'package:clock/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_labels.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';

/// A horizontal row of the social stickers; tapping one pops the sheet with
/// its [SocialStickerKind].
///
/// The sound credit is offered only with a [soundCredit] to show, which a
/// video has when one of its sounds has a title.
class SocialStickerKindRow extends StatelessWidget {
  const SocialStickerKindRow({this.soundCredit, super.key});

  /// The credit for the video's first creditable sound, or `null` when it
  /// has none.
  final SocialStickerData? soundCredit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final samples = [
      SocialStickerData(
        kind: SocialStickerKind.mention,
        name: l10n.videoEditorSocialStickerMentionSample,
      ),
      SocialStickerData(
        kind: SocialStickerKind.hashtag,
        hashtag: l10n.videoEditorSocialStickerHashtagSample,
      ),
      // A domain is not translated; Divine's own stands in for any.
      const SocialStickerData(
        kind: SocialStickerKind.link,
        url: 'https://divine.video',
      ),
      ?soundCredit,
    ];
    return _SampleRow(samples: samples);
  }
}

/// A horizontal row of the interactive stickers; tapping one pops the sheet
/// with its [SocialStickerKind].
///
/// Replies and Add yours, the most used, come right after the countdown. The
/// reply is offered only with a [reply] to show, which a video recorded as a
/// reply has. The interactive cards, replies, Add yours, a poll, quiz, slider
/// and question, are offered only while the video has none of them,
/// [hasInteractiveCard] being false: a video carries one. The question is
/// offered only when [canAskQuestion].
class InteractiveStickerKindRow extends StatelessWidget {
  const InteractiveStickerKindRow({
    this.reply,
    this.hasInteractiveCard = false,
    this.canAskQuestion = true,
    super.key,
  });

  /// The sticker showing what the video replies to, or `null` when it
  /// replies to nothing.
  final SocialStickerData? reply;

  /// Whether the video has an interactive card already.
  final bool hasInteractiveCard;

  /// Whether the account may ask a question: its answers come as private
  /// messages, which an account restricted to messaging Divine alone could
  /// never receive.
  final bool canAskQuestion;

  @override
  Widget build(BuildContext context) {
    final sample =
        SocialStickerData.countdown(
          now: clock.now().add(const Duration(days: 11)),
          localeName: Localizations.localeOf(context).toString(),
          use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        ).copyWith(
          countdownTitle: context.l10n.videoEditorSocialStickerCountdownSample,
        );
    final l10n = context.l10n;
    final mostUsed = [
      SocialStickerData.interactive(
        SocialStickerKind.replies,
        prompt: l10n.videoEditorSocialStickerRepliesSample,
      ),
      SocialStickerData.interactive(
        SocialStickerKind.addYours,
        prompt: l10n.videoEditorSocialStickerAddYoursSample,
        hashtag: SocialStickerData.hashtagForPrompt(
          l10n.videoEditorSocialStickerAddYoursSample,
        ),
      ),
    ];
    final polls = [
      SocialStickerData(
        kind: SocialStickerKind.poll,
        pollQuestion: l10n.videoEditorSocialStickerPollSampleQuestion,
        pollOptions: [
          l10n.videoEditorSocialStickerPollSampleYes,
          l10n.videoEditorSocialStickerPollSampleNo,
        ],
      ),
      // Years read the same in every language.
      SocialStickerData(
        kind: SocialStickerKind.quiz,
        pollQuestion: l10n.videoEditorSocialStickerQuizSampleQuestion,
        pollOptions: const ['2013', '2015'],
        quizAnswer: 0,
      ),
      SocialStickerData(
        kind: SocialStickerKind.slider,
        pollQuestion: l10n.videoEditorSocialStickerSliderSampleQuestion,
        sliderEmoji: '😋',
      ),
      if (canAskQuestion)
        SocialStickerData.interactive(
          SocialStickerKind.question,
          prompt: l10n.videoEditorSocialStickerQuestionSample,
        ),
    ];
    return _SampleRow(
      samples: [
        sample,
        if (!hasInteractiveCard) ...mostUsed,
        ?reply,
        if (!hasInteractiveCard) ...polls,
      ],
    );
  }
}

/// A sideways row of [samples], each popping the sheet with its kind.
class _SampleRow extends StatelessWidget {
  const _SampleRow({required this.samples});

  final List<SocialStickerData> samples;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: StickerKindTile.rowHeightOf(context, [
        for (final sample in samples) l10n.socialStickerKindLabel(sample.kind),
      ]),
      child: ListView.separated(
        scrollDirection: .horizontal,
        padding: const .symmetric(horizontal: 16),
        itemCount: samples.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final sample = samples[index];
          return StickerKindTile(
            label: l10n.socialStickerKindLabel(sample.kind),
            onTap: () => context.pop(sample.kind),
            child: SocialStickerView(data: sample),
          );
        },
      ),
    );
  }
}
