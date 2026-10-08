// ABOUTME: Preserves later recovery values during shared-card snapshot selection.
// ABOUTME: Keeps pending privacy and deletion arrays independent of mutable inputs.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/curated_lists_snapshot.dart';

void main() {
  group('CuratedListsSnapshot recovery state', () {
    test('full composed recovery state freezes and roundtrips', () {
      const owner =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const event =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final collaborators = [owner];
      final pendingIds = [event];
      final original = CuratedList(
        id: 'recovery-shape',
        pubkey: owner,
        name: 'Recovery shape',
        videoEventIds: const [event],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        pendingVisibility: CuratedListVisibility(
          isPublic: false,
          isCollaborative: true,
          allowedCollaborators: collaborators,
          relayAccepted: true,
        ),
        pendingPlaintextEventIds: pendingIds,
      );
      final snapshot = CuratedListsSnapshot([original]);
      final unchanged = CuratedListsSnapshot([snapshot.lists.single]);
      final before = snapshot.lists.single;
      expect(before.props, original.props);
      expect(before.toJson(), original.toJson());
      final hash = snapshot.hashCode;
      collaborators.clear();
      pendingIds.clear();
      expect(snapshot, unchanged);
      expect(snapshot.hashCode, hash);
      expect(snapshot, isNot(CuratedListsSnapshot([original])));
      final restored = snapshot.lists.single;
      expect(restored.pendingVisibility?.allowedCollaborators, [owner]);
      expect(restored.pendingVisibility?.relayAccepted, isTrue);
      expect(restored.pendingPlaintextEventIds, [event]);
    });
  });
}
