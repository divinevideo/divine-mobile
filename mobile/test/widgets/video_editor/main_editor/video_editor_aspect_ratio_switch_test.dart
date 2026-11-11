// ABOUTME: Tests the editor's switch between square and 9:16: one history
// ABOUTME: entry with the cropped clips and moved layers, and an announcement.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_aspect_ratio_switch.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/features/main_editor/services/sizes_manager.dart'
    show SizesManager;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _Editor extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_Editor';
}

class _Sizes extends Mock implements SizesManager {}

class _Main extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _Clips extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('switchEditorAspectRatio', () {
    late _Editor editor;
    late _Main main;
    late _Clips clips;
    late WidgetLayer sticker;
    late List<({List<Layer>? layers, Map<String, dynamic> meta})> entries;

    DivineVideoClip clip(String id) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('/documents/$id.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );

    setUp(() {
      editor = _Editor();
      main = _Main();
      clips = _Clips();
      entries = [];
      // Above the square frame of the 9:16 canvas, which ends 90 above the
      // centre; its size is unknown off screen, so its centre is kept on.
      sticker = WidgetLayer(
        widget: const SizedBox(),
        offset: const Offset(0, -150),
      );

      final sizes = _Sizes();
      when(() => sizes.bodySize).thenReturn(const Size(180, 320));
      when(() => editor.mounted).thenReturn(true);
      when(() => editor.sizesManager).thenReturn(sizes);
      when(() => editor.activeLayers).thenReturn([sticker]);
      when(() => editor.stateManager).thenReturn(
        StateManager(onStateHistoryChange: () {}, activeBackgroundImage: null),
      );
      when(() => editor.setState(any())).thenAnswer(
        (call) => (call.positionalArguments.single as VoidCallback)(),
      );
      when(
        () => editor.addHistory(
          layers: any(named: 'layers'),
          meta: any(named: 'meta'),
        ),
      ).thenAnswer((call) {
        entries.add((
          layers: call.namedArguments[#layers] as List<Layer>?,
          meta: Map<String, dynamic>.from(
            call.namedArguments[#meta] as Map<String, dynamic>,
          ),
        ));
      });
      when(() => main.state).thenReturn(const VideoEditorMainState());
    });

    Future<void> pumpAndSwitch(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoEditorScope(
            editorKey: GlobalKey<ProImageEditorState>(),
            editorOverride: editor,
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
            playheadAdvancingNotifier: ValueNotifier(false),
            fromLibrary: false,
            onOpenCamera: () {},
            onOpenClipsEditor: () {},
            onAddStickers: () {},
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            onOpenEffects: () {},
            onAddEditTextLayer: ([layer]) async => null,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<ClipEditorBloc>.value(value: clips),
                BlocProvider<VideoEditorMainBloc>.value(value: main),
              ],
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => switchEditorAspectRatio(context),
                  child: const Text('Switch'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Switch'));
      await tester.pump();
    }

    testWidgets('crops every clip square and moves a layer the square frame '
        'would cut off, in one history entry', (tester) async {
      when(
        () => clips.state,
      ).thenReturn(ClipEditorState(clips: [clip('a'), clip('b')]));

      await pumpAndSwitch(tester);

      final entry = entries.single;
      final saved = [
        for (final json
            in entry.meta[VideoEditorConstants.clipsStateHistoryKey] as List)
          json as Map,
      ];
      expect(saved.map((c) => c['id']), ['a', 'b']);
      expect(
        saved.map((c) => c['targetAspectRatio']),
        everyElement(model.AspectRatio.square.name),
      );
      final moved = entry.layers!.single;
      expect(moved.id, sticker.id);
      expect(moved.offset.dy, closeTo(-90, 1e-6));
      // A copy: the entry before keeps the layer where it was.
      expect(moved, isNot(same(sticker)));
      expect(sticker.offset, const Offset(0, -150));
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains(l10n.videoEditorMadeSquareAnnouncement),
      );
    });

    testWidgets('does nothing while a clip is still being rendered', (
      tester,
    ) async {
      when(() => clips.state).thenReturn(
        ClipEditorState(isStabilizing: true, clips: [clip('a')]),
      );

      await pumpAndSwitch(tester);

      expect(entries, isEmpty);
      expect(tester.takeAnnouncements(), isEmpty);
    });
  });
}
