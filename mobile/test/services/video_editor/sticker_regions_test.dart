// ABOUTME: Tests where a rendered video's tappable stickers stand: placed on
// ABOUTME: the kept frame from the export's capture, and timed on the output.

import 'dart:math' show pi;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show VideoStickerKind, VideoStickerRegion;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/sticker_regions.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

const _link = SocialStickerData(
  kind: SocialStickerKind.link,
  url: 'https://divine.video/about',
);

/// The capture of a sticker carrying [data], standing [offset] from the
/// body's centre, [box] big before it is turned by [rotation].
ExportedLayer _captured(
  SocialStickerData data, {
  Offset offset = Offset.zero,
  Size box = const Size(144, 32),
  double rotation = 0,
  Duration? startTime,
  Duration? endTime,
  List<LayerAnimation> animations = const [],
  double opacity = 1,
  BlendMode blendMode = BlendMode.srcOver,
  LayerMask? mask,
}) {
  final meta = data.toMeta();
  return ExportedLayer(
    layer: WidgetLayer(
      id: 'sticker',
      widget: const SizedBox(),
      offset: offset,
      rotation: rotation,
      startTime: startTime,
      endTime: endTime,
      animations: animations,
      opacity: opacity,
      blendMode: blendMode,
      mask: mask,
      meta: meta,
      exportConfigs: WidgetLayerExportConfigs(id: 'sticker', meta: meta),
    ),
    bytes: Uint8List(0),
    logicalSize: box,
    boxSize: box,
  );
}

/// The capture of a layer that is no social sticker, such as an emoji,
/// standing [offset] from the body's centre, [box] big.
ExportedLayer _other({
  Offset offset = Offset.zero,
  Size box = const Size(40, 40),
  Duration? startTime,
  Duration? endTime,
  List<LayerAnimation> animations = const [],
}) => ExportedLayer(
  layer: WidgetLayer(
    id: 'emoji',
    widget: const SizedBox(),
    offset: offset,
    startTime: startTime,
    endTime: endTime,
    animations: animations,
  ),
  bytes: Uint8List(0),
  logicalSize: box,
  boxSize: box,
);

/// The editor timeline of one clip lasting [duration].
TransitionTimelineMap _timeline(Duration duration) =>
    TransitionTimelineMap.fromClips([
      DivineVideoClip(
        id: 'clip',
        video: EditorVideo.file('/clip.mp4'),
        duration: duration,
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      ),
    ]);

List<VideoStickerRegion> _regions(
  List<ExportedLayer> layers, {
  Size bodySize = const Size(360, 640),
}) => stickerRegionsFor(
  capturedLayers: layers,
  bodySize: bodySize,
  targetAspectRatio: 9 / 16,
  timelineMap: _timeline(const Duration(seconds: 6)),
);

void main() {
  group('stickerRegionsFor', () {
    test('places a link sticker as a fraction of the frame', () {
      final regions = _regions([
        _captured(
          _link,
          offset: const Offset(0, -160),
          rotation: 0.3,
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 3),
        ),
      ]);

      expect(
        regions,
        equals([
          const VideoStickerRegion(
            kind: VideoStickerKind.link,
            target: 'https://divine.video/about',
            centerX: 0.5,
            centerY: 0.25,
            width: 0.4,
            height: 0.05,
            rotation: 0.3,
            start: Duration(seconds: 1),
            end: Duration(seconds: 3),
            style: 'light',
            label: 'divine.video',
          ),
        ]),
      );
    });

    test('measures against the part of the body the export keeps', () {
      // A 400 by 800 body keeps 400 by 711.1 of a 9:16 export, from 44.4
      // down, so the body's centre is still the frame's.
      final region = _regions([
        _captured(_link),
      ], bodySize: const Size(400, 800)).single;

      expect(region.centerY, closeTo(0.5, 1e-9));
      expect(region.height, closeTo(32 / (400 * 16 / 9), 1e-9));
      expect(region.width, closeTo(144 / 400, 1e-9));
    });

    test('opens a hashtag and a mention by what they point to', () {
      final regions = _regions([
        _captured(
          const SocialStickerData(
            kind: SocialStickerKind.hashtag,
            hashtag: 'Summer',
          ),
        ),
        _captured(
          SocialStickerData(
            kind: SocialStickerKind.mention,
            pubkey: 'A' * 64,
            name: 'alice',
          ),
        ),
      ]);

      expect(
        regions.map((region) => (region.kind, region.target)),
        equals([
          (VideoStickerKind.hashtag, 'summer'),
          (VideoStickerKind.mention, 'a' * 64),
        ]),
      );
    });

    test('gives a sound credit a look only as the still note', () {
      final regions = _regions([
        _captured(
          const SocialStickerData(
            kind: SocialStickerKind.soundCredit,
            soundTitle: 'Song',
            soundArtist: 'Artist',
          ),
        ),
        _captured(
          const SocialStickerData(
            kind: SocialStickerKind.soundCredit,
            soundTitle: 'Song',
            soundId: 'bundled_song',
            soundDesign: SocialStickerSoundDesign.vinyl,
          ),
          offset: const Offset(0, 100),
        ),
      ]);

      expect(
        regions.map((region) => (region.kind, region.style, region.label)),
        equals([
          (VideoStickerKind.sound, 'light', 'Song\nArtist'),
          (VideoStickerKind.sound, null, 'Song'),
        ]),
      );
      expect(
        regions.map((region) => region.target),
        equals(['', 'bundled_song']),
      );
    });

    test('gives a faded, blended or masked sticker no look', () {
      // Apart, so no sticker lies on another.
      final regions = _regions([
        _captured(_link, opacity: 0.5, offset: const Offset(0, -150)),
        _captured(
          _link,
          blendMode: BlendMode.multiply,
          offset: const Offset(0, -50),
        ),
        _captured(
          _link,
          mask: const LayerMask(shape: LayerMaskShape.ellipse),
          offset: const Offset(0, 50),
        ),
        _captured(_link, offset: const Offset(0, 150)),
      ]);

      expect(
        regions.map((region) => region.style),
        equals([null, null, null, 'light']),
      );
    });

    test('gives a sticker no look where a layer above lies on it', () {
      String? styleWith(ExportedLayer upper, {double rotation = 0}) =>
          _regions([_captured(_link, rotation: rotation), upper]).single.style;

      expect(styleWith(_other()), isNull);
      expect(styleWith(_other(offset: const Offset(0, -60))), equals('light'));
      expect(
        styleWith(_other(offset: const Offset(0, -60)), rotation: pi / 2),
        isNull,
      );
      // Turned an eighth clockwise, the sticker runs down to the right.
      expect(
        styleWith(_other(offset: const Offset(50, 50)), rotation: pi / 4),
        isNull,
      );
      expect(
        styleWith(_other(offset: const Offset(50, 50)), rotation: -pi / 4),
        equals('light'),
      );
      expect(
        styleWith(
          _other(
            offset: const Offset(0, -200),
            animations: const [
              LayerAnimation(
                type: LayerAnimationType.slide,
                phase: AnimationPhase.animateIn,
                duration: Duration(milliseconds: 300),
                slideDirection: SlideDirection.left,
              ),
            ],
          ),
        ),
        isNull,
        reason: 'a moving layer may cross the sticker on its way',
      );
      expect(
        styleWith(
          _other(
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 2),
          ),
        ),
        isNull,
        reason: 'the sticker shows the whole video, so the two meet',
      );
      expect(
        _regions([
          _captured(_link, endTime: const Duration(seconds: 1)),
          _other(startTime: const Duration(seconds: 1)),
        ]).single.style,
        equals('light'),
      );
      expect(
        _regions([
          _captured(_link, startTime: const Duration(seconds: 1)),
          _other(endTime: const Duration(seconds: 1)),
        ]).single.style,
        equals('light'),
      );
      expect(
        _regions([_other(), _captured(_link)]).single.style,
        equals('light'),
      );
    });

    test('leaves out a sticker no one can see', () {
      expect(_regions([_captured(_link, opacity: 0)]), isEmpty);
    });

    test('redraws only looks that cover platform-dependent glyphs', () {
      expect(
        [
          for (final style in InfoStickerStyle.pills)
            _regions([_captured(_link.copyWith(style: style))]).single.style,
        ],
        equals(['light', null, null, 'brand', 'highlight', null, null, null]),
      );
    });

    test('leaves out a sticker that moves', () {
      final regions = _regions([
        _captured(
          _link,
          animations: const [
            LayerAnimation(
              type: LayerAnimationType.slide,
              phase: AnimationPhase.animateIn,
              duration: Duration(milliseconds: 300),
              slideDirection: SlideDirection.left,
            ),
          ],
        ),
      ]);

      expect(regions, isEmpty);
    });

    test('leaves out a sticker pushed off the frame', () {
      final regions = _regions([
        _captured(_link, offset: const Offset(0, -700)),
      ]);

      expect(regions, isEmpty);
    });

    test('places nothing without the body the offsets are measured in', () {
      expect(
        stickerRegionsFor(
          capturedLayers: [_captured(_link)],
          bodySize: null,
          targetAspectRatio: 9 / 16,
          timelineMap: _timeline(const Duration(seconds: 6)),
        ),
        isEmpty,
      );
    });
  });
}
