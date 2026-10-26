// ABOUTME: The small diamond that marks a keyframe on a timeline tile that is
// ABOUTME: not selected: a layer's own, a layer mask's or a clip mask's.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';

/// A keyframe drawn small, centred at [left] on the edge of its tile [top]
/// down from the tile's top: the bottom edge for a layer's own keyframes, the
/// top one for a mask's.
///
/// Only a mark: a tap on it reaches the tile, like a tap anywhere else on it.
/// White with a dark rim, so it reads on the tile and on the timeline beneath
/// it alike. Place it in a [Stack].
class TimelineKeyframeDot extends StatelessWidget {
  /// Creates a [TimelineKeyframeDot].
  const TimelineKeyframeDot({required this.left, required this.top, super.key});

  /// Where along the tile the keyframe sits.
  final double left;

  /// How far down the tile the edge it sits on runs.
  final double top;

  /// How wide and high the mark is.
  static const double size = 10;
  static const double _coreSize = 6;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left - size / 2,
      top: top - size / 2,
      width: size,
      height: size,
      child: const IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            alignment: Alignment.center,
            children: [
              DivineIcon(
                icon: .diamondFill,
                size: size,
                color: TimelineConstants.trimHandleMarkerColor,
              ),
              DivineIcon(
                icon: .diamondFill,
                size: _coreSize,
                color: VineTheme.whiteText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
