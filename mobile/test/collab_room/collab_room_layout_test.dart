import 'dart:ui' show Color;

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show DmMessage;
import 'package:openvine/collab_room/collab_room_layout.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

CollabRoom _room({
  String? layout,
  String aspectRatio = 'vertical',
  double? gap,
  int? borderColor,
  CollabRoomArrangement arrangement = CollabRoomArrangement.sideBySide,
  Duration? partLength,
  int? samCell = 1,
}) => foldCollabRooms([
  DmMessage(
    id: '1' * 64,
    conversationId: DmRepository.computeConversationId([_author, _sam]),
    senderPubkey: _author,
    content: 'text',
    createdAt: 1,
    giftWrapId: '2' * 64,
    tags: collabRoomTags(
      roomId: '0' * 32,
      type: CollabRoomMessageType.invite,
      recipientPubkey: _sam,
      snapshot: CollabRoomSnapshot(
        revision: 0,
        phase: CollabRoomPhase.recording,
        layout: layout,
        aspectRatio: aspectRatio,
        gap: gap,
        borderColor: borderColor,
        arrangement: arrangement,
        partLength: partLength,
        members: [
          const CollabRoomMember(
            pubkey: _author,
            status: CollabRoomMemberStatus.joined,
            cell: 0,
          ),
          CollabRoomMember(
            pubkey: _sam,
            status: CollabRoomMemberStatus.joined,
            cell: samCell,
          ),
        ],
      ),
    ),
  ),
], ownerPubkey: _author).single;

void main() {
  group('collabRoomLayoutsFor', () {
    test('lists the layouts with one cell per person', () {
      for (final count in [2, 3, 4]) {
        final layouts = collabRoomLayoutsFor(count);
        expect(layouts, isNotEmpty);
        expect(layouts.every((l) => l.cellCount == count), isTrue);
      }
      expect(collabRoomLayoutsFor(1), isEmpty);
    });
  });

  group('collabRoomMaxPartLength', () {
    test('shares the post length between everyone, in whole steps', () {
      expect(
        collabRoomMaxPartLength(2),
        const Duration(milliseconds: 3100),
      );
      expect(
        collabRoomMaxPartLength(3),
        const Duration(milliseconds: 2100),
      );
      expect(
        collabRoomMaxPartLength(4),
        const Duration(milliseconds: 1500),
      );
      for (final count in [2, 3, 4]) {
        expect(
          collabRoomMaxPartLength(count) * count,
          lessThanOrEqualTo(VideoEditorConstants.maxDuration),
        );
      }
    });

    test('counts a room nobody joined yet as two people', () {
      expect(collabRoomMaxPartLength(1), collabRoomMaxPartLength(2));
    });
  });

  group('collabRoomPartLengthFor', () {
    test('starts at the default length', () {
      expect(collabRoomPartLengthFor(null, 2), collabRoomDefaultPartLength);
    });

    test('shortens the default to what fits more people', () {
      expect(
        collabRoomPartLengthFor(null, 3),
        const Duration(milliseconds: 2100),
      );
    });

    test('keeps a pick within the shortest and longest part', () {
      expect(
        collabRoomPartLengthFor(const Duration(milliseconds: 200), 2),
        collabRoomMinPartLength,
      );
      expect(
        collabRoomPartLengthFor(const Duration(seconds: 5), 2),
        const Duration(milliseconds: 3100),
      );
      expect(
        collabRoomPartLengthFor(const Duration(milliseconds: 1800), 4),
        const Duration(milliseconds: 1500),
      );
    });
  });

  group('CollabRoomLayout', () {
    test('gives each person the shape of their cell', () {
      final room = _room(layout: 'sideBySide');
      expect(room.layoutPreset, SplitScreenLayoutPreset.sideBySide);
      expect(room.frameAspectRatio, model.AspectRatio.vertical);
      expect(room.cellRects, hasLength(2));
      expect(room.cellOf(_sam), 1);
      // Half of a 9:16 frame, less the gaps, is about 9:32.
      expect(room.cellAspectRatioOf(_sam), closeTo(9 / 32, 0.02));
    });

    test('reads a square frame', () {
      final room = _room(layout: 'stacked', aspectRatio: 'square');
      expect(room.frameAspectRatio, model.AspectRatio.square);
      expect(room.cellAspectRatioOf(_author), closeTo(2, 0.1));
    });

    test('gives the person in a round window a round cell', () {
      final room = _room(layout: 'circleBottomRight');
      expect(room.cellShapes, hasLength(2));
      expect(room.cellShapeOf(_sam), SplitScreenCellShape.oval);
      // A circle's square, whatever the frame's shape.
      expect(room.cellAspectRatioOf(_sam), closeTo(1, 1e-9));
      expect(room.cellShapeOf(_author)!.isRectangle, isFalse);
    });

    test('spaces the cells by the default gap until the host sets one', () {
      final room = _room(layout: 'sideBySide');
      expect(room.cellGap, collabRoomCellGap);
      expect(
        room.cellRects,
        SplitScreenLayoutPreset.sideBySide.cellRects(
          aspectRatio: 9 / 16,
          gap: collabRoomCellGap,
        ),
      );
    });

    test("spaces the cells by the host's gap", () {
      final room = _room(layout: 'sideBySide', gap: 0.05);
      expect(room.cellGap, 0.05);
      expect(
        room.cellRects,
        SplitScreenLayoutPreset.sideBySide.cellRects(
          aspectRatio: 9 / 16,
          gap: 0.05,
        ),
      );
      // A wider gap leaves each cell narrower.
      expect(
        room.cellAspectRatioOf(_sam),
        lessThan(_room(layout: 'sideBySide').cellAspectRatioOf(_sam)!),
      );
    });

    test("fills the gaps in the host's colour, or the default", () {
      expect(_room().borderColor, collabRoomBorderColor);
      expect(
        _room(borderColor: 0x27C58B).borderColor,
        const Color(0xFF27C58B),
      );
    });

    test('keeps a gap within what a layout draws', () {
      expect(
        _room(layout: 'sideBySide', gap: 0.5).cellGap,
        SplitScreenLayoutGeometry.maxGap,
      );
    });

    test('gives everyone the whole frame in series', () {
      final room = _room(
        layout: 'circleBottomRight',
        arrangement: CollabRoomArrangement.series,
      );
      expect(room.inSeries, isTrue);
      expect(room.cellShapeOf(_sam), SplitScreenCellShape.rectangle);
      expect(room.cellAspectRatioOf(_sam), 9 / 16);
      expect(room.cellAspectRatioOf(_author), 9 / 16);
    });

    test('plays each part for the length the host picked', () {
      expect(
        _room(partLength: const Duration(seconds: 2)).partLength,
        const Duration(seconds: 2),
      );
      expect(_room().partLength, collabRoomDefaultPartLength);
    });

    test('knows whether everyone has a cell of the layout', () {
      expect(_room(layout: 'sideBySide').seatsFitLayout, isTrue);
      expect(
        _room(layout: 'sideBySide', samCell: null).seatsFitLayout,
        isFalse,
      );
      expect(_room(layout: 'sideBySide', samCell: 0).seatsFitLayout, isFalse);
      expect(_room().seatsFitLayout, isFalse);
    });

    test('gives no cell before a layout is picked', () {
      final room = _room();
      expect(room.layoutPreset, isNull);
      expect(room.cellRects, isEmpty);
      expect(room.cellShapes, isEmpty);
      expect(room.cellAspectRatioOf(_sam), isNull);
      expect(room.cellShapeOf(_sam), isNull);
    });
  });
}
