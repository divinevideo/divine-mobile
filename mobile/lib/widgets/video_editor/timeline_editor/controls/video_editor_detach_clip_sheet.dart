// ABOUTME: Bottom sheets asking what fills a timeline slot — when a clip is
// ABOUTME: detached onto the canvas (nothing, a colour, or a photo) and when
// ABOUTME: the backdrop that took its place is changed afterwards

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/clip_placeholder_fill.dart';

/// What the user picked to fill the slot a detached clip leaves behind.
enum DetachClipChoice {
  /// Close the gap: every later clip starts earlier.
  removeSlot,

  /// Hold a solid colour for as long as the clip ran.
  color,

  /// Hold a photographed still for as long as the clip ran.
  image,
}

/// Asks what takes the detached clip's place on the timeline.
///
/// Returns `null` when the sheet is dismissed, which cancels the detach —
/// nothing is committed until a choice comes back.
///
/// [canRemoveSlot] is `false` for a lone clip: closing the gap would leave the
/// composition with no track at all, so the option is not offered rather than
/// offered and rejected.
Future<DetachClipChoice?> showDetachClipSheet(
  BuildContext context, {
  required bool canRemoveSlot,
}) {
  return VineBottomSheet.show<DetachClipChoice>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    body: _DetachClipSheet(canRemoveSlot: canRemoveSlot),
  );
}

class _DetachClipSheet extends StatelessWidget {
  const _DetachClipSheet({required this.canRemoveSlot});

  final bool canRemoveSlot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(
              l10n.videoEditorDetachTitle,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              l10n.videoEditorDetachDescription,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            if (canRemoveSlot)
              _ChoiceTile(
                icon: DivineIconName.prohibit,
                label: l10n.videoEditorDetachReplaceRemove,
                detail: l10n.videoEditorDetachReplaceRemoveDetail,
                choice: DetachClipChoice.removeSlot,
              ),
            _ChoiceTile(
              icon: DivineIconName.paintBucket,
              label: l10n.videoEditorDetachReplaceColor,
              detail: l10n.videoEditorDetachReplaceColorDetail,
              choice: DetachClipChoice.color,
            ),
            _ChoiceTile(
              icon: DivineIconName.camera,
              label: l10n.videoEditorDetachReplaceImage,
              detail: l10n.videoEditorDetachReplaceImageDetail,
              choice: DetachClipChoice.image,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks which backdrop the placeholder clip holding a detached clip's slot
/// should show from now on.
///
/// [current] is the fill it holds, which marks the matching option and is what
/// the colour picker opens on; `null` for a placeholder from a draft written
/// before the fill was recorded.
///
/// Returns `null` when the sheet is dismissed, and never
/// [DetachClipChoice.removeSlot]: emptying the slot is Delete on the same
/// action bar, and it shortens the composition rather than changing a backdrop.
Future<DetachClipChoice?> showClipBackdropSheet(
  BuildContext context, {
  required ClipPlaceholderFill? current,
}) {
  return VineBottomSheet.show<DetachClipChoice>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    body: _ClipBackdropSheet(current: current),
  );
}

class _ClipBackdropSheet extends StatelessWidget {
  const _ClipBackdropSheet({required this.current});

  final ClipPlaceholderFill? current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(
              l10n.videoEditorBackdropTitle,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              l10n.videoEditorBackdropDescription,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            _ChoiceTile(
              icon: DivineIconName.paintBucket,
              label: l10n.videoEditorDetachReplaceColor,
              detail: l10n.videoEditorBackdropColorDetail,
              choice: DetachClipChoice.color,
              isCurrent: current is ClipPlaceholderColorFill,
            ),
            _ChoiceTile(
              icon: DivineIconName.camera,
              label: l10n.videoEditorDetachReplaceImage,
              detail: l10n.videoEditorBackdropImageDetail,
              choice: DetachClipChoice.image,
              isCurrent: current is ClipPlaceholderImageFill,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.choice,
    this.isCurrent = false,
  });

  final DivineIconName icon;
  final String label;
  final String detail;
  final DetachClipChoice choice;

  /// Whether this is what the slot already holds. Marks the option rather than
  /// disabling it: re-picking Colour is how a shade is adjusted.
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      button: true,
      selected: isCurrent,
      label: '$label. $detail',
      child: ExcludeSemantics(
        child: Material(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.pop<DetachClipChoice>(choice),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 16,
                children: [
                  DivineIcon(icon: icon, color: colors.primaryText),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          label,
                          style: VineTheme.bodyLargeFont(
                            color: colors.primaryText,
                          ),
                        ),
                        Text(
                          detail,
                          style: VineTheme.bodySmallFont(
                            color: colors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    const DivineIcon(
                      icon: .check,
                      color: VineTheme.vineGreen,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
