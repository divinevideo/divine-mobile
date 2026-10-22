// ABOUTME: Pins minimal recovery serialization and accepted-only authorization.
// ABOUTME: Keeps source permission mutations separate from captured evidence.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_record.dart';

void main() {
  group('CuratedListRecoveryRecord', () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const publicEvent =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const acceptedEvent =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const collaborator =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const privateVideo =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    test(
      'round trips a captured permission snapshot without private payload',
      () {
        final collaborators = [collaborator];
        final now = DateTime.utc(2026, 10, 5);
        final source = CuratedList(
          id: 'private-list',
          name: 'Private title',
          description: 'Private description',
          pubkey: owner,
          videoEventIds: const [privateVideo],
          createdAt: now,
          updatedAt: now,
          isPublic: false,
          isCollaborative: true,
          allowedCollaborators: collaborators,
        );
        final target = CuratedListVisibility.fromList(
          source,
          relayAccepted: true,
        );
        collaborators.clear();
        expect(target.allowedCollaborators, [collaborator]);
        expect(
          target.allowedCollaborators.clear,
          throwsUnsupportedError,
        );
        final record = CuratedListRecoveryRecord(
          plaintextEventIds: const [publicEvent],
          visibility: target,
          acceptedEventId: acceptedEvent,
          acceptedAt: now,
          requiresPrivateCommit: true,
          permissionEpoch: 3,
        );
        final encoded = jsonEncode(record.toJson());
        final decoded = CuratedListRecoveryRecord.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
        expect(decoded.visibility, target);
        expect(decoded.plaintextEventIds, [publicEvent]);
        expect(decoded.acceptedEventId, acceptedEvent);
        expect(decoded.acceptedAt, now);
        expect(decoded.requiresPrivateCommit, isTrue);
        expect(decoded.permissionEpoch, 3);
        expect(decoded.permissionsRetired, isFalse);
        expect(decoded.toJson(), record.toJson());
        expect(encoded, isNot(contains(source.name)));
        expect(encoded, isNot(contains(source.description)));
        expect(encoded, isNot(contains(source.videoEventIds.single)));
        expect(encoded, isNot(contains(owner)));
      },
    );

    test('unconfirmed legacy target cannot authorize permission recovery', () {
      final ids = [publicEvent];
      final encoded = <String, dynamic>{
        'plaintextEventIds': ids,
        'visibility': {
          'isPublic': true,
          'isCollaborative': true,
          'allowedCollaborators': [collaborator],
        },
      };
      final recovered = CuratedListRecoveryRecord.fromJson(encoded);
      ids.clear();
      expect(recovered.visibility, isNull);
      expect(recovered.plaintextEventIds, [publicEvent]);
      expect(recovered.toJson().containsKey('visibility'), isFalse);
      expect(recovered.permissionEpoch, 0);
    });

    test('retired empty coordinate keeps its lifetime tombstone', () {
      const retired = CuratedListRecoveryRecord(
        permissionEpoch: 4,
        permissionsRetired: true,
      );
      final restored = CuratedListRecoveryRecord.fromJson(retired.toJson());
      expect(restored.isEmpty, isFalse);
      expect(restored.permissionsRetired, isTrue);
      expect(restored.permissionEpoch, 4);
      expect(restored.visibility, isNull);
      expect(restored.plaintextEventIds, isEmpty);
    });
  });
}
