// ABOUTME: Replays explicit local edits against a fresh curated-list revision.
// ABOUTME: Preserves remote members and retains ambiguous edits as conflicts.

import 'package:collection/collection.dart';
import 'package:models/models.dart';

/// Pure three-way reconciliation; null means the owner must resolve a conflict.
abstract final class CuratedListDraftReconciler {
  static const _equal = DeepCollectionEquality();

  /// Payload fields edited by list APIs, excluding delivery and cache metadata.
  static const _fields = [
    'name',
    'description',
    'imageUrl',
    'videoEventIds',
    'isPublic',
    'tags',
    'isCollaborative',
    'allowedCollaborators',
    'thumbnailEventId',
    'playOrder',
  ];

  /// Extends existing intent with only changes made by the latest operation.
  static CuratedListEditDraft stage(CuratedList previous, CuratedList updated) {
    final draft = previous.localEditDraft;
    final value = (draft?.desired ?? previous).toJson()
      ..['pubkey'] = updated.pubkey;
    final before = previous.toJson();
    final after = updated.toJson();
    for (final field in _fields) {
      if (!_equal.equals(before[field], after[field])) {
        value[field] = after[field];
      }
    }
    return CuratedListEditDraft(
      baseline: draft?.baseline ?? previous.copyWith(pubkey: updated.pubkey),
      desired: CuratedList.fromJson(value..remove('localEditDraft')),
      canReplay: draft?.canReplay ?? true,
    );
  }

  static Map<String, dynamic> _publicationValue(CuratedList list) {
    final value = list.toJson();
    if (list.isPublic &&
        list.description == 'Curated video list: ${list.name}') {
      value['description'] = null;
    }
    return value;
  }

  /// Returns the fresh revision plus only proven local deltas.
  static CuratedList? reconcile(
    CuratedListEditDraft draft,
    CuratedList remote,
  ) {
    if (!draft.canReplay) return null;
    final baseline = draft.baseline;
    final desired = draft.desired;
    if (baseline.authorScopedId != remote.authorScopedId ||
        desired.authorScopedId != remote.authorScopedId) {
      return null;
    }
    // A private draft never inherits a visibility expansion from another copy.
    if (!desired.isPublic && remote.isPublic && !baseline.isPublic) return null;
    final before = _publicationValue(baseline);
    final after = _publicationValue(desired);
    // An unchanged fallback remains implicit when the owner changes the name.
    if (baseline.description == desired.description &&
        before['description'] == null) {
      after['description'] = null;
    }
    final result = _publicationValue(remote);
    final localPermissionsChanged =
        CuratedListVisibility.fromList(baseline) !=
        CuratedListVisibility.fromList(desired);
    // Privacy flips change the meaning of every member and collaborator. Never
    // infer consent to publish or revoke a concurrently changed permission set.
    if (localPermissionsChanged &&
        (remote.isPublic != baseline.isPublic ||
            (desired.isPublic != baseline.isPublic &&
                CuratedListVisibility.fromList(remote) !=
                    CuratedListVisibility.fromList(baseline))) &&
        CuratedListVisibility.fromList(remote) !=
            CuratedListVisibility.fromList(desired)) {
      return null;
    }

    for (final field in _fields) {
      if (_equal.equals(before[field], after[field])) continue;
      if (field == 'videoEventIds' ||
          field == 'allowedCollaborators' ||
          field == 'tags') {
        final oldValues = List<String>.from(before[field] as List);
        final wanted = List<String>.from(after[field] as List);
        final fresh = List<String>.from(result[field] as List);
        final merged = <String>{...fresh}
          ..removeAll(oldValues.where((value) => !wanted.contains(value)))
          ..addAll(wanted.where((value) => !oldValues.contains(value)));
        if (field == 'videoEventIds') {
          final shared = oldValues.where(wanted.contains).toSet();
          final oldOrder = oldValues.where(shared.contains).toList();
          final localOrder = wanted.where(shared.contains).toList();
          final liveShared = shared.intersection(fresh.toSet());
          final remoteOrder = fresh.where(liveShared.contains).toList();
          final originalRemoteOrder = oldValues
              .where(liveShared.contains)
              .toList();
          final desiredRemoteOrder = wanted.where(liveShared.contains).toList();
          final insertionOrder = [
            ...oldValues.where(wanted.contains),
            ...wanted.where((value) => !oldValues.contains(value)),
          ];
          final reordered =
              !_equal.equals(oldOrder, localOrder) ||
              !_equal.equals(wanted, insertionOrder);
          if (reordered &&
              !_equal.equals(remoteOrder, originalRemoteOrder) &&
              !_equal.equals(remoteOrder, desiredRemoteOrder)) {
            return null;
          }
          result[field] = reordered
              ? [
                  ...wanted.where(merged.contains),
                  ...fresh.where(
                    (value) =>
                        merged.contains(value) && !wanted.contains(value),
                  ),
                ]
              : merged.toList();
        } else {
          result[field] = merged.toList();
        }
      } else {
        if (!_equal.equals(result[field], before[field]) &&
            !_equal.equals(result[field], after[field])) {
          return null;
        }
        result[field] = after[field];
      }
    }
    if (!_equal.equals(
          before['allowedCollaborators'],
          after['allowedCollaborators'],
        ) &&
        desired.isCollaborative == desired.allowedCollaborators.isNotEmpty &&
        result['isPublic'] == true) {
      result['isCollaborative'] =
          (result['allowedCollaborators'] as List).isNotEmpty;
    }
    if (result['isPublic'] == false && result['isCollaborative'] == true) {
      return null;
    }
    result.remove('localEditDraft');
    return CuratedList.fromJson(result).copyWith(
      pendingRepublish: true,
      localEditDraft: CuratedListEditDraft(
        baseline: remote,
        desired: CuratedList.fromJson(result),
      ),
    );
  }
}
