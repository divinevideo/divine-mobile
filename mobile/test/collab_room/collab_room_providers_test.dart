// ABOUTME: Tests for the camera flow's part context: finishing keeps the
// ABOUTME: cell for the screens animating out, and only an active part calls

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/collab_room/call/collab_room_call_providers.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';

const _me = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _callKey =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  group(CollabRoomPartNotifier, () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('keeps the cell of a finished part, only no longer active', () {
      container
          .read(collabRoomPartProvider.notifier)
          .set(
            const CollabRoomPartContext(
              roomId: 'room',
              cellAspectRatio: 1,
              cellShape: SplitScreenCellShape.oval,
              me: _me,
              callKey: _callKey,
            ),
          );
      expect(container.read(collabRoomPartProvider)!.isActive, isTrue);

      container.read(collabRoomPartProvider.notifier).finish();

      final part = container.read(collabRoomPartProvider)!;
      expect(part.isActive, isFalse);
      expect(part.roomId, 'room');
      expect(part.cellShape, SplitScreenCellShape.oval);
      expect(part.callKey, _callKey);
    });
  });

  group('collabRoomPartCallId', () {
    const part = CollabRoomPartContext(
      roomId: 'room',
      cellAspectRatio: 1,
      me: _me,
      callKey: _callKey,
    );

    test('names the call of the part being filmed', () {
      expect(collabRoomPartCallId(part), (
        roomId: 'room',
        callKey: _callKey,
        me: _me,
      ));
    });

    test('names none for a finished part or a room without a call', () {
      const finished = CollabRoomPartContext(
        roomId: 'room',
        cellAspectRatio: 1,
        me: _me,
        callKey: _callKey,
        finished: true,
      );
      const noCall = CollabRoomPartContext(
        roomId: 'room',
        cellAspectRatio: 1,
        me: _me,
      );

      expect(collabRoomPartCallId(finished), isNull);
      expect(collabRoomPartCallId(noCall), isNull);
      expect(collabRoomPartCallId(null), isNull);
    });
  });
}
