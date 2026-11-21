// ABOUTME: Maps a collaborative room onto the editor's split-screen layouts:
// ABOUTME: which layouts fit, which cell is whose, and each cell's shape

import 'dart:ui';

import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/video_editor/split_screen_layout.dart';

/// Space between two cells of a room's video, as a fraction of the frame's
/// shorter side (see [SplitScreenLayoutPreset.cellRects]).
const collabRoomCellGap = 0.01;

/// The fewest people a room needs before its author can start it.
const collabRoomMinParticipants = 2;

/// The layouts a room of [participantCount] people can be filmed in, in the
/// order the editor lists them.
List<SplitScreenLayoutPreset> collabRoomLayoutsFor(int participantCount) =>
    SplitScreenLayoutPreset.values
        .where((preset) => preset.cellCount == participantCount)
        .toList();

/// Extension methods reading a room's layout choices.
extension CollabRoomLayout on CollabRoom {
  /// The layout the author picked, or `null` before one is picked or when
  /// this version of the app does not know it.
  SplitScreenLayoutPreset? get layoutPreset => SplitScreenLayoutPreset.values
      .where((preset) => preset.name == layout)
      .firstOrNull;

  /// The shape of the posted video.
  model.AspectRatio get frameAspectRatio =>
      aspectRatio == 'square' ? model.AspectRatio.square : .vertical;

  /// Where each cell of the picked layout sits, as fractions of the frame.
  List<Rect> get cellRects =>
      layoutPreset?.cellRects(
        aspectRatio: frameAspectRatio.value,
        gap: collabRoomCellGap,
      ) ??
      const [];

  /// The shape of each cell of the picked layout in its rect of [cellRects].
  List<SplitScreenCellShape> get cellShapes =>
      layoutPreset?.cellShapes(
        aspectRatio: frameAspectRatio.value,
        gap: collabRoomCellGap,
      ) ??
      const [];

  /// The people who fill a cell, in cell order: everyone the author already
  /// seated by their cell, then whoever joined since in member order.
  List<CollabRoomMember> get seats {
    final people = participants;
    final seated = people.where((m) => m.cell != null).toList()
      ..sort((a, b) => a.cell!.compareTo(b.cell!));
    return [...seated, ...people.where((m) => m.cell == null)];
  }

  /// The cell [pubkey] fills, or `null`.
  int? cellOf(String pubkey) =>
      participants.where((m) => m.pubkey == pubkey).firstOrNull?.cell;

  /// The shape of the cell [pubkey] fills, or `null` when the layout gives
  /// them none.
  SplitScreenCellShape? cellShapeOf(String pubkey) {
    final cell = cellOf(pubkey);
    final shapes = cellShapes;
    if (cell == null || cell >= shapes.length) return null;
    return shapes[cell];
  }

  /// Width / height of the cell [pubkey] fills, or `null` when the layout
  /// gives them none.
  double? cellAspectRatioOf(String pubkey) {
    final cell = cellOf(pubkey);
    final rects = cellRects;
    if (cell == null || cell >= rects.length) return null;
    final rect = rects[cell];
    return rect.width * frameAspectRatio.value / rect.height;
  }
}
