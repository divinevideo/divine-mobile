// ABOUTME: Bottom sheet asking what fills the timeline slot when a clip is
// ABOUTME: detached onto the canvas — nothing, a colour, or a photo

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';

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

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.choice,
  });

  final DivineIconName icon;
  final String label;
  final String detail;
  final DetachClipChoice choice;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      button: true,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
