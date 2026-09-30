// ABOUTME: The chroma-key recorder's settings: a top-bar chip showing the
// ABOUTME: current backdrop, and the sheet that tunes the key over the camera.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/utils/chroma_key_backdrop_image.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_clip_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_controls.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKey;
import 'package:unified_logger/unified_logger.dart';

/// Opens the chroma-key settings over the live viewfinder.
///
/// The barrier stays clear on purpose: the settings are tuned against the
/// camera, and a scrim would dim exactly the picture being judged.
///
/// Remote record triggers are paused while it is open, the way the lip-sync
/// sound picker pauses them, so a volume key cannot start a take behind it.
Future<void> showVideoRecorderChromaKeySettings(BuildContext context) async {
  final bloc = context.read<VideoRecorderBloc>()
    ..add(const VideoRecorderRemoteRecordPaused());
  try {
    await VineBottomSheet.show<void>(
      context: context,
      contentTitle: context.l10n.videoEditorChromaKeyTitle,
      barrierColor: VineTheme.transparent,
      initialChildSize: 0.5,
      contentWrapper: (_, sheet) => BlocProvider<VideoRecorderBloc>.value(
        value: bloc,
        // The sheet's own messenger: a snackbar raised from inside it would
        // otherwise land on the recorder's scaffold, underneath the sheet.
        child: ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: VineTheme.transparent,
            resizeToAvoidBottomInset: false,
            body: sheet,
          ),
        ),
      ),
      buildScrollBody: (scrollController) =>
          _ChromaKeySettings(scrollController: scrollController),
    );
  } finally {
    bloc.addIfOpen(const VideoRecorderRemoteRecordResumed());
  }
}

/// Top-bar chip naming the mode's settings, led by a swatch of the backdrop.
class VideoRecorderChromaKeyChip extends StatelessWidget {
  const VideoRecorderChromaKeyChip({super.key});

  @override
  Widget build(BuildContext context) {
    final chromaKey = context.select(
      (VideoRecorderBloc b) => b.state.chromaKey,
    );

    return Flexible(
      child: Material(
        type: .transparency,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: chipLabelTextScaleLimit,
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: () => showVideoRecorderChromaKeySettings(context),
              borderRadius: .circular(16),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const .fromLTRB(8, 8, 16, 8),
                decoration: ShapeDecoration(
                  color: VineTheme.scrim15,
                  shape: RoundedRectangleBorder(borderRadius: .circular(16)),
                ),
                child: Row(
                  mainAxisSize: .min,
                  spacing: 8,
                  children: [
                    ExcludeSemantics(
                      child: _BackdropSwatch(chromaKey: chromaKey),
                    ),
                    Flexible(
                      child: Text(
                        context.l10n.videoEditorChromaKeyTitle,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: VineTheme.labelLargeFont(
                          color: VineTheme.whiteText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small picture of what the key puts behind the subject.
class _BackdropSwatch extends StatelessWidget {
  const _BackdropSwatch({required this.chromaKey});

  static const double _size = 24;

  final ClipChromaKey chromaKey;

  @override
  Widget build(BuildContext context) {
    final imagePath = chromaKey.backgroundImagePath;
    final color = chromaKey.key.backgroundColor;
    final icon = switch (chromaKey.backgroundType) {
      ClipChromaKeyBackgroundType.transparent =>
        DivineIconName.textBgTransparent,
      ClipChromaKeyBackgroundType.video => DivineIconName.filmSlate,
      ClipChromaKeyBackgroundType.color ||
      ClipChromaKeyBackgroundType.image => DivineIconName.userFocus,
    };
    final fallback = DivineIcon(
      icon: icon,
      size: 20,
      color: VineTheme.whiteText,
    );

    return ClipRRect(
      borderRadius: .circular(6),
      child: SizedBox.square(
        dimension: _size,
        child: switch (chromaKey.backgroundType) {
          ClipChromaKeyBackgroundType.color when color != null => ColoredBox(
            color: color,
          ),
          ClipChromaKeyBackgroundType.image when imagePath != null =>
            Image.file(
              File(imagePath),
              fit: .cover,
              cacheWidth: 72,
              errorBuilder: (_, _, _) => Center(child: fallback),
            ),
          _ => Center(child: fallback),
        },
      ),
    );
  }
}

/// The settings panel, bound to the recorder.
///
/// The same panel as the editor's chroma key screen, so the key and
/// backdrop a clip is recorded with are the ones baked into it and the ones
/// the editor re-opens with.
class _ChromaKeySettings extends StatelessWidget {
  const _ChromaKeySettings({required this.scrollController});

  final ScrollController scrollController;

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
        scrollController: scrollController,
        chromaKey: chromaKey,
        // Also while a written-off still is out: the camera cannot take a
        // second one until it is back.
        isDetecting:
            status == ChromaKeyMeasurementStatus.detecting ||
            status == ChromaKeyMeasurementStatus.superseded,
        detectionNotice: _measurementNotice(context.l10n, status),
        onDetect: () =>
            bloc.add(const VideoRecorderChromaKeyMeasureRequested()),
        onGreenPreset: () => bloc.add(
          const VideoRecorderChromaKeyPresetSelected(ChromaKey.greenScreen()),
        ),
        onBluePreset: () => bloc.add(
          const VideoRecorderChromaKeyPresetSelected(ChromaKey.blueScreen()),
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
