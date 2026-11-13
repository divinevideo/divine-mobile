// ABOUTME: Music/Effects filter at the end of the sound picker's search field.
// ABOUTME: Shows the active kind and opens a menu to pick another.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show SoundKind;
import 'package:openvine/l10n/l10n.dart';

/// Pill naming the kind of sound the picker's lists are narrowed to, `All`
/// for none. Tapping it opens a menu to pick another, as the search results'
/// filter pill does.
///
/// Sounds whose kind is unknown, as most taken from a video are, only show
/// under All.
class AudioKindFilterPill extends StatelessWidget {
  const AudioKindFilterPill({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The kind the lists are narrowed to, or `null` for every sound.
  final SoundKind? selected;

  /// Called with the kind picked from the menu; not called when the menu is
  /// dismissed.
  final ValueChanged<SoundKind?> onChanged;

  /// The menu's value for [SoundKind] `null`, which has no name of its own.
  static const _allValue = 'all';

  Future<void> _pick(BuildContext context) async {
    final value = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: selected?.name ?? _allValue,
      options: [
        VineBottomSheetSelectionOptionData(
          label: _labelOf(context, null),
          value: _allValue,
          leadingIcon: DivineIconName.waveform,
        ),
        VineBottomSheetSelectionOptionData(
          label: _labelOf(context, SoundKind.music),
          value: SoundKind.music.name,
          leadingIcon: DivineIconName.musicNotes,
        ),
        VineBottomSheetSelectionOptionData(
          label: _labelOf(context, SoundKind.effect),
          value: SoundKind.effect.name,
          leadingIcon: DivineIconName.lightning,
        ),
      ],
    );
    if (value == null) return;
    onChanged(value == _allValue ? null : SoundKind.values.byName(value));
  }

  static String _labelOf(BuildContext context, SoundKind? kind) =>
      switch (kind) {
        null => context.l10n.libraryFilterAll,
        SoundKind.music => context.l10n.categoryMusic,
        SoundKind.effect => context.l10n.videoEditorAudioFilterEffects,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final label = _labelOf(context, selected);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      // Its own node, so it is not read as part of the search field.
      child: Semantics(
        container: true,
        button: true,
        label: context.l10n.searchFilterPillSemanticLabel(label),
        excludeSemantics: true,
        // excludeSemantics drops the InkWell's own tap action with its text.
        onTap: () => _pick(context),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('audio_kind_filter'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pick(context),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Text(
                    label,
                    style: VineTheme.titleSmallFont(
                      color: colors.accentPositive,
                    ),
                  ),
                  DivineIcon(
                    icon: DivineIconName.caretDown,
                    size: 16,
                    color: colors.accentPositive,
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
