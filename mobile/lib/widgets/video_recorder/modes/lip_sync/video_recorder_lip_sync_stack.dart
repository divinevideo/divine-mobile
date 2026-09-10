import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_audio_progress_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';

/// Lip-sync mode stack.
///
/// Identical to capture mode, with an audio-select chip added to the top bar
/// so the user can pick a sound to lip-sync to, and the audio waveform
/// progress bar overlaid while recording. Reuses the capture stack and only
/// supplies the lip-sync-specific slots.
class VideoRecorderLipSyncStack extends StatelessWidget {
  const VideoRecorderLipSyncStack({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoRecorderCaptureStack(
      fromEditor: false,
      topBarCenter: _LipSyncAudioButton(),
      audioProgressBar: VideoRecorderAudioProgressBar(),
      recordButton: _LipSyncRecordButton(),
    );
  }
}

/// Record button gated on an audio selection.
///
/// Until a sound is picked it renders disabled (grayed) and a tap shows a
/// snackbar telling the user to add audio first, rather than starting a
/// recording that wouldn't be synced to anything.
class _LipSyncRecordButton extends ConsumerWidget {
  const _LipSyncRecordButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSound = ref.watch(
      videoEditorProvider.select((s) => s.selectedSound != null),
    );

    return RecordButton(
      onBlockedTap: hasSound ? null : () => _showAddAudioSnackbar(context),
    );
  }

  void _showAddAudioSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoRecorderLipSyncAddAudioFirst,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 140),
        ),
      );
  }
}

/// Audio-select chip wired to the recorder's selected sound.
///
/// Pauses remote-triggered recording while the selection sheet is open so a
/// remote start can't fire behind the picker, mirroring the recorder's
/// existing audio-chip behavior.
class _LipSyncAudioButton extends ConsumerWidget {
  const _LipSyncAudioButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSound = ref.watch(
      videoEditorProvider.select((s) => s.selectedSound),
    );

    return Flexible(
      child: VideoEditorAudioChip(
        selectedSound: selectedSound,
        onSoundChanged: (sound) => _onSoundChanged(ref, sound),
        onSelectionStarted: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRemoteRecordPaused(),
        ),
        onSelectionEnded: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRemoteRecordResumed(),
        ),
      ),
    );
  }

  /// Adopts the newly selected [sound], discarding any recorded clips first.
  ///
  /// Recorded clips are synced to the previously selected sound, so changing
  /// the selection invalidates them. Clips are cleared before the new sound is
  /// stored because [ClipManagerNotifier.clearAll] resets the editor (which
  /// would otherwise wipe the just-selected sound).
  Future<void> _onSoundChanged(WidgetRef ref, AudioEvent? sound) async {
    final previousSound = ref.read(videoEditorProvider).selectedSound;
    if (sound != previousSound && ref.read(clipManagerProvider).hasClips) {
      await ref.read(clipManagerProvider.notifier).clearAll();
    }
    ref.read(videoEditorProvider.notifier).selectRecorderAudioTrack(sound);
  }
}
