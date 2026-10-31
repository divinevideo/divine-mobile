// ABOUTME: Where a creator sets up a question, Add yours or replies sticker: what
// ABOUTME: it asks or is titled, and the hashtag an Add yours's answers share.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';

/// What a question asks, an Add yours prompts or a replies sticker is
/// titled, with a note on where the answers go; an Add yours also takes the
/// hashtag its answers share.
class SocialStickerPromptFields extends StatefulWidget {
  const SocialStickerPromptFields({this.autofocus = false, super.key});

  final bool autofocus;

  @override
  State<SocialStickerPromptFields> createState() =>
      _SocialStickerPromptFieldsState();
}

class _SocialStickerPromptFieldsState extends State<SocialStickerPromptFields> {
  late final TextEditingController _promptController;
  late final TextEditingController _hashtagController;
  final _hashtagFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final data = context.read<SocialStickerCubit>().state.data;
    _promptController = TextEditingController(text: data.prompt ?? '');
    _hashtagController = TextEditingController(text: data.hashtag ?? '');
  }

  @override
  void dispose() {
    _promptController.dispose();
    _hashtagController.dispose();
    _hashtagFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = context.select(
      (SocialStickerCubit cubit) => cubit.state.data.kind,
    );
    final isAddYours = kind == SocialStickerKind.addYours;
    final cubit = context.read<SocialStickerCubit>();
    return BlocListener<SocialStickerCubit, SocialStickerState>(
      // The hashtag follows the prompt until the creator writes their own.
      listenWhen: (previous, current) =>
          previous.data.hashtag != current.data.hashtag,
      listener: (context, state) {
        final hashtag = state.data.hashtag ?? '';
        if (_hashtagFocus.hasFocus || _hashtagController.text == hashtag) {
          return;
        }
        _hashtagController.text = hashtag;
      },
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 16,
        children: [
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: DivineTextField(
              controller: _promptController,
              filled: true,
              autofocus: widget.autofocus,
              labelText: switch (kind) {
                SocialStickerKind.addYours =>
                  l10n.videoEditorSocialStickerAddYoursPromptHint,
                SocialStickerKind.replies =>
                  l10n.videoEditorSocialStickerRepliesTitleHint,
                _ => l10n.videoEditorSocialStickerQuestionHint,
              },
              maxLength: SocialStickerData.maxPromptLength,
              textInputAction: isAddYours ? .next : .done,
              onChanged: cubit.promptChanged,
            ),
          ),
          if (isAddYours)
            Padding(
              padding: const .symmetric(horizontal: 16),
              child: DivineTextField(
                controller: _hashtagController,
                focusNode: _hashtagFocus,
                filled: true,
                labelText: l10n.videoEditorSocialStickerAddYoursHashtagHint,
                prefixText: '#',
                textCapitalization: .none,
                textInputAction: .done,
                autocorrect: false,
                onChanged: cubit.promptHashtagChanged,
              ),
            ),
          StickerSheetNote(
            text: switch (kind) {
              SocialStickerKind.addYours =>
                l10n.videoEditorSocialStickerAddYoursNote,
              SocialStickerKind.replies =>
                l10n.videoEditorSocialStickerRepliesNote,
              _ => l10n.videoEditorSocialStickerQuestionNote,
            },
          ),
        ],
      ),
    );
  }
}
