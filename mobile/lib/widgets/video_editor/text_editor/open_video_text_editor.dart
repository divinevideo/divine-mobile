// ABOUTME: Opens the text editor over the video editor and closes its panels
// ABOUTME: and the sub-editor again once it is gone, whichever way it went.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/screens/video_editor/video_text_editor_screen.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Opens the text editor over the video editor, for a new text layer or to
/// change [layer], and returns the layer it hands back, or `null` when it
/// closes without one.
///
/// The text editor is pushed on the navigator above [context], the app's
/// navigator, on top of the editor's page. A navigation back to a page below
/// the editor (a notification tap, a deep link, a home-screen quick action)
/// removes the editor's page in the same frame and fades the text editor out
/// over it, so the push resolves after the editor has closed [mainBloc] and
/// [textBloc]. The closing events are dropped then.
Future<TextLayer?> openVideoTextEditor(
  BuildContext context, {
  required VideoEditorMainBloc mainBloc,
  required VideoEditorTextBloc textBloc,
  TextLayer? layer,
}) async {
  mainBloc.add(const VideoEditorMainOpenSubEditor(.text));

  final result = await Navigator.push<TextLayer>(
    context,
    PageRouteBuilder<TextLayer>(
      settings: const RouteSettings(name: 'video_text_editor'),
      opaque: false,
      barrierDismissible: true,
      barrierColor: VineTheme.transparent,
      pageBuilder: (_, _, _) => BlocProvider.value(
        value: textBloc,
        child: VideoTextEditorScreen(layer: layer),
      ),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );

  textBloc.addIfOpen(const VideoEditorTextClosePanels());
  mainBloc.addIfOpen(const VideoEditorMainSubEditorClosed());
  return result;
}
