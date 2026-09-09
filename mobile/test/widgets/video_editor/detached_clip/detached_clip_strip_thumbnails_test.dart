// ABOUTME: Tests the filmstrip behind a detached clip's timeline bar — how many
// ABOUTME: slots it lays out and which frame each one picks.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/detached_clip_thumbnails/detached_clip_thumbnails_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_strip_thumbnails.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

DivineVideoClip _clip({double aspectRatio = 0.5625}) => DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/documents/clip-1.mp4'),
  duration: const Duration(seconds: 4),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: aspectRatio,
);

/// Unmounts the strip and drops the pooled entry inside the test body.
///
/// Releasing arms the pool's grace timer, and `flutter_test` reports a pending
/// timer before `tearDown` gets a chance to cancel it.
Future<void> _settlePool(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  detachedClipThumbnailPool.resetForTesting();
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('detached_strip');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    // No platform channel in a widget test: the strip is driven by a manager
    // whose extraction stream never emits, so every slot falls back to the
    // poster. The slot geometry is what these tests are about.
    DetachedClipThumbnails.openOverride = (clip, _) async =>
        DetachedClipThumbnails.withManager(
          ClipThumbnailManager(
            stripThumbnailStreamFactory: ({
              required videoPath,
              required clipId,
              required duration,
              required outputSize,
              required thumbsPerSecond,
              startOffset = Duration.zero,
              priorityTimestamps,
            }) => const Stream.empty(),
          )..sync(clips: [clip], devicePixelRatio: 1),
          clip.id,
        );
  });

  tearDown(() {
    DetachedClipThumbnails.openOverride = null;
    detachedClipThumbnailPool.resetForTesting();
    PathProviderPlatform.instance = originalPathProvider;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group(DetachedClipStripThumbnails, () {
    testWidgets('fills the bar with one slot per clip-width of frames', (
      tester,
    ) async {
      final meta = DetachedClipLayerData(
        clip: _clip(),
        layerId: 'layer-1',
      ).toMeta();

      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            height: 40,
            child: DetachedClipStripThumbnails(meta: meta),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A 9:16 clip in a 40px-tall bar is 22.5px wide per frame, so a 200px bar
      // takes nine of them. One stretched frame would read as a smear rather
      // than a filmstrip.
      final slots = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(DetachedClipStripThumbnails),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == 40,
          ),
        ),
      );
      expect(slots, hasLength(9));
      await _settlePool(tester);
    });

    testWidgets('lays out fewer, wider slots for a landscape clip', (
      tester,
    ) async {
      final meta = DetachedClipLayerData(
        clip: _clip(aspectRatio: 16 / 9),
        layerId: 'layer-1',
      ).toMeta();

      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            height: 40,
            child: DetachedClipStripThumbnails(meta: meta),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 40px tall at 16:9 is 71px per frame — three cover the bar.
      final slots = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(DetachedClipStripThumbnails),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == 40,
          ),
        ),
      );
      expect(slots, hasLength(3));
      await _settlePool(tester);
    });

    testWidgets('renders nothing for meta it cannot read', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 40,
            child: DetachedClipStripThumbnails(meta: {'description': 'x'}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // An unreadable layer must not take down the timeline it sits in.
      expect(tester.takeException(), isNull);
      expect(find.byType(Row), findsNothing);
      await _settlePool(tester);
    });

    testWidgets('survives an unbounded bar without laying out slots', (
      tester,
    ) async {
      final meta = DetachedClipLayerData(
        clip: _clip(),
        layerId: 'layer-1',
      ).toMeta();

      await tester.pumpWidget(
        _app(
          Row(
            children: [
              SizedBox(
                height: 40,
                child: DetachedClipStripThumbnails(meta: meta),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // An unbounded width gives no slot count to compute; drawing nothing
      // beats throwing inside a timeline row.
      expect(tester.takeException(), isNull);
      await _settlePool(tester);
    });
  });
}
