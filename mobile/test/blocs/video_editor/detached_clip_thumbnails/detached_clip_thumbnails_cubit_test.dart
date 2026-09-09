// ABOUTME: Tests that a detached clip's filmstrip resolves from layer meta and
// ABOUTME: is extracted once, not again on every selection

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/detached_clip_thumbnails/detached_clip_thumbnails_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart'
    show StripThumbnail;
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

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/documents/clip-1.mp4'),
  duration: const Duration(seconds: 4),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 0.5625,
  thumbnailPath: '/documents/clip-1.jpg',
);

Map<String, dynamic> _meta() =>
    DetachedClipLayerData(clip: _clip(), layerId: 'layer-1').toMeta();

/// The source key the cubit and the pool agree on for [meta].
String _sourceKey(Map<String, dynamic> meta) {
  final raw = meta['clip'];
  if (raw is! Map) return 'unreadable';
  return '${raw['id']}|${raw['filePath']}|${raw['trimStartMs']}'
      '|${raw['trimEndMs']}|${raw['playbackSpeed']}|${raw['volume']}';
}

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;
  late int opens;
  late StreamController<List<StripThumbnail>> frames;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('detached_thumbnails');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    opens = 0;
    frames = StreamController<List<StripThumbnail>>.broadcast();

    // No platform channel in a unit test: the manager is driven from a stream
    // the test owns, so the frames arrive when the test says they do.
    DetachedClipThumbnails.openOverride = (clip, _) async {
      opens++;
      return DetachedClipThumbnails.withManager(
        ClipThumbnailManager(
          stripThumbnailStreamFactory: ({
            required videoPath,
            required clipId,
            required duration,
            required outputSize,
            required thumbsPerSecond,
            startOffset = Duration.zero,
            priorityTimestamps,
          }) => frames.stream,
        )..sync(clips: [clip], devicePixelRatio: 1),
        clip.id,
      );
    };
  });

  tearDown(() async {
    DetachedClipThumbnails.openOverride = null;
    detachedClipThumbnailPool.resetForTesting();
    await frames.close();
    PathProviderPlatform.instance = originalPathProvider;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group(DetachedClipThumbnailsCubit, () {
    DetachedClipThumbnailsCubit build(Map<String, dynamic> meta) {
      final cubit = DetachedClipThumbnailsCubit(
        meta: meta,
        devicePixelRatio: 1,
        sourceKey: _sourceKey(meta),
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('reads the clip shape and poster out of the layer meta', () async {
      final cubit = build(_meta());

      final ready = await cubit.stream.firstWhere((s) => s.isReady);

      // Everything the bar needs to lay itself out, without the widget ever
      // touching a clip or a documents path.
      expect(ready.aspectRatio, 0.5625);
      expect(ready.posterPath, '${tempDir.path}/clip-1.jpg');
      expect(ready.span, const Duration(seconds: 4));
    });

    test('publishes extracted frames as they arrive', () async {
      final cubit = build(_meta());
      await cubit.stream.firstWhere((s) => s.isReady);

      final withFrames = cubit.stream.firstWhere((s) => s.frames.isNotEmpty);
      frames.add([
        const StripThumbnail(
          path: '/frames/0.jpg',
          timestamp: Duration(seconds: 1),
        ),
      ]);

      final state = await withFrames;
      expect(state.frames.single.path, '/frames/0.jpg');
      expect(state.frames.single.timestamp, const Duration(seconds: 1));
    });

    test('extracts once across the remount a selection causes', () async {
      final meta = _meta();
      final first = build(meta);
      await first.stream.firstWhere((s) => s.isReady);
      expect(opens, 1);

      // Selecting the row wraps its tile, which recreates the cubit. Without
      // the pool that re-extracts the whole strip, visibly, on every tap.
      await first.close();
      final second = build(meta);
      await second.stream.firstWhere((s) => s.isReady);

      expect(opens, 1);
    });

    test('shows a pooled strip on its very first state', () async {
      final meta = _meta();
      final first = build(meta);
      await first.stream.firstWhere((s) => s.isReady);
      frames.add([
        const StripThumbnail(
          path: '/frames/0.jpg',
          timestamp: Duration(seconds: 1),
        ),
      ]);
      await first.stream.firstWhere((s) => s.frames.isNotEmpty);
      await first.close();

      final second = build(meta);
      final ready = await second.stream.firstWhere((s) => s.isReady);

      // The remount renders the frames it had rather than flashing posters.
      expect(ready.frames, hasLength(1));
    });

    test('emits nothing for meta that is not a detached clip', () async {
      final cubit = build({'description': 'a sticker'});
      final states = <DetachedClipThumbnailsState>[];
      final subscription = cubit.stream.listen(states.add);
      await pumpEventQueue();
      await subscription.cancel();

      // An unreadable layer must not take down the timeline it sits in.
      expect(states, isEmpty);
      expect(opens, 0);
    });
  });
}
