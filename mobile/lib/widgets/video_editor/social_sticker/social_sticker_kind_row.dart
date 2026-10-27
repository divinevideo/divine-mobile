// ABOUTME: The row of social stickers in the sticker sheet, each shown with a
// ABOUTME: sample of what it looks like; tapping one pops its kind.

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
/// video has when one of its sounds has a title and an artist.
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
    return SizedBox(
      height: 112,
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
