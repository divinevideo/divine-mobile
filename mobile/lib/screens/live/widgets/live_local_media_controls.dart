import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class LiveLocalMediaControls extends StatelessWidget {
  const LiveLocalMediaControls({
    required this.cameraButtonLabel,
    required this.microphoneButtonLabel,
    required this.onToggleCamera,
    required this.onToggleMicrophone,
    required this.onSwitchCamera,
    required this.onEnableAudioOnly,
    super.key,
  });

  final String cameraButtonLabel;
  final String microphoneButtonLabel;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onSwitchCamera;
  final VoidCallback onEnableAudioOnly;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        DivineButton(
          label: microphoneButtonLabel,
          size: DivineButtonSize.small,
          type: DivineButtonType.secondary,
          onPressed: onToggleMicrophone,
        ),
        DivineButton(
          label: cameraButtonLabel,
          size: DivineButtonSize.small,
          type: DivineButtonType.secondary,
          onPressed: onToggleCamera,
        ),
        DivineButton(
          label: 'Flip camera',
          size: DivineButtonSize.small,
          type: DivineButtonType.secondary,
          onPressed: onSwitchCamera,
        ),
        DivineButton(
          label: 'Audio only',
          size: DivineButtonSize.small,
          type: DivineButtonType.secondary,
          onPressed: onEnableAudioOnly,
        ),
      ],
    );
  }
}
