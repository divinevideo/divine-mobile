// ABOUTME: Notice on the Add sound screen while microphone access is refused,
// ABOUTME: with the way to grant it in the system settings.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/sound_recorder/sound_recorder_cubit.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shown while microphone access is refused, with the way to grant it.
class MicrophoneDeniedNotice extends StatelessWidget {
  /// Creates the notice.
  const MicrophoneDeniedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                children: [
                  DivineIcon(
                    icon: DivineIconName.microphone,
                    color: context.vineColors.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      l10n.videoEditorVoiceOverPermissionTitle,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                l10n.soundsRecordPermissionBody,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
              DivineButton(
                key: const Key('add_sound_open_settings'),
                label: l10n.videoEditorVoiceOverOpenSettings,
                type: DivineButtonType.secondary,
                size: DivineButtonSize.small,
                onPressed: () =>
                    context.read<SoundRecorderCubit>().openSettings(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
