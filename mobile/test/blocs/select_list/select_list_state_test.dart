// ABOUTME: Tests for SelectListState: which notice a list waiting to sync
// ABOUTME: shows on its row in the list picker.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/select_list/select_list_state.dart';

// Full-length 64-char ids — never truncate.
final String _ownerPubkey = 'f' * 64;
final String _deletedEventId = 'c' * 64;

CuratedList _list({bool holdsVideo = false}) => CuratedList(
  id: 'list',
  pubkey: _ownerPubkey,
  name: 'List',
  videoEventIds: holdsVideo ? ['a' * 64] : const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

SelectListState _state({
  required CuratedList list,
  required bool holdsVideo,
}) => SelectListState(
  lists: [list],
  memberListIds: holdsVideo ? {list.id} : const {},
  selectedListIds: holdsVideo ? {list.id} : const {},
);

void main() {
  group(SelectListState, () {
    group('syncNoticeFor', () {
      test('is null for a list with nothing to sync', () {
        final list = _list(holdsVideo: true);

        expect(
          _state(list: list, holdsVideo: true).syncNoticeFor(list),
          isNull,
        );
      });

      test('says the video waits for the relay while the list republishes '
          'with it', () {
        final list = _list(holdsVideo: true).copyWith(pendingRepublish: true);

        expect(
          _state(list: list, holdsVideo: true).syncNoticeFor(list),
          SelectListSyncNotice.videoPending,
        );
      });

      test('names an accepted permission change before the video', () {
        final list = _list(holdsVideo: true).copyWith(
          pendingRepublish: true,
          pendingVisibility: const CuratedListVisibility(
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: [],
            relayAccepted: true,
          ),
        );

        expect(
          _state(list: list, holdsVideo: true).syncNoticeFor(list),
          SelectListSyncNotice.permissionRecovery,
        );
      });

      test('says other changes wait when the republished list does not hold '
          'the video', () {
        final list = _list().copyWith(pendingRepublish: true);

        expect(
          _state(list: list, holdsVideo: false).syncNoticeFor(list),
          SelectListSyncNotice.recovery,
        );
      });

      test('says other changes wait for a deletion request alone', () {
        final list = _list(
          holdsVideo: true,
        ).copyWith(pendingPlaintextEventIds: [_deletedEventId]);

        expect(
          _state(list: list, holdsVideo: true).syncNoticeFor(list),
          SelectListSyncNotice.recovery,
        );
      });
    });
  });
}
