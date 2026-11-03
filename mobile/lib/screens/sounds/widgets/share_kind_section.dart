// ABOUTME: Files a sound shared from Add sound as music or as a sound effect,
// ABOUTME: which decides where it shows when people filter the sound picker.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show SoundKind;
import 'package:openvine/l10n/l10n.dart';

/// Lets the user say whether a sound they share is music or a sound effect.
///
/// Optional: a sound filed as neither shows only when the picker is not
/// narrowed to one of them.
class ShareKindSection extends StatelessWidget {
  const ShareKindSection({
    required this.kind,
    required this.onChanged,
    super.key,
  });

  /// The chosen kind, or `null` for neither.
  final SoundKind? kind;

  /// Called with the kind picked from the menu, or `null` while the kind
  /// cannot change.
  final ValueChanged<SoundKind?>? onChanged;

  /// The menu's value for neither, which [SoundKind] has no name for.
  static const _neither = 'neither';

  Future<void> _pick(
    BuildContext context,
    ValueChanged<SoundKind?> onChanged,
  ) async {
    final l10n = context.l10n;
    final value = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: kind?.name ?? _neither,
      options: [
        VineBottomSheetSelectionOptionData(
          label: l10n.categoryMusic,
          value: SoundKind.music.name,
          leadingIcon: DivineIconName.musicNotes,
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.soundsShareKindEffect,
          value: SoundKind.effect.name,
          leadingIcon: DivineIconName.lightning,
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.soundsShareKindNeither,
          value: _neither,
          leadingIcon: DivineIconName.waveform,
        ),
      ],
    );
    if (value == null) return;
    onChanged(value == _neither ? null : SoundKind.values.byName(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onChanged = this.onChanged;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            l10n.soundsShareKindLabel,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Text(
            l10n.soundsShareKindDescription,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          DivineButton(
            key: const Key('add_sound_kind_button'),
            label: switch (kind) {
              null => l10n.soundsShareKindChoose,
              SoundKind.music => l10n.categoryMusic,
              SoundKind.effect => l10n.soundsShareKindEffect,
            },
            trailingIcon: DivineIconName.caretDown,
            type: DivineButtonType.secondary,
            size: DivineButtonSize.small,
            onPressed: onChanged == null
                ? null
                : () => _pick(context, onChanged),
          ),
        ],
      ),
    );
  }
}
