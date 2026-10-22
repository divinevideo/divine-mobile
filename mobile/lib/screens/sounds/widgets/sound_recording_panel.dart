// ABOUTME: The Add sound screen's recording in progress: live levels, the
// ABOUTME: elapsed time against the length limit, and the stop button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/sound_recorder/sound_recorder_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/audio/live_amplitude_waveform.dart';
import 'package:openvine/widgets/audio/record_toggle_button.dart';
import 'package:time_formatter/time_formatter.dart';

/// The recording in progress: its live levels, its length, and stop.
class SoundRecordingPanel extends StatelessWidget {
  /// Creates the panel.
  const SoundRecordingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 40, 16, 16),
      child: Column(
        spacing: 24,
        children: [
          RepaintBoundary(
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: _RecordingWave(),
            ),
          ),
          _RecordingClock(),
          _StopRecordingButton(),
        ],
      ),
    );
  }
}

class _RecordingWave extends StatelessWidget {
  const _RecordingWave();

  @override
  Widget build(BuildContext context) {
    final bars = context.select((SoundRecorderCubit c) => c.state.waveformBars);
    final samplePosition = context.select(
      (SoundRecorderCubit c) => c.state.elapsed,
    );
    final isRecording = context.select(
      (SoundRecorderCubit c) => c.state.isRecording,
    );
    return LiveAmplitudeWaveform(
      bars: bars,
      isRecording: isRecording,
      color: context.vineColors.accentPositive,
      sampleInterval: SoundRecorderCubit.amplitudeInterval,
      samplePosition: samplePosition,
    );
  }
}

/// Elapsed time over the length at which the recording stops on its own.
class _RecordingClock extends StatelessWidget {
  const _RecordingClock();

  @override
  Widget build(BuildContext context) {
    final elapsed = context.select((SoundRecorderCubit c) => c.state.elapsed);
    final maxDuration = context.select(
      (SoundRecorderCubit c) => c.state.maxDuration,
    );
    return Text(
      '${TimeFormatter.formatMinutesSeconds(elapsed)} / '
      '${TimeFormatter.formatMinutesSeconds(maxDuration)}',
      style: VineTheme.titleLargeFont(color: context.vineColors.onSurface),
    );
  }
}

class _StopRecordingButton extends StatelessWidget {
  const _StopRecordingButton();

  @override
  Widget build(BuildContext context) {
    // Stays a stop shape while the file is being finished, but inert.
    final isRecording = context.select(
      (SoundRecorderCubit c) => c.state.isRecording,
    );
    return RecordToggleButton(
      key: const Key('add_sound_stop_recording'),
      isRecording: true,
      semanticLabel: context.l10n.videoEditorVoiceOverStopSemanticLabel,
      onPressed: isRecording
          ? () => context.read<SoundRecorderCubit>().stop()
          : null,
    );
  }
}
