// ABOUTME: The color mask in capture mode: the color mask screen over the live
// ABOUTME: camera, where a tap picks the wall's color and the rest is tuned.

import 'dart:io';
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/utils/chroma_key_backdrop_image.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_clip_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_controls.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_screen_layout.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/remote_record_pause.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKey;
import 'package:unified_logger/unified_logger.dart';

/// Opens the color mask screen over the camera.
///
/// The same screen the editor opens for a clip, with the live camera where the
/// clip would be: tapping the picture takes the wall's color, and the settings
/// below act on the viewfinder as they change. There is nothing to confirm, so
/// Close and Done both just return to the camera.
///
/// Remote record triggers are paused while it is open, the way the sound
/// picker pauses them, so a volume key cannot start a take behind it.
Future<void> showVideoRecorderChromaKeySettings(BuildContext context) {
  final bloc = context.read<VideoRecorderBloc>();
  final navigator = Navigator.of(context);
  return showWithRemoteRecordPaused(
    bloc,
    () => navigator.push<void>(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'video_recorder_color_mask'),
        // Not opaque, so the recorder below keeps its camera session and the
        // viewfinder's texture keeps streaming into this screen.
        opaque: false,
        barrierColor: VineTheme.backgroundCamera,
        pageBuilder: (_, _, _) => BlocProvider<VideoRecorderBloc>.value(
          value: bloc,
          child: const VideoRecorderColorMaskScreen(),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
  );
}

/// The color mask screen for the camera, bound to [VideoRecorderBloc].
///
/// Every change goes straight to the recorder, so the viewfinder behind this
/// screen and the take it records match what is shown here.
class VideoRecorderColorMaskScreen extends StatefulWidget {
  const VideoRecorderColorMaskScreen({super.key});

  @override
  State<VideoRecorderColorMaskScreen> createState() =>
      _VideoRecorderColorMaskScreenState();
}

class _VideoRecorderColorMaskScreenState
    extends State<VideoRecorderColorMaskScreen> {
  /// Whether a tap has picked a color yet. Until one has, the picture says it
  /// can be tapped: nothing else on screen gives that away.
  bool _hasPicked = false;

  void _onPatchPicked(Uint8List patch) {
    setState(() => _hasPicked = true);
    context.read<VideoRecorderBloc>().add(
      VideoRecorderChromaKeyPatchPicked(patch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (VideoRecorderBloc b) => b.state.chromaKeyMeasurementStatus,
    );
    final hint = chromaKeyPreviewHintText(
      context,
      isDetecting: status == ChromaKeyMeasurementStatus.detecting,
      hasPicked: _hasPicked,
    );
    final l10n = context.l10n;

    return ChromaKeyScreenLayout(
      onClose: () => Navigator.of(context).pop(),
      closeSemanticLabel: l10n.commonClose,
      onDone: () => Navigator.of(context).pop(),
      doneSemanticLabel: l10n.videoEditorChromaKeyDoneSemanticLabel,
      preview: Stack(
        children: [
          VideoRecorderCameraPreview(
            // A tap picks the color here; focus stays with the camera.
            enableTapToFocus: false,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            onColorPatchPicked: _onPatchPicked,
          ),
          if (hint != null) ChromaKeyPreviewHint(text: hint),
        ],
      ),
      showRemove: true,
      onRemove: () {
        // The key and backdrop stay as they were set, so turning the mask on
        // again brings them back.
        context.read<VideoRecorderBloc>().add(
          const VideoRecorderChromaKeyEnabledSet(enabled: false),
        );
        Navigator.of(context).pop();
      },
      controls: const _ColorMaskControls(),
    );
  }
}

/// The settings panel, bound to the recorder.
///
/// The same panel as the editor's color mask screen, so the key and backdrop
/// a clip is recorded with are the ones baked into it and the ones the editor
/// re-opens with.
class _ColorMaskControls extends StatelessWidget {
  const _ColorMaskControls();

  @override
  Widget build(BuildContext context) {
    final (chromaKey, status) = context.select(
      (VideoRecorderBloc b) => (
        b.state.chromaKey,
        b.state.chromaKeyMeasurementStatus,
      ),
    );
    final bloc = context.read<VideoRecorderBloc>();

    return BlocListener<VideoRecorderBloc, VideoRecorderBlocState>(
      listenWhen: (previous, current) =>
          previous.chromaKeyMeasurementStatus !=
          current.chromaKeyMeasurementStatus,
      // The notice appears inline with nothing to move a screen reader to it,
      // so it is said aloud as well.
      listener: (context, state) {
        final notice = _measurementNotice(
          context.l10n,
          state.chromaKeyMeasurementStatus,
        );
        if (notice == null) return;
        announceDetached(
          context,
          notice,
          description: 'announce the chroma-key measurement result',
          logName: 'VideoRecorderChromaKeySettings',
        );
      },
      child: ChromaKeyControlsPanel(
        chromaKey: chromaKey,
        // Also while a written-off still is out: the camera cannot take a
        // second one until it is back.
        isDetecting:
            status == ChromaKeyMeasurementStatus.detecting ||
            status == ChromaKeyMeasurementStatus.superseded,
        detectionNotice: _measurementNotice(context.l10n, status),
        showSurfaceHint: status == ChromaKeyMeasurementStatus.failed,
        onDetect: () =>
            bloc.add(const VideoRecorderChromaKeyMeasureRequested()),
        onGreenPreset: () => bloc.add(
          const VideoRecorderChromaKeyPresetSelected(
            ChromaKey.greenScreen(),
          ),
        ),
        onBluePreset: () => bloc.add(
          const VideoRecorderChromaKeyPresetSelected(
            ChromaKey.blueScreen(),
          ),
        ),
        onKeyColorChanged: (color) =>
            bloc.add(VideoRecorderChromaKeySettingsChanged(color: color)),
        onSimilarityChanged: (value) => bloc.add(
          VideoRecorderChromaKeySettingsChanged(similarity: value),
        ),
        onSmoothnessChanged: (value) => bloc.add(
          VideoRecorderChromaKeySettingsChanged(smoothness: value),
        ),
        onSpillChanged: (value) =>
            bloc.add(VideoRecorderChromaKeySettingsChanged(spill: value)),
        onPickBackground: (type) => _pickBackdrop(context, type),
      ),
    );
  }

  /// What the panel says about the last measurement, or `null` when there is
  /// nothing to report.
  static String? _measurementNotice(
    AppLocalizations l10n,
    ChromaKeyMeasurementStatus status,
  ) => switch (status) {
    ChromaKeyMeasurementStatus.failed => l10n.videoEditorChromaKeyDetectFailed,
    ChromaKeyMeasurementStatus.timedOut =>
      l10n.videoEditorChromaKeyDetectTimedOut,
    ChromaKeyMeasurementStatus.idle ||
    ChromaKeyMeasurementStatus.detecting ||
    ChromaKeyMeasurementStatus.superseded => null,
  };

  Future<void> _pickBackdrop(
    BuildContext context,
    ClipChromaKeyBackgroundType type,
  ) async {
    final bloc = context.read<VideoRecorderBloc>();
    switch (type) {
      case ClipChromaKeyBackgroundType.transparent:
        bloc.add(const VideoRecorderChromaKeyBackdropSet.transparent());
      case ClipChromaKeyBackgroundType.color:
        final picked = await showFullColorPicker(
          context,
          initialColor:
              bloc.state.chromaKey.key.backgroundColor ??
              VineTheme.surfaceBackground,
        );
        // Only the RGB channels are used — the keyed area is filled solidly —
        // so a translucent pick would be rejected by the key.
        if (picked != null) {
          bloc.addIfOpen(
            VideoRecorderChromaKeyBackdropSet.color(
              picked.withValues(alpha: 1),
            ),
          );
        }
      case ClipChromaKeyBackgroundType.image:
        await _shootImageBackdrop(context, bloc);
      case ClipChromaKeyBackgroundType.video:
        final path = await showChromaKeyClipPicker(context);
        if (path != null) {
          bloc.addIfOpen(VideoRecorderChromaKeyBackdropSet.video(path));
        }
    }
  }

  Future<void> _shootImageBackdrop(
    BuildContext context,
    VideoRecorderBloc bloc,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedMessage = context.l10n.videoEditorChromaKeyImagePickFailed;
    try {
      final path = await captureChromaKeyBackdropImage(ownerId: 'recorder');
      if (path == null) return;
      // The bloc owns the file from here and deletes it if no clip is ever
      // recorded with it. A recorder that closed meanwhile owns nothing.
      if (!bloc.addIfOpen(VideoRecorderChromaKeyBackdropSet.image(path))) {
        await File(path).delete();
      }
    } catch (error, stackTrace) {
      Log.error(
        'Failed to capture the chroma-key backdrop image',
        name: 'VideoRecorderChromaKeySettings',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      messenger.showSnackBar(DivineSnackbarContainer.snackBar(failedMessage));
    }
  }
}
