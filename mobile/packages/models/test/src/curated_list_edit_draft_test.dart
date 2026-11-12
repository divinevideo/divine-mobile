// ABOUTME: Pins durable list-edit snapshots and their account coordinate.
// ABOUTME: Rejects nested or mismatched drafts without dropping saved intent.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  CuratedList baseline() => CuratedList(
    id: 'draft',
    name: 'Original',
    pubkey: 'a' * 64,
    videoEventIds: ['b' * 64],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  group('durable curated list edit drafts', () {
    test('baseline and desired value survive a cache JSON round trip', () {
      final original = baseline();
      final draft = CuratedListEditDraft(
        baseline: original,
        desired: original.copyWith(name: 'Edited'),
      );
      final row = original.copyWith(
        localEditDraft: draft,
        hasRelayConflict: true,
      );
      final restored = CuratedList.fromJson(
        jsonDecode(jsonEncode(row.toJson())) as Map<String, dynamic>,
      );
      expect(restored.localEditDraft!.baseline, original);
      expect(restored.localEditDraft!.desired.name, 'Edited');
      expect(restored.hasRelayConflict, isTrue);
      expect(restored.needsSync, isTrue);
      expect(
        restored
            .copyWith(clearLocalEditDraft: true, hasRelayConflict: false)
            .needsSync,
        isFalse,
      );
    });

    test('snapshots cannot be changed through a caller-owned member list', () {
      final original = baseline();
      final draft = CuratedListEditDraft(
        baseline: original,
        desired: original.copyWith(name: 'Edited'),
      );
      original.videoEventIds.add('c' * 64);
      expect(draft.baseline.videoEventIds, ['b' * 64]);
      expect(
        () => draft.desired.videoEventIds.add('d' * 64),
        throwsUnsupportedError,
      );
    });

    test('nested saved drafts are rejected', () {
      final original = baseline();
      final draft = CuratedListEditDraft(baseline: original, desired: original);
      final json = draft.toJson();
      (json['baseline'] as Map<String, dynamic>)['localEditDraft'] = draft
          .toJson();
      expect(() => CuratedListEditDraft.fromJson(json), throwsFormatException);
    });

    test('a draft cannot transfer a coordinate between accounts', () {
      final original = baseline();
      expect(
        () => CuratedListEditDraft(
          baseline: original,
          desired: original.copyWith(pubkey: 'c' * 64),
        ),
        throwsFormatException,
      );
    });
  });
}
