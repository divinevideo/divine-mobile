import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/clip_delete_snackbar.dart';

class VideoRecorderClassicActionsTop extends ConsumerWidget {
  const VideoRecorderClassicActionsTop({super.key});

  void _deleteLastClip(BuildContext context, WidgetRef ref) {
    unawaited(ref.read(clipManagerProvider.notifier).scheduleDeleteLastClip());
    showClipDeleteSnackbar(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = context.select(
      (VideoRecorderBloc b) => b.state.isRecording,
    );
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isRecording || !hasClips ? 0 : 1,
      child: Row(
        mainAxisAlignment: .center,
        children: [
          DivineIconButton(
            icon: .trash,
            semanticLabel: context.l10n.videoRecorderDeleteLastClipLabel,
            semanticIdentifier: SemanticIds.cameraDeleteClipButton,
            size: .small,
            type: .ghostSecondary,
            onPressed: () => _deleteLastClip(context, ref),
          ),
        ],
      ),
    );
  }
}
