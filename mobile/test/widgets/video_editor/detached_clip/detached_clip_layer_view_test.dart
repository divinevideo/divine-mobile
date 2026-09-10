// ABOUTME: Tests the detached clip's playhead mapping and its still poster,
// ABOUTME: the two halves that work without a native decoder.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_keyed_video.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_player.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_player_registry.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

DivineVideoClip _clip({
  Duration duration = const Duration(seconds: 6),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double? playbackSpeed,
  String? thumbnailPath,
}) => DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/documents/clip-1.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .square,
  originalAspectRatio: 1,
  trimStart: trimStart,
  trimEnd: trimEnd,
  playbackSpeed: playbackSpeed,
  thumbnailPath: thumbnailPath,
);

/// The poster reads no localized copy, but every app root under `mobile/test`
/// registers the delegates so a later `context.l10n` read cannot fail silently
/// (#3613).
Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// Mounts [child] the way the editor mounts a layer: a fixed-width box whose
/// child is measured unbounded by a `FittedBox` and then scaled.
Widget _layerHost(Widget child) => Center(
  child: SizedBox(width: 120, child: FittedBox(child: child)),
);

void main() {
  group('detachedClipPlayerPosition', () {
    test('starts at zero, because the player is already trimmed', () {
      final position = detachedClipPlayerPosition(
        Duration.zero,
        _clip(trimStart: const Duration(seconds: 1)),
      );

      // The companion loads the clip with its trim as the source range, so its
      // own timeline starts at the trim point. Adding the trim on top of that
      // would seek a second later than the layer's first frame.
      expect(position, Duration.zero);
    });

    test('advances with the playhead', () {
      final position = detachedClipPlayerPosition(
        const Duration(seconds: 2),
        _clip(trimStart: const Duration(seconds: 1)),
      );

      expect(position, const Duration(seconds: 2));
    });

    test('tracks wall clock, not source time, on a sped-up clip', () {
      final position = detachedClipPlayerPosition(
        const Duration(seconds: 2),
        _clip(playbackSpeed: 2),
      );

      // The player applies the clip's speed itself and reports playback time,
      // so handing it source time would seek twice as far as the layer has run.
      expect(position, const Duration(seconds: 2));
    });

    test('offsets by where the layer starts on the timeline', () {
      final position = detachedClipPlayerPosition(
        const Duration(seconds: 5),
        _clip(),
        layerStart: const Duration(seconds: 3),
      );

      expect(position, const Duration(seconds: 2));
    });

    test('clamps to the clip start before its window opens', () {
      final position = detachedClipPlayerPosition(
        const Duration(seconds: 1),
        _clip(trimStart: const Duration(seconds: 1)),
        layerStart: const Duration(seconds: 4),
      );

      // Seeking to a negative position throws on the native side.
      expect(position, Duration.zero);
    });

    test('parks on the last frame past the clip end', () {
      final position = detachedClipPlayerPosition(
        const Duration(seconds: 30),
        _clip(trimEnd: const Duration(seconds: 2)),
      );

      // Six seconds of source less a two-second tail is four of playback.
      expect(position, const Duration(seconds: 4));
    });

    test('starts a split tail where the head stopped', () {
      final position = detachedClipPlayerPosition(
        Duration.zero,
        _clip(),
        sourceOffset: const Duration(seconds: 2),
      );

      // Without the offset the tail would rewind to the clip's first frame at
      // its own start, replaying what the head just showed.
      expect(position, const Duration(seconds: 2));
    });

    test('advances a split tail from its offset', () {
      final position = detachedClipPlayerPosition(
        const Duration(seconds: 5),
        _clip(),
        layerStart: const Duration(seconds: 4),
        sourceOffset: const Duration(seconds: 2),
      );

      expect(position, const Duration(seconds: 3));
    });

    test('parks at the sped-up length, not the source length', () {
      final position = detachedClipPlayerPosition(
        const Duration(seconds: 30),
        _clip(playbackSpeed: 2),
      );

      // A six-second clip at 2x is on screen for three.
      expect(position, const Duration(seconds: 3));
    });
  });

  group('detachedClipPlayerKey', () {
    Map<String, dynamic> meta(String layerId) =>
        DetachedClipLayerData(clip: _clip(), layerId: layerId).toMeta();

    test('gives two layers of one clip their own player', () {
      // A player carries one position and one time window, so two layers can
      // only share it while they sit at the same moment — where a duplicate
      // starts, and never again once it is moved or split.
      expect(
        detachedClipPlayerKey(meta('layer-1')),
        isNot(detachedClipPlayerKey(meta('layer-2'))),
      );
    });

    test('is stable across a meta rebuild for the same layer', () {
      // A history write hands the layer an equal but distinct map; a key that
      // changed there would drop the pooled player on every undo.
      expect(
        detachedClipPlayerKey(meta('layer-1')),
        detachedClipPlayerKey(meta('layer-1')),
      );
    });

    test('is null for meta that names no clip', () {
      expect(detachedClipPlayerKey({'kind': 'sticker'}), isNull);
    });
  });

  group(DetachedClipLayerView, () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('detached_layer_view');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      detachedClipPlayers.resetForTesting();
      resetCachedDocumentsPath();
      await getDocumentsPath();
    });

    tearDown(() {
      resetCachedDocumentsPath();
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Map<String, dynamic> keyedMeta(ChromaKey key) => DetachedClipLayerData(
      clip: _clip(),
      layerId: 'layer-1',
      chromaKey: ClipChromaKey(key: key),
    ).toMeta();

    ChromaKeyedVideo keyedVideo(WidgetTester tester) =>
        tester.widget(find.byType(ChromaKeyedVideo).first);

    Future<void> disposeLayerView(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      detachedClipPlayers.resetForTesting();
    }

    testWidgets(
      'applies the layer key over the canvas without a checkerboard',
      (tester) async {
        await tester.pumpWidget(
          _app(
            _layerHost(
              DetachedClipLayerView(
                meta: keyedMeta(const ChromaKey.greenScreen()),
              ),
            ),
          ),
        );

        final preview = keyedVideo(tester);
        expect(preview.chromaKey?.key, const ChromaKey.greenScreen());
        expect(preview.previewTransparency, isFalse);
        await disposeLayerView(tester);
      },
    );

    testWidgets('re-reads a changed layer key without replacing the view', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _layerHost(
            DetachedClipLayerView(
              meta: keyedMeta(const ChromaKey.greenScreen()),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        _app(
          _layerHost(
            DetachedClipLayerView(
              meta: keyedMeta(const ChromaKey.blueScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      final preview = keyedVideo(tester);
      expect(preview.chromaKey?.key, const ChromaKey.blueScreen());
      expect(preview.previewTransparency, isFalse);
      await disposeLayerView(tester);
    });
  });

  group(DetachedClipPoster, () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('detached_poster');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    testWidgets('lays out under the unbounded constraints a layer gets', (
      tester,
    ) async {
      final meta = DetachedClipLayerData(
        clip: _clip(),
        layerId: 'layer-1',
      ).toMeta();

      // pro_image_editor renders a layer inside a FittedBox, which measures
      // its child unbounded. An AspectRatio threw `RenderAspectRatio has
      // unbounded constraints` there and the layer drew nothing at all.
      await tester.pumpWidget(_app(_layerHost(DetachedClipPoster(meta: meta))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('sizes itself in the clip aspect ratio', (tester) async {
      final meta = DetachedClipLayerData(
        clip: _clip(),
        layerId: 'layer-1',
      ).toMeta();

      await tester.pumpWidget(_app(_layerHost(DetachedClipPoster(meta: meta))));
      await tester.pumpAndSettle();

      // The FittedBox scales whatever the content lays itself out at, so only
      // the ratio has to be right — the absolute size never reaches the screen.
      final size = tester.getSize(
        find.descendant(
          of: find.byType(DetachedClipPoster),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(size.width / size.height, closeTo(1, 0.001));
    });

    testWidgets('renders nothing for meta it cannot read', (tester) async {
      await tester.pumpWidget(
        _app(const DetachedClipPoster(meta: {'description': 'a sticker'})),
      );
      await tester.pumpAndSettle();

      // A layer the loader could not resolve must not take down the tree it
      // is mounted in.
      expect(find.byType(ClipRRect), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens no video player', (tester) async {
      final meta = DetachedClipLayerData(
        clip: _clip(),
        layerId: 'layer-1',
      ).toMeta();

      await tester.pumpWidget(_app(DetachedClipPoster(meta: meta)));
      await tester.pumpAndSettle();

      // The draft render path mounts every layer offscreen just to rasterize
      // it; a decoder started there is a codec nobody watches.
      expect(find.byType(DetachedClipLayerView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
