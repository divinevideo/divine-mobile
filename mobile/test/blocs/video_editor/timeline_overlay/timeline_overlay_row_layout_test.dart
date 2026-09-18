// ABOUTME: Tests for TimelineOverlayRowLayout.
// ABOUTME: Pins the row-packing rules the overlay strips rely on.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_row_layout.dart';
import 'package:openvine/models/timeline_overlay_item.dart';

TimelineOverlayItem _item(
  String id, {
  required int startMs,
  required int endMs,
  int row = 0,
  TimelineOverlayType type = TimelineOverlayType.layer,
}) {
  return TimelineOverlayItem(
    id: id,
    type: type,
    startTime: Duration(milliseconds: startMs),
    endTime: Duration(milliseconds: endMs),
    row: row,
    label: id,
  );
}

Map<String, int> _rows(List<TimelineOverlayItem> items) => {
  for (final item in items) item.id: item.row,
};

void main() {
  group(TimelineOverlayRowLayout, () {
    group('assignRows', () {
      test('packs non-overlapping items onto one row', () {
        final result = TimelineOverlayRowLayout.assignRows([
          _item('a', startMs: 0, endMs: 1000),
          _item('b', startMs: 1000, endMs: 2000),
          _item('c', startMs: 2000, endMs: 3000),
        ]);

        expect(_rows(result), {'a': 0, 'b': 0, 'c': 0});
      });

      test('places an overlapping item below every earlier overlap', () {
        final result = TimelineOverlayRowLayout.assignRows([
          _item('a', startMs: 0, endMs: 2000),
          _item('b', startMs: 1000, endMs: 3000),
          _item('c', startMs: 1500, endMs: 2500),
          _item('d', startMs: 3000, endMs: 4000),
        ]);

        expect(_rows(result), {'a': 0, 'b': 1, 'c': 2, 'd': 0});
      });

      test('ignores the incoming row and preserves list order', () {
        final result = TimelineOverlayRowLayout.assignRows([
          _item('a', startMs: 0, endMs: 1000, row: 4),
          _item('b', startMs: 500, endMs: 1500),
        ]);

        expect(result.map((i) => i.id), ['a', 'b']);
        expect(_rows(result), {'a': 0, 'b': 1});
      });
    });

    group('compactRows', () {
      test('collapses an empty row left behind by a removed item', () {
        final result = TimelineOverlayRowLayout.compactRows([
          _item('a', startMs: 0, endMs: 1000),
          _item('b', startMs: 500, endMs: 1500, row: 2),
        ]);

        expect(_rows(result), {'a': 0, 'b': 1});
      });

      test('shifts an item up by at most one row per pass', () {
        final result = TimelineOverlayRowLayout.compactRows([
          _item('a', startMs: 0, endMs: 1000),
          _item('b', startMs: 0, endMs: 1000, row: 1),
          _item('c', startMs: 2000, endMs: 3000, row: 3),
        ]);

        // Row 2 is empty and collapses (c: 3 -> 2); c then moves up one more
        // row because nothing on row 1 overlaps it — but no further.
        expect(_rows(result), {'a': 0, 'b': 1, 'c': 1});
      });

      test('pushes a later same-row overlap down instead of stacking', () {
        final result = TimelineOverlayRowLayout.compactRows([
          _item('a', startMs: 0, endMs: 2000),
          _item('b', startMs: 1000, endMs: 3000),
        ]);

        expect(_rows(result), {'a': 0, 'b': 1});
      });
    });

    group('recalculateRows', () {
      test('compacts each strip type independently', () {
        final result = TimelineOverlayRowLayout.recalculateRows([
          _item('layer', startMs: 0, endMs: 1000, row: 2),
          _item(
            'sound',
            startMs: 0,
            endMs: 1000,
            row: 3,
            type: TimelineOverlayType.sound,
          ),
        ]);

        expect(_rows(result), {'layer': 0, 'sound': 0});
      });
    });

    group('shiftRowsDown', () {
      test('moves only the same-type items at or below the row', () {
        final result = TimelineOverlayRowLayout.shiftRowsDown(
          [
            _item('moved', startMs: 0, endMs: 1000, row: 1),
            _item('below', startMs: 0, endMs: 1000, row: 1),
            _item('deeper', startMs: 0, endMs: 1000, row: 2),
            _item('above', startMs: 0, endMs: 1000),
            _item(
              'other',
              startMs: 0,
              endMs: 1000,
              row: 1,
              type: TimelineOverlayType.sound,
            ),
          ],
          TimelineOverlayType.layer,
          1,
          'moved',
        );

        expect(_rows(result), {
          'moved': 1,
          'below': 2,
          'deeper': 3,
          'above': 0,
          'other': 1,
        });
      });
    });
  });
}
