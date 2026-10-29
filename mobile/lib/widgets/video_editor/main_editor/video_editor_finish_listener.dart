// ABOUTME: Delivers a ready edit handover above transient editor controls.
// ABOUTME: Keeps Done observable while gestures or sub-editors hide the toolbar.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Finishes the editor when the main bloc completes a pending Done request.
///
/// Mounted by the scaffold, not by the toolbar that disappears during a layer
/// gesture or while a sub-editor owns the controls.
class VideoEditorFinishListener extends StatelessWidget {
  const VideoEditorFinishListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
      listenWhen: (previous, current) =>
          previous.handOverCounter != current.handOverCounter,
      listener: (context, _) {
        final editor = VideoEditorScope.of(context).editor;
        if (editor != null && editor.mounted) editor.doneEditing();
      },
      child: child,
    );
  }
}
