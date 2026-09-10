import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

class VideoEditorRemoveArea extends ConsumerWidget {
  const VideoEditorRemoveArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = VideoEditorScope.of(context);
    final isLayerOverRemoveArea = context.select(
      (VideoEditorMainBloc bloc) => bloc.state.isLayerOverRemoveArea,
    );

    return Center(
      child: Semantics(
        liveRegion: true,
        label: isLayerOverRemoveArea
            ? context.l10n.videoEditorReleaseToDeleteLayer
            : context.l10n.videoEditorDeleteLayerDropZone,
        child: AnimatedScale(
          key: scope.removeAreaKey,
          scale: isLayerOverRemoveArea ? 1.4 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Container(
            padding: const .all(10),
            decoration: ShapeDecoration(
              color: VineTheme.error,
              shape: RoundedRectangleBorder(borderRadius: .circular(20)),
            ),
            child: DivineIcon(
              icon: .trash,
              size: 28,
              color: context.vineColors.background,
            ),
          ),
        ),
      ),
    );
  }
}
