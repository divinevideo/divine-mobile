// ABOUTME: Top bar widget for video recorder screen
// ABOUTME: Contains close button, audio chip, and forward button using VideoEditorToolbar

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';

/// Top bar with close button, segment bar, and forward button.
class VideoRecorderTopBar extends ConsumerStatefulWidget {
  /// Creates a video recorder top bar widget.
  const VideoRecorderTopBar({super.key});

  @override
  ConsumerState<VideoRecorderTopBar> createState() =>
      _VideoRecorderTopBarState();
}

class _VideoRecorderTopBarState extends ConsumerState<VideoRecorderTopBar> {
  bool _isSelectingSound = false;

  @override
  Widget build(BuildContext context) {
    final isRecording = context.select(
      (VideoRecorderBloc b) => b.state.isRecording,
    );
    final selectedSound = ref.watch(
      videoEditorProvider.select((s) => s.selectedSound),
    );
    final clipCount = ref.watch(clipManagerProvider.select((s) => s.clipCount));
    final hasClips = clipCount > 0;

    return Align(
      alignment: .topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isRecording
            ? const SizedBox.shrink()
            : AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isSelectingSound ? 0 : 1,
                child: VideoEditorToolbar(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                  closeSemanticLabel: context.l10n.videoRecorderCloseLabel,
                  doneSemanticLabel:
                      context.l10n.videoRecorderContinueToEditorLabel,
                  doneIcon: DivineIconName.caretRight,
                  onClose: () => closeVideoRecorder(context, ref),
                  onDone: hasClips
                      ? () => openVideoEditorFromRecorder(context, ref)
                      : null,
                  center: Flexible(
                    child: VideoEditorAudioChip(
                      selectedSound: selectedSound,
                      onSoundChanged: (sound) {
                        ref
                            .read(videoEditorProvider.notifier)
                            .selectSound(sound);
                      },
                      onSelectionStarted: () {
                        setState(() => _isSelectingSound = true);
                        context.read<VideoRecorderBloc>().add(
                          const VideoRecorderRemoteRecordPaused(),
                        );
                      },
                      onSelectionEnded: () {
                        setState(() => _isSelectingSound = false);
                        context.read<VideoRecorderBloc>().add(
                          const VideoRecorderRemoteRecordResumed(),
                        );
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
