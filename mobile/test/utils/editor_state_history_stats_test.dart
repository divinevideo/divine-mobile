// ABOUTME: Pins the draft-history counts the draft load and save log lines
// ABOUTME: report: undo steps, kept layers and stored stroke points

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/editor_state_history_stats.dart';

Map<String, dynamic> _stroke(int points) => {
  'mode': 'freeStyle',
  'offsets': [
    for (var i = 0; i < points; i++) {'x': i, 'y': i},
  ],
};

/// A paint layer as the export writes it: every stroke in `items`, and the
/// first one repeated as `item`.
Map<String, dynamic> _paintLayer(String id, List<int> strokePoints) => {
  'id': id,
  'type': 'paint',
  'item': _stroke(strokePoints.first),
  'items': [for (final points in strokePoints) _stroke(points)],
};

void main() {
  group(EditorStateHistoryStats, () {
    group('of', () {
      test('counts steps, the shown step and layers deleted since', () {
        final stats = EditorStateHistoryStats.of({
          'position': 2,
          'references': {
            'drawing': _paintLayer('drawing', [3, 2]),
            'text': {'id': 'text', 'type': 'text'},
          },
          'history': [
            {
              'layers': [
                {'id': 'drawing'},
              ],
            },
            {
              'layers': [
                {'id': 'drawing', 'x': 1},
                {'id': 'text'},
              ],
            },
            {
              'layers': [
                {'id': 'text'},
              ],
            },
          ],
        });

        expect(stats.steps, equals(3));
        expect(stats.position, equals(2));
        expect(stats.currentLayers, equals(1));
        expect(stats.keptLayers, equals(2));
        expect(stats.paintPoints, equals(5));
      });

      test('counts strokes again in every step that rewrites them', () {
        final stats = EditorStateHistoryStats.of({
          'position': 1,
          'references': {
            'drawing': _paintLayer('drawing', [3]),
          },
          'history': [
            {
              'layers': [
                {'id': 'drawing'},
              ],
            },
            {
              'layers': [
                _paintLayer('drawing', [3, 4]),
              ],
            },
          ],
        });

        expect(stats.paintPoints, equals(3 + 7));
      });

      test('counts a lone legacy item when there is no items list', () {
        final stats = EditorStateHistoryStats.of({
          'position': 0,
          'history': [
            {
              'layers': [
                {'id': 'drawing', 'type': 'paint', 'item': _stroke(6)},
              ],
            },
          ],
        });

        expect(stats.paintPoints, equals(6));
        expect(stats.keptLayers, equals(1));
      });

      test('reports nothing for a draft without editor history', () {
        final stats = EditorStateHistoryStats.of(const {});

        expect(stats.steps, equals(0));
        expect(stats.position, isNull);
        expect(stats.currentLayers, equals(0));
        expect(stats.keptLayers, equals(0));
        expect(stats.paintPoints, equals(0));
      });
    });

    group('toString', () {
      test('reads as one log fragment', () {
        const stats = EditorStateHistoryStats(
          steps: 12,
          position: 11,
          currentLayers: 2,
          keptLayers: 5,
          paintPoints: 7504,
        );

        expect(
          stats.toString(),
          equals(
            'history 12 step(s) at 11, layers 2 current / 5 kept, '
            'paint points 7504',
          ),
        );
      });
    });
  });
}
