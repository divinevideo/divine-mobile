// ABOUTME: The sheet where a creator sets up a social sticker: who or what it
// ABOUTME: points to, its look, and the button that places or saves it.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_inputs.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_labels.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_poll_inputs.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_prompt_inputs.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';

/// Opens the social sticker sheet and resolves with the sticker as the
/// creator set it up, or `null` when they closed the sheet.
///
/// [isNew] is true for a sticker that is not on the canvas yet.
/// [otherHashtags] are the post's hashtags besides this sticker's, which
/// count toward the most a video can carry. [soundChoices] are the credits
/// for the video's sounds a sound credit can switch between.
Future<SocialStickerData?> showSocialStickerSheet(
  BuildContext context, {
  required SocialStickerData initial,
  bool isNew = false,
  Set<String> otherHashtags = const {},
  List<SocialStickerData> soundChoices = const [],
}) {
  return VineBottomSheet.show<SocialStickerData>(
    context: context,
    title: Text(context.l10n.socialStickerKindLabel(initial.kind)),
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    body: _SocialStickerScope(
      initial: initial,
      otherHashtags: otherHashtags,
      soundChoices: soundChoices,
      child: SocialStickerSheet(isNew: isNew),
    ),
  );
}

/// Provides the cubit that holds the sticker and, for a hashtag, the search
/// that suggests hashtags.
class _SocialStickerScope extends ConsumerWidget {
  const _SocialStickerScope({
    required this.initial,
    required this.otherHashtags,
    required this.soundChoices,
    required this.child,
  });

  final SocialStickerData initial;
  final Set<String> otherHashtags;
  final List<SocialStickerData> soundChoices;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final scope = BlocProvider(
      // A new account's blocklist starts the sticker over rather than leaving
      // it checked against the last one.
      key: ValueKey(blocklistRepository),
      create: (_) => SocialStickerCubit(
        initial: initial,
        blocklistRepository: blocklistRepository,
        otherHashtags: otherHashtags,
        soundChoices: soundChoices,
      ),
      child: child,
    );
    if (initial.kind != SocialStickerKind.hashtag) return scope;
    final hashtagRepository = ref.watch(hashtagRepositoryProvider);
    return BlocProvider(
      key: ValueKey(hashtagRepository),
      create: (_) => HashtagSearchBloc(hashtagRepository: hashtagRepository),
      child: scope,
    );
  }
}

/// Lets the creator set up a social sticker while a preview shows it, and
/// pops with the result.
class SocialStickerSheet extends StatelessWidget {
  const SocialStickerSheet({required this.isNew, super.key});

  /// Whether the sticker is not on the canvas yet, which names the button.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final kind = context.select(
      (SocialStickerCubit cubit) => cubit.state.data.kind,
    );
    // The options scroll on a short screen, between the preview above them
    // and the button below them.
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const Padding(padding: .fromLTRB(16, 8, 16, 0), child: _Preview()),
        Flexible(
          child: SingleChildScrollView(
            padding: const .symmetric(vertical: 16),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              spacing: 16,
              children: [
                ...switch (kind) {
                  SocialStickerKind.mention => const [SocialStickerPersonRow()],
                  SocialStickerKind.hashtag => [
                    SocialStickerHashtagField(autofocus: isNew),
                  ],
                  SocialStickerKind.link => [
                    SocialStickerLinkFields(autofocus: isNew),
                  ],
                  SocialStickerKind.soundCredit => const [
                    SocialStickerSoundChoice(),
                    SocialStickerSoundDesignPicker(),
                    SocialStickerLyricField(),
                  ],
                  SocialStickerKind.countdown => [
                    SocialStickerCountdownFields(autofocus: isNew),
                  ],
                  // What it replies to comes from the reply itself.
                  SocialStickerKind.reply => [
                    StickerSheetNote(
                      text: context.l10n.videoEditorSocialStickerReplyNote,
                    ),
                  ],
                  SocialStickerKind.poll || SocialStickerKind.quiz => [
                    SocialStickerPollFields(autofocus: isNew),
                  ],
                  SocialStickerKind.slider => [
                    SocialStickerSliderFields(autofocus: isNew),
                  ],
                  SocialStickerKind.question ||
                  SocialStickerKind.addYours ||
                  SocialStickerKind.replies => [
                    SocialStickerPromptFields(autofocus: isNew),
                  ],
                },
                // A sticker with one look has nothing to pick.
                if (kind.styles.length > 1) const SocialStickerStylePicker(),
              ],
            ),
          ),
        ),
        StickerSheetFooter(child: _ConfirmButton(isNew: isNew)),
      ],
    );
  }
}

/// The sticker as it will look, on a dark ground like a video's.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final data = context.select((SocialStickerCubit cubit) => cubit.state.data);
    // Smaller while the keyboard is up, so the field and what is suggested
    // below it still fit above the button.
    final isTyping = MediaQuery.viewInsetsOf(context).bottom > 0;
    return SizedBox(
      height: isTyping ? 72 : 140,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.surfaceBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(isTyping ? 12 : 20),
          child: data.isComplete
              ? FittedBox(child: SocialStickerView(data: data))
              // Nothing to show yet: a person, hashtag or address is to come.
              : Center(
                  child: Text(
                    context.l10n.socialStickerKindLabel(data.kind),
                    style: VineTheme.titleMediumFont(
                      color: VineTheme.whiteText.withValues(alpha: 0.6),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Places or saves the sticker once it has everything it shows and its
/// hashtag still fits on the post.
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final (data, canConfirm) = context.select(
      (SocialStickerCubit cubit) => (cubit.state.data, cubit.state.canConfirm),
    );
    final l10n = context.l10n;
    return DivineButton(
      label: isNew ? l10n.videoEditorInfoStickerAdd : l10n.videoEditorDoneLabel,
      expanded: true,
      onPressed: canConfirm ? () => Navigator.of(context).pop(data) : null,
    );
  }
}
