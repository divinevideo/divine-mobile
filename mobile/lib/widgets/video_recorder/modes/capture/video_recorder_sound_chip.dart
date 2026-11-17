// ABOUTME: Capture mode's sound chip: the sound a session records against,
// ABOUTME: which plays during each take and becomes the editor's audio track.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';

/// The sound to record against, in capture mode's top bar.
///
/// A picked sound plays while each take runs, so the takes line up with it,
/// and the editor opens with the clips muted and the sound as its own track.
/// The takes are synced to the sound, so it can only be picked, retimed or
/// removed while the session has no clips. After the first take the chip still
/// names the sound, and a tap says how to change it. A session recorded
/// without a sound hides the chip, since a sound picked now would not line up
/// with the takes already there; the editor adds one instead.
class VideoRecorderSoundChip extends ConsumerWidget {
  const VideoRecorderSoundChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSound = ref.watch(
      videoEditorProvider.select((s) => s.selectedSound),
    );
    final hasClips = ref.watch(clipManagerProvider.select((s) => s.hasClips));

    if (hasClips && selectedSound == null) return const SizedBox.shrink();

    return Flexible(
      child: VideoEditorAudioChip(
        selectedSound: selectedSound,
        onSoundChanged: (sound) => ref
            .read(videoEditorProvider.notifier)
            .selectRecorderAudioTrack(sound),
        onSelectionStarted: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRemoteRecordPaused(),
        ),
        onSelectionEnded: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRemoteRecordResumed(),
        ),
        onLockedTap: hasClips ? () => _showLockedHint(context) : null,
      ),
    );
  }

  void _showLockedHint(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoRecorderSoundLockedHint,
        ),
      );
  }
}
