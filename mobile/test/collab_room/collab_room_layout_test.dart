import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show DmMessage;
import 'package:openvine/collab_room/collab_room_layout.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

CollabRoom _room({String? layout, String aspectRatio = 'vertical'}) =>
    foldCollabRooms([
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
            members: const [
              CollabRoomMember(
                pubkey: _author,
                status: CollabRoomMemberStatus.joined,
                cell: 0,
              ),
              CollabRoomMember(
                pubkey: _sam,
                status: CollabRoomMemberStatus.joined,
                cell: 1,
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
