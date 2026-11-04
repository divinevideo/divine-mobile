// ABOUTME: Thin line that fills as a sound plays, shared by the sound picker's
// ABOUTME: player and My Sounds rows that have no waveform to fill.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A thin line filled to [progress], a 0–1 fraction of a sound played.
///
/// Decorative: what plays is said by the row or player it sits in.
class SoundProgressBar extends StatelessWidget {
  const SoundProgressBar({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: .circular(2),
        child: SizedBox(
          height: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: context.vineColors.outlineDisabled),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: progress,
                child: ColoredBox(color: context.vineColors.accentPositive),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
