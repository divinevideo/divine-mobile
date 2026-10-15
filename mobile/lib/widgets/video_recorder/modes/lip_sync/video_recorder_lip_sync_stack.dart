import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_audio_progress_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';
import 'package:unified_logger/unified_logger.dart';

/// Lip-sync mode stack.
///
/// A lip-sync video starts from its sound, so until one is picked the mode
/// shows the sound picker where the viewfinder goes. Once a sound is picked it
/// is capture mode with an audio chip in the top bar, which adjusts or removes
/// the sound, and the audio waveform progress bar overlaid while recording.
/// Removing the sound brings the picker back.
class VideoRecorderLipSyncStack extends ConsumerStatefulWidget {
  const VideoRecorderLipSyncStack({super.key});

  @override
  ConsumerState<VideoRecorderLipSyncStack> createState() =>
      _VideoRecorderLipSyncStackState();
}

class _VideoRecorderLipSyncStackState
    extends ConsumerState<VideoRecorderLipSyncStack> {
  /// Whether the viewfinder shows rather than the picker.
  ///
  /// Held while the recorder leaves lip-sync or closes: both reset the editor
  /// on the way out, and following that would swap in the picker during the
  /// exit transition.
  late bool _hasSound = ref.read(videoEditorProvider).selectedSound != null;

  @override
  Widget build(BuildContext context) {
    final hasSound = ref.watch(
      videoEditorProvider.select((s) => s.selectedSound != null),
    );
    final isLipSync = context.select(
      (VideoRecorderBloc b) =>
          b.state.recorderMode == VideoRecorderMode.lipSync,
    );
    if (isLipSync && (ModalRoute.isCurrentOf(context) ?? true)) {
      _hasSound = hasSound;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _hasSound
          ? const VideoRecorderCaptureStack(
              fromEditor: false,
              topBarCenter: _LipSyncAudioButton(),
              audioProgressBar: VideoRecorderAudioProgressBar(),
            )
          : const _LipSyncSoundPicker(),
    );
  }
}

/// The sound picker in place of the viewfinder, shown until a sound is picked.
///
/// The camera keeps running behind it, so the viewfinder is ready the moment a
/// sound is picked. Remote record control is paused while it shows, which
/// hands the volume keys back to the sound previews.
class _LipSyncSoundPicker extends ConsumerStatefulWidget {
  const _LipSyncSoundPicker();

  @override
  ConsumerState<_LipSyncSoundPicker> createState() =>
      _LipSyncSoundPickerState();
}

class _LipSyncSoundPickerState extends ConsumerState<_LipSyncSoundPicker> {
  late final VideoRecorderBloc _recorderBloc;

  /// The pick being adopted. Clearing the recorded clips for it keeps the
  /// picker on screen, so a second pick meanwhile is dropped.
  Future<void>? _adoption;

  @override
  void initState() {
    super.initState();
    _recorderBloc = context.read<VideoRecorderBloc>()
      ..add(const VideoRecorderRemoteRecordPaused());
  }

  @override
  void dispose() {
    _recorderBloc.addIfOpen(const VideoRecorderRemoteRecordResumed());
    super.dispose();
  }

  void _onSoundPicked(AudioEvent sound) {
    if (_adoption != null) return;
    final adoption = _adoptLipSyncSound(
      ref,
      sound,
    ).whenComplete(() => _adoption = null);
    _adoption = adoption;
    _runAdoption(adoption);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      // The mode wheel below the picker keeps clear of the home indicator.
      removeBottom: true,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: const .vertical(bottom: .circular(32)),
          // A Material rather than a ColoredBox: the sound rows are ListTiles,
          // which paint their ink on the nearest Material.
          child: Material(
            color: context.vineColors.surface,
            child: AudioSelectionBottomSheet(
              onSoundPicked: _onSoundPicked,
              // The viewfinder's top bar, and its close button, only shows once
              // a sound is picked.
              categoryBarLeading: DivineIconButton(
                icon: .x,
                semanticLabel: context.l10n.videoRecorderCloseLabel,
                semanticIdentifier: SemanticIds.cameraCloseButton,
                type: .secondary,
                size: .small,
                onPressed: () => closeVideoRecorder(context, ref),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adopts the newly selected [sound], discarding any recorded clips first.
///
/// Recorded clips are synced to the previously selected sound, so changing
/// the selection invalidates them. Clips are cleared before the new sound is
/// stored because [ClipManagerNotifier.clearAll] resets the editor (which
/// would otherwise wipe the just-selected sound).
///
/// The notifiers are read before clearing: the reset drops the sound, which
/// swaps the viewfinder for the picker and can dispose [ref] before the
/// clearing finishes.
Future<void> _adoptLipSyncSound(WidgetRef ref, AudioEvent? sound) async {
  final editor = ref.read(videoEditorProvider.notifier);
  final clipManager = ref.read(clipManagerProvider.notifier);
  final previousSound = ref.read(videoEditorProvider).selectedSound;
  if (sound != previousSound && ref.read(clipManagerProvider).hasClips) {
    await clipManager.clearAll();
  }
  editor.selectRecorderAudioTrack(sound);
}

void _runAdoption(Future<void> adoption) => runDetached(
  adoption,
  'adopt the lip-sync sound',
  logName: 'VideoRecorderLipSyncStack',
  category: LogCategory.video,
);

/// Audio chip for the recorder's selected sound, which opens the timing
/// screen to adjust or remove it.
///
/// Pauses remote-triggered recording while that screen is open so a remote
/// start can't fire behind it, mirroring the recorder's existing audio-chip
/// behavior.
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
        onSoundChanged: (sound) => _runAdoption(_adoptLipSyncSound(ref, sound)),
        onSelectionStarted: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRemoteRecordPaused(),
        ),
        onSelectionEnded: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRemoteRecordResumed(),
        ),
      ),
    );
  }
}
