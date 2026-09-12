// ABOUTME: Drives the detached clip's green-screen action end to end: the
// ABOUTME: screen it opens, and what it writes back onto the layer.

import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/screens/video_editor/video_clip_chroma_key_screen.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_chroma_key.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../helpers/divine_video_player_channel.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Keeps the screen's on-open measurement off the platform channel.
///
/// Reporting no screen is the ordinary outcome for footage without one, so
/// the screen opens on the green preset and the test drives it from there.
class _StubProVideoEditor extends ProVideoEditor {
  @override
  void initializeStream() {
    // Intentional no-op: nothing native to stream from in a widget test.
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    throw const ChromaKeyDetectionException('no screen in test footage');
  }
}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _FakeLayer extends Fake implements Layer {}

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/old/clip-1.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.square,
  originalAspectRatio: 1,
);

WidgetLayer _detachedLayer({ClipChromaKey? chromaKey}) {
  final meta = DetachedClipLayerData(
    clip: _clip(),
    layerId: 'layer-1',
    sourceOffset: const Duration(seconds: 2),
    chromaKey: chromaKey,
  ).toMeta();
  return WidgetLayer(
    id: 'layer-1',
    widget: const SizedBox.shrink(),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'layer-1', meta: meta),
  );
}

void main() {
  group('editDetachedClipChromaKey', () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;
    late ProVideoEditor originalProVideoEditor;
    late _MockProImageEditorState editor;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(_FakeLayer());
    });

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('detached_chroma');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _StubProVideoEditor();

      // The screen opens a preview player on the clip's file; both halves of
      // the native player are mocked so it initializes without a plugin.
      DivineVideoPlayerController.resetIdCounterForTesting();
      installMockDivineVideoPlayer();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('divine_video_player'),
        (call) async =>
            call.method == 'create' ? <String, Object?>{'textureId': 1} : null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
      });

      editor = _MockProImageEditorState();
      when(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      ).thenAnswer((_) {});
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      ProVideoEditor.instance = originalProVideoEditor;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// A page with one button that runs the action for [layer], inside the
    /// scope the timeline's action bar would provide.
    Future<void> pump(WidgetTester tester, Layer layer) async {
      when(() => editor.activeLayers).thenReturn([layer]);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoEditorScope(
            editorKey: GlobalKey(),
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 1,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
            playheadAdvancingNotifier: ValueNotifier<bool>(false),
            fromLibrary: false,
            onOpenCamera: () {},
            onOpenClipsEditor: () {},
            onAddStickers: () {},
            onAddEditTextLayer: ([layer]) async => null,
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            editorOverride: editor,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => editDetachedClipChromaKey(context, layer),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // Documents path, then the route's fade. Bounded rather than settled:
      // the screen's controls carry a spinner while it measures.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    /// The layer the action wrote back, read off the editor.
    WidgetLayer written() =>
        verify(
              () => editor.replaceLayer(
                index: 0,
                layer: captureAny(named: 'layer'),
              ),
            ).captured.single
            as WidgetLayer;

    testWidgets('opens the detached variant of the green-screen screen', (
      tester,
    ) async {
      await pump(tester, _detachedLayer());

      expect(find.byType(VideoClipChromaKeyScreen), findsOneWidget);
      // A live key has no second track for a library clip to play on.
      expect(find.text(l10n.videoEditorChromaKeyBackgroundVideo), findsNothing);
      expect(
        find.text(l10n.videoEditorChromaKeyCanvasTransparentHint),
        findsOneWidget,
      );
    });

    testWidgets('writes the confirmed key onto the layer, keeping the rest', (
      tester,
    ) async {
      await pump(tester, _detachedLayer());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorChromaKeyDoneSemanticLabel),
      );
      await tester.pumpAndSettle();

      final layer = written();
      final meta = DetachedClipLayerData.metaOf(layer);
      expect(DetachedClipLayerData.hasChromaKey(meta), isTrue);
      // Both meta slots and the live widget follow, the way a crop's
      // write-back does, so a draft round-trip and the canvas agree.
      expect(DetachedClipLayerData.hasChromaKey(layer.meta), isTrue);
      expect(
        DetachedClipLayerData.hasChromaKey(layer.exportConfigs.meta),
        isTrue,
      );
      expect(layer.widget, isA<DetachedClipLayerView>());
      // The layer's own settings survive: the key is added, not the meta
      // rebuilt.
      expect(DetachedClipLayerData.layerIdOf(meta), 'layer-1');
      expect(
        DetachedClipLayerData.sourceOffsetOf(meta),
        const Duration(seconds: 2),
      );
      expect(find.byType(VideoClipChromaKeyScreen), findsNothing);
    });

    testWidgets('takes the key off the layer on Remove', (tester) async {
      await pump(
        tester,
        _detachedLayer(
          chromaKey: const ClipChromaKey(key: ChromaKey.blueScreen()),
        ),
      );

      final remove = find.text(l10n.videoEditorChromaKeyRemove);
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();

      final meta = DetachedClipLayerData.metaOf(written());
      expect(DetachedClipLayerData.hasChromaKey(meta), isFalse);
      expect(DetachedClipLayerData.layerIdOf(meta), 'layer-1');
    });

    testWidgets('leaves the layer alone when the screen is dismissed', (
      tester,
    ) async {
      await pump(tester, _detachedLayer());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorChromaKeyCloseSemanticLabel),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      );
    });

    testWidgets('does nothing for a layer that is not a detached clip', (
      tester,
    ) async {
      await pump(tester, TextLayer(text: 'caption'));

      expect(find.byType(VideoClipChromaKeyScreen), findsNothing);
      verifyNever(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      );
    });
  });
}
