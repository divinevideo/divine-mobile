import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

class TimelineDropIndicatorLine extends StatelessWidget {
  const TimelineDropIndicatorLine({required this.lineY, super.key});

  final double lineY;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: lineY - 0.5,
      child: ColoredBox(
        color: context.vineColors.onSurfaceMuted,
        child: const SizedBox(height: 1),
      ),
    );
  }
}
