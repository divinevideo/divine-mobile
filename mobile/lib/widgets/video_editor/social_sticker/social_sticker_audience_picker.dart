// ABOUTME: Where a creator picks who may answer an Add yours or replies sticker:
// ABOUTME: everyone, the people they follow, or only themselves.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoStickerAudience;
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';

/// Who may answer an Add yours or replies sticker, and what that means for
/// everyone else.
class SocialStickerAudiencePicker extends StatelessWidget {
  const SocialStickerAudiencePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.select((SocialStickerCubit cubit) => cubit.state.data);
    final audience = data.audience;
    final isAddYours = data.kind == SocialStickerKind.addYours;
    final cubit = context.read<SocialStickerCubit>();
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Semantics(
            header: true,
            child: Text(
              l10n.videoEditorSocialStickerAudienceTitle,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
        ),
        StickerChipRow(
          children: [
            for (final choice in VideoStickerAudience.values)
              StickerChoiceChip(
                label: switch (choice) {
                  VideoStickerAudience.everyone =>
                    l10n.videoEditorSocialStickerAudienceEveryone,
                  VideoStickerAudience.following =>
                    l10n.videoEditorSocialStickerAudienceFollowing,
                  VideoStickerAudience.creator =>
                    l10n.videoEditorSocialStickerAudienceCreator,
                },
                selected: choice == audience,
                onTap: () => cubit.audienceChanged(choice),
              ),
          ],
        ),
        if (audience.isRestricted)
          StickerSheetNote(
            text: switch ((audience, isAddYours)) {
              (VideoStickerAudience.creator, true) =>
                l10n.videoEditorSocialStickerAudienceCreatorAddYoursNote,
              (VideoStickerAudience.creator, false) =>
                l10n.videoEditorSocialStickerAudienceCreatorRepliesNote,
              (_, true) =>
                l10n.videoEditorSocialStickerAudienceFollowingAddYoursNote,
              (_, false) =>
                l10n.videoEditorSocialStickerAudienceFollowingRepliesNote,
            },
          ),
      ],
    );
  }
}
