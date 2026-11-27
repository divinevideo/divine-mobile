// ABOUTME: The settings of the picked colour filter, shown in the filter
// ABOUTME: editor's bottom bar in place of the filter picker.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/filter_settings.dart';
import 'package:openvine/widgets/video_editor/video_editor_settings_panel.dart';

/// The settings of the picked filter, one card per [FilterSettingsCard] that
/// [filterSettingsCardsOf] lists for it, each starting at the preset's own
/// values and with a button that puts them back.
class VideoEditorFilterSettingsPanel extends StatelessWidget {
  const VideoEditorFilterSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final preset = context.select(
      (VideoEditorFilterBloc b) => b.state.selectedFilter,
    );
    // The changes only move when a setting does, so the cards rebuild no
    // more often than that.
    final values = context.select(
      (VideoEditorFilterBloc b) => b.state.settingValues,
    );
    if (preset == null) return const SizedBox.shrink();
    final bloc = context.read<VideoEditorFilterBloc>();
    final l10n = context.l10n;
    return VideoEditorSettingsPanel(
      title: l10n.videoEditorEffectSettingsTitle(preset.name),
      onBack: () =>
          bloc.add(const VideoEditorFilterSettingsToggled(open: false)),
      children: [
        for (final card in filterSettingsCardsOf(preset))
          VideoEditorSettingsGroupCard(
            key: ValueKey((card.kind, card.number)),
            title: _titleOf(l10n, card),
            settings: card.settings,
            values: values,
            onChanged: (key, value) =>
                bloc.add(VideoEditorFilterSettingChanged(key, value)),
            resetLabel: switch (card.kind) {
              FilterSettingsCardKind.light => l10n.videoEditorFilterLightReset,
              FilterSettingsCardKind.color => l10n.videoEditorFilterColorReset,
              FilterSettingsCardKind.overlay =>
                l10n.videoEditorFilterOverlayReset,
              FilterSettingsCardKind.cast => l10n.videoEditorFilterCastReset,
              FilterSettingsCardKind.balance =>
                l10n.videoEditorFilterBalanceReset,
            },
            onReset:
                card.settings.any((setting) => values.containsKey(setting.key))
                ? () => bloc.add(VideoEditorFilterSettingsReset(card))
                : null,
          ),
      ],
    );
  }

  static String _titleOf(AppLocalizations l10n, FilterSettingsCard card) {
    final title = switch (card.kind) {
      FilterSettingsCardKind.light => l10n.videoEditorFilterLightTitle,
      FilterSettingsCardKind.color => l10n.videoEditorTuneColor,
      FilterSettingsCardKind.overlay => l10n.videoEditorFilterOverlayTitle,
      FilterSettingsCardKind.cast => l10n.videoEditorFilterCastTitle,
      FilterSettingsCardKind.balance => l10n.videoEditorFilterBalanceTitle,
    };
    return card.number == 0
        ? title
        : l10n.videoEditorFilterSettingsNumberedTitle(
            title,
            NumberFormat.decimalPattern(l10n.localeName).format(card.number),
          );
  }
}
