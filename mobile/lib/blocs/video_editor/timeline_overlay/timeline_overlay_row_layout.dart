// ABOUTME: Row packing for timeline overlay items: assigns, compacts and
// ABOUTME: shifts the vertical rows so items of one strip never overlap.

import 'package:openvine/models/timeline_overlay_item.dart';

/// Pure row-packing rules for [TimelineOverlayItem]s.
///
/// Every strip (sounds, filters, tunes, layers, captions) lays its items out
/// on numbered rows. Two items may share a row only when their time windows
/// do not overlap. These functions decide the row numbers; the bloc owns
/// *when* they run.
abstract final class TimelineOverlayRowLayout {
  /// Packs [items] into the fewest rows while preserving list order.
  ///
  /// An item's row must be strictly greater than the row of any temporally
  /// overlapping item that was placed before it. This prevents items from
  /// visually "jumping over" earlier items. Non-overlapping items can share a
  /// row.
  static List<TimelineOverlayItem> assignRows(List<TimelineOverlayItem> items) {
    if (items.isEmpty) return items;

    final result = <TimelineOverlayItem>[];

    for (final item in items) {
      var row = 0;
      for (final placed in result) {
        if (_overlaps(item, placed) && placed.row >= row) {
          row = placed.row + 1;
        }
      }
      result.add(item.copyWith(row: row));
    }

    return result;
  }

  /// Gently compacts rows for items that already have row assignments.
  ///
  /// Groups items by [TimelineOverlayType] and compacts each type
  /// independently.
  static List<TimelineOverlayItem> recalculateRows(
    List<TimelineOverlayItem> items,
  ) {
    final grouped = <TimelineOverlayType, List<TimelineOverlayItem>>{};
    for (final item in items) {
      (grouped[item.type] ??= []).add(item);
    }
    return [for (final group in grouped.values) ..._compactRows(group)];
  }

  /// Compacts rows gradually.
  ///
  /// 0. Resolve same-row overlaps by pushing the later item down.
  /// 1. Completely empty rows are collapsed (items shift through).
  /// 2. Each item may then shift up by at most **one** row if
  ///    its target row has no temporal overlap.
  ///
  /// Items are processed from lowest to highest row so upstream
  /// moves can cascade within a single pass.
  static List<TimelineOverlayItem> _compactRows(
    List<TimelineOverlayItem> items,
  ) {
    if (items.isEmpty) return items;

    // Step 0: Resolve same-row overlaps.
    // Process items from lowest row upward. When two items on the
    // same row overlap, push the later-added one down.
    final resolved = List<TimelineOverlayItem>.from(items);
    for (var i = 0; i < resolved.length; i++) {
      for (var j = i + 1; j < resolved.length; j++) {
        final a = resolved[i];
        final b = resolved[j];
        if (a.row == b.row && _overlaps(a, b)) {
          resolved[j] = b.copyWith(row: b.row + 1);
        }
      }
    }

    // Step 1: Collapse completely empty rows.
    final usedRows = <int>{for (final item in resolved) item.row};
    final sortedUsed = usedRows.toList()..sort();
    final rowMap = {
      for (var i = 0; i < sortedUsed.length; i++) sortedUsed[i]: i,
    };
    final result = [
      for (final item in resolved) item.copyWith(row: rowMap[item.row]),
    ];

    // Step 2: Try to shift each item up by 1 row if no overlap.
    // Process from lowest row first so cascading works naturally.
    result.sort((a, b) => a.row.compareTo(b.row));
    for (var i = 0; i < result.length; i++) {
      final item = result[i];
      if (item.row <= 0) continue;

      final hasOverlap = result.any(
        (other) =>
            other.id != item.id &&
            other.row == item.row - 1 &&
            _overlaps(item, other),
      );
      if (!hasOverlap) {
        result[i] = item.copyWith(row: item.row - 1);
      }
    }

    return result;
  }

  /// Shifts all items of [type] with row >= [fromRow] down by one row,
  /// excluding the item with [excludeId].
  static List<TimelineOverlayItem> shiftRowsDown(
    List<TimelineOverlayItem> items,
    TimelineOverlayType type,
    int fromRow,
    String excludeId,
  ) {
    return items.map((i) {
      if (i.id != excludeId && i.type == type && i.row >= fromRow) {
        return i.copyWith(row: i.row + 1);
      }
      return i;
    }).toList();
  }

  static bool _overlaps(TimelineOverlayItem a, TimelineOverlayItem b) =>
      a.startTime < b.endTime && b.startTime < a.endTime;
}
