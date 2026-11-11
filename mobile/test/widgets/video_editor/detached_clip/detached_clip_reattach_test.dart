// ABOUTME: Tests for the "back to timeline" action of a detached clip: what
// ABOUTME: it reads off the layer and hands to the clip editor

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_reattach.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  group('reattachDetachedClip', () {
    const key = ClipChromaKey(key: ChromaKey.greenScreen());
    late Directory documents;
    late PathProviderPlatform originalPathProvider;
    late _MockClipEditorBloc clipBloc;
    late _MockVideoEditorMainBloc mainBloc;
    late _MockTimelineOverlayBloc overlayBloc;

    setUpAll(() {
      registerFallbackValue(const ClipEditorEditingStarted());
    });

    setUp(() {
      documents = Directory.systemTemp.createTempSync('detached_reattach');
      File('${documents.path}/b_unkeyed.mp4').writeAsBytesSync(const [0]);
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(documents.path);
      // The reattach resolves the documents path, which caches it for every
      // later suite in the merged test isolate.
      resetCachedDocumentsPath();

      clipBloc = _MockClipEditorBloc();
      mainBloc = _MockVideoEditorMainBloc();
      overlayBloc = _MockTimelineOverlayBloc();
      when(() => clipBloc.isClosed).thenReturn(false);
      when(() => mainBloc.state).thenReturn(
        const VideoEditorMainState(currentPosition: Duration(seconds: 1)),
      );
    });

    tearDown(() {
      resetCachedDocumentsPath();
      PathProviderPlatform.instance = originalPathProvider;
      if (documents.existsSync()) documents.deleteSync(recursive: true);
    });

    WidgetLayer detachedLayer() {
      final meta = DetachedClipLayerData(
        clip: DivineVideoClip(
          id: 'b',
          video: EditorVideo.file('${documents.path}/b_unkeyed.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
        layerId: 'detached_b',
        chromaKey: key,
        bakedChromaKey: DetachedClipBakedChromaKey(
          videoPath: '${documents.path}/b_keyed.mp4',
          sourcePath: '${documents.path}/b_unkeyed.mp4',
          chromaKey: key,
        ),
      ).toMeta();
      return WidgetLayer(
        id: 'detached_b',
        widget: const SizedBox.shrink(),
        meta: meta,
        exportConfigs: WidgetLayerExportConfigs(id: 'detached_b', meta: meta),
      );
    }

    testWidgets('hands the live key and the baked one to the clip editor', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ClipEditorBloc>.value(value: clipBloc),
            BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
            BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
          ],
          child: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final layer = detachedLayer();

      await reattachDetachedClip(
        context,
        layer,
        item: TimelineOverlayItem(
          id: layer.id,
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          endTime: const Duration(seconds: 2),
          layer: layer,
        ),
      );

      final request =
          verify(() => clipBloc.add(captureAny())).captured.single
              as ClipEditorDetachedClipReattachRequested;
      // The bloc decides whether the baked file comes back, and needs both:
      // a layer whose key was taken off comes back without one.
      expect(request.chromaKey, key);
      expect(
        request.bakedChromaKey?.videoPath,
        '${documents.path}/b_keyed.mp4',
      );
      expect(request.clip.video?.file?.path, '${documents.path}/b_unkeyed.mp4');
    });
  });
}
