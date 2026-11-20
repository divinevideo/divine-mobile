// ABOUTME: Maps a collaborative room onto the editor's split-screen layouts:
// ABOUTME: which layouts fit, which cell is whose, and each cell's shape

import 'dart:math' as math;
import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';

/// Space between two cells of a room's video, as a fraction of the frame's
/// shorter side (see [SplitScreenLayoutPreset.cellRects]), until the host
/// sets one.
const collabRoomCellGap = 0.01;

/// The colour of the gaps between a room's cells until the host picks one:
/// fixed media chrome, the same in either appearance.
const Color collabRoomBorderColor = VineTheme.backgroundColor;

/// The fewest people a room needs before its author can start it.
const collabRoomMinParticipants = 2;

/// How long each part plays in series until the host picks a length.
const collabRoomDefaultPartLength = Duration(seconds: 3);

/// The shortest part the host can pick.
const collabRoomMinPartLength = Duration(seconds: 1);

/// The steps the part length moves in.
const collabRoomPartLengthStep = Duration(milliseconds: 100);

/// The longest part each of [participantCount] people can film in series:
/// all of them together still fit in one video. Rounded down to a whole
/// [collabRoomPartLengthStep].
Duration collabRoomMaxPartLength(int participantCount) {
  final share =
      VideoEditorConstants.maxDuration.inMilliseconds ~/
      math.max(participantCount, collabRoomMinParticipants);
  final step = collabRoomPartLengthStep.inMilliseconds;
  return Duration(milliseconds: share ~/ step * step);
}

/// How long each of [participantCount] people's parts plays in series:
/// [picked], or [collabRoomDefaultPartLength] before a pick, kept between
/// [collabRoomMinPartLength] and [collabRoomMaxPartLength].
Duration collabRoomPartLengthFor(Duration? picked, int participantCount) {
  final max = collabRoomMaxPartLength(participantCount);
  final length = picked ?? collabRoomDefaultPartLength;
  if (length > max) return max;
  if (length < collabRoomMinPartLength) return collabRoomMinPartLength;
  return length;
}

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

  /// Space between two cells: the host's pick, or [collabRoomCellGap] for a
  /// room whose host has not set one, at most the widest gap a layout draws.
  double get cellGap => (snapshot.gap ?? collabRoomCellGap).clamp(
    0,
    SplitScreenLayoutGeometry.maxGap,
  );

  /// The colour of the gaps: the host's pick, or [collabRoomBorderColor].
  Color get borderColor {
    final rgb = snapshot.borderColor;
    return rgb == null
        ? collabRoomBorderColor
        : colorFromArgb32(0xFF000000 | rgb);
  }

  /// Whether the parts play one after another, each full frame, instead of
  /// side by side.
  bool get inSeries => arrangement == CollabRoomArrangement.series;

  /// How long each part plays in series.
  Duration get partLength =>
      collabRoomPartLengthFor(snapshot.partLength, participants.length);

  /// Where each cell of the picked layout sits, as fractions of the frame.
  List<Rect> get cellRects =>
      layoutPreset?.cellRects(
        aspectRatio: frameAspectRatio.value,
        gap: cellGap,
      ) ??
      const [];

  /// The shape of each cell of the picked layout in its rect of [cellRects].
  List<SplitScreenCellShape> get cellShapes =>
      layoutPreset?.cellShapes(
        aspectRatio: frameAspectRatio.value,
        gap: cellGap,
      ) ??
      const [];

  /// Whether every participant has a cell of their own in the picked layout.
  bool get seatsFitLayout {
    final count = layoutPreset?.cellCount;
    if (count == null) return false;
    final cells = participants.map((member) => member.cell).toList();
    return cells.length == count &&
        cells.toSet().length == count &&
        cells.every((cell) => cell != null && cell >= 0 && cell < count);
  }

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
  /// them none. In series every part fills the whole frame.
  SplitScreenCellShape? cellShapeOf(String pubkey) {
    final cell = cellOf(pubkey);
    final shapes = cellShapes;
    if (cell == null || cell >= shapes.length) return null;
    if (inSeries) return SplitScreenCellShape.rectangle;
    return shapes[cell];
  }

  /// Width / height of the cell [pubkey] fills, or `null` when the layout
  /// gives them none. In series every part fills the whole frame.
  double? cellAspectRatioOf(String pubkey) {
    final cell = cellOf(pubkey);
    final rects = cellRects;
    if (cell == null || cell >= rects.length) return null;
    if (inSeries) return frameAspectRatio.value;
    final rect = rects[cell];
    return rect.width * frameAspectRatio.value / rect.height;
  }
}
