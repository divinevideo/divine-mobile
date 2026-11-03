// ABOUTME: Optional cover for a sound shared from Add sound: a square preview
// ABOUTME: and a button that opens the camera and gallery sheet.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Edge length of the cover preview.
const _previewSize = 88.0;

/// Lets the user give a sound they share a cover.
///
/// The cover shows next to the sound wherever people pick one; without it the
/// sound has a colour tile, since a standalone sound has no video to borrow a
/// frame from.
class ShareCoverSection extends StatelessWidget {
  const ShareCoverSection({
    required this.coverImage,
    required this.onChangeCover,
    super.key,
  });

  /// The chosen cover, or `null` when there is none yet.
  final Uint8List? coverImage;

  /// Opens the cover sheet, or `null` while the cover cannot change.
  final VoidCallback? onChangeCover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = coverImage == null
        ? l10n.soundsShareCoverAdd
        : l10n.soundsShareCoverReplace;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        spacing: 16,
        children: [
          // Tapping the preview opens the same sheet as the button, as the
          // badge artwork and the profile picture do.
          Semantics(
            button: true,
            label: label,
            child: GestureDetector(
              onTap: onChangeCover,
              child: _CoverPreview(coverImage: coverImage),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  l10n.soundsShareCoverLabel,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                Text(
                  l10n.soundsShareCoverDescription,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                DivineButton(
                  key: const Key('add_sound_cover_button'),
                  label: label,
                  type: DivineButtonType.secondary,
                  size: DivineButtonSize.small,
                  onPressed: onChangeCover,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.coverImage});

  final Uint8List? coverImage;

  @override
  Widget build(BuildContext context) {
    final bytes = coverImage;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: _previewSize,
          child: bytes == null
              ? DecoratedBox(
                  key: const Key('add_sound_cover_placeholder'),
                  decoration: BoxDecoration(
                    color: context.vineColors.surfaceContainerHigh,
                    border: Border.all(color: context.vineColors.outlineMuted),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: DivineIcon(
                      icon: DivineIconName.image,
                      color: context.vineColors.onSurfaceMuted,
                    ),
                  ),
                )
              : Image.memory(
                  bytes,
                  key: const Key('add_sound_cover_image'),
                  fit: BoxFit.cover,
                  cacheWidth: (_previewSize * 2).round(),
                  gaplessPlayback: true,
                ),
        ),
      ),
    );
  }
}
