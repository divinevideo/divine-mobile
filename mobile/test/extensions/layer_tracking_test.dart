// ABOUTME: Tests how a tracked object's path becomes a layer's keyframes.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_tracking.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:openvine/models/video_editor/track_frame_mapping.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show AnimationCurve, Layer, LayerKeyframe, LayerPlacement;
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ObjectTrackSample, VideoObjectTrack;

void main() {
  const ms = Duration(milliseconds: 1);
  // A vertical frame filling a vertical canvas: a frame fraction f is the
  // layer offset ((f.dx - 0.5) * 225, (f.dy - 0.5) * 400).
  final mapping = TrackFrameMapping(
    canvasSize: const Size(225, 400),
    videoAspectRatio: 9 / 16,
    targetAspectRatio: 9 / 16,
  );

  LayerTrackTarget target({
    Duration start = Duration.zero,
    Duration end = const Duration(seconds: 2),
    Duration anchor = const Duration(seconds: 1),
  }) => LayerTrackTarget(
    clipId: 'clip',
    video: EditorVideo.file('/tmp/clip.mp4'),
    clipStart: Duration.zero,
    trimStart: Duration.zero,
    speed: 1,
    start: start,
    end: end,
    anchor: anchor,
    videoAspectRatio: 9 / 16,
    targetAspectRatio: 9 / 16,
  );

  /// An object crossing the frame from x [from] to [to] (fractions) over two
  /// seconds at 30 fps, marked at one second, sized [scaleAt] times its
  /// marked size.
  VideoObjectTrack crossing({
    double from = 0.3,
    double to = 0.7,
    double Function(double seconds)? scaleAt,
    Offset Function(double seconds)? centerAt,
  }) => VideoObjectTrack(
    anchorTime: ms * 1000,
    samples: [
      for (var i = 0; i <= 60; i++)
        () {
          final seconds = i / 30;
          final scale = scaleAt?.call(seconds) ?? 1.0;
          return ObjectTrackSample(
            time: ms * (seconds * 1000).round(),
            center:
                centerAt?.call(seconds) ??
                Offset(from + (to - from) * seconds / 2, 0.5),
            size: Size(0.2 * scale, 0.1 * scale),
            scale: scale,
          );
        }(),
    ],
  );

  const placement = LayerPlacement(
    offset: Offset(0, -100),
    scale: 1.5,
    rotation: 0.2,
    opacity: 0.8,
  );

  List<LayerKeyframe> keyframesFor(
    Layer layer,
    VideoObjectTrack track, {
    LayerTrackTarget? on,
    LayerPlacement Function(Duration time)? placementAt,
  }) => trackedLayerKeyframes(
    layer: layer,
    track: track,
    target: on ?? target(),
    mapping: mapping,
    placementAt: placementAt ?? (_) => placement,
  )!;

  Matcher offsetNear(Offset expected, [double tolerance = 1e-6]) =>
      isA<Offset>()
          .having((o) => o.dx, 'dx', closeTo(expected.dx, tolerance))
          .having((o) => o.dy, 'dy', closeTo(expected.dy, tolerance));

  group('trackedLayerKeyframes', () {
    test('keeps the layer where it sat against the object', () {
      final keyframes = keyframesFor(Layer(), crossing());

      // A steady crossing needs no keyframes between its two ends.
      expect(keyframes.map((k) => k.time), [Duration.zero, ms * 2000]);
      expect(keyframes.first.offset, offsetNear(const Offset(-45, -100)));
      expect(keyframes.last.offset, offsetNear(const Offset(45, -100)));
      for (final keyframe in keyframes) {
        expect(keyframe.scale, 1.5);
        expect(keyframe.rotation, 0.2);
        expect(keyframe.opacity, 0.8);
        expect(keyframe.curve, AnimationCurve.linear);
      }
    });

    test('grows and shrinks the layer, and its distance, with the object', () {
      final keyframes = keyframesFor(
        Layer(),
        crossing(from: 0.5, to: 0.5, scaleAt: (s) => 1 + 0.5 * (s - 1)),
      );
      final last = keyframes.last;
      expect(last.time, ms * 2000);
      expect(last.scale, closeTo(1.5 * 1.5, 1e-9));
      expect(last.offset, offsetNear(const Offset(0, -150)));
      expect(keyframes.first.scale, closeTo(1.5 * 0.5, 1e-9));
      expect(keyframes.first.offset, offsetNear(const Offset(0, -50)));
    });

    test('keeps the fade and turn the layer has at each moment', () {
      final keyframes = keyframesFor(
        Layer(),
        crossing(),
        placementAt: (time) => LayerPlacement(
          offset: const Offset(0, -100),
          rotation: time.inMilliseconds / 1000,
          opacity: 1 - time.inMilliseconds / 4000,
        ),
      );
      expect(keyframes.first.rotation, 0);
      expect(keyframes.last.rotation, closeTo(2, 1e-9));
      expect(keyframes.last.opacity, closeTo(0.5, 1e-9));
    });

    test('keeps a keyframe where the object turns a corner', () {
      final keyframes = keyframesFor(
        Layer(),
        crossing(
          centerAt: (s) => s <= 1
              ? Offset(0.3 + 0.2 * s, 0.5)
              : Offset(0.5, 0.5 - 0.2 * (s - 1)),
        ),
      );
      expect(keyframes.map((k) => k.time), [
        Duration.zero,
        ms * 1000,
        ms * 2000,
      ]);
    });

    test('only follows the object inside the stretch it was tracked for', () {
      final keyframes = keyframesFor(
        Layer(),
        crossing(),
        on: target(start: ms * 500, end: ms * 1500),
      );
      expect(keyframes.first.time, ms * 500);
      expect(keyframes.last.time, ms * 1500);
      expect(keyframes.first.offset, offsetNear(const Offset(-22.5, -100)));
    });

    test('times the keyframes from the start of the layer', () {
      final keyframes = keyframesFor(Layer(startTime: ms * 500), crossing());
      expect(keyframes.first.time, ms * -500);
      expect(keyframes.last.time, ms * 1500);
    });

    test('replaces the keyframes inside the stretch, keeps the others', () {
      final layer = Layer(
        keyframes: [
          const LayerKeyframe(
            time: Duration(milliseconds: 600),
            offset: Offset(9, 9),
          ),
          const LayerKeyframe(
            time: Duration(milliseconds: 3500),
            offset: Offset(7, 7),
          ),
        ],
      );
      final keyframes = keyframesFor(layer, crossing());
      expect(keyframes.map((k) => k.time), [
        Duration.zero,
        ms * 2000,
        ms * 3500,
      ]);
      expect(keyframes.last.offset, const Offset(7, 7));
    });

    test('gives nothing for a track that stays on the marked frame', () {
      final track = VideoObjectTrack(
        anchorTime: ms * 1000,
        samples: [
          ObjectTrackSample(
            time: ms * 1000,
            center: const Offset(0.5, 0.5),
            size: const Size(0.2, 0.1),
          ),
        ],
      );
      expect(
        trackedLayerKeyframes(
          layer: Layer(),
          track: track,
          target: target(),
          mapping: mapping,
          placementAt: (_) => placement,
        ),
        isNull,
      );
    });
  });

  group('simplifyTrackedPoses', () {
    TrackedPose pose(int ms, double x, {double scale = 1}) => (
      time: Duration(milliseconds: ms),
      offset: Offset(x, 0),
      scale: scale,
      rotation: 0,
      opacity: 1,
    );

    test('drops what a straight line already covers', () {
      final poses = [for (var i = 0; i <= 10; i++) pose(i * 100, i * 5.0)];
      expect(
        simplifyTrackedPoses(poses, tolerance: 0.6, referenceSize: 80),
        [poses.first, poses.last],
      );
    });

    test('keeps a pose further off the line than the tolerance', () {
      final poses = [pose(0, 0), pose(100, 1), pose(200, 0)];
      expect(
        simplifyTrackedPoses(poses, tolerance: 0.6, referenceSize: 80),
        poses,
      );
      expect(
        simplifyTrackedPoses(
          [pose(0, 0), pose(100, 0.5), pose(200, 0)],
          tolerance: 0.6,
          referenceSize: 80,
        ),
        hasLength(2),
      );
    });

    test('weighs a change of size like a move', () {
      // 1 % at a reference size of 80 counts as 0.8 px.
      final poses = [pose(0, 0), pose(100, 0, scale: 1.01), pose(200, 0)];
      expect(
        simplifyTrackedPoses(poses, tolerance: 0.6, referenceSize: 80),
        poses,
      );
    });
  });
}
