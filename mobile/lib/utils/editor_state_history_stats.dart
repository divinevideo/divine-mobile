// ABOUTME: Counts what a draft's persisted editor history holds, so draft
// ABOUTME: loads and saves can log how heavy the draft has become

/// What a draft's persisted editor history holds.
///
/// The history keeps every undo step, and with them every layer the draft
/// ever had, deleted ones included. A paint layer stores each point of each
/// stroke, and opening the draft rebuilds those points once per step, so a
/// long history over a large drawing costs memory and load time that nothing
/// on screen shows. These counts put that cost in the log. They hold counts
/// only, never layer content.
class EditorStateHistoryStats {
  /// Creates the stats from the counts.
  const EditorStateHistoryStats({
    required this.steps,
    required this.position,
    required this.currentLayers,
    required this.keptLayers,
    required this.paintPoints,
  });

  /// Counts the persisted, unminified [history] the editor exports.
  factory EditorStateHistoryStats.of(Map<String, dynamic> history) {
    final entries = history[_historyKey];
    final steps = entries is List ? entries : const <Object?>[];
    final position = history[_positionKey];
    final current = position is int && position >= 0 && position < steps.length
        ? steps[position]
        : (steps.isEmpty ? null : steps.last);

    final keptIds = <Object?>{};
    var paintPoints = 0;
    void countLayer(Object? layer) {
      if (layer is! Map) return;
      keptIds.add(layer[_idKey]);
      paintPoints += _paintPointsOf(layer);
    }

    final references = history[_referencesKey];
    if (references is Map) {
      keptIds.addAll(references.keys);
      references.values.forEach(countLayer);
    }
    for (final step in steps) {
      if (step is Map) _layersOf(step).forEach(countLayer);
    }

    return EditorStateHistoryStats(
      steps: steps.length,
      position: position is int ? position : null,
      currentLayers: current is Map ? _layersOf(current).length : 0,
      keptLayers: keptIds.whereType<Object>().length,
      paintPoints: paintPoints,
    );
  }

  /// The undo steps the history holds.
  final int steps;

  /// The step the editor shows, or `null` when the history names none.
  final int? position;

  /// The layers the shown step holds.
  final int currentLayers;

  /// The distinct layers any step holds, including ones deleted since.
  final int keptLayers;

  /// The stroke points stored for paint layers, summed over every place the
  /// history stores a stroke list.
  final int paintPoints;

  @override
  String toString() =>
      'history $steps step(s) at ${position ?? '-'}, '
      'layers $currentLayers current / $keptLayers kept, '
      'paint points $paintPoints';
}

const _historyKey = 'history';
const _positionKey = 'position';
const _referencesKey = 'references';
const _layersKey = 'layers';
const _idKey = 'id';
const _itemsKey = 'items';
const _itemKey = 'item';
const _offsetsKey = 'offsets';

List<Object?> _layersOf(Map<Object?, Object?> step) {
  final layers = step[_layersKey];
  return layers is List ? layers : const [];
}

/// The stroke points [layer] stores. A paint layer writes its strokes as
/// `items` and repeats the first one as `item`, so `item` counts only when
/// there is no `items` list.
int _paintPointsOf(Map<Object?, Object?> layer) {
  final items = layer[_itemsKey];
  final strokes = items is List && items.isNotEmpty
      ? items
      : [?layer[_itemKey]];
  var points = 0;
  for (final stroke in strokes) {
    if (stroke is! Map) continue;
    final offsets = stroke[_offsetsKey];
    if (offsets is List) points += offsets.length;
  }
  return points;
}
