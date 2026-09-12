import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';

/// Watches [TimelineOverlayBloc] and renders layer / sound / filter strips.
///
/// Extracted into its own widget so that overlay state changes only rebuild
/// the overlay strips — not the clip strip or ruler.
class TimelineOverlayStrips extends StatefulWidget {
  const TimelineOverlayStrips({
    required this.totalWidth,
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.clipEdgesMs,
    required this.playheadPosition,
    super.key,
    this.onItemTapped,
    this.onItemMoved,
    this.onItemMoving,
    this.onItemTrimmed,
    this.onTrimDragChanged,
    this.onDragStarted,
    this.onDragEnded,
  });

  final double totalWidth;
  final double pixelsPerSecond;
  final Duration totalDuration;
  final List<int> clipEdgesMs;
  final ValueNotifier<Duration> playheadPosition;
  final ValueChanged<TimelineOverlayItem>? onItemTapped;
  final OverlayMoveCallback? onItemMoved;
  final OverlayMovingCallback? onItemMoving;
  final OverlayTrimCallback? onItemTrimmed;
  final ValueChanged<bool>? onTrimDragChanged;
  final ValueChanged<TimelineOverlayItem>? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  State<TimelineOverlayStrips> createState() => _TimelineOverlayStripsState();
}

class _TimelineOverlayStripsState extends State<TimelineOverlayStrips> {
  // -- cached inputs (change detection) ------------------------------------
  List<TimelineOverlayItem>? _prevItems;
  String? _prevSelectedId;
  List<int>? _prevClipEdgesMs;
  List<Duration>? _prevTimelineMarkers;

  // -- cached bucket-split results -----------------------------------------
  var _soundItems = const <TimelineOverlayItem>[];
  var _filterItems = const <TimelineOverlayItem>[];
  var _tuneItems = const <TimelineOverlayItem>[];
  var _layerItems = const <TimelineOverlayItem>[];
  var _captionItems = const <TimelineOverlayItem>[];
  var _soundRowCount = 0;
  var _filterRowCount = 0;
  var _tuneRowCount = 0;
  var _layerRowCount = 0;
  var _captionRowCount = 0;

  // -- cached snap-point list -----------------------------------------------
  var _snapPointsMs = const <int>[];

  void _rebuildBuckets(List<TimelineOverlayItem> items) {
    final soundItems = <TimelineOverlayItem>[];
    final filterItems = <TimelineOverlayItem>[];
    final tuneItems = <TimelineOverlayItem>[];
    final layerItems = <TimelineOverlayItem>[];
    final captionItems = <TimelineOverlayItem>[];
    var maxSoundRow = -1;
    var maxFilterRow = -1;
    var maxTuneRow = -1;
    var maxLayerRow = -1;
    var maxCaptionRow = -1;

    for (final item in items) {
      switch (item.type) {
        case TimelineOverlayType.sound:
          soundItems.add(item);
          if (item.row > maxSoundRow) maxSoundRow = item.row;
        case TimelineOverlayType.filter:
          filterItems.add(item);
          if (item.row > maxFilterRow) maxFilterRow = item.row;
        case TimelineOverlayType.tune:
          tuneItems.add(item);
          if (item.row > maxTuneRow) maxTuneRow = item.row;
        case TimelineOverlayType.layer:
          layerItems.add(item);
          if (item.row > maxLayerRow) maxLayerRow = item.row;
        case TimelineOverlayType.captions:
          captionItems.add(item);
          if (item.row > maxCaptionRow) maxCaptionRow = item.row;
      }
    }

    _soundItems = soundItems;
    _filterItems = filterItems;
    _tuneItems = tuneItems;
    _layerItems = layerItems;
    _captionItems = captionItems;
    _soundRowCount = maxSoundRow + 1;
    _filterRowCount = maxFilterRow + 1;
    _tuneRowCount = maxTuneRow + 1;
    _layerRowCount = maxLayerRow + 1;
    _captionRowCount = maxCaptionRow + 1;
  }

  void _rebuildSnapPoints(
    List<TimelineOverlayItem> items,
    String? selectedItemId,
    List<int> clipEdgesMs,
    List<Duration> timelineMarkers,
  ) {
    final snapSet = <int>{};
    for (final item in items) {
      if (item.id == selectedItemId) continue;
      snapSet.add(item.startTime.inMilliseconds);
      snapSet.add(item.endTime.inMilliseconds);
    }
    snapSet.addAll(clipEdgesMs);
    snapSet.addAll(timelineMarkers.map((marker) => marker.inMilliseconds));
    snapSet.add(widget.playheadPosition.value.inMilliseconds);
    _snapPointsMs = snapSet.toList();
  }

  @override
  Widget build(BuildContext context) {
    final (
      :items,
      :selectedItemId,
      :collapsedTypes,
      :timelineMarkers,
      :isLayerMultiSelectMode,
      :multiSelectedLayerIds,
    ) = context.select(
      (TimelineOverlayBloc b) => (
        items: b.state.items,
        selectedItemId: b.state.selectedItemId,
        collapsedTypes: b.state.collapsedTypes,
        timelineMarkers: b.state.timelineMarkers,
        isLayerMultiSelectMode: b.state.isLayerMultiSelectMode,
        multiSelectedLayerIds: b.state.multiSelectedLayerIds,
      ),
    );
    final isVolumeEditMode = context.select(
      (VideoEditorMainBloc b) => b.state.isVolumeEditMode,
    );

    // Rebuild buckets only when the items list changes.
    final itemsDirty = !identical(items, _prevItems);
    if (itemsDirty) {
      _rebuildBuckets(items);
      _prevItems = items;
    }

    // Rebuild snap points when items, selection, or clip edges change.
    if (itemsDirty ||
        _prevSelectedId != selectedItemId ||
        !identical(widget.clipEdgesMs, _prevClipEdgesMs) ||
        !identical(timelineMarkers, _prevTimelineMarkers)) {
      _rebuildSnapPoints(
        items,
        selectedItemId,
        widget.clipEdgesMs,
        timelineMarkers,
      );
      _prevSelectedId = selectedItemId;
      _prevClipEdgesMs = widget.clipEdgesMs;
      _prevTimelineMarkers = timelineMarkers;
    }

    // In volume edit mode each sound item gets its own dedicated row so the
    // user can adjust the volume of every track independently. The row index
    // is set by list position (0, 1, 2, …) regardless of the item's stored
    // row value, which may place multiple items on the same row in normal mode.
    final soundItemsForDisplay = isVolumeEditMode && _soundItems.isNotEmpty
        ? [
            for (var i = 0; i < _soundItems.length; i++)
              _soundItems[i].copyWith(row: i),
          ]
        : _soundItems;
    final soundRowCountForDisplay = isVolumeEditMode
        ? _soundItems.length
        : _soundRowCount;

    final stripConfigs = [
      (
        items: soundItemsForDisplay,
        rowCount: soundRowCountForDisplay,
        isCollapsed:
            !isVolumeEditMode &&
            collapsedTypes.contains(TimelineOverlayType.sound),
        type: TimelineOverlayType.sound,
        color: VineTheme.accentVioletBackground,
        rowHeight: TimelineConstants.soundOverlayRowHeight,
      ),
      (
        items: _filterItems,
        rowCount: _filterRowCount,
        isCollapsed: collapsedTypes.contains(TimelineOverlayType.filter),
        type: TimelineOverlayType.filter,
        color: VineTheme.success,
        rowHeight: TimelineConstants.overlayRowHeight,
      ),
      (
        items: _tuneItems,
        rowCount: _tuneRowCount,
        isCollapsed: collapsedTypes.contains(TimelineOverlayType.tune),
        type: TimelineOverlayType.tune,
        color: VineTheme.accentBlueBackground,
        rowHeight: TimelineConstants.overlayRowHeight,
      ),
      (
        items: _layerItems,
        rowCount: _layerRowCount,
        isCollapsed: collapsedTypes.contains(TimelineOverlayType.layer),
        type: TimelineOverlayType.layer,
        color: VineTheme.accentVioletBackground,
        rowHeight: TimelineConstants.overlayRowHeight,
      ),
      (
        items: _captionItems,
        rowCount: _captionRowCount,
        isCollapsed: collapsedTypes.contains(TimelineOverlayType.captions),
        type: TimelineOverlayType.captions,
        color: VineTheme.accentPinkBackground,
        rowHeight: TimelineConstants.overlayRowHeight,
      ),
    ];

    return Padding(
      padding: const .only(top: TimelineConstants.overlayStripGap),
      child: Column(
        spacing: TimelineConstants.overlayStripGap,
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          for (final config in stripConfigs)
            if (config.items.isNotEmpty)
              TimelineOverlayStrip(
                items: config.items,
                rowCount: config.rowCount,
                totalWidth: widget.totalWidth,
                pixelsPerSecond: widget.pixelsPerSecond,
                totalDuration: widget.totalDuration,
                clipEdgesMs: widget.clipEdgesMs,
                color: config.color,
                rowHeight: config.rowHeight,
                isCollapsed: config.isCollapsed,
                selectedItemId: selectedItemId,
                // Every strip enters selection mode so non-mergeable items
                // (audio, filters, text, stickers) dim and can't drag; only
                // mergeable draw layers stay selectable.
                isLayerMultiSelectMode: isLayerMultiSelectMode,
                multiSelectedLayerIds: multiSelectedLayerIds,
                snapPointsMs: _snapPointsMs,
                onItemTapped: widget.onItemTapped,
                onItemMoved: widget.onItemMoved,
                onItemMoving: widget.onItemMoving,
                onTrimChanged: widget.onItemTrimmed,
                onTrimDragChanged: widget.onTrimDragChanged,
                onDragStarted: widget.onDragStarted,
                onDragEnded: widget.onDragEnded,
              ),
        ],
      ),
    );
  }
}
