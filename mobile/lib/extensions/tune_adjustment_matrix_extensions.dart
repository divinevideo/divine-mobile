// ABOUTME: Shared helpers for grouping tune adjustments into timeline "sets".
// ABOUTME: One Adjust session -> one set (a group sharing a time window).

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:uuid/uuid.dart';

/// Set-oriented reads over a single [TuneAdjustmentMatrix].
extension TuneAdjustmentMatrixTuneSet on TuneAdjustmentMatrix {
  /// The timeline set this adjustment belongs to.
  ///
  /// Falls back to the adjustment's own [id] for legacy matrices written
  /// before sets existed.
  String get tuneSetId =>
      meta[VideoEditorConstants.tuneSetIdMetaKey] as String? ?? id;

  /// The adjustment kind (`brightness`, `contrast`, …) recorded on the matrix.
  ///
  /// Falls back to the adjustment's own [id].
  String get tuneKind =>
      meta[VideoEditorConstants.tuneKindMetaKey] as String? ?? id;
}

/// Helpers for building and identifying tune-adjustment *sets* — the group of
/// adjustments one Adjust session produces, rendered as a single timeline bar
/// sharing one time window.
abstract class TuneSet {
  /// A fresh, unique timeline-set id.
  ///
  /// Random rather than clock-based: two calls in one microsecond would share
  /// a timestamp.
  static String newId() => 'set_${const Uuid().v4()}';

  /// The unique per-instance id for a member of set [setId] of the given
  /// [kind]. Members need unique ids so multiple sets — or multiple segments
  /// of the same kind — can coexist in the editor's flat adjustment list.
  static String memberId({required String kind, required String setId}) =>
      '${kind}__$setId';

  /// The non-neutral members of [adjustments], by set, in the order the sets
  /// first appear.
  ///
  /// A member with value 0 is left out, and so is a set with no other
  /// member. Every member of a set shares one time window, so a set's first
  /// member stands for it.
  static Map<String, List<TuneAdjustmentMatrix>> groupBySet(
    Iterable<TuneAdjustmentMatrix> adjustments,
  ) {
    final sets = <String, List<TuneAdjustmentMatrix>>{};
    for (final adjustment in adjustments) {
      if (adjustment.value == 0) continue;
      (sets[adjustment.tuneSetId] ??= []).add(adjustment);
    }
    return sets;
  }

  /// The `meta` map that records a member's [setId] and adjustment [kind].
  static Map<String, dynamic> metaFor({
    required String setId,
    required String kind,
  }) => {
    VideoEditorConstants.tuneSetIdMetaKey: setId,
    VideoEditorConstants.tuneKindMetaKey: kind,
  };

  /// Kind-keyed seed matrices for the tune bloc's bottom-bar sliders when
  /// editing the set [setId].
  ///
  /// Set members carry unique per-instance ids, but the bottom bar reads
  /// values by preset kind — so each member is re-keyed to its [tuneKind].
  /// Returns an empty list for a new session ([setId] `null`) or when the set
  /// has no members.
  static List<TuneAdjustmentMatrix> sessionSeed(
    List<TuneAdjustmentMatrix> active,
    String? setId,
  ) {
    if (setId == null) return const [];
    return [
      for (final m in active)
        if (m.tuneSetId == setId)
          TuneAdjustmentMatrix(
            id: m.tuneKind,
            value: m.value,
            matrix: const [],
          ),
    ];
  }
}
