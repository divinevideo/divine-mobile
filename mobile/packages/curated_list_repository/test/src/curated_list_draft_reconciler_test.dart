// ABOUTME: Regression coverage for durable explicit list edits and replay.
// ABOUTME: Protects remote data, metadata and permission changes.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  final a = 'a' * 64;
  final b = 'b' * 64;
  final c = 'c' * 64;
  final base = CuratedList(
    id: 'offline-edits',
    name: 'Original',
    pubkey: 'd' * 64,
    videoEventIds: [a, b],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  CuratedListEditDraft stage(CuratedList desired) =>
      CuratedListDraftReconciler.stage(base, desired);
  CuratedList? replay(CuratedList desired, CuratedList remote) =>
      CuratedListDraftReconciler.reconcile(stage(desired), remote);

  group('explicit list draft reconciliation', () {
    test('only deliberate membership removals apply to the fresh list', () {
      final merged = replay(
        base.copyWith(videoEventIds: [b]),
        base.copyWith(videoEventIds: [a, b, c]),
      );
      expect(merged!.videoEventIds, [b, c]);
    });
    test('an unchanged local member never resurrects a remote deletion', () {
      final merged = replay(
        base.copyWith(name: 'Renamed'),
        base.copyWith(videoEventIds: [a, c]),
      );
      expect(merged!.videoEventIds, [a, c]);
      expect(merged.name, 'Renamed');
    });
    test('manual reorder preserves an unseen remote member', () {
      final merged = replay(
        base.copyWith(videoEventIds: [b, a], playOrder: PlayOrder.manual),
        base.copyWith(videoEventIds: [a, c, b]),
      );
      expect(merged!.videoEventIds, [b, a, c]);
      expect(merged.playOrder, PlayOrder.manual);
    });
    test(
      'a newly added member can be reordered ahead of the original members',
      () {
        final added = base.copyWith(videoEventIds: [a, b, c]);
        final visible = added.copyWith(localEditDraft: stage(added));
        final reordered = CuratedListDraftReconciler.stage(
          visible,
          visible.copyWith(
            videoEventIds: [c, a, b],
            playOrder: PlayOrder.manual,
          ),
        );
        final fresh = base.copyWith(videoEventIds: [a, b, 'e' * 64]);
        expect(
          CuratedListDraftReconciler.reconcile(reordered, fresh)!.videoEventIds,
          [c, a, b, 'e' * 64],
        );
      },
    );
    test('competing metadata changes require an explicit owner choice', () {
      expect(
        replay(base.copyWith(name: 'Local'), base.copyWith(name: 'Remote')),
        isNull,
      );
    });
    test('competing manual orders remain a conflict', () {
      final baseline = base.copyWith(videoEventIds: [a, b, c]);
      final draft = CuratedListDraftReconciler.stage(
        baseline,
        baseline.copyWith(videoEventIds: [b, a, c]),
      );
      expect(
        CuratedListDraftReconciler.reconcile(
          draft,
          baseline.copyWith(videoEventIds: [a, c, b]),
        ),
        isNull,
      );
    });
    test(
      'collaborator deltas preserve a newly granted remote collaborator',
      () {
        final baseline = base.copyWith(
          isCollaborative: true,
          allowedCollaborators: [a],
        );
        final draft = CuratedListDraftReconciler.stage(
          baseline,
          baseline.copyWith(allowedCollaborators: [c]),
        );
        final merged = CuratedListDraftReconciler.reconcile(
          draft,
          baseline.copyWith(allowedCollaborators: [a, b]),
        );
        expect(merged!.allowedCollaborators, [b, c]);
        expect(merged.isCollaborative, isTrue);
      },
    );
    test(
      'a privacy proposal cannot revoke concurrently changed permissions',
      () {
        final baseline = base.copyWith(
          isCollaborative: true,
          allowedCollaborators: [a],
        );
        final draft = CuratedListDraftReconciler.stage(
          baseline,
          baseline.copyWith(
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: [],
          ),
        );
        expect(
          CuratedListDraftReconciler.reconcile(
            draft,
            baseline.copyWith(allowedCollaborators: [a, b]),
          ),
          isNull,
        );
      },
    );
    test('metadata edits follow newly private remote visibility', () {
      final merged = replay(
        base.copyWith(name: 'Renamed'),
        base.copyWith(isPublic: false),
      );
      expect(merged!.isPublic, isFalse);
      expect(merged.name, 'Renamed');
    });
    test(
      'extending a draft preserves its original baseline and permission intent',
      () {
        final desired = base.copyWith(isPublic: false);
        final draft = stage(desired);
        final visible = base.copyWith(localEditDraft: draft);
        final extended = CuratedListDraftReconciler.stage(
          visible,
          visible.copyWith(name: 'Renamed'),
        );
        expect(extended.baseline, base);
        expect(extended.desired.isPublic, isFalse);
        expect(extended.desired.name, 'Renamed');
        final row = visible.copyWith(localEditDraft: extended);
        final restored = CuratedList.fromJson(
          jsonDecode(jsonEncode(row.toJson())) as Map<String, dynamic>,
        );
        expect(restored.localEditDraft, extended);
        expect(restored.needsSync, isTrue);
      },
    );
    test('tag edits preserve unseen remote tags', () {
      final baseline = base.copyWith(tags: ['old']);
      final draft = CuratedListDraftReconciler.stage(
        baseline,
        baseline.copyWith(tags: ['new']),
      );
      expect(
        CuratedListDraftReconciler.reconcile(
          draft,
          baseline.copyWith(tags: ['old', 'remote']),
        )!.tags,
        ['remote', 'new'],
      );
    });
    test('an invalid private collaborative target is never produced', () {
      expect(
        replay(
          base.copyWith(name: 'Edited'),
          base.copyWith(isPublic: false, isCollaborative: true),
        ),
        isNull,
      );
    });
    test('local collaborator intent cannot reopen a remotely private list', () {
      expect(
        replay(
          base.copyWith(isCollaborative: true, allowedCollaborators: [a]),
          base.copyWith(isPublic: false),
        ),
        isNull,
      );
    });
    test('private draft intent stays held when relay visibility expands', () {
      final baseline = base.copyWith(isPublic: false);
      final draft = CuratedListDraftReconciler.stage(
        baseline,
        baseline.copyWith(videoEventIds: [a, b, c]),
      );
      expect(
        CuratedListDraftReconciler.reconcile(
          draft,
          baseline.copyWith(isPublic: true, videoEventIds: [a, b, 'e' * 64]),
        ),
        isNull,
      );
    });
    test(
      'wire fallbacks allow explicit offline description edits',
      () {
        final draft = CuratedListDraftReconciler.stage(
          base,
          base.copyWith(description: 'Owner description'),
        );
        final remote = base.copyWith(
          description: 'Curated video list: Original',
        );
        expect(
          CuratedListDraftReconciler.reconcile(draft, remote)!.description,
          'Owner description',
        );
      },
    );
    test(
      'legacy copies without an original delta require explicit recovery',
      () {
        final draft = CuratedListEditDraft(
          baseline: base,
          desired: base.copyWith(name: 'Legacy copy'),
          canReplay: false,
        );
        expect(CuratedListDraftReconciler.reconcile(draft, base), isNull);
        final visible = base.copyWith(localEditDraft: draft);
        expect(
          CuratedListDraftReconciler.stage(
            visible,
            visible.copyWith(description: 'More intent'),
          ).canReplay,
          isFalse,
        );
        final restored = CuratedList.fromJson(visible.toJson());
        expect(restored.localEditDraft!.canReplay, isFalse);
      },
    );
    test('a draft never moves to a different owner coordinate', () {
      expect(
        replay(base.copyWith(name: 'Renamed'), base.copyWith(pubkey: 'e' * 64)),
        isNull,
      );
    });
  });
}
