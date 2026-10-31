// ABOUTME: Tests where a poll, quiz or slider may stand on a video: above the
// ABOUTME: other layers, and moved or shrunk into the part the feed leaves clear.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/poll_sticker_placement.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

WidgetLayer _layer(String id, {bool poll = false}) {
  final meta = poll
      ? const SocialStickerData(
          kind: SocialStickerKind.poll,
          pollQuestion: 'Which one?',
          pollOptions: ['Red', 'Blue'],
        ).toMeta()
      : const SocialStickerData(
          kind: SocialStickerKind.hashtag,
          hashtag: 'summer',
        ).toMeta();
  return WidgetLayer(
    id: id,
    widget: const SizedBox(),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: id, meta: meta),
  );
}

void main() {
  group('pollLayerIndexBelowTop', () {
    test('finds a poll with another layer above it', () {
      expect(
        pollLayerIndexBelowTop([
          _layer('a'),
          _layer('p', poll: true),
          _layer('b'),
        ]),
        equals(1),
      );
    });

    test('leaves a poll on top, and a video without one, alone', () {
      expect(
        pollLayerIndexBelowTop([_layer('a'), _layer('p', poll: true)]),
        isNull,
      );
      expect(pollLayerIndexBelowTop([_layer('a'), _layer('b')]), isNull);
    });
  });

  group('layerDropBehindPoll', () {
    TimelineOverlayItem bar(String id, int row, {bool poll = false}) =>
        TimelineOverlayItem(
          id: id,
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          endTime: const Duration(seconds: 3),
          row: row,
          layer: _layer(id, poll: poll),
        );

    final items = [bar('a', 0), bar('p', 1, poll: true)];

    test('knows the bar of a poll', () {
      expect(isPollTimelineItem(items.last), isTrue);
      expect(isPollTimelineItem(items.first), isFalse);
    });

    test('keeps a drop above the poll as it is', () {
      expect(
        layerDropBehindPoll(items: items, row: 0, insertAbove: false),
        equals((row: 0, insertAbove: false)),
      );
      expect(
        layerDropBehindPoll(items: items, row: 1, insertAbove: true),
        equals((row: 1, insertAbove: true)),
      );
    });

    test('lifts a drop below the poll to its row, pushing the poll down', () {
      expect(
        layerDropBehindPoll(items: items, row: 1, insertAbove: false),
        equals((row: 1, insertAbove: true)),
      );
      expect(
        layerDropBehindPoll(items: items, row: 4, insertAbove: true),
        equals((row: 1, insertAbove: true)),
      );
    });

    test('leaves every drop alone without a poll', () {
      expect(
        layerDropBehindPoll(items: [bar('a', 0)], row: 3, insertAbove: false),
        equals((row: 3, insertAbove: false)),
      );
    });
  });

  group('pollSafeRect', () {
    test('marks the safe part of the frame an export keeps', () {
      // A 9:16 export keeps 400 by 711.1 of this body, from 44.4 down.
      final rect = pollSafeRect(
        bodySize: const Size(400, 800),
        targetAspectRatio: 9 / 16,
      );

      expect(rect.left, closeTo(24, 1e-9));
      expect(rect.right, closeTo(328, 1e-9));
      expect(rect.top, closeTo(165.33, 0.01));
      expect(rect.bottom, closeTo(627.56, 0.01));
    });
  });

  group('pollLayerNeedsLocking', () {
    test('locks a poll that can still turn or resize, or stands turned', () {
      final free = _layer('p', poll: true);
      final locked = _layer('p', poll: true)
        ..interaction = pollLayerInteraction();
      final turned = _layer('p', poll: true)
        ..interaction = pollLayerInteraction()
        ..rotation = 0.3;

      expect(pollLayerNeedsLocking(free), isTrue);
      expect(pollLayerNeedsLocking(locked), isFalse);
      expect(pollLayerNeedsLocking(turned), isTrue);
    });

    test('lets a poll move but not turn or resize', () {
      final interaction = pollLayerInteraction();

      expect(interaction.enableMove, isTrue);
      expect(interaction.enableRotate, isFalse);
      expect(interaction.enableScale, isFalse);
    });
  });

  group('fitPollIntoSafeArea', () {
    // A 9:16 export keeps 400 by 711.1 of this body, from 44.4 down, so the
    // safe area runs from 24 to 328 across and from 165.3 to 627.6 down.
    const body = Size(400, 800);

    ({Offset shift, double scale})? fit(
      Offset offset,
      Size size, {
      double rotation = 0,
    }) => fitPollIntoSafeArea(
      offset: offset,
      size: size,
      rotation: rotation,
      bodySize: body,
      targetAspectRatio: 9 / 16,
    );

    test('leaves a poll inside the safe area where it is', () {
      expect(fit(const Offset(-16, 0), const Size(200, 150)), isNull);
    });

    test('moves a poll pushed under the buttons on the right back', () {
      final result = fit(const Offset(150, 0), const Size(200, 150));

      expect(result?.scale, equals(1));
      expect(result?.shift.dx, closeTo(-122, 1e-9));
      expect(result?.shift.dy, equals(0));
    });

    test('shrinks a poll wider than the safe area, and keeps it inside', () {
      final result = fit(Offset.zero, const Size(400, 150))!;

      expect(result.scale, closeTo(304 / 400, 1e-9));
      // Shrunk to 304 wide about the body's centre, it runs from 48 to 352,
      // 24 past the right edge of the safe area.
      expect(result.shift.dx, closeTo(-24, 1e-9));
    });

    test('measures a turned poll by the box it covers', () {
      // Turned a quarter, 200 wide and 100 high covers 100 by 200; centred
      // 200 down it reaches from 100, 65.3 above the safe area.
      final result = fit(
        const Offset(-16, -200),
        const Size(200, 100),
        rotation: math.pi / 2,
      );

      expect(result?.scale, closeTo(1, 1e-9));
      expect(result?.shift.dx, closeTo(0, 1e-9));
      expect(result?.shift.dy, closeTo(65.33, 0.01));
    });
  });
}
